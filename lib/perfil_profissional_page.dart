import 'package:flutter/material.dart';
import 'ads_carousel.dart';

class PerfilProfissionalPage extends StatelessWidget {
  final GymAd ad;

  const PerfilProfissionalPage({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ad.gymName),
        backgroundColor: Colors.red,
      ),
      body: ListView(
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
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                ad.rating.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(Icons.location_on, color: Colors.red.shade400),
              Text(ad.distance),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            ad.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 32, thickness: 1),
          const Text(
            "Sobre o Profissional",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Aqui o profissional poderá descrever sua formação, especializações, métodos de trabalho, valores e experiência na área fitness.",
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          const Text(
            "Serviços Oferecidos",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('Personal Trainer')),
              Chip(label: Text('Nutrição Esportiva')),
              Chip(label: Text('Consultoria Online')),
              Chip(label: Text('Avaliação Física')),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrar em contato com o profissional'),
                ),
              );
            },
            icon: const Icon(Icons.message),
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
    );
  }
}
