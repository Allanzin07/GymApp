// lib/notifications_button.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_service.dart';
import 'notifications_panel.dart';

class NotificationsButton extends StatelessWidget {
  final String? currentUserId;
  final double wideBreakpoint;

  const NotificationsButton({
    super.key,
    this.currentUserId,
    this.wideBreakpoint = 900,
  });

  String get _uid => currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    
    // Não exibe o botão se não houver usuário autenticado
    if (uid.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<int>(
      stream: uid.isNotEmpty ? NotificationsService().streamUnreadCount(uid) : Stream.value(0),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notificações',
          onPressed: () => _openPanel(context),
          icon: Stack(
            children: [
              const Icon(Icons.notifications, size: 26, color: Colors.white),
              if (unread > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : unread.toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPanel(BuildContext context) {
    // Verifica se há usuário autenticado antes de abrir o painel
    final uid = _uid;
    if (uid.isEmpty || FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para ver suas notificações.'),
        ),
      );
      return;
    }
    
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= wideBreakpoint;

    final panel = NotificationsPanel(currentUserId: uid);

    if (isWide) {
      // Modal lateral similar ao LinkedIn — aparece como Dialog at the right
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.only(left: 120, top: 60, bottom: 60, right: 24),
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 420,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: panel,
            ),
          ),
        ),
      );
    } else {
      // Mobile: abrir como tela inteira
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Notificações'), backgroundColor: Colors.red),
        body: panel,
      )));
    }
  }
}
