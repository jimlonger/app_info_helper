import 'dart:convert';

import 'package:x_app_utils/x_app_utils.dart';
import 'package:x_app_utils/event_bus_manager_flutter.dart';
import 'package:x_app_utils/event_bus_manager_getx.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await XAppUtils.instance.init();
  runApp(const ExampleApp());
}

final class CounterChangedEvent {
  const CounterChangedEvent({required this.source, required this.value});

  final String source;
  final int value;
}

final class ExampleMessageEvent {
  const ExampleMessageEvent(this.message);

  final String message;
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EventManager Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const EventManagerHomePage(),
    );
  }
}

class EventManagerHomePage extends StatefulWidget {
  const EventManagerHomePage({super.key});

  @override
  State<EventManagerHomePage> createState() => _EventManagerHomePageState();
}

class _EventManagerHomePageState extends State<EventManagerHomePage>
    with EventManagerStateMixin<EventManagerHomePage> {
  final List<String> _eventLog = <String>[];

  @override
  void initState() {
    super.initState();

    // `dynamic` receives all event types. The State Mixin cancels this
    // subscription automatically when this page is disposed.
    EventBusManager.owner(this).listen<dynamic>((event) {
      if (!mounted) {
        return;
      }
      setState(() {
        _eventLog.insert(0, '${event.runtimeType}: ${_eventText(event)}');
        if (_eventLog.length > 8) {
          _eventLog.removeLast();
        }
      });
    });
  }

  String _eventText(dynamic event) => switch (event) {
        CounterChangedEvent() => '${event.source} = ${event.value}',
        ExampleMessageEvent() => event.message,
        _ => event.toString(),
      };

  @override
  Widget build(BuildContext context) {
    final info = XAppUtils.instance;
    final platformSummary = <String>[
      'Platform: ${info.platform.isEmpty ? '-' : info.platform}',
      'App: ${info.appName.isEmpty ? '-' : info.appName}',
      'Device: ${info.deviceModel.isEmpty ? '-' : info.deviceModel}',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('EventManager 示例')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('当前平台信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...platformSummary.map(Text.new),
          const SizedBox(height: 24),
          Text('事件场景', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const StateEventManagerPage(),
              ),
            ),
            child: const Text('Flutter State 自动销毁'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const GetxEventManagerPage(),
              ),
            ),
            child: const Text('GetX Controller 自动销毁'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ServiceEventManagerPage(),
              ),
            ),
            child: const Text('普通服务对象关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const XAppUtilsConsolePage(),
              ),
            ),
            child: const Text('XAppUtils 全功能面板'),
          ),
          const SizedBox(height: 24),
          Text('全局事件日志', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_eventLog.isEmpty)
            const Text('尚未发送事件')
          else
            ..._eventLog.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry),
              ),
            ),
        ],
      ),
    );
  }
}

class StateEventManagerPage extends StatefulWidget {
  const StateEventManagerPage({super.key});

  @override
  State<StateEventManagerPage> createState() => _StateEventManagerPageState();
}

class _StateEventManagerPageState extends State<StateEventManagerPage>
    with EventManagerStateMixin<StateEventManagerPage> {
  late final EventSubscription<CounterChangedEvent> _subscription;
  int _receivedValue = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _subscription = EventBusManager.owner(this).listen<CounterChangedEvent>(
      (event) {
        if (!mounted) {
          return;
        }
        setState(() => _receivedValue = event.value);
      },
    );
  }

  void _fire() {
    EventBusManager.fire(
      CounterChangedEvent(source: 'State page', value: _receivedValue + 1),
    );
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _subscription.pause();
      } else {
        _subscription.resume();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter State 自动销毁')),
      body: _EventPageBody(
        receivedLabel: 'State 接收值: $_receivedValue',
        paused: _paused,
        onFire: _fire,
        onTogglePause: _togglePause,
        description: '返回上一页时 State.dispose() 自动取消 owner(this) 的订阅。',
      ),
    );
  }
}

