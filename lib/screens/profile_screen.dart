import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'saved_routes_screen.dart';
import 'travel_history_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String name;
  final String email;
  final String phone;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
  });

  static const Color primaryBlue = Color(0xFF2F68B1);

  @override
  Widget build(BuildContext context) {
    final String initial =
        name.isNotEmpty ? name[0].toUpperCase() : email[0].toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 50,
            backgroundColor: primaryBlue,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : 'User',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: primaryBlue),
                  title: const Text('Full Name'),
                  subtitle: Text(name.isNotEmpty ? name : '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email, color: primaryBlue),
                  title: const Text('Email'),
                  subtitle: Text(email),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone, color: primaryBlue),
                  title: const Text('Phone'),
                  subtitle: Text(phone.isNotEmpty ? phone : '-'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outlined, color: primaryBlue),
                  title: const Text('Saved Routes'),
                  subtitle: const Text('View your saved routes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavedRoutesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history, color: primaryBlue),
                  title: const Text('Travel History'),
                  subtitle: const Text('View past trips & activities'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TravelHistoryScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: primaryBlue),
                  title: const Text('Settings'),
                  subtitle: const Text('App settings & preferences'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
