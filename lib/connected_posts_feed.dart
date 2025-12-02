import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_feed_widget.dart';

/// Widget que exibe posts de profissionais/academias conectados ao usuário
class ConnectedPostsFeed extends StatelessWidget {
  final String? currentUserId;

  const ConnectedPostsFeed({super.key, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    try {
      // Verifica se o Firebase está inicializado
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null && currentUserId == null) {
        return const SizedBox.shrink();
      }

      final userId = currentUserId ?? auth.currentUser?.uid;
      
      if (userId == null || userId.isEmpty) {
        return const SizedBox.shrink();
      }

      final firestore = FirebaseFirestore.instance;

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Busca conexões ativas do usuário
        stream: firestore
            .collection('connections')
            .where('usuarioId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, connectionsSnapshot) {
          if (connectionsSnapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }

          if (connectionsSnapshot.hasError) {
            // Silenciosamente ignora erros para não travar o app
            debugPrint('Erro ao carregar conexões: ${connectionsSnapshot.error}');
            return const SizedBox.shrink();
          }

          final connections = connectionsSnapshot.data?.docs ?? [];
          
          if (connections.isEmpty) {
            return const SizedBox.shrink();
          }

        // Extrai IDs de profissionais e academias conectados
        final connectedIds = <String>[];
        for (var conn in connections) {
          final data = conn.data();
          final profissionalId = data['profissionalId'] as String?;
          final academiaId = data['academiaId'] as String?;
          if (profissionalId != null) connectedIds.add(profissionalId);
          if (academiaId != null) connectedIds.add(academiaId);
        }

        if (connectedIds.isEmpty) {
          return const SizedBox.shrink();
        }

        // Limita a 10 IDs para evitar erro do Firestore (whereIn tem limite de 10)
        final idsToQuery = connectedIds.length > 10 
            ? connectedIds.take(10).toList() 
            : connectedIds;

        // Se não houver IDs para consultar, retorna vazio
        if (idsToQuery.isEmpty) {
          return const SizedBox.shrink();
        }

        // Busca posts desses profissionais/academias
        // Nota: Firestore não permite múltiplos whereIn, então filtramos collectionName no cliente
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('posts')
              .where('userId', whereIn: idsToQuery)
              .snapshots(),
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              );
            }

            if (postsSnapshot.hasError) {
              return const SizedBox.shrink();
            }

            final allPosts = postsSnapshot.data?.docs ?? [];
            
            // Filtra apenas posts de academias e profissionais (remove outros tipos)
            final posts = allPosts.where((doc) {
              final collectionName = doc.data()['collectionName'] as String?;
              return collectionName == 'academias' || collectionName == 'professionals';
            }).toList();
            
            if (posts.isEmpty) {
              return const SizedBox.shrink();
            }

            // Ordena por data (mais recente primeiro)
            final sortedPosts = [...posts]..sort((a, b) {
              final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.dynamic_feed, color: Colors.red, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Feed de Conexões',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                ...sortedPosts.map((doc) {
                  final data = doc.data();
                  final collectionName = data['collectionName'] as String? ?? 'Desconhecido';
                  final auth = FirebaseAuth.instance;
                  final currentUser = auth.currentUser;
                  
                  // Garante que sempre usa o ID do usuário logado do Firebase Auth
                  final effectiveUserId = currentUser?.uid ?? userId;

                  // Busca nome e foto do usuário do Firestore se disponível
                  return StreamBuilder<DocumentSnapshot>(
                    stream: firestore.collection('users').doc(effectiveUserId).snapshots(),
                    builder: (context, userSnapshot) {
                      String userName = currentUser?.displayName ?? 'Usuário';
                      String userPhotoUrl = currentUser?.photoURL ?? '';
                      
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        userName = userData?['name'] as String? ?? 
                                  userData?['nome'] as String? ?? 
                                  userName;
                        userPhotoUrl = userData?['fotoUrl'] as String? ?? 
                                      userData?['fotoPerfilUrl'] as String? ?? 
                                      userPhotoUrl;
                      }

                      return Column(
                        children: [
                          PostCard(
                            key: ValueKey(doc.id),
                            docId: doc.id,
                            data: data,
                            canManage: false, // Usuários não podem gerenciar posts de outros
                            currentUserId: effectiveUserId, // Sempre usa o ID do Firebase Auth
                            currentUserName: userName,
                            currentUserPhotoUrl: userPhotoUrl,
                            isAuthenticated: currentUser != null,
                            onEdit: null,
                            onDelete: null,
                          ),
                          // Badge indicando tipo de perfil
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: collectionName == 'academias' 
                                      ? Colors.blue.shade100 
                                      : Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  collectionName == 'academias' ? 'Academia' : 'Profissional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: collectionName == 'academias' 
                                        ? Colors.blue.shade800 
                                        : Colors.purple.shade800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  );
                }),
              ],
            );
          },
        );
      },
      );
    } catch (e) {
      // Captura qualquer erro não tratado para evitar travamento
      debugPrint('Erro no ConnectedPostsFeed: $e');
      return const SizedBox.shrink();
    }
  }
}

