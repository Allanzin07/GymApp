import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'ads_carousel.dart';
import 'favorites_page.dart';
import 'perfil_academia_page.dart';
import 'perfil_profissional_page.dart';

class HomeUsuarioPage extends StatefulWidget {
  const HomeUsuarioPage({super.key});

  @override
  State<HomeUsuarioPage> createState() => _HomeUsuarioPageState();
}

class _HomeUsuarioPageState extends State<HomeUsuarioPage> {
  bool isLoggedIn = false;
  List<GymAd> favoriteAds = [];

  void _onLoginOrProfile() {
    if (isLoggedIn) {
      print('Abrir perfil de usuário');
      // Futuro: redirecionar para o perfil do próprio usuário
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(userType: 'Usuário'),
        ),
      ).then((_) {
        setState(() {
          isLoggedIn = true;
        });
      });
    }
  }

  Widget _buildDrawerItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }

  // 🔥 Novo método: stream de anúncios do Firestore
  Stream<List<GymAd>> _getAdsStream() {
    return FirebaseFirestore.instance
        .collection('anuncios')
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return GymAd(
                id: doc.id,
                gymName: data['nome'] ?? '',
                title: data['descricao'] ?? '',
                imageUrl: data['imagem'] ?? '',
                distance: data['distancia'] ?? '',
                rating: (data['avaliacao'] ?? 0).toDouble(),
                type: data['tipo'] ?? 'Academia',
              );
            }).toList());
  }

  bool _isFavorite(GymAd ad) => favoriteAds.any((fav) => fav.id == ad.id);

  void _toggleFavorite(GymAd ad) {
    setState(() {
      if (_isFavorite(ad)) {
        favoriteAds.removeWhere((fav) => fav.id == ad.id);
      } else {
        favoriteAds.add(ad);
      }
    });
  }

  void _onTapAd(GymAd ad) {
    if (ad.type == 'Academia') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PerfilAcademiaPage(ad: ad)),
      );
    } else if (ad.type == 'Profissional') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PerfilProfissionalPage(ad: ad)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
        backgroundColor: Colors.red,
        actions: [
          TextButton(
            onPressed: _onLoginOrProfile,
            child: Text(
              isLoggedIn ? 'Perfil' : 'Entrar',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.red.shade700),
              child: const Center(
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            _buildDrawerItem('Home', Icons.home, () => Navigator.pop(context)),
            _buildDrawerItem('Favoritos', Icons.favorite, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritesPage(favorites: favoriteAds),
                ),
              );
            }),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Anúncios de academias e profissionais próximos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🔥 Substitui o AdsCarousel fixo pelo StreamBuilder
          StreamBuilder<List<GymAd>>(
            stream: _getAdsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhum anúncio encontrado.'));
              }

              final ads = snapshot.data!;
              return AdsCarousel(
                ads: ads,
                onTapAd: _onTapAd,
                onFavorite: _toggleFavorite,
                isFavorite: _isFavorite,
              );
            },
          ),
        ],
      ),
    );
  }
}
