import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_widgets.dart';
import 'workouts_list_page.dart';
import 'notifications_service.dart';

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();

  final List<String> daysOfWeek = [
    "Segunda",
    "Terça",
    "Quarta",
    "Quinta",
    "Sexta",
    "Sábado",
    "Domingo"
  ];

  final List<String> muscleGroups = [
    "Peito",
    "Costas",
    "Pernas",
    "Ombros",
    "Bíceps",
    "Tríceps",
    "Abdômen",
    "Cardio"
  ];

  Map<String, List<Map<String, dynamic>>> weeklyPlan = {};
  Map<String, List<Map<String, dynamic>>> musclePlan = {};

  @override
  void initState() {
    super.initState();
    for (var d in daysOfWeek) {
      weeklyPlan[d] = [];
    }
    for (var m in muscleGroups) {
      musclePlan[m] = [];
    }
  }

  void addExerciseDialog(String category, bool isWeekly) {
    TextEditingController name = TextEditingController();
    TextEditingController reps = TextEditingController();
    TextEditingController series = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Adicionar Exercício - $category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomRadiusTextfield(controller: name, hintText: "Nome do exercício"),
            const SizedBox(height: 10),
            CustomRadiusTextfield(controller: series, hintText: "Séries (ex: 4)"),
            const SizedBox(height: 10),
            CustomRadiusTextfield(controller: reps, hintText: "Repetições (ex: 12)"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.text.isEmpty) return;

              final data = {
                "name": name.text,
                "series": series.text,
                "reps": reps.text,
              };

              setState(() {
                if (isWeekly) {
                  weeklyPlan[category]!.add(data);
                } else {
                  musclePlan[category]!.add(data);
                }
              });

              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  bool _isSaving = false;

  Future<void> saveWorkout() async {
    if (_isSaving) return; // Previne múltiplos cliques
    
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Digite um nome para o treino.")),
      );
      return;
    }

    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final profissionalId = _auth.currentUser?.uid;

    if (profissionalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro: usuário não autenticado.")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final workout = {
        "title": _titleController.text.trim(),
        "profissionalId": profissionalId,
        "createdAt": FieldValue.serverTimestamp(),
        "weeklyPlan": weeklyPlan,
        "musclePlan": musclePlan,
        "observations": _observationsController.text.trim(),
      };

      // Timeout de 15 segundos para salvar
      final docRef = await _firestore
          .collection("treinos")
          .add(workout)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Tempo limite excedido ao salvar treino');
            },
          );
      
      final workoutId = docRef.id;

      if (!mounted) return;

      // Mostra o dialog ANTES de fazer o pop (mais seguro)
      final shouldAssign = await _showAssignWorkoutDialog(workoutId, profissionalId);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shouldAssign 
            ? "Treino criado e atribuído com sucesso!" 
            : "Treino criado com sucesso!"),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Aguarda um pouco para o usuário ver a mensagem
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navega de volta após o dialog
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Erro ao salvar treino: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar treino: ${e.toString()}"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Mostra dialog para atribuir treino a clientes conectados
  /// Retorna true se atribuiu a algum cliente, false caso contrário
  Future<bool> _showAssignWorkoutDialog(String workoutId, String profissionalId) async {
    if (!mounted) return false;
    
    final _firestore = FirebaseFirestore.instance;
    
    // Busca conexões ativas do profissional com timeout reduzido
    QuerySnapshot<Map<String, dynamic>> connectionsSnapshot;
    try {
      connectionsSnapshot = await _firestore
          .collection('connections')
          .where('profissionalId', isEqualTo: profissionalId)
          .where('status', isEqualTo: 'active') // Filtra direto na query
          .limit(10) // Limita a 10 para evitar sobrecarga
          .get()
          .timeout(
            const Duration(seconds: 5), // Timeout reduzido
            onTimeout: () {
              debugPrint('Timeout ao buscar conexões');
              throw TimeoutException('Timeout ao buscar conexões', const Duration(seconds: 5));
            },
          );
    } on TimeoutException {
      debugPrint('Timeout ao buscar conexões');
      return false;
    } catch (e) {
      debugPrint('Erro ao buscar conexões: $e');
      return false;
    }

    if (connectionsSnapshot.docs.isEmpty) {
      // Não há clientes conectados
      return false;
    }

    final activeConnections = connectionsSnapshot.docs;

    // Busca dados dos clientes de forma paralela (mais eficiente)
    final List<Map<String, dynamic>> clients = [];
    
    // Busca todos os clientes em paralelo com timeout reduzido
    final futures = activeConnections.map((connDoc) async {
      final connData = connDoc.data();
      final usuarioId = connData['usuarioId'] as String?;
      if (usuarioId == null) return null;
      
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(usuarioId)
            .get()
            .timeout(
              const Duration(seconds: 2), // Timeout reduzido
              onTimeout: () {
                throw TimeoutException('Timeout', const Duration(seconds: 2));
              },
            );
        
        if (!userDoc.exists) return null;
        
        final userData = userDoc.data() ?? {};
        return {
          'id': usuarioId,
          'nome': userData['nome'] ?? userData['name'] ?? 'Cliente',
          'fotoUrl': userData['fotoPerfilUrl'] ?? userData['fotoUrl'] ?? '',
          'connectionId': connDoc.id,
        };
      } on TimeoutException {
        return null; // Pula silenciosamente
      } catch (e) {
        debugPrint('Erro ao buscar cliente $usuarioId: $e');
        return null;
      }
    }).toList();
    
    // Aguarda todas as buscas com timeout total reduzido
    try {
      final results = await Future.wait(futures, eagerError: false)
          .timeout(
            const Duration(seconds: 5), // Timeout total reduzido
            onTimeout: () {
              debugPrint('Timeout ao buscar todos os clientes');
              return List<Map<String, dynamic>?>.filled(futures.length, null);
            },
          );
      
      // Filtra resultados nulos
      for (var result in results) {
        if (result != null) {
          clients.add(result);
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar clientes: $e');
    }

    if (clients.isEmpty) {
      return false;
    }

    // Mostra dialog de seleção
    final selectedClients = <String>{};
    
    if (!mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Atribuir treino?'),
          content: SizedBox(
            width: double.maxFinite,
            child: clients.isEmpty
                ? const Text('Nenhum cliente conectado.')
                : ListView.builder(
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
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Pular'),
            ),
            ElevatedButton(
              onPressed: selectedClients.isEmpty
                  ? null
                  : () async {
                      await _assignWorkoutToClients(workoutId, selectedClients.toList());
                      if (context.mounted) {
                        Navigator.pop(context, true); // Retorna true se atribuiu
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
    
    return result ?? false; // Retorna true se atribuiu, false caso contrário
  }


  /// Atribui o treino aos clientes selecionados (versão com contexto explícito)
  Future<void> _assignWorkoutToClientsWithContext(
    BuildContext ctx,
    String workoutId,
    List<String> clientIds,
  ) async {
    final _firestore = FirebaseFirestore.instance;
    final profissionalId = FirebaseAuth.instance.currentUser?.uid;
    
    if (profissionalId == null) return;
    
    try {
      // Busca dados do treino e do profissional uma vez
      final workoutDoc = await _firestore.collection('treinos').doc(workoutId).get();
      if (!workoutDoc.exists) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
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
        // Verifica se já existe atribuição para evitar duplicatas
        final existing = await _firestore
            .collection('treinos_atribuidos')
            .where('workoutId', isEqualTo: workoutId)
            .where('clienteId', isEqualTo: clientId)
            .limit(1)
            .get();
        
        if (existing.docs.isEmpty) {
          // Valida que todos os campos estão preenchidos antes de criar
          if (workoutId.isEmpty || clientId.isEmpty || profissionalId.isEmpty) {
            debugPrint('Erro: Campos vazios - workoutId: $workoutId, clientId: $clientId, profissionalId: $profissionalId');
            continue;
          }
          
          await _firestore.collection('treinos_atribuidos').add({
            'workoutId': workoutId,
            'clienteId': clientId,
            'profissionalId': profissionalId,
            'atribuidoEm': FieldValue.serverTimestamp(),
            'status': 'ativo',
          });

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
        }
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Treino atribuído a ${clientIds.length} cliente(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Erro ao atribuir treino: $e')),
        );
      }
    }
  }

  /// Atribui o treino aos clientes selecionados (versão original para compatibilidade)
  Future<void> _assignWorkoutToClients(String workoutId, List<String> clientIds) async {
    return _assignWorkoutToClientsWithContext(context, workoutId, clientIds);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Gerenciamento de Treinos"),
          centerTitle: true,
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Criar Treino"),
              Tab(text: "Treinos Criados"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Aba 1: Criar Treino
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Campo de título
                CustomRadiusTextfield(
                  controller: _titleController,
                  hintText: "Nome do treino (Ex: Treino frequência A/B)",
                ),
                const SizedBox(height: 16),
                
                // Campo de observações
                CustomRadiusTextfield(
                  controller: _observationsController,
                  hintText: "Observações gerais (ex: Descanso de 60s entre séries, aquecimento obrigatório)",
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Seção: Treino por dia da semana
                const Text(
                  "Treino por dia da semana",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                ...daysOfWeek.map((day) {
                  final exercises = weeklyPlan[day]!;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        exercises.isEmpty 
                          ? 'Nenhum exercício adicionado'
                          : '${exercises.length} exercício(s)',
                        style: TextStyle(
                          color: exercises.isEmpty ? Colors.grey : Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        if (exercises.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "Nenhum exercício adicionado",
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...exercises.asMap().entries.map((exerciseEntry) {
                            final exerciseIndex = exerciseEntry.key;
                            final exercise = exerciseEntry.value;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade50,
                                child: Icon(Icons.fitness_center, 
                                  color: Colors.red.shade700, 
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                exercise["name"] ?? 'Exercício',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                "${exercise["series"] ?? '0'} séries x ${exercise["reps"] ?? '0'} reps",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    weeklyPlan[day]!.removeAt(exerciseIndex);
                                  });
                                },
                                tooltip: 'Remover exercício',
                              ),
                            );
                          }),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CustomRadiusButton(
                            onPressed: () => addExerciseDialog(day, true),
                            text: "➕ Adicionar exercício",
                            backgroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Seção: Treino por grupo muscular
                const Text(
                  "Treino por grupo muscular",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                ...muscleGroups.map((muscle) {
                  final exercises = musclePlan[muscle]!;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        muscle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        exercises.isEmpty 
                          ? 'Nenhum exercício adicionado'
                          : '${exercises.length} exercício(s)',
                        style: TextStyle(
                          color: exercises.isEmpty ? Colors.grey : Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        if (exercises.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "Nenhum exercício adicionado",
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...exercises.asMap().entries.map((exerciseEntry) {
                            final exerciseIndex = exerciseEntry.key;
                            final exercise = exerciseEntry.value;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade50,
                                child: Icon(Icons.fitness_center, 
                                  color: Colors.red.shade700, 
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                exercise["name"] ?? 'Exercício',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                "${exercise["series"] ?? '0'} séries x ${exercise["reps"] ?? '0'} reps",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    musclePlan[muscle]!.removeAt(exerciseIndex);
                                  });
                                },
                                tooltip: 'Remover exercício',
                              ),
                            );
                          }),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CustomRadiusButton(
                            onPressed: () => addExerciseDialog(muscle, false),
                            text: "Adicionar exercício",
                            backgroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Botão de salvar
                _isSaving
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      )
                    : CustomRadiusButton(
                        onPressed: saveWorkout,
                        text: "Salvar Treino",
                        backgroundColor: Colors.green,
                      ),
                const SizedBox(height: 16),
              ],
            ),
            // Aba 2: Treinos Criados
            const WorkoutsListPage(),
          ],
        ),
      ),
    );
  }
}

