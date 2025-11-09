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

  // Filtros
  String _searchText = '';
  String? _selectedType;
  double _maxDistance = 10.0;
  double _minRating = 0.0;
  double? _maxPrice;

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage(userType: 'Usuário')),
      (route) => false,
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
      GymAd(
        id: '3',
        gymName: 'FitZone Academia',
        title: 'CrossFit e treinos funcionais',
        imageUrl:
            'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1200',
        distance: '2.5km',
        rating: 4.5,
        type: 'Academia',
      ),
      GymAd(
        id: '4',
        gymName: 'Maria Nutricionista',
        title: 'Consultoria nutricional esportiva',
        imageUrl:
            'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1200',
        distance: '800m',
        rating: 4.8,
        type: 'Profissional',
      ),
      GymAd(
        id: '5',
        gymName: 'PowerGym',
        title: 'Musculação avançada e powerlifting',
        imageUrl:
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200',
        distance: '5km',
        rating: 4.6,
        type: 'Academia',
      ),
    ];
  }

  /// ✅ Corrigido: função segura que aceita "m", "km", "k", letras maiúsculas/minúsculas e ignora erros
  double _parseDistance(String distance) {
    distance = distance.trim().toLowerCase();

    if (distance.endsWith('km')) {
      final numStr = distance.replaceAll('km', '').trim();
      return double.tryParse(numStr) ?? 0.0;
    } else if (distance.endsWith('k')) {
      final numStr = distance.replaceAll('k', '').trim();
      return double.tryParse(numStr) ?? 0.0;
    } else if (distance.endsWith('m')) {
      final numStr = distance.replaceAll('m', '').trim();
      final meters = double.tryParse(numStr) ?? 0.0;
      return meters / 1000;
    } else {
      // Caso não tenha unidade, tenta converter direto
      return double.tryParse(distance) ?? 0.0;
    }
  }

  List<GymAd> _filterAds(List<GymAd> ads) {
    return ads.where((ad) {
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();
        final matchesName = ad.gymName.toLowerCase().contains(searchLower);
        final matchesTitle = ad.title.toLowerCase().contains(searchLower);
        if (!matchesName && !matchesTitle) return false;
      }

      if (_selectedType != null && ad.type != _selectedType) {
        return false;
      }

      final distanceInKm = _parseDistance(ad.distance);
      if (distanceInKm > _maxDistance) return false;

      if (ad.rating < _minRating) return false;

      // Filtro por preço (será implementado quando o campo price for adicionado ao GymAd)
      // if (_maxPrice != null && ad.price > _maxPrice!) return false;

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchText = '';
      _selectedType = null;
      _maxDistance = 10.0;
      _minRating = 0.0;
      _maxPrice = null;
    });
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
        const SnackBar(content: Text('Crie uma conta para visualizar detalhes.')),
      );
      return;
    }

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

  Widget _buildDrawerItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAds = _exampleAds();
    final filteredAds = _filterAds(allAds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair',
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
                      setState(() => favoriteAds = updatedFavorites);
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
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar academias ou profissionais...',
                prefixIcon: const Icon(Icons.search, color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredAds.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nenhum anúncio encontrado.'),
              ),
            )
          else
            AdsCarousel(
              ads: filteredAds,
              onTapAd: _onTapAd,
              onFavorite: _toggleFavorite,
              isFavorite: _isFavorite,
            ),
          const SizedBox(height: 24),
          // Painel de descoberta e filtros
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descubra academias e profissionais perto de você',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Filtro por Tipo
                const Text(
                  'Tipo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Academias',
                      selected: _selectedType == 'Academia',
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? 'Academia' : null;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Profissionais',
                      selected: _selectedType == 'Profissional',
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? 'Profissional' : null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtro por Distância
                const Text(
                  'Distância máxima',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _maxDistance,
                        min: 1.0,
                        max: 20.0,
                        divisions: 19,
                        label: '${_maxDistance.toStringAsFixed(1)} km',
                        activeColor: Colors.red,
                        onChanged: (value) {
                          setState(() {
                            _maxDistance = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '${_maxDistance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtro por Avaliação
                const Text(
                  'Avaliação mínima',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _minRating,
                        min: 0.0,
                        max: 5.0,
                        divisions: 10,
                        label: _minRating > 0 ? _minRating.toStringAsFixed(1) : 'Sem filtro',
                        activeColor: Colors.red,
                        onChanged: (value) {
                          setState(() {
                            _minRating = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _minRating > 0 ? _minRating.toStringAsFixed(1) : 'Todas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtro por Valor
                const Text(
                  'Valor máximo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Até R\$ 50',
                      selected: _maxPrice == 50.0,
                      onSelected: (selected) {
                        setState(() {
                          _maxPrice = selected ? 50.0 : null;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Até R\$ 100',
                      selected: _maxPrice == 100.0,
                      onSelected: (selected) {
                        setState(() {
                          _maxPrice = selected ? 100.0 : null;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Até R\$ 200',
                      selected: _maxPrice == 200.0,
                      onSelected: (selected) {
                        setState(() {
                          _maxPrice = selected ? 200.0 : null;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Sem limite',
                      selected: _maxPrice == null,
                      onSelected: (selected) {
                        setState(() {
                          _maxPrice = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botão limpar filtros
                if (_selectedType != null || _minRating > 0 || _maxPrice != null || _maxDistance < 10.0)
                  Center(
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear, color: Colors.red),
                      label: const Text(
                        'Limpar filtros',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red,
      labelStyle: TextStyle(
        color: selected ? Colors.red.shade700 : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? Colors.red : Colors.grey.shade300,
        width: selected ? 2 : 1,
      ),
    );
  }
}
