import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen pop-up showing [image] with pinch-to-zoom, a "Pinch to Zoom"
/// hint, and a close button. Reusable across any profile screen that lets a
/// user tap an avatar to inspect it more closely -- pass whatever
/// [ImageProvider] the avatar itself is already rendering (`FileImage` for a
/// freshly-picked photo, `NetworkImage`/`CloudinaryService.thumbnail(...)`
/// for a persisted one).
Future<void> showZoomableImageDialog(
  BuildContext context,
  ImageProvider image, {
  Color accentColor = AppTheme.parentPurple,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Pinch to Zoom',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image(image: image, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: accentColor,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
