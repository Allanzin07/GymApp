import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nutrition_details_page.dart';

class MyNutritionPage extends StatelessWidget {
  const MyNutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Minha Dieta'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Faça login para ver seus planos nutricionais.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Dieta'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('nutrition_plans')
            .where('studentUid', isEqualTo: currentUserId)
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
                      'Erro ao carregar planos nutricionais.',
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
                      'Nenhum plano nutricional atribuído a você ainda.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Conecte-se com nutricionistas para receber planos!',
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

          // Busca dados do nutricionista para cada plano
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(
              docs.map((doc) async {
                final data = doc.data();
                final nutricionistaId = data['createdBy'] as String?;
                String nutricionistaName = 'Nutricionista';

                if (nutricionistaId != null) {
                  try {
                    final profDoc = await _firestore
                        .collection('professionals')
                        .doc(nutricionistaId)
                        .get();
                    if (profDoc.exists) {
                      final profData = profDoc.data() ?? {};
                      nutricionistaName = profData['nome'] as String? ??
                                        profData['name'] as String? ??
                                        'Nutricionista';
                    }
                  } catch (e) {
                    // Ignora erro
                  }
                }

                return {
                  'planId': doc.id,
                  'planData': data,
                  'nutricionistaName': nutricionistaName,
                  'sentAt': data['sentAt'],
                };
              }),
            ),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                );
              }

              final plans = futureSnapshot.data ?? [];

              // Ordena por data de envio (mais recente primeiro)
              plans.sort((a, b) {
                final aTime = (a['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bTime = (b['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final planData = plan['planData'] as Map<String, dynamic>;
                  final title = planData['title'] as String? ?? 'Plano Nutricional';
                  final objective = planData['objective'] as String? ?? '';
                  final nutricionistaName = plan['nutricionistaName'] as String;
                  final sentAt = plan['sentAt'] as Timestamp?;

                  String dateText = 'Data não informada';
                  if (sentAt != null) {
                    final date = sentAt.toDate();
                    dateText = 'Recebido em: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                            const SizedBox(height: 2),
                          ],
                          Text(
                            'Por: $nutricionistaName',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateText,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NutritionDetailsPage(
                              planData: planData,
                              nutricionistaName: nutricionistaName,
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
        },
      ),
    );
  }
}

