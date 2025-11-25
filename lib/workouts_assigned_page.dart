import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_details_page.dart';

class WorkoutsAssignedPage extends StatelessWidget {
  const WorkoutsAssignedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final _firestore = FirebaseFirestore.instance;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Área Fitness'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Faça login para ver seus treinos.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área Fitness'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('treinos_atribuidos')
            .where('clienteId', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'ativo')
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

          final assignments = snapshot.data?.docs ?? [];

          if (assignments.isEmpty) {
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
                      'Nenhum treino atribuído ainda.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seu profissional ainda não atribuiu treinos para você.',
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

          // Busca os dados dos treinos
          return FutureBuilder<List<Map<String, dynamic>?>>(
            future: Future.wait(
              assignments.map((assignmentDoc) async {
                final assignmentData = assignmentDoc.data();
                final workoutId = assignmentData['workoutId'] as String?;
                
                if (workoutId == null) return null as Map<String, dynamic>?;

                try {
                  final workoutDoc = await _firestore
                      .collection('treinos')
                      .doc(workoutId)
                      .get();

                  if (!workoutDoc.exists) return null as Map<String, dynamic>?;

                  final workoutData = workoutDoc.data() ?? {};
                  
                  // Busca nome do profissional
                  final profissionalId = workoutData['profissionalId'] as String?;
                  String profissionalName = 'Profissional';
                  
                  if (profissionalId != null) {
                    try {
                      final profDoc = await _firestore
                          .collection('professionals')
                          .doc(profissionalId)
                          .get();
                      if (profDoc.exists) {
                        final profData = profDoc.data() ?? {};
                        profissionalName = profData['nome'] as String? ?? 
                                          profData['name'] as String? ?? 
                                          'Profissional';
                      }
                    } catch (e) {
                      // Ignora erro ao buscar nome do profissional
                    }
                  }

                  return {
                    'workoutId': workoutId,
                    'workoutData': workoutData,
                    'assignmentId': assignmentDoc.id,
                    'atribuidoEm': assignmentData['atribuidoEm'],
                    'profissionalName': profissionalName,
                  } as Map<String, dynamic>?;
                } catch (e) {
                  return null as Map<String, dynamic>?;
                }
              }),
            ),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }

              final workouts = futureSnapshot.data
                      ?.whereType<Map<String, dynamic>>()
                      .toList() ?? [];

              if (workouts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum treino encontrado.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                );
              }

              // Ordena por data de atribuição (mais recente primeiro)
              workouts.sort((a, b) {
                final aTime = (a['atribuidoEm'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bTime = (b['atribuidoEm'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  final workoutData = workout['workoutData'] as Map<String, dynamic>;
                  final title = workoutData['title'] as String? ?? 'Treino sem título';
                  final profissionalName = workout['profissionalName'] as String? ?? 'Profissional';
                  final atribuidoEm = workout['atribuidoEm'] as Timestamp?;

                  String dateText = 'Data não informada';
                  if (atribuidoEm != null) {
                    final date = atribuidoEm.toDate();
                    dateText = 'Atribuído em: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Por: $profissionalName',
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
                            builder: (_) => WorkoutDetailsPage(data: workoutData),
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



