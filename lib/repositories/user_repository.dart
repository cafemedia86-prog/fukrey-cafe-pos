
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userRepositoryProvider = Provider((ref) => UserRepository(Supabase.instance.client));

class UserModel {
  final String id;
  final String email;
  final String role; // 'admin', 'staff', or 'customer'
  final String? outletId;
  final String? fullName;
  final String? phone;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.outletId,
    this.fullName,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      outletId: json['outlet_id'],
      fullName: json['full_name'],
      phone: json['phone'],
    );
  }
}

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      print('DEBUG: [UserRepository] Error fetching profile: $e');
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final List<dynamic> data = await _supabase
          .from('profiles')
          .select()
          .order('email');
      
      return data.map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> signUpCustomer({
    required String email, 
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'role': 'customer',
      },
    );

    if (response.user != null) {
      // The trigger 'on_auth_user_created' in Supabase will create the profile.
      // We manually update it here just to be sure metadata is synced 
      // if the trigger doesn't handle all fields yet.
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'role': 'customer',
      }).eq('id', response.user!.id);
    }
  }

  Future<void> updateUser(String userId, {
    String? role, 
    String? outletId,
    String? fullName,
    String? phone,
  }) async {
    final Map<String, dynamic> updates = {};
    if (role != null) updates['role'] = role;
    if (outletId != null) updates['outlet_id'] = outletId;
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    }
  }
}

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.watch(userRepositoryProvider).getAllUsers();
});

final outletsRepoProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final data = await supabase.from('outlets').select();
  return List<Map<String, dynamic>>.from(data);
});
