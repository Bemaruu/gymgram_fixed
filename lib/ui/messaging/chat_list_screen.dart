import 'package:flutter/material.dart';
import '../../models/chat.dart';
import '../../services/chat_service.dart';
import '../search/search_screen.dart';
import 'chat_conversation_screen.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_list_item.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _loading = true;
  List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chats = await ChatService.instance.listChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(Chat chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: chat.id,
          otherUserId: chat.otherUserId,
          otherUsername: chat.otherUsername,
          otherAvatarUrl: chat.otherAvatarUrl,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mensajes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFFF)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF00BFFF),
              backgroundColor: const Color(0xFF1A1A1A),
              child: _chats.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.75,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: ChatEmptyState(
                                  icon: Icons.forum_outlined,
                                  title: 'Conecta con tu comunidad',
                                  subtitle: 'Escribe a alguien que sigues desde su perfil.',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SearchScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.search, color: Color(0xFF00BFFF)),
                                  label: const Text(
                                    'Buscar personas',
                                    style: TextStyle(
                                      color: Color(0xFF00BFFF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF00BFFF)),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _chats.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF1A1A1A),
                        height: 1,
                        indent: 76,
                      ),
                      itemBuilder: (_, i) => ChatListItem(
                        chat: _chats[i],
                        onTap: () => _openChat(_chats[i]),
                      ),
                    ),
            ),
    );
  }
}
