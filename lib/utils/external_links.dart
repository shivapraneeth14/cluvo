import 'package:url_launcher/url_launcher.dart';

/// Shared external-link policy for the mobile app.
///
/// Only `https`/`http` links with a non-empty host may be launched from
/// user/content-controlled URLs. Anything else (intent://, sms:, tel:, custom
/// app schemes, blank scheme) is ignored — those can deep-link into unrelated
/// apps or PhishKit-style surfaces and must never be reachable from
/// organizer-supplied content.
///
/// `mailto:` is allowed ONLY for hardcoded support links
/// ([allowMailto]), never for user content.
bool isSafeExternalUrl(Uri uri, {bool allowMailto = false}) {
  if (uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'mailto') return allowMailto;
  return scheme == 'https' || scheme == 'http';
}

/// Tries to open [raw] in the platform's external application. Returns true
/// when the link was launched, false when the URL is unsafe or no app exists.
Future<bool> openExternalLink(String raw, {bool allowMailto = false}) async {
  final uri = Uri.tryParse(raw);
  if (uri == null || !isSafeExternalUrl(uri, allowMailto: allowMailto)) {
    return false;
  }
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}