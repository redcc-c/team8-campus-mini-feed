import 'package:flutter/foundation.dart';

class FeedBookmarks extends ChangeNotifier {
  final _posts = <String>{};
  final _boards = <String>{};

  bool hasPost(String id) => _posts.contains(id);
  bool hasBoard(String id) => _boards.contains(id);
  Iterable<String> get recentPostIds => _posts.toList().reversed;

  void togglePost(String id) {
    if (!_posts.add(id)) _posts.remove(id);
    notifyListeners();
  }

  void toggleBoard(String id) {
    if (!_boards.add(id)) _boards.remove(id);
    notifyListeners();
  }
}
