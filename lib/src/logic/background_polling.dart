import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../network/rest.dart';
import '../network/twitarr.dart';
import 'disk_store.dart';
import 'notifications.dart';
import 'store.dart';

Future<void> runBackground() async {
  if (!await AndroidAlarmManager.initialize()) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to start up.'),
      library: 'Cruisemonkey',
      context: 'during startup',
    ));
    return;
  }
  if (!await AndroidAlarmManager.periodic(const Duration(minutes: 1), 0, _periodicCallback, /*exact: true,*/ wakeup: true)) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Android Alarm Manager failed to schedule periodic background task.'),
      library: 'Cruisemonkey',
      context: 'during startup',
    ));
    return;
  }
  await _periodicCallback();
}

Future<void> _periodicCallback() async {
  await _backgroundUpdate();
  /// If this isn't reliable enough, we could try this:
  // if (!await AndroidAlarmManager.oneShot(
  //              const Duration(minutes: 1), 1, _periodicCallback,
  //              /*exact: true,*/ /// If it's still not reliable enough, we could add this.
  //              wakeup: true,
  //              /*allowWhileIdle: true,*/ /// If it's still not reliable enough, we could add this.
  //    )) {
  //   FlutterError.reportError(FlutterErrorDetails(
  //     exception: Exception('Android Alarm Manager failed to schedule one-shot task.'),
  //     library: 'Cruisemonkey',
  //     context: 'during periodic background task',
  //   ));
  //   return;
  // }
}

Future<void> _backgroundUpdate() async {
  try {
    DataStore store;
    try {
      store = DiskDataStore();
    } on DatabaseException catch (error) {
      if (error.toString() == 'DatabaseException(database is locked (code 5 SQLITE_BUSY))') {
        print('Database is locked; skipping background update.');
        return;
      }
      rethrow;
    }
    final Map<Setting, dynamic> settings = await store.restoreSettings().asFuture();
    final String baseUrl = settings.containsKey(Setting.server) ? settings[Setting.server] as String : kDefaultTwitarrUrl;
    final Twitarr twitarr = RestTwitarrConfiguration(baseUrl: baseUrl).createTwitarr();
    if (settings.containsKey(Setting.debugNetworkLatency))
      twitarr.debugLatency = settings[Setting.debugNetworkLatency] as double;
    if (settings.containsKey(Setting.debugNetworkReliability))
      twitarr.debugReliability = settings[Setting.debugNetworkReliability] as double;
    final Credentials credentials = await store.restoreCredentials().asFuture();
    await checkForMessages(credentials, twitarr, store);
  } on UserFriendlyError catch (error) {
    print('Skipping background update: $error');
  }
}

Future<void> checkForMessages(Credentials credentials, Twitarr twitarr, DataStore store) async {
  try {
    if (credentials == null) {
      print('Not logged in; skipping check for messages.');
      return;
    }
    print('I call my phone and I check my messages.');
    SeamailSummary summary;
    await store.updateFreshnessToken((int freshnessToken) async {
      summary = await twitarr.getUnreadSeamailMessages(
        credentials: credentials,
        freshnessToken: freshnessToken,
      ).asFuture();
      final int result = summary.freshnessToken;
      if (freshnessToken == null)
        summary = null;
      return result;
    });
    if (summary != null) {
      final List<Future<void>> futures = <Future<void>>[];
      final Notifications notifications = await Notifications.instance;
      for (SeamailThreadSummary thread in summary.threads) {
        for (SeamailMessageSummary message in thread.messages) {
          final String body = '${message.user.toUser(null)}: ${message.text}';
          futures.add(notifications.messageUnread(thread.id, message.id, thread.subject, body));
          futures.add(store.addNotification(thread.id, message.id));
        }
      }
      await Future.wait(futures);
    }
  } on UserFriendlyError catch (error) {
    print('Failed to check for messages: $error');
  }
}
