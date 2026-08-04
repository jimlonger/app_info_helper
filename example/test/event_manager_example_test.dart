import 'package:x_app_utils_example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('State event page sends and receives events', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Flutter State 自动销毁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送 CounterChangedEvent'));
    await tester.pump();

    expect(find.text('State 接收值: 1'), findsOneWidget);
  });

  testWidgets('service event page receives service messages', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('普通服务对象关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送服务消息'));
    await tester.pump();

    expect(find.text('最新消息: 服务消息 #1'), findsOneWidget);
  });

  testWidgets('XAppUtils console exposes parameter output actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('XAppUtils 全功能面板'));
    await tester.pumpAndSettle();
    final printJsonButton = find.text('打印完整参数 JSON');
    await tester.tap(printJsonButton);
    await tester.pump();

    expect(find.textContaining('完整参数 JSON'), findsNWidgets(2));
  });
}
