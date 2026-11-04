import 'dart:io';

import 'package:flutter/material.dart';

import 'avatar_image.dart';

/// A child's avatar, with the app's standard illustrated placeholder.
///
/// Thin wrapper over [AvatarImage] — the picked-file-then-URL-then-fallback
/// rule lives there, shared with the driver's own avatar and with every
/// rider row on the driver's screens, so a fix to one is a fix to all.
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
  Widget build(BuildContext context) => AvatarImage(
    localFile: localFile,
    photoUrl: photoUrl,
    size: size,
    borderRadius: borderRadius,
    uploading: uploading,
    fallback: Image.asset(
      'assets/images/profile/boy_transparent.gif',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
}
