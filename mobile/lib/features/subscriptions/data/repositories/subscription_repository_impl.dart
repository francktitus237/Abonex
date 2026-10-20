import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';

/// Traduit les exceptions réseau en Failure métier.
/// Toutes les données viennent de l'API Django — pas de mode démo.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({required this._remote});

  final SubscriptionRemoteDataSource _remote;

  @override
  Future<Result<List<Subscription>>> getSubscriptions() async {
    try {
      return Ok(await _remote.list());
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
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
  }) async {
    try {
      return Ok(
        await _remote.create({
          'name': name,
          'provider': provider,
          'category': category.name,
          'amount': amount,
          'start_date': startDate?.toIso8601String().substring(0, 10),
          'next_due_date': nextDueDate.toIso8601String().substring(0, 10),
          'due_time': dueTime == null ? null : _timeToJson(dueTime),
          'end_date': endDate?.toIso8601String().substring(0, 10),
          'cycle': cycle.name,
          'currency': currency ?? 'XAF',
        }),
      );
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
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
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearDueTime = false,
  }) async {
    try {
      return Ok(
        await _remote.update(id, {
          'name': ?name,
          'provider': ?provider,
          'category': ?category?.name,
          'amount': ?amount,
          if (nextDueDate != null)
            'next_due_date': nextDueDate.toIso8601String().substring(0, 10),
          if (clearDueTime)
            'due_time': null
          else if (dueTime != null)
            'due_time': _timeToJson(dueTime),
          'cycle': ?cycle?.name,
          'currency': ?currency,
          if (clearStartDate)
            'start_date': null
          else if (startDate != null)
            'start_date': startDate.toIso8601String().substring(0, 10),
          if (clearEndDate)
            'end_date': null
          else if (endDate != null)
            'end_date': endDate.toIso8601String().substring(0, 10),
        }),
      );
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Subscription>> markPaid(String id) async {
    try {
      return Ok(await _remote.updateStatus(id, 'paid'));
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> deleteSubscription(String id) async {
    try {
      await _remote.delete(id);
      return const Ok(null);
    } on DioException catch (e) {
      return Err(_toFailure(ApiException.fromDio(e)));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  /// TimeOfDay → "HH:MM" accepté par le TimeField DRF.
  String _timeToJson(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Failure _toFailure(ApiException e) => switch (e.statusCode) {
    400 => ValidationFailure(e.message, fieldErrors: e.fieldErrors),
    401 || 403 => AuthFailure(e.message),
    null => const NetworkFailure(),
    _ => ServerFailure(e.message, statusCode: e.statusCode),
  };
}
