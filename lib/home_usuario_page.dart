import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'choose_login_type_page.dart';
import 'ads_carousel.dart';
import 'favorites_page.dart';
import 'minha_rede_usuario.dart';
import 'home_academia_page.dart';
import 'home_profissional_page.dart';
import 'conversations_page.dart';
import 'notifications_button.dart';
import 'editar_perfil_usuario_page.dart';
import 'package:geolocator/geolocator.dart';
import 'connected_posts_feed.dart';
import 'user_fitness_selection_page.dart';

class HomeUsuarioPage extends StatefulWidget {
  final bool guestMode;

  const HomeUsuarioPage({super.key, this.guestMode = false});

  @override
  State<HomeUsuarioPage> createState() => _HomeUsuarioPageState();
}

class _HomeUsuarioPageState extends State<HomeUsuarioPage> {
  bool isLoggedIn = true;

  // Variável de estado para a lista de objetos GymAd favoritos
  List<GymAd> favoriteAds = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Adicionado para acesso rápido ao UID

  List<GymAd> _allAds = [];

  bool _isLoadingAds = true;

  String? _loadError;

  // Filtros
  String _searchText = '';
  String? _selectedType;
  double _maxDistance = 10.0;
  double _minRating = 0.0;
  Position? _userPosition;
  StreamSubscription<Position>? _locationSubscription;
  String? _userName;
  String? _userProfilePicUrl;
  String? _userEmail; // Adicional, se quiser mostrar
  bool _isLoadingUserData = false;

