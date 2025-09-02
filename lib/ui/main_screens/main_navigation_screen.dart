// main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'rutina_screen.dart';
import 'alimentacion_screen.dart';
import 'perfil_screen.dart';
import '../shared/custom_bottom_nav.dart';

class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MainNavigationScreen({super.key, required this.userData});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late String username;
  late String bio;

  @override
  void initState() {
    super.initState();
    username = widget.userData['username'] ?? 'usuario';
    bio = widget.userData['bio'] ?? ''; // ← bio vacía si no se agregó aún
  }

  List<Widget> get _screens => [
        const RoutineScreen(),
        const HomeScreen(),
        const AlimentacionScreen(),
        ProfileScreen(
          initialUsername: username,
          initialBio: bio,
        ),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
