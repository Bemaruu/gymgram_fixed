import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/ai_trainer_service.dart';
import 'ai_trainer_avatars.dart';
import 'ai_trainer_onboarding_sheet.dart';
import 'widgets/typing_indicator.dart';

class AITrainerChatScreen extends StatefulWidget {
  const AITrainerChatScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AITrainerChatScreen()),
    );
  }

  @override
  State<AITrainerChatScreen> createState() => _AITrainerChatScreenState();
}

class _AITrainerChatScreenState extends State<AITrainerChatScreen> {
  AITrainerConfig? _config;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  int _usedToday = 0;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    var config = await AITrainerService.instance.getConfig();
    if (config == null && mounted) {
      final ok = await AITrainerOnboardingSheet.show(context);
      if (ok != true) {
        if (mounted) Navigator.pop(context);
        return;
      }
      config = await AITrainerService.instance.getConfig();
    }
    final msgs = await AITrainerService.instance.getMessages();
    final used = await AITrainerService.instance.dailyMessagesUsed();
    if (!mounted) return;
    setState(() {
      _config = config;
      _messages = msgs;
      _usedToday = used;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (_usedToday >= AITrainerService.dailyMessageLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Llegaste al limite diario de mensajes.')),
      );
      return;
    }
    // Optimistic insert: el mensaje del usuario aparece de inmediato.
    final optimistic = <String, dynamic>{
      'id': '__optimistic__${DateTime.now().microsecondsSinceEpoch}',
      'role': 'user',
      'content': text,
      'message_type': 'chat',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages = [..._messages, optimistic];
      _sending = true;
      _controller.clear();
    });
    HapticFeedback.lightImpact();
    _scrollToBottom();

    final error = await AITrainerService.instance.sendMessage(text);
    final msgs = await AITrainerService.instance.getMessages();
    final used = await AITrainerService.instance.dailyMessagesUsed();
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _usedToday = used;
      _sending = false;
    });
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config ?? AITrainerConfig.defaults();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            AITrainerAvatars.circle(id: config.avatarId, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        config.trainerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Tu entrenador personal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reconfigurar',
            icon: const Icon(Icons.tune, color: Colors.white70),
            onPressed: () async {
              final ok = await AITrainerOnboardingSheet.show(context);
              if (ok == true) _bootstrap();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: (_messages.isEmpty && !_sending)
                      ? _emptyState(config)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_sending && i == _messages.length) {
                              return _typingBubble(config);
                            }
                            return _animatedBubble(_messages[i], config);
                          },
                        ),
                ),
                _composer(),
              ],
            ),
    );
  }

  Widget _emptyState(AITrainerConfig config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AITrainerAvatars.circle(id: config.avatarId, size: 72),
            const SizedBox(height: 16),
            Text(
              'Hola, soy ${config.trainerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuentame como vas con tu entrenamiento o pregunta lo que necesites. Tu coach IA esta listo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps [_bubble] with a fade+slide-up enter animation. Uses the message id
  /// as the [ValueKey] so existing bubbles do not re-animate on rebuild.
  Widget _animatedBubble(Map<String, dynamic> m, AITrainerConfig config) {
    final id = (m['id'] ?? '').toString();
    return TweenAnimationBuilder<double>(
      key: ValueKey('bubble-$id'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: _bubble(m, config),
    );
  }

  /// Bubble del coach con los 3 puntos animados mientras esperamos la respuesta.
  Widget _typingBubble(AITrainerConfig config) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey('typing'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AITrainerAvatars.circle(id: config.avatarId, size: 28),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: const TypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m, AITrainerConfig config) {
    final role = m['role'] as String? ?? 'user';
    final isMine = role == 'user';
    final type = m['message_type'] as String? ?? 'chat';
    final text = m['content'] as String? ?? '';

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            AITrainerAvatars.circle(id: config.avatarId, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMine
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF00D4FF), Color(0xFF0086B3)],
                      )
                    : null,
                color: isMine ? null : const Color(0xFF1A1A1A),
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (type == 'post_workout')
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsFill.barbell,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Post-entreno',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final blocked = _usedToday >= AITrainerService.dailyMessageLimit;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '$_usedToday/${AITrainerService.dailyMessageLimit} mensajes hoy',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !blocked,
                    style: const TextStyle(color: Colors.white),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: blocked
                          ? 'Limite diario alcanzado'
                          : 'Escribe a tu coach...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (blocked || _sending) ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
