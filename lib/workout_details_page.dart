import 'package:flutter/material.dart';

class WorkoutDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const WorkoutDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data["title"] as String? ?? "Treino";
    final weeklyPlan = data["weeklyPlan"] as Map<String, dynamic>? ?? {};
    final musclePlan = data["musclePlan"] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Treino por dia da semana
          if (weeklyPlan.isNotEmpty) ...[
            const Text(
              "Treino por dia da semana",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...weeklyPlan.entries.map((e) {
              final exercises = e.value as List<dynamic>? ?? [];
              if (exercises.isEmpty) return const SizedBox.shrink();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.red),
                  title: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    ...exercises.map((ex) {
                      final exercise = ex as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.fitness_center, size: 20),
                        title: Text(
                          exercise["name"] as String? ?? "Exercício",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "${exercise["series"] ?? "N/A"} séries x ${exercise["reps"] ?? "N/A"} reps",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Treino por grupo muscular
          if (musclePlan.isNotEmpty) ...[
            const Text(
              "Treino por grupo muscular",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...musclePlan.entries.map((e) {
              final exercises = e.value as List<dynamic>? ?? [];
              if (exercises.isEmpty) return const SizedBox.shrink();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.sports_gymnastics, color: Colors.red),
                  title: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    ...exercises.map((ex) {
                      final exercise = ex as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.fitness_center, size: 20),
                        title: Text(
                          exercise["name"] as String? ?? "Exercício",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "${exercise["series"] ?? "N/A"} séries x ${exercise["reps"] ?? "N/A"} reps",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }),
          ],

          // Mensagem se não houver treinos
          if (weeklyPlan.isEmpty && musclePlan.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  "Este treino ainda não possui exercícios cadastrados.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



