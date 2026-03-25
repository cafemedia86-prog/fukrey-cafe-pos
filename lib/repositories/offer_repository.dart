import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Offer {
  final String id;
  final String imageUrl;
  final String? title;
  final int displayOrder;
  final bool isActive;

  Offer({
    required this.id,
    required this.imageUrl,
    this.title,
    required this.displayOrder,
    required this.isActive,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      imageUrl: json['image_url'],
      title: json['title'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class OfferRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Offer>> getOffers() async {
    try {
      final response = await _client
          .from('offers')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      
      return (response as List).map((e) => Offer.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching offers: $e');
      return [];
    }
  }

  Future<void> addOffer(String imageUrl, {String? title}) async {
    await _client.from('offers').insert({
      'image_url': imageUrl,
      'title': title,
    });
  }

  Future<void> deleteOffer(String id) async {
    await _client.from('offers').delete().eq('id', id);
  }
}

final offerRepositoryProvider = Provider((ref) => OfferRepository());

final offersProvider = FutureProvider<List<Offer>>((ref) async {
  return ref.watch(offerRepositoryProvider).getOffers();
});
