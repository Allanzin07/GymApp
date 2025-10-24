import 'package:flutter/material.dart';
import 'login_page.dart';
import 'ads_carousel.dart';
import 'adicionar_anuncio_page.dart'; // 👈 Import da nova tela

class HomeAcademiaPage extends StatefulWidget {
  const HomeAcademiaPage({super.key});

  @override
  State<HomeAcademiaPage> createState() => _HomeAcademiaPageState();
}

class _HomeAcademiaPageState extends State<HomeAcademiaPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Painel da Academia'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(userType: 'Academia'),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Bem-vindo(a), Academia!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 16),
          AdsCarousel(
            ads: [
              GymAd(
                id: '1',
                gymName: 'Minha Academia',
                title: 'Desconto especial para novos alunos!',
                imageUrl:
                    'https://images.unsplash.com/photo-1558611848-73f7eb4001a1?w=1200&q=80&auto=format&fit=crop',
                distance: '0m',
                rating: 4.9,
              ),
            ],
            onTapAd: (ad) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AcademiaProfilePage(ad: ad),
                ),
              );
            },
            onFavorite: (_) {},
            isFavorite: (_) => false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text('Novo Anúncio'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdicionarAnuncioPage(),
            ),
          );
        },
      ),
    );
  }
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.red),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.fitness_center, color: Colors.white, size: 48),
                SizedBox(height: 10),
                Text(
                  'Minha Academia',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Editar Perfil'),
            onTap: () {
              // Em breve: página de edição do perfil da academia
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Gerenciar Anúncios'),
            onTap: () {
              // Em breve: página de gerenciamento de anúncios
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(userType: 'Academia'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Página pública da academia (acessada por usuários normais ao clicar num anúncio)
class AcademiaProfilePage extends StatelessWidget {
  final GymAd ad;
  const AcademiaProfilePage({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ad.gymName),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(ad.imageUrl),
            const SizedBox(height: 16),
            Text(
              ad.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Distância: ${ad.distance}'),
            const SizedBox(height: 8),
            Text('Avaliação: ${ad.rating} ⭐'),
            const SizedBox(height: 16),
            const Text(
              'Descrição e informações adicionais da academia...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
