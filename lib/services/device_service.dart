// lib/services/device_service.dart

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_model.dart';
import 'supabase_service.dart';

class DeviceService {
  static const int maxDevicesPerShop = 3;
  static const int maxFailedAttempts = 5;
  static const int blockHours = 24;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SupabaseService _supabase = SupabaseService();

  // Returns a stable device id for identifying the device
  Future<String> getDeviceId() async {
    // Try platform specific ids
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        if (info.id != null && info.id!.isNotEmpty) return info.id!; // androidId
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        if (info.identifierForVendor != null && info.identifierForVendor!.isNotEmpty) {
          return info.identifierForVendor!;
        }
      }
    } catch (_) {
      // ignore
    }

    // Fallback: use secure storage to persist a generated id
    const key = 'gold_calc_device_id';
    var id = await _secureStorage.read(key: key);
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (Platform.operatingSystem);
      await _secureStorage.write(key: key, value: id);
    }
    return id;
  }

  // Check if the device is allowed for the shop (checks Supabase shop record)
  Future<bool> isDeviceAllowed(String shopId) async {
    final deviceId = await getDeviceId();
    final shop = await _supabase.getShopById(shopId);
    if (shop == null) return false;

    // If shop is blocked, immediately disallow
    if (shop.isBlocked) return false;

    // If device already registered -> allowed
    if (shop.devices.contains(deviceId)) return true;

    // If shop has fewer than max devices, allow (but caller should register)
    if (shop.devices.length < maxDevicesPerShop) return true;

    // Otherwise disallow
    return false;
  }

  // Register current device for the given shop (adds to Supabase devices list)
  Future<bool> registerDeviceForShop(String shopId) async {
    final deviceId = await getDeviceId();
    try {
      final shop = await _supabase.getShopById(shopId);
      if (shop == null) return false;
      final devices = List<String>.from(shop.devices);
      if (!devices.contains(deviceId)) {
        if (devices.length >= maxDevicesPerShop) return false;
        devices.add(deviceId);
        final ok = await _supabase.updateShopDevices(shopId, devices);
        return ok;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Failed attempts handling (local + optional supabase sync)
  Future<int> incrementFailedAttempt(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final key = 'failed_attempts_${shopId}_$deviceId';
    final current = prefs.getInt(key) ?? 0;
    final updated = current + 1;
    await prefs.setInt(key, updated);

    if (updated >= maxFailedAttempts) {
      // block on Supabase as well
      await _supabase.blockShop(shopId, Duration(hours: blockHours));
      // store blocked timestamp
      final blockedKey = 'blocked_until_${shopId}_$deviceId';
      final until = DateTime.now().add(const Duration(hours: blockHours)).toIso8601String();
      await prefs.setString(blockedKey, until);
    }

    // also update remote counter (optional)
    await _supabase.setFailedAttempts(shopId, updated);
    return updated;
  }

  Future<void> resetFailedAttempts(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final key = 'failed_attempts_${shopId}_$deviceId';
    await prefs.remove(key);
    await _supabase.setFailedAttempts(shopId, 0);
    final blockedKey = 'blocked_until_${shopId}_$deviceId';
    await prefs.remove(blockedKey);
  }

  Future<bool> isBlocked(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await getDeviceId();
    final blockedKey = 'blocked_until_${shopId}_$deviceId';
    final untilStr = prefs.getString(blockedKey);
    if (untilStr == null) return false;
    final until = DateTime.tryParse(untilStr);
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      // expired -> clear
      await prefs.remove(blockedKey);
      return false;
    }
    return true;
  }
}
