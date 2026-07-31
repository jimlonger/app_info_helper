import 'package:flutter/widgets.dart';

import 'event_bus_manager_core.dart';

/// Automatically cancels owned event subscriptions when a [State] is disposed.
mixin EventManagerStateMixin<T extends StatefulWidget> on State<T>
    implements EventSubscriptionOwner {
  final EventBusSubscriptionOwner _eventBusOwner = EventBusSubscriptionOwner();

  @override
  void registerEventSubscription(EventSubscriptionHandle subscription) {
    _eventBusOwner.registerEventSubscription(subscription);
  }

  @override
  void unregisterEventSubscription(EventSubscriptionHandle subscription) {
    _eventBusOwner.unregisterEventSubscription(subscription);
  }

  @override
  void dispose() {
    _eventBusOwner.dispose();
    super.dispose();
  }
}
