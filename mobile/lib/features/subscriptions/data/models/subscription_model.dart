import 'package:flutter/material.dart';

import '../../domain/entities/subscription.dart';

/// Modèle JSON ↔ entité. Le snake_case correspond au contrat Django.
class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.name,
    required super.provider,
    required super.category,
    required super.amount,
    required super.nextDueDate,
    required super.cycle,
    required super.status,
    super.currency,
    super.description,
    super.startDate,
    super.endDate,
    super.dueTime,
  });

  /// "14:30:00" (DRF TimeField) → TimeOfDay.
  static TimeOfDay? _parseTime(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      provider: json['provider'] as String? ?? '',
      category: SubscriptionCategory.parse(json['category'] as String? ?? ''),
      // DRF sérialise les Decimal en string ("48500.00") :
      // on accepte les deux formes.
      amount: double.parse(json['amount'].toString()),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      cycle: BillingCycle.values.firstWhere(
        (c) => c.name == json['cycle'],
        orElse: () => BillingCycle.monthly,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubscriptionStatus.dueSoon,
      ),
      currency: json['currency'] as String? ?? 'XAF',
      description: json['description'] as String? ?? '',
      startDate: json['start_date'] is String
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] is String
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      dueTime: _parseTime(json['due_time']),
    );
  }
}
