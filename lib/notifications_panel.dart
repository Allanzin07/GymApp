// lib/notifications_panel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_service.dart';

// IMPORTS para navegação — ajuste caminhos se necessário
import 'chat_page.dart';
import 'conversations_page.dart';
import 'minha_rede_page.dart';
import 'my_nutrition_page.dart';
import 'workouts_assigned_page.dart';

class NotificationsPanel extends StatefulWidget {
  final String? currentUserId;

  const NotificationsPanel({super.key, this.currentUserId});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final NotificationsService _service = NotificationsService();
  String get _uid => widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble;
      case 'connection_request':
        return Icons.person_add;
      case 'connection_accept':
        return Icons.check_circle;
      case 'workout_assigned':
        return Icons.fitness_center;
      case 'nutrition_plan_assigned':
      case 'nutrition_plan_updated':
        return Icons.restaurant_menu;
      case 'system':
      default:
        return Icons.notifications;
    }
  }

  Color _iconColor(String type) {
    return type == 'message' ? Colors.red : Colors.red.shade400;
  }

  void _handleTap(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final type = data['type'] as String? ?? 'system';
    final payload = (data['data'] as Map<String, dynamic>?) ?? {};

    // Marca como lida
    try {
      await _service.markAsRead(doc.id);
    } catch (_) {}

    // Navega conforme tipo
    if (type == 'message') {
      final otherId = payload['otherUserId'] as String? ?? payload['from'] as String?;
      final conversationId = payload['conversationId'] as String?;
      final otherName = payload['otherUserName'] as String?;
      final otherPhoto = payload['otherUserPhoto'] as String?;

      if (otherId != null) {
        // Abre ChatPage diretamente
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
          otherUserId: otherId,
          otherUserName: otherName ?? 'Contato',
          otherUserPhotoUrl: otherPhoto,
        )));
        return;
      }

      if (conversationId != null) {
        // Se não tiver otherId, abre a lista de conversas
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsPage()));
        return;
      }

      // fallback
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsPage()));
      return;
    }

    if (type == 'connection_request' || type == 'connection_accept') {
      // Abre página MinhaRede para gerenciar solicitações
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MinhaRedePage()));
      return;
    }

    if (type == 'workout_assigned') {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutsAssignedPage()),
      );
      return;
    }

    if (type == 'nutrition_plan_assigned' || type == 'nutrition_plan_updated') {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyNutritionPage()),
      );
      return;
    }

    // Outras notificações: abrir conversas por padrão
    Navigator.pop(context); // fecha modal se houver
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Faça login para ver notificações.', style: Theme.of(context).textTheme.bodyLarge),
      ));
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Cabeçalho fixo (apenas quando o widget estiver sozinho; se for usado dentro do Dialog, não estraga)
          Container(
            color: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                const SizedBox(width: 12),
                Text('Notificações', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => _service.markAllAsRead(_uid),
                  child: const Text('Marcar todas como lidas', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.streamNotificationsForUser(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }
                final docs = snapshot.data?.docs ?? [];
                
                // Ordena client-side por data (mais recente primeiro)
                final sortedDocs = [...docs]..sort((a, b) {
                  final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  return bTime.compareTo(aTime); // Descending
                });

                if (sortedDocs.isEmpty) {
                  return Center(child: Text('Sem notificações', style: TextStyle(color: Colors.grey[600])));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (_, __) => Divider(height: 0, color: Colors.grey.shade200),
                  itemCount: sortedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final d = doc.data();
                    final isRead = (d['isRead'] as bool?) ?? false;
                    final type = (d['type'] as String?) ?? 'system';
                    final title = (d['title'] as String?) ?? '';
                    final body = (d['message'] as String?) ?? (d['body'] as String?) ?? ''; // Usa 'message' primeiro, fallback para 'body'
                    final created = (d['createdAt'] as Timestamp?)?.toDate();

                    return ListTile(
                      onTap: () => _handleTap(doc),
                      tileColor: isRead ? Colors.white : Colors.red.shade50,
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(_iconForType(type), color: _iconColor(type)),
                      ),
                      title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.bold)),
                      subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (created != null)
                            Text(
                              _prettyTimeAgo(created),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          const SizedBox(height: 6),
                          if (!isRead)
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _prettyTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }
}
