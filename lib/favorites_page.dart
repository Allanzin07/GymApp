import 'package:flutter/material.dart';
import 'ads_carousel.dart'; // para usar GymAd

class FavoritesPage extends StatefulWidget {
  final List<GymAd> favorites;
  final Function(List<GymAd>) onFavoritesChanged;

  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.onFavoritesChanged,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<GymAd> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = List.from(widget.favorites);
  }

  void _removeFavorite(GymAd ad) {
    setState(() {
      _favorites.removeWhere((item) => item.id == ad.id);
    });
    widget.onFavoritesChanged(_favorites);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ad.gymName} removido dos favoritos'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Favoritos"),
        backgroundColor: Colors.red,
      ),
      body: _favorites.isEmpty
          ? const Center(
              child: Text(
                "Nenhum anúncio favoritado ainda",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final ad = _favorites[index];
                return Dismissible(
                  key: Key(ad.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeFavorite(ad),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Image.network(ad.imageUrl, width: 60, fit: BoxFit.cover),
                      title: Text(ad.gymName),
                      subtitle: Text(ad.title),
                      trailing: const Icon(Icons.favorite, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
