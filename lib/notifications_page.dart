import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  final bool asDialog; // se estiver abrindo como modal lateral
  const NotificationsPage({super.key, this.asDialog = false});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentUserId == null) {
      return _buildScaffold(
        theme,
        body: const Center(child: Text('Faça login para ver suas notificações')),
      );
    }

    final notificationsStream = _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return _buildScaffold(
      theme,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar notificações.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma notificação por enquanto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 0, color: Colors.red.shade50),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = data['type'] as String? ?? 'geral';
              final message = data['message'] as String? ?? 'Notificação';
              final senderName = data['senderName'] as String? ?? 'Usuário';
              final createdAt = data['createdAt'] as Timestamp?;

              return ListTile(
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: _iconForType(type),
                ),
                title: Text(
                  senderName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                trailing: Text(
                  _formatTimestamp(createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                onTap: () => _handleNotificationTap(type, data),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScaffold(ThemeData theme, {required Widget body}) {
    if (widget.asDialog && kIsWeb) {
      // Exibir como painel lateral no web
      return Container(
        width: 400,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade600,
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Notificações',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Exibir como página normal no mobile
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red.shade600,
        title: const Text('Notificações'),
      ),
      backgroundColor: Colors.grey.shade50,
      body: body,
    );
  }

  Icon _iconForType(String type) {
    switch (type) {
      case 'message':
        return const Icon(Icons.chat, color: Colors.red);
      case 'connection_request':
        return const Icon(Icons.person_add, color: Colors.red);
      case 'connection_accept':
        return const Icon(Icons.check_circle, color: Colors.red);
      case 'update':
        return const Icon(Icons.campaign, color: Colors.red);
      default:
        return const Icon(Icons.notifications, color: Colors.red);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (DateUtils.isSameDay(date, now)) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleNotificationTap(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'message':
        // Navegar para o chat
        Navigator.pushNamed(context, '/chat', arguments: {
          'participantId': data['senderId'],
          'participantName': data['senderName'],
        });
        break;
      case 'connection_request':
        // Exibir solicitações pendentes
        Navigator.pushNamed(context, '/network');
        break;
      case 'connection_accept':
        // Mostrar perfil da conexão aceita
        Navigator.pushNamed(context, '/profile',
            arguments: {'userId': data['senderId']});
        break;
      default:
        // Apenas fechar modal
        if (widget.asDialog && kIsWeb) Navigator.pop(context);
    }
  }
}
