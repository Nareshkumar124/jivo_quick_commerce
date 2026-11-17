import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [finder]'s widget sits inside a `Semantics(liveRegion: true)`,
/// so TalkBack reads it out when it appears.
bool isInLiveRegion(WidgetTester tester, Finder finder) => tester
    .widgetList<Semantics>(
      find.ancestor(of: finder, matching: find.byType(Semantics)),
    )
    .any((s) => s.properties.liveRegion ?? false);