class GetxEventManagerController extends GetxController
    with EventManagerGetxMixin {
  final receivedValue = 0.obs;
  final paused = false.obs;
  late final EventSubscription<CounterChangedEvent> _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = EventBusManager.owner(this).listen<CounterChangedEvent>(
      (event) => receivedValue.value = event.value,
    );
  }

  void fire() {
    EventBusManager.fire(
      CounterChangedEvent(source: 'GetX page', value: receivedValue.value + 1),
    );
  }

  void togglePause() {
    paused.toggle();
    if (paused.value) {
      _subscription.pause();
    } else {
      _subscription.resume();
    }
  }
}

class GetxEventManagerPage extends StatefulWidget {
  const GetxEventManagerPage({super.key});

  @override
  State<GetxEventManagerPage> createState() => _GetxEventManagerPageState();
}

class _GetxEventManagerPageState extends State<GetxEventManagerPage> {
  static const String _tag = 'event-manager-example-getx';
  late final GetxEventManagerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(GetxEventManagerController(), tag: _tag);
  }

  @override
  void dispose() {
    // Get.delete invokes the controller's onClose(), where EventManagerGetxMixin
    // automatically cancels owner(this) subscriptions.
    Get.delete<GetxEventManagerController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GetX Controller 自动销毁')),
      body: Obx(
        () => _EventPageBody(
          receivedLabel: 'GetX 接收值: ${_controller.receivedValue.value}',
          paused: _controller.paused.value,
          onFire: _controller.fire,
          onTogglePause: _controller.togglePause,
          description: '页面关闭时 Get.delete() 触发 onClose()，订阅自动取消。',
        ),
      ),
    );
  }
}

class ExampleEventService with EventManagerMixin {
  final ValueNotifier<String> latestMessage = ValueNotifier<String>('尚未接收消息');

  void start() {
    EventBusManager.owner(this).listen<ExampleMessageEvent>((event) {
      latestMessage.value = event.message;
    });
  }

  void close() {
    disposeEventManager();
    latestMessage.dispose();
  }
}

class ServiceEventManagerPage extends StatefulWidget {
  const ServiceEventManagerPage({super.key});

  @override
  State<ServiceEventManagerPage> createState() =>
      _ServiceEventManagerPageState();
}

class _ServiceEventManagerPageState extends State<ServiceEventManagerPage> {
  late final ExampleEventService _service;
  int _messageNumber = 0;

  @override
  void initState() {
    super.initState();
    _service = ExampleEventService()..start();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('普通服务对象关闭')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('服务对象没有框架生命周期，需要在 close() 中调用 disposeEventManager()。'),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: _service.latestMessage,
              builder: (context, message, _) => Text('最新消息: $message'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                _messageNumber++;
                EventBusManager.fire(
                  ExampleMessageEvent('服务消息 #$_messageNumber'),
                );
              },
              child: const Text('发送服务消息'),
            ),
          ],
        ),
      ),
    );
  }
}

class XAppUtilsConsolePage extends StatefulWidget {
  const XAppUtilsConsolePage({super.key});

  @override
  State<XAppUtilsConsolePage> createState() => _XAppUtilsConsolePageState();
}

class _XAppUtilsConsolePageState extends State<XAppUtilsConsolePage> {
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  final TextEditingController _fallbackNamespaceController =
      TextEditingController(text: 'x_app_utils_example');
  final TextEditingController _localIdController =
      TextEditingController(text: 'example-local-id');
  final List<String> _output = <String>[];

  LocalIdSlot _slot = LocalIdSlot.primary;
  bool _running = false;

  XAppUtils get _utils => XAppUtils.instance;

  @override
  void dispose() {
    _fallbackNamespaceController.dispose();
    _localIdController.dispose();
    super.dispose();
  }

