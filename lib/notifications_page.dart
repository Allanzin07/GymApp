import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'chat_page.dart';
import 'minha_rede_page.dart';
import 'workouts_assigned_page.dart';
import 'my_nutrition_page.dart';

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

    // Usa o serviço de notificações que já tem orderBy configurado
    // ou faz query sem orderBy e ordena no cliente
    final notificationsStream = _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: _currentUserId)
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
          
          debugPrint('Notificações encontradas: ${docs.length}');
          for (var doc in docs) {
            final data = doc.data();
            debugPrint('Notificação: type=${data['type']}, title=${data['title']}, receiverId=${data['receiverId']}, createdAt=${data['createdAt']}');
          }
          
          // Ordena client-side por data (mais recente primeiro)
          final sortedDocs = [...docs]..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime); // Descending
          });

          debugPrint('Notificações ordenadas: ${sortedDocs.length}');

          if (sortedDocs.isEmpty) {
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
            itemCount: sortedDocs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 0, color: Colors.red.shade50),
            itemBuilder: (context, index) {
              final data = sortedDocs[index].data();
              final type = data['type'] as String? ?? 'geral';
              final title = data['title'] as String? ?? 'Notificação';
              final message = data['message'] as String? ?? '';
              final isRead = data['isRead'] as bool? ?? false;
              final createdAt = data['createdAt'] as Timestamp?;

              return ListTile(
                tileColor: isRead ? Colors.white : Colors.red.shade50,
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: _iconForType(type),
                ),
                title: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: message.isNotEmpty ? Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ) : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTimestamp(createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                    if (!isRead) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () => _handleNotificationTap(type, data, sortedDocs[index].id),
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
      case 'workout_assigned':
        return const Icon(Icons.fitness_center, color: Colors.red);
      case 'nutrition_plan_assigned':
      case 'nutrition_plan_updated':
        return const Icon(Icons.restaurant_menu, color: Colors.orange);
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

  void _handleNotificationTap(String type, Map<String, dynamic> data, String notificationId) async {
    // Marca como lida
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
    }

    switch (type) {
      case 'message':
        // Navegar para o chat
        final senderId = data['senderId'] as String?;
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        final otherId = payload['otherUserId'] as String? ?? senderId;
        final otherName = payload['otherUserName'] as String? ?? 'Usuário';
        final otherPhoto = payload['otherUserPhoto'] as String?;
        
        if (otherId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                otherUserId: otherId,
                otherUserName: otherName,
                otherUserPhotoUrl: otherPhoto,
              ),
            ),
          );
        }
        break;
      case 'connection_request':
        // Exibir solicitações pendentes
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MinhaRedePage()),
        );
        break;
      case 'connection_accept':
        // Mostrar perfil da conexão aceita
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MinhaRedePage()),
        );
        break;
      case 'workout_assigned':
        // Fecha o dialog se estiver aberto como modal
        if (widget.asDialog) {
          Navigator.pop(context);
        }
        // Navega para a página de treinos atribuídos (Área Fitness)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkoutsAssignedPage()),
        );
        break;
      case 'nutrition_plan_assigned':
      case 'nutrition_plan_updated':
        // Fecha o dialog se estiver aberto como modal
        if (widget.asDialog) {
          Navigator.pop(context);
        }
        // Navega para a página de planos nutricionais (Minha Dieta)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyNutritionPage()),
        );
        break;
      default:
        // Apenas fechar modal
        if (widget.asDialog && kIsWeb) Navigator.pop(context);
    }
  }
}
