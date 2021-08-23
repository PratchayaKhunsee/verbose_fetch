/// The HTTP request method.
enum RequestMethod {
  get,
  post,
  put,
  delete,
  head,
  patch,
}

/// The mode of doing HTTP request.
///
/// - Can only be used in web platform.
enum RequestMode {
  cors,
  noCors,
  sameOrigin,
  navigate,
}

/// How to manage the HTTP cache.
///
/// - Can only be used in web platform.
enum RequestCacheMode {
  normal,
  noStore,
  reload,
  noCache,
  forceCache,
  onlyIfCached,
}

/// How browsers handling the HTTP response in redirect mode.
///
/// - Can only be used in web platform.
enum RequestRedirectMode {
  follow,
  error,
  manual,
}

/// The option of HTTP request referrer policy.
///
/// - Can only be used in web platform.
enum RequestReferrerPolicy {
  noReferrer,
  noReferrerWhenDowngrade,
  origin,
  originWhenCrossOrigin,
  sameOrigin,
  strictOrigin,
  strictOriginWhenCrossOrigin,
  unsafeUrl,
}

/// How browsers handling HTTP request with credentials.
///
/// - Can only be used in web platform.
enum RequestCredentials {
  omit,
  sameOrigin,
  include,
}

/// The type of request body.
enum RequestBodyType {
  text,
  formData,
  json,
}

/// The form field type.
enum FormDataFieldType {
  nonFile,
  file,
}
