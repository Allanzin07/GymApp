import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'editar_perfil_academia_page.dart';
import 'choose_login_type_page.dart';
import 'post_feed_widget.dart';
import 'minha_rede_page.dart';
import 'conversations_page.dart';
import 'chat_page.dart';
import 'notifications_button.dart';
import 'notifications_service.dart';
import 'chat_service.dart';
import 'ratings_widget.dart';

/// Widget reutilizável para botão de conexão que verifica status e permite conectar/desconectar
class _ConnectionButton extends StatelessWidget {
  final String? currentUserId;
  final String targetId;
  final String targetType; // 'profissional' ou 'academia'
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onChat;

  const _ConnectionButton({
    required this.currentUserId,
    required this.targetId,
    required this.targetType,
    required this.onConnect,
    required this.onDisconnect,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Faça login para se conectar.')),
          );
        },
        icon: const Icon(Icons.link),
        label: const Text('Conectar-se'),
      );
    }

    final _firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('connections')
          .where('usuarioId', isEqualTo: currentUserId)
          .where(targetType == 'profissional' ? 'profissionalId' : 'academiaId',
              isEqualTo: targetId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        String? connectionStatus;

        if (docs.isNotEmpty) {
          final data = docs.first.data();
          connectionStatus = data['status'] as String? ?? 'pending';
        }

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (connectionStatus == null)
              // Não conectado - mostra botão conectar
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Conectar-se'),
              )
            else if (connectionStatus == 'active')
              // Conectado - mostra botão desconectar
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onDisconnect,
                icon: const Icon(Icons.check_circle),
                label: const Text('Conectado'),
              )
            else if (connectionStatus == 'pending')
              // Aguardando aprovação
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aguardando aprovação...'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Aguardando'),
              )
            else
              // Outro status (rejected, etc) - permite conectar novamente
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Conectar-se'),
              ),
            // Botão de chat sempre visível (permite diálogo antes de conectar)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Enviar Mensagem'),
            ),
          ],
        );
      },
    );
  }
}

class HomeAcademiaPage extends StatefulWidget {
  final String? academiaId;

  const HomeAcademiaPage({super.key, this.academiaId});

  @override
  State<HomeAcademiaPage> createState() => _HomeAcademiaPageState();
}

