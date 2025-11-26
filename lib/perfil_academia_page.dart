import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'ads_carousel.dart';

class PerfilAcademiaPage extends StatelessWidget {
  final GymAd ad;

  const PerfilAcademiaPage({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(ad.gymName),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kIsWeb ? 1200 : double.infinity,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              ad.imageUrl,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ad.gymName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                ad.rating.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const Spacer(),
              Icon(Icons.location_on, color: Colors.red.shade400),
              Text(
                ad.distance,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            ad.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Divider(height: 32, thickness: 1, color: Theme.of(context).dividerTheme.color),
          Text(
            "Sobre a Academia",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Aqui você poderá inserir informações detalhadas sobre a academia — como horários de funcionamento, planos disponíveis, estrutura, localização e diferenciais.",
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Serviços Disponíveis",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  'Musculação',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ),
              Chip(
                label: Text(
                  'Crossfit',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ),
              Chip(
                label: Text(
                  'Aulas Funcionais',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ),
              Chip(
                label: Text(
                  'Personal Trainer',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrar em contato com a academia'),
                ),
              );
            },
            icon: const Icon(Icons.phone),
            label: const Text("Entrar em Contato"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}
