import 'package:flutter_test/flutter_test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_pro/ai/ocr_layout.dart';
import 'package:transit_pro/ai/slip_matcher.dart';
import 'package:transit_pro/ai/slip_parser.dart';
import 'package:transit_pro/ai/text_utils.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────
//
// Transcribed from the owner's real screenshots, one visual row per line the
// way OcrService hands them to the parser, with the noise ML Kit really
// produces: "ID#" read as "lD#" and a 1 inside it as l, a time split as
// "2:1 5", JazzCash's superscript ".00" swallowed into the number.

/// images/8.webp — Easypaisa → Easypaisa.
const easypaisaSlip = [
  'easypaisa',
  'Transaction Successful',
  'Money has been sent',
  '26 June 2024 2:1 5 AM',
  'lD#226l5557344',
  'Funding Source',
  'easypaisa Mobile Account',
  'Sent to',
  'HUSNAIN ALI',
  '03151929161',
  'Account Details',
  'HUSNAIN ALI',
  'Sent by HUMAIRA',
  '03168962255',
  'Message/Reference',
  'Easy Paisa',
  'Amount',
  '1000.00',
  'Fee / Charge',
  'No Charge',
  'Total Amount',
  'Rs.1000.00',
];

/// images/9.jpg — JazzCash → JazzCash. "Rs. 1.00" has a superscript ".00",
/// which OCR reads as "Rs. 100".
const jazzCashSlip = [
  'November 20, 2026 at 01:33',
  'Transaction Successful',
  'Transferred to JazzCash',
  'Rs. 100',
  'transferred to',
  'MUHAMMAD SHOAIB ASLAM',
  'Account # 03227229477',
  'Transaction Fee Free',
  'TALHA ASLAM',
  'From',
  'Account # 03101413717',
  'TID 446804416088',
  'Securely sent via',
];

/// images/10.jpg — Meezan Bank → JazzCash over Raast. The watermark and
/// logos bleed into the rows.
const meezanSlip = [
  'Transaction Successful',
  'Meezan Bank Meezan Bank Meezan Bank',
  'PKR 10',
  'Meezan Bank Meezan Bank',
  'Nov 20, 2026 | 1:39 AM',
  'MEEZAN From Account:',
  'TALHA ASLAM',
  '1147xxx3511',
  'Jazz To Account:',
  'TALHA ASLAM',
  '0310xxx3717',
  'Reference Number (STAN): 013956',
  'Transaction Type: Raast',
  'Add To Beneficiary',
];

/// images/11.jpg — NayaPay → JazzCash over Raast; the id is cut short
/// with "..." and followed by the copy icon.
const nayaPaySlip = [
  'Talha Aslam',
  'JazzCash/Mobilink MFB-3717',
  'Rs. 1',
  '20 Nov 2026, 01:36 AM',
  'Amount Sent Rs. 1',
  'Service Fee (Incl. Tax) Rs. 0',
  'Total Amount Rs. 1',
  'Transaction ID 6aff5db31783980fb91ca... D',
  'ADDITIONAL INFORMATION',
  'Destination Acc. Title Talha Aslam',
  'Destination Bank JazzCash - Mobilink',
  'Microfinance Bank',
  'Destination Acc. Number ●●●●3717',
  'Source Acc. Title Talha Aslam',
  'Channel Raast',
  'Sent with NayaPay',
];

/// Talha's own payout: a JazzCash wallet ending 3717.
const talhaPayout = PayoutDetails(
  bankName: 'Meezan Bank',
  accountTitle: 'TALHA ASLAM',
  accountNumber: '01140103511',
  wallets: [
    WalletAccount(
      provider: 'JazzCash',
      name: 'Talha Aslam',
      number: '03101413717',
    ),
  ],
);

