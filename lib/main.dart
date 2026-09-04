import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TransitMyApp());
}

class TransitMyApp extends StatelessWidget {
  const TransitMyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'transitMY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F68B1)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
