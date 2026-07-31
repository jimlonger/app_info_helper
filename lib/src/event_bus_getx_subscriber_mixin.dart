import 'package:get/get.dart';

import 'event_bus_manager_core.dart';

/// Automatically cancels owned event subscriptions when a GetX controller
/// reaches [GetxController.onClose].
///
/// For framework-independent objects, use [EventManagerMixin]
/// from `event_bus_manager.dart` instead.
mixin EventManagerGetxMixin on GetxController
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
  void onClose() {
    _eventBusOwner.dispose();
    super.onClose();
  }
}
