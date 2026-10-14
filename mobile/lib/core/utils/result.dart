import '../errors/failure.dart';

/// Résultat d'une opération : soit une valeur (`Ok`), soit une `Failure` (`Err`).
///
/// On évite les exceptions comme mécanisme de retour : le `switch` exhaustif
/// force l'appelant à traiter explicitement le cas d'erreur.
///
/// ```dart
/// switch (await repo.login(...)) {
///   case Ok(value: final user): ...
///   case Err(failure: final f): ...
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
