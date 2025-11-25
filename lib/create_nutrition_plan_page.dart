import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'custom_widgets.dart';
import 'nutrition_plans_list_page.dart';
import 'notifications_service.dart';

class CreateNutritionPlanPage extends StatefulWidget {
  final String? planId; // Se fornecido, edita um plano existente
  final Map<String, dynamic>? existingPlanData;

  const CreateNutritionPlanPage({
    super.key,
    this.planId,
    this.existingPlanData,
  });

  @override
  State<CreateNutritionPlanPage> createState() => _CreateNutritionPlanPageState();
}

class _CreateNutritionPlanPageState extends State<CreateNutritionPlanPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _objectiveController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();

  final List<String> daysOfWeek = [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
  ];

  final List<String> dayNames = [
    "Segunda-feira",
    "Terça-feira",
    "Quarta-feira",
    "Quinta-feira",
    "Sexta-feira",
    "Sábado",
    "Domingo"
  ];

  final List<String> mealTypes = [
    "breakfast",
    "morningSnack",
    "lunch",
    "afternoonSnack",
    "dinner",
    "supper"
  ];

  final List<String> mealNames = [
    "Café da manhã",
    "Lanche da manhã",
    "Almoço",
    "Lanche da tarde",
    "Jantar",
    "Ceia"
  ];

  // Estrutura: days[day][mealType] = List<Map<String, String>>
  Map<String, Map<String, List<Map<String, String>>>> days = {};

  @override
  void initState() {
    super.initState();
    
    // Inicializa estrutura vazia
    for (var day in daysOfWeek) {
      days[day] = {};
      for (var meal in mealTypes) {
        days[day]![meal] = [];
      }
    }

    // Se estiver editando, carrega dados existentes
    if (widget.existingPlanData != null) {
      _loadExistingPlan();
    }
  }

  void _loadExistingPlan() {
    final data = widget.existingPlanData!;
    _titleController.text = data['title'] ?? '';
    _objectiveController.text = data['objective'] ?? '';
    _observationsController.text = data['observations'] ?? '';
    
    if (data['days'] != null) {
      days = Map<String, Map<String, List<Map<String, String>>>>.from(
        (data['days'] as Map).map((key, value) {
          final dayMap = value as Map;
          return MapEntry(
            key.toString(),
            Map<String, List<Map<String, String>>>.from(
              dayMap.map((mealKey, mealValue) {
                final mealList = mealValue as List;
                return MapEntry(
                  mealKey.toString(),
                  mealList.map((item) => Map<String, String>.from(item as Map)).toList(),
                );
              }),
            ),
          );
        }),
      );
    }
  }

  void _addFoodDialog(String day, String mealType) {
    TextEditingController foodController = TextEditingController();
    TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Adicionar Alimento - ${_getMealName(mealType)}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomRadiusTextfield(
              controller: foodController,
              hintText: "Alimento (ex: Ovos mexidos)",
            ),
            const SizedBox(height: 10),
            CustomRadiusTextfield(
              controller: quantityController,
              hintText: "Quantidade (ex: 3 unidades, 150g)",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (foodController.text.isEmpty) return;

              setState(() {
                days[day]![mealType]!.add({
                  "food": foodController.text,
                  "quantity": quantityController.text,
                });
              });

              Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  String _getMealName(String mealType) {
    final index = mealTypes.indexOf(mealType);
    return index >= 0 ? mealNames[index] : mealType;
  }

  /// Mostra dialog para enviar notificação de atualização para clientes
  Future<void> _showUpdateNotificationDialog(String planId, String? currentStudentUid) async {
    if (!mounted) return;

    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final nutricionistaId = _auth.currentUser?.uid;
    if (nutricionistaId == null) return;

    // Busca conexões ativas
    try {
      final connectionsSnapshot = await _firestore
          .collection('connections')
          .where('profissionalId', isEqualTo: nutricionistaId)
          .where('status', isEqualTo: 'active')
          .get();

      final List<Map<String, dynamic>> clients = [];
      for (var connDoc in connectionsSnapshot.docs) {
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
            const SnackBar(content: Text('Você não tem clientes conectados.')),
          );
        }
        return;
      }

      // Se só tem um cliente e é o atual, pergunta diretamente
      if (clients.length == 1 && clients[0]['id'] == currentStudentUid) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Atualização do Plano'),
            content: Text(
              'Deseja notificar ${clients[0]['nome']} sobre esta atualização?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Não'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sim, notificar'),
              ),
            ],
          ),
        );

        if (result == true && mounted) {
          await _sendUpdateNotification(planId, [currentStudentUid!]);
        }
        return;
      }

      // Múltiplos clientes - mostra seleção
      final selectedClients = <String>{};
      if (currentStudentUid != null) {
        selectedClients.add(currentStudentUid); // Pré-seleciona o cliente atual
      }

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Notificar clientes sobre atualização?'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selecione os clientes que devem ser notificados:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        final isSelected = selectedClients.contains(client['id']);
                        final isCurrent = client['id'] == currentStudentUid;

                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Text(client['nome'] as String),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Atual',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                            backgroundImage: (client['fotoUrl'] as String).isNotEmpty
                                ? NetworkImage(client['fotoUrl'] as String)
                                : null,
                            child: (client['fotoUrl'] as String).isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: selectedClients.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text('Notificar ${selectedClients.length} cliente(s)'),
              ),
            ],
          ),
        ),
      );

      if (result == true && mounted) {
        await _sendUpdateNotification(planId, selectedClients.toList());
      }
    } catch (e) {
      debugPrint('Erro ao carregar clientes: $e');
    }
  }

  /// Envia notificação de atualização para os clientes selecionados
  Future<void> _sendUpdateNotification(String planId, List<String> studentIds) async {
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final nutricionistaId = _auth.currentUser?.uid;
    
    if (nutricionistaId == null) return;

    try {
      final notificationsService = NotificationsService();
      final planTitle = _titleController.text.trim();

      // Busca nome do nutricionista
      String nutricionistaName = 'Nutricionista';
      try {
        final profDoc = await _firestore.collection('professionals').doc(nutricionistaId).get();
        if (profDoc.exists) {
          final profData = profDoc.data() ?? {};
          nutricionistaName = profData['nome'] as String? ?? 
                            profData['name'] as String? ?? 
                            'Nutricionista';
        }
      } catch (e) {
        debugPrint('Erro ao buscar nome do nutricionista: $e');
      }

      // Cria notificação de atualização para cada cliente
      for (final studentId in studentIds) {
        try {
          await notificationsService.createNotification(
            senderId: nutricionistaId,
            receiverId: studentId,
            type: 'nutrition_plan_updated',
            title: '$nutricionistaName atualizou seu plano nutricional',
            message: 'Plano: $planTitle foi atualizado',
            data: {
              'planId': planId,
              'planTitle': planTitle,
            },
          );
        } catch (e) {
          debugPrint('Erro ao criar notificação para $studentId: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${studentIds.length} cliente(s) notificado(s) sobre a atualização!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao enviar notificação de atualização: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao notificar cliente: $e')),
        );
      }
    }
  }

  Future<void> _savePlan() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Digite um nome para o plano.")),
      );
      return;
    }

    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final nutricionistaId = _auth.currentUser?.uid;

    if (nutricionistaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro: usuário não autenticado.")),
      );
      return;
    }

    try {
      if (widget.planId != null) {
        // Atualiza plano existente - preserva studentUid e status
        final existingData = widget.existingPlanData ?? {};
        final studentUid = existingData['studentUid'] as String?;
        final currentStatus = existingData['status'] as String? ?? 'draft';
        
        final updateData = {
          "title": _titleController.text.trim(),
          "objective": _objectiveController.text.trim(),
          "observations": _observationsController.text.trim(),
          "days": days,
          "updatedAt": FieldValue.serverTimestamp(),
          // Preserva studentUid e status se já existirem
          if (studentUid != null) "studentUid": studentUid,
          "status": currentStatus,
        };

        await _firestore.collection("nutrition_plans").doc(widget.planId).update(updateData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Plano atualizado com sucesso!")),
          );
          
          // Sempre pergunta se quer notificar clientes sobre a atualização
          await _showUpdateNotificationDialog(widget.planId!, studentUid);
          
          Navigator.pop(context);
        }
      } else {
        // Cria novo plano
        final planData = {
          "createdBy": nutricionistaId,
          "title": _titleController.text.trim(),
          "objective": _objectiveController.text.trim(),
          "observations": _observationsController.text.trim(),
          "days": days,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "status": "draft", // draft, active, finished
        };
        // Cria novo plano
        await _firestore.collection("nutrition_plans").add(planData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Plano criado com sucesso!")),
          );
          // Navega para a lista de planos ou mostra dialog para enviar
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const NutritionPlansListPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar plano: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.planId != null ? "Editar Plano Nutricional" : "Criar Plano Nutricional"),
          centerTitle: true,
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Informações"),
              Tab(text: "Refeições"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Aba 1: Informações do plano
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CustomRadiusTextfield(
                  controller: _titleController,
                  hintText: "Nome do plano (ex: Bulking Limpo)",
                ),
                const SizedBox(height: 16),
                CustomRadiusTextfield(
                  controller: _objectiveController,
                  hintText: "Objetivo (ex: Hipertrofia, Emagrecimento, Cutting)",
                ),
                const SizedBox(height: 16),
                CustomRadiusTextfield(
                  controller: _observationsController,
                  hintText: "Observações gerais (ex: Beber 3L de água por dia)",
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                CustomRadiusButton(
                  onPressed: _savePlan,
                  text: widget.planId != null ? "Atualizar Plano" : "Salvar Plano",
                  backgroundColor: Colors.orange,
                ),
              ],
            ),
            // Aba 2: Refeições por dia
            ListView(
              padding: const EdgeInsets.all(16),
              children: daysOfWeek.asMap().entries.map((entry) {
                final dayIndex = entry.key;
                final day = entry.value;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      dayNames[dayIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: mealTypes.asMap().entries.map((mealEntry) {
                      final mealIndex = mealEntry.key;
                      final mealType = mealEntry.value;
                      final mealName = mealNames[mealIndex];
                      final foods = days[day]![mealType]!;

                      return ExpansionTile(
                        title: Text("🕐 $mealName"),
                        children: [
                          if (foods.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                "Nenhum alimento adicionado",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            ...foods.asMap().entries.map((foodEntry) {
                              final foodIndex = foodEntry.key;
                              final food = foodEntry.value;
                              return ListTile(
                                title: Text(food['food'] ?? ''),
                                subtitle: Text(food['quantity'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      days[day]![mealType]!.removeAt(foodIndex);
                                    });
                                  },
                                ),
                              );
                            }),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CustomRadiusButton(
                              onPressed: () => _addFoodDialog(day, mealType),
                              text: "Adicionar alimento",
                              backgroundColor: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

