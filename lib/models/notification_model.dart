class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String route;
  final bool isActive;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.route,
    required this.isActive,
    required this.createdAt,
  });
}
