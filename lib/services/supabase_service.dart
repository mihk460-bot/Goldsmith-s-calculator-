// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fetch shop by id from 'shops' table
  Future<ShopModel?> getShopById(String shopId) async {
    try {
      final res = await _client.from('shops').select().eq('id', shopId).maybeSingle();
      if (res == null) return null;
      if (res is Map<String, dynamic>) return ShopModel.fromMap(res);
      return null;
    } catch (e) {
      // ignore
      return null;
    }
  }

  // Update devices array for a shop
  Future<bool> updateShopDevices(String shopId, List<String> devices) async {
    try {
      final r = await _client.from('shops').update({
        'devices': devices,
      }).eq('id', shopId).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }

  // Reset devices list
  Future<bool> resetShopDevices(String shopId) async {
    try {
      final r = await _client.from('shops').update({
        'devices': <String>[],
      }).eq('id', shopId).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }

  // Create activation code
  Future<bool> createActivationCode(String code, int daysValid) async {
    try {
      final expiresAt = DateTime.now().add(Duration(days: daysValid)).toIso8601String();
      final r = await _client.from('activation_codes').insert({
        'code': code,
        'expires_at': expiresAt,
        'used': false,
      }).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }

  // Validate activation code
  Future<bool> validateAndConsumeActivationCode(String code, String shopId) async {
    try {
      final r = await _client.from('activation_codes').select().eq('code', code).maybeSingle();
      if (r == null) return false;
      if (r is Map<String, dynamic>) {
        if (r['used'] == true) return false;
        final expires = DateTime.tryParse(r['expires_at']?.toString() ?? '');
        if (expires == null || expires.isBefore(DateTime.now())) return false;
        // mark used and attach to shop
        final upd = await _client.from('activation_codes').update({
          'used': true,
          'used_by': shopId,
          'used_at': DateTime.now().toIso8601String(),
        }).eq('code', code).execute();
        return upd.error == null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Set failed attempts counter on shop
  Future<bool> setFailedAttempts(String shopId, int count) async {
    try {
      final r = await _client.from('shops').update({
        'failed_attempts': count,
      }).eq('id', shopId).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }

  // Block a shop for a duration
  Future<bool> blockShop(String shopId, Duration duration) async {
    try {
      final until = DateTime.now().add(duration).toIso8601String();
      final r = await _client.from('shops').update({
        'is_blocked': true,
        'blocked_until': until,
      }).eq('id', shopId).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }

  // Unblock shop
  Future<bool> unblockShop(String shopId) async {
    try {
      final r = await _client.from('shops').update({
        'is_blocked': false,
        'blocked_until': null,
        'failed_attempts': 0,
      }).eq('id', shopId).execute();
      return r.error == null;
    } catch (e) {
      return false;
    }
  }
}
