@JS()
library js;

import 'package:js/js.dart';

@JS('console.error')
external void printError(msg);

@JS('console.log')
external void print(msg);

@JS('Object')
class Object {
  external static dynamic entries(obj);
}

@JS('Array')
class Array {
  external static bool isArray(value);
  external static Array from(arrayLike);
  external int get length;
}

@JS('Promise')
class Promise {}

@JS('Uint8Array')
class Uint8Array {
  external Uint8Array(length);
  external static Uint8Array from(arrayLike);
}

@JS('Blob')
class Blob {
  external Blob(array, [options]);
}

@JS('FormData')
class FormData {
  external void append(String name, value, [String? filename]);
}

@JS('Headers')
class Headers {
  external factory Headers();
  external void set(String name, String value);
  external String get(String name);
}

@JS('Request')
class Request {
  external factory Request(
    url, [
    init,
  ]);
}

@JS('fetch')
external Promise fetch(
  resource, [
  init,
]);
