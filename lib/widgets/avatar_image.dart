import 'dart:io';

import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';

/// Somebody's profile photo: a freshly-picked [localFile] while an upload is
/// in flight, else the persisted [photoUrl] from Firestore, else [fallback].
///
/// The rule that matters is the order. Every avatar in this app used to be
/// written one of two broken ways — `Image.file(...)` only, which showed a
/// just-picked photo and then lost it on the next launch because the
/// uploaded URL was never read back; or a bare emoji, which never showed a
/// photo at all even when one had been uploaded and was sitting in
/// Firestore. This exists so neither can be written again by accident: it
/// is one widget, it reads both sources, and the fallback is the last
/// resort rather than the only case.
class AvatarImage extends StatelessWidget {
  /// A local file chosen on this device moments ago. Wins over [photoUrl]
  /// so the avatar updates the instant it is picked, not when the upload
  /// finishes.
  final File? localFile;

  /// The persisted URL — the one part of this that survives a restart.
  final String? photoUrl;

  final double size;
  final BorderRadius borderRadius;

  /// Shown when there is no photo at all, and while one is loading.
  /// Typically an emoji or an illustration, never a broken-image icon.
  final Widget fallback;

  /// Draws a scrim and a spinner over the avatar, so a photo that is still
  /// uploading does not look saved before it is.
  final bool uploading;

  const AvatarImage({
    super.key,
    required this.localFile,
    required this.photoUrl,
    required this.size,
    required this.fallback,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(width: size, height: size, child: _image()),
        ),
        if (uploading)
          ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              width: size,
              height: size,
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _image() {
    final file = localFile;
    if (file != null) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A picked file can go away under us — a cleared cache, a photo
        // deleted from the gallery between pick and render.
        errorBuilder: (_, _, _) => _networkOrFallback(),
      );
    }
    return _networkOrFallback();
  }

  Widget _networkOrFallback() {
    final url = photoUrl;
    if (url == null || url.isEmpty) return Center(child: fallback);
    // Cloudinary resizes on the fly — asking for roughly 2x the render
    // size covers standard and high-density screens without shipping a
    // full-resolution photo into a 44px avatar.
    return Image.network(
      CloudinaryService.thumbnail(url, width: (size * 2).round()),
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Center(child: fallback),
      errorBuilder: (_, _, _) => Center(child: fallback),
    );
  }
}

/// The emoji that stands in for a rider with no photo: `🎓` for a college
/// or university rider, `🧒` for a school child.
///
/// Lives here rather than being redefined in each driver screen — two
/// copies of it had already drifted apart from one another.
Widget riderGlyph(String instituteType, {double size = 22}) {
  final t = instituteType.toLowerCase();
  final isOlder = t.contains('university') || t.contains('college');
  return Text(isOlder ? '🎓' : '🧒', style: TextStyle(fontSize: size));
}
