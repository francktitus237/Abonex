import 'package:dio/dio.dart';

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
  }) async {
    try {
      return Ok(
        await _remote.create({
          'name': name,
          'provider': provider,
          'category': category.name,
          'amount': amount,
          'next_due_date': nextDueDate.toIso8601String().substring(0, 10),
          'cycle': cycle.name,
          'currency': 'XAF',
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

  Failure _toFailure(ApiException e) => switch (e.statusCode) {
    400 => ValidationFailure(e.message, fieldErrors: e.fieldErrors),
    401 || 403 => AuthFailure(e.message),
    null => const NetworkFailure(),
    _ => ServerFailure(e.message, statusCode: e.statusCode),
  };
}
