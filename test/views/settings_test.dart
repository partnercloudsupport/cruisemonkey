import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cruisemonkey/src/basic_types.dart';
import 'package:cruisemonkey/src/logic/cruise.dart';
import 'package:cruisemonkey/src/logic/store.dart';
import 'package:cruisemonkey/src/models/user.dart';
import 'package:cruisemonkey/src/network/rest.dart';
import 'package:cruisemonkey/src/network/twitarr.dart';
import 'package:cruisemonkey/src/views/settings.dart';
import 'package:cruisemonkey/src/widgets.dart';

import '../loggers.dart';
import '../mocks.dart';

Future<void> main() async {
  testWidgets('Settings', (WidgetTester tester) async {
    final List<String> log = <String>[];
    final TrivialDataStore store = TrivialDataStore();
    store.storedCredentials = const Credentials(username: 'aaa', password: 'aaaaaa', key: 'blabla');
    final CruiseModel model = _TestCruiseModel(
      initialTwitarrConfiguration: const RestTwitarrConfiguration(baseUrl: 'https://example.com/'),
      store: store,
      onError: (String error) { throw Exception(error); },
      log: log,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Cruise(
          cruiseModel: model,
          child: const Settings(),
        ),
      ),
    );
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'https://example.com/'));
    await tester.tap(find.text('gbasden\'s server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://69.62.137.54:42111/'));
    await tester.tap(find.text('hendusoone\'s server'));
    await tester.pump();
    expect(model.twitarrConfiguration, const RestTwitarrConfiguration(baseUrl: 'http://twitarrdev.wookieefive.net:3000/'));
    expect(log, <String>[
      'LoggingTwitarr(497174609).login aaa / aaaaaa',
      'LoggingTwitarr(497174609).getCalendar',
      'LoggingTwitarr(497174609).dispose',
      'LoggingTwitarr(387053049).getCalendar',
      'LoggingTwitarr(387053049).dispose',
      'LoggingTwitarr(207387977).getCalendar'
    ]);
  });
}

class _TestCruiseModel extends CruiseModel {
  _TestCruiseModel({
    @required TwitarrConfiguration initialTwitarrConfiguration,
    @required DataStore store,
    @required ErrorCallback onError,
    @required this.log,
  }) : assert(log != null),
       super(
    initialTwitarrConfiguration: initialTwitarrConfiguration,
    store: store,
    onError: onError,
  );

  final List<String> log;

  @override
  TwitarrConfiguration get twitarrConfiguration => _twitarrConfiguration;
  TwitarrConfiguration _twitarrConfiguration;
  @override
  void selectTwitarrConfiguration(TwitarrConfiguration newConfiguration) {
    _twitarrConfiguration = newConfiguration;
    super.selectTwitarrConfiguration(LoggingTwitarrConfiguration(newConfiguration.hashCode, log));
  }
}
