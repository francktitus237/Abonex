/// Données pays/devise/langue pour la configuration de premier
/// démarrage et l'automatisation de la devise locale.
/// Couvre les cibles : Afrique, UE, Asie, Amériques.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.currency,
    required this.currencySymbol,
    required this.languages,
  });

  /// Code ISO 3166-1 alpha-2.
  final String code;
  final String name;

  /// Code ISO 4217 (XAF, EUR, USD…).
  final String currency;
  final String currencySymbol;

  /// Langues principales du pays (codes ISO 639-1), première = défaut.
  final List<String> languages;
}

abstract final class AppCountries {
  static const all = [
    // --- Afrique ---
    Country(code: 'CM', name: 'Cameroun', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr', 'en']),
    Country(code: 'CI', name: 'Côte d\'Ivoire', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'SN', name: 'Sénégal', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'GA', name: 'Gabon', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'CG', name: 'Congo', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'CD', name: 'RD Congo', currency: 'CDF', currencySymbol: 'FC', languages: ['fr']),
    Country(code: 'BJ', name: 'Bénin', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'BF', name: 'Burkina Faso', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'TG', name: 'Togo', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'ML', name: 'Mali', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'NE', name: 'Niger', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'TD', name: 'Tchad', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'GQ', name: 'Guinée équatoriale', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr', 'es']),
    Country(code: 'MG', name: 'Madagascar', currency: 'MGA', currencySymbol: 'Ar', languages: ['fr']),
    Country(code: 'MA', name: 'Maroc', currency: 'MAD', currencySymbol: 'DH', languages: ['fr', 'ar']),
    Country(code: 'DZ', name: 'Algérie', currency: 'DZD', currencySymbol: 'DA', languages: ['ar', 'fr']),
    Country(code: 'TN', name: 'Tunisie', currency: 'TND', currencySymbol: 'DT', languages: ['ar', 'fr']),
    Country(code: 'NG', name: 'Nigeria', currency: 'NGN', currencySymbol: '₦', languages: ['en']),
    Country(code: 'GH', name: 'Ghana', currency: 'GHS', currencySymbol: '₵', languages: ['en']),
    Country(code: 'KE', name: 'Kenya', currency: 'KES', currencySymbol: 'KSh', languages: ['en', 'sw']),
    Country(code: 'ZA', name: 'Afrique du Sud', currency: 'ZAR', currencySymbol: 'R', languages: ['en']),

    // --- Union européenne ---
    Country(code: 'FR', name: 'France', currency: 'EUR', currencySymbol: '€', languages: ['fr']),
    Country(code: 'BE', name: 'Belgique', currency: 'EUR', currencySymbol: '€', languages: ['fr', 'nl', 'de']),
    Country(code: 'DE', name: 'Allemagne', currency: 'EUR', currencySymbol: '€', languages: ['de']),
    Country(code: 'ES', name: 'Espagne', currency: 'EUR', currencySymbol: '€', languages: ['es']),
    Country(code: 'IT', name: 'Italie', currency: 'EUR', currencySymbol: '€', languages: ['it']),
    Country(code: 'PT', name: 'Portugal', currency: 'EUR', currencySymbol: '€', languages: ['pt']),
    Country(code: 'NL', name: 'Pays-Bas', currency: 'EUR', currencySymbol: '€', languages: ['nl']),
    Country(code: 'LU', name: 'Luxembourg', currency: 'EUR', currencySymbol: '€', languages: ['fr', 'de']),
    Country(code: 'CH', name: 'Suisse', currency: 'CHF', currencySymbol: 'CHF', languages: ['fr', 'de', 'it']),
    Country(code: 'GB', name: 'Royaume-Uni', currency: 'GBP', currencySymbol: '£', languages: ['en']),

    // --- Amériques ---
    Country(code: 'US', name: 'États-Unis', currency: 'USD', currencySymbol: '\$', languages: ['en', 'es']),
    Country(code: 'CA', name: 'Canada', currency: 'CAD', currencySymbol: '\$', languages: ['en', 'fr']),
    Country(code: 'MX', name: 'Mexique', currency: 'MXN', currencySymbol: '\$', languages: ['es']),
    Country(code: 'BR', name: 'Brésil', currency: 'BRL', currencySymbol: 'R\$', languages: ['pt']),

    // --- Asie / Moyen-Orient ---
    Country(code: 'IN', name: 'Inde', currency: 'INR', currencySymbol: '₹', languages: ['en', 'hi']),
    Country(code: 'CN', name: 'Chine', currency: 'CNY', currencySymbol: '¥', languages: ['zh']),
    Country(code: 'JP', name: 'Japon', currency: 'JPY', currencySymbol: '¥', languages: ['ja']),
    Country(code: 'SG', name: 'Singapour', currency: 'SGD', currencySymbol: 'S\$', languages: ['en', 'zh']),
    Country(code: 'AE', name: 'Émirats arabes unis', currency: 'AED', currencySymbol: 'AED', languages: ['ar', 'en']),
    Country(code: 'PH', name: 'Philippines', currency: 'PHP', currencySymbol: '₱', languages: ['en']),
    Country(code: 'VN', name: 'Vietnam', currency: 'VND', currencySymbol: '₫', languages: ['vi']),
  ];

  static Country? byCode(String? code) {
    if (code == null) return null;
    for (final c in all) {
      if (c.code == code.toUpperCase()) return c;
    }
    return null;
  }

  /// Devise détectée depuis la locale du téléphone — utilisée
  /// pour pré-remplir intelligemment la devise au 1er démarrage.
  static String? currencyForLocale(String? countryCode) =>
      byCode(countryCode)?.currency;
}
