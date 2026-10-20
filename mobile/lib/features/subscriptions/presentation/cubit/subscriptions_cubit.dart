import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';

/// États de la liste d'abonnements — classes simples (pas de freezed
/// nécessaire ici : l'état tient en un champ).
sealed class SubscriptionsState extends Equatable {
  const SubscriptionsState();

  /// Liste déjà connue (utile pendant le chargement initial :
  /// les squelettes affichent des placeholders).
  List<Subscription>? get subscriptions => switch (this) {
    SubscriptionsLoaded(:final items) => items,
    _ => null,
  };
}

class SubscriptionsInitial extends SubscriptionsState {
  const SubscriptionsInitial();
  @override
  List<Object?> get props => [];
}

class SubscriptionsLoading extends SubscriptionsState {
  const SubscriptionsLoading();
  @override
  List<Object?> get props => [];
}

class SubscriptionsLoaded extends SubscriptionsState {
  const SubscriptionsLoaded(this.items);
  final List<Subscription> items;
  @override
  List<Object?> get props => [items];
}

class SubscriptionsError extends SubscriptionsState {
  const SubscriptionsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Cubit des abonnements : singleton — les onglets Accueil,
/// Abonnements, Calendrier et Rapports lisent la MÊME source.
class SubscriptionsCubit extends Cubit<SubscriptionsState> {
  SubscriptionsCubit(this._repository) : super(const SubscriptionsInitial());

  final SubscriptionRepository _repository;
  bool _requested = false;

  /// Chargement idempotent : appelé par chaque onglet, exécuté une fois.
  Future<void> ensureLoaded() {
    if (_requested) return Future.value();
    _requested = true;
    return refresh();
  }

  Future<void> refresh() async {
    emit(const SubscriptionsLoading());
    final result = await _repository.getSubscriptions();
    emit(switch (result) {
      Ok(value: final list) => SubscriptionsLoaded(list),
      Err(failure: final f) => SubscriptionsError(f.message),
    });
    if (result case Ok(value: final list)) {
      // Replanifie les rappels locaux d'échéances.
      unawaited(
        getIt<NotificationService>().scheduleDueReminders(list),
      );
    }
  }

  /// Marque une échéance comme payée — met à jour la liste en place.
  Future<Result<Subscription>> markPaid(Subscription sub) async {
    final result = await _repository.markPaid(sub.id);
    if (result case Ok(value: final updated)) {
      final current = state.subscriptions ?? [];
      final next = [
        for (final s in current)
          if (s.id == updated.id) updated else s,
      ];
      emit(SubscriptionsLoaded(next));
      unawaited(
        getIt<NotificationService>().scheduleDueReminders(next),
      );
    }
    return result;
  }

  /// Supprime un abonnement — retiré de la liste en place.
  Future<Result<void>> delete(Subscription sub) async {
    final result = await _repository.deleteSubscription(sub.id);
    if (result is Ok) {
      final current = state.subscriptions ?? [];
      final next = [for (final s in current) if (s.id != sub.id) s];
      emit(SubscriptionsLoaded(next));
      unawaited(
        getIt<NotificationService>().scheduleDueReminders(next),
      );
    }
    return result;
  }

  /// Retrouve un abonnement par id dans l'état courant.
  Subscription? byId(String id) {
    for (final s in state.subscriptions ?? const <Subscription>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<Result<Subscription>> create({
    required String name,
    required String provider,
    required SubscriptionCategory category,
    required double amount,
    required DateTime nextDueDate,
    required BillingCycle cycle,
    String? currency,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? dueTime,
  }) async {
    final result = await _repository.createSubscription(
      name: name,
      provider: provider,
      category: category,
      amount: amount,
      nextDueDate: nextDueDate,
      cycle: cycle,
      currency: currency,
      description: description,
      startDate: startDate,
      endDate: endDate,
      dueTime: dueTime,
    );
    if (result case Ok(value: final created)) {
      final current = state.subscriptions ?? [];
      final next = [...current, created];
      emit(SubscriptionsLoaded(next));
      unawaited(
        getIt<NotificationService>().scheduleDueReminders(next),
      );
    }
    return result;
  }

  /// Modification complète d'un abonnement existant.
  Future<Result<Subscription>> update({
    required String id,
    String? name,
    String? provider,
    SubscriptionCategory? category,
    double? amount,
    DateTime? nextDueDate,
    BillingCycle? cycle,
    String? currency,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? dueTime,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDueTime = false,
  }) async {
    final result = await _repository.updateSubscription(
      id: id,
      name: name,
      provider: provider,
      category: category,
      amount: amount,
      nextDueDate: nextDueDate,
      cycle: cycle,
      currency: currency,
      description: description,
      startDate: startDate,
      endDate: endDate,
      dueTime: dueTime,
      clearStartDate: clearStartDate,
      clearEndDate: clearEndDate,
      clearDueTime: clearDueTime,
    );
    if (result case Ok(value: final updated)) {
      final current = state.subscriptions ?? [];
      final next = [
        for (final s in current) s.id == updated.id ? updated : s,
      ];
      emit(SubscriptionsLoaded(next));
      unawaited(
        getIt<NotificationService>().scheduleDueReminders(next),
      );
    }
    return result;
  }
}