class _HomeAcademiaPageState extends State<HomeAcademiaPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _academiaId {
    return widget.academiaId ?? _auth.currentUser?.uid ?? 'academia_demo';
  }

  bool get _isOwner =>
      widget.academiaId == null || widget.academiaId == _auth.currentUser?.uid;

  void _showZoomableImage(BuildContext context, String imageUrl, String name) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false, // Torna a rota transparente para ver o fundo
        barrierDismissible: true, // Permite fechar ao tocar fora
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: ZoomableProfileView(
              imageUrl: imageUrl,
              name: name,
              heroTag: 'academia-profile-picture-$_academiaId', // Tag única
            ),
          );
        },
        // Efeito de fade na transição
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _connectWithAcademia() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para se conectar.')),
      );
      return;
    }

    try {
      final connectionsRef = _firestore.collection('connections');
      final existing = await connectionsRef
          .where('usuarioId', isEqualTo: currentUser.uid)
          .where('academiaId', isEqualTo: _academiaId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final data = doc.data();
        final currentStatus = (data['status'] as String?) ?? 'pending';
        if (!data.containsKey('status')) {
          await doc.reference
              .set({'status': 'pending'}, SetOptions(merge: true));
        }
        if (!mounted) return;
        final message = currentStatus == 'active'
            ? 'Você já está conectado a esta academia.'
            : 'Aguardando aprovação desta academia.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      await connectionsRef.add({
        'usuarioId': currentUser.uid,
        'academiaId': _academiaId,
        'status': 'pending',
        'isActiveForUsuario': true,
        'isActiveForAcademia': false,
        'vinculadoEm': FieldValue.serverTimestamp(),
      });

      // ✅ Cria notificação para a academia
      try {
        final notificationsService = NotificationsService();
        final chatService = ChatService();
        final userProfile = await chatService.fetchProfile(currentUser.uid);
        final userName = userProfile['nome'] as String? ??
            userProfile['name'] as String? ??
            'Usuário';

        await notificationsService.createNotification(
          senderId: currentUser.uid,
          receiverId: _academiaId,
          type: 'connection_request',
          title: '$userName te enviou uma solicitação de conexão',
          message: 'Clique para ver e responder à solicitação',
          data: {
            'connectionType': 'usuario_to_academia',
            'usuarioId': currentUser.uid,
          },
        );
      } catch (e) {
        debugPrint('Erro ao criar notificação de conexão: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitação registrada! Verifique sua rede.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MinhaRedePage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível conectar: $e')),
      );
    }
  }

  /// Desconecta da academia
  Future<void> _disconnectFromAcademia() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar'),
        content: const Text('Deseja realmente desconectar desta academia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final connectionsRef = _firestore.collection('connections');
      final existing = await connectionsRef
          .where('usuarioId', isEqualTo: currentUser.uid)
          .where('academiaId', isEqualTo: _academiaId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Desconectado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desconectar: $e')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Faz logout do Firebase Auth
        await FirebaseAuth.instance.signOut();

        // Navega para a tela de escolha de login removendo todas as rotas anteriores
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ChooseLoginTypePage()),
          (route) => false,
        );
      } catch (e) {
        // Em caso de erro, ainda tenta navegar
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ChooseLoginTypePage()),
            (route) => false,
          );
        }
      }
    }
  }

  void _openChat({
    required String participantName,
    String? participantPhotoUrl,
  }) {
    final size = MediaQuery.of(context).size;
    final isWide = kIsWeb || size.width >= 900;

    if (isWide) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            child: Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 600),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  elevation: 8,
                  child: ChatPanel(
                    participantId: _academiaId,
                    participantName: participantName,
                    participantPhotoUrl: participantPhotoUrl,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            otherUserId: _academiaId,
            otherUserName: participantName,
            otherUserPhotoUrl: participantPhotoUrl,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('academias').doc(_academiaId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final nome = data['nome'] ?? 'Nome da Academia';
        final descricao =
            data['descricao'] ?? 'Descrição da academia ainda não cadastrada.';
        final localizacao = data['localizacao'] ?? 'Localização não informada';
        final email = data['email'] ?? '';
        final whatsapp = data['whatsapp'] ?? '';
        final link = data['link'] ?? '';
        final capaUrl = data['capaUrl'] ??
            'https://images.unsplash.com/photo-1571019613914-85f342c55f86?w=1600&q=80&auto=format&fit=crop';
        final fotoPerfilUrl = data['fotoPerfilUrl'] ??
            'https://cdn-icons-png.flaticon.com/512/149/149071.png';

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text("Perfil da Academia"),
            backgroundColor: Colors.red,
            actions: _isOwner
                ? [
                    NotificationsButton(
                        currentUserId: FirebaseAuth.instance.currentUser?.uid),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Sair',
                      onPressed: () => _confirmLogout(),
                    ),
                  ]
                : null,
          ),
          drawer: _isOwner
              ? Drawer(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(color: Colors.red.shade700),
                        child: const Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            'Menu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.home, color: Colors.red),
                        title: const Text(
                          'Home',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => Navigator.pop(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.people, color: Colors.red),
                        title: const Text(
                          'Minha Rede',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MinhaRedePage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.chat, color: Colors.red),
                        title: const Text(
                          'Chat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConversationsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : null,
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: kIsWeb ? 1200 : double.infinity,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 📸 Foto de capa
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(capaUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // 🖼️ Foto de perfil (MODIFICAÇÃO AQUI)
                        Positioned(
                          bottom: -50,
                          left: 20,
                          // 1. Usar GestureDetector para detectar o toque
                          child: GestureDetector(
                            onTap: () => _showZoomableImage(
                                context, fotoPerfilUrl, nome),
                            // 2. Usar Hero para a animação de transição (zoom suave)
                            child: Hero(
                              // A tag DEVE ser única para este widget
                              tag: 'academia-profile-picture-$_academiaId',
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    Theme.of(context).cardTheme.color ??
                                        Colors.white,
                                backgroundImage: NetworkImage(fotoPerfilUrl),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    // Nome e descrição
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            descricao,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Theme.of(context)
                                      .iconTheme
                                      .color
                                      ?.withOpacity(0.7),
                                  size: 18),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  localizacao,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (email.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.email,
                                    color: Theme.of(context)
                                        .iconTheme
                                        .color
                                        ?.withOpacity(0.7),
                                    size: 18),
                                const SizedBox(width: 4),
                                Text(email,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color)),
                              ],
                            ),
                          if (whatsapp.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone,
                                    color: Theme.of(context)
                                        .iconTheme
                                        .color
                                        ?.withOpacity(0.7),
                                    size: 18),
                                const SizedBox(width: 4),
                                Text(whatsapp,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color)),
                              ],
                            ),
                          if (link.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.link,
                                    color: Theme.of(context)
                                        .iconTheme
                                        .color
                                        ?.withOpacity(0.7),
                                    size: 18),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    link,
                                    style:
                                        TextStyle(color: Colors.blue.shade300),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (!_isOwner) ...[
                            _ConnectionButton(
                              currentUserId: _auth.currentUser?.uid,
                              targetId: _academiaId,
                              targetType: 'academia',
                              onConnect: _connectWithAcademia,
                              onDisconnect: _disconnectFromAcademia,
                              onChat: () => _openChat(
                                participantName: nome,
                                participantPhotoUrl: fotoPerfilUrl,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RatingsWidget(
                              targetId: _academiaId,
                              targetType: 'academia',
                              currentUserId: _auth.currentUser?.uid,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isOwner) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EditarPerfilAcademiaPage(),
                                    ),
                                  );
                                },
                                icon:
                                    const Icon(Icons.edit, color: Colors.white),
                                label: const Text(
                                  "Editar Perfil",
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 32, thickness: 0.8),
                    // Feed de publicações
                    PostFeedWidget(
                      userId: _academiaId,
                      userName: nome,
                      userPhotoUrl: fotoPerfilUrl,
                      collectionName: 'academias',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ZoomableProfileView extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String heroTag;

  const ZoomableProfileView({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector para fechar ao tocar em qualquer lugar
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Fecha a tela de zoom
      },
      // Usamos Scaffold para garantir que o layout ocupe a tela corretamente
      child: Scaffold(
        backgroundColor:
            Colors.black.withOpacity(0.9), // Fundo escuro semi-transparente
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // O Hero deve ter a mesma tag do Hero no perfil (HomeAcademiaPage, HomeProfissionalPage, etc.)
              Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  // Tenta ocupar a maior parte da tela, mas mantendo a proporção
                  fit: BoxFit.contain,
                  height: MediaQuery.of(context).size.height * 0.8,
                  width: MediaQuery.of(context).size.width * 0.9,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 100,
                      width: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error,
                        color: Colors.white, size: 100);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration
                      .none, // Para remover qualquer sublinhado padrão de links em alguns contextos
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Toque para fechar',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
