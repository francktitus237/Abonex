import '../../features/workspace/data/datasources/workspace_remote_datasource.dart';

/// Conversion de montants vers la devise locale de l'utilisateur.
/// Les taux viennent de l'endpoint backend /rates/ (taux réels,
/// cache 12 h serveur). Ici on garde un cache mémoire par devise.
class CurrencyConverter {
  CurrencyConverter(this._datasource);

  final WorkspaceRemoteDataSource _datasource;
  final Map<String, Map<String, double>> _cache = {};

  /// Taux pour `base` : rates[USD]=0.0016 → 1 BASE = 0.0016 USD.
  /// Retourne null si le service est indisponible (hors-ligne…).
  Future<Map<String, double>?> _ratesFor(String base) async {
    if (_cache.containsKey(base)) return _cache[base];
    try {
      final rates = await _datasource.exchangeRates(base);
      _cache[base] = rates;
      return rates;
    } on Exception {
      return null;
    }
  }

  /// Convertit `amount` exprimé en `currency` vers `target`.
  /// Ex. 45 USD → XAF : 45 / rates[USD].
  /// Retourne null si la conversion est impossible.
  Future<double?> convert(
    double amount,
    String currency,
    String target,
  ) async {
    if (currency == target) return amount;
    final rates = await _ratesFor(target);
    if (rates == null) return null;
    final rate = rates[currency];
    if (rate == null || rate == 0) return null;
    return amount / rate;
  }

  /// Somme d'une liste de montants hétéro-devises convertie
  /// dans la devise cible. Les montants non convertibles
  /// sont ignorés (plutôt que fausser le total).
  Future<double> convertAll(
    Iterable<({double amount, String currency})> amounts,
    String target,
  ) async {
    var total = 0.0;
    for (final a in amounts) {
      total += await convert(a.amount, a.currency, target) ?? 0;
    }
    return total;
  }
}
