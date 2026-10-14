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
  });

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
    );
  }
}
