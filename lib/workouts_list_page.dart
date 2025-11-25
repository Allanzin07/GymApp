import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_service.dart';
import 'workout_edit_page.dart';

class WorkoutsListPage extends StatefulWidget {
  const WorkoutsListPage({super.key});

  @override
  State<WorkoutsListPage> createState() => _WorkoutsListPageState();
}

class _WorkoutsListPageState extends State<WorkoutsListPage> {
  /// Mostra dialog para atribuir treino a clientes conectados
  Future<void> _showAssignWorkoutDialog(String workoutId, String profissionalId) async {
    final _firestore = FirebaseFirestore.instance;
    
    // Busca conexões do profissional
    final connectionsSnapshot = await _firestore
        .collection('connections')
        .where('profissionalId', isEqualTo: profissionalId)
        .get();

    // Filtra apenas conexões ativas
    final activeConnections = connectionsSnapshot.docs.where((doc) {
      final data = doc.data();
      return (data['status'] as String?) == 'active';
    }).toList();

    if (activeConnections.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você não tem clientes conectados ainda.')),
        );
      }
      return;
    }

    // Busca dados dos clientes
    final List<Map<String, dynamic>> clients = [];
    for (var connDoc in activeConnections) {
      final connData = connDoc.data();
      final usuarioId = connData['usuarioId'] as String?;
      if (usuarioId != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(usuarioId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            clients.add({
              'id': usuarioId,
              'nome': userData['nome'] ?? userData['name'] ?? 'Cliente',
              'fotoUrl': userData['fotoPerfilUrl'] ?? userData['fotoUrl'] ?? '',
              'connectionId': connDoc.id,
            });
          }
        } catch (e) {
          debugPrint('Erro ao buscar cliente $usuarioId: $e');
        }
      }
    }

    if (clients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum cliente encontrado.')),
        );
      }
      return;
    }

    // Mostra dialog de seleção
    final selectedClients = <String>{};
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Atribuir treino a algum cliente?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final isSelected = selectedClients.contains(client['id']);
                  
                  return CheckboxListTile(
                    title: Text(client['nome'] as String),
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedClients.add(client['id'] as String);
                        } else {
                          selectedClients.remove(client['id']);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      radius: 20,
                      backgroundImage: (client['fotoUrl'] as String).isNotEmpty
                          ? NetworkImage(client['fotoUrl'] as String)
                          : null,
                      backgroundColor: Colors.grey.shade300,
                      child: (client['fotoUrl'] as String).isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedClients.isEmpty
                  ? null
                  : () async {
                      await _assignWorkoutToClients(workoutId, selectedClients.toList());
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Exclui um treino
  Future<void> _deleteWorkout(String workoutId, String workoutTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir treino'),
        content: Text('Deseja realmente excluir o treino "$workoutTitle"?\n\nEsta ação não pode ser desfeita.'),
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final _firestore = FirebaseFirestore.instance;
    
    try {
      // Verifica se há atribuições ativas para este treino
      final assignments = await _firestore
          .collection('treinos_atribuidos')
          .where('workoutId', isEqualTo: workoutId)
          .get();

      if (assignments.docs.isNotEmpty) {
        // Pergunta se deseja excluir mesmo assim
        final confirmDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Atenção'),
            content: Text(
              'Este treino foi atribuído a ${assignments.docs.length} cliente(s).\n\n'
              'Deseja excluir mesmo assim? As atribuições também serão removidas.',
            ),
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
                child: const Text('Excluir mesmo assim'),
              ),
            ],
          ),
        );

        if (confirmDelete != true) return;

        // Remove todas as atribuições
        for (var assignment in assignments.docs) {
          await assignment.reference.delete();
        }
      }

      // Remove o treino
      await _firestore.collection('treinos').doc(workoutId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao excluir treino: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir treino: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Atribui o treino aos clientes selecionados
  Future<void> _assignWorkoutToClients(String workoutId, List<String> clientIds) async {
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final profissionalId = _auth.currentUser?.uid;
    
    if (profissionalId == null) {
      debugPrint('ERRO: Usuário não autenticado ao tentar atribuir treino');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Você precisa estar autenticado para atribuir treinos.')),
        );
      }
      return;
    }
    
    debugPrint('Atribuindo treino $workoutId para ${clientIds.length} cliente(s) pelo profissional $profissionalId');
    
    try {
      // Busca dados do treino e do profissional uma vez
      final workoutDoc = await _firestore.collection('treinos').doc(workoutId).get();
      if (!workoutDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Treino não encontrado.')),
          );
        }
        return;
      }

      final workoutData = workoutDoc.data() ?? {};
      final workoutTitle = workoutData['title'] as String? ?? 'Treino';

      // Busca nome do profissional
      String profissionalName = 'Profissional';
      try {
        final profDoc = await _firestore.collection('professionals').doc(profissionalId).get();
        if (profDoc.exists) {
          final profData = profDoc.data() ?? {};
          profissionalName = profData['nome'] as String? ?? 
                            profData['name'] as String? ?? 
                            'Profissional';
        }
      } catch (e) {
        debugPrint('Erro ao buscar nome do profissional: $e');
      }

      final notificationsService = NotificationsService();

      for (final clientId in clientIds) {
        try {
          // Verifica se já existe atribuição para evitar duplicatas
          debugPrint('Verificando duplicatas para workoutId: $workoutId, clientId: $clientId');
          final existing = await _firestore
              .collection('treinos_atribuidos')
              .where('workoutId', isEqualTo: workoutId)
              .where('clienteId', isEqualTo: clientId)
              .limit(1)
              .get();
          
          debugPrint('Query de duplicatas executada. Encontrados: ${existing.docs.length}');
          
          if (existing.docs.isEmpty) {
            // Valida que todos os campos estão preenchidos antes de criar
            if (workoutId.isEmpty || clientId.isEmpty || profissionalId.isEmpty) {
              debugPrint('Erro: Campos vazios - workoutId: $workoutId, clientId: $clientId, profissionalId: $profissionalId');
              continue;
            }
            
            debugPrint('Criando atribuição: workoutId=$workoutId, clientId=$clientId, profissionalId=$profissionalId');
            await _firestore.collection('treinos_atribuidos').add({
              'workoutId': workoutId,
              'clienteId': clientId,
              'profissionalId': profissionalId,
              'atribuidoEm': FieldValue.serverTimestamp(),
              'status': 'ativo',
            });
            debugPrint('Atribuição criada com sucesso!');

          // ✅ Cria notificação para o cliente
          try {
            await notificationsService.createNotification(
              senderId: profissionalId,
              receiverId: clientId,
              type: 'workout_assigned',
              title: '$profissionalName te enviou um treino',
              message: 'Treino: $workoutTitle',
              data: {
                'workoutId': workoutId,
                'workoutTitle': workoutTitle,
              },
            );
          } catch (e) {
            debugPrint('Erro ao criar notificação de treino: $e');
          }
          } else {
            debugPrint('Atribuição já existe, pulando...');
          }
        } catch (e) {
          debugPrint('Erro ao processar cliente $clientId: $e');
          // Continua para o próximo cliente mesmo se houver erro
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Treino atribuído a ${clientIds.length} cliente(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atribuir treino: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final profissionalId = _auth.currentUser?.uid;

    if (profissionalId == null) {
      return const Center(
        child: Text('Faça login para ver seus treinos.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Busca treinos do profissional logado
      stream: _firestore
          .collection('treinos')
          .where('profissionalId', isEqualTo: profissionalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar treinos.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detalhes: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Se não houver treinos, mostra mensagem
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum treino criado ainda.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie seu primeiro treino na aba "Criar Treino"',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        // Ordena por data de criação (mais recente primeiro)
        final sortedDocs = [...docs]..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime); // Descending
          });

        // Lista de treinos
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data();
            final title = data['title'] as String? ?? 'Treino sem título';
            final createdAt = data['createdAt'] as Timestamp?;

            String dateText = 'Data não informada';
            if (createdAt != null) {
              final date = createdAt.toDate();
              dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: const Icon(Icons.fitness_center, color: Colors.red),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Criado em: $dateText',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.red),
                      tooltip: 'Atribuir a cliente',
                      onPressed: () => _showAssignWorkoutDialog(doc.id, profissionalId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Excluir treino',
                      onPressed: () => _deleteWorkout(doc.id, title),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () {
                  // Navegar para visualizar/editar o treino
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutEditPage(
                        workoutId: doc.id,
                        workoutData: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

