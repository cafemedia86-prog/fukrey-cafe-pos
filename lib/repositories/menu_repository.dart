
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';
import '../core/constants.dart';

class MenuRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final Map<String, List<MenuItem>> _cache = {};

  Future<List<MenuItem>> getMenuItems({String? outletId}) async {
    final cacheKey = outletId ?? 'all';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final response = await _client
          .from('menu_items')
          .select()
          .eq('is_available', true);
      final items = (response as List).map((e) => MenuItem.fromJson(e)).toList();
      _cache[cacheKey] = items;
      return items;
    } catch (e) {
      return [];
    }
  }

  void clearCache() => _cache.clear();
}

final menuRepositoryProvider = Provider((ref) => MenuRepository());

final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  return ref.watch(menuRepositoryProvider).getMenuItems();
});

final outletMenuItemsProvider = FutureProvider.family<List<MenuItem>, String>((ref, outletId) async {
  // Handle 'general' outletId bypass for development
  if (outletId == 'general') {
    return ref.watch(menuRepositoryProvider).getMenuItems(); // Fetch all items if 'general'
  }
  return ref.watch(menuRepositoryProvider).getMenuItems(outletId: outletId);
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('categories').select();
  return List<Map<String, dynamic>>.from(response as List);
});
