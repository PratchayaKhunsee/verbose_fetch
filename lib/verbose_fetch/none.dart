import '_enum.dart';
import '_instance.dart';

/// Do the request.
///
/// [mode],[credentials],[cacheMode],[redirect],[referrer],[referrerPolicy],[intergrity],[keepAlive]
/// named parameters can only be used in web platform.
Future<FetchResponse> fetch(
  String url, {
  RequestMethod? method,
  Map<String, String>? headers,
  RequestBody? body,
  RequestMode? mode,
  RequestCredentials? credentials,
  RequestCacheMode? cacheMode,
  RequestRedirectMode? redirect,
  String? referrer,
  RequestReferrerPolicy? referrerPolicy,
  RequestIntergrity? intergrity,
  bool? keepAlive,
}) async {
  throw UnsupportedError(
      'The current platform is not supported for this library.');
}