  void _append(String value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _output.insert(0, '[${DateTime.now().toIso8601String()}]\n$value');
    });
  }

  Future<void> _run(String label, Future<dynamic> Function() action) async {
    if (_running) {
      return;
    }

    setState(() => _running = true);
    try {
      final result = await action();
      _append('$label\n$result');
    } catch (error, stackTrace) {
      _append('$label 失败\n$error\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  void _printData() {
    _append('完整参数 JSON\n${_jsonEncoder.convert(_utils.data)}');
  }

  void _printSummary() {
    final summary = <String, dynamic>{
      'isInitialized': _utils.isInitialized,
      'appName': _utils.appName,
      'packageName': _utils.packageName,
      'version': _utils.version,
      'buildNumber': _utils.buildNumber,
      'platform': _utils.platform,
      'deviceModel': _utils.deviceModel,
      'osVersion': _utils.osVersion,
      'locale': _utils.locale,
      'timeZone': _utils.timeZone,
      'advertisingId': _utils.advertisingId,
      'deviceId': _utils.deviceId,
      'primaryLocalId': _utils.primaryLocalId,
      'secondaryLocalId': _utils.secondaryLocalId,
    };
    _append('常用参数\n${_jsonEncoder.convert(summary)}');
  }

  Future<void> _configureLocalIds() async {
    final namespace = _fallbackNamespaceController.text.trim();
    await _utils.configureLocalIds(
      LocalIdStorageOptions(
        fallbackNamespace: namespace.isEmpty ? null : namespace,
      ),
    );
    return _printData();
  }

  @override
  Widget build(BuildContext context) {
    final localIdLabel = _slot == LocalIdSlot.primary ? '主本地 ID' : '副本地 ID';

    return Scaffold(
      appBar: AppBar(title: const Text('XAppUtils 全功能面板')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('所有异步调用的返回值、异常和参数都会打印到本页面底部。'),
          const SizedBox(height: 16),
          _ConsoleSection(
            title: '初始化与刷新',
            children: <Widget>[
              _ActionButton(
                label: '初始化 init()',
                running: _running,
                onPressed: () => _run('init()', _utils.init),
              ),
              _ActionButton(
                label: '等待 ready',
                running: _running,
                onPressed: () =>
                    _run('ready', () async => (await _utils.ready).data),
              ),
              _ActionButton(
                label: '刷新全部 refresh()',
                running: _running,
                onPressed: () => _run('refresh()', _utils.refresh),
              ),
              _ActionButton(
                label: '刷新广告 ID',
                running: _running,
                onPressed: () => _run('refreshAdvertisingId()', () async {
                  await _utils.refreshAdvertisingId();
                  return _utils.advertisingId;
                }),
              ),
              _ActionButton(
                label: '刷新设备 ID',
                running: _running,
                onPressed: () => _run('refreshDeviceId()', () async {
                  await _utils.refreshDeviceId();
                  return _utils.deviceId;
                }),
              ),
              _ActionButton(
                label: '请求 ATT / IDFA',
                running: _running,
                onPressed: () => _run('requestIdfaAuthorization()', () async {
                  final result = await _utils.requestIdfaAuthorization();
                  return <String, dynamic>{
                    'isSuccess': result.isSuccess,
                    'idfa': result.idfa,
                    'failure': result.failure.name,
                  };
                }),
              ),
            ],
          ),
          _ConsoleSection(
            title: '参数打印',
            children: <Widget>[
              _ActionButton(
                label: '打印常用参数',
                running: _running,
                onPressed: _printSummary,
              ),
              _ActionButton(
                label: '打印完整参数 JSON',
                running: _running,
                onPressed: _printData,
              ),
            ],
          ),
          _ConsoleSection(
            title: '本地安全 ID',
            children: <Widget>[
              TextField(
                controller: _fallbackNamespaceController,
                decoration: const InputDecoration(
                  labelText: '兜底 namespace（可选）',
                ),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: '配置本地 ID 存储',
                running: _running,
                onPressed: () =>
                    _run('configureLocalIds()', _configureLocalIds),
              ),
              DropdownButtonFormField<LocalIdSlot>(
                initialValue: _slot,
                decoration: const InputDecoration(labelText: 'ID 槽位'),
                items: LocalIdSlot.values
                    .map(
                      (slot) => DropdownMenuItem<LocalIdSlot>(
                        value: slot,
                        child:
                            Text(slot == LocalIdSlot.primary ? '主 ID' : '副 ID'),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (slot) {
                        if (slot != null) {
                          setState(() => _slot = slot);
                        }
                      },
              ),
              TextField(
                controller: _localIdController,
                decoration: InputDecoration(labelText: '$localIdLabel 写入值'),
              ),
              const SizedBox(height: 8),
              _ActionButton(
                label: '读取 $localIdLabel',
                running: _running,
                onPressed: () => _run('readLocalId($_slot)', () {
                  return _utils.readLocalId(slot: _slot);
                }),
              ),
              _ActionButton(
                label: '写入 $localIdLabel',
                running: _running,
                onPressed: () => _run('writeLocalId($_slot)', () async {
                  await _utils.writeLocalId(
                    _localIdController.text,
                    slot: _slot,
                  );
                  return _utils.data;
                }),
              ),
              _ActionButton(
                label: '检查 $localIdLabel 是否存在',
                running: _running,
                onPressed: () => _run('containsLocalId($_slot)', () {
                  return _utils.containsLocalId(slot: _slot);
                }),
              ),
              _ActionButton(
                label: '重置 $localIdLabel',
                running: _running,
                onPressed: () => _run('resetLocalId($_slot)', () {
                  return _utils.resetLocalId(slot: _slot);
                }),
              ),
              _ActionButton(
                label: '删除 $localIdLabel',
                running: _running,
                onPressed: () => _run('deleteLocalId($_slot)', () async {
                  await _utils.deleteLocalId(slot: _slot);
                  return _utils.data;
                }),
              ),
              _ActionButton(
                label: '读取全部本地 ID',
                running: _running,
                onPressed: () =>
                    _run('readAllLocalIds()', _utils.readAllLocalIds),
              ),
              _ActionButton(
                label: '重置全部本地 ID',
                running: _running,
                onPressed: () =>
                    _run('resetAllLocalIds()', _utils.resetAllLocalIds),
              ),
              _ActionButton(
                label: '删除全部本地 ID',
                running: _running,
                onPressed: () => _run('deleteAllLocalIds()', () async {
                  await _utils.deleteAllLocalIds();
                  return _utils.data;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text('页面输出', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed:
                    _output.isEmpty ? null : () => setState(_output.clear),
                child: const Text('清空'),
              ),
            ],
          ),
          const Divider(),
          if (_output.isEmpty)
            const SelectableText('点击上方按钮后，结果将在这里显示。')
          else
            ..._output.map(
              (entry) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsoleSection extends StatelessWidget {
  const _ConsoleSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.running,
    required this.onPressed,
  });

  final String label;
  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: running ? null : onPressed,
        child: Text(label),
      ),
    );
  }
}

class _EventPageBody extends StatelessWidget {
  const _EventPageBody({
    required this.receivedLabel,
    required this.paused,
    required this.onFire,
    required this.onTogglePause,
    required this.description,
  });

  final String receivedLabel;
  final bool paused;
  final VoidCallback onFire;
  final VoidCallback onTogglePause;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(description),
          const SizedBox(height: 16),
          Text(receivedLabel, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: onFire, child: const Text('发送 CounterChangedEvent')),
          OutlinedButton(
            onPressed: onTogglePause,
            child: Text(paused ? '恢复监听' : '暂停监听并丢弃事件'),
          ),
        ],
      ),
    );
  }
}
