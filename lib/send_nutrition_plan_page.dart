import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_service.dart';

class SendNutritionPlanPage extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> planData;

  const SendNutritionPlanPage({
    super.key,
    required this.planId,
    required this.planData,
  });

  @override
  State<SendNutritionPlanPage> createState() => _SendNutritionPlanPageState();
}

class _SendNutritionPlanPageState extends State<SendNutritionPlanPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  final Set<String> _selectedClients = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final nutricionistaId = _auth.currentUser?.uid;
    if (nutricionistaId == null) return;

    try {
      // Busca conexões ativas do nutricionista
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

      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar clientes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendPlan() async {
    if (_selectedClients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um cliente.')),
      );
      return;
    }

    final nutricionistaId = _auth.currentUser?.uid;
    if (nutricionistaId == null) return;

    try {
      final notificationsService = NotificationsService();
      final planTitle = widget.planData['title'] as String? ?? 'Plano Nutricional';

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

      for (final clientId in _selectedClients) {
        // Atualiza o plano com o studentUid e status active
        // Se já tinha um studentUid diferente, mantém o novo (permite reenvio)
        await _firestore.collection('nutrition_plans').doc(widget.planId).update({
          'studentUid': clientId,
          'status': 'active',
          'sentAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Cria notificação
        try {
          await notificationsService.createNotification(
            senderId: nutricionistaId,
            receiverId: clientId,
            type: 'nutrition_plan_assigned',
            title: '$nutricionistaName te enviou um plano nutricional',
            message: 'Plano: $planTitle',
            data: {
              'planId': widget.planId,
              'planTitle': planTitle,
            },
          );
        } catch (e) {
          debugPrint('Erro ao criar notificação: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plano enviado para ${_selectedClients.length} cliente(s)!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar plano: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Plano Nutricional'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _clients.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Você não tem clientes conectados ainda.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clients.length,
                        itemBuilder: (context, index) {
                          final client = _clients[index];
                          final isSelected = _selectedClients.contains(client['id']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CheckboxListTile(
                              title: Text(client['nome'] as String),
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedClients.add(client['id'] as String);
                                  } else {
                                    _selectedClients.remove(client['id']);
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
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedClients.isEmpty ? null : _sendPlan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Enviar para ${_selectedClients.length} cliente(s)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

