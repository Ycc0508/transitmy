import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  static const Color primaryBlue = Color(0xFF2F68B1);
  final NotificationService _service = NotificationService();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _routeController = TextEditingController();

  String _type = 'Service Alert';
  bool _isActive = true;
  int? _editingId;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _titleController.clear();
    _messageController.clear();
    _routeController.clear();
    setState(() {
      _type = 'Service Alert';
      _isActive = true;
      _editingId = null;
    });
  }

  void _saveNotification() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final route = _routeController.text.trim();

    if (title.isEmpty || message.isEmpty || route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    if (_editingId == null) {
      _service.addNotification(
        title: title,
        message: message,
        type: _type,
        route: route,
      );
    } else {
      _service.updateNotification(
        id: _editingId!,
        title: title,
        message: message,
        type: _type,
        route: route,
        isActive: _isActive,
      );
    }

    _clearForm();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingId == null ? 'Notification added.' : 'Notification updated.'),
      ),
    );
  }

  void _edit(NotificationModel item) {
    setState(() {
      _editingId = item.id;
      _titleController.text = item.title;
      _messageController.text = item.message;
      _routeController.text = item.route;
      _type = item.type;
      _isActive = item.isActive;
    });
  }

  Future<void> _delete(NotificationModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text('Delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _service.deleteNotification(item.id);
      if (_editingId == item.id) _clearForm();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.getAllNotifications();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Admin Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildForm(),
          const SizedBox(height: 20),
          const Text(
            'Existing Notifications',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No notifications available.')),
            )
          else
            ...notifications.map(_buildAdminCard),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final editing = _editingId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Edit Notification' : 'Add Notification',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Service Alert', child: Text('Service Alert')),
                DropdownMenuItem(value: 'News & Updates', child: Text('News & Updates')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _routeController,
              decoration: const InputDecoration(
                labelText: 'Route',
                hintText: 'e.g. MRT Kajang Line or All Routes',
                border: OutlineInputBorder(),
              ),
            ),
            if (editing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active notification'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveNotification,
                    icon: Icon(editing ? Icons.save : Icons.add),
                    label: Text(editing ? 'Update' : 'Add'),
                  ),
                ),
                if (editing) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _clearForm,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(NotificationModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          item.type == 'Service Alert'
              ? Icons.warning_amber_rounded
              : Icons.article_outlined,
          color: primaryBlue,
        ),
        title: Text(item.title),
        subtitle: Text(
          '${item.type} • ${item.route}\n${item.message}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => _edit(item),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(item),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
