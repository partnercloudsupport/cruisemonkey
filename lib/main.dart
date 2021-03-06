import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'src/logic/background_polling.dart';
import 'src/logic/cruise.dart';
import 'src/logic/disk_store.dart';
import 'src/logic/notifications.dart';
import 'src/models/user.dart';
import 'src/network/rest.dart';
import 'src/progress.dart';
import 'src/views/calendar.dart';
import 'src/views/comms.dart';
import 'src/views/create_account.dart';
import 'src/views/deck_plans.dart';
import 'src/views/drawer.dart';
import 'src/views/karaoke.dart';
import 'src/views/profile.dart';
import 'src/views/settings.dart';
import 'src/views/stream.dart';
import 'src/widgets.dart';

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

void main() {
  print('CruiseMonkey has started');
  final CruiseModel model = CruiseModel(
    initialTwitarrConfiguration: const RestTwitarrConfiguration(baseUrl: kDefaultTwitarrUrl),
    store: DiskDataStore(),
    onError: _handleError,
    onCheckForMessages: checkForMessages,
  );
  runApp(CruiseMonkeyApp(cruiseModel: model, scaffoldKey: scaffoldKey));
  if (Platform.isAndroid)
    runBackground();
  Notifications.instance.then((Notifications notifications) {
    notifications.onTap = (String threadId) async {
      print('Received tap to view: $threadId');
      await model.loggedIn;
      Navigator.popUntil(scaffoldKey.currentContext, ModalRoute.withName('/'));
      CommsView.showSeamailThread(scaffoldKey.currentContext, model.seamail.threadById(threadId));
    };
  });
}

void _handleError(String message) {
  final AnimationController controller = AnimationController(
    duration: const Duration(seconds: 4),
    vsync: const PermanentTickerProvider(),
  );
  final Animation<double> opacity = controller.drive(TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.ease)),
        weight: 500,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.0),
        weight: 2500,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.ease)),
        weight: 2000,
      ),
    ],
  ));
  final Animation<double> position = controller.drive(
    Tween<double>(begin: 128.0, end: 36.0).chain(CurveTween(curve: Curves.easeOutBack)),
  );
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return Positioned(
        left: 24.0,
        right: 24.0,
        bottom: position.value,
        child: IgnorePointer(
          child: FadeTransition(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: ShapeDecoration(
                color: Colors.grey[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                shadows: kElevationToShadow[4],
              ),
              child: Text(message, style: theme.textTheme.caption.copyWith(color: Colors.white)),
            ),
          ),
        ),
      );
    },
  );
  final OverlayState overlay = Overlay.of(scaffoldKey.currentContext);
  controller.addListener(() {
    if (overlay.mounted)
      entry.markNeedsBuild();
  });
  controller.addStatusListener((AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (overlay.mounted)
        entry.remove();
      controller.dispose();
    }
  });
  overlay.insert(entry);
  controller.forward();
}

class PermanentTickerProvider extends TickerProvider {
  const PermanentTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class CruiseMonkeyApp extends StatelessWidget {
  const CruiseMonkeyApp({
    Key key,
    this.cruiseModel,
    this.scaffoldKey,
  }) : super(key: key);

  final CruiseModel cruiseModel;

  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Cruise(
      cruiseModel: cruiseModel,
      child: Now(
        period: const Duration(seconds: 15),
        child: CruiseMonkeyHome(scaffoldKey: scaffoldKey),
      ),
    );
  }
}

class CruiseMonkeyHome extends StatelessWidget {
  const CruiseMonkeyHome({
    Key key,
    this.scaffoldKey,
  }) : super(key: key);

  final GlobalKey<ScaffoldState> scaffoldKey;

  static const List<View> pages = <View>[
    CalendarView(),
    DeckPlanView(),
    KaraokeView(),
    CommsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CruiseMonkey',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        accentColor: Colors.greenAccent,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: DefaultTabController(
        length: 4,
        child: Builder(
          builder: (BuildContext context) {
            final TabController tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (BuildContext context, Widget child) {
                return Scaffold(
                  key: scaffoldKey,
                  appBar: AppBar(
                    leading: ValueListenableBuilder<ProgressValue<AuthenticatedUser>>(
                      valueListenable: Cruise.of(context).user.best,
                      builder: (BuildContext context, ProgressValue<AuthenticatedUser> value, Widget child) {
                        return Badge(
                          enabled: value is FailedProgress,
                          child: Builder(
                            builder: (BuildContext context) {
                              return IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () { Scaffold.of(context).openDrawer(); },
                                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    title: const Text('CruiseMonkey'),
                    bottom: TabBar(
                      isScrollable: true,
                      tabs: pages.map((View page) => page.buildTab(context)).toList(),
                    ),
                  ),
                  drawer: const CruiseMonkeyDrawer(),
                  floatingActionButton: pages[tabController.index].buildFab(context),
                  body: const TabBarView(
                    children: pages,
                  ),
                );
              },
            );
          },
        ),
      ),
      routes: <String, WidgetBuilder>{
        '/profile': (BuildContext context) => const Profile(),
        '/create_account': (BuildContext context) => const CreateAccount(),
        '/settings': (BuildContext context) => const Settings(),
        '/twitarr': (BuildContext context) => const TweetStreamView(),
      },
    );
  }
}
