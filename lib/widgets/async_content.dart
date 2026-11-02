import 'package:flutter/material.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    required this.snapshot,
    required this.builder,
    super.key,
  });
  final AsyncSnapshot<T> snapshot;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('데이터를 불러오지 못했습니다. 연결을 확인하고 화면을 다시 열어 주세요.'),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return builder(snapshot.requireData);
  }
}

void showNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
