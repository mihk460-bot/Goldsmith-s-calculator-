// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';
import '../services/device_service.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final DeviceService _deviceService = DeviceService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final phone = _phoneController.text.trim();
    try {
      // If admin password entered in phone field -> open admin
      if (phone == adminPassword) {
        Navigator.of(context).pushReplacementNamed('/admin');
        return;
      }

      if (phone.isEmpty) {
        setState(() {
          _error = 'ادخل رقم المحل أو رقم الهاتف';
          _loading = false;
        });
        return;
      }

      final shopId = phone; // We treat entered phone as shop id for this app

      // Check device allowed
      final blocked = await _deviceService.isBlocked(shopId);
      if (blocked) {
        setState(() {
          _error = 'هذا الجهاز محظور مؤقتاً بعد محاولات خاطئة';
          _loading = false;
        });
        return;
      }

      final allowed = await _deviceService.isDeviceAllowed(shopId);
      if (!allowed) {
        setState(() {
          _error = 'هذا الجهاز غير مسجل أو تجاوز حد الأجهزة المسموح به';
          _loading = false;
        });
        return;
      }

      // register device if not already
      await _deviceService.registerDeviceForShop(shopId);

      // save shopId locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_id', shopId);

      Navigator.of(context).pushReplacementNamed('/calculator');
    } catch (e) {
      setState(() {
        _error = 'فشل تسجيل الدخول';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل الدخول'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'أدخل رقم المحل أو الهاتف',
                style: TextStyle(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.text,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  hintText: 'مثال: 0123456789 أو معرف المحل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const CircularProgressIndicator() : const Text('دخول'),
              ),
              const SizedBox(height: 12),
              Text(
                'لو كنت المسؤول، ادخل كلمة مرور الأدمن في حقل رقم الهاتف لفتح لوحة الأدمن',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
