/// Turns OCR lines (text + bounding box) into reading-order text.
///
/// ML Kit returns blocks, and on a two-column receipt ("Amount Sent ......
/// Rs. 1") the label column and the value column often land in different
/// blocks — so "Amount Sent" and "Rs. 1" end up far apart in the text. A
/// receipt is read row by row, so [rowsOf] puts everything that shares a
/// row back on one line, left to right.
///
/// Pure Dart (no ML Kit types) so it can be unit tested.
library;

class OcrFragment {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrFragment(this.text, this.left, this.top, this.right, this.bottom);

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// Merges fragments whose vertical centres sit within half a line height of
/// each other into one line, ordered left to right; rows top to bottom.
List<String> rowsOf(List<OcrFragment> fragments) {
  final sorted = [...fragments.where((f) => f.text.trim().isNotEmpty)]
    ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrFragment>>[];
  for (final f in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final ref = row.first;
      final tolerance =
          0.5 * (ref.height < f.height ? ref.height : f.height).clamp(4, 200);
      final rowCenter =
          row.map((r) => r.centerY).reduce((a, b) => a + b) / row.length;
      if ((f.centerY - rowCenter).abs() <= tolerance) {
        row.add(f);
        continue;
      }
    }
    rows.add([f]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((f) => f.text.trim())
          .join(' '),
  ];
}
