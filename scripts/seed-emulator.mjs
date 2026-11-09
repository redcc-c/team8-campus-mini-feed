// Local fixtures only. Never use production service accounts in this script.
const projectId = 'demo-team8-campus';
const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Seeding is restricted to a loopback Firestore emulator.');
}
const base = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;
async function write(path, fields) {
  const response = await fetch(`${base}/${path}`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ fields }),
  });
  if (!response.ok) throw new Error(`Local seed failed: ${response.status} ${path}`);
}
for (const [id, name, description] of [
  ['free', '자유', '가벼운 일상과 캠퍼스 이야기'],
  ['study', '공부', '질문과 스터디, 배움의 기록'],
  ['hobby', '취미', '함께 즐기는 관심사와 취미'],
]) {
  await write(`boards/${id}`, { name: { stringValue: name }, description: { stringValue: description } });
}
await write('posts/seed-welcome', {
  boardId: { stringValue: 'free' }, authorId: { stringValue: 'seed-user-0008' },
  content: { stringValue: '로컬 Firebase 테스트 게시글입니다. 새 글과 댓글을 작성해 보세요.' },
  createdAt: { timestampValue: new Date().toISOString() },
});
console.log('Seeded 3 boards and one welcome post in demo-team8-campus (local only).');
