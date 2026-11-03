import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static const _channelId = 'abonex_due_reminders_v2';
  static String get _channelName => _t('ns.channelReminders');
  static String get _channelDesc => _t('ns.channelRemindersDesc');

  // Canal "alarme" : notification plein écran par-dessus
  // l'écran verrouillé, sonnerie forte — impossible à manquer.
  static const _urgentChannelId = 'abonex_urgent';
  static String get _urgentChannelName => _t('ns.channelUrgent');
  static String get _urgentChannelDesc => _t('ns.channelUrgentDesc');

  // Canal dédié aux rendez-vous : sonnerie d'alarme en boucle
  // jusqu'à ce que l'utilisateur arrête ou repousse.
  static const _eventChannelId = 'abonex_event_alarm';
  static String get _eventChannelName => _t('ns.channelEvent');
  static String get _eventChannelDesc => _t('ns.channelEventDesc');

  static const actionStop = 'stop';
  static const actionSnooze = 'snooze';
  static const _snoozeDuration = Duration(minutes: 10);

  // Plages d'identifiants : rappels classiques 0-59, hebdo 999,
  // alarmes de RDV 1000-1999, reports (snooze) 2000-2999.
  static const _eventIdBase = 1000;
  static const _snoozeIdBase = 2000;
  static const _idRange = 1000;

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

  /// Canal + son selon la sonnerie choisie par l'utilisateur.
  /// Android grave le son dans le canal à sa création : un ID
  /// distinct par choix est requis (le son d'un canal existant
  /// est immuable côté système).
  static Future<(String, AndroidNotificationSound?)> _alarmChannelFor(
    String base,
  ) async {
    var sel = 'default';
    String? customPath;
    var rev = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      sel = prefs.getString(SettingsStorage.kAlarmSound) ?? 'default';
      customPath = prefs.getString(SettingsStorage.kAlarmCustomPath);
      rev = prefs.getInt(SettingsStorage.kAlarmCustomRev) ?? 0;
    } catch (_) {}
    return switch (sel) {
      'classic' || 'digital' || 'chime' => (
          '${base}_$sel',
          RawResourceAndroidNotificationSound('alarm_$sel'),
        ),
      'custom' when customPath != null => (
          '${base}_custom_$rev',
          UriAndroidNotificationSound('file://$customPath'),
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
    await android?.requestNotificationsPermission();
    // Demande l'autorisation plein écran (rappel type alarme).
    await android?.requestFullScreenIntentPermission();
    // Alarme à l'heure exacte du rendez-vous (Android 12+).
    await android?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  /// Action sur l'alarme quand l'app est au premier plan.
  Future<void> _onResponse(NotificationResponse r) async {
    if (r.actionId == actionSnooze) await snoozeFromPayload(r.payload);
  }

  /// Replanifie tous les rappels à chaque chargement de la liste :
  /// simple et toujours cohérent avec l'état serveur.
  Future<void> scheduleDueReminders(List<Subscription> subs) async {
    if (!_initialized) return;
    // On ne touche pas aux reports (snooze) en cours : ils doivent
    // survivre à un rafraîchissement de la liste.
    for (var i = 0; i < 60; i++) {
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
        if (id >= 60) break; // limite Android de notifications planifiées
        await _plugin.zonedSchedule(
          id: id++,
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
        );
      }
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
        if (id >= 60) break;
        await _plugin.zonedSchedule(
          id: id++,
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
    await _plugin.zonedSchedule(
      id: 999,
      title: _t('ns.weeklyTitle'),
      body: _t('ns.weeklyBody'),
      scheduledDate: next,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly-update',
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
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Aperçu : joue la sonnerie choisie une seule fois (réglages).
  Future<void> previewAlarmSound() async {
    await init();
    final (channelId, sound) = await _alarmChannelFor(
      'abonex_alarm_preview',
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
        audioAttributesUsage: AudioAttributesUsage.alarm,
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
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
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
