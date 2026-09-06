import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryBlue = Color(0xFF2F68B1);

  bool _notificationsEnabled = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Preferences',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined, color: primaryBlue),
                  title: const Text('Notifications'),
                  subtitle: const Text('Receive service alerts and updates'),
                  value: _notificationsEnabled,
                  activeColor: primaryBlue,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveBool('notifications_enabled', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: primaryBlue),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch to dark theme'),
                  value: _darkMode,
                  activeColor: primaryBlue,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    _saveBool('dark_mode', value);
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'About',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.train, color: primaryBlue),
                  title: const Text('transitMY'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: primaryBlue),
                  title: Text('Data Source'),
                  subtitle: Text('data.gov.my — Malaysian Open Data'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.flag_outlined, color: primaryBlue),
                  title: Text('SDG Goal'),
                  subtitle: Text('SDG 9: Industry, Innovation & Infrastructure'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
