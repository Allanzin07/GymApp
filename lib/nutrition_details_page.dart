import 'package:flutter/material.dart';

class NutritionDetailsPage extends StatelessWidget {
  final Map<String, dynamic> planData;
  final String nutricionistaName;

  const NutritionDetailsPage({
    super.key,
    required this.planData,
    required this.nutricionistaName,
  });

  String _getDayName(String day) {
    final dayNames = {
      'monday': 'Segunda-feira',
      'tuesday': 'Terça-feira',
      'wednesday': 'Quarta-feira',
      'thursday': 'Quinta-feira',
      'friday': 'Sexta-feira',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };
    return dayNames[day] ?? day;
  }

  String _getMealName(String mealType) {
    final mealNames = {
      'breakfast': 'Café da manhã',
      'morningSnack': 'Lanche da manhã',
      'lunch': 'Almoço',
      'afternoonSnack': 'Lanche da tarde',
      'dinner': 'Jantar',
      'supper': 'Ceia',
    };
    return mealNames[mealType] ?? mealType;
  }

  String _getMealIcon(String mealType) {
    final mealIcons = {
      'breakfast': '🌅',
      'morningSnack': '🍎',
      'lunch': '🍛',
      'afternoonSnack': '🥗',
      'dinner': '🍽️',
      'supper': '🌙',
    };
    return mealIcons[mealType] ?? '🍴';
  }

  @override
  Widget build(BuildContext context) {
    final title = planData['title'] as String? ?? 'Plano Nutricional';
    final objective = planData['objective'] as String? ?? '';
    final observations = planData['observations'] as String? ?? '';
    final days = planData['days'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Informações do plano
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (objective.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Objetivo: $objective',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Por: $nutricionistaName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (observations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Observações:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      observations,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Refeições por dia
          ...days.entries.map((dayEntry) {
            final day = dayEntry.key;
            final meals = dayEntry.value as Map<String, dynamic>? ?? {};

            if (meals.isEmpty) return const SizedBox.shrink();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: Text(
                  _getDayName(day),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: meals.entries.map((mealEntry) {
                  final mealType = mealEntry.key;
                  final foods = mealEntry.value as List<dynamic>? ?? [];

                  if (foods.isEmpty) return const SizedBox.shrink();

                  return ExpansionTile(
                    leading: Text(
                      _getMealIcon(mealType),
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(_getMealName(mealType)),
                    children: foods.map((foodItem) {
                      final food = foodItem as Map<String, dynamic>;
                      final foodName = food['food'] as String? ?? '';
                      final quantity = food['quantity'] as String? ?? '';

                      return ListTile(
                        leading: const Icon(Icons.restaurant, size: 20),
                        title: Text(
                          foodName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: quantity.isNotEmpty
                            ? Text(
                                quantity,
                                style: TextStyle(color: Colors.grey.shade600),
                              )
                            : null,
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            );
          }).toList(),

          // Mensagem se não houver refeições
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  "Este plano ainda não possui refeições cadastradas.",
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

