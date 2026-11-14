import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/models.dart';
import '../../data/community_repository.dart';

class PopularRanking extends StatefulWidget {
  const PopularRanking({
    required this.posts,
    required this.repository,
    required this.builder,
    super.key,
  });

  final List<FeedPost> posts;
  final CommunityRepository repository;
  final Widget Function(List<FeedPost>) builder;

  @override
  State<PopularRanking> createState() => _PopularRankingState();
}

class _PopularRankingState extends State<PopularRanking> {
  final _counts = <String, int>{};
  final _subscriptions = <String, StreamSubscription<Set<String>>>{};

  @override
  void initState() {
    super.initState();
    _syncPosts();
  }

  @override
  void didUpdateWidget(PopularRanking oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPosts();
  }

  void _syncPosts() {
    final visibleIds = widget.posts.map((post) => post.id).toSet();
    for (final id in _subscriptions.keys.toList()) {
      if (visibleIds.contains(id)) continue;
      _subscriptions.remove(id)?.cancel();
      _counts.remove(id);
    }
    for (final id in visibleIds) {
      _subscriptions.putIfAbsent(
        id,
        () => widget.repository.watchLikes(id).listen((likes) {
          if (mounted && _counts[id] != likes.length) {
            setState(() => _counts[id] = likes.length);
          }
        }, onError: (Object error, StackTrace stackTrace) {}),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = widget.posts.toList()
      ..sort((a, b) {
        final order = (_counts[b.id] ?? 0).compareTo(_counts[a.id] ?? 0);
        return order == 0 ? b.createdAt.compareTo(a.createdAt) : order;
      });
    return widget.builder(ranked);
  }
}
