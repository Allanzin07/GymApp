import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget de avaliações para profissionais e academias
class RatingsWidget extends StatelessWidget {
  final String targetId;
  final String targetType; // 'profissional' ou 'academia'
  final String? currentUserId;
  final VoidCallback? onRatingSubmitted; // Callback quando avaliação é enviada

  const RatingsWidget({
    super.key,
    required this.targetId,
    required this.targetType,
    this.currentUserId,
    this.onRatingSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final ratings = snapshot.data?.docs ?? [];
        double averageRating = 0.0;
        if (ratings.isNotEmpty) {
          final sum = ratings.fold<double>(
            0.0,
            (sum, doc) => sum + ((doc.data()['rating'] as num?)?.toDouble() ?? 0.0),
          );
          averageRating = sum / ratings.length;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showRatingsDialog(context, targetId, targetType, currentUserId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Avaliações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final starValue = index + 1.0;
                                return Icon(
                                  averageRating >= starValue
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${ratings.length} avaliação(ões)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRatingsDialog(
    BuildContext context,
    String targetId,
    String targetType,
    String? currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _RatingsDialog(
        targetId: targetId,
        targetType: targetType,
        currentUserId: currentUserId,
        parentContext: context, // Passa o contexto pai para exibir mensagens
        onRatingSubmitted: onRatingSubmitted, // Passa o callback
      ),
    );
  }
}

class _RatingsDialog extends StatefulWidget {
  final String targetId;
  final String targetType;
  final String? currentUserId;
  final BuildContext parentContext; // Contexto pai para exibir mensagens
  final VoidCallback? onRatingSubmitted; // Callback quando avaliação é enviada

  const _RatingsDialog({
    required this.targetId,
    required this.targetType,
    this.currentUserId,
    required this.parentContext,
    this.onRatingSubmitted,
  });

  @override
  State<_RatingsDialog> createState() => _RatingsDialogState();
}

class _RatingsDialogState extends State<_RatingsDialog> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  double? _selectedRating;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  /// Calcula e atualiza a média de avaliações no documento do target
  Future<void> _updateAverageRating(String targetId, String targetType) async {
    try {
      final _firestore = FirebaseFirestore.instance;
      
      // Busca todas as avaliações do target
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // Se não há avaliações, remove o campo de rating
        final collectionName = targetType == 'profissional' ? 'professionals' : 'academias';
        await _firestore.collection(collectionName).doc(targetId).update({
          'rating': 0.0,
          'avaliacao': 0.0,
        });
        return;
      }

      // Calcula a média
      double sum = 0.0;
      for (var doc in ratingsSnapshot.docs) {
        final ratingValue = doc.data()['rating'];
        if (ratingValue != null) {
          final rating = (ratingValue is num) 
              ? ratingValue.toDouble() 
              : (double.tryParse(ratingValue.toString()) ?? 0.0);
          sum += rating;
        }
      }

      final averageRating = sum / ratingsSnapshot.docs.length;

      // Atualiza o documento do target com a média
      final collectionName = targetType == 'profissional' ? 'professionals' : 'academias';
      await _firestore.collection(collectionName).doc(targetId).update({
        'rating': averageRating,
        'avaliacao': averageRating,
      });

      debugPrint('Média de avaliações atualizada: $averageRating para $targetType $targetId');
    } catch (e) {
      debugPrint('Erro ao atualizar média de avaliações: $e');
      // Não lança exceção para não interromper o fluxo de criação da avaliação
    }
  }

  Future<void> _submitRating() async {
    // Tenta obter a nota do slider ou do campo de texto
    double? rating = _selectedRating;
    if (rating == null && _ratingController.text.isNotEmpty) {
      rating = double.tryParse(_ratingController.text.replaceAll(',', '.'));
    }
    
    if (rating == null || rating < 0.0 || rating > 5.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma nota entre 0.0 e 5.0.')),
      );
      return;
    }
    
    // Garante que a nota está no intervalo válido
    rating = rating.clamp(0.0, 5.0);

    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para avaliar.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final _firestore = FirebaseFirestore.instance;

      // Verifica se o usuário já avaliou
      final existing = await _firestore
          .collection('ratings')
          .where('targetId', isEqualTo: widget.targetId)
          .where('targetType', isEqualTo: widget.targetType)
          .where('userId', isEqualTo: widget.currentUserId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Atualiza avaliação existente
        await existing.docs.first.reference.update({
          'rating': rating,
          'comment': _commentController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Cria nova avaliação
        await _firestore.collection('ratings').add({
          'targetId': widget.targetId,
          'targetType': widget.targetType,
          'userId': widget.currentUserId,
          'rating': rating,
          'comment': _commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Calcula e atualiza a média de avaliações no documento do target
      await _updateAverageRating(widget.targetId, widget.targetType);

      if (mounted) {
        // Limpa os campos primeiro
        _commentController.clear();
        _ratingController.clear();
        _selectedRating = null;
        setState(() {});
      }
      
      // Chama o callback para recarregar dados (se fornecido)
      if (widget.onRatingSubmitted != null) {
        widget.onRatingSubmitted!();
      }
      
      // Fecha o modal primeiro
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Aguarda um pouco para o modal fechar
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Exibe mensagem de sucesso no contexto pai (fora do modal)
      if (mounted) {
        try {
          // Tenta encontrar o ScaffoldMessenger no contexto pai
          final messenger = ScaffoldMessenger.maybeOf(widget.parentContext);
          if (messenger != null) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Avaliação enviada com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            // Fallback: tenta usar o contexto atual
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avaliação enviada com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao exibir mensagem: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao enviar avaliação: $e');
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar avaliação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Avaliações',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formulário de avaliação (se usuário logado)
                  if (widget.currentUserId != null) ...[
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('ratings')
                          .where('targetId', isEqualTo: widget.targetId)
                          .where('targetType', isEqualTo: widget.targetType)
                          .where('userId', isEqualTo: widget.currentUserId)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        Map<String, dynamic>? existingRating;
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          existingRating = snapshot.data!.docs.first.data();
                          if (_selectedRating == null && _commentController.text.isEmpty && _ratingController.text.isEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final ratingValue = existingRating?['rating'];
                              if (ratingValue != null) {
                                _selectedRating = (ratingValue is num) ? ratingValue.toDouble() : double.tryParse(ratingValue.toString());
                                _ratingController.text = _selectedRating?.toStringAsFixed(1) ?? '';
                              }
                              _commentController.text = existingRating?['comment'] ?? '';
                              setState(() {});
                            });
                          }
                        }

                        return Card(
                          color: Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingRating != null
                                      ? 'Editar sua avaliação'
                                      : 'Deixe sua avaliação',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Slider para seleção de nota (0.0 a 5.0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Nota:',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (_selectedRating ?? 0.0).toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Slider(
                                      value: _selectedRating ?? 0.0,
                                      min: 0.0,
                                      max: 5.0,
                                      divisions: 50, // Permite incrementos de 0.1
                                      label: (_selectedRating ?? 0.0).toStringAsFixed(1),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedRating = value;
                                          _ratingController.text = value.toStringAsFixed(1);
                                        });
                                      },
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '0.0',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '5.0',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Campo de texto para entrada manual
                                    TextField(
                                      controller: _ratingController,
                                      decoration: InputDecoration(
                                        labelText: 'Ou digite a nota manualmente (0.0 a 5.0)',
                                        hintText: 'Ex: 4.5, 3.2, 2.8',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        prefixIcon: const Icon(Icons.star, color: Colors.amber),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value.replaceAll(',', '.'));
                                        if (parsed != null && parsed >= 0.0 && parsed <= 5.0) {
                                          setState(() {
                                            _selectedRating = parsed;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Campo de comentário
                                TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Deixe um comentário (opcional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submitRating,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(existingRating != null
                                            ? 'Atualizar Avaliação'
                                            : 'Enviar Avaliação'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Lista de avaliações
                  const Text(
                    'Todas as avaliações',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ratings')
                        .where('targetId', isEqualTo: widget.targetId)
                        .where('targetType', isEqualTo: widget.targetType)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final ratings = snapshot.data?.docs ?? [];

                      if (ratings.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.star_border,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma avaliação ainda',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ratings.length,
                        itemBuilder: (context, index) {
                          final ratingDoc = ratings[index];
                          final ratingData = ratingDoc.data();
                          final ratingValue = ratingData['rating'];
                          final rating = (ratingValue is num) 
                              ? ratingValue.toDouble().clamp(0.0, 5.0)
                              : (double.tryParse(ratingValue?.toString() ?? '0') ?? 0.0);
                          final comment = ratingData['comment'] as String? ?? '';
                          final userId = ratingData['userId'] as String?;
                          final createdAt = ratingData['createdAt'] as Timestamp?;

                          return FutureBuilder<DocumentSnapshot>(
                            future: userId != null
                                ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get()
                                : null,
                            builder: (context, userSnapshot) {
                              String userName = 'Usuário';
                              String? userPhotoUrl;

                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                userName = userData?['nome'] ??
                                    userData?['name'] ??
                                    'Usuário';
                                userPhotoUrl = userData?['fotoPerfilUrl'] ??
                                    userData?['fotoUrl'];
                              }

                              String dateText = '';
                              if (createdAt != null) {
                                final date = createdAt.toDate();
                                dateText =
                                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundImage: userPhotoUrl != null
                                                ? NetworkImage(userPhotoUrl)
                                                : null,
                                            backgroundColor: Colors.grey.shade300,
                                            child: userPhotoUrl == null
                                                ? const Icon(Icons.person, size: 20)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dateText.isNotEmpty)
                                                  Text(
                                                    dateText,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              ...List.generate(5, (index) {
                                                final starValue = index + 1.0;
                                                return Icon(
                                                  rating >= starValue
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 18,
                                                );
                                              }),
                                              const SizedBox(width: 8),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          comment,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

