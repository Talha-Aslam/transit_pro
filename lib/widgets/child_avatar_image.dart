import 'dart:io';

import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';

/// A child's avatar: a freshly-picked local [localFile] while an upload is
/// in flight, else the persisted [photoUrl] from Firestore, else a
/// placeholder. Optionally shows a spinner overlay while [uploading].
///
/// Shared by `parent_dashboard.dart` and `parent_profile.dart`'s `_ChildCard`
/// — both used to render this avatar with `Image.file(...)` only, which is
/// why a picked photo displayed instantly but vanished on the next app
/// launch: [photoUrl] (the one part of this that actually survives a
/// restart) was never read at either call site, even though
/// `ParentDataService.updateChildImage` was already uploading it and saving
/// it to Firestore correctly.
class ChildAvatarImage extends StatelessWidget {
  final File? localFile;
  final String? photoUrl;
  final double size;
  final BorderRadius borderRadius;
  final bool uploading;

  const ChildAvatarImage({
    super.key,
    required this.localFile,
    required this.photoUrl,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(borderRadius: borderRadius, child: _image()),
        // A translucent scrim + spinner while the upload is in flight, so
        // the avatar doesn't look "done" before the photo actually saved —
        // this is what makes the wait visible, not just the button being
        // briefly unresponsive.
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
    if (localFile != null) {
      return Image.file(
        localFile!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      // Cloudinary resizes on the fly — asking for roughly 2x the render
      // size covers standard and high-density screens without shipping a
      // full-resolution photo into a 44px avatar.
      return Image.network(
        CloudinaryService.thumbnail(photoUrl!, width: (size * 2).round()),
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(),
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Image.asset(
    'assets/images/profile/boy_transparent.gif',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}
