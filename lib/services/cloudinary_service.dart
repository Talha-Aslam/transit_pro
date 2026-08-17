import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:transit_core/transit_core.dart';

/// Result of a successful upload.
class UploadResult {
  /// HTTPS URL to store on the owning document and render in the UI.
  final String secureUrl;

  /// Cloudinary's identifier — required to delete the asset later.
  final String publicId;

  final int bytes;
  final String format;

  const UploadResult({
    required this.secureUrl,
    required this.publicId,
    this.bytes = 0,
    this.format = '',
  });
}

class UploadException implements Exception {
  final String message;
  const UploadException(this.message);

  @override
  String toString() => message;
}

/// File storage, backed by Cloudinary rather than Firebase Storage.
///
/// Firebase Storage is not provisioned on `transitpro-db` and, for a project of
/// this vintage, enabling it requires the paid Blaze plan. Cloudinary's free
/// tier (25 GB) needs no card, so it carries driver documents, payment slips
/// and profile photos.
///
/// **Uploads are unsigned.** The Cloudinary API *secret* must never ship inside
/// a client app — anyone could extract it and delete the whole media library.
/// An unsigned upload preset is the correct mechanism: it needs only the cloud
/// name and the preset name, both of which are safe to expose.
///
/// Set up in the Cloudinary dashboard:
/// Settings → Upload → Upload presets → Add preset → Signing mode: **Unsigned**
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  /// Whether uploads can run at all. Every caller must check this and degrade
  /// gracefully — the app is fully usable without it.
  bool get isConfigured => AppConfig.hasCloudinary;

  Uri _endpoint(String resourceType) => Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '${AppConfig.cloudinaryCloudName}/$resourceType/upload',
      );

  /// Uploads [file] and returns its URL.
  ///
  /// [folder] keeps the media library organised, e.g. `driver_documents`.
  /// [resourceType] is `image` for photos and slips, `raw` for PDFs.
  Future<UploadResult> upload(
    File file, {
    String folder = 'transitpro',
    String resourceType = 'image',
    String? publicIdHint,
  }) async {
    if (!isConfigured) {
      throw const UploadException(
        'File upload is not configured. Provide CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET via --dart-define.',
      );
    }

    if (!file.existsSync()) {
      throw const UploadException('The selected file no longer exists.');
    }

    final request = http.MultipartRequest('POST', _endpoint(resourceType))
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = folder;

    if (publicIdHint != null && publicIdHint.isNotEmpty) {
      request.fields['public_id'] = publicIdHint;
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final reason = _extractError(response.body) ?? 'HTTP ${response.statusCode}';
        throw UploadException('Upload failed: $reason');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = body['secure_url'] as String?;
      final publicId = body['public_id'] as String?;

      if (secureUrl == null || publicId == null) {
        throw const UploadException('Upload succeeded but returned no URL.');
      }

      return UploadResult(
        secureUrl: secureUrl,
        publicId: publicId,
        bytes: (body['bytes'] as num?)?.toInt() ?? 0,
        format: body['format'] as String? ?? '',
      );
    } on UploadException {
      rethrow;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      throw UploadException('Upload failed. Check your connection: $e');
    }
  }

  // Convenience wrappers so callers don't repeat folder names.
  //
  // None of these pass a public id, and that is deliberate. The `TransitPro`
  // preset is configured with `Overwrite: false`, and Cloudinary does not allow
  // unsigned uploads to set `overwrite: true` at all — so a fixed id like
  // `user_<uid>` would collide the second time the same user changed their
  // photo. Letting Cloudinary mint a random id makes every upload succeed;
  // replacing a file means storing the new URL and leaving the old asset
  // orphaned, which is free and harmless at 25 GB.

  Future<UploadResult> uploadProfilePhoto(File file, String uid) =>
      upload(file, folder: 'transitpro/profiles');

  Future<UploadResult> uploadDriverDocument(File file, String driverId, String docType) =>
      upload(file, folder: 'transitpro/driver_documents');

  Future<UploadResult> uploadPaymentSlip(File file, String paymentId) =>
      upload(file, folder: 'transitpro/payment_slips');

  /// Builds a resized delivery URL from a stored [secureUrl].
  ///
  /// Cloudinary transforms on the fly, so a 4 MB phone photo can be served as a
  /// 200 px avatar without a second upload — worth doing on list screens.
  static String thumbnail(String secureUrl, {int width = 200}) {
    const marker = '/upload/';
    final i = secureUrl.indexOf(marker);
    if (i == -1) return secureUrl;
    return secureUrl.replaceFirst(
      marker,
      '${marker}w_$width,c_limit,q_auto,f_auto/',
    );
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return decoded['error']['message'] as String?;
      }
    } catch (_) {
      // Fall through — the body wasn't JSON.
    }
    return null;
  }
}

// NOTE ON DELETION
// ────────────────
// Deleting an asset requires a signed request, which needs the API secret and
// therefore must NOT happen from the app. Options, in order of preference:
//   1. Leave orphaned files. At 25 GB free this is fine for a pilot.
//   2. Delete manually from the Cloudinary dashboard.
//   3. Add a signed delete endpoint later if the project ever gets a server.
// Storing `publicId` on every document keeps all three options open.
