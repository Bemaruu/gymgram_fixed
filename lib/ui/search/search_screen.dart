import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggested = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _loadSuggested();
  }

  Future<void> _loadSuggested() async {
    try {
      final s = await SupabaseService.instance.getSuggestedProfiles();
      if (mounted) setState(() => _suggested = s);
    } catch (_) {/* silencioso: el empty state cubre el caso */}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 380), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await SupabaseService.instance.searchProfiles(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _hasSearched = true;
      });
      AnalyticsService.instance.searchPerformed(query, results.length);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProfile(Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: profile['id'] as String,
          username: profile['username'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFF00BFFF),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre de usuario...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF00BFFF), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFFF)),
      );
    }

    if (!_hasSearched) {
      if (_suggested.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.person_search, color: Colors.white24, size: 72),
              SizedBox(height: 16),
              Text(
                'Busca personas por nombre de usuario',
                style: TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _suggested.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Sugerencias para ti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          final p = _suggested[i - 1];
          return _UserTile(profile: p, onTap: () => _openProfile(p));
        },
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sin resultados para "${_searchController.text.trim()}"',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (_, i) => _UserTile(
        profile: _results[i],
        onTap: () => _openProfile(_results[i]),
      ),
    );
  }
}

// ── Tarjeta de usuario en resultados ─────────────────────────────────────────

class _UserTile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onTap;

  const _UserTile({required this.profile, required this.onTap});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _isFollowing = false;
  bool _loadingFollow = true;

  @override
  void initState() {
    super.initState();
    _checkFollow();
  }

  Future<void> _checkFollow() async {
    try {
      final following = await SupabaseService.instance
          .isFollowing(widget.profile['id'] as String);
      if (mounted) setState(() { _isFollowing = following; _loadingFollow = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _toggleFollow() async {
    final newState = !_isFollowing;
    setState(() => _isFollowing = newState);
    try {
      if (newState) {
        await SupabaseService.instance.followUser(widget.profile['id'] as String);
      } else {
        await SupabaseService.instance.unfollowUser(widget.profile['id'] as String);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = !newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.profile['username'] as String? ?? '';
    final fullName = widget.profile['full_name'] as String? ?? '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final avatarUrl = widget.profile['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return InkWell(
      onTap: widget.onTap,
      splashColor: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.2),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFF00BFFF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fullName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        fullName,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // Botón seguir
            if (!_loadingFollow)
              _FollowButton(
                isFollowing: _isFollowing,
                onTap: _toggleFollow,
              )
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFFF)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Botón seguir / siguiendo ──────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;

  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : const Color(0xFF00BFFF),
          border: Border.all(
            color: isFollowing ? Colors.white38 : const Color(0xFF00BFFF),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? 'Siguiendo' : 'Seguir',
          style: TextStyle(
            color: isFollowing ? Colors.white54 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
