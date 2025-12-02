import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_widgets.dart';
import 'notifications_service.dart';

class WorkoutEditPage extends StatefulWidget {
  final String workoutId;
  final Map<String, dynamic> workoutData;

  const WorkoutEditPage({
    super.key,
    required this.workoutId,
    required this.workoutData,
  });

  @override
  State<WorkoutEditPage> createState() => _WorkoutEditPageState();
}

class _WorkoutEditPageState extends State<WorkoutEditPage> {
  late TextEditingController _titleController;
  bool _isEditing = false;
  bool _isSaving = false;

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

  late Map<String, List<Map<String, dynamic>>> weeklyPlan;
  late Map<String, List<Map<String, dynamic>>> musclePlan;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.workoutData['title'] as String? ?? '');
    
    // Adiciona listener para detectar mudanças no título
    _titleController.addListener(() {
      if (mounted) {
        setState(() => _isEditing = true);
      }
    });
    
    // Inicializa os planos com os dados existentes ou vazios
    final weeklyPlanData = widget.workoutData['weeklyPlan'] as Map<String, dynamic>? ?? {};
    final musclePlanData = widget.workoutData['musclePlan'] as Map<String, dynamic>? ?? {};

    weeklyPlan = {};
    for (var day in daysOfWeek) {
      final exercises = weeklyPlanData[day] as List<dynamic>? ?? [];
      weeklyPlan[day] = exercises.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    musclePlan = {};
    for (var muscle in muscleGroups) {
      final exercises = musclePlanData[muscle] as List<dynamic>? ?? [];
      musclePlan[muscle] = exercises.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
                _isEditing = true;
              });

              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void removeExercise(String category, int index, bool isWeekly) {
    setState(() {
      if (isWeekly) {
        weeklyPlan[category]!.removeAt(index);
      } else {
        musclePlan[category]!.removeAt(index);
      }
      _isEditing = true;
    });
  }

  Future<void> saveWorkout() async {
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

    setState(() => _isSaving = true);

    try {
      await _firestore.collection("treinos").doc(widget.workoutId).update({
        "title": _titleController.text.trim(),
        "weeklyPlan": weeklyPlan,
        "musclePlan": musclePlan,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Treino atualizado com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar treino: $e")),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showAssignWorkoutDialog() async {
    final _firestore = FirebaseFirestore.instance;
    final profissionalId = FirebaseAuth.instance.currentUser?.uid;
    
    if (profissionalId == null) return;
    
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
                      await _assignWorkoutToClients(selectedClients.toList());
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

  Future<void> _assignWorkoutToClients(List<String> clientIds) async {
    final _firestore = FirebaseFirestore.instance;
    final profissionalId = FirebaseAuth.instance.currentUser?.uid;
    
    if (profissionalId == null) return;
    
    try {
      final workoutTitle = _titleController.text.trim().isNotEmpty 
          ? _titleController.text.trim() 
          : widget.workoutData['title'] as String? ?? 'Treino';

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
            .where('workoutId', isEqualTo: widget.workoutId)
            .where('clienteId', isEqualTo: clientId)
            .limit(1)
            .get();
        
        if (existing.docs.isEmpty) {
          // Valida que todos os campos estão preenchidos antes de criar
          if (widget.workoutId.isEmpty || clientId.isEmpty || profissionalId.isEmpty) {
            debugPrint('Erro: Campos vazios - workoutId: ${widget.workoutId}, clientId: $clientId, profissionalId: $profissionalId');
            continue;
          }
          
          await _firestore.collection('treinos_atribuidos').add({
            'workoutId': widget.workoutId,
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
                'workoutId': widget.workoutId,
                'workoutTitle': workoutTitle,
              },
            );
          } catch (e) {
            debugPrint('Erro ao criar notificação de treino: $e');
          }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visualizar/Editar Treino"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_isEditing)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Salvar alterações',
              onPressed: _isSaving ? null : () => saveWorkout(),
            ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Atribuir a cliente',
            onPressed: _showAssignWorkoutDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomRadiusTextfield(
            controller: _titleController,
            hintText: "Nome do treino (Ex: Treino frequência A/B)",
          ),
          const SizedBox(height: 20),

          // Dias da semana
          const Text(
            "Treino por dia da semana",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          ...daysOfWeek.map((day) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(day),
                children: [
                  ...weeklyPlan[day]!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ex = entry.value;
                    return ListTile(
                      title: Text(ex["name"] ?? "Exercício"),
                      subtitle: Text("${ex["series"] ?? "N/A"} séries x ${ex["reps"] ?? "N/A"} reps"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => removeExercise(day, index, true),
                      ),
                    );
                  }),
                  CustomRadiusButton(
                    onPressed: () => addExerciseDialog(day, true),
                    text: "Adicionar exercício",
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          const Text(
            "Treino por grupo muscular",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          ...muscleGroups.map((muscle) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(muscle),
                children: [
                  ...musclePlan[muscle]!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ex = entry.value;
                    return ListTile(
                      title: Text(ex["name"] ?? "Exercício"),
                      subtitle: Text("${ex["series"] ?? "N/A"} séries x ${ex["reps"] ?? "N/A"} reps"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => removeExercise(muscle, index, false),
                      ),
                    );
                  }),
                  CustomRadiusButton(
                    onPressed: () => addExerciseDialog(muscle, false),
                    text: "Adicionar exercício",
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }),

          if (_isEditing) ...[
            const SizedBox(height: 20),
            CustomRadiusButton(
              onPressed: _isSaving ? () {} : () => saveWorkout(),
              text: _isSaving ? "Salvando..." : "Salvar Alterações",
              backgroundColor: Colors.green,
            ),
          ],
        ],
      ),
    );
  }
}

