import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/chat_service.dart';

class MessageInput extends StatefulWidget {
  final bool enabled;
  final String? disabledReason;
  final String? hintUsername;
  final Future<void> Function(String text) onSend;
  const MessageInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.disabledReason,
    this.hintUsername,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_hasText) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
      setState(() => _hasText = false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewPadding.bottom + 10,
        ),
        color: Colors.black,
        child: Text(
          widget.disabledReason ?? 'No puedes enviar mensajes aquí',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: ChatService.maxMessageLength,
                  textInputAction: TextInputAction.newline,
                  cursorColor: const Color(0xFF00BFFF),
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(ChatService.maxMessageLength),
                  ],
                  decoration: InputDecoration(
                    hintText: widget.hintUsername != null && widget.hintUsername!.isNotEmpty
                        ? 'Manda un mensaje a @${widget.hintUsername}'
                        : 'Escribe algo motivador…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hasText ? 1.0 : 0.5,
              child: Material(
                color: const Color(0xFF00BFFF),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _hasText && !_sending ? _send : null,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
