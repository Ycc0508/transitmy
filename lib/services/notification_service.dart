import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: 1,
      title: 'Service Alert',
      message: 'Minor delays may occur on selected Rapid Rail services.',
      type: 'Service Alert',
      route: 'Rapid Rail',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
    NotificationModel(
      id: 2,
      title: 'News & Updates',
      message: 'Check the latest public transport information before travelling.',
      type: 'News & Updates',
      route: 'All Routes',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  List<NotificationModel> getActiveNotifications() {
    final result = _notifications.where((item) => item.isActive).toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(result);
  }

  List<NotificationModel> getAllNotifications() {
    final result = List<NotificationModel>.from(_notifications);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  void addNotification({
    required String title,
    required String message,
    required String type,
    required String route,
  }) {
    final nextId = _notifications.isEmpty
        ? 1
        : _notifications.map((item) => item.id).reduce((a, b) => a > b ? a : b) + 1;

    _notifications.add(
      NotificationModel(
        id: nextId,
        title: title,
        message: message,
        type: type,
        route: route,
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  void updateNotification({
    required int id,
    required String title,
    required String message,
    required String type,
    required String route,
    required bool isActive,
  }) {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final old = _notifications[index];
    _notifications[index] = NotificationModel(
      id: old.id,
      title: title,
      message: message,
      type: type,
      route: route,
      isActive: isActive,
      createdAt: old.createdAt,
    );
  }

  void deleteNotification(int id) {
    _notifications.removeWhere((item) => item.id == id);
  }
}
