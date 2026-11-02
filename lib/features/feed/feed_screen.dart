import 'package:flutter/material.dart';

import '../../core/bootstrap.dart';
import '../../core/models.dart';
import '../../widgets/async_content.dart';
import '../posts/compose_screen.dart';
import '../posts/detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({required this.services, required this.board, super.key});
  final AppServices services;
  final Board board;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final _posts = widget.services.repository.watchPosts(widget.board.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.board.name} 게시판')),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey('compose'),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('글쓰기'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ComposeScreen(services: widget.services, board: widget.board),
        ),
      ),
    ),
    body: StreamBuilder<List<FeedPost>>(
      stream: _posts,
      builder: (context, snapshot) => AsyncContent(
        snapshot: snapshot,
        builder: (posts) => posts.isEmpty
            ? const Center(
                child: Text(
                  '아직 이야기가 없어요.\n첫 번째 글을 남겨 보세요.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    child: InkWell(
                      key: ValueKey('post-${post.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScreen(
                            services: widget.services,
                            board: widget.board,
                            post: post,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_circle_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(anonymousName(post.authorId)),
                                const Spacer(),
                                Text(
                                  relativeTime(post.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              post.content,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '이야기 더 보기 →',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ),
  );
}
