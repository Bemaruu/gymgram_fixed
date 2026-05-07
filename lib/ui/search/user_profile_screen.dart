import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/medal_preview_section.dart';
import '../../widgets/post_grid.dart';
import '../social/follow_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _followLoading = false;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.getProfileById(widget.userId),
        SupabaseService.instance.getPostsByUserId(widget.userId),
        SupabaseService.instance.isFollowing(widget.userId),
        SupabaseService.instance.getFollowCounts(widget.userId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _posts = results[1] as List<Map<String, dynamic>>;
        _isFollowing = results[2] as bool;
        final counts = results[3] as Map<String, int>;
        _followersCount = counts['followers'] ?? 0;
        _followingCount = counts['following'] ?? 0;
        _isLoading = false;
      });
      AnalyticsService.instance.userProfileViewed(widget.userId);
    } catch (e) {
      debugPrint('UserProfileScreen load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) {
        await SupabaseService.instance.unfollowUser(widget.userId);
        AnalyticsService.instance.unfollowAction(widget.userId);
        setState(() {
          _isFollowing = false;
          _followersCount = (_followersCount - 1).clamp(0, 999999);
        });
      } else {
        await SupabaseService.instance.followUser(widget.userId);
        AnalyticsService.instance.followAction(widget.userId);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  String _formatGoal(String? g) {
    switch ((g ?? '').toUpperCase()) {
      case 'LOSE_WEIGHT': return 'Perder peso';
      case 'GAIN_MUSCLE': return 'Ganar músculo';
      case 'MAINTAIN': return 'Mantener';
      default: return '';
    }
  }

  String _formatLocation(String? l) {
    switch ((l ?? '').toUpperCase()) {
      case 'GYM': return 'Gimnasio';
      case 'HOME': return 'Casa';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _profile?['username'] as String? ?? widget.username;
    final fullName = _profile?['full_name'] as String? ?? '';
    final bio = _profile?['bio'] as String? ?? '';
    final goalLabel = _formatGoal(_profile?['fitness_goal'] as String?);
    final locationLabel = _formatLocation(_profile?['training_location'] as String?);
    final avatarUrl = _profile?['avatar_url'] as String?;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          '@$username',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Avatar
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.15),
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00BFFF),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Nombre completo
                        if (fullName.isNotEmpty)
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 4),

                        // Username
                        Text(
                          '@$username',
                          style: const TextStyle(color: Colors.black54, fontSize: 14),
                        ),

                        // Bio
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Chips de info
                        if (goalLabel.isNotEmpty || locationLabel.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              if (goalLabel.isNotEmpty) _Chip(goalLabel),
                              if (locationLabel.isNotEmpty) _Chip(locationLabel),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Estadísticas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(label: 'Publicaciones', value: '${_posts.length}'),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                    userId: widget.userId,
                                    isOwner: false,
                                    mode: FollowMode.followers,
                                  ),
                                ),
                              ),
                              child: _Stat(label: 'Seguidores', value: '$_followersCount'),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                    userId: widget.userId,
                                    isOwner: false,
                                    mode: FollowMode.following,
                                  ),
                                ),
                              ),
                              child: _Stat(label: 'Seguidos', value: '$_followingCount'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Botón Seguir / Siguiendo
                        SizedBox(
                          width: double.infinity,
                          child: _followLoading
                              ? const Center(child: CircularProgressIndicator())
                              : AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _isFollowing ? Colors.transparent : const Color(0xFF00BFFF),
                                    border: Border.all(
                                      color: _isFollowing ? Colors.grey.shade400 : const Color(0xFF00BFFF),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextButton(
                                    onPressed: _toggleFollow,
                                    child: Text(
                                      _isFollowing ? 'Siguiendo' : 'Seguir',
                                      style: TextStyle(
                                        color: _isFollowing ? Colors.black54 : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        MedalPreviewSection(
                          userId: widget.userId,
                          isOwner: false,
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),

                // Grilla de posts
                SliverToBoxAdapter(
                  child: _posts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'Sin publicaciones aún',
                              style: TextStyle(color: Colors.black38),
                            ),
                          ),
                        )
                      : PostGrid(
                          posts: _posts,
                          isOwner: false,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                        ),
                ),
              ],
            ),
          ),
    );
  }

}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }
}
