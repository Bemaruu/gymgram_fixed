import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/profile_photo_local.dart';
import '../../services/post_service.dart';
import '../../services/routine_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/copy_routine_bottom_sheet.dart';
import '../../widgets/medal_preview_section.dart';
import '../../widgets/personal_routine_card.dart';
import '../../widgets/post_grid.dart';
import '../../widgets/premium_rank_preview.dart';
import '../../widgets/profile_tabs_nav.dart';
import '../../widgets/routine_card.dart';
import '../social/follow_list_screen.dart';
import 'create_post_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String initialUsername;
  final String initialBio;
  final void Function(String? avatarUrl)? onAvatarChanged;

  const ProfileScreen({
    super.key,
    required this.initialUsername,
    required this.initialBio,
    this.onAvatarChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String username;
  late String bio;

  bool _isLoadingProfile = true;
  String? _displayName;
  String? _avatarUrl;
  double? _weight;
  double? _height;
  String? _fitnessGoal;
  String? _trainingLocation;
  List<Map<String, dynamic>> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  ProfileTab _selectedTab = ProfileTab.fotos;
  List<Map<String, dynamic>> _personalRoutines = [];
  List<Map<String, dynamic>> _communityRoutines = [];
  bool _routinesLoaded = false;
  List<Map<String, dynamic>> _savedPosts = [];
  bool _savedLoaded = false;

  @override
  void initState() {
    super.initState();
    username = widget.initialUsername;
    bio = widget.initialBio;
    AnalyticsService.instance.ownProfileViewed();
    _loadProfile();
    _loadUserPosts();
    _loadFollowCounts();
  }

  Future<void> _loadFollowCounts() async {
    final uid = SupabaseService.instance.currentUserId;
    if (uid == null) return;
    try {
      final counts = await SupabaseService.instance.getFollowCounts(uid);
      if (!mounted) return;
      setState(() {
        _followersCount = counts['followers'] ?? 0;
        _followingCount = counts['following'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final raw = await SupabaseService.instance.getRawMyProfile();
      if (!mounted) return;
      setState(() {
        if (raw != null) {
          _avatarUrl = raw['avatar_url'] as String?;
          final u = raw['username'] as String?;
          if (u != null && u.isNotEmpty) username = u;
          final dn = raw['full_name'] as String?;
          if (dn != null && dn.isNotEmpty) _displayName = dn;
          final b = raw['bio'] as String?;
          if (b != null && b.isNotEmpty) bio = b;
          final w = raw['weight'];
          _weight = w != null ? (w as num).toDouble() : null;
          final h = raw['height'];
          _height = h != null ? (h as num).toDouble() : null;
          _fitnessGoal = raw['fitness_goal'] as String?;
          _trainingLocation = raw['training_location'] as String?;
        }
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final posts = await PostService.instance.getUserPosts();
      if (!mounted) return;
      setState(() => _userPosts = posts);
    } catch (e) {
      debugPrint('Error cargando posts del perfil: $e');
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), _loadUserPosts(), _loadFollowCounts()]);
    if (_selectedTab == ProfileTab.rutinas) {
      _routinesLoaded = false;
      await _loadMyRoutines();
    } else if (_selectedTab == ProfileTab.guardados) {
      _savedLoaded = false;
      await _loadSavedPosts();
    }
  }

  Future<void> _loadMyRoutines() async {
    if (_routinesLoaded) return;
    try {
      final results = await Future.wait([
        RoutineService.instance.getMyPersonalRoutines(),
        RoutineService.instance.getMyCommunityRoutines(),
      ]);
      if (!mounted) return;
      setState(() {
        _personalRoutines = results[0];
        _communityRoutines = results[1];
        _routinesLoaded = true;
      });
    } catch (e) {
      debugPrint('loadMyRoutines error: $e');
      if (mounted) setState(() => _routinesLoaded = true);
    }
  }

  Future<void> _loadSavedPosts() async {
    if (_savedLoaded) return;
    try {
      final list = await PostService.instance.getSavedPosts();
      if (!mounted) return;
      setState(() {
        _savedPosts = list;
        _savedLoaded = true;
      });
    } catch (e) {
      debugPrint('loadSavedPosts error: $e');
      if (mounted) setState(() => _savedLoaded = true);
    }
  }

  void _onTabChanged(ProfileTab tab) {
    setState(() => _selectedTab = tab);
    if (tab == ProfileTab.rutinas) _loadMyRoutines();
    if (tab == ProfileTab.guardados) _loadSavedPosts();
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.pushNamed(
      context,
      '/edit_profile',
      arguments: {
        'username': username,
        'bio': bio,
      },
    ) as Map<String, dynamic>?;

    if (result != null) {
      final newAvatar = result['avatarUrl'] as String?;
      // Limpiar todo el cache de imágenes para que no quede ninguna foto vieja
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      setState(() {
        username = result['username'] ?? username;
        bio = result['bio'] ?? bio;
        if (newAvatar != null && newAvatar.isNotEmpty) {
          _avatarUrl = newAvatar;
        }
      });
      if (newAvatar != null && newAvatar.isNotEmpty) {
        widget.onAvatarChanged?.call(newAvatar);
      }
    }
  }

  String _formatFitnessGoal(String? goal) {
    switch (goal) {
      case 'LOSE_WEIGHT':
        return 'Perder peso';
      case 'GAIN_MUSCLE':
        return 'Ganar músculo';
      case 'MAINTAIN':
        return 'Mantener';
      default:
        return 'Sin objetivo';
    }
  }

  String _formatTrainingLocation(String? location) {
    switch (location) {
      case 'HOME':
        return 'Casa';
      case 'GYM':
        return 'Gimnasio';
      default:
        return 'Sin definir';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case ProfileTab.fotos:
        return PostGrid(
          posts: _userPosts,
          isOwner: true,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onPostDeleted: (id) => setState(
            () => _userPosts.removeWhere((p) => p['id'] == id),
          ),
          onPostUpdated: (id, newCaption) => setState(() {
            final i = _userPosts.indexWhere((p) => p['id'] == id);
            if (i != -1) {
              _userPosts[i] = {..._userPosts[i], 'caption': newCaption};
            }
          }),
        );
      case ProfileTab.rutinas:
        if (!_routinesLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PersonalRoutineCard(
                routines: _personalRoutines,
                isOwner: true,
                onTap: () =>
                    Navigator.pushNamed(context, '/rutina_screen'),
              ),
              if (_communityRoutines.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    'Rutinas que comparto',
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
                    isOwner: true,
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
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final created = await Navigator.pushNamed(
                      context, '/create-community-routine');
                  if (created == true) {
                    _routinesLoaded = false;
                    _loadMyRoutines();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF00BFFF), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: Color(0xFF00BFFF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Crear rutina para la comunidad',
                        style: TextStyle(
                          color: Color(0xFF00BFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case ProfileTab.rango:
        return const PremiumRankPreview();
      case ProfileTab.guardados:
        if (!_savedLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_savedPosts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Text(
                'Aún no has guardado publicaciones',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }
        return PostGrid(
          posts: _savedPosts,
          isOwner: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        );
    }
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayNameToShow =
        (_displayName != null && _displayName!.trim().isNotEmpty)
            ? _displayName!
            : username;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          _loadUserPosts();
        },
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: _isLoadingProfile
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                Center(
                  child: GestureDetector(
                    onLongPress: () =>
                        Navigator.pushNamed(context, '/admin/usage'),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_avatarUrl!) as ImageProvider
                          : LocalProfilePhoto.imageFile != null
                              ? FileImage(LocalProfilePhoto.imageFile!)
                              : const AssetImage('assets/images/default_profile.png'),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  displayNameToShow,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  bio.isNotEmpty ? bio : 'No definido',
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_weight != null)
                      _buildInfoChip('Peso: ${_weight!.toStringAsFixed(1)} kg'),
                    if (_height != null)
                      _buildInfoChip('Altura: ${_height!.toStringAsFixed(1)} cm'),
                    if (_fitnessGoal != null && _fitnessGoal!.isNotEmpty)
                      _buildInfoChip(_formatFitnessGoal(_fitnessGoal)),
                    if (_trainingLocation != null && _trainingLocation!.isNotEmpty)
                      _buildInfoChip(_formatTrainingLocation(_trainingLocation)),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final uid = SupabaseService.instance.currentUserId;
                        if (uid == null) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: uid,
                            isOwner: true,
                            mode: FollowMode.followers,
                          ),
                        ));
                      },
                      child: Column(
                        children: [
                          Text(
                            '$_followersCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'GymFriends',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final uid = SupabaseService.instance.currentUserId;
                        if (uid == null) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: uid,
                            isOwner: true,
                            mode: FollowMode.following,
                          ),
                        ));
                      },
                      child: Column(
                        children: [
                          Text(
                            '$_followingCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Siguiendo',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_userPosts.length}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Publicaciones',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (SupabaseService.instance.currentUserId != null)
                  MedalPreviewSection(
                    userId: SupabaseService.instance.currentUserId!,
                    isOwner: true,
                  ),

                const SizedBox(height: 12),

              ],
            ),
          ),
          SliverToBoxAdapter(
            child: ProfileTabsNav(
              selected: _selectedTab,
              onChanged: _onTabChanged,
              showSaved: true,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildTabContent(),
          ),
        ],
      ),
    ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black),
                onPressed: _navigateToEditProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}