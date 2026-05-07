import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
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
  String? _avatarUrl;
  int _routineResetToken = 0;
  int _alimentacionResetToken = 0;

  late String username;
  late String bio;

  @override
  void initState() {
    super.initState();
    username = widget.userData['username'] ?? 'usuario';
    bio = widget.userData['bio'] ?? '';
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final profile = await SupabaseService.instance.getRawMyProfile();
      if (!mounted) return;
      final url = profile?['avatar_url'] as String?;
      if (url != null && url.isNotEmpty) {
        setState(() => _avatarUrl = url);
      }
    } catch (_) {}
  }

  void _onAvatarChanged(String? newUrl) {
    if (newUrl != null && newUrl.isNotEmpty && newUrl != _avatarUrl) {
      setState(() => _avatarUrl = newUrl);
    }
  }

  List<Widget> get _screens => [
        RoutineScreen(resetToken: _routineResetToken),
        const HomeScreen(),
        AlimentacionScreen(resetToken: _alimentacionResetToken),
        ProfileScreen(
          initialUsername: username,
          initialBio: bio,
          onAvatarChanged: _onAvatarChanged,
        ),
      ];

  static const _tabNames = ['rutina', 'feed', 'nutricion', 'perfil'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _routineResetToken++;
      if (index == 2) _alimentacionResetToken++;
    });
    AnalyticsService.instance.tabChanged(_tabNames[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        profileImageUrl: _avatarUrl,
      ),
    );
  }
}
