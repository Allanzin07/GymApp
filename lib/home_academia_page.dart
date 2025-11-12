import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'editar_perfil_academia_page.dart';
import 'login_page.dart';
import 'post_feed_widget.dart';
import 'minha_rede_page.dart';
import 'conversations_page.dart';

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
        final descricao = data['descricao'] ?? 'Descrição da academia ainda não cadastrada.';
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
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Sair',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(userType: 'Academia'),
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
                        backgroundImage: NetworkImage(fotoPerfilUrl),
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
                        descricao,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
                      if (email.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.email, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text(email, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      if (whatsapp.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text(whatsapp, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      if (link.isNotEmpty)
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
                      const SizedBox(height: 16),
                      if (_isOwner) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditarPerfilAcademiaPage(),
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
                  userId: _academiaId,
                  userName: nome,
                  userPhotoUrl: fotoPerfilUrl,
                  collectionName: 'academias',
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
