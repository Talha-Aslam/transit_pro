import 'package:flutter/widgets.dart';

/// Owns a [TextEditingController] for exactly as long as a sheet or dialog
/// is on screen.
///
/// Disposing the controller when `showModalBottomSheet`'s future completes
/// is too early: a sheet dragged away completes that future at the start of
/// its closing animation, while the text field is still mounted, and the
/// controller is pulled out from under it — the `_dependents.isEmpty`
/// assertion. Tying it to this widget's lifetime disposes it only once the
/// sheet itself is gone.
class TextControllerScope extends StatefulWidget {
  final Widget Function(TextEditingController controller) builder;
  const TextControllerScope({super.key, required this.builder});

  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_ctrl);
}
