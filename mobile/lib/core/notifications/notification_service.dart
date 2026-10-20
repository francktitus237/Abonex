import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/subscriptions/domain/entities/subscription.dart';
import '../di/injection.dart';
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
/// Une notification est programmée 3 jours avant + le jour J
/// pour chaque abonnement "À venir". Les rendez-vous déclenchent
/// en plus une ALARME exacte à l'heure prévue.
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'abonex_due_reminders_v2';
  static const _channelName = 'Rappels importants';
  static const _channelDesc =
      'Alertes sonores avant les paiements et rappels de suivi.';

  // Canal "alarme" : notification plein écran par-dessus
  // l'écran verrouillé, sonnerie forte — impossible à manquer.
  static const _urgentChannelId = 'abonex_urgent';
  static const _urgentChannelName = 'Alarmes d\'échéance';
  static const _urgentChannelDesc =
      'Rappels plein écran avec sonnerie pour les paiements du jour.';

  // Canal dédié aux rendez-vous : sonnerie d'alarme en boucle
  // jusqu'à ce que l'utilisateur arrête ou repousse.
  static const _eventChannelId = 'abonex_event_alarm';
  static const _eventChannelName = 'Alarmes de rendez-vous';
  static const _eventChannelDesc =
      'Sonne à l\'heure exacte du rendez-vous jusqu\'à arrêt ou report.';

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

  static const _notificationDetails = NotificationDetails(
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

  static const _urgentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _urgentChannelId,
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
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  static final _eventAlarmDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _eventChannelId,
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
      actions: const [
        AndroidNotificationAction(
          actionSnooze,
          'Repousser 10 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionStop,
          'Arrêter',
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
                DarwinNotificationAction.plain(
                  actionSnooze,
                  'Repousser 10 min',
                ),
                DarwinNotificationAction.plain(
                  actionStop,
                  'Arrêter',
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
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _urgentChannelId,
        _urgentChannelName,
        description: _urgentChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
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
    final urgent = settings.soundAlerts;
    final reminderDays = settings.reminderDays;
    final reminderHour = settings.reminderHour;
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
        final isToday = daysBefore == 0 &&
            sub.nextDueDate.year == now.year &&
            sub.nextDueDate.month == now.month &&
            sub.nextDueDate.day == now.day;
        // Rendez-vous avec heure : le jour J, c'est l'alarme exacte
        // qui prévient — pas de doublon à l'heure de rappel.
        if (isToday && sub.isEvent && sub.dueTime != null) continue;
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
              ? (sub.isEvent
                  ? 'Rendez-vous aujourd\'hui : ${sub.name}'
                  : 'Échéance aujourd\'hui : ${sub.name}')
              : daysBefore == 1
              ? (sub.isEvent
                  ? 'Rendez-vous demain : ${sub.name}'
                  : 'Échéance demain : ${sub.name}')
              : (sub.isEvent
                  ? 'Rendez-vous dans $daysBefore j : ${sub.name}'
                  : 'Échéance dans $daysBefore j : ${sub.name}'),
          body: sub.isEvent
              ? _eventBody(sub)
              : '${sub.provider} — ${AppFormatters.money(sub.amount, sub.currency)} à payer.',
          scheduledDate: when,
          // Jour J + rappels sonores activés → alarme plein écran.
          notificationDetails: urgent && daysBefore == 0
              ? _urgentDetails
              : _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'subscription:${sub.id}',
        );
      }
    }

    // Alarmes de rendez-vous : à l'heure exacte, sonnerie en boucle,
    // boutons Arrêter / Repousser.
    for (final sub in subs) {
      if (!sub.isEvent || sub.dueTime == null) continue;
      if (sub.status == SubscriptionStatus.paid) continue;
      final when = tz.TZDateTime.from(sub.dueAt, tz.local);
      if (!when.isAfter(now)) continue;
      final numericId = int.tryParse(sub.id) ?? sub.id.hashCode.abs();
      await _scheduleEventAlarm(
        _plugin,
        id: _eventIdBase + numericId % _idRange,
        title: 'Rendez-vous : ${sub.name}',
        body: _eventBody(sub),
        when: when,
        payload: _eventPayload(sub.id, sub.name, _eventBody(sub)),
      );
    }

    // Rappel récurrent : chaque lundi 9h, invite à mettre la liste
    // à jour (factures, salaires, nouveaux abonnements oubliés).
    var next = _nextWeekday(DateTime.monday, reminderHour);
    await _plugin.zonedSchedule(
      id: 999,
      title: 'Abonex — liste à jour ?',
      body:
          'Pensez à ajouter vos nouvelles factures et abonnements pour un suivi complet.',
      scheduledDate: next,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly-update',
    );
  }

  static String _eventBody(Subscription sub) => sub.dueTime != null
      ? 'C\'est l\'heure — ${AppFormatters.dateTimeLong(sub.dueAt)}'
      : AppFormatters.dateLong(sub.nextDueDate);

  /// Payload auto-suffisant : l'isolate de fond n'a pas accès à la
  /// liste des abonnements pour reconstruire titre et texte.
  static String _eventPayload(String id, String name, String body) =>
      'event:$id\u0001$name\u0001$body';

  /// Repousse l'alarme de 10 minutes à partir du payload reçu.
  /// Statique : utilisable depuis l'isolate de fond.
  static Future<void> snoozeFromPayload(String? payload) async {
    if (payload == null || !payload.startsWith('event:')) return;
    final parts = payload.substring(6).split('\u0001');
    if (parts.length < 3) return;
    final [id, name, body] = parts;
    final numericId = int.tryParse(id) ?? id.hashCode.abs();
    await _scheduleEventAlarm(
      FlutterLocalNotificationsPlugin(),
      id: _snoozeIdBase + numericId % _idRange,
      title: 'Rendez-vous : $name',
      body: body,
      when: tz.TZDateTime.now(tz.local).add(_snoozeDuration),
      payload: payload,
    );
  }

  /// Alarme exacte si autorisée, sinon repli sur le mode inexact
  /// (le système peut décaler de quelques minutes).
  static Future<void> _scheduleEventAlarm(
    FlutterLocalNotificationsPlugin plugin, {
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String payload,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) => plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _eventAlarmDetails,
      androidScheduleMode: mode,
      payload: payload,
    );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Prochain [weekday] à [hour]h — DateTime monday=1 … sunday=7.
  /// On calcule l'écart en jours : aucune boucle, aucun risque
  /// de tourner indéfiniment.
  tz.TZDateTime _nextWeekday(int weekday, int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var delta = (weekday - now.weekday) % DateTime.daysPerWeek;
    var d = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + delta,
      hour,
    );
    if (!d.isAfter(now)) {
      // Créneau du jour déjà passé → semaine prochaine.
      d = d.add(const Duration(days: DateTime.daysPerWeek));
    }
    return d;
  }
}
