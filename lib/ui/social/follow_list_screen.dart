import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../search/user_profile_screen.dart';

enum FollowMode { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool isOwner;
  final FollowMode mode;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.isOwner,
    required this.mode,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  String get _title {
    if (widget.mode == FollowMode.followers) {
      return widget.isOwner ? 'GymFriends' : 'Seguidores';
    } else {
      return widget.isOwner ? 'Siguiendo' : 'Seguidos';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = widget.mode == FollowMode.followers
          ? await SupabaseService.instance.getFollowers(widget.userId)
          : await SupabaseService.instance.getFollowing(widget.userId);
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('FollowListScreen load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProfile(Map<String, dynamic> profile) {
    final profileId = profile['id'] as String;
    final currentId = SupabaseService.instance.currentUserId;

    if (profileId == currentId) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: profileId,
          username: profile['username'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          _title,
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
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        'Nadie aquí todavía',
                        style: TextStyle(color: Colors.black38, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _UserTile(
                    profile: _users[i],
                    onTap: () => _openProfile(_users[i]),
                  ),
                ),
    );
  }
}

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

  final String? _currentUserId = SupabaseService.instance.currentUserId;

  bool get _isMe =>
      (widget.profile['id'] as String?) == _currentUserId;

  @override
  void initState() {
    super.initState();
    if (!_isMe) {
      _checkFollow();
    } else {
      setState(() => _loadingFollow = false);
    }
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
    final avatarUrl = widget.profile['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return InkWell(
      onTap: _isMe ? null : widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.15),
              backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (fullName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        fullName,
                        style: const TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            if (!_isMe)
              _loadingFollow
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00BFFF)),
                    )
                  : _FollowButton(
                      isFollowing: _isFollowing,
                      onTap: _toggleFollow,
                    ),
          ],
        ),
      ),
    );
  }
}

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
            color: isFollowing ? Colors.black26 : const Color(0xFF00BFFF),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? 'Siguiendo' : 'Seguir',
          style: TextStyle(
            color: isFollowing ? Colors.black54 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
