import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_nutrition_plan_page.dart';
import 'send_nutrition_plan_page.dart';

class NutritionPlansListPage extends StatelessWidget {
  const NutritionPlansListPage({super.key});

  // Função para confirmar e excluir um plano alimentar
  static Future<void> _confirmDeletePlan(
    BuildContext context,
    FirebaseFirestore firestore,
    String planId,
    String planTitle,
  ) async {
    // Mostra diálogo de confirmação
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text(
            'Tem certeza que deseja excluir o plano alimentar "$planTitle"?\n\nEsta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    // Se o usuário confirmou, exclui o plano
    if (confirmDelete == true) {
      try {
        await firestore.collection('nutrition_plans').doc(planId).delete();
        
        // Mostra mensagem de sucesso
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plano alimentar excluído com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Mostra mensagem de erro
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir plano: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final nutricionistaId = _auth.currentUser?.uid;

    if (nutricionistaId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Planos Nutricionais'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Faça login para ver seus planos.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos Nutricionais'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateNutritionPlanPage(),
                ),
              );
            },
            tooltip: 'Criar novo plano',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('nutrition_plans')
            .where('createdBy', isEqualTo: nutricionistaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar planos.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum plano criado ainda.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crie seu primeiro plano nutricional!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateNutritionPlanPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Criar Plano'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
              return bTime.compareTo(aTime);
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data();
              final title = data['title'] as String? ?? 'Plano sem título';
              final objective = data['objective'] as String? ?? '';
              final status = data['status'] as String? ?? 'draft';
              final studentUid = data['studentUid'] as String?;
              final createdAt = data['createdAt'] as Timestamp?;

              String dateText = 'Data não informada';
              if (createdAt != null) {
                final date = createdAt.toDate();
                dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
              }

              Color statusColor = Colors.grey;
              String statusText = 'Rascunho';
              if (status == 'active') {
                statusColor = Colors.green;
                statusText = 'Ativo';
              } else if (status == 'finished') {
                statusColor = Colors.blue;
                statusText = 'Finalizado';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.restaurant_menu, color: Colors.orange),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (objective.isNotEmpty) ...[
                        Text(
                          'Objetivo: $objective',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Criado em: $dateText',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sempre mostra botão de enviar (para novos envios ou reenvios)
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.orange),
                        tooltip: studentUid == null ? 'Enviar para cliente' : 'Reenviar ou enviar para outros',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SendNutritionPlanPage(planId: doc.id, planData: data),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        tooltip: 'Editar',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateNutritionPlanPage(
                                planId: doc.id,
                                existingPlanData: data,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Excluir',
                        onPressed: () => _confirmDeletePlan(context, _firestore, doc.id, title),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    // Pode abrir detalhes ou editar
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateNutritionPlanPage(
                          planId: doc.id,
                          existingPlanData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

