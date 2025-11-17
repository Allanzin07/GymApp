import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'editar_perfil_profissional_page.dart';
import 'post_feed_widget.dart';
import 'minha_rede_page.dart';
import 'conversations_page.dart';
import 'chat_page.dart';
import 'notifications_button.dart';

class HomeProfissionalPage extends StatefulWidget {
  final String? profissionalId;

  const HomeProfissionalPage({super.key, this.profissionalId});

  @override
  State<HomeProfissionalPage> createState() => _HomeProfissionalPageState();
}

class _HomeProfissionalPageState extends State<HomeProfissionalPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _profissionalId {
    return widget.profissionalId ?? _auth.currentUser?.uid ?? 'profissional_demo';
  }

  bool get _isOwner =>
      widget.profissionalId == null || widget.profissionalId == _auth.currentUser?.uid;

  Future<void> _connectWithProfessional() async {
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
          .where('profissionalId', isEqualTo: _profissionalId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final data = doc.data();
        final currentStatus = (data['status'] as String?) ?? 'pending';
        if (!data.containsKey('status')) {
          await doc.reference.set({'status': 'pending'}, SetOptions(merge: true));
        }
        if (!mounted) return;
        final message = currentStatus == 'active'
            ? 'Você já está conectado a este profissional.'
            : 'Aguardando aprovação deste profissional.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      await connectionsRef.add({
        'usuarioId': currentUser.uid,
        'profissionalId': _profissionalId,
        'status': 'pending',
        'isActiveForUsuario': true,
        'isActiveForProfissional': false,
        'vinculadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação registrada! Verifique sua rede.')),
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
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  elevation: 8,
                  child: ChatPanel(
                    participantId: _profissionalId,
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
            otherUserId: _profissionalId,
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
      stream: _firestore.collection('professionals').doc(_profissionalId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final nome = data['nome'] ?? 'Nome do Profissional';
        final especialidade = data['especialidade'] ?? 'Especialidade não informada';
        final descricao = data['descricao'] ?? 'Descrição ainda não cadastrada.';
        final localizacao = data['localizacao'] ?? '';
        final email = data['email'] ?? '';
        final whatsapp = data['whatsapp'] ?? '';
        final link = data['link'] ?? '';
        final fotoUrl = data['fotoUrl'] ??
            'https://cdn-icons-png.flaticon.com/512/149/149071.png';
        final capaUrl = data['capaUrl'] ??
            'https://images.unsplash.com/photo-1571019613914-85f342c55f86?w=1600&q=80&auto=format&fit=crop';

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text('Perfil Profissional'),
            backgroundColor: Colors.red,
            actions: _isOwner
                ? [
                    NotificationsButton(
                        currentUserId: FirebaseAuth.instance.currentUser?.uid),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(userType: 'Profissional'),
                          ),
                        );
                      },
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
          body: SingleChildScrollView(
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
                    // 🖼️ Foto de perfil
                    Positioned(
                      bottom: -50,
                      left: 20,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(fotoUrl),
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        especialidade,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        descricao,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (localizacao.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                localizacao,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text(email, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                      if (whatsapp.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text(whatsapp, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                      if (link.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.link, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                link,
                                style: const TextStyle(color: Colors.blue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (!_isOwner) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _connectWithProfessional,
                              icon: const Icon(Icons.link),
                              label: const Text('Conectar-se'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _openChat(
                                participantName: nome,
                                participantPhotoUrl: fotoUrl,
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Enviar Mensagem'),
                            ),
                          ],
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
                                  builder: (_) => const EditarPerfilProfissionalPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
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
                  userId: _profissionalId,
                  userName: nome,
                  userPhotoUrl: fotoUrl,
                  collectionName: 'professionals',
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
