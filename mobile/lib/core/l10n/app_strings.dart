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
    'nav.notifications': 'Notifications',

    // Commun
    'common.cancel': 'Annuler',
    'common.confirm': 'Valider',
    'common.retry': 'Réessayer',
    'common.refresh': 'Actualiser',
    'common.save': 'Enregistrer',
    'common.add': 'Ajouter',
    'common.delete': 'Supprimer',
    'common.edit': 'Modifier',
    'common.send': 'Envoyer',
    'common.later': 'Plus tard',
    'common.email': 'Email',
    'common.amount': 'Montant',
    'common.required': 'Champ obligatoire',
    'common.requiredShort': 'Requis',
    'common.loadError': 'Chargement impossible',
    'common.unexpected': 'Erreur inattendue.',

    // Erreurs techniques (Failure / ApiException)
    'error.network': 'Pas de connexion internet.',
    'error.networkLong':
        'Impossible de joindre le serveur. Vérifiez votre connexion '
        'et réessayez.',
    'error.auth': 'Identifiants incorrects.',
    'error.cache': 'Erreur de cache local.',
    'error.unexpected': 'Une erreur inattendue est survenue.',
    'error.400': 'Requête invalide. Vérifiez les informations saisies.',
    'error.401': 'Session expirée ou identifiants incorrects.',
    'error.403': 'Action non autorisée pour votre rôle.',
    'error.404':
        'Service introuvable. L\'adresse du serveur a peut-être changé.',
    'error.409': 'Ces données existent déjà.',
    'error.422': 'Données invalides. Vérifiez le formulaire.',
    'error.429': 'Trop de tentatives. Patientez quelques instants.',
    'error.500': 'Le serveur rencontre un problème. Réessayez dans un moment.',
    'error.other': 'Une erreur est survenue (code {code}). Réessayez.',

    // Statuts / cycles / catégories
    'status.paid': 'Payé',
    'status.dueSoon': 'À venir',
    'status.overdue': 'En retard',
    'status.done': 'Terminé',
    'status.settled': 'Réglé',
    'cycle.monthly': 'Mensuel',
    'cycle.quarterly': 'Trimestriel',
    'cycle.yearly': 'Annuel',
    'cycle.daily': 'Chaque jour',
    'cycle.weekly': 'Chaque semaine',
    'cycle.once': 'Une seule fois',
    'cycle.perMonthly': 'par mois',
    'cycle.perQuarterly': 'par trimestre',
    'cycle.perYearly': 'par an',
    'cycle.perDaily': 'par jour',
    'cycle.perWeekly': 'par semaine',
    'cycle.perOnce': 'en une fois',
    'category.software': 'Logiciels',
    'category.rent': 'Loyers',
    'category.insurance': 'Assurances',
    'category.telecom': 'Télécom',
    'category.energy': 'Énergie',
    'category.water': 'Eau',
    'category.payroll': 'Salaires',
    'category.transport': 'Transport',
    'category.event': 'Événement',
    'category.other': 'Autre (alimentation, santé…)',
    'event.label': 'Rendez-vous',

    // Dates relatives
    'date.today': 'Aujourd’hui',
    'date.tomorrow': 'Demain',
    'date.late': 'En retard de {n} j',
    'date.in': 'Dans {n} j',
    'cal.weekdays': 'L M M J V S D',

    // Tableau de bord
    'dash.greeting': 'Bonjour, {name}',
    'dash.spent': 'Dépensé ce mois',
    'dash.toPay': 'Reste à payer',
    'dash.count': '{n} abonnement{s} suivi{s}',
    'dash.events': '{n} rendez-vous',
    'dash.updateHint':
        'Facture d\'eau, d\'électricité, salaire ou nouvel abonnement '
        'à suivre ? Pensez à mettre votre liste à jour.',
    'dash.overdue': '{n} échéance{s} en retard{total}',
    'dash.upcoming': 'Prochaines échéances',
    'dash.budget': 'Budget du mois',
    'dash.budgetTitle': 'Budget mensuel',
    'dash.budgetEdit': 'Modifier',
    'dash.budgetSet': 'Définir',
    'dash.budgetHint':
        'Définissez votre budget mensuel pour suivre la consommation '
        'de vos dépenses.',
    'dash.budgetUnavailable': 'Budget indisponible — réessayer',
    'dash.budgetFail': 'Budget non enregistré. Réessayez.',
    'dash.committed': '{amount} engagés',
    'dash.budgetPct': '{pct} % de {amount}',
    'dash.over': 'Dépassement de {amount}',
    'dash.byCategory': 'Dépenses par catégorie',
    'reminder.dialogTitle': 'Rappel de paiement',
    'reminder.overdueBody': '{n} échéance{s} en retard{total}.',
    'reminder.more': 'et {n} autre{s}…',
    'reminder.viewDue': 'Voir les échéances',
    'toast.paid': '{name} marqué comme payé.',
    'toast.done': '{name} marqué comme terminé.',

    // Abonnements — liste
    'subs.search': 'Rechercher un abonnement…',
    'subs.integrations': 'Import & intégrations',
    'filter.all': 'Tous',
    'filter.paid': 'Payés',
    'filter.done': 'Terminés',
    'filter.dueSoon': 'À venir',
    'filter.overdue': 'En retard',
    'subs.empty': 'Aucun abonnement',
    'subs.emptySub':
        'Ajoutez votre première échéance récurrente pour commencer '
        'le suivi.',
    'subs.addFirst': 'Ajouter un abonnement',
    'subs.noResult': 'Aucun résultat',
    'subs.noResultSub': 'Modifiez la recherche ou les filtres.',
    'subs.tabSubs': 'Abonnements',
    'subs.tabEvents': 'Rendez-vous',
    'subs.emptySubs': 'Aucun abonnement pour le moment',
    'subs.emptyEvents': 'Aucun rendez-vous pour le moment',

    // Abonnements — formulaire
    'form.editTitle': 'Modifier — {name}',
    'form.newEvent': 'Nouveau rendez-vous',
    'form.newSub': 'Nouvel abonnement',
    'form.typeSub': 'Abonnement',
    'form.typeEvent': 'Rendez-vous',
    'form.import': 'Importer plusieurs abonnements ou choisir un service',
    'form.name': 'Nom',
    'form.title': 'Titre',
    'form.nameHint': 'Ex. Loyer siège social',
    'form.titleHint': 'Ex. Entretien, réunion, RDV médecin…',
    'form.provider': 'Fournisseur (optionnel)',
    'form.providerHint': 'Choisir ou saisir un fournisseur',
    'form.providerLoading': 'Chargement des fournisseurs de votre pays…',
    'form.providerHelper':
        'Selon le pays du compte. Fournisseur absent ? Saisissez son nom.',
    'form.providerFail': 'Catalogue indisponible — réessayer',
    'form.description': 'Description (optionnel)',
    'form.descHint': 'Ex. Abonnement EDF — appartement Paris 11e',
    'form.descHintEvent': 'Ex. Bureaux — Bonanjo, Douala',
    'form.amountInvalid': 'Montant invalide',
    'form.cycle': 'Cycle',
    'form.recurrence': 'Répéter le rappel',
    'form.category': 'Catégorie',
    'form.country': 'Pays de l\'abonnement',
    'form.firstDue': 'Première échéance : {date}',
    'form.date': 'Date : {date}',
    'form.time': 'Heure (optionnel)',
    'form.timeSet': 'Heure : {time}',
    'form.noTime': 'Sans heure',
    'form.reminderInfo':
        'Vous serez alerté avant cette date selon vos réglages de rappel.',
    'form.onceDue': 'Échéance unique : {date}',
    'form.nextDue': 'Prochaine échéance calculée : {date}',
    'form.advanced': 'Options avancées',
    'form.advancedSub': 'Date de prise, fin de contrat…',
    'form.startDate': 'Date de prise (ex. dimanche dernier)',
    'form.started': 'Pris le : {date}',
    'form.unknownDate': 'Date inconnue',
    'form.endDate': 'Fin du contrat',
    'form.ends': 'Fin le : {date}',
    'form.noEnd': 'Sans date de fin',
    'form.submitting': 'Enregistrement…',
    'form.saveChanges': 'Enregistrer les modifications',
    'form.createReminder': 'Créer le rappel',
    'form.add': 'Ajouter l\'abonnement',
    'form.saved': 'Modifications enregistrées.',
    'form.eventSaved': 'Rendez-vous enregistré.',
    'form.subSaved': 'Abonnement ajouté.',
    'form.pickFirstDue': 'Première échéance',
    'form.pickStart': 'Date de prise de l\'abonnement',
    'form.pickEnd': 'Fin du contrat',
    'form.pickTime': 'Heure du rendez-vous',

    // Abonnements — détail
    'detail.title': 'Détail',
    'detail.notFound': 'Abonnement introuvable',
    'detail.notFoundSub': 'Il a peut-être été supprimé.',
    'detail.eventDate': 'Date du rendez-vous',
    'detail.time': 'Heure',
    'detail.countdown': 'Compte à rebours',
    'detail.nextDue': 'Prochaine échéance',
    'detail.billingCycle': 'Cycle de facturation',
    'detail.category': 'Catégorie',
    'detail.provider': 'Fournisseur',
    'detail.country': 'Pays',
    'detail.description': 'Description',
    'detail.at': 'à {time}',
    'detail.markPaid': 'Marquer comme payé',
    'detail.markDone': 'Marquer comme terminé',
    'detail.deleteTitle': 'Supprimer ?',
    'detail.deleteBody':
        '« {name} » sera définitivement retiré de votre suivi.',
    'detail.deleted': 'Abonnement supprimé.',
    'detail.history': 'Historique des paiements',
    'detail.historyEmpty': 'Aucun paiement enregistré.',
    'detail.historyFail': 'Historique indisponible',
    'detail.paidOn': 'Payé le {date}',

    // Calendrier
    'cal.select': 'Sélectionnez un jour',
    'cal.none': 'Aucune échéance',
    'cal.noneSub': 'Rien à payer ce jour-là.',

    // Rapports
    'reports.events': 'Rendez-vous',
    'reports.noData': 'Pas de données',
    'reports.noDataSub': 'Ajoutez des abonnements pour voir les rapports.',
    'reports.noExpenses': 'Pas de dépenses',
    'reports.noExpensesSub':
        'Ajoutez des abonnements facturés pour voir les rapports.',
    'reports.byCategory': 'Répartition par catégorie',
    'reports.perMonth': 'par mois (équivalent)',
    'reports.forecast': 'Échéances des 6 prochains mois',

    // Notifications in-app
    'notif.empty': 'Aucune notification',
    'notif.emptySub':
        'Toutes vos échéances sont réglées. Nous vous préviendrons '
        'dès qu\'un paiement approche.',
    'notif.pastEvent': 'Rendez-vous passé',
    'notif.duePassed': 'Échéance dépassée',
    'notif.expected': '{amount} — attendue le {date}',
    'notif.dueToday': 'Échéance aujourd\'hui',
    'notif.dueIn': 'Échéance dans {n} j',
    'notif.hint':
        'Nouvelle facture ou abonnement non suivi ? Ajoutez-le pour '
        'des rappels complets.',

    // Notifications système / alarmes (NotificationService)
    'ns.eventToday': 'Rendez-vous aujourd\'hui : {name}',
    'ns.dueToday': 'Échéance aujourd\'hui : {name}',
    'ns.eventTomorrow': 'Rendez-vous demain : {name}',
    'ns.dueTomorrow': 'Échéance demain : {name}',
    'ns.eventIn': 'Rendez-vous dans {n} j : {name}',
    'ns.dueIn': 'Échéance dans {n} j : {name}',
    'ns.payBody': '{provider} — {amount} à payer.',
    'ns.eventTime': 'C\'est l\'heure — {date}',
    'ns.eventTitle': 'Rendez-vous : {name}',
    'ns.dueAlarmTitle': 'Échéance : {name}',
    'ns.soonEvent': 'Rendez-vous dans {h} : {name}',
    'ns.soonDue': 'Échéance dans {h} : {name}',
    'ns.snooze': 'Repousser 10 min',
    'ns.stop': 'Arrêter',
    'ns.weeklyTitle': 'Abonex — liste à jour ?',
    'ns.weeklyBody':
        'Pensez à ajouter vos nouvelles factures et abonnements pour '
        'un suivi complet.',
    'ns.overdueTitle': 'Toujours en retard : {name}',
    'ns.markPaid': 'Marquer payé',
    'ns.markDone': 'Marquer terminé',
    'ns.channelReminders': 'Rappels importants',
    'ns.channelRemindersDesc':
        'Alertes sonores avant les paiements et rappels de suivi.',
    'ns.channelUrgent': 'Alarmes d\'échéance',
    'ns.channelUrgentDesc':
        'Rappels plein écran avec sonnerie pour les paiements du jour.',
    'ns.channelEvent': 'Alarmes de rendez-vous',
    'ns.channelEventDesc':
        'Sonne à l\'heure exacte du rendez-vous jusqu\'à arrêt ou report.',

    // Intégrations
    'int.title': 'Import & intégrations',
    'int.csvTitle': 'Importer un fichier',
    'int.csvSub':
        'CSV avec les colonnes : name, provider, category, amount, '
        'currency, cycle, next_due_date',
    'int.csvPick': 'Choisir un fichier CSV',
    'int.connections': 'Comptes connectés',
    'int.connectionsSub':
        'Re-synchronisez en un tap — vos identifiants restent chiffrés '
        'côté serveur.',
    'int.resync': 'Re-synchroniser',
    'int.disconnect': 'Déconnecter',
    'int.connectors': 'Connexions professionnelles',
    'int.connectorsSub':
        'Ces intégrations nécessitent des clés API du fournisseur, '
        'pas votre mot de passe habituel. Les données disponibles '
        'varient selon le service ; certains montants et dates '
        'restent à compléter. Les connecteurs de paiement '
        'concernent les abonnements facturés à vos clients.',
    'int.connect': 'Connecter',
    'int.connectTitle': 'Connecter {name}',
    'int.connectGo': 'Connecter et analyser',
    'int.noneDetected': 'Aucun service détecté sur ce compte.',
    'int.syncFail': 'Synchronisation impossible.',
    'int.connectFail': 'Connexion au fournisseur impossible.',
    'int.disconnectFail': 'Déconnexion impossible.',
    'int.disconnected': '{name} déconnecté.',
    'int.csvEmpty': 'Fichier vide ou en-têtes manquants.',
    'int.csvNoRows': 'Aucune ligne valide dans le fichier.',
    'int.csvImported': '{n} abonnement(s) importé(s){skipped}.',
    'int.csvSkipped': ' — {n} ligne(s) ignorée(s)',
    'int.csvFail': 'Fichier illisible. Vérifiez le format CSV.',
    'int.importFail': 'Import impossible. Réessayez.',
    'int.presetAdded': '{name} ajouté à vos abonnements.',
    'int.popular': 'Services populaires',
    'int.popularSub':
        'Netflix, Spotify & co ne publient pas de date de prélèvement '
        'via API — choisissez le service, tout est pré-rempli, vous '
        'posez juste la date de renouvellement.',
    'int.searchService': 'Rechercher un service…',
    'int.detected': '{n} service(s) détecté(s)',
    'int.detectedSub':
        'Vérifiez puis importez — le montant reste à compléter si le '
        'fournisseur ne le publie pas.',
    'int.due': 'échéance : {date}',
    'int.dueUndefined': 'à définir',
    'int.more': '… et {n} autre(s)',
    'int.import': 'Importer {n} abonnement(s)',
    'int.groupPayments': 'Paiements récurrents',
    'int.groupCloud': 'Cloud, serveurs & SaaS',
    'int.groupDomains': 'Domaines & registrars',
    'int.groupOther': 'Autres',
    'int.catStreaming': 'Streaming & TV',
    'int.catMusic': 'Musique',
    'int.catStorage': 'Stockage cloud',
    'int.catGaming': 'Jeux vidéo',
    'int.catProductivity': 'Productivité & outils pro',
    'int.catSecurity': 'Sécurité & VPN',
    'int.addPreset': 'Ajouter {name}',
    'int.presetSub':
        'Montant et cycle pré-remplis — ajustez si votre forfait '
        'diffère, puis indiquez la date du prochain prélèvement.',
    'int.renewal': 'Prochain renouvellement',
    'int.nextDebit': 'Prochain prélèvement : {date}',
    'int.addToMine': 'Ajouter à mes abonnements',

    // Agrégation bancaire (Powens)
    'bank.title': 'Synchronisation bancaire',
    'bank.sub':
        'Détection automatique de vos prélèvements récurrents '
        '(énergie, eau, télécom, loyer, streaming…) directement sur '
        'votre relevé bancaire. Vous vous connectez à votre banque '
        'chez notre partenaire agréé — Abonex ne voit jamais vos '
        'identifiants bancaires.',
    'bank.connect': 'Connecter ma banque',
    'bank.fail': 'Connexion bancaire impossible — réessayez.',

    // Utilisateurs & rôles
    'users.info': 'Les droits sont vérifiés côté serveur à chaque action.',
    'users.invite': 'Inviter',
    'users.inviteTitle': 'Inviter un collaborateur',
    'users.role': 'Rôle',
    'users.roleManager': 'Gestionnaire — tout gérer',
    'users.roleAssistant': 'Assistant — marquer payé/terminé',
    'users.roleViewer': 'Lecteur — consultation',
    'users.inviteSent': 'Invitation envoyée à {email}.',
    'users.inviteFail': 'Envoi de l\'invitation impossible.',
    'users.loadFail': 'Impossible de charger les utilisateurs.',
    'users.roleFail': 'Impossible de modifier ce rôle.',
    'users.roleChanged': '{email} est maintenant {role}.',
    'users.changeRole': 'Modifier le rôle',

    // Authentification
    'auth.welcome': 'Bienvenue sur Abonex',
    'auth.loginSub':
        'Connectez-vous pour piloter vos abonnements en toute sérénité.',
    'auth.emailHint': 'vous@entreprise.com',
    'auth.emailPro': 'Email professionnel',
    'auth.emailInvalid': 'Entrez un email valide',
    'auth.password': 'Mot de passe',
    'auth.passwordMin': '8 caractères minimum',
    'auth.forgot': 'Mot de passe oublié ?',
    'auth.login': 'Se connecter',
    'auth.newHere': 'Nouveau sur Abonex ?',
    'auth.createAccount': 'Créer un compte',
    'auth.haveInvite': 'J\'ai une invitation',
    'auth.secure': 'Connexion sécurisée',
    'auth.resetTitle': 'Réinitialiser le mot de passe',
    'auth.resetSent':
        'Si un compte existe pour cet email, un lien a été envoyé.',
    'auth.createTitle': 'Créez votre espace',
    'auth.createSub':
        'Votre compte propriétaire est créé en quelques secondes.',
    'auth.country': 'Pays',
    'auth.countryHelper': 'Devise : {currency} — ajustable après',
    'auth.confirmPassword': 'Confirmer le mot de passe',
    'auth.passwordMismatch': 'Les mots de passe ne correspondent pas',
    'auth.terms':
        'J’accepte les conditions d’utilisation et la politique de '
        'confidentialité.',
    'auth.acceptTerms': 'Acceptez les conditions pour continuer.',
    'auth.creating': 'Création…',
    'auth.create': 'Créer mon compte',
    'auth.dataSecure': 'Vos données sont sécurisées côté serveur.',

    // Invitation
    'invite.title': 'Rejoindre un espace de travail',
    'invite.sub':
        'Collez le lien d\'invitation reçu par email et choisissez '
        'votre mot de passe.',
    'invite.link': 'Lien ou code d\'invitation',
    'invite.linkHint': 'abonex://invite/…',
    'invite.linkRequired': 'Lien requis',
    'invite.invalid': 'Lien d\'invitation invalide ou expiré.',
    'invite.join': 'Rejoindre l\'espace',

    // Réinitialisation du mot de passe (lien abonex://reset/…)
    'reset.title': 'Nouveau mot de passe',
    'reset.sub':
        'Collez le lien reçu par email et choisissez un nouveau '
        'mot de passe.',
    'reset.link': 'Lien de réinitialisation',
    'reset.linkHint': 'abonex://reset/…',
    'reset.linkRequired': 'Lien requis',
    'reset.newPassword': 'Nouveau mot de passe',
    'reset.submit': 'Réinitialiser',
    'reset.done': 'Mot de passe réinitialisé — connectez-vous.',
    'reset.invalid': 'Lien invalide ou expiré.',
    'reset.haveLink': 'J\'ai un lien de réinitialisation',

    // Onboarding
    'onb.skip': 'Passer',
    'onb.next': 'Continuer',
    'onb.start': 'Commencer',
    'onb.1.badge': 'Suivi des dépenses',
    'onb.1.title': 'Maîtrisez chaque franc\ndépensé',
    'onb.1.desc':
        'Abonex centralise vos abonnements, factures, loyers et salaires '
        '— entreprise ou foyer, vous savez toujours où va votre argent.',
    'onb.2.badge': 'Rappels intelligents',
    'onb.2.title': 'Zéro échéance\noubliée',
    'onb.2.desc':
        'Rappels automatiques avant chaque paiement, alerte plein écran '
        'le jour J : ne payez plus jamais de pénalité de retard.',
    'onb.3.badge': 'Équipe & sécurité',
    'onb.3.title': 'Collaborez en toute\nsérénité',
    'onb.3.desc':
        'Invitez vos collaborateurs avec des rôles précis : chacun voit '
        'et fait exactement ce que vous avez décidé.',
    'onb.expenses': 'Dépenses du mois',
    'onb.bills': 'Factures',
    'onb.rent': 'Loyers',
    'onb.salary': 'Salaires',
    'onb.rentTomorrow': 'Loyer demain',
    'onb.dueToday': 'Échéance du jour',

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
    'profile.app': 'Application',
    'profile.users': 'Utilisateurs & rôles',
    'profile.usersSub': 'Inviter, changer les droits',
    'profile.integrations': 'Import & intégrations',
    'profile.integrationsSub': 'Fichier CSV, comptes OVH/IONOS connectés',
    'profile.logout': 'Se déconnecter',
    'auth.verified': 'Adresse email vérifiée.',
    'auth.personal': 'Personnel',
    'auth.business': 'Entreprise',
    'auth.personalHint':
        'Suivez vos abonnements et rendez-vous perso.',
    'auth.businessHint':
        'Personnel + gestion des employés, rôles et '
            'masse salariale.',
    'emp.title': 'Employés',
    'emp.empty': 'Aucun employé',
    'emp.emptySub':
        'Ajoutez vos employés — chaque paie devient une '
            'échéance mensuelle suivie.',
    'emp.add': 'Ajouter un employé',
    'emp.edit': 'Modifier l\u2019employé',
    'emp.name': 'Nom complet',
    'emp.position': 'Poste / fonction',
    'emp.salary': 'Salaire mensuel',
    'emp.payDay': 'Jour de paie (jour du mois)',
    'emp.active': 'Employé actif',
    'emp.activeSub':
        'Inactif : la paie n\u2019est plus suivie '
            'comme échéance',
    'emp.deleted': 'Employé supprimé.',
    'emp.saved': 'Employé enregistré — paie suivie '
        'automatiquement.',
    'emp.payroll': 'Masse salariale : {amount}/mois',
    'auth.verifyFail': 'Lien de vérification invalide ou expiré.',
    'profile.dataSection': 'Données & compte',
    'profile.employees': 'Employés',
    'profile.employeesSub':
        'Paies suivies comme échéances mensuelles',
    'profile.exportData': 'Exporter mes données (CSV)',
    'profile.exportDataSub':
        'Abonnements, paiements — format tableur',
    'profile.exportFail': "L'export a échoué.",
    'profile.deleteAccount': 'Supprimer le compte',
    'profile.deleteAccountSub':
        'Définitif — toutes vos données sont effacées',
    'profile.deleteWarn':
        'Cette action est irréversible : abonnements, '
            'paiements et espace de travail seront supprimés. '
            'Confirmez avec votre mot de passe.',
    'profile.deleted': 'Compte supprimé.',
    'profile.deleteFail': 'Suppression impossible : '
        'vérifiez le mot de passe.',
    'profile.edit': 'Modifier le profil',
    'profile.firstName': 'Prénom',
    'profile.lastName': 'Nom',
    'profile.saving': 'Enregistrement…',
    'profile.save': 'Enregistrer',
    'profile.updated': 'Profil mis à jour.',
    'profile.unexpected': 'Erreur inattendue.',
    'profile.photo.change': 'Changer la photo',
    'profile.photo.remove': 'Retirer',
    'profile.photo.updated': 'Photo de profil mise à jour.',
    'profile.photo.removed': 'Photo de profil retirée.',
    'profile.currency': 'Devise de base',
    'profile.password': 'Mot de passe',
    'profile.passwordSub': 'Changer votre mot de passe',
    'profile.password.current': 'Mot de passe actuel',
    'profile.password.new': 'Nouveau mot de passe',
    'profile.password.confirm': 'Confirmer le nouveau',
    'profile.password.mismatch': 'Les mots de passe ne correspondent pas.',
    'profile.password.changed': 'Mot de passe mis à jour.',
    'settings.theme': 'Thème',
    'settings.language': 'Langue',
    'settings.biometric': 'Verrouillage biométrique',
    'settings.biometricSub': 'Empreinte ou Face ID à l’ouverture',
    'settings.biometricUnavailable':
        'Biométrie indisponible ou vérification annulée.',
    'settings.biometricReason': 'Déverrouillez Abonex',
    'settings.biometricConfirm':
        'Confirmez pour activer le déverrouillage biométrique',
    'settings.sound': 'Rappels sonores',
    'settings.soundSub': 'Alarme plein écran le jour de l’échéance',
    'reminder.title': 'Rappels d’échéance',
    'reminder.remindMe': 'Me rappeler :',
    'reminder.dayJ': 'Le jour J',
    'reminder.hour': 'Heure du rappel :',
    'reminder.atLeastOne': 'Choisissez au moins un rappel.',
    'reminder.summary': '{days} à {hour}h',

    // Sonnerie d'alarme
    'alarm.title': 'Sonnerie d\'alarme',
    'alarm.choose': 'Choisir la sonnerie',
    'alarm.opt.default': 'Système (par défaut)',
    'alarm.opt.classic': 'Classique',
    'alarm.opt.digital': 'Digitale',
    'alarm.opt.chime': 'Carillon',
    'alarm.opt.custom': 'Personnalisée : {name}',
    'alarm.import': 'Importer un son…',
    'alarm.imported': 'Sonnerie importée : {name}',
    'alarm.test': 'Écouter',
    'alarm.previewTitle': 'Test de la sonnerie',
    'alarm.previewBody': 'Voici la sonnerie de vos alarmes.',
    'alarm.disabled':
        'Notifications désactivées — les alarmes ne sonneront pas.',
    'alarm.enable': 'Activer',
    'alarm.blocked':
        'Notifications bloquées — activez-les pour Abonex dans les '
        'paramètres du téléphone.',
    'alarm.battery': 'Fiabiliser les alarmes',
    'alarm.batterySub': 'Exclure Abonex des économies d\'énergie',
    'alarm.exactWarn':
        'Alarmes exactes refusées — les sonneries peuvent être retardées.',
    'alarm.exactEnable': 'Autoriser les alarmes exactes',
    'alarm.testRing': 'Tester l\'alarme',
    'alarm.testScheduled': 'Alarme de test dans 30 s — quittez l\'app !',
    'alarm.testTitle': 'Test de l\'alarme Abonex',
    'alarm.testBody':
        'Si vous entendez ceci, les sonneries d\'échéance fonctionnent.',
    'alarm.volumeHint':
        'Le son des alarmes suit le volume « Alarme » du téléphone '
        '(distinct du volume sonnerie).',

    // Mise à jour
    'update.title': 'Mise à jour de l\'application',
    'update.installed': 'Version installée : {v}',
    'update.upToDate': 'Abonex est déjà à jour.',
    'update.checkFail': 'Vérification impossible — réessayez.',
    'update.available': 'Mise à jour disponible',
    'update.body':
        'La version {latest} est disponible (installée : {current}).\n\n'
        'Voulez-vous télécharger la mise à jour maintenant, ou rester '
        'sur la version actuelle ?',
    'update.action': 'Mettre à jour',

    // Rôles
    'role.owner': 'Propriétaire',
    'role.manager': 'Gestionnaire',
    'role.assistant': 'Assistant',
    'role.viewer': 'Lecteur',
  };

  // ───────────────────────── ENGLISH ─────────────────────────
  static const _en = <String, String>{
    'nav.home': 'Home',
    'nav.subscriptions': 'Subscriptions',
    'nav.calendar': 'Calendar',
    'nav.reports': 'Reports',
    'nav.profile': 'Profile',
    'nav.notifications': 'Notifications',

    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.retry': 'Retry',
    'common.refresh': 'Refresh',
    'common.save': 'Save',
    'common.add': 'Add',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.send': 'Send',
    'common.later': 'Later',
    'common.email': 'Email',
    'common.amount': 'Amount',
    'common.required': 'Required field',
    'common.requiredShort': 'Required',
    'common.loadError': 'Could not load',
    'common.unexpected': 'Unexpected error.',

    'error.network': 'No internet connection.',
    'error.networkLong':
        'Could not reach the server. Check your connection '
        'and try again.',
    'error.auth': 'Invalid credentials.',
    'error.cache': 'Local cache error.',
    'error.unexpected': 'An unexpected error occurred.',
    'error.400': 'Invalid request. Check the information entered.',
    'error.401': 'Session expired or invalid credentials.',
    'error.403': 'Action not allowed for your role.',
    'error.404': 'Service not found. The server address may have changed.',
    'error.409': 'This data already exists.',
    'error.422': 'Invalid data. Check the form.',
    'error.429': 'Too many attempts. Please wait a moment.',
    'error.500': 'The server is having trouble. Try again later.',
    'error.other': 'An error occurred (code {code}). Try again.',

    'status.paid': 'Paid',
    'status.dueSoon': 'Upcoming',
    'status.overdue': 'Overdue',
    'status.done': 'Done',
    'status.settled': 'Settled',
    'cycle.monthly': 'Monthly',
    'cycle.quarterly': 'Quarterly',
    'cycle.yearly': 'Yearly',
    'cycle.daily': 'Every day',
    'cycle.weekly': 'Every week',
    'cycle.once': 'One-time',
    'cycle.perMonthly': 'per month',
    'cycle.perQuarterly': 'per quarter',
    'cycle.perYearly': 'per year',
    'cycle.perDaily': 'per day',
    'cycle.perWeekly': 'per week',
    'cycle.perOnce': 'one-time payment',
    'category.software': 'Software',
    'category.rent': 'Rent',
    'category.insurance': 'Insurance',
    'category.telecom': 'Telecom',
    'category.energy': 'Energy',
    'category.water': 'Water',
    'category.payroll': 'Payroll',
    'category.transport': 'Transport',
    'category.event': 'Event',
    'category.other': 'Other (food, health…)',
    'event.label': 'Event',

    'date.today': 'Today',
    'date.tomorrow': 'Tomorrow',
    'date.late': '{n} d overdue',
    'date.in': 'In {n} d',
    'cal.weekdays': 'M T W T F S S',

    'dash.greeting': 'Hello, {name}',
    'dash.spent': 'Spent this month',
    'dash.toPay': 'Left to pay',
    'dash.count': '{n} subscription{s} tracked',
    'dash.events': '{n} appointment{s}',
    'dash.updateHint':
        'Water bill, electricity bill, salary or a new subscription '
        'to track? Remember to keep your list up to date.',
    'dash.overdue': '{n} overdue payment{s}{total}',
    'dash.upcoming': 'Upcoming payments',
    'dash.budget': 'Monthly budget',
    'dash.budgetTitle': 'Monthly budget',
    'dash.budgetEdit': 'Edit',
    'dash.budgetSet': 'Set',
    'dash.budgetHint': 'Set your monthly budget to track your spending.',
    'dash.budgetUnavailable': 'Budget unavailable — retry',
    'dash.budgetFail': 'Budget not saved. Try again.',
    'dash.committed': '{amount} committed',
    'dash.budgetPct': '{pct}% of {amount}',
    'dash.over': 'Over by {amount}',
    'dash.byCategory': 'Spending by category',
    'reminder.dialogTitle': 'Payment reminder',
    'reminder.overdueBody': '{n} overdue payment{s}{total}.',
    'reminder.more': 'and {n} other{s}…',
    'reminder.viewDue': 'View due dates',
    'toast.paid': '{name} marked as paid.',
    'toast.done': '{name} marked as done.',

    'subs.search': 'Search a subscription…',
    'subs.integrations': 'Import & integrations',
    'filter.all': 'All',
    'filter.paid': 'Paid',
    'filter.done': 'Done',
    'filter.dueSoon': 'Upcoming',
    'filter.overdue': 'Overdue',
    'subs.empty': 'No subscriptions',
    'subs.emptySub': 'Add your first recurring payment to start tracking.',
    'subs.addFirst': 'Add a subscription',
    'subs.noResult': 'No results',
    'subs.noResultSub': 'Adjust the search or the filters.',
    'subs.tabSubs': 'Subscriptions',
    'subs.tabEvents': 'Appointments',
    'subs.emptySubs': 'No subscriptions yet',
    'subs.emptyEvents': 'No appointments yet',

    'form.editTitle': 'Edit — {name}',
    'form.newEvent': 'New event',
    'form.newSub': 'New subscription',
    'form.typeSub': 'Subscription',
    'form.typeEvent': 'Event',
    'form.import': 'Import multiple subscriptions or pick a service',
    'form.name': 'Name',
    'form.title': 'Title',
    'form.nameHint': 'E.g. Office rent',
    'form.titleHint': 'E.g. Interview, meeting, doctor appointment…',
    'form.provider': 'Provider (optional)',
    'form.providerHint': 'Pick or type a provider',
    'form.providerLoading': 'Loading providers for your country…',
    'form.providerHelper':
        'Based on your account country. Provider missing? Type its name.',
    'form.providerFail': 'Catalog unavailable — retry',
    'form.description': 'Description (optional)',
    'form.descHint': 'E.g. EDF plan — Paris 11th flat',
    'form.descHintEvent': 'E.g. Offices — Bonanjo, Douala',
    'form.amountInvalid': 'Invalid amount',
    'form.cycle': 'Billing cycle',
    'form.recurrence': 'Repeat reminder',
    'form.category': 'Category',
    'form.country': 'Subscription country',
    'form.firstDue': 'First due date: {date}',
    'form.date': 'Date: {date}',
    'form.time': 'Time (optional)',
    'form.timeSet': 'Time: {time}',
    'form.noTime': 'No time',
    'form.reminderInfo':
        'You will be alerted before this date based on your reminder settings.',
    'form.onceDue': 'One-time due date: {date}',
    'form.nextDue': 'Next due date: {date}',
    'form.advanced': 'Advanced options',
    'form.advancedSub': 'Start date, contract end…',
    'form.startDate': 'Start date (e.g. last Sunday)',
    'form.started': 'Started: {date}',
    'form.unknownDate': 'Unknown date',
    'form.endDate': 'Contract end',
    'form.ends': 'Ends: {date}',
    'form.noEnd': 'No end date',
    'form.submitting': 'Saving…',
    'form.saveChanges': 'Save changes',
    'form.createReminder': 'Create reminder',
    'form.add': 'Add subscription',
    'form.saved': 'Changes saved.',
    'form.eventSaved': 'Event saved.',
    'form.subSaved': 'Subscription added.',
    'form.pickFirstDue': 'First due date',
    'form.pickStart': 'Subscription start date',
    'form.pickEnd': 'Contract end',
    'form.pickTime': 'Event time',

    'detail.title': 'Details',
    'detail.notFound': 'Subscription not found',
    'detail.notFoundSub': 'It may have been deleted.',
    'detail.eventDate': 'Event date',
    'detail.time': 'Time',
    'detail.countdown': 'Countdown',
    'detail.nextDue': 'Next due date',
    'detail.billingCycle': 'Billing cycle',
    'detail.category': 'Category',
    'detail.provider': 'Provider',
    'detail.country': 'Country',
    'detail.description': 'Description',
    'detail.at': 'at {time}',
    'detail.markPaid': 'Mark as paid',
    'detail.markDone': 'Mark as done',
    'detail.deleteTitle': 'Delete?',
    'detail.deleteBody': '"{name}" will be permanently removed from tracking.',
    'detail.deleted': 'Subscription deleted.',
    'detail.history': 'Payment history',
    'detail.historyEmpty': 'No payments recorded.',
    'detail.historyFail': 'History unavailable',
    'detail.paidOn': 'Paid on {date}',

    'cal.select': 'Select a day',
    'cal.none': 'Nothing due',
    'cal.noneSub': 'Nothing to pay that day.',

    'reports.events': 'Events',
    'reports.noData': 'No data',
    'reports.noDataSub': 'Add subscriptions to see reports.',
    'reports.noExpenses': 'No expenses',
    'reports.noExpensesSub': 'Add billed subscriptions to see reports.',
    'reports.byCategory': 'Breakdown by category',
    'reports.perMonth': 'per month (equivalent)',
    'reports.forecast': 'Due dates, next 6 months',

    'notif.empty': 'No notifications',
    'notif.emptySub':
        'All your payments are settled. We will let you know as soon '
        'as a payment is coming up.',
    'notif.pastEvent': 'Past event',
    'notif.duePassed': 'Payment overdue',
    'notif.expected': '{amount} — due {date}',
    'notif.dueToday': 'Due today',
    'notif.dueIn': 'Due in {n} d',
    'notif.hint':
        'New bill or untracked subscription? Add it for complete reminders.',

    'ns.eventToday': 'Event today: {name}',
    'ns.dueToday': 'Due today: {name}',
    'ns.eventTomorrow': 'Event tomorrow: {name}',
    'ns.dueTomorrow': 'Due tomorrow: {name}',
    'ns.eventIn': 'Event in {n} d: {name}',
    'ns.dueIn': 'Due in {n} d: {name}',
    'ns.payBody': '{provider} — {amount} to pay.',
    'ns.eventTime': 'It\'s time — {date}',
    'ns.eventTitle': 'Event: {name}',
    'ns.dueAlarmTitle': 'Due now: {name}',
    'ns.soonEvent': 'Event in {h}: {name}',
    'ns.soonDue': 'Due in {h}: {name}',
    'ns.snooze': 'Snooze 10 min',
    'ns.stop': 'Stop',
    'ns.weeklyTitle': 'Abonex — list up to date?',
    'ns.weeklyBody':
        'Remember to add your new bills and subscriptions for '
        'complete tracking.',
    'ns.overdueTitle': 'Still overdue: {name}',
    'ns.markPaid': 'Mark as paid',
    'ns.markDone': 'Mark as done',
    'ns.channelReminders': 'Important reminders',
    'ns.channelRemindersDesc':
        'Sound alerts before payments and tracking reminders.',
    'ns.channelUrgent': 'Due-date alarms',
    'ns.channelUrgentDesc':
        'Full-screen reminders with ringtone for payments due today.',
    'ns.channelEvent': 'Event alarms',
    'ns.channelEventDesc':
        'Rings at the exact event time until stopped or snoozed.',

    'int.title': 'Import & integrations',
    'int.csvTitle': 'Import a file',
    'int.csvSub':
        'CSV with columns: name, provider, category, amount, '
        'currency, cycle, next_due_date',
    'int.csvPick': 'Pick a CSV file',
    'int.connections': 'Connected accounts',
    'int.connectionsSub':
        'Re-sync in one tap — your credentials stay encrypted '
        'server-side.',
    'int.resync': 'Re-sync',
    'int.disconnect': 'Disconnect',
    'int.connectors': 'Professional connections',
    'int.connectorsSub':
        'These integrations require API keys from the provider, '
        'not your usual password. Available data varies by service; '
        'some amounts and dates still need to be filled in. Payment '
        'connectors cover subscriptions billed to your customers.',
    'int.connect': 'Connect',
    'int.connectTitle': 'Connect {name}',
    'int.connectGo': 'Connect and analyze',
    'int.noneDetected': 'No service detected on this account.',
    'int.syncFail': 'Sync failed.',
    'int.connectFail': 'Could not connect to the provider.',
    'int.disconnectFail': 'Could not disconnect.',
    'int.disconnected': '{name} disconnected.',
    'int.csvEmpty': 'Empty file or missing headers.',
    'int.csvNoRows': 'No valid row in the file.',
    'int.csvImported': '{n} subscription(s) imported{skipped}.',
    'int.csvSkipped': ' — {n} row(s) skipped',
    'int.csvFail': 'Unreadable file. Check the CSV format.',
    'int.importFail': 'Import failed. Try again.',
    'int.presetAdded': '{name} added to your subscriptions.',
    'int.popular': 'Popular services',
    'int.popularSub':
        'Netflix, Spotify & co do not publish billing dates via API — '
        'pick the service, everything is pre-filled, you only set the '
        'renewal date.',
    'int.searchService': 'Search a service…',
    'int.detected': '{n} detected service(s)',
    'int.detectedSub':
        'Check then import — the amount still needs to be filled in '
        'if the provider does not publish it.',
    'int.due': 'due: {date}',
    'int.dueUndefined': 'to set',
    'int.more': '… and {n} other(s)',
    'int.import': 'Import {n} subscription(s)',
    'int.groupPayments': 'Recurring payments',
    'int.groupCloud': 'Cloud, servers & SaaS',
    'int.groupDomains': 'Domains & registrars',
    'int.groupOther': 'Other',
    'int.catStreaming': 'Streaming & TV',
    'int.catMusic': 'Music',
    'int.catStorage': 'Cloud storage',
    'int.catGaming': 'Video games',
    'int.catProductivity': 'Productivity & pro tools',
    'int.catSecurity': 'Security & VPN',
    'int.addPreset': 'Add {name}',
    'int.presetSub':
        'Amount and cycle pre-filled — adjust if your plan differs, '
        'then set the next debit date.',
    'int.renewal': 'Next renewal',
    'int.nextDebit': 'Next debit: {date}',
    'int.addToMine': 'Add to my subscriptions',

    'bank.title': 'Bank sync',
    'bank.sub':
        'Automatically detects your recurring payments (energy, '
        'water, telecom, rent, streaming…) straight from your bank '
        'statement. You sign in to your bank through our licensed '
        'partner — Abonex never sees your banking credentials.',
    'bank.connect': 'Connect my bank',
    'bank.fail': 'Bank connection failed — please try again.',

    'users.info': 'Permissions are verified server-side on every action.',
    'users.invite': 'Invite',
    'users.inviteTitle': 'Invite a collaborator',
    'users.role': 'Role',
    'users.roleManager': 'Manager — manage everything',
    'users.roleAssistant': 'Assistant — mark as paid/done',
    'users.roleViewer': 'Viewer — read only',
    'users.inviteSent': 'Invitation sent to {email}.',
    'users.inviteFail': 'Could not send the invitation.',
    'users.loadFail': 'Could not load users.',
    'users.roleFail': 'Could not change this role.',
    'users.roleChanged': '{email} is now {role}.',
    'users.changeRole': 'Change role',

    'auth.welcome': 'Welcome to Abonex',
    'auth.loginSub': 'Sign in to manage your subscriptions with ease.',
    'auth.emailHint': 'you@company.com',
    'auth.emailPro': 'Work email',
    'auth.emailInvalid': 'Enter a valid email',
    'auth.password': 'Password',
    'auth.passwordMin': '8 characters minimum',
    'auth.forgot': 'Forgot password?',
    'auth.login': 'Sign in',
    'auth.newHere': 'New to Abonex?',
    'auth.createAccount': 'Create an account',
    'auth.haveInvite': 'I have an invitation',
    'auth.secure': 'Secure connection',
    'auth.resetTitle': 'Reset password',
    'auth.resetSent':
        'If an account exists for this email, a link has been sent.',
    'auth.createTitle': 'Create your workspace',
    'auth.createSub': 'Your owner account is created in seconds.',
    'auth.country': 'Country',
    'auth.countryHelper': 'Currency: {currency} — adjustable later',
    'auth.confirmPassword': 'Confirm password',
    'auth.passwordMismatch': 'Passwords do not match',
    'auth.terms': 'I accept the terms of use and the privacy policy.',
    'auth.acceptTerms': 'Accept the terms to continue.',
    'auth.creating': 'Creating…',
    'auth.create': 'Create my account',
    'auth.dataSecure': 'Your data is secured server-side.',

    'invite.title': 'Join a workspace',
    'invite.sub':
        'Paste the invitation link received by email and choose '
        'your password.',
    'invite.link': 'Invitation link or code',
    'invite.linkHint': 'abonex://invite/…',
    'invite.linkRequired': 'Link required',
    'invite.invalid': 'Invalid or expired invitation link.',
    'invite.join': 'Join the workspace',

    'reset.title': 'New password',
    'reset.sub':
        'Paste the link received by email and choose a new '
        'password.',
    'reset.link': 'Reset link',
    'reset.linkHint': 'abonex://reset/…',
    'reset.linkRequired': 'Link required',
    'reset.newPassword': 'New password',
    'reset.submit': 'Reset password',
    'reset.done': 'Password reset — you can sign in.',
    'reset.invalid': 'Invalid or expired link.',
    'reset.haveLink': 'I have a reset link',

    'onb.skip': 'Skip',
    'onb.next': 'Continue',
    'onb.start': 'Get started',
    'onb.1.badge': 'Expense tracking',
    'onb.1.title': 'Master every penny\nyou spend',
    'onb.1.desc':
        'Abonex centralizes your subscriptions, bills, rent and payroll '
        '— business or household, you always know where your money goes.',
    'onb.2.badge': 'Smart reminders',
    'onb.2.title': 'Never miss\na due date',
    'onb.2.desc':
        'Automatic reminders before each payment, full-screen alert on '
        'the day: never pay a late fee again.',
    'onb.3.badge': 'Team & security',
    'onb.3.title': 'Collaborate with\npeace of mind',
    'onb.3.desc':
        'Invite collaborators with precise roles: everyone sees and does '
        'exactly what you decided.',
    'onb.expenses': 'Monthly spending',
    'onb.bills': 'Bills',
    'onb.rent': 'Rent',
    'onb.salary': 'Payroll',
    'onb.rentTomorrow': 'Rent tomorrow',
    'onb.dueToday': 'Due today',

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
    'profile.app': 'App',
    'profile.users': 'Users & roles',
    'profile.usersSub': 'Invite people, change permissions',
    'profile.integrations': 'Import & integrations',
    'profile.integrationsSub': 'CSV file, connected OVH/IONOS accounts',
    'profile.logout': 'Log out',
    'auth.verified': 'Email address verified.',
    'auth.personal': 'Personal',
    'auth.business': 'Business',
    'auth.personalHint':
        'Track your personal subscriptions and appointments.',
    'auth.businessHint':
        'Personal + employee management, roles and payroll.',
    'emp.title': 'Employees',
    'emp.empty': 'No employees',
    'emp.emptySub':
        'Add your employees — each payroll becomes a '
            'tracked monthly due.',
    'emp.add': 'Add an employee',
    'emp.edit': 'Edit employee',
    'emp.name': 'Full name',
    'emp.position': 'Position / role',
    'emp.salary': 'Monthly salary',
    'emp.payDay': 'Pay day (day of month)',
    'emp.active': 'Active employee',
    'emp.activeSub':
        'Inactive: payroll is no longer tracked as a due',
    'emp.deleted': 'Employee deleted.',
    'emp.saved': 'Employee saved — payroll tracked '
        'automatically.',
    'emp.payroll': 'Payroll: {amount}/month',
    'auth.verifyFail': 'Verification link invalid or expired.',
    'profile.dataSection': 'Data & account',
    'profile.employees': 'Employees',
    'profile.employeesSub':
        'Payrolls tracked as monthly dues',
    'profile.exportData': 'Export my data (CSV)',
    'profile.exportDataSub':
        'Subscriptions, payments — spreadsheet format',
    'profile.exportFail': 'Export failed.',
    'profile.deleteAccount': 'Delete account',
    'profile.deleteAccountSub':
        'Permanent — all your data is erased',
    'profile.deleteWarn':
        'This action is irreversible: subscriptions, payments '
            'and workspace will be deleted. Confirm with your '
            'password.',
    'profile.deleted': 'Account deleted.',
    'profile.deleteFail': 'Could not delete: check the password.',
    'profile.edit': 'Edit profile',
    'profile.firstName': 'First name',
    'profile.lastName': 'Last name',
    'profile.saving': 'Saving…',
    'profile.save': 'Save',
    'profile.updated': 'Profile updated.',
    'profile.unexpected': 'Unexpected error.',
    'profile.photo.change': 'Change photo',
    'profile.photo.remove': 'Remove',
    'profile.photo.updated': 'Profile photo updated.',
    'profile.photo.removed': 'Profile photo removed.',
    'profile.currency': 'Base currency',
    'profile.password': 'Password',
    'profile.passwordSub': 'Change your password',
    'profile.password.current': 'Current password',
    'profile.password.new': 'New password',
    'profile.password.confirm': 'Confirm new password',
    'profile.password.mismatch': 'Passwords do not match.',
    'profile.password.changed': 'Password updated.',
    'settings.theme': 'Theme',
    'settings.language': 'Language',
    'settings.biometric': 'Biometric lock',
    'settings.biometricSub': 'Fingerprint or Face ID when opening the app',
    'settings.biometricUnavailable':
        'Biometrics unavailable or verification cancelled.',
    'settings.biometricReason': 'Unlock Abonex',
    'settings.biometricConfirm': 'Confirm to enable biometric unlock',
    'settings.sound': 'Sound reminders',
    'settings.soundSub': 'Full-screen alarm on the due date',
    'reminder.title': 'Due-date reminders',
    'reminder.remindMe': 'Remind me:',
    'reminder.dayJ': 'On the day',
    'reminder.hour': 'Reminder time:',
    'reminder.atLeastOne': 'Choose at least one reminder.',
    'reminder.summary': '{days} at {hour}:00',

    'alarm.title': 'Alarm ringtone',
    'alarm.choose': 'Choose ringtone',
    'alarm.opt.default': 'System (default)',
    'alarm.opt.classic': 'Classic',
    'alarm.opt.digital': 'Digital',
    'alarm.opt.chime': 'Chime',
    'alarm.opt.custom': 'Custom: {name}',
    'alarm.import': 'Import a sound…',
    'alarm.imported': 'Ringtone imported: {name}',
    'alarm.test': 'Listen',
    'alarm.previewTitle': 'Ringtone preview',
    'alarm.previewBody': 'This is your alarm ringtone.',
    'alarm.disabled': 'Notifications are off — alarms will not ring.',
    'alarm.enable': 'Enable',
    'alarm.blocked':
        'Notifications blocked — enable them for Abonex in '
        'the phone settings.',
    'alarm.battery': 'Make alarms reliable',
    'alarm.batterySub': 'Exclude Abonex from battery saving',
    'alarm.exactWarn': 'Exact alarms denied — ringtones may be delayed.',
    'alarm.exactEnable': 'Allow exact alarms',
    'alarm.testRing': 'Test the alarm',
    'alarm.testScheduled': 'Test alarm in 30 s — leave the app!',
    'alarm.testTitle': 'Abonex alarm test',
    'alarm.testBody': 'If you can hear this, due-time alarms work.',
    'alarm.volumeHint':
        'Alarm sound follows the phone\'s Alarm volume '
        '(separate from ringtone volume).',

    'update.title': 'App update',
    'update.installed': 'Installed version: {v}',
    'update.upToDate': 'Abonex is up to date.',
    'update.checkFail': 'Check failed — try again.',
    'update.available': 'Update available',
    'update.body':
        'Version {latest} is available (installed: {current}).\n\n'
        'Do you want to download the update now, or stay on the '
        'current version?',
    'update.action': 'Update',

    'role.owner': 'Owner',
    'role.manager': 'Manager',
    'role.assistant': 'Assistant',
    'role.viewer': 'Viewer',
  };
}
