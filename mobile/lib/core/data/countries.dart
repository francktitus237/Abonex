/// Données pays/devise/langue pour la configuration de premier
/// démarrage et l'automatisation de la devise locale.
/// Couvre les cibles : Afrique, UE, Asie, Amériques.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.nameEn,
    required this.currency,
    required this.currencySymbol,
    required this.languages,
  });

  /// Code ISO 3166-1 alpha-2.
  final String code;

  /// Nom en français.
  final String name;

  /// Nom en anglais — affiché quand la langue de l'app est EN.
  final String nameEn;

  /// Code ISO 4217 (XAF, EUR, USD…).
  final String currency;
  final String currencySymbol;

  /// Langues principales du pays (codes ISO 639-1), première = défaut.
  final List<String> languages;

  /// Nom dans la langue demandée ('fr' | 'en').
  String nameFor(String lang) => lang == 'en' ? nameEn : name;

  /// Drapeau emoji dérivé du code ISO (indicateurs régionaux).
  String get flag => String.fromCharCodes(
    code.codeUnits.map((c) => 0x1F1E6 + c - 0x41),
  );
}

abstract final class AppCountries {
  static const all = [
    // --- Afrique ---
    Country(code: 'CM', name: 'Cameroun', nameEn: 'Cameroon', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr', 'en']),
    Country(code: 'CI', name: 'Côte d\'Ivoire', nameEn: 'Ivory Coast', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'SN', name: 'Sénégal', nameEn: 'Senegal', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'GA', name: 'Gabon', nameEn: 'Gabon', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'CG', name: 'Congo', nameEn: 'Congo', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'CD', name: 'RD Congo', nameEn: 'DR Congo', currency: 'CDF', currencySymbol: 'FC', languages: ['fr']),
    Country(code: 'BJ', name: 'Bénin', nameEn: 'Benin', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'BF', name: 'Burkina Faso', nameEn: 'Burkina Faso', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'TG', name: 'Togo', nameEn: 'Togo', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'ML', name: 'Mali', nameEn: 'Mali', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'NE', name: 'Niger', nameEn: 'Niger', currency: 'XOF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'TD', name: 'Tchad', nameEn: 'Chad', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr']),
    Country(code: 'GQ', name: 'Guinée équatoriale', nameEn: 'Equatorial Guinea', currency: 'XAF', currencySymbol: 'FCFA', languages: ['fr', 'es']),
    Country(code: 'MG', name: 'Madagascar', nameEn: 'Madagascar', currency: 'MGA', currencySymbol: 'Ar', languages: ['fr']),
    Country(code: 'MA', name: 'Maroc', nameEn: 'Morocco', currency: 'MAD', currencySymbol: 'DH', languages: ['fr', 'ar']),
    Country(code: 'DZ', name: 'Algérie', nameEn: 'Algeria', currency: 'DZD', currencySymbol: 'DA', languages: ['ar', 'fr']),
    Country(code: 'TN', name: 'Tunisie', nameEn: 'Tunisia', currency: 'TND', currencySymbol: 'DT', languages: ['ar', 'fr']),
    Country(code: 'NG', name: 'Nigeria', nameEn: 'Nigeria', currency: 'NGN', currencySymbol: '₦', languages: ['en']),
    Country(code: 'GH', name: 'Ghana', nameEn: 'Ghana', currency: 'GHS', currencySymbol: '₵', languages: ['en']),
    Country(code: 'KE', name: 'Kenya', nameEn: 'Kenya', currency: 'KES', currencySymbol: 'KSh', languages: ['en', 'sw']),
    Country(code: 'ZA', name: 'Afrique du Sud', nameEn: 'South Africa', currency: 'ZAR', currencySymbol: 'R', languages: ['en']),

    // --- Union européenne ---
    Country(code: 'FR', name: 'France', nameEn: 'France', currency: 'EUR', currencySymbol: '€', languages: ['fr']),
    Country(code: 'BE', name: 'Belgique', nameEn: 'Belgium', currency: 'EUR', currencySymbol: '€', languages: ['fr', 'nl', 'de']),
    Country(code: 'DE', name: 'Allemagne', nameEn: 'Germany', currency: 'EUR', currencySymbol: '€', languages: ['de']),
    Country(code: 'ES', name: 'Espagne', nameEn: 'Spain', currency: 'EUR', currencySymbol: '€', languages: ['es']),
    Country(code: 'IT', name: 'Italie', nameEn: 'Italy', currency: 'EUR', currencySymbol: '€', languages: ['it']),
    Country(code: 'PT', name: 'Portugal', nameEn: 'Portugal', currency: 'EUR', currencySymbol: '€', languages: ['pt']),
    Country(code: 'NL', name: 'Pays-Bas', nameEn: 'Netherlands', currency: 'EUR', currencySymbol: '€', languages: ['nl']),
    Country(code: 'LU', name: 'Luxembourg', nameEn: 'Luxembourg', currency: 'EUR', currencySymbol: '€', languages: ['fr', 'de']),
    Country(code: 'CH', name: 'Suisse', nameEn: 'Switzerland', currency: 'CHF', currencySymbol: 'CHF', languages: ['fr', 'de', 'it']),
    Country(code: 'GB', name: 'Royaume-Uni', nameEn: 'United Kingdom', currency: 'GBP', currencySymbol: '£', languages: ['en']),

    // --- Amériques ---
    Country(code: 'US', name: 'États-Unis', nameEn: 'United States', currency: 'USD', currencySymbol: '\$', languages: ['en', 'es']),
    Country(code: 'CA', name: 'Canada', nameEn: 'Canada', currency: 'CAD', currencySymbol: '\$', languages: ['en', 'fr']),
    Country(code: 'MX', name: 'Mexique', nameEn: 'Mexico', currency: 'MXN', currencySymbol: '\$', languages: ['es']),
    Country(code: 'BR', name: 'Brésil', nameEn: 'Brazil', currency: 'BRL', currencySymbol: 'R\$', languages: ['pt']),

    // --- Asie / Moyen-Orient ---
    Country(code: 'IN', name: 'Inde', nameEn: 'India', currency: 'INR', currencySymbol: '₹', languages: ['en', 'hi']),
    Country(code: 'CN', name: 'Chine', nameEn: 'China', currency: 'CNY', currencySymbol: '¥', languages: ['zh']),
    Country(code: 'JP', name: 'Japon', nameEn: 'Japan', currency: 'JPY', currencySymbol: '¥', languages: ['ja']),
    Country(code: 'SG', name: 'Singapour', nameEn: 'Singapore', currency: 'SGD', currencySymbol: 'S\$', languages: ['en', 'zh']),
    Country(code: 'AE', name: 'Émirats arabes unis', nameEn: 'United Arab Emirates', currency: 'AED', currencySymbol: 'AED', languages: ['ar', 'en']),
    Country(code: 'PH', name: 'Philippines', nameEn: 'Philippines', currency: 'PHP', currencySymbol: '₱', languages: ['en']),
    Country(code: 'VN', name: 'Vietnam', nameEn: 'Vietnam', currency: 'VND', currencySymbol: '₫', languages: ['vi']),
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
