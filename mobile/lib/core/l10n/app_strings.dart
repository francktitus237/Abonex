import 'package:flutter/widgets.dart';

/// Traductions FR / EN de l'app.
///
/// Usage dans un widget :  Text(context.tr('profile.title'))
/// Avec variable          :  context.tr('reminder.dayBefore', {'d': '3'})
///
/// `context.tr` s'abonne à la locale du MaterialApp : quand l'utilisateur
/// change de langue, tous les widgets qui l'utilisent se reconstruisent.
extension AppTr on BuildContext {
  String tr(String key, [Map<String, String>? args]) =>
      AppStrings.t(Localizations.localeOf(this).languageCode, key, args);
}

abstract final class AppStrings {
  /// Version sans BuildContext (notifications, formatters…).
  static String t(String lang, String key, [Map<String, String>? args]) {
    var text = (_all[lang] ?? _all['fr']!)[key] ?? _all['fr']![key] ?? key;
    args?.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  static const Map<String, Map<String, String>> _all = {'fr': _fr, 'en': _en};

  // ───────────────────────── FRANÇAIS ─────────────────────────
  static const _fr = <String, String>{
    // Navigation
    'nav.home': 'Accueil',
    'nav.subscriptions': 'Abonnements',
    'nav.calendar': 'Calendrier',
    'nav.reports': 'Rapports',
    'nav.profile': 'Profil',

    // Guide de première connexion
    'guide.badge': 'PRISE EN MAIN',
    'guide.skip': 'Passer',
    'guide.next': 'Continuer',
    'guide.done': 'Explorer Abonex',
    'guide.1.title': 'Votre tableau de bord',
    'guide.1.desc':
        'Retrouvez immédiatement votre budget, vos dépenses et vos prochaines échéances.',
    'guide.2.title': 'Ajoutez un abonnement',
    'guide.2.desc':
        'Ouvrez l’onglet Abonnements puis utilisez le bouton Ajouter pour commencer votre suivi.',
    'guide.3.title': 'Gardez une longueur d’avance',
    'guide.3.desc':
        'Le calendrier et les rapports vous aident à anticiper chaque paiement.',

    // Profil
    'profile.title': 'Profil',
    'profile.preferences': 'Préférences',
    'profile.admin': 'Administration',
    'profile.users': 'Utilisateurs & rôles',
    'profile.usersSub': 'Inviter, changer les droits',
    'profile.integrations': 'Import & intégrations',
    'profile.integrationsSub': 'Fichier CSV, comptes OVH/IONOS connectés',
    'profile.logout': 'Se déconnecter',
    'profile.edit': 'Modifier le profil',
    'profile.firstName': 'Prénom',
    'profile.lastName': 'Nom',
    'profile.saving': 'Enregistrement…',
    'profile.save': 'Enregistrer',
    'profile.updated': 'Profil mis à jour.',
    'profile.unexpected': 'Erreur inattendue.',
    'settings.theme': 'Thème',
    'settings.language': 'Langue',
    'settings.biometric': 'Verrouillage biométrique',
    'settings.biometricSub': 'Empreinte ou Face ID à l’ouverture',
    'settings.biometricUnavailable':
        'Biométrie indisponible ou vérification annulée.',
    'settings.sound': 'Rappels sonores',
    'settings.soundSub': 'Alarme plein écran le jour de l’échéance',
    'reminder.title': 'Rappels d’échéance',
    'reminder.remindMe': 'Me rappeler :',
    'reminder.dayJ': 'Le jour J',
    'reminder.hour': 'Heure du rappel :',
    'reminder.atLeastOne': 'Choisissez au moins un rappel.',
    'reminder.summary': '{days} à {hour}h',
    'common.cancel': 'Annuler',

    // Rôles
    'role.owner': 'Propriétaire',
    'role.manager': 'Gestionnaire',
    'role.assistant': 'Assistant',
    'role.viewer': 'Lecteur',

    // Dates relatives
    'date.today': 'Aujourd’hui',
    'date.tomorrow': 'Demain',
    'date.late': 'En retard de {n} j',
    'date.in': 'Dans {n} j',
  };

  // ───────────────────────── ENGLISH ─────────────────────────
  static const _en = <String, String>{
    'nav.home': 'Home',
    'nav.subscriptions': 'Subscriptions',
    'nav.calendar': 'Calendar',
    'nav.reports': 'Reports',
    'nav.profile': 'Profile',

    'guide.badge': 'GETTING STARTED',
    'guide.skip': 'Skip',
    'guide.next': 'Continue',
    'guide.done': 'Explore Abonex',
    'guide.1.title': 'Your dashboard',
    'guide.1.desc':
        'Instantly see your budget, your spending and your upcoming due dates.',
    'guide.2.title': 'Add a subscription',
    'guide.2.desc':
        'Open the Subscriptions tab and use the Add button to start tracking.',
    'guide.3.title': 'Stay one step ahead',
    'guide.3.desc':
        'The calendar and reports help you anticipate every payment.',

    'profile.title': 'Profile',
    'profile.preferences': 'Preferences',
    'profile.admin': 'Administration',
    'profile.users': 'Users & roles',
    'profile.usersSub': 'Invite people, change permissions',
    'profile.integrations': 'Import & integrations',
    'profile.integrationsSub': 'CSV file, connected OVH/IONOS accounts',
    'profile.logout': 'Log out',
    'profile.edit': 'Edit profile',
    'profile.firstName': 'First name',
    'profile.lastName': 'Last name',
    'profile.saving': 'Saving…',
    'profile.save': 'Save',
    'profile.updated': 'Profile updated.',
    'profile.unexpected': 'Unexpected error.',
    'settings.theme': 'Theme',
    'settings.language': 'Language',
    'settings.biometric': 'Biometric lock',
    'settings.biometricSub': 'Fingerprint or Face ID when opening the app',
    'settings.biometricUnavailable':
        'Biometrics unavailable or verification cancelled.',
    'settings.sound': 'Sound reminders',
    'settings.soundSub': 'Full-screen alarm on the due date',
    'reminder.title': 'Due-date reminders',
    'reminder.remindMe': 'Remind me:',
    'reminder.dayJ': 'On the day',
    'reminder.hour': 'Reminder time:',
    'reminder.atLeastOne': 'Choose at least one reminder.',
    'reminder.summary': '{days} at {hour}:00',
    'common.cancel': 'Cancel',

    'role.owner': 'Owner',
    'role.manager': 'Manager',
    'role.assistant': 'Assistant',
    'role.viewer': 'Viewer',

    'date.today': 'Today',
    'date.tomorrow': 'Tomorrow',
    'date.late': '{n} d overdue',
    'date.in': 'In {n} d',
  };
}