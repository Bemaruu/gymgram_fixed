import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/chat_service.dart';
import '../../services/recipe_service.dart';
import '../../services/routine_service.dart';
import '../../services/supabase_service.dart';
import '../messaging/chat_conversation_screen.dart';
import '../../widgets/copy_personal_week_sheet.dart';
import '../../widgets/copy_routine_bottom_sheet.dart';
import '../../widgets/medal_preview_section.dart';
import '../../widgets/personal_routine_card.dart';
import '../../widgets/post_grid.dart';
import '../../widgets/premium_rank_preview.dart';
import '../../widgets/profile_tabs_nav.dart';
import '../../widgets/routine_card.dart';
import '../recipes/widgets/recipes_grid.dart';
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

  ProfileTab _selectedTab = ProfileTab.fotos;
  List<Map<String, dynamic>> _personalRoutines = [];
  List<Map<String, dynamic>> _communityRoutines = [];
  bool _routinesLoaded = false;
  List<Map<String, dynamic>> _publicRecipes = [];
  bool _recipesLoaded = false;

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

  Future<void> _loadUserRoutines() async {
    if (_routinesLoaded) return;
    try {
      final results = await Future.wait([
        RoutineService.instance.getPersonalRoutinesByUserId(widget.userId),
        RoutineService.instance.getCommunityRoutinesByUserId(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _personalRoutines = results[0];
        _communityRoutines = results[1];
        _routinesLoaded = true;
      });
    } catch (e) {
      debugPrint('loadUserRoutines error: $e');
      if (mounted) setState(() => _routinesLoaded = true);
    }
  }

  Future<void> _loadUserRecipes() async {
    if (_recipesLoaded) return;
    try {
      final list =
          await RecipeService.instance.getPublicRecipesOf(widget.userId);
      if (!mounted) return;
      setState(() {
        _publicRecipes = list;
        _recipesLoaded = true;
      });
    } catch (e) {
      debugPrint('loadUserRecipes error: $e');
      if (mounted) setState(() => _recipesLoaded = true);
    }
  }

  void _onTabChanged(ProfileTab tab) {
    setState(() => _selectedTab = tab);
    if (tab == ProfileTab.rutinas) _loadUserRoutines();
    if (tab == ProfileTab.recetas) _loadUserRecipes();
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case ProfileTab.fotos:
        return _posts.isEmpty
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
              );
      case ProfileTab.rutinas:
        if (!_routinesLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_personalRoutines.isEmpty && _communityRoutines.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Text(
                'Este usuario aún no comparte rutinas',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        final username =
            _profile?['username'] as String? ?? widget.username;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_personalRoutines.isNotEmpty)
                PersonalRoutineCard(
                  routines: _personalRoutines,
                  isOwner: false,
                  ownerUsername: username,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CopyPersonalWeekSheet(
                        routines: _personalRoutines,
                        sourceUserId: widget.userId,
                        ownerUsername: username,
                      ),
                    );
                  },
                ),
              if (_communityRoutines.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    'Rutinas que comparte',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ..._communityRoutines.map(
                  (r) => RoutineCard(
                    routine: r,
                    isOwner: false,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CopyRoutineBottomSheet(routine: r),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      case ProfileTab.recetas:
        if (!_recipesLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_publicRecipes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Text(
                'Este usuario aun no comparte recetas',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: RecipesGrid(recipes: _publicRecipes),
        );
      case ProfileTab.rango:
        return const PremiumRankPreview();
      case ProfileTab.guardados:
        return const SizedBox.shrink();
    }
  }

  Future<void> _openChat() async {
    try {
      final chatId = await ChatService.instance.findOrCreateChat(widget.userId);
      if (!mounted) return;
      final username = _profile?['username'] as String? ?? widget.username;
      final avatarUrl = _profile?['avatar_url'] as String?;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            chatId: chatId,
            otherUserId: widget.userId,
            otherUsername: username,
            otherAvatarUrl: avatarUrl,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el chat')),
        );
      }
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
                              ? CachedNetworkImageProvider(avatarUrl)
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

                        // Botón Seguir / Siguiendo (+ Mensaje cuando sigo)
                        _followLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Row(
                                children: [
                                  Expanded(
                                    child: AnimatedContainer(
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
                                  if (_isFollowing) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BFFF),
                                          border: Border.all(color: const Color(0xFF0086B3)),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x3300BFFF),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextButton(
                                          onPressed: _openChat,
                                          child: const Text(
                                            'Mensaje',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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

                // Nav (sin Guardados en perfil ajeno) + contenido por tab
                SliverToBoxAdapter(
                  child: ProfileTabsNav(
                    selected: _selectedTab,
                    onChanged: _onTabChanged,
                    showSaved: false,
                  ),
                ),
                SliverToBoxAdapter(child: _buildTabContent()),
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
