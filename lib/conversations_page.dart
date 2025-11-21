import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'chat_service.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  String? get _me => _auth.currentUser?.uid;

  String? _selectedConversationId;
  String? _selectedOtherUserId;
  Map<String, dynamic>? _selectedProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900 || kIsWeb;

    if (_me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mensagens'), backgroundColor: Colors.red),
        body: Center(child: Text('Faça login para acessar suas conversas.', style: theme.textTheme.bodyLarge)),
      );
    }

    final stream = _firestore
        .collection('conversations')
        .where('users', arrayContains: _me)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens'), backgroundColor: Colors.red),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            final ta = a.data().containsKey('updatedAt') ? a['updatedAt'] : a['createdAt'];
            final tb = b.data().containsKey('updatedAt') ? b['updatedAt'] : b['createdAt'];
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Timestamp).compareTo(ta as Timestamp);
          });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma conversa ainda.\nInicie uma com um profissional ou academia.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }

          if (isWide && _selectedConversationId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _preselect(docs.first);
            });
          }

          return isWide ? _wideLayout(docs) : _narrowLayout(docs);
        },
      ),
    );
  }

  Widget _wideLayout(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return Row(
      children: [
        Container(
          width: 360,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: _conversationsList(docs, highlightSelection: true),
        ),
        Expanded(
          child: _selectedConversationId != null && _selectedOtherUserId != null && _selectedProfile != null
              ? ChatPanel(
                  participantId: _selectedOtherUserId!,
                  participantName: _selectedProfile!['nome'] ?? 'Contato',
                  participantPhotoUrl: _selectedProfile!['fotoUrl'] ?? _selectedProfile!['photoUrl'],
                  showHeader: true,
                )
              : const Center(child: Text('Selecione uma conversa')),
        ),
      ],
    );
  }

  Widget _narrowLayout(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return _conversationsList(docs, highlightSelection: false);
  }

  Widget _conversationsList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {required bool highlightSelection}) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();

        final users = (data['users'] as List).map((e) => e.toString()).toList();
        final otherId = users.firstWhere((id) => id != _me);
        final last = data['lastMessage'] as String? ?? '';

        final List<String> unreadBy =
            data.containsKey('unreadBy') ? List<String>.from(data['unreadBy']) : <String>[];
        final bool hasUnread = unreadBy.contains(_me);

        final Map<String, dynamic> unreadCountMap =
            data.containsKey('unreadCount') ? Map<String, dynamic>.from(data['unreadCount']) : {};
        int unreadCount = unreadCountMap[_me] ?? 0;

        if (hasUnread && unreadCount == 0) {
          unreadCount = 1;
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _chatService.fetchProfile(otherId),
          builder: (context, snap) {
            final profile = snap.data;
            final title = profile?['nome'] ?? profile?['displayName'] ?? 'Contato';
            final photo = profile?['fotoUrl'] ?? profile?['photoUrl'];

            return Dismissible(
              key: ValueKey(doc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Excluir conversa'),
                    content: const Text('Deseja realmente excluir esta conversa?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
                    ],
                  ),
                );
              },
              onDismissed: (_) async {
                await _firestore.collection('conversations').doc(doc.id).delete();
              },
              child: ListTile(
                leading: Stack(
  children: [
    CircleAvatar(
      backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
      backgroundColor: Colors.red.shade100,
      child: photo == null ? const Icon(Icons.person, color: Colors.red) : null,
    ),
    if (unreadCount > 0)
      Positioned(
        right: -2,
        top: -2,
        child: Container(
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Text(
            unreadCount > 99 ? '99+' : unreadCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
  ],
),
                title: Text(title, style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(last.isEmpty ? 'Conversa iniciada' : last, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  await _chatService.markConversationRead(doc.id);
                  if (!mounted) return;
                  if (highlightSelection) {
                    setState(() {
                      _selectedConversationId = doc.id;
                      _selectedOtherUserId = otherId;
                      _selectedProfile = profile;
                    });
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) {
                    return ChatPage(
                      otherUserId: otherId,
                      otherUserName: title,
                      otherUserPhotoUrl: photo,
                    );
                  }));
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _preselect(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final users = (doc.data()['users'] as List).map((e) => e.toString()).toList();
    final otherId = users.firstWhere((id) => id != _me);
    final prof = await _chatService.fetchProfile(otherId);
    if (!mounted) return;
    setState(() {
      _selectedConversationId = doc.id;
      _selectedOtherUserId = otherId;
      _selectedProfile = prof;
    });
  }
}
