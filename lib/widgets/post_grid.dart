import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/post_service.dart';
import '../ui/main_screens/edit_post_screen.dart';
import '../ui/social/comments_sheet.dart';

class PostGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isOwner;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final void Function(String postId)? onPostDeleted;
  final void Function(String postId, String newCaption)? onPostUpdated;

  const PostGrid({
    super.key,
    required this.posts,
    this.isOwner = false,
    this.shrinkWrap = false,
    this.physics,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay publicaciones',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final mediaUrl = post['media_url'] as String? ?? '';
        return GestureDetector(
          onTap: () => _showDetail(context, post),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              // Gradiente sutil en esquina para indicar que es tapeable
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> post) {
    final postId = post['id'] as String? ?? '';
    if (postId.isNotEmpty) AnalyticsService.instance.postDetailViewed(postId);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _PostDetailPage(
          post: post,
          isOwner: isOwner,
          onPostDeleted: onPostDeleted,
          onPostUpdated: onPostUpdated,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isOwner;
  final void Function(String postId)? onPostDeleted;
  final void Function(String postId, String newCaption)? onPostUpdated;

  const _PostDetailPage({
    required this.post,
    required this.isOwner,
    this.onPostDeleted,
    this.onPostUpdated,
  });

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage>
    with SingleTickerProviderStateMixin {
  late String _caption;
  bool _isDeleting = false;
  bool _isLiked = false;
  late int _likesCount;
  late int _commentsCount;
  double? _imageAspectRatio; // relación ancho/alto natural de la imagen

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _caption = widget.post['caption'] as String? ?? '';
    _likesCount    = (widget.post['likes_count']    as int?) ?? 0;
    _commentsCount = (widget.post['comments_count'] as int?) ?? 0;

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
    _scaleCtrl.forward();

    _loadLikeStatus();
    _loadCommentsCount();
    _loadImageAspectRatio();
  }

  Future<void> _loadCommentsCount() async {
    if (_postId.isEmpty) return;
    try {
      final comments = await PostService.instance.getComments(_postId);
      if (mounted) setState(() => _commentsCount = comments.length);
    } catch (_) {}
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

  /// Carga las dimensiones naturales de la imagen para que el panel
  /// inferior siempre tenga exactamente el mismo ancho que la foto.
  void _loadImageAspectRatio() {
    final url = _mediaUrl;
    if (url.isEmpty) return;
    final stream = CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.width / info.image.height;
          });
        }
      },
      onError: (_, __) {},
    ));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLikeStatus() async {
    final postId = widget.post['id'] as String? ?? '';
    if (postId.isEmpty) return;
    try {
      final results = await Future.wait([
        PostService.instance.hasLiked(postId),
        PostService.instance.getLikesCount(postId),
      ]);
      if (mounted) {
        setState(() {
          _isLiked = results[0] as bool;
          _likesCount = results[1] as int;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'] as String? ?? '';
    if (postId.isEmpty) return;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await PostService.instance.toggleLike(postId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  String get _postId => widget.post['id'] as String? ?? '';
  String get _mediaUrl => widget.post['media_url'] as String? ?? '';

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar publicación',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Esta acción es permanente y no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await PostService.instance.deletePost(_postId);
      AnalyticsService.instance.postDeleted(_postId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onPostDeleted?.call(_postId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _edit() async {
    Navigator.pop(context);
    final newCaption = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(
          postId: _postId,
          mediaUrl: _mediaUrl,
          initialCaption: _caption,
        ),
      ),
    );
    if (newCaption != null) {
      AnalyticsService.instance.postEdited(_postId);
      widget.onPostUpdated?.call(_postId, newCaption);
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFF00BFFF), size: 20),
                ),
                title: const Text('Editar publicación',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Cambia la descripción', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _edit();
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                ),
                title: const Text('Eliminar publicación',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.red)),
                subtitle: const Text('Esta acción no se puede deshacer',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _delete();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileData = widget.post['profiles'] as Map<String, dynamic>?;
    final username = profileData?['username'] as String? ?? '';
    final hasText = username.isNotEmpty || _caption.isNotEmpty;

    // Ancho máximo disponible para la imagen
    final double maxW = MediaQuery.of(context).size.width - 24;
    final double maxH = MediaQuery.of(context).size.height * 0.68;

    // Calcula el ancho real que ocupa el contenido de la foto (BoxFit.contain).
    // Si la imagen es más portrait que el recuadro → queda limitada por altura.
    // Si es más landscape → queda limitada por anchura.
    final double imageW = _imageAspectRatio == null
        ? maxW
        : _imageAspectRatio! < (maxW / maxH)
            ? (_imageAspectRatio! * maxH).clamp(0.0, maxW)
            : maxW;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Fondo oscuro ───────────────────────────────────────────────
              const ColoredBox(color: Colors.black87),

              // ── Imagen con animación ───────────────────────────────────────
              GestureDetector(
                onTap: () {}, // evita que el tap en la imagen cierre la pantalla
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Imagen principal — se ajusta al ancho real de la foto
                      Hero(
                        tag: _postId,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxH,
                              maxWidth: maxW,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: _mediaUrl,
                              fit: BoxFit.contain,
                              width: imageW,
                              errorWidget: (_, __, ___) => Container(
                                height: 300,
                                width: imageW,
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white38, size: 60),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Panel inferior — mismo ancho que la foto ────────────
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: imageW,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info usuario + caption
                              Expanded(
                                child: hasText
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (username.isNotEmpty)
                                            Text(
                                              '@$username',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (_caption.isNotEmpty) ...[
                                            if (username.isNotEmpty)
                                              const SizedBox(height: 4),
                                            Text(
                                              _caption,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.75),
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(width: 12),

                              // Acciones
                              Column(
                                children: [
                                  // Like
                                  GestureDetector(
                                    onTap: _toggleLike,
                                    child: Column(
                                      children: [
                                        Icon(
                                          _isLiked
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: _isLiked
                                              ? Colors.red.shade400
                                              : Colors.white60,
                                          size: 26,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_likesCount',
                                          style: const TextStyle(
                                              color: Colors.white60, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Comentarios
                                  GestureDetector(
                                    onTap: _openComments,
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Colors.white60,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_commentsCount',
                                          style: const TextStyle(
                                              color: Colors.white60, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (widget.isOwner) ...[
                                    const SizedBox(height: 14),
                                    // Menú del dueño
                                    _isDeleting
                                        ? const SizedBox(
                                            width: 26,
                                            height: 26,
                                            child: CircularProgressIndicator(
                                              color: Colors.white54,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: _showMenu,
                                            child: const Icon(
                                              Icons.more_horiz_rounded,
                                              color: Colors.white60,
                                              size: 26,
                                            ),
                                          ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Botón cerrar ───────────────────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
