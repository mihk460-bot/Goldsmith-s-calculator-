// lib/models/shop_model.dart

class ShopModel {
  final String id;
  final String name;
  final List<String> devices;
  final DateTime? subscriptionEnd;
  final bool isBlocked;
  final int failedAttempts;

  ShopModel({
    required this.id,
    required this.name,
    this.devices = const [],
    this.subscriptionEnd,
    this.isBlocked = false,
    this.failedAttempts = 0,
  });

  factory ShopModel.fromMap(Map<String, dynamic> m) {
    return ShopModel(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      devices: (m['devices'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subscriptionEnd: m['subscription_end'] == null
          ? null
          : DateTime.tryParse(m['subscription_end'].toString()),
      isBlocked: m['is_blocked'] == true,
      failedAttempts: (m['failed_attempts'] is int)
          ? m['failed_attempts'] as int
          : int.tryParse(m['failed_attempts']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'devices': devices,
        'subscription_end': subscriptionEnd?.toIso8601String(),
        'is_blocked': isBlocked,
        'failed_attempts': failedAttempts,
      };
}
