# EventBusManager

`EventBusManager` is a lightweight, asynchronous, application-wide event bus.
It uses Dart broadcast streams directly and has no `event_bus` package
dependency.

## Any lifecycle-aware object

The core API does not depend on Flutter. Any object can use
`EventManagerMixin` and invoke `disposeEventManager()` in its own lifecycle
method.

```dart
class SocketService with EventManagerMixin {
  void start() {
    EventBusManager.owner(this).listen<ConnectionLostEvent>((event) {
      // Reconnect.
    });
  }

  void close() {
    disposeEventManager();
  }
}
```

Objects that already provide automatic lifecycle callbacks can call that method
from their `dispose`, `close`, or equivalent callback. The event bus cannot
automatically detect destruction of arbitrary Dart objects without such a
lifecycle signal.

## Send an event

```dart
EventBusManager.fire(const CartChangedEvent(itemCount: 3));
```

Define concrete, immutable events in application code:

```dart
final class CartChangedEvent {
  const CartChangedEvent({required this.itemCount});

  final int itemCount;
}
```

## Listen manually

Use this in services or other long-lived objects. Cancel the subscription when
the object is no longer needed.

```dart
final subscription = EventBusManager.listen<CartChangedEvent>((event) {
  print(event.itemCount);
});

subscription.cancel();
```

Use `listen<dynamic>` only for cross-cutting concerns such as logging. It
receives every event.

## Flutter State lifecycle

Import `package:x_app_utils/event_bus_manager_flutter.dart` and mix in
`EventManagerStateMixin`. Listeners created through `owner(this)` are cancelled
automatically from `State.dispose()`.

```dart
class CartPageState extends State<CartPage>
    with EventManagerStateMixin<CartPage> {
  @override
  void initState() {
    super.initState();
    EventBusManager.owner(this).listen<CartChangedEvent>((event) {
      setState(() {});
    });
  }
}
```

## Pause and resume

```dart
final subscription = EventBusManager.listen<CartChangedEvent>((event) {});

subscription.pause();
// Events fired now are dropped for this subscription, not buffered.
subscription.resume();
subscription.cancel();
```

The pause operation intentionally drops events. Retaining events while paused
requires a queue and can cause unbounded memory growth.
