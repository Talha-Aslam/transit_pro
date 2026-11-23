import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/app/fee_agreement_sync.dart';
import 'package:transit_pro/theme/app_theme.dart';
import 'package:transit_pro/widgets/seat_fee.dart';

const _driver = 'drv1';

Student _rider(String id, {int fee = 0, String? driverId = _driver}) => Student(
  id: id,
  name: 'Rider $id',
  parentId: 'p1',
  driverId: driverId,
  monthlyFeePaisa: fee,
);

RideRequest _request(
  String studentId, {
  RideRequestStatus status = RideRequestStatus.accepted,
  int fee = 0,
  FeeStatus feeStatus = FeeStatus.none,
  String driverId = _driver,
}) => RideRequest(
  id: '${driverId}_$studentId',
  requesterId: 'p1',
  studentId: studentId,
  driverId: driverId,
  scheduleId: 'r1',
  status: status,
  feePaisa: fee,
  feeStatus: feeStatus,
);

void main() {
  group('FeeAgreementSync.pendingUpdates', () {
    List<(Student, int)> pending(
      List<RideRequest> requests,
      List<Student> roster,
    ) => FeeAgreementSync.pendingUpdates(
      driverId: _driver,
      requests: requests,
      roster: roster,
    );

    test('a fee agreed after booking is applied to the rider', () {
      final out = pending(
        [_request('s1', fee: 500000, feeStatus: FeeStatus.accepted)],
        [_rider('s1')],
      );
      expect(out.single.$1.id, 's1');
      expect(out.single.$2, 500000);
    });

    test('a changed fee replaces the old one', () {
      final out = pending(
        [_request('s1', fee: 600000, feeStatus: FeeStatus.accepted)],
        [_rider('s1', fee: 500000)],
      );
      expect(out.single.$2, 600000);
    });

    test('nothing to do when the record already shows the agreed fee', () {
      expect(
        pending(
          [_request('s1', fee: 500000, feeStatus: FeeStatus.accepted)],
          [_rider('s1', fee: 500000)],
        ),
        isEmpty,
      );
    });

    test('a proposed or rejected fee leaves the current fee alone', () {
      for (final status in [FeeStatus.proposed, FeeStatus.rejected]) {
        expect(
          pending(
            [_request('s1', fee: 700000, feeStatus: status)],
            [_rider('s1', fee: 500000)],
          ),
          isEmpty,
          reason: status.name,
        );
      }
    });

    test('a waiting request or another driver\'s rider is never touched', () {
      expect(
        pending(
          [
            _request(
              's1',
              status: RideRequestStatus.pending,
              fee: 500000,
              feeStatus: FeeStatus.accepted,
            ),
            _request('s2', fee: 500000, feeStatus: FeeStatus.accepted),
          ],
          [_rider('s1'), _rider('s2', driverId: 'someone-else')],
        ),
        isEmpty,
      );
    });
  });

  group('seatFeeSummary', () {
    test('the fee in force', () {
      final (text, color) = seatFeeSummary(
        _rider('s1', fee: 450000),
        _request('s1', fee: 450000, feeStatus: FeeStatus.accepted),
      )!;
      expect(text, 'Fee: Rs.4500 / month');
      expect(color, AppTheme.success);
    });

    test('no fee yet', () {
      final (text, _) = seatFeeSummary(_rider('s1'), _request('s1'))!;
      expect(text, 'No monthly fee set');
    });

    test('a change waiting on the family', () {
      final (text, color) = seatFeeSummary(
        _rider('s1', fee: 450000),
        _request('s1', fee: 500000, feeStatus: FeeStatus.proposed),
      )!;
      expect(text, contains('Rs.4500'));
      expect(text, contains('Rs.5000 sent'));
      expect(color, AppTheme.warning);
    });

    test('a declined change keeps the old fee', () {
      final (text, color) = seatFeeSummary(
        _rider('s1', fee: 450000),
        _request('s1', fee: 500000, feeStatus: FeeStatus.rejected),
      )!;
      expect(text, contains('family declined Rs.5000'));
      expect(color, AppTheme.error);
    });
  });
}
