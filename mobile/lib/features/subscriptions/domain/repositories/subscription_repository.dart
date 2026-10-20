import 'package:flutter/material.dart' show TimeOfDay;

import '../../../../core/utils/result.dart';
import '../entities/subscription.dart';

/// Contrat domaine : ce dont l'UI a besoin, sans détail technique.
abstract class SubscriptionRepository {
  Future<Result<List<Subscription>>> getSubscriptions();

  Future<Result<Subscription>> createSubscription({
    required String name,
    required String provider,
    required SubscriptionCategory category,
    required double amount,
    required DateTime nextDueDate,
    required BillingCycle cycle,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? dueTime,
  });

  /// Modifie un abonnement existant (PATCH partiel).
  /// clearStartDate/clearEndDate/clearDueTime servent à effacer une valeur.
  Future<Result<Subscription>> updateSubscription({
    required String id,
    String? name,
    String? provider,
    SubscriptionCategory? category,
    double? amount,
    DateTime? nextDueDate,
    BillingCycle? cycle,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? dueTime,
    bool clearStartDate,
    bool clearEndDate,
    bool clearDueTime,
  });

  /// Marque un abonnement comme payé (PATCH status).
  Future<Result<Subscription>> markPaid(String id);

  /// Supprime définitivement un abonnement.
  Future<Result<void>> deleteSubscription(String id);
}
