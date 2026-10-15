import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/subscriptions/domain/entities/subscription.dart';
import '../di/injection.dart';
import '../storage/settings_storage.dart';
import '../utils/formatters.dart';

/// Rappels locaux d'échéances (CDC : anticiper chaque paiement).
/// Une notification est programmée 3 jours avant + le jour J
/// pour chaque abonnement "À venir".
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

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
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
    await android?.requestNotificationsPermission();
    // Demande l'autorisation plein écran (rappel type alarme).
    await android?.requestFullScreenIntentPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  /// Replanifie tous les rappels à chaque chargement de la liste :
  /// simple et toujours cohérent avec l'état serveur.
  Future<void> scheduleDueReminders(List<Subscription> subs) async {
    if (!_initialized) return;
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    // Réglages personnalisés : jours d'anticipation + heure +
    // mode alarme — tout vient du profil utilisateur.
    final settings = getIt<SettingsStorage>();
    final urgent = settings.soundAlerts;
    final reminderDays = settings.reminderDays;
    final reminderHour = settings.reminderHour;
    var id = 0;
    for (final sub in subs) {
      if (sub.status != SubscriptionStatus.dueSoon) continue;
      // Un rappel par jour d'anticipation choisi (ex. J-7, J-3, J).
      for (final daysBefore in reminderDays) {
        var when = tz.TZDateTime(
          tz.local,
          sub.nextDueDate.year,
          sub.nextDueDate.month,
          sub.nextDueDate.day - daysBefore,
          reminderHour,
        );
        if (when.isBefore(now)) {
          // J passé → on décale au prochain créneau possible.
          when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
        }
        if (id >= 60) break; // limite Android de notifications planifiées
        await _plugin.zonedSchedule(
          id: id++,
          title: daysBefore == 0
              ? 'Échéance aujourd\'hui : ${sub.name}'
              : daysBefore == 1
              ? 'Échéance demain : ${sub.name}'
              : 'Échéance dans $daysBefore j : ${sub.name}',
          body: '${sub.provider} — ${AppFormatters.money(sub.amount, sub.currency)} à payer.',
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
