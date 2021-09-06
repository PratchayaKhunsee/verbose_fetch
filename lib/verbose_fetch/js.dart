@JS()
library js;

import 'package:js/js.dart';
import 'package:js/js_util.dart';

@JS()
external dynamic window;

getObjectEntryIterator(obj) {
  return callMethod(getProperty(window, 'Object'), 'entries', [obj]);
}

createArray([List? member]) {
  return callConstructor(getProperty(window, 'Array'), member ?? []);
}

createArrayFrom(arrayLike) {
  return callMethod(getProperty(window, 'Array'), 'from',
      arrayLike != null ? [arrayLike] : []);
}

removeFirstFromArray(array) {
  if (!instanceof(array, getProperty(window, 'Array'))) return;
  return callMethod(array, 'shift', []);
}

isArray(obj) {
  return callMethod(getProperty(window, 'Array'), 'isArray', [obj]);
}

getLength(list) {
  return getProperty(list, 'length');
}

createUint8Array(lengthOrObject, [int? byteOffset, int? length]) {
  var args = [lengthOrObject];
  if (byteOffset != null) args.add(byteOffset);
  if (length != null) args.add(length);
  return callConstructor(getProperty(window, 'Uint8Array'), args);
}

createUint8ArrayFrom(arrayLike) {
  return callMethod(getProperty(window, 'Uint8Array'), 'from', [arrayLike]);
}

createBlob(array, [options]) {
  var args = [array];
  if (options != null) args.add(options);
  return callConstructor(getProperty(window, 'Blob'), args);
}

createFormData() {
  return callConstructor(getProperty(window, 'FormData'), []);
}

appendFormDataField(formData, String name, value, [String? filename]) {
  if (!instanceof(formData, getProperty(window, 'FormData'))) return;
  var args = [name, value];
  if (filename != null) args.add(filename);
  callMethod(formData, 'append', args);
}

createRequest(url, [init]) {
  var args = [url];
  if (init != null) args.add(init);

  return callConstructor(getProperty(window, 'Request'), args);
}

createHeaders() {
  return callConstructor(getProperty(window, 'Headers'), []);
}

setHeaders(headers, String name, String value) {
  if (!instanceof(headers, getProperty(window, 'Headers'))) return;
  callMethod(headers, 'set', [name, value]);
}

callFetch(resource, [init]) {
  var args = [resource];
  if (init != null) args.add(init);
  return callMethod(window, 'fetch', args);
}
