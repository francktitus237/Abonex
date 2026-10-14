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
  });

  /// Marque un abonnement comme payé (PATCH status).
  Future<Result<Subscription>> markPaid(String id);

  /// Supprime définitivement un abonnement.
  Future<Result<void>> deleteSubscription(String id);
}
