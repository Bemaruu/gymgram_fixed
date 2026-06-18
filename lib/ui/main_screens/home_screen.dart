import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../widgets/official_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../services/analytics_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/supabase_service.dart';
import '../messaging/chat_list_screen.dart';
import '../messaging/widgets/unread_badge.dart';
import '../search/search_screen.dart';
import '../search/user_profile_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeletons/feed_post_skeleton.dart';
import '../../widgets/streak_flame.dart';
import '../social/comments_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _hasNotifications = false;
  int _unreadChats = 0;
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedIds = {};
  Set<String> _savedIds = {};

  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 30;

  RealtimeChannel? _homeChannel;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _checkUnreadNotifications();
    _loadUnreadChats();
    _subscribeRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize().catchError(
        (e) => debugPrint('NotificationService error: $e'),
      );
    });
  }

  void _subscribeRealtime() {
    final uid = SupabaseService.instance.currentUserId;
    if (uid == null) return;
    final client = SupabaseService.instance.client;

    // Un solo canal con filtros server-side (user_id) para ambas tablas:
    // reduce conexiones por usuario y el fan-out de mensajes en realtime.
    _homeChannel = client
        .channel('home-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) {
            if (mounted) setState(() => _hasNotifications = true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _loadUnreadChats(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _homeChannel?.unsubscribe();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadChats() async {
    try {
      final count = await ChatService.instance.getTotalUnread();
      if (mounted) setState(() => _unreadChats = count);
    } catch (_) {}
  }

  Future<void> _checkUnreadNotifications() async {
    try {
      final uid = SupabaseService.instance.currentUserId;
      if (uid == null) return;
      final data = await SupabaseService.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', uid)
          .isFilter('read_at', null)
          .limit(1);
      if (mounted) setState(() => _hasNotifications = (data as List).isNotEmpty);
    } catch (_) {}
  }

  Future<void> _loadPosts() async {
    if (!_isLoading) setState(() => _isLoading = true);
    try {
      final posts = await PostService.instance.getFeedPosts(limit: _pageSize);
      final postIds = posts.map((p) => p['id'] as String).toList();
      final batch = await PostService.instance.batchGetLikedAndSaved(postIds);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _likedIds = batch.likedIds;
        _savedIds = batch.savedIds;
        _hasMore = posts.length == _pageSize;
        _isLoading = false;
      });
      AnalyticsService.instance.feedViewed();
    } catch (e) {
      debugPrint('Error cargando posts: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Carga la siguiente página del feed y la agrega al final (scroll infinito).
  /// Se dispara desde el itemBuilder al acercarse al último post.
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    try {
      final more = await PostService.instance
          .getFeedPosts(limit: _pageSize, offset: _posts.length);
      final existing = _posts.map((p) => p['id']).toSet();
      final fresh =
          more.where((p) => !existing.contains(p['id'])).toList();
      if (fresh.isEmpty) {
        _hasMore = false;
        return;
      }
      final ids = fresh.map((p) => p['id'] as String).toList();
      final batch = await PostService.instance.batchGetLikedAndSaved(ids);
      if (!mounted) return;
      setState(() {
        _posts.addAll(fresh);
        _likedIds.addAll(batch.likedIds);
        _savedIds.addAll(batch.savedIds);
        _hasMore = more.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Error cargando más posts: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: FeedPostSkeletonList(count: 3),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: RefreshIndicator(
          onRefresh: _loadPosts,
          color: const Color(0xFF00BFFF),
          backgroundColor: Colors.grey[900],
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: const Center(
                  child: EmptyState(
                    icon: PhosphorIconsRegular.imageSquare,
                    title: 'Aún no hay publicaciones',
                    subtitle: 'Sé el primero en compartir tu progreso',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadPosts,
            color: const Color(0xFF00BFFF),
            backgroundColor: Colors.grey[900],
            displacement: 60,
            child: PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: PageScrollPhysics(),
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                if (index >= _posts.length - 3) _loadMore();
                final post = _posts[index];
                final id = post['id'] as String? ?? '';
                return PostWidget(
                  // Clave por id del post: sin ella, al refrescar/reordenar el
                  // feed Flutter reutiliza el State por posición y los
                  // contadores + estado de like quedan pegados del post
                  // anterior (initState no vuelve a correr).
                  key: ValueKey(id),
                  post: post,
                  initialIsLiked: _likedIds.contains(id),
                  initialIsSaved: _savedIds.contains(id),
                );
              },
            ),
          ),
          // Botón de notificaciones
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
                if (mounted) setState(() => _hasNotifications = false);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(PhosphorIconsRegular.bell, color: Colors.white, size: 22),
                    ),
                    if (_hasNotifications)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Indicador de racha (fueguito)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 60,
            child: const StreakBadge(),
          ),
          // Botón de mensajes
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 64,
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                );
                _loadUnreadChats();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(PhosphorIconsRegular.paperPlaneTilt, color: Colors.white, size: 22),
                    ),
                    if (_unreadChats > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: UnreadBadge(count: _unreadChats, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Botón de búsqueda
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PostWidget ────────────────────────────────────────────────────────────────

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool initialIsLiked;
  final bool initialIsSaved;
  const PostWidget({
    super.key,
    required this.post,
    this.initialIsLiked = false,
    this.initialIsSaved = false,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  DateTime? _viewStartTime;

  bool _isLiked = false;
  bool _isSaved = false;
  late int _likesCount;
  late int _commentsCount;

  // Guards anti spam-tap: evitan llamadas de red concurrentes que podrían
  // descuadrar el conteo (race entre like/unlike o save/unsave rápidos).
  bool _likeBusy = false;
  bool _saveBusy = false;

  late AnimationController _heartBounceCtrl;
  late Animation<double> _heartScale;

  late AnimationController _floatingHeartCtrl;
  late Animation<double> _floatingHeartOpacity;
  late Animation<double> _floatingHeartSize;

  // Lista de media (carrusel). Siempre tiene al menos 1 elemento.
  late final List<({String url, String type})> _media =
      PostService.mediaOf(widget.post);

  // Helpers de acceso al mapa
  String get _postId    => (widget.post['id']        as String?) ?? '';
  String get _mediaUrl  => _media.first.url;
  String get _mediaType => (widget.post['media_type'] as String?) ?? 'image';
  String get _caption   => (widget.post['caption']   as String?) ?? '';
  String get _userId    => (widget.post['user_id']   as String?) ?? '';

  Map<String, dynamic>? get _profile =>
      widget.post['profiles'] as Map<String, dynamic>?;
  String get _username   => (_profile?['username']  as String?) ?? '';
  String? get _avatarUrl => _profile?['avatar_url'] as String?;
  bool get _isOfficial   => _profile?['is_official'] == true;

  @override
  void initState() {
    super.initState();
    _viewStartTime = DateTime.now();
    _isLiked       = widget.initialIsLiked;
    _isSaved       = widget.initialIsSaved;
    _likesCount    = (widget.post['likes_count']    as int?) ?? 0;
    _commentsCount = (widget.post['comments_count'] as int?) ?? 0;

    _heartBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartBounceCtrl, curve: Curves.easeInOut));

    _floatingHeartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _floatingHeartOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_floatingHeartCtrl);
    _floatingHeartSize = Tween(begin: 60.0, end: 120.0)
        .animate(CurvedAnimation(parent: _floatingHeartCtrl, curve: Curves.easeOut));

    // Video
    if (_mediaType == 'video') {
      final uri = Uri.tryParse(_mediaUrl);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        _videoController = VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _videoController!.play();
            _videoController!.setLooping(true);
          });
      }
    }

  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tras un refresh del feed, el mismo post (misma key) llega con datos
    // frescos del servidor. Re-sincronizamos contadores y estado solo cuando
    // realmente cambian, para no pisar la actualización optimista en rebuilds
    // no relacionados (polls de notificaciones, etc.).
    final newLikes = (widget.post['likes_count'] as int?) ?? 0;
    final oldLikes = (oldWidget.post['likes_count'] as int?) ?? 0;
    final newComments = (widget.post['comments_count'] as int?) ?? 0;
    final oldComments = (oldWidget.post['comments_count'] as int?) ?? 0;
    if (newLikes != oldLikes ||
        newComments != oldComments ||
        widget.initialIsLiked != oldWidget.initialIsLiked ||
        widget.initialIsSaved != oldWidget.initialIsSaved) {
      setState(() {
        _likesCount = newLikes;
        _commentsCount = newComments;
        _isLiked = widget.initialIsLiked;
        _isSaved = widget.initialIsSaved;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_postId.isEmpty || _saveBusy) return;
    _saveBusy = true;
    final newSaved = !_isSaved;
    setState(() => _isSaved = newSaved);
    try {
      await PostService.instance.toggleSavePost(_postId);
    } catch (_) {
      if (mounted) setState(() => _isSaved = !newSaved);
    } finally {
      _saveBusy = false;
    }
  }

  @override
  void deactivate() {
    _videoController?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    if (_viewStartTime != null && _postId.isNotEmpty) {
      final ms = DateTime.now().difference(_viewStartTime!).inMilliseconds;
      PostService.instance.logPostView(_postId, ms);
    }
    _videoController?.dispose();
    _heartBounceCtrl.dispose();
    _floatingHeartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_postId.isEmpty || _likeBusy) return;
    _likeBusy = true;
    final newLiked = !_isLiked;
    setState(() {
      _isLiked = newLiked;
      _likesCount = (_likesCount + (newLiked ? 1 : -1)).clamp(0, 1 << 31);
    });
    _heartBounceCtrl.forward(from: 0);
    if (newLiked) {
      AnalyticsService.instance.postLiked(_postId);
    } else {
      AnalyticsService.instance.postUnliked(_postId);
    }
    try {
      await PostService.instance.toggleLike(_postId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !newLiked;
          _likesCount = (_likesCount + (newLiked ? -1 : 1)).clamp(0, 1 << 31);
        });
      }
    } finally {
      _likeBusy = false;
    }
  }

  void _onDoubleTap() {
    if (!_isLiked) _toggleLike();
    _floatingHeartCtrl.forward(from: 0);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: _postId,
        onCountChanged: (count) {
          if (mounted) setState(() => _commentsCount = count);
        },
      ),
    );
  }

  void _openUserProfile(BuildContext context) {
    if (_userId.isEmpty) return;
    if (_userId == SupabaseService.instance.currentUserId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: _userId, username: _username),
      ),
    );
  }

  Widget _buildMedia() {
    final uri = Uri.tryParse(_mediaUrl);
    final isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (_mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    // Carrusel de imágenes (más de una). Solo imágenes; el video va aparte.
    if (_media.length > 1) {
      return _FeedCarousel(media: _media);
    }

    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: _mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(PhosphorIconsRegular.imageBroken, color: Colors.white54, size: 60),
        ),
      );
    }

    if (File(_mediaUrl).existsSync()) {
      return Image.file(
        File(_mediaUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return const Center(
      child: Icon(PhosphorIconsRegular.imageBroken, color: Colors.white54, size: 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Media ──────────────────────────────────────────────────────────
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: _buildMedia(),
        ),

        // ── Gradiente inferior ─────────────────────────────────────────────
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.55, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),

        // ── Corazón flotante (double tap) ─────────────────────────────────
        Center(
          child: AnimatedBuilder(
            animation: _floatingHeartCtrl,
            builder: (_, __) => Opacity(
              opacity: _floatingHeartOpacity.value,
              child: Icon(
                PhosphorIconsFill.heart,
                color: Colors.red.shade400,
                size: _floatingHeartSize.value,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 20)],
              ),
            ),
          ),
        ),

        // ── Info inferior izquierda ────────────────────────────────────────
        Positioned(
          left: 16,
          right: 90,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openUserProfile(context),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage: (_avatarUrl?.isNotEmpty == true)
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : null,
                      child: (_avatarUrl?.isNotEmpty == true)
                          ? null
                          : Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '@$_username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    if (_isOfficial) ...[
                      const SizedBox(width: 5),
                      const OfficialBadge(size: 17),
                    ],
                  ],
                ),
              ),
              if (_caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Barra de acciones derecha ──────────────────────────────────────
        Positioned(
          right: 12,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LIKE
              _ActionButton(
                icon: AnimatedBuilder(
                  animation: _heartBounceCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _heartScale.value,
                    child: Icon(
                      _isLiked ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                      color: _isLiked ? Colors.red.shade400 : Colors.white,
                      size: 30,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
                label: _formatCount(_likesCount),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),

              // COMENTARIOS
              _ActionButton(
                icon: const Icon(
                  PhosphorIconsRegular.chatCircle,
                  color: Colors.white,
                  size: 28,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
                label: _formatCount(_commentsCount),
                onTap: _openComments,
              ),
              const SizedBox(height: 20),

              // GUARDAR
              _ActionButton(
                icon: Icon(
                  _isSaved ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple,
                  color: _isSaved ? Colors.amber : Colors.white,
                  size: 28,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
                label: '',
                onTap: _toggleSave,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}

// ── Pantalla de notificaciones ────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!_isLoading) setState(() { _isLoading = true; _error = null; });
    try {
      final client = SupabaseService.instance.client;
      final uid = SupabaseService.instance.currentUserId;
      if (uid == null) { setState(() => _isLoading = false); return; }

      // Eliminar notificaciones > 7 días
      await client.rpc('cleanup_old_notifications');

      // Cargar notificaciones con perfil del actor
      final data = await client
          .from('notifications')
          .select('id, type, post_id, read_at, created_at, actor:profiles!actor_id(id, username, avatar_url)')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      // Marcar todas como leídas
      await client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .isFilter('read_at', null);

      if (mounted) setState(() { _notifications = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error al cargar notificaciones'; _isLoading = false; });
      debugPrint('NotificationsScreen error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _notifications.isEmpty
                  ? const Center(
                      child: Text('Sin notificaciones', style: TextStyle(color: Colors.white54)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: const Color(0xFF00BFFF),
                      backgroundColor: Colors.grey[900],
                      child: ListView.separated(
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.white12, height: 1),
                        itemBuilder: (context, i) => _NotifTile(notif: _notifications[i]),
                      ),
                    ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifTile({required this.notif});

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return 'Hace 1 sem';
  }

  @override
  Widget build(BuildContext context) {
    final actor = notif['actor'] as Map<String, dynamic>?;
    final username = (actor?['username'] as String?) ?? 'alguien';
    final actorId = (actor?['id'] as String?) ?? '';
    final avatarUrl = actor?['avatar_url'] as String?;
    final type = (notif['type'] as String?) ?? '';
    final isUnread = notif['read_at'] == null;
    final createdAt = DateTime.tryParse((notif['created_at'] as String?) ?? '');

    final (IconData icon, Color iconColor, String actionText) = switch (type) {
      'like'          => (PhosphorIconsFill.heart, Colors.red, 'le dio like a tu publicación.'),
      'follow'        => (PhosphorIconsFill.userPlus, const Color(0xFF00BFFF), 'empezó a seguirte.'),
      'comment'       => (PhosphorIconsFill.chatCircle, Colors.amber, 'comentó en tu publicación.'),
      'coach_message' => (PhosphorIconsFill.barbell, const Color(0xFF00BFFF), 'Tu entrenador respondió tu entrenamiento.'),
      _               => (PhosphorIconsFill.bell, Colors.white54, 'interactuó contigo.'),
    };

    return Container(
      color: isUnread ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[850],
          backgroundImage: (avatarUrl?.isNotEmpty == true) ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: (avatarUrl?.isNotEmpty != true)
              ? Icon(icon, color: iconColor, size: 20)
              : null,
        ),
        title: RichText(
          text: TextSpan(
            children: [
              if (type != 'coach_message')
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: actorId.isNotEmpty
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: actorId, username: username),
                              ),
                            )
                        : null,
                    child: Text(
                      '@$username ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              TextSpan(
                text: actionText,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        subtitle: createdAt != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_timeAgo(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              )
            : null,
      ),
    );
  }
}

// ── Carrusel de imágenes en el feed ───────────────────────────────────────────

class _FeedCarousel extends StatefulWidget {
  final List<({String url, String type})> media;
  const _FeedCarousel({required this.media});

  @override
  State<_FeedCarousel> createState() => _FeedCarouselState();
}

class _FeedCarouselState extends State<_FeedCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.media.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final url = widget.media[i].url;
            final uri = Uri.tryParse(url);
            final isNetwork =
                uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
            if (!isNetwork) {
              return const Center(
                child: Icon(PhosphorIconsRegular.imageBroken,
                    color: Colors.white54, size: 60),
              );
            }
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(
                    color: Colors.white24, strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(PhosphorIconsRegular.imageBroken,
                    color: Colors.white54, size: 60),
              ),
            );
          },
        ),
        // Contador "1/3" arriba al centro.
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1}/${widget.media.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Puntos indicadores arriba (debajo del contador).
        Positioned(
          top: MediaQuery.of(context).padding.top + 38,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.media.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 7 : 5,
                  height: active ? 7 : 5,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 3),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Botón de acción reutilizable ──────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: icon,
          ),
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }
}

