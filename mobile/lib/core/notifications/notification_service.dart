import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/subscriptions/domain/entities/subscription.dart';
import '../di/injection.dart';
import '../l10n/app_strings.dart';
import '../storage/settings_storage.dart';
import '../utils/formatters.dart';

/// Action sur l'alarme de rendez-vous reçue hors de l'app (app
/// fermée ou en arrière-plan) : exécutée dans un isolate dédié,
/// d'où l'annotation et l'initialisation locale du fuseau horaire.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse r) async {
  if (r.actionId != NotificationService.actionSnooze) return;
  tz_data.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (_) {}
  await NotificationService.snoozeFromPayload(r.payload);
}

/// Rappels locaux d'échéances (CDC : anticiper chaque paiement).
/// Chaque échéance reçoit des rappels sonores aux jours choisis,
/// des rappels rapprochés (3h et 1h avant) quand l'heure est
/// connue, puis une ALARME plein écran à l'heure exacte.
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Texte traduit sans BuildContext — les notifications sont
  /// construites hors de l'arbre de widgets.
  static String _t(String key, [Map<String, String>? args]) =>
      AppStrings.t(AppFormatters.lang, key, args);

  // Suffixe _v3 : les canaux Android sont IMMUABLES — une version
  // précédente a pu créer ces canaux avec une ressource sonore
  // absente (APK antérieur à l'ajout des sonneries) ; ils resteraient
  // silencieux à vie. Nouvel ID → canal recréé proprement.
  static const _channelId = 'abonex_due_reminders_v3';
  static String get _channelName => _t('ns.channelReminders');
  static String get _channelDesc => _t('ns.channelRemindersDesc');

  // Canal "alarme" : notification plein écran par-dessus
  // l'écran verrouillé, sonnerie forte — impossible à manquer.
  // Le suffixe _v3 invalide les anciens canaux : Android rend
  // les attributs audio d'un canal immuables après sa création.
  static const _urgentChannelId = 'abonex_urgent_v3';
  static String get _urgentChannelName => _t('ns.channelUrgent');
  static String get _urgentChannelDesc => _t('ns.channelUrgentDesc');

  // Canal dédié aux rendez-vous : sonnerie d'alarme en boucle
  // jusqu'à ce que l'utilisateur arrête ou repousse.
  static const _eventChannelId = 'abonex_event_alarm_v3';
  static String get _eventChannelName => _t('ns.channelEvent');
  static String get _eventChannelDesc => _t('ns.channelEventDesc');

  static const actionStop = 'stop';
  static const actionSnooze = 'snooze';
  static const _snoozeDuration = Duration(minutes: 10);

  // Plages d'identifiants : rappels classiques 0-149, rappels de
  // relance (en retard) 150-299, hebdo 999, alarmes d'échéance
  // 1000-2999, aperçu 3000, reports (snooze) 4000-5999.
  static const _maxRegular = 150;
  static const _overdueIdBase = 150;
  static const _maxOverdue = 150;
  static const _eventIdBase = 1000;
  static const _snoozeIdBase = 4000;
  static const _idRange = 2000;

  // FLAG_INSISTENT : le son se répète jusqu'à fermeture.
  static final _insistent = Int32List.fromList(const <int>[4]);

  static NotificationDetails get _notificationDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  /// Canal natif vers MainActivity : copie d'un fichier audio dans
  /// le MediaStore Android (URI content:// lisible par le système —
  /// certains appareils refusent les sons android.resource:// sur
  /// les canaux de notification).
  static const _mediaStore = MethodChannel('abonex/media_store');

  /// Garantit qu'une sonnerie INTÉGRÉE existe dans le MediaStore et
  /// retourne son URI content:// (cache dans les préférences — la
  /// copie n'est faite qu'une fois). Retourne null en cas d'échec
  /// (isolate de fond sans accès assets/canal → repli res/raw).
  static Future<String?> _builtinMediaStoreUri(String key) async {
    const prefKey = 'alarm_ms_uri_';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$prefKey$key');
      if (cached != null && cached.startsWith('content://')) {
        return cached;
      }
      final bytes = await rootBundle.load('assets/sounds/alarm_$key.wav');
      final dir = await getApplicationSupportDirectory();
      final tmp = File('${dir.path}/alarm_$key.wav');
      await tmp.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      final uri = await _mediaStore.invokeMethod<String>('importSound', {
        'path': tmp.path,
        'name': 'builtin_$key',
      });
      if (uri != null && uri.startsWith('content://')) {
        await prefs.setString('$prefKey$key', uri);
        return uri;
      }
    } catch (e) {
      debugPrint('Abonex: copie MediaStore de la sonnerie $key — $e');
    }
    return null;
  }

  /// Canal + son selon la sonnerie choisie par l'utilisateur.
  /// Android grave le son dans le canal à sa création : un ID
  /// distinct par choix est requis (le son d'un canal existant
  /// est immuable côté système).
  static Future<(String, AndroidNotificationSound?)> _alarmChannelFor(
    String base, {
    /// Permet d'écouter une sonnerie qui n'est pas encore celle
    /// sauvegardée (sélection survolée dans le dialogue).
    String? selection,
  }) async {
    var sel = selection ?? 'default';
    String? customPath;
    var rev = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      sel = selection ?? prefs.getString(SettingsStorage.kAlarmSound) ?? 'default';
      customPath = prefs.getString(SettingsStorage.kAlarmCustomPath);
      rev = prefs.getInt(SettingsStorage.kAlarmCustomRev) ?? 0;
    } catch (_) {}
    // Sonneries intégrées : de préférence une copie MediaStore en
    // content:// — certains téléphones (XOS notamment) refusent de
    // jouer les sons android.resource:// sur les canaux, alors que
    // content:// fonctionne (c'est le chemin de l'import, éprouvé).
    // Suffixe _ms dans l'ID de canal : un éventuel canal cassé créé
    // avec res/raw n'est jamais réutilisé.
    if (sel == 'classic' || sel == 'digital' || sel == 'chime') {
      final msUri = await _builtinMediaStoreUri(sel);
      if (msUri != null) {
        return ('${base}_${sel}_ms', UriAndroidNotificationSound(msUri));
      }
      return (
        '${base}_$sel',
        RawResourceAndroidNotificationSound('alarm_$sel'),
      );
    }
    return switch (sel) {
      'custom' when customPath != null => (
          '${base}_custom_$rev',
          // content:// (MediaStore, lisible par le système) ou
          // file:// en repli — l'URI est stockée telle quelle.
          UriAndroidNotificationSound(
            customPath.contains('://') ? customPath : 'file://$customPath',
          ),
        ),
      _ => (base, null),
    };
  }

  /// Crée le canal Android porteur du son choisi (no-op sur iOS).
  static Future<void> _createChannel(
    FlutterLocalNotificationsPlugin plugin,
    AndroidNotificationChannel channel,
  ) => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel) ??
      Future.value();

  static NotificationDetails _urgentDetails(
    String channelId,
    AndroidNotificationSound? sound,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      _urgentChannelName,
      channelDescription: _urgentChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      sound: sound,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  static NotificationDetails _eventAlarmDetails(
    String channelId,
    AndroidNotificationSound? sound,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      _eventChannelName,
      channelDescription: _eventChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      additionalFlags: _insistent,
      sound: sound,
      actions: [
        AndroidNotificationAction(
          actionSnooze,
          _t('ns.snooze'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionStop,
          _t('ns.stop'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: _eventChannelId,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _eventChannelId,
              actions: [
                DarwinNotificationAction.plain(actionSnooze, _t('ns.snooze')),
                DarwinNotificationAction.plain(
                  actionStop,
                  _t('ns.stop'),
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _urgentChannelId,
        _urgentChannelName,
        description: _urgentChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _eventChannelId,
        _eventChannelName,
        description: _eventChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    // Chaque demande de permission est isolée : une plateforme qui
    // lève une exception ici ne doit PAS empêcher _initialized de
    // passer à true — sinon scheduleDueReminders sortirait en
    // silence et AUCUNE alarme ne serait jamais programmée.
    try {
      await android?.requestNotificationsPermission();
    } catch (_) {}
    try {
      // Autorisation plein écran (rappel type alarme).
      await android?.requestFullScreenIntentPermission();
    } catch (_) {}
    try {
      // Alarme à l'heure exacte du rendez-vous (Android 12+).
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
    _initialized = true;
  }

  /// Action sur l'alarme quand l'app est au premier plan.
  Future<void> _onResponse(NotificationResponse r) async {
    if (r.actionId == actionSnooze) await snoozeFromPayload(r.payload);
  }

  /// Un plantage de planification sur UNE échéance ne doit jamais
  /// annuler les suivantes — sans ce garde-fou, une seule
  /// PlatformException (permission, canal, date) stoppait la boucle
  /// et TOUTES les alarmes prévues après n'étaient pas programmées.
  static Future<void> _safeSchedule(
    Future<void> Function() run,
    String label,
  ) async {
    try {
      await run();
    } catch (e) {
      debugPrint('Abonex: échec de programmation ($label) — $e');
    }
  }

  /// Replanifie tous les rappels à chaque chargement de la liste :
  /// simple et toujours cohérent avec l'état serveur.
  Future<void> scheduleDueReminders(List<Subscription> subs) async {
    if (!_initialized) return;
    // On ne touche pas aux reports (snooze) en cours : ils doivent
    // survivre à un rafraîchissement de la liste.
    for (var i = 0; i < _overdueIdBase + _maxOverdue; i++) {
      await _plugin.cancel(id: i);
    }
    await _plugin.cancel(id: 999);
    for (var i = 0; i < _idRange; i++) {
      await _plugin.cancel(id: _eventIdBase + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    // Réglages personnalisés : jours d'anticipation + heure +
    // mode alarme — tout vient du profil utilisateur.
    final settings = getIt<SettingsStorage>();
    // Les textes des notifications suivent la langue persistée.
    AppFormatters.lang = settings.locale.languageCode;
    final urgent = settings.soundAlerts;
    final reminderDays = settings.reminderDays;
    final reminderHour = settings.reminderHour;
    // Canal d'alarme jour J avec la sonnerie choisie (le son se
    // fixe à la création du canal → un canal par choix).
    final (urgentChannel, urgentSound) = await _alarmChannelFor(
      _urgentChannelId,
    );
    await _createChannel(
      _plugin,
      AndroidNotificationChannel(
        urgentChannel,
        _urgentChannelName,
        description: _urgentChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: urgentSound,
      ),
    );
    final urgentDetails = _urgentDetails(urgentChannel, urgentSound);
    var id = 0;
    // Déduplique les jours choisis (ex. J-7 et J tombant le même
    // jour ne doivent produire qu'UN rappel).
    final days = {...reminderDays}.toList()..sort();
    for (final sub in subs) {
      if (sub.status != SubscriptionStatus.dueSoon) continue;
      for (final daysBefore in days) {
        var when = tz.TZDateTime(
          tz.local,
          sub.nextDueDate.year,
          sub.nextDueDate.month,
          sub.nextDueDate.day - daysBefore,
          reminderHour,
        );
        final isToday =
            daysBefore == 0 &&
            sub.nextDueDate.year == now.year &&
            sub.nextDueDate.month == now.month &&
            sub.nextDueDate.day == now.day;
        // Échéance à heure fixe : le jour J, c'est l'alarme exacte
        // qui prévient — pas de doublon à l'heure de rappel.
        if (isToday && sub.dueTime != null) continue;
        if (when.isBefore(now)) {
          // Rappel passé → on le saute SAUF le jour J même,
          // qui mérite une alerte immédiate.
          if (!isToday) continue;
          when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
        }
        if (id >= _maxRegular) break;
        final notifId = id++;
        await _safeSchedule(
          () => _plugin.zonedSchedule(
            id: notifId,
            title: daysBefore == 0
                ? _t(sub.isEvent ? 'ns.eventToday' : 'ns.dueToday', {
                    'name': sub.name,
                  })
                : daysBefore == 1
                ? _t(sub.isEvent ? 'ns.eventTomorrow' : 'ns.dueTomorrow', {
                    'name': sub.name,
                  })
                : _t(sub.isEvent ? 'ns.eventIn' : 'ns.dueIn', {
                    'n': '$daysBefore',
                    'name': sub.name,
                  }),
            body: sub.isEvent
                ? _eventBody(sub)
                : _t('ns.payBody', {
                        'provider': sub.provider,
                        'amount': AppFormatters.money(sub.amount, sub.currency),
                      }) +
                      _descSuffix(sub),
            scheduledDate: when,
            // Jour J + rappels sonores activés → alarme plein écran.
            notificationDetails: urgent && daysBefore == 0
                ? urgentDetails
                : _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'subscription:${sub.id}',
          ),
          'reminder:${sub.id}',
        );
      }
    }

    // Relances des échéances EN RETARD : sans elles, un paiement
    // dépassé tombait dans l'oubli — le planificateur ne suivait
    // que les échéances "à venir". Un rappel quotidien à l'heure
    // de rappel tant que l'échéance reste impayée (reprogrammé à
    // chaque chargement de la liste → cohérent avec le serveur).
    var overdueId = _overdueIdBase;
    for (final sub in subs) {
      if (sub.status != SubscriptionStatus.overdue) continue;
      if (overdueId >= _overdueIdBase + _maxOverdue) break;
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminderHour,
      );
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      final notifId = overdueId++;
      await _safeSchedule(
        () => _plugin.zonedSchedule(
          id: notifId,
          title: _t('ns.overdueTitle', {'name': sub.name}),
          body: _t('ns.payBody', {
                'provider': sub.provider,
                'amount': AppFormatters.money(sub.amount, sub.currency),
              }) +
              _descSuffix(sub),
          scheduledDate: when,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Quotidien : repart chaque jour à la même heure jusqu'à
          // ce que l'échéance soit soldée (ou la liste rechargée).
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'subscription:${sub.id}',
        ),
        'overdue:${sub.id}',
      );
    }

    // Rappels rapprochés le jour J pour les échéances à heure
    // fixe : notification sonore 3h puis 1h avant l'heure exacte —
    // l'anticipation se densifie à mesure que l'échéance approche.
    for (final sub in subs) {
      if (sub.dueTime == null) continue;
      if (sub.status == SubscriptionStatus.paid) continue;
      for (final offset in const [Duration(hours: 3), Duration(hours: 1)]) {
        final when = tz.TZDateTime.from(
          sub.dueAt.subtract(offset),
          tz.local,
        );
        if (!when.isAfter(now)) continue;
        if (id >= _maxRegular) break;
        final notifId = id++;
        await _safeSchedule(
          () => _plugin.zonedSchedule(
            id: notifId,
            title: _t(sub.isEvent ? 'ns.soonEvent' : 'ns.soonDue', {
              'h': '${offset.inHours} h',
              'name': sub.name,
            }),
            body: sub.isEvent
                ? AppFormatters.dateTimeLong(sub.dueAt)
                : _t('ns.payBody', {
                        'provider': sub.provider,
                        'amount': AppFormatters.money(sub.amount, sub.currency),
                      }) +
                      _descSuffix(sub),
            scheduledDate: when,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'subscription:${sub.id}',
          ),
          'soon:${sub.id}',
        );
      }
    }

    // Alarme exacte à la date/heure : sonnerie en boucle jusqu'à
    // Arrêter / Repousser — pour les rendez-vous ET tout abonnement
    // dont l'échéance précise l'heure.
    for (final sub in subs) {
      if (sub.dueTime == null) continue;
      if (sub.status == SubscriptionStatus.paid) continue;
      final when = tz.TZDateTime.from(sub.dueAt, tz.local);
      if (!when.isAfter(now)) continue;
      // hashCode peut être négatif → abs() obligatoire, et la plage
      // est large (2000) pour limiter les collisions entre IDs.
      final numericId = int.tryParse(sub.id) ?? sub.id.hashCode.abs();
      final title = _t(sub.isEvent ? 'ns.eventTitle' : 'ns.dueAlarmTitle', {
        'name': sub.name,
      });
      final body = sub.isEvent
          ? _eventBody(sub)
          : _t('ns.payBody', {
                  'provider': sub.provider,
                  'amount': AppFormatters.money(sub.amount, sub.currency),
                }) +
                _descSuffix(sub);
      await _scheduleEventAlarm(
        _plugin,
        id: _eventIdBase + numericId % _idRange,
        title: title,
        body: body,
        when: when,
        payload: _eventPayload(sub.id, sub.name, title, body),
      );
    }

    // Rappel récurrent : chaque lundi 9h, invite à mettre la liste
    // à jour (factures, salaires, nouveaux abonnements oubliés).
    var next = _nextWeekday(DateTime.monday, reminderHour);
    await _safeSchedule(
      () => _plugin.zonedSchedule(
        id: 999,
        title: _t('ns.weeklyTitle'),
        body: _t('ns.weeklyBody'),
        scheduledDate: next,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'weekly-update',
      ),
      'weekly',
    );
  }

  static String _eventBody(Subscription sub) =>
      (sub.dueTime != null
          ? _t('ns.eventTime', {'date': AppFormatters.dateTimeLong(sub.dueAt)})
          : AppFormatters.dateLong(sub.nextDueDate)) +
      _descSuffix(sub);

  /// Note libre (ville, lieu, référence…) rappelée dans l'alerte.
  static String _descSuffix(Subscription sub) {
    final d = sub.description.trim();
    return d.isEmpty ? '' : '\n$d';
  }

  /// Payload auto-suffisant : l'isolate de fond n'a pas accès à la
  /// liste des abonnements pour reconstruire titre et texte.
  static String _eventPayload(
    String id,
    String name,
    String title,
    String body,
  ) => 'event:$id\u0001$name\u0001$title\u0001$body';

  /// Repousse l'alarme de 10 minutes à partir du payload reçu.
  /// Statique : utilisable depuis l'isolate de fond.
  static Future<void> snoozeFromPayload(String? payload) async {
    if (payload == null || !payload.startsWith('event:')) return;
    final parts = payload.substring(6).split('\u0001');
    if (parts.length < 3) return;
    final id = parts[0];
    final name = parts[1];
    // Format v2 : le titre est embarqué (abonnements comme RDV) ;
    // l'ancien format à 3 champs garde le titre de rendez-vous.
    final title = parts.length >= 4 ? parts[2] : null;
    final body = parts.length >= 4 ? parts[3] : parts[2];
    final numericId = int.tryParse(id) ?? id.hashCode.abs();
    // Isolate de fond : la langue est relue depuis les préférences
    // plutôt que le singleton de l'UI.
    String lang = 'fr';
    try {
      final prefs = await SharedPreferences.getInstance();
      lang = prefs.getString('locale') ?? 'fr';
    } catch (_) {}
    await _scheduleEventAlarm(
      FlutterLocalNotificationsPlugin(),
      id: _snoozeIdBase + numericId % _idRange,
      title:
          title ?? AppStrings.t(lang, 'ns.eventTitle', {'name': name}),
      body: body,
      when: tz.TZDateTime.now(tz.local).add(_snoozeDuration),
      payload: payload,
    );
  }

  /// Alarme exacte si autorisée, sinon repli sur le mode inexact
  /// (le système peut décaler de quelques minutes). Le canal porte
  /// la sonnerie choisie — recréé à chaque appel car un changement
  /// de sonnerie implique un nouvel ID de canal.
  static Future<void> _scheduleEventAlarm(
    FlutterLocalNotificationsPlugin plugin, {
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String payload,
  }) async {
    final (channelId, sound) = await _alarmChannelFor(_eventChannelId);
    await _createChannel(
      plugin,
      AndroidNotificationChannel(
        channelId,
        _eventChannelName,
        description: _eventChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: sound,
      ),
    );
    final details = _eventAlarmDetails(channelId, sound);
    Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: mode,
      payload: payload,
    );
    // Permission « Alarmes & rappels » (Android 12+) : si refusée,
    // tout mode exact lève une exception → repli inexact direct.
    final canExact =
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        true;
    if (!canExact) {
      debugPrint(
        'Abonex: alarme exacte non autorisée — alarme $id '
        'programmée en mode approximatif',
      );
      await _safeSchedule(
        () => schedule(AndroidScheduleMode.inexactAllowWhileIdle),
        'alarm:$id',
      );
      return;
    }
    // alarmClock = AlarmManager.setAlarmClock : LE mode le plus
    // fiable — sonne pile à l'heure même en Doze, prioritaire sur
    // l'économiseur de batterie (API prévue pour les applis réveil).
    // Repli : exact → inexact. Toutes les exceptions sont capturées,
    // pas seulement PlatformException.
    var scheduled = false;
    for (final mode in [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
    ]) {
      try {
        await schedule(mode);
        scheduled = true;
        break;
      } catch (e) {
        debugPrint('Abonex: alarme $id refusée en mode $mode — $e');
      }
    }
    if (!scheduled) {
      await _safeSchedule(
        () => schedule(AndroidScheduleMode.inexactAllowWhileIdle),
        'alarm:$id',
      );
    }
  }

  /// Vrai si l'utilisateur a autorisé les notifications — sinon
  /// AUCUN rappel ni sonnerie ne sortira (cause la plus fréquente
  /// de "ça ne sonne pas" sur un téléphone fraîchement installé).
  Future<bool> notificationsEnabled() async {
    await init();
    final enabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
    return enabled ?? true; // iOS : géré par les permissions système
  }

  /// Redemande l'autorisation (utile si elle a été refusée au
  /// premier lancement — Android ne la repropose pas tout seul).
  Future<bool> requestPermissions() async {
    await init();
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Permission « Alarmes et rappels » (Android 12+) : sans elle,
  /// les sonneries à l'heure exacte tombent en mode approximatif —
  /// le système peut alors les retarder de plusieurs minutes.
  Future<bool> exactAlarmsAllowed() async {
    await init();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        true;
  }

  /// Ouvre l'écran système « Alarmes et rappels » — Android refuse
  /// toute demande directe, seul ce réglage existe. Retourne l'état
  /// de la permission une fois l'utilisateur revenu.
  Future<bool> requestExactAlarms() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    } catch (_) {}
    return exactAlarmsAllowed();
  }

  /// Alarme de TEST : programme une vraie sonnerie ~30 s plus tard
  /// en passant par exactement le même chemin que les alarmes de
  /// rendez-vous (canal, plein écran, setAlarmClock). Le moyen le
  /// plus fiable de vérifier que tout fonctionne sur CET appareil.
  /// L'ID 6000 est hors de toutes les plages de rappels.
  Future<void> scheduleTestAlarm() async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(
      const Duration(seconds: 30),
    );
    final title = _t('alarm.testTitle');
    final body = _t('alarm.testBody');
    await _scheduleEventAlarm(
      _plugin,
      id: 6000,
      title: title,
      body: body,
      when: when,
      payload: _eventPayload('test', _t('alarm.title'), title, body),
    );
  }

  /// Aperçu : joue la sonnerie choisie une seule fois (réglages).
  /// Retourne false si les notifications sont bloquées — la vue
  /// affiche alors un message au lieu de croire que ça joue.
  ///
  /// Canal en usage "notification" (pas "alarme") : le volume suivi
  /// est celui que l'utilisateur règle naturellement — sinon un
  /// volume « Alarme » à 0 rend l'aperçu muet et semble cassé.
  Future<bool> previewAlarmSound({String? soundKey}) async {
    if (!await notificationsEnabled()) return false;
    final (channelId, sound) = await _alarmChannelFor(
      'abonex_alarm_preview_v3',
      selection: soundKey,
    );
    await _createChannel(
      _plugin,
      AndroidNotificationChannel(
        channelId,
        _eventChannelName,
        description: _eventChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: sound,
      ),
    );
    await _plugin.show(
      id: 3000,
      title: _t('alarm.previewTitle'),
      body: _t('alarm.previewBody'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _eventChannelName,
          channelDescription: _eventChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          sound: sound,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
    return true;
  }

  /// Prochain [weekday] à [hour]h — DateTime monday=1 … sunday=7.
  /// On calcule l'écart en jours : aucune boucle, aucun risque
  /// de tourner indéfiniment.
  tz.TZDateTime _nextWeekday(int weekday, int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var delta = (weekday - now.weekday) % DateTime.daysPerWeek;
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day + delta, hour);
    if (!d.isAfter(now)) {
      // Créneau du jour déjà passé → semaine prochaine.
      d = d.add(const Duration(days: DateTime.daysPerWeek));
    }
    return d;
  }
}
