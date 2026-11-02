import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, getDocs, collection, serverTimestamp, setDoc, setLogLevel, Timestamp } from 'firebase/firestore';

setLogLevel('silent');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-team8-campus', firestore: {
    host: '127.0.0.1', port: 8080, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
  }});
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'boards/free'), { name: '자유', description: '테스트 게시판' });
  });
});
after(async () => { await env?.cleanup(); });
const user = (uid = 'alice') => env.authenticatedContext(uid).firestore();
const payload = (changes = {}) => ({ boardId: 'free', authorId: 'alice', content: '안녕하세요', createdAt: serverTimestamp(), ...changes });
async function post() { const db = user(); await setDoc(doc(db, 'posts/p1'), payload()); return db; }

test('unauthenticated access is denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(db, 'boards')));
  await assertFails(setDoc(doc(db, 'posts/p1'), payload()));
});
test('authenticated users read boards but cannot create boards', async () => {
  const db = user();
  await assertSucceeds(getDocs(collection(db, 'boards')));
  await assertFails(setDoc(doc(db, 'boards/new'), { name: '새 게시판', description: '임의 생성' }));
});
test('post owner is tied to authenticated UID', async () => {
  await assertSucceeds(setDoc(doc(user(), 'posts/p1'), payload()));
  await assertFails(setDoc(doc(user('bob'), 'posts/p2'), payload()));
});
test('post fields, existing board and server timestamps are required', async () => {
  const db = user();
  await assertFails(setDoc(doc(db, 'posts/extra'), payload({ admin: true })));
  await assertFails(setDoc(doc(db, 'posts/board'), payload({ boardId: 'unknown' })));
  await assertFails(setDoc(doc(db, 'posts/time'), payload({ createdAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(db, 'posts/missing'), { authorId: 'alice', content: '누락' }));
});
test('empty and whitespace-only posts are rejected', async () => {
  for (const [index, content] of ['', '  \n\t ', '\u3000'].entries()) {
    await assertFails(setDoc(doc(user(), `posts/empty-${index}`), payload({ content })));
  }
});
test('500 Korean characters are allowed; 501 are rejected', async () => {
  await assertSucceeds(setDoc(doc(user(), 'posts/boundary'), payload({ content: '가'.repeat(500) })));
  await assertFails(setDoc(doc(user(), 'posts/over'), payload({ content: '가'.repeat(501) })));
});
test('emoji limits match the Dart Unicode code-point counter', async () => {
  await assertSucceeds(setDoc(doc(user(), 'posts/emoji'), payload({ content: '🙂'.repeat(500) })));
  await assertFails(setDoc(doc(user(), 'posts/emoji-over'), payload({ content: '🙂'.repeat(501) })));
});
test('authenticated peers can read posts; content mutation is disabled initially', async () => {
  const db = await post();
  await assertSucceeds(getDoc(doc(user('bob'), 'posts/p1')));
  await assertFails(setDoc(doc(db, 'posts/p1'), payload({ content: '변조' })));
  await assertFails(deleteDoc(doc(db, 'posts/p1')));
});
test('comments require an existing post, own UID and valid content', async () => {
  const db = await post();
  const comment = { authorId: 'alice', content: '댓글', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'posts/p1/comments/c1'), comment));
  await assertFails(setDoc(doc(db, 'posts/missing/comments/c1'), comment));
  await assertFails(setDoc(doc(db, 'posts/p1/comments/spoof'), { ...comment, authorId: 'bob' }));
  await assertFails(setDoc(doc(db, 'posts/p1/comments/empty'), { ...comment, content: ' \n ' }));
  await assertFails(setDoc(doc(db, 'posts/p1/comments/long'), { ...comment, content: '가'.repeat(201) }));
});
test('one like per UID; only the owner can cancel it', async () => {
  const db = await post();
  const ref = doc(db, 'posts/p1/likes/alice');
  const like = { userId: 'alice', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(ref, like));
  await assertFails(setDoc(ref, like));
  await assertFails(setDoc(doc(user('bob'), 'posts/p1/likes/alice'), like));
  await assertFails(deleteDoc(doc(user('bob'), 'posts/p1/likes/alice')));
  await assertSucceeds(deleteDoc(ref));
});
test('report creation is restricted; report contents are never readable by clients', async () => {
  const db = await post();
  const report = { reporterId: 'alice', reason: 'spam', createdAt: serverTimestamp() };
  const ref = doc(db, 'posts/p1/reports/alice');
  await assertSucceeds(setDoc(ref, report));
  await assertFails(getDoc(ref));
  await assertFails(getDoc(doc(user('bob'), 'posts/p1/reports/alice')));
  await assertFails(setDoc(ref, report));
  await assertFails(setDoc(doc(user('bob'), 'posts/p1/reports/bob'), { ...report, reporterId: 'bob', reason: 'invalid' }));
});
test('unlisted collections are denied', async () => {
  await assertFails(setDoc(doc(user(), 'private/config'), { role: 'admin' }));
});
