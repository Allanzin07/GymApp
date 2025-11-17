// lib/chat_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';

/// ChatPage é uma tela completa que pode ser usada isoladamente (mobile)
/// ou como container que usa ChatPanel (quando você quiser embutir).
class ChatPage extends StatelessWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Em mobile/pequenas larguras, ChatPage abre em tela inteira.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (otherUserPhotoUrl != null && otherUserPhotoUrl!.isNotEmpty)
                  ? NetworkImage(otherUserPhotoUrl!)
                  : null,
              backgroundColor: Colors.white24,
              child: (otherUserPhotoUrl == null || otherUserPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                otherUserName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ChatPanel(
        participantId: otherUserId,
        participantName: otherUserName,
        participantPhotoUrl: otherUserPhotoUrl,
        showHeader: false,
      ),
    );
  }
}

/// ChatPanel contém a lógica/UI principal do chat: mensagens (stream), composer e scroll.
/// Projetado para ser embutido (e também usado dentro de ChatPage).
class ChatPanel extends StatefulWidget {
  final String participantId;
  final String participantName;
  final String? participantPhotoUrl;
  final bool showHeader;
  final VoidCallback? onClose;

  const ChatPanel({
    super.key,
    required this.participantId,
    required this.participantName,
    this.participantPhotoUrl,
    this.showHeader = true,
    this.onClose,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _conversationId;
  bool _isCreating = false;

  String? get _me => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _prepareConversation();
  }

  Future<void> _prepareConversation() async {
    if (_me == null) return;
    setState(() => _isCreating = true);
    final id = await _chatService.getOrCreateConversation(widget.participantId);
    if (mounted) {
      setState(() {
        _conversationId = id;
        _isCreating = false;
      });
      if (id != null) {
        await _chatService.markConversationRead(id);
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null || _me == null) return;

    final message = {
      'senderId': _me,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    };

    try {
      await _chatService.sendMessage(_conversationId!, message);
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    if (!widget.showHeader) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.red,
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: (widget.participantPhotoUrl != null && widget.participantPhotoUrl!.isNotEmpty)
                ? NetworkImage(widget.participantPhotoUrl!)
                : null,
            child: (widget.participantPhotoUrl == null || widget.participantPhotoUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.participantName,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Faça login para acessar mensagens.', style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }

    if (_conversationId == null) {
      return Center(
        child: _isCreating ? const CircularProgressIndicator() : const SizedBox.shrink(),
      );
    }

    final messagesRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(_conversationId!)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: messagesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (_conversationId != null) {
                _chatService.markConversationRead(_conversationId!);
              }
              if (docs.isEmpty) {
                return Center(
                  child: Text('Nenhuma mensagem ainda. Comece a conversa!', style: Theme.of(context).textTheme.bodyMedium),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final senderId = data['senderId'] as String?;
                  final isMine = senderId == _me;
                  final text = data['text'] as String? ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  return _MessageBubble(
                    isMine: isMine,
                    text: text,
                    timestamp: timestamp,
                    showAvatar: !isMine,
                    avatarUrl: isMine ? null : widget.participantPhotoUrl,
                  );
                },
              );
            },
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Digite sua mensagem...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.red,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bubble widget (simples e responsivo)
class _MessageBubble extends StatelessWidget {
  final bool isMine;
  final String text;
  final Timestamp? timestamp;
  final bool showAvatar;
  final String? avatarUrl;

  const _MessageBubble({
    required this.isMine,
    required this.text,
    required this.timestamp,
    required this.showAvatar,
    this.avatarUrl,
  });

  String get _time {
    final d = timestamp?.toDate();
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? Colors.red : Colors.grey.shade200;
    final textColor = isMine ? Colors.white : Colors.black87;
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty) ? const Icon(Icons.person, size: 16) : null,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 6),
                      bottomRight: Radius.circular(isMine ? 6 : 16),
                    ),
                  ),
                  child: Text(text, style: TextStyle(color: textColor)),
                ),
                if (_time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_time, style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 12),
        ],
      ),
    );
  }
}
