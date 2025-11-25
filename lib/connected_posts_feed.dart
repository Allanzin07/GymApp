import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

                  return Column(
                    children: [
                      _SimplePostCard(
                        key: ValueKey(doc.id),
                        docId: doc.id,
                        data: data,
                        currentUserId: userId,
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

/// Versão simplificada do PostCard para exibição no feed de conexões
class _SimplePostCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String? currentUserId;

  const _SimplePostCard({
    super.key,
    required this.docId,
    required this.data,
    required this.currentUserId,
  });

  @override
  State<_SimplePostCard> createState() => _SimplePostCardState();
}

class _SimplePostCardState extends State<_SimplePostCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessingLike = false;

  List<String> get _likedBy {
    final likedBy = widget.data['likedBy'];
    if (likedBy is Iterable) {
      return likedBy.map((e) => e.toString()).toList();
    }
    return const [];
  }

  int get _likesCount {
    final likedBy = _likedBy;
    if (likedBy.isNotEmpty) {
      return likedBy.length;
    }
    final likes = widget.data['likes'];
    if (likes is int) return likes;
    if (likes is num) return likes.toInt();
    return 0;
  }

  bool get _hasLiked {
    final userId = widget.currentUserId;
    if (userId == null) return false;
    return _likedBy.contains(userId);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Agora';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Agora';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Agora';
    }
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) return;
    if (_isProcessingLike) return;

    setState(() {
      _isProcessingLike = true;
    });

    try {
      final postRef = _firestore.collection('posts').doc(widget.docId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw Exception('Publicação não encontrada.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final likedBy =
            (data['likedBy'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

        if (likedBy.contains(widget.currentUserId)) {
          likedBy.remove(widget.currentUserId!);
        } else {
          likedBy.add(widget.currentUserId!);
        }

        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível atualizar a curtida: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLike = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.data['text'] ?? '';
    final mediaUrl = widget.data['mediaUrl'] as String?;
    final mediaType = widget.data['mediaType'] as String?;
    final userName = widget.data['userName'] ?? 'Usuário';
    final userPhotoUrl = widget.data['userPhotoUrl'] ?? '';
    final timestamp = widget.data['createdAt'];
    final updatedAt = widget.data['updatedAt'];
    final editedLabel = updatedAt != null ? ' • editado' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: userPhotoUrl.isNotEmpty
                  ? NetworkImage(userPhotoUrl)
                  : null,
              child: userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_formatDate(timestamp)}$editedLabel'),
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          if (mediaUrl != null) ...[
            const SizedBox(height: 8),
            if (mediaType == 'image')
              CachedNetworkImage(
                imageUrl: mediaUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.error),
                ),
              )
            else if (mediaType == 'video')
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 60),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _hasLiked ? Colors.red : null,
                  ),
                  onPressed: _isProcessingLike ? null : _toggleLike,
                  tooltip: _hasLiked ? 'Remover curtida' : 'Curtir',
                ),
                Text('$_likesCount'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
