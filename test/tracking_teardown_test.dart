import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/app/tracking_service.dart';

/// Tearing down tracking from inside `State.dispose()`.
///
/// `TrackingService.stop()` writes to half a dozen notifiers, and other
/// screens are listening: the driver dashboard's live stat cards watch
/// `liveRevision`. Flutter locks the element tree while it tears a widget
/// down, so marking one of those builders as needing build during that
/// throws "markNeedsBuild() called when widget tree was locked". Leaving
/// the Route tab with no trip running did exactly that.
void main() {
  final tracking = TrackingService.instance;

  tearDown(tracking.stop);

  /// A live card and, beside it, a widget that tears tracking down when it
  /// leaves — the two halves of the crash, in one tree.
  Future<Object?> pumpThenRemoveDisposer(
    WidgetTester tester, {
    required VoidCallback onDispose,
  }) async {
    final show = ValueNotifier<bool>(true);
    addTearDown(show.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) => Column(
            children: [
              // The dashboard's live stat card, in miniature.
              ValueListenableBuilder<int>(
                valueListenable: tracking.liveRevision,
                builder: (context, rev, _) => Text('rev $rev'),
              ),
              if (visible) _Disposer(onDispose: onDispose),
            ],
          ),
        ),
      ),
    );

    show.value = false;
    await tester.pump();
    // Lets the deferred teardown's microtask run before we look.
    await tester.pump();
    return tester.takeException();
  }

  testWidgets('stopping straight from dispose is what crashed', (tester) async {
    final error = await pumpThenRemoveDisposer(
      tester,
      onDispose: tracking.stop,
    );
    expect(
      error,
      isNotNull,
      reason:
          'This test exists to prove the next one is not vacuous: if Flutter '
          'ever stops rejecting this, the safe path below proves nothing.',
    );
    expect('$error', contains('locked'));
  });

  testWidgets('stopAfterFrame tears down without crashing', (tester) async {
    final error = await pumpThenRemoveDisposer(
      tester,
      onDispose: tracking.stopAfterFrame,
    );
    expect(error, isNull);
  });

  testWidgets('the deferred stop really does stop', (tester) async {
    // Deferring must not quietly turn into skipping.
    tracking.liveRevision.value = 0;
    await pumpThenRemoveDisposer(tester, onDispose: tracking.stopAfterFrame);
    expect(tracking.route, isNull);
    expect(tracking.etaMinutes.value, 0);
    expect(tracking.distanceMeters.value, isNull);
    expect(tracking.liveRevision.value, greaterThan(0));
  });

  test('the route screen does not stop tracking inline in dispose', () {
    final src = File(
      'lib/screens/driver/driver_route.dart',
    ).readAsStringSync();
    final start = src.indexOf('  void dispose() {');
    expect(start, greaterThan(-1), reason: 'dispose() not found');
    final body = src.substring(start, src.indexOf('\n  }', start));
    expect(body, contains('_tracking.stopAfterFrame()'));
    expect(
      body.contains('_tracking.stop()'),
      isFalse,
      reason: 'a synchronous stop() here is the crash',
    );
  });
}

class _Disposer extends StatefulWidget {
  final VoidCallback onDispose;
  const _Disposer({required this.onDispose});

  @override
  State<_Disposer> createState() => _DisposerState();
}

class _DisposerState extends State<_Disposer> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
