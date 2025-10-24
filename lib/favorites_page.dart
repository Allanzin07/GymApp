import 'package:flutter/material.dart';
import 'ads_carousel.dart'; // para poder usar GymAd

class FavoritesPage extends StatelessWidget {
  final List<GymAd> favorites;

  const FavoritesPage({super.key, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Favoritos"),
        backgroundColor: Colors.red,
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Text(
                "Nenhum anúncio favoritado ainda",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final ad = favorites[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Image.network(ad.imageUrl, width: 60, fit: BoxFit.cover),
                    title: Text(ad.gymName),
                    subtitle: Text(ad.title),
                    trailing: const Icon(Icons.favorite, color: Colors.red),
                  ),
                );
              },
            ),
    );
  }
}
