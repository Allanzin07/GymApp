import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'ads_carousel.dart';
import 'favorites_page.dart';
import 'minha_rede_page.dart';
import 'home_academia_page.dart';
import 'home_profissional_page.dart';
import 'conversations_page.dart';

class HomeUsuarioPage extends StatefulWidget {
  final bool guestMode;
  const HomeUsuarioPage({super.key, this.guestMode = false});

  @override
  State<HomeUsuarioPage> createState() => _HomeUsuarioPageState();
}

class _HomeUsuarioPageState extends State<HomeUsuarioPage> {
  bool isLoggedIn = true;
  List<GymAd> favoriteAds = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<GymAd> _allAds = [];
  bool _isLoadingAds = true;
  String? _loadError;

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

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() {
      _isLoadingAds = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _firestore.collection('academias').get(),
        _firestore.collection('professionals').get(),
      ]);

      final academiasSnapshot = results[0];
      final profissionaisSnapshot = results[1];

      final academias = academiasSnapshot.docs.map((doc) {
        final data = doc.data();
        final nome = data['nome'] as String? ?? 'Academia';
        final descricao = data['descricao'] as String? ?? 'Descubra nossos serviços e planos.';
        final fotoPerfil = data['fotoPerfilUrl'] as String? ??
            data['fotoUrl'] as String? ??
            'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1200';
        final distancia = data['distancia']?.toString() ?? data['distance']?.toString() ?? '0 km';
        final avaliacao = _parseRating(data['avaliacao'] ?? data['rating']);

        return GymAd(
          id: doc.id,
          gymName: nome,
          title: descricao,
          imageUrl: fotoPerfil,
          distance: distancia,
          rating: avaliacao,
          type: 'Academia',
        );
      });

      final profissionais = profissionaisSnapshot.docs.map((doc) {
        final data = doc.data();
        final nome = data['nome'] as String? ?? 'Profissional';
        final especialidade = data['especialidade'] as String? ??
            data['descricao'] as String? ??
            'Conheça meu trabalho e resultados.';
        final fotoPerfil = data['fotoUrl'] as String? ??
            'https://cdn-icons-png.flaticon.com/512/149/149071.png';
        final distancia = data['distancia']?.toString() ?? data['distance']?.toString() ?? '0 km';
        final avaliacao = _parseRating(data['avaliacao'] ?? data['rating']);

        return GymAd(
          id: doc.id,
          gymName: nome,
          title: especialidade,
          imageUrl: fotoPerfil,
          distance: distancia,
          rating: avaliacao,
          type: 'Profissional',
        );
      });

      setState(() {
        _allAds = [...academias, ...profissionais];
        _isLoadingAds = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Erro ao carregar cadastros: $e';
        _isLoadingAds = false;
      });
    }
  }

  double _parseRating(dynamic value) {
    if (value is num) return value.toDouble().clamp(0, 5);
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) {
        return parsed.clamp(0, 5);
      }
    }
    return 0.0;
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
        MaterialPageRoute(
          builder: (_) => HomeAcademiaPage(academiaId: ad.id),
        ),
      );
    } else if (ad.type == 'Profissional') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeProfissionalPage(profissionalId: ad.id),
        ),
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
    final filteredAds = _filterAds(_allAds);

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
            _buildDrawerItem('Minha Rede', Icons.people, () {
              Navigator.pop(context);
              if (widget.guestMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Crie uma conta para acessar sua rede.'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MinhaRedePage()),
              );
            }),
            _buildDrawerItem('Chat', Icons.chat, () async {
              Navigator.pop(context);
              if (widget.guestMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Crie uma conta para usar o chat.'),
                  ),
                );
                return;
              }

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Faça login para acessar o chat.'),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConversationsPage(),
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
          if (_isLoadingAds)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadAds,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (filteredAds.isEmpty)
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
