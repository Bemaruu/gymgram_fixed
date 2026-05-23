import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../search/user_profile_screen.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final ScrollController _scroll = ScrollController();
  final List<Message> _messages = [];
  RealtimeChannel? _channel;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _isBlockedByMe = false;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = Supabase.instance.client.auth.currentUser?.id;
    _scroll.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    _isBlockedByMe = await ChatService.instance.isBlocked(widget.otherUserId);
    await _loadInitial();
    _subscribe();
    await ChatService.instance.markChatRead(widget.chatId);
  }

  Future<void> _loadInitial() async {
    try {
      final list = await ChatService.instance.loadMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= ChatService.messagesPageSize;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('loadMessages error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _messages.last.createdAt;
      final more = await ChatService.instance.loadMessages(
        widget.chatId,
        before: oldest,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(more);
        _hasMore = more.length >= ChatService.messagesPageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _subscribe() {
    _channel = ChatService.instance.subscribeToChat(
      widget.chatId,
      onInsert: (msg) {
        if (!mounted) return;
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() => _messages.insert(0, msg));
        if (msg.receiverId == _myUid) {
          ChatService.instance.markChatRead(widget.chatId);
        }
      },
    );
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _handleSend(String text) async {
    // Optimistic insert: el mensaje del usuario aparece de inmediato.
    final myUid = _myUid;
    Message? optimistic;
    if (myUid != null) {
      optimistic = Message(
        id: '__optimistic__${DateTime.now().microsecondsSinceEpoch}',
        chatId: widget.chatId,
        senderId: myUid,
        receiverId: widget.otherUserId,
        text: text,
        status: MessageStatus.sent,
        readAt: null,
        isDeleted: false,
        createdAt: DateTime.now(),
      );
      setState(() => _messages.insert(0, optimistic!));
    }
    try {
      await ChatService.instance.sendMessage(widget.chatId, text);
      // Reload after send: trae la versión real (con id real) y reemplaza el
      // optimista. Realtime tambien empuja al receptor sin tocar al sender.
      final list = await ChatService.instance.loadMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= ChatService.messagesPageSize;
      });
    } catch (e) {
      // Rollback del optimista
      if (optimistic != null && mounted) {
        setState(() => _messages.removeWhere((m) => m.id == optimistic!.id));
      }
      if (kDebugMode) debugPrint('sendMessage error: $e');
      if (!mounted) return;
      final msg = e.toString();
      String show = 'No se pudo enviar';
      if (msg.contains('Rate limit')) show = 'Espera unos segundos antes de enviar más';
      if (msg.contains('Blocked'))    show = 'No puedes enviar mensajes a este usuario';
      if (msg.contains('too long'))   show = 'Mensaje demasiado largo';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(show)));
    }
  }

  Future<void> _toggleBlock() async {
    try {
      if (_isBlockedByMe) {
        await ChatService.instance.unblockUser(widget.otherUserId);
      } else {
        await ChatService.instance.blockUser(widget.otherUserId);
      }
      if (!mounted) return;
      setState(() => _isBlockedByMe = !_isBlockedByMe);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción')),
        );
      }
    }
  }

  Future<void> _reportUser() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Reportar usuario', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Cuéntanos qué pasó',
              hintStyle: TextStyle(color: Colors.white38),
              counterStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Enviar', style: TextStyle(color: Color(0xFF00BFFF))),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ChatService.instance.reportUser(
        targetUserId: widget.otherUserId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado. Gracias.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String show = 'No se pudo enviar el reporte';
      if (msg.contains('Rate limit')) show = 'Has reportado mucho. Inténtalo en una hora.';
      if (msg.contains('Reason too long')) show = 'Motivo demasiado largo';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(show)));
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    final ch = _channel;
    if (ch != null) ChatService.instance.unsubscribe(ch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.otherUsername.isNotEmpty
        ? widget.otherUsername[0].toUpperCase()
        : '?';
    final avatar = widget.otherAvatarUrl;
    final hasValidAvatar = avatar != null && avatar.startsWith('https://');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: widget.otherUserId,
                username: widget.otherUsername,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.18),
                backgroundImage: hasValidAvatar ? CachedNetworkImageProvider(avatar) : null,
                child: !hasValidAvatar
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF00BFFF),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '@${widget.otherUsername}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: const Color(0xFF1A1A1A),
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'block')  _toggleBlock();
              if (v == 'report') _reportUser();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Text(
                  _isBlockedByMe ? 'Desbloquear usuario' : 'Bloquear usuario',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Reportar usuario', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)))
                : _messages.isEmpty
                    ? const ChatEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Sin mensajes todavía',
                        subtitle: 'Rompe el hielo con un saludo o una idea de entrenamiento.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00BFFF),
                                  ),
                                ),
                              ),
                            );
                          }
                          final m = _messages[i];
                          return TweenAnimationBuilder<double>(
                            key: ValueKey('msg-${m.id}'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            builder: (context, t, child) => Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, (1 - t) * 8),
                                child: child,
                              ),
                            ),
                            child: MessageBubble(
                              message: m,
                              isMine: m.senderId == _myUid,
                            ),
                          );
                        },
                      ),
          ),
          MessageInput(
            enabled: !_isBlockedByMe,
            disabledReason: _isBlockedByMe
                ? 'Has bloqueado a este usuario. Desbloquéalo para escribir.'
                : null,
            hintUsername: widget.otherUsername,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}