  double calcularDistanciaEmKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || widget.guestMode) return;

    if (!mounted) return;
    setState(() {
      _isLoadingUserData = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();

      if (data != null && mounted) {
        setState(() {
          // 1. CORRIGIDO: O campo no Firestore é 'name', não 'nome'.
          _userName = data['name'] as String? ?? 'Usuário';

          // 2. CORRIGIDO: O campo no Firestore é 'fotoPerfilUrl'
          _userProfilePicUrl = data['fotoPerfilUrl'] as String?;

          // O email pode ser pego do Auth ou do Firestore (o Firestore usa 'email' minúsculo)
          _userEmail = data['email'] as String? ?? _auth.currentUser?.email;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Faz logout do Firebase Auth
        await FirebaseAuth.instance.signOut();

        // Navega para a tela de escolha de login removendo todas as rotas anteriores
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ChooseLoginTypePage()),
          (route) => false,
        );
      } catch (e) {
        // Em caso de erro, ainda tenta navegar
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ChooseLoginTypePage()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) _loadAds();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) _loadAds();
        return;
      }

      // Adiciona timeout para evitar travamento
      try {
        _userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy
              .medium, // Reduzido de high para medium para ser mais rápido
          timeLimit: const Duration(seconds: 10), // Timeout de 10 segundos
        );
      } on TimeoutException {
        // Em caso de timeout, continua sem localização
        _userPosition = null;
        debugPrint('Timeout ao obter localização');
      }
    } catch (e) {
      // Ignora erros de localização e continua carregando os anúncios
      debugPrint('Erro ao obter localização: $e');
    } finally {
      // Garante que os anúncios sejam carregados mesmo se a localização falhar
      if (mounted) {
        _loadAds();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Carrega localização de forma assíncrona sem bloquear a UI
    _getUserLocation();
    // Inicia stream de localização em tempo real
    _startLocationStream();

    // NOVO: Carrega dados do usuário para o Drawer
    if (!widget.guestMode) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Inicia stream de localização em tempo real
  void _startLocationStream() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100, // Atualiza a cada 100 metros
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _userPosition = position;
          });
          // Recalcula distâncias quando a localização muda
          _recalculateDistances();
        }
      },
      onError: (error) {
        debugPrint('Erro no stream de localização: $error');
      },
    );
  }

  /// Recalcula distâncias de todos os anúncios
  void _recalculateDistances() {
    if (_userPosition == null) return;

    setState(() {
      _allAds = _allAds.map((ad) {
        if (ad.latitude != null && ad.longitude != null) {
          final distanceKm = calcularDistanciaEmKm(
            _userPosition!.latitude,
            _userPosition!.longitude,
            ad.latitude!,
            ad.longitude!,
          );

          // Cria novo GymAd com distância atualizada
          return GymAd(
            id: ad.id,
            gymName: ad.gymName,
            title: ad.title,
            imageUrl: ad.imageUrl,
            distance: '${distanceKm.toStringAsFixed(1)} km',
            rating: ad.rating,
            type: ad.type,
            calculatedDistanceKm: distanceKm,
            latitude: ad.latitude,
            longitude: ad.longitude,
          );
        }

        return ad;
      }).toList();
    });
  }

  // =========================================================
  // CORREÇÃO: PERSISTÊNCIA DE FAVORITOS
  // =========================================================

  /// Carrega os favoritos do Firestore. Chamado após _loadAds.
  Future<void> _loadFavorites() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || widget.guestMode) return;

    try {
      // 1. Busca o documento do usuário
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();

      if (data != null) {
        // 2. Extrai a lista de IDs favoritos do Firestore
        final List<String> favoriteIds =
            (data['favoriteAdIds'] as List<dynamic>?)
                    ?.map((id) => id.toString())
                    .toList() ??
                [];

        // 3. Filtra _allAds (os anúncios já carregados) para criar a lista de GymAd favoritos
        // Nota: Apenas os anúncios que já foram carregados estarão disponíveis aqui.
        final List<GymAd> loadedFavorites =
            _allAds.where((ad) => favoriteIds.contains(ad.id)).toList();

        if (mounted) {
          setState(() {
            // Atualiza a lista de favoritos no estado com os objetos GymAd encontrados
            favoriteAds = loadedFavorites;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar favoritos: $e');
    }
  }

  /// Persiste a alteração de favorito no Firestore.
  Future<void> _updateFavoriteInFirestore(String adId, bool isAdding) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || widget.guestMode) return;

    try {
      final userRef = _firestore.collection('users').doc(uid);

      // Usa FieldValue.arrayUnion para adicionar ou arrayRemove para remover
      await userRef.update({
        'favoriteAdIds': isAdding
            ? FieldValue.arrayUnion([adId])
            : FieldValue.arrayRemove([adId]),
      });
    } catch (e) {
      debugPrint('Erro ao atualizar favoritos no Firestore: $e');
      if (mounted) {
        // Opcional: Notificar usuário ou reverter estado local
      }
    }
  }

  // =========================================================
  // FIM: PERSISTÊNCIA DE FAVORITOS
  // =========================================================

  Future<void> _loadAds() async {
    if (!mounted) return;

    setState(() {
      _isLoadingAds = true;
      _loadError = null;
    });

    try {
      // Adiciona timeout para evitar travamento
      final results = await Future.wait([
        _firestore.collection('academias').get().timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  _firestore.collection('academias').limit(0).get(),
            ),
        _firestore.collection('professionals').get().timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  _firestore.collection('professionals').limit(0).get(),
            ),
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Tempo limite excedido ao carregar anúncios');
        },
      );

      if (!mounted) return;

      final academiasSnapshot = results[0];
      final profissionaisSnapshot = results[1];

      final academias =
          await Future.wait(academiasSnapshot.docs.map((doc) async {
        final data = doc.data();

        final nome = data['nome'] as String? ?? 'Academia';

        final descricao = data['descricao'] as String? ??
            'Descubra nossos serviços e planos.';

        final fotoPerfil = data['fotoPerfilUrl'] as String? ??
            data['fotoUrl'] as String? ??
            'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1200';

        // Tenta obter avaliação do documento, se não tiver, calcula da coleção ratings
        double avaliacao = _parseRating(data['avaliacao'] ?? data['rating']);

        if (avaliacao == 0.0) {
          // Calcula média em tempo real se não estiver no documento
          avaliacao = await _calculateAverageRating(doc.id, 'academia');
        }

        // Busca localização GPS
        double? lat;
        double? lng;
        double? calculatedDistanceKm;
        String distancia = 'Distância não disponível';

        if (data['localizacaoGPS'] != null) {
          final gps = data['localizacaoGPS'] as Map<String, dynamic>;
          lat = (gps['lat'] as num?)?.toDouble();
          lng = (gps['lng'] as num?)?.toDouble();

          // Calcula distância se tiver localização do usuário
          if (lat != null && lng != null && _userPosition != null) {
            calculatedDistanceKm = calcularDistanciaEmKm(
              _userPosition!.latitude,
              _userPosition!.longitude,
              lat,
              lng,
            );

            distancia = '${calculatedDistanceKm.toStringAsFixed(1)} km';
          } else if (lat != null && lng != null) {
            distancia = 'Localização GPS disponível';
          }
        } else {
          // Se não tem GPS, usa o campo de texto antigo
          distancia = data['distancia']?.toString() ??
              data['distance']?.toString() ??
              'Localização não informada';
        }

        return GymAd(
          id: doc.id,
          gymName: nome,
          title: descricao,
          imageUrl: fotoPerfil,
          distance: distancia,
          rating: avaliacao,
          type: 'Academia',
          calculatedDistanceKm: calculatedDistanceKm,
          latitude: lat,
          longitude: lng,
        );
      }));

      final profissionais =
          await Future.wait(profissionaisSnapshot.docs.map((doc) async {
        final data = doc.data();

        final nome = data['nome'] as String? ?? 'Profissional';

        final especialidade = data['especialidade'] as String? ??
            data['descricao'] as String? ??
            'Conheça meu trabalho e resultados.';

        final fotoPerfil = data['fotoUrl'] as String? ??
            'https://cdn-icons-png.flaticon.com/512/149/149071.png';

        // Tenta obter avaliação do documento, se não tiver, calcula da coleção ratings
        double avaliacao = _parseRating(data['avaliacao'] ?? data['rating']);

        if (avaliacao == 0.0) {
          // Calcula média em tempo real se não estiver no documento
          avaliacao = await _calculateAverageRating(doc.id, 'profissional');
        }

        // Busca localização GPS
        double? lat;
        double? lng;
        double? calculatedDistanceKm;
        String distancia = 'Distância não disponível';

        if (data['localizacaoGPS'] != null) {
          final gps = data['localizacaoGPS'] as Map<String, dynamic>;
          lat = (gps['lat'] as num?)?.toDouble();
          lng = (gps['lng'] as num?)?.toDouble();

          // Calcula distância se tiver localização do usuário
          if (lat != null && lng != null && _userPosition != null) {
            calculatedDistanceKm = calcularDistanciaEmKm(
              _userPosition!.latitude,
              _userPosition!.longitude,
              lat,
              lng,
            );

            distancia = '${calculatedDistanceKm.toStringAsFixed(1)} km';
          } else if (lat != null && lng != null) {
            distancia = 'Localização GPS disponível';
          }
        } else {
          // Se não tem GPS, usa o campo de texto antigo
          distancia = data['distancia']?.toString() ??
              data['distance']?.toString() ??
              'Localização não informada';
        }

        return GymAd(
          id: doc.id,
          gymName: nome,
          title: especialidade,
          imageUrl: fotoPerfil,
          distance: distancia,
          rating: avaliacao,
          type: 'Profissional',
          calculatedDistanceKm: calculatedDistanceKm,
          latitude: lat,
          longitude: lng,
        );
      }));

      if (!mounted) return;

      setState(() {
        _allAds = [...academias, ...profissionais];
        _isLoadingAds = false;
      });

      // 🚨 NOVO: Carrega os favoritos APÓS _allAds estar preenchido.
      _loadFavorites();
    } catch (e) {
      debugPrint('Erro ao carregar anúncios: $e');

      if (!mounted) return;

      setState(() {
        _loadError = 'Erro ao carregar cadastros. Tente novamente.';
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

  /// Calcula a média de avaliações de um target em tempo real
  Future<double> _calculateAverageRating(
      String targetId, String targetType) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        return 0.0;
      }

      double sum = 0.0;

      for (var doc in ratingsSnapshot.docs) {
        final ratingValue = doc.data()['rating'];

        if (ratingValue != null) {
          final rating = (ratingValue is num)
              ? ratingValue.toDouble()
              : (double.tryParse(ratingValue.toString()) ?? 0.0);

          sum += rating;
        }
      }

      return (sum / ratingsSnapshot.docs.length).clamp(0.0, 5.0);
    } catch (e) {
      debugPrint('Erro ao calcular média de avaliações: $e');

      return 0.0;
    }
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
      // Filtro de busca por texto
      if (_searchText.isNotEmpty) {
        final searchLower = _searchText.toLowerCase();

        final matchesName = ad.gymName.toLowerCase().contains(searchLower);

        final matchesTitle = ad.title.toLowerCase().contains(searchLower);

        if (!matchesName && !matchesTitle) return false;
      }

      // Filtro por tipo
      if (_selectedType != null && ad.type != _selectedType) {
        return false;
      }

      // Filtro por distância - usa distância calculada se disponível
      double distanceInKm;

      if (ad.calculatedDistanceKm != null) {
        // Usa distância calculada em tempo real
        distanceInKm = ad.calculatedDistanceKm!;
      } else if (ad.latitude != null &&
          ad.longitude != null &&
          _userPosition != null) {
        // Calcula distância agora se tiver coordenadas
        distanceInKm = calcularDistanciaEmKm(
          _userPosition!.latitude,
          _userPosition!.longitude,
          ad.latitude!,
          ad.longitude!,
        );
      } else {
        // Se não tem GPS, tenta parsear do texto (compatibilidade com dados antigos)
        distanceInKm = _parseDistance(ad.distance);
      }

      // Se o filtro de distância está ativo e não tem localização GPS, não mostra
      if (_maxDistance < 10.0 && ad.latitude == null && ad.longitude == null) {
        return false; // Não mostra academias/profissionais sem GPS quando filtro está ativo
      }

      if (distanceInKm > _maxDistance) return false;

      // Filtro por avaliação
      if (ad.rating < _minRating) return false;

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchText = '';
      _selectedType = null;
      _maxDistance = 10.0;
      _minRating = 0.0;
    });
  }

  bool _isFavorite(GymAd ad) => favoriteAds.any((fav) => fav.id == ad.id);

  // 🚨 CORRIGIDO: Função agora persiste no Firestore e atualiza o estado local
  void _toggleFavorite(GymAd ad) {
    if (widget.guestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie uma conta para marcar favoritos.')),
      );
      return;
    }

    final isCurrentlyFavorite = _isFavorite(ad);
    final isAdding = !isCurrentlyFavorite;

    // 1. Atualiza o estado local imediatamente
    setState(() {
      if (isCurrentlyFavorite) {
        favoriteAds.removeWhere((fav) => fav.id == ad.id);
      } else {
        favoriteAds.add(ad);
      }
    });

    // 2. Persiste a mudança no Firestore de forma assíncrona
    _updateFavoriteInFirestore(ad.id, isAdding);
  }

  void _onTapAd(GymAd ad) async {
    if (widget.guestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Crie uma conta para visualizar detalhes.')),
      );

      return;
    }

    if (ad.type == 'Academia') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeAcademiaPage(academiaId: ad.id),
        ),
      );
    } else if (ad.type == 'Profissional') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeProfissionalPage(profissionalId: ad.id),
        ),
      );
    }

    // Recarrega os dados quando volta da página de perfil
    // Isso garante que as avaliações atualizadas sejam refletidas
    // E recarrega os favoritos caso tenham sido alterados (embora o _loadAds já chame _loadFavorites)
    if (mounted) {
      _loadAds();
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
          // Só mostra notificações se o usuário estiver autenticado
          if (!widget.guestMode && FirebaseAuth.instance.currentUser != null)
            NotificationsButton(
                currentUserId: FirebaseAuth.instance.currentUser?.uid),

          // Mostra botão de login para visitantes ou logout para usuários autenticados
          if (widget.guestMode || FirebaseAuth.instance.currentUser == null)
            IconButton(
              icon: const Icon(Icons.login, color: Colors.white),
              tooltip: 'Fazer Login',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginPage(userType: 'Usuário')),
                );
              },
            )
          else
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
            UserAccountsDrawerHeader(
              accountName: _isLoadingUserData
                  ? const Text('Carregando...',
                      style: TextStyle(color: Colors.white70))
                  : Text(
                      _userName ?? (widget.guestMode ? 'Visitante' : 'Usuário'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
              accountEmail: Text(
                  _userEmail ??
                      (widget.guestMode
                          ? 'Modo Visitante'
                          : 'Toque aqui para editar seu perfil'),
                  style: const TextStyle(color: Colors.white70)),
              currentAccountPicture: _isLoadingUserData
                  ? const Center(
                      child: SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.red.shade900,
                      // Se houver foto, usa NetworkImage; senão, usa a default ou Asset.
                      backgroundImage: (_userProfilePicUrl != null &&
                                  _userProfilePicUrl!.isNotEmpty
                              ? NetworkImage(_userProfilePicUrl!)
                              : const AssetImage('assets/default_profile.png'))
                          as ImageProvider,
                      child: _userProfilePicUrl == null ||
                              _userProfilePicUrl!.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 40)
                          : null,
                    ),
              decoration: BoxDecoration(color: Colors.red.shade700),
              // Permite editar o perfil ao clicar no header
              onDetailsPressed: widget.guestMode
                  ? null
                  : () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditarPerfilUsuarioPage(),
                        ),
                      ).then((_) {
                        // Recarrega os dados do usuário ao voltar
                        _loadUserData();
                      });
                    },
            ),
            _buildDrawerItem('Home', Icons.home, () => Navigator.pop(context)),
            _buildDrawerItem('Favoritos', Icons.favorite, () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FavoritesPage(
                    favorites: favoriteAds,
                    // Garante que a lista de favoritos seja atualizada localmente ao voltar da página
                    onFavoritesChanged: (updatedFavorites) {
                      setState(() => favoriteAds = updatedFavorites);
                      // O Firestore já foi atualizado pelo _toggleFavorite
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

              // Abre a modal específica para usuários
              showDialog(
                context: context,
                builder: (context) => const MinhaRedeUsuario(),
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
            _buildDrawerItem('Área Fitness', Icons.fitness_center, () {
              Navigator.pop(context);

              if (widget.guestMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Crie uma conta para acessar sua área fitness.'),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserFitnessSelectionPage(),
                ),
              );
            }),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kIsWeb ? 1200 : double.infinity,
          ),
          child: ListView(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
                            label: _minRating > 0
                                ? _minRating.toStringAsFixed(1)
                                : 'Sem filtro',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _minRating > 0
                                ? _minRating.toStringAsFixed(1)
                                : 'Todas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Botão limpar filtros
                    if (_selectedType != null ||
                        _minRating > 0 ||
                        _maxDistance < 10.0)
                      Center(
                        child: TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear, color: Colors.red),
                          label: const Text(
                            'Limpar filtros',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Feed de posts de conexões
              if (!widget.guestMode)
                ConnectedPostsFeed(
                  currentUserId: FirebaseAuth.instance.currentUser?.uid,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.red.shade700 : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? Colors.red : Colors.grey.shade300,
        width: selected ? 2 : 1,
      ),
    );
  }
}
