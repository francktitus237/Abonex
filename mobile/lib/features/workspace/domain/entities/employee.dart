/// Employé d'un espace entreprise. Le backend génère
/// automatiquement un abonnement 'payroll' mensuel par employé
/// actif — suivi au dashboard, calendrier et rappels.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.position = '',
    required this.salary,
    this.currency = 'XAF',
    this.payDay = 25,
    this.active = true,
  });

  final String id;
  final String name;

  /// Poste / fonction — affiché dans la description de la paie.
  final String position;
  final double salary;
  final String currency;

  /// Jour de paie dans le mois (1-31, clampé mois courts).
  final int payDay;

  /// Inactif = l'échéance payroll est retirée du suivi.
  final bool active;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    position: json['position'] as String? ?? '',
    salary: double.tryParse(json['salary'].toString()) ?? 0,
    currency: json['currency'] as String? ?? 'XAF',
    payDay: json['pay_day'] as int? ?? 25,
    active: json['active'] as bool? ?? true,
  );
}
