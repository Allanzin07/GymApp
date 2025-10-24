// lib/ads_carousel.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GymAd {
  final String id;
  final String gymName;
  final String title;
  final String imageUrl;
  final String distance;
  final double rating;
  final String type; // 'Academia' ou 'Profissional'

  GymAd({
    required this.id,
    required this.gymName,
    required this.title,
    required this.imageUrl,
    required this.distance,
    required this.rating,
    this.type = 'Academia',
  });
}


/// AdsCarousel agora aceita:
/// - ads: lista de anúncios
/// - onTapAd: callback quando o card é tocado
/// - onFavorite: callback quando o coração é tocado (toggle)
/// - isFavorite: função que retorna bool para saber se o ad está favoritado
class AdsCarousel extends StatelessWidget {
  final List<GymAd> ads;
  final void Function(GymAd)? onTapAd;
  final void Function(GymAd)? onFavorite;
  final bool Function(GymAd)? isFavorite;

  const AdsCarousel({
    Key? key,
    required this.ads,
    this.onTapAd,
    this.onFavorite,
    this.isFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Nenhum anúncio disponível',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          final fav = isFavorite?.call(ad) ?? false;

          return _AdCard(
            ad: ad,
            isFavorite: fav,
            onTap: () => onTapAd?.call(ad),
            onFavorite: () => onFavorite?.call(ad),
          );
        },
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final GymAd ad;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  const _AdCard({
    Key? key,
    required this.ad,
    required this.isFavorite,
    this.onTap,
    this.onFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, top: 8, bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              children: [
                // Imagem em background (com cache e placeholder)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: ad.imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Icon(Icons.broken_image, color: Colors.red.shade700, size: 40),
                      ),
                    ),
                  ),
                ),

                // Gradiente inferior para legibilidade do texto
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Conteúdo do card
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ad.gymName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ad.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // distância
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(ad.distance, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          // botão favorito (usa callbacks passados)
                          InkWell(
                            onTap: onFavorite,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
