// lib/screens/admin_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _shops = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final res = await client.from('shops').select();
      if (res is List) {
        setState(() => _shops = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetDevices(String shopId) async {
    final ok = await _supabaseService.resetShopDevices(shopId);
    if (ok) _loadShops();
  }

  Future<void> _unblock(String shopId) async {
    final ok = await _supabaseService.unblockShop(shopId);
    if (ok) _loadShops();
  }

  Future<void> _createCodeDialog() async {
    final codeCtl = TextEditingController();
    final daysCtl = TextEditingController(text: '30');
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('إنشاء كود تفعيل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtl, decoration: const InputDecoration(labelText: 'الكود')),
              TextField(controller: daysCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدة بالأيام')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () async {
                  final code = codeCtl.text.trim();
                  final days = int.tryParse(daysCtl.text) ?? 30;
                  if (code.isNotEmpty) {
                    final ok = await _supabaseService.createActivationCode(code, days);
                    if (ok) Navigator.of(context).pop();
                  }
                },
                child: const Text('إنشاء'))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الأدمن'),
          actions: [
            IconButton(onPressed: _createCodeDialog, icon: const Icon(Icons.add)),
            IconButton(onPressed: _loadShops, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _shops.length,
                itemBuilder: (context, i) {
                  final s = _shops[i];
                  final id = s['id']?.toString() ?? '';
                  final name = s['name']?.toString() ?? id;
                  final devices = (s['devices'] as List?)?.length ?? 0;
                  final expiry = s['subscription_end']?.toString() ?? '-';
                  final blocked = s['is_blocked'] == true;
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('أجهزة: $devices • انتهاء: $expiry'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (blocked)
                            IconButton(onPressed: () => _unblock(id), icon: const Icon(Icons.lock_open))
                          else
                            IconButton(onPressed: () => _resetDevices(id), icon: const Icon(Icons.clear)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
