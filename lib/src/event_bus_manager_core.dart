import 'dart:async';

/// Receives subscriptions that should be cancelled with a lifecycle owner.
abstract interface class EventSubscriptionOwner {
  /// Registers [subscription] for lifecycle-managed cancellation.
  void registerEventSubscription(EventSubscriptionHandle subscription);

  /// Removes an already cancelled [subscription] from lifecycle management.
  void unregisterEventSubscription(EventSubscriptionHandle subscription);
}

/// A cancellable subscription managed by [EventBusManager].
abstract interface class EventSubscriptionHandle {
  /// Cancels the subscription. Calling this more than once is safe.
  void cancel();
}

/// A framework-independent owner for event subscriptions.
///
/// Call [dispose] from the host object's lifecycle method, such as `dispose`,
/// `close`, `onClose`, or a service shutdown hook.
final class EventBusSubscriptionOwner implements EventSubscriptionOwner {
  final List<EventSubscriptionHandle> _subscriptions =
      <EventSubscriptionHandle>[];

  bool _isDisposed = false;

  /// Whether [dispose] has already been called.
  bool get isDisposed => _isDisposed;

  @override
  void registerEventSubscription(EventSubscriptionHandle subscription) {
    if (_isDisposed) {
      subscription.cancel();
      return;
    }
    _subscriptions.add(subscription);
  }

  @override
  void unregisterEventSubscription(EventSubscriptionHandle subscription) {
    _subscriptions.remove(subscription);
  }

  /// Cancels all owned subscriptions. Calling this more than once is safe.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    final subscriptions = List<EventSubscriptionHandle>.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in subscriptions.reversed) {
      subscription.cancel();
    }
  }
}

/// Adds framework-independent event subscription ownership to any object.
///
/// A lifecycle-aware object must call [disposeEventManager] from its
/// own cleanup callback. After that, `EventBusManager.owner(this)` listeners
/// are cancelled automatically.
mixin EventManagerMixin implements EventSubscriptionOwner {
  final EventBusSubscriptionOwner _eventBusOwner = EventBusSubscriptionOwner();

  /// Whether this object's event subscriptions have been disposed.
  bool get isEventManagerDisposed => _eventBusOwner.isDisposed;

  @override
  void registerEventSubscription(EventSubscriptionHandle subscription) {
    _eventBusOwner.registerEventSubscription(subscription);
  }

  @override
  void unregisterEventSubscription(EventSubscriptionHandle subscription) {
    _eventBusOwner.unregisterEventSubscription(subscription);
  }

  /// Cancels every subscription registered through `owner(this)`.
  void disposeEventManager() {
    _eventBusOwner.dispose();
  }
}

/// A subscription to events of type [T].
///
/// Calling [pause] drops events for this subscription until [resume] is called.
/// It deliberately does not call [StreamSubscription.pause], so a paused
/// subscription cannot build an unbounded event buffer.
final class EventSubscription<T> implements EventSubscriptionHandle {
  EventSubscription._();

  late final StreamSubscription<T> _subscription;
  void Function()? _onCancel;

  bool _isPaused = false;
  bool _isCancelled = false;

  /// Whether event callbacks are currently being ignored.
  bool get isPaused => _isPaused;

  /// Whether this subscription was cancelled.
  bool get isCancelled => _isCancelled;

  /// Stops invoking this subscription's callback and drops future events.
  ///
  /// If [resumeSignal] completes, the subscription resumes automatically. A
  /// failed signal also resumes the subscription, matching Stream semantics.
  void pause([Future<void>? resumeSignal]) {
    if (_isCancelled) {
      return;
    }

    _isPaused = true;
    if (resumeSignal != null) {
      unawaited(
        resumeSignal.then<void>(
          (_) => resume(),
          onError: (_, __) => resume(),
        ),
      );
    }
  }

  /// Starts invoking this subscription's callback again.
  void resume() {
    if (!_isCancelled) {
      _isPaused = false;
    }
  }

  /// Cancels the subscription without requiring callers to await a Future.
  @override
  void cancel() {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    final onCancel = _onCancel;
    _onCancel = null;
    onCancel?.call();
    unawaited(_subscription.cancel());
  }
}

/// A lightweight scope that associates subsequent listeners with [owner].
final class EventBusOwnerScope {
  const EventBusOwnerScope._(this._owner);

  final EventSubscriptionOwner? _owner;

  /// Listens for [T] events and registers the resulting subscription with the
  /// scope owner when one was supplied.
  EventSubscription<T> listen<T>(void Function(T event) onData) {
    return EventBusManager._listen<T>(onData, owner: _owner);
  }
}

/// A global, asynchronous broadcast event bus.
///
/// Events are not retained: listeners only receive events fired after they
/// subscribe. Prefer concrete event types over `dynamic` in application code.
final class EventBusManager {
  EventBusManager._();

  static final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  /// Fires [event] to all matching listeners.
  static void fire(dynamic event) {
    if (_controller.isClosed) {
      throw StateError('EventBusManager has been closed.');
    }
    _controller.add(event);
  }

  /// Listens for events of type [T].
  ///
  /// This creates an unowned subscription; callers must call `cancel()`.
  /// Use `EventBusManager.owner(this).listen<T>(...)` for lifecycle-managed
  /// subscriptions in a Flutter State object.
  static EventSubscription<T> listen<T>(void Function(T event) onData) {
    return _listen<T>(onData);
  }

  /// Creates a listener scope owned by [owner].
  ///
  /// Omitting [owner] is equivalent to calling [listen] directly.
  static EventBusOwnerScope owner([EventSubscriptionOwner? owner]) {
    return EventBusOwnerScope._(owner);
  }

  static EventSubscription<T> _listen<T>(
    void Function(T event) onData, {
    EventSubscriptionOwner? owner,
  }) {
    final handle = EventSubscription<T>._();
    handle._subscription = _controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen((event) {
      if (!handle.isPaused && !handle.isCancelled) {
        onData(event);
      }
    });

    if (owner != null) {
      handle._onCancel = () => owner.unregisterEventSubscription(handle);
      owner.registerEventSubscription(handle);
    }

    return handle;
  }
}
