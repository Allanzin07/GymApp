import 'package:flutter/material.dart';
import 'login_page.dart';
import 'ads_carousel.dart';
import 'favorites_page.dart';
import 'perfil_academia_page.dart';
import 'perfil_profissional_page.dart';

class HomeUsuarioPage extends StatefulWidget {
  final bool guestMode;
  const HomeUsuarioPage({super.key, this.guestMode = false});

  @override
  State<HomeUsuarioPage> createState() => _HomeUsuarioPageState();
}

class _HomeUsuarioPageState extends State<HomeUsuarioPage> {
  bool isLoggedIn = true;
  List<GymAd> favoriteAds = [];

  void _logout() {
    if (widget.guestMode) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage(userType: 'Usuário')),
        (route) => false,
      );
      return;
    }

    setState(() => isLoggedIn = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage(userType: 'Usuário')),
      (route) => false,
    );
  }

  void _onLoginOrProfile() {
    if (widget.guestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Modo visitante: crie uma conta para acessar mais recursos.')),
      );
      return;
    }

    if (isLoggedIn) {
      print('Abrir perfil do usuário');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage(userType: 'Usuário')),
      ).then((_) => setState(() => isLoggedIn = true));
    }
  }

  Widget _buildDrawerItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  List<GymAd> _exampleAds() {
    return [
      GymAd(
        id: '1',
        gymName: 'Academia Alpha',
        title: 'Musculação e funcional de alta performance',
        imageUrl:
            'https://images.unsplash.com/photo-1554284126-aa88f22d8f85?w=1200',
        distance: '300m',
        rating: 4.7,
        type: 'Academia',
      ),
      GymAd(
        id: '2',
        gymName: 'João Personal',
        title: 'Aulas personalizadas e consultoria',
        imageUrl:
            'https://images.unsplash.com/photo-1599058917212-d750089bc07c?w=1200',
        distance: '1.2km',
        rating: 4.9,
        type: 'Profissional',
      ),
    ];
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
    if (widget.guestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Crie uma conta para visualizar detalhes.')),
      );
      return;
    }

    if (ad.type == 'Academia') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PerfilAcademiaPage(ad: ad)));
    } else if (ad.type == 'Profissional') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PerfilProfissionalPage(ad: ad)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = _exampleAds();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guestMode ? 'Bem-vindo (Visitante)' : 'Bem-vindo'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(widget.guestMode ? Icons.login : Icons.logout,
                color: Colors.white),
            tooltip: widget.guestMode ? 'Entrar' : 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.red.shade700),
              child: const Center(
                child: Text('Menu',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
            ),
            _buildDrawerItem('Home', Icons.home, () => Navigator.pop(context)),
            _buildDrawerItem('Favoritos', Icons.favorite, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritesPage(
                    favorites: favoriteAds,
                    onFavoritesChanged: (updatedFavorites) {
                      setState(() {
                        favoriteAds = updatedFavorites;
                      });
                    },
                  ),
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
                  color: Colors.red.shade700),
            ),
          ),
          const SizedBox(height: 12),
          AdsCarousel(
            ads: ads,
            onTapAd: _onTapAd,
            onFavorite: _toggleFavorite,
            isFavorite: _isFavorite,
          ),
          if (widget.guestMode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.grey[200],
                child: const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Modo visitante'),
                  subtitle: Text(
                      'Crie uma conta para comprar planos ou contratar serviços.'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
