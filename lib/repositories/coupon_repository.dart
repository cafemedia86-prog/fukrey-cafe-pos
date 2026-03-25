
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/coupon_model.dart';

final couponRepositoryProvider = Provider((ref) => CouponRepository(Supabase.instance.client));

class CouponRepository {
  final SupabaseClient _supabase;

  CouponRepository(this._supabase);

  Future<CouponModel?> getCouponByCode(String code) async {
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) return null;
      return CouponModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<List<CouponModel>> getCoupons() async {
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false);
      return (data as List).map((json) => CouponModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addCoupon(Map<String, dynamic> couponData) async {
    await _supabase.from('coupons').insert(couponData);
  }

  Future<void> deleteCoupon(String id) async {
    await _supabase.from('coupons').delete().eq('id', id);
  }
}

final couponsProvider = FutureProvider<List<CouponModel>>((ref) {
  return ref.watch(couponRepositoryProvider).getCoupons();
});
