// lib/conversations_page.dart
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

  // seleção local (apenas para layout amplo)
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
        .orderBy('updatedAt', descending: true)
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
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Nenhuma conversa ainda. Inicie uma com um profissional ou academia.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              ),
            );
          }

          // preselect first on wide layout
          if (isWide && _selectedConversationId == null && docs.isNotEmpty) {
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
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ChatPanel(
                        participantId: _selectedOtherUserId!,
                        participantName: _selectedProfile!['nome'] ?? 'Contato',
                        participantPhotoUrl: _selectedProfile!['fotoUrl'] ?? _selectedProfile!['photoUrl'],
                        showHeader: true,
                        onClose: () {
                          setState(() {
                            _selectedConversationId = null;
                            _selectedOtherUserId = null;
                            _selectedProfile = null;
                          });
                        },
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 72, color: Colors.red.shade200),
                      const SizedBox(height: 12),
                      Text('Selecione uma conversa', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Escolha um contato à esquerda para abrir o chat.', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
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
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final users = (doc['users'] as List).map((e) => e.toString()).toList();
        final otherId = users.firstWhere((id) => id != _me);
        final last = doc['lastMessage'] as String? ?? '';
        final updated = doc['updatedAt'] as Timestamp?;
        final isSelected = highlightSelection && doc.id == _selectedConversationId;
        final unreadList =
            (doc.data()['unreadBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        final hasUnread = unreadList.contains(_me);

        return FutureBuilder<Map<String, dynamic>>(
          future: _chatService.fetchProfile(otherId),
          builder: (context, snap) {
            final profile = snap.data;
            final title = profile?['nome'] ?? profile?['displayName'] ?? 'Contato';
            final photo = profile?['fotoUrl'] ?? profile?['photoUrl'];
            return ListTile(
              dense: true,
              selected: isSelected,
              selectedTileColor: Colors.red.shade50,
              leading: CircleAvatar(
                backgroundImage: (photo != null && photo.toString().isNotEmpty) ? NetworkImage(photo) : null,
                backgroundColor: Colors.red.shade100,
                child: (photo == null) ? const Icon(Icons.person, color: Colors.red) : null,
              ),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(last.isEmpty ? 'Conversa iniciada' : last, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(updated),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (hasUnread)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              onTap: () async {
                if (highlightSelection) {
                  final prof = await _chatService.fetchProfile(otherId);
                  setState(() {
                    _selectedConversationId = doc.id;
                    _selectedOtherUserId = otherId;
                    _selectedProfile = prof;
                  });
                  await _chatService.markConversationRead(doc.id);
                  return;
                }
                // narrow: open full ChatPage
                final prof = await _chatService.fetchProfile(otherId);
                await _chatService.markConversationRead(doc.id);
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) {
                  return ChatPage(
                    otherUserId: otherId,
                    otherUserName: prof['nome'] ?? 'Contato',
                    otherUserPhotoUrl: prof['fotoUrl'] ?? prof['photoUrl'],
                  );
                }));
              },
            );
          },
        );
      },
    );
  }

  Future<void> _preselect(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final users = (doc['users'] as List).map((e) => e.toString()).toList();
    final otherId = users.firstWhere((id) => id != _me);
    final prof = await _chatService.fetchProfile(otherId);
    if (!mounted) return;
    setState(() {
      _selectedConversationId = doc.id;
      _selectedOtherUserId = otherId;
      _selectedProfile = prof;
    });
    await _chatService.markConversationRead(doc.id);
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } else {
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    }
  }
}