void main() {
  group('text utilities', () {
    test('rejoins a time OCR split in two', () {
      expect(fixSplitTimes('26 June 2024 2:1 5 AM'), '26 June 2024 2:15 AM');
    });

    test('reads every date format the apps use', () {
      DateTime? d(String s) => findDates([s]).firstOrNull?.value;
      expect(d('26 June 2024 2:1 5 AM'), DateTime(2024, 6, 26, 2, 15));
      expect(d('November 20, 2026 at 01:33'), DateTime(2026, 11, 20, 1, 33));
      expect(d('Nov 20, 2026 | 1:39 AM'), DateTime(2026, 11, 20, 1, 39));
      expect(d('20 Nov 2026, 01:36 AM'), DateTime(2026, 11, 20, 1, 36));
      expect(d('20 Nov 2026, 1:36 PM'), DateTime(2026, 11, 20, 13, 36));
      expect(d('15-JAN-2018'), DateTime(2018, 1, 15));
      expect(d('11/03/2025'), DateTime(2025, 3, 11));
      expect(d('31/02/2025'), isNull);
    });

    test('money in every shape', () {
      expect(parsePaisa('1,000'), 100000);
      expect(parsePaisa('1000.00'), 100000);
      expect(parsePaisa('1 00'), 100);
      expect(moneyPattern.firstMatch('Rs.1000.00')![1], '1000.00');
      expect(moneyPattern.firstMatch('Rs. 1')![1], '1');
      expect(moneyPattern.firstMatch('PKR 10')![1], '10');
      expect(moneyPattern.firstMatch('transfers 2'), isNull);
    });

    test('last four digits of masked and plain accounts', () {
      expect(last4Digits('03151929161'), '9161');
      expect(last4Digits('0310xxx3717'), '3717');
      expect(last4Digits('●●●●3717'), '3717');
      expect(last4Digits('JazzCash/Mobilink MFB-3717'), '3717');
      expect(last4Digits('Account # 03227229477'), '9477');
      expect(last4Digits('no digits'), isNull);
    });

    test('names: tolerant, but not of a different person', () {
      expect(namesMatch('TALHA ASLAM', 'Talha Aslam'), isTrue);
      expect(namesMatch('Muhammad Talha Aslam', 'Talha Aslam'), isTrue);
      expect(namesMatch('HUSNAlN ALI', 'Husnain Ali Khan'), isTrue);
      expect(namesMatch('MUHAMMAD SHOAIB ASLAM', 'Talha Aslam'), isFalse);
      expect(namesMatch('Ali', 'Husnain Ali'), isFalse);
      expect(nameMatchPercent('TALHA ASLAM', 'Talha Aslam'), 100);
      expect(nameMatchPercent('Shoaib Aslam', 'Talha Aslam'), lessThan(60));
    });

    test('row builder puts a label and its value back on one line', () {
      final rows = rowsOf(const [
        OcrFragment('Rs. 1', 570, 540, 622, 570),
        OcrFragment('Amount Sent', 64, 538, 210, 568),
        OcrFragment('Service Fee (Incl. Tax)', 64, 605, 300, 637),
        OcrFragment('Rs. 0', 570, 606, 622, 636),
        OcrFragment('Total Amount Rs. 1', 64, 705, 622, 737),
      ]);
      expect(rows, [
        'Amount Sent Rs. 1',
        'Service Fee (Incl. Tax) Rs. 0',
        'Total Amount Rs. 1',
      ]);
    });
  });

  group('slip parser — real samples', () {
    test('Easypaisa', () {
      final r = SlipParser.parse(easypaisaSlip);
      expect(r.provider, 'easypaisa');
      expect(r.successful, isTrue);
      expect(r.amountPaisa, 100000);
      expect(r.conf('amount'), greaterThanOrEqualTo(0.9));
      expect(r.transactionId, '22615557344');
      expect(r.paidAt, DateTime(2024, 6, 26, 2, 15));
      expect(r.receiverName, 'Husnain Ali');
      expect(r.receiverAccountLast4, '9161');
      expect(r.senderName, 'Humaira');
      expect(r.needsAi, isFalse);
      expect(r.registryKey, 'easypaisa_22615557344');
    });

    test('JazzCash: superscript decimals make the amount doubtful', () {
      final r = SlipParser.parse(jazzCashSlip);
      expect(r.provider, 'jazzcash');
      expect(r.successful, isTrue);
      expect(r.amountPaisa, 10000, reason: 'OCR read "Rs. 100"');
      expect(r.conf('amount'), lessThan(0.6));
      expect(r.needsAi, isTrue, reason: 'Gemini must confirm the amount');
      expect(r.transactionId, '446804416088');
      expect(r.paidAt, DateTime(2026, 11, 20, 1, 33));
      expect(r.receiverName, 'Muhammad Shoaib Aslam');
      expect(r.receiverAccountLast4, '9477');
      expect(r.senderName, 'Talha Aslam');
    });

    test('JazzCash: Gemini fills the amount OCR could not trust', () {
      final ocr = SlipParser.parse(jazzCashSlip);
      final ai = SlipReading.fromAi({
        'provider': 'JazzCash',
        'successful': true,
        'amount': 1.0,
        'transactionId': '446804416088',
        'dateTime': '2026-11-20T01:33:00',
        'receiverName': 'MUHAMMAD SHOAIB ASLAM',
        'receiverAccount': '03227229477',
        'senderName': 'TALHA ASLAM',
      });
      final merged = ocr.mergedWith(ai);
      expect(merged.amountPaisa, 100);
      expect(merged.engine, 'ocr+gemini');
      // Confident OCR fields are kept.
      expect(merged.transactionId, '446804416088');
      expect(merged.receiverAccountLast4, '9477');
    });

    test('Gemini unavailable: the OCR result stands', () {
      final ocr = SlipParser.parse(jazzCashSlip);
      expect(ocr.mergedWith(SlipReading.empty).amountPaisa, 10000);
      expect(ocr.mergedWith(SlipReading.empty).engine, 'ocr');
    });

    test('Meezan → JazzCash via Raast', () {
      final r = SlipParser.parse(meezanSlip);
      expect(r.provider, 'meezan');
      expect(r.amountPaisa, 1000);
      expect(r.transactionId, '013956');
      expect(r.paidAt, DateTime(2026, 11, 20, 1, 39));
      expect(r.receiverName, 'Talha Aslam');
      expect(r.receiverAccountLast4, '3717');
      expect(r.senderName, 'Talha Aslam');
      expect(r.senderAccountLast4, '3511');
      expect(r.needsAi, isFalse);
    });

    test('NayaPay: truncated transaction id', () {
      final r = SlipParser.parse(nayaPaySlip);
      expect(r.provider, 'nayapay');
      expect(r.amountPaisa, 100);
      expect(r.conf('amount'), greaterThanOrEqualTo(0.9));
      expect(r.transactionId, '6aff5db31783980fb91ca');
      expect(r.transactionIdTruncated, isTrue);
      expect(r.paidAt, DateTime(2026, 11, 20, 1, 36));
      expect(r.receiverName, 'Talha Aslam');
      expect(r.receiverAccountLast4, '3717');
      expect(r.senderName, 'Talha Aslam');
      expect(r.registryKey, 'nayapay_6AFF5DB31783980FB91CA');
    });

    test('a total wins over the amount sent, and fees are ignored', () {
      final r = SlipParser.parse(const [
        'Amount Sent Rs. 5,000',
        'Service Fee Rs. 25',
        'Total Amount Rs. 5,025',
        'TID 1234567890',
      ]);
      expect(r.amountPaisa, 502500);
    });

    test('two different unlabelled figures are ambiguous', () {
      final r = SlipParser.parse(const [
        'Rs. 500',
        'Rs. 4,500',
        'TID 99887766',
      ]);
      expect(r.conf('amount'), lessThan(0.6));
      expect(r.needsAi, isTrue);
    });

    test('failed / pending transfers are flagged', () {
      final r = SlipParser.parse([
        ...easypaisaSlip.map(
          (l) => l == 'Transaction Successful' ? 'Transaction Failed' : l,
        ),
      ]);
      expect(r.successful, isFalse);
      expect(
        SlipParser.parse(const ['Transaction Pending', 'Rs. 100']).successful,
        isFalse,
      );
    });
  });

  group('slip matching', () {
    final now = DateTime(2024, 6, 27, 9);
    final husnain = SlipExpectation.forDriver(
      amountPaisa: 100000,
      periodStart: DateTime(2024, 6, 24),
      driverName: 'Husnain Ali',
      payout: const PayoutDetails(
        wallets: [
          WalletAccount(
            provider: 'Easypaisa',
            name: 'Husnain Ali',
            number: '0315 1929161',
          ),
        ],
      ),
    );

    test('a slip that fits the bill matches', () {
      final c = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        husnain,
        now: now,
      );
      expect(c.issues, isEmpty);
      expect(c.matches, isTrue);
      expect(c.summary(), 'AI check: matches ✅');
      expect(c.transactionId, '22615557344');
      expect(c.receiverAccountLast4, '9161');
    });

    test('amount mismatch names both figures', () {
      final c = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        SlipExpectation.forDriver(
          amountPaisa: 150000,
          periodStart: DateTime(2024, 6, 24),
          driverName: 'Husnain Ali',
        ),
        now: now,
      );
      expect(c.issues, [SlipCheck.amountMismatch]);
      expect(c.summary(), contains('Rs 1,000 vs bill Rs 1,500'));
      expect(c.messages().single, contains('Rs 1,500'));
    });

    test('money sent to someone else', () {
      final c = evaluateSlip(
        SlipParser.parse(
          jazzCashSlip,
        ).mergedWith(SlipReading.fromAi(const {'amount': 1})),
        SlipExpectation.forDriver(
          amountPaisa: 100,
          periodStart: DateTime(2026, 11, 18),
          driverName: 'Talha Aslam',
          payout: talhaPayout,
        ),
        now: DateTime(2026, 11, 20, 2),
      );
      expect(c.issues, [SlipCheck.receiverMismatch]);
      expect(c.messages().single, contains('Muhammad Shoaib Aslam'));
    });

    test('masked receiver number matches a wallet by its last four', () {
      final c = evaluateSlip(
        SlipParser.parse(meezanSlip),
        SlipExpectation.forDriver(
          amountPaisa: 1000,
          periodStart: DateTime(2026, 11, 18),
          driverName: 'Someone Else',
          payout: talhaPayout,
        ),
        now: DateTime(2026, 11, 20, 2),
      );
      expect(c.issues, isEmpty);
    });

    test('NayaPay slip to the right wallet matches', () {
      final c = evaluateSlip(
        SlipParser.parse(nayaPaySlip),
        SlipExpectation.forDriver(
          amountPaisa: 100,
          periodStart: DateTime(2026, 11, 1),
          driverName: 'Talha Aslam',
          payout: talhaPayout,
        ),
        now: DateTime(2026, 11, 20, 2),
      );
      expect(c.matches, isTrue);
      expect(c.transactionId, '6aff5db31783980fb91ca…');
    });

    test('an old screenshot is out of the bill period', () {
      final c = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        SlipExpectation.forDriver(
          amountPaisa: 100000,
          periodStart: DateTime(2024, 8, 1),
          driverName: 'Husnain Ali',
        ),
        now: DateTime(2024, 8, 5),
      );
      expect(c.issues, [SlipCheck.dateOutOfRange]);
    });

    test('paying three days early is fine; a future date is not', () {
      final early = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        SlipExpectation.forDriver(
          amountPaisa: 100000,
          periodStart: DateTime(2024, 6, 28),
          driverName: 'Husnain Ali',
        ),
        now: now,
      );
      expect(early.issues, isEmpty);
      final future = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        husnain,
        now: DateTime(2024, 6, 20),
      );
      expect(future.issues, [SlipCheck.dateOutOfRange]);
    });

    test('a transaction id already used is a duplicate', () {
      final c = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        husnain,
        duplicate: true,
        now: now,
      );
      expect(c.issues, [SlipCheck.duplicateTransaction]);
      expect(c.summary(), contains('1 issue'));
    });

    test('receiver not read is a soft "unreadable", not a mismatch', () {
      final c = evaluateSlip(
        SlipParser.parse(const [
          'Transaction Successful',
          'Total Amount Rs. 1,000',
          'TID 5566778899',
        ]),
        husnain,
        now: now,
      );
      expect(c.issues, [SlipCheck.receiverUnreadable]);
    });

    test('a failed transfer is reported', () {
      final c = evaluateSlip(
        SlipParser.parse([
          ...easypaisaSlip.map(
            (l) => l == 'Transaction Successful' ? 'Transaction Failed' : l,
          ),
        ]),
        husnain,
        now: now,
      );
      expect(c.issues, [SlipCheck.notSuccessful]);
    });

    test('nothing useful read: unreadable', () {
      final c = evaluateSlip(
        SlipParser.parse(const ['Hello', 'Good morning']),
        husnain,
        now: now,
      );
      expect(c.issues, [SlipCheck.unreadable]);
    });
  });

  group('SlipCheck model', () {
    test('round-trips through a map and onto a Payment', () {
      final check = SlipCheck(
        provider: 'jazzcash',
        amountPaisa: 450000,
        expectedAmountPaisa: 500000,
        transactionId: '446804416088',
        paidAt: DateTime(2026, 11, 20, 1, 33),
        receiverName: 'Talha Aslam',
        receiverAccountLast4: '3717',
        engine: SlipCheck.engineBoth,
        issues: const [SlipCheck.amountMismatch, SlipCheck.dateOutOfRange],
        checkedAt: DateTime(2026, 11, 20, 2),
      );
      final back = SlipCheck.fromMap(check.toMap());
      expect(back.amountPaisa, 450000);
      expect(back.issues, check.issues);
      expect(back.engine, 'ocr+gemini');
      expect(back.receiverAccountLast4, '3717');
      expect(
        back.summary(),
        'AI check: 2 issues — amount Rs 4,500 vs bill Rs 5,000 ⚠️',
      );

      final payment = Payment.fromMap('p1', {
        'studentId': 's',
        'parentId': 'u',
        'monthKey': '2026-11',
        'amountPaisa': 500000,
        'slipCheck': check.toMap(),
      });
      expect(payment.slipCheck?.issues.length, 2);
      expect(payment.toMap()['slipCheck'], isA<Map<String, dynamic>>());
      expect(
        payment
            .copyWith(slipCheck: back.copyWith(issues: const []))
            .slipCheck!
            .matches,
        isTrue,
      );
    });

    test('stores no full account number', () {
      final c = evaluateSlip(
        SlipParser.parse(easypaisaSlip),
        const SlipExpectation(amountPaisa: 100000),
      );
      final stored = c.toMap().values.join(' ');
      expect(stored, isNot(contains('03151929161')));
      expect(stored, isNot(contains('03168962255')));
    });
  });
}
