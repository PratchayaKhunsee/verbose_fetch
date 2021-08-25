import 'dart:convert';
import 'dart:typed_data';

import '_enum.dart';

/// The subresource integrity builder for the HTTP request.
class RequestIntergrity {
  String checksum;
  String hash;
  RequestIntergrity({
    required this.hash,
    required this.checksum,
  });

  String text() => '${hash.toLowerCase()}-$checksum';
}

/// The instance of the part of the form field.
///
/// It can be [FileField] or [NonFileField].
abstract class FormDataField {
  late String name;
  dynamic _value;
  FormDataField(this.name, this._value);

  get value => _value;

  /// Convert the value by [json.decode] method if it is a JSON-convertible string.
  /// Otherwise, it returns the original value instead.
  tryJsonDecodeValue() {
    try {
      return json.decode(value as String);
    } catch (e) {
      return value;
    }
  }

  /// Convert the value to the list of values if it is a string containing has ","(colon) as the separator.
  /// Otherwise, it returns the original value instead.
  trySplitValue({
    Function(String value)? replaceEach,
  }) {
    try {
      return (value as String).split(RegExp(",")).map((v) {
        try {
          return replaceEach?.call(v) ?? v;
        } catch (err) {
          return v;
        }
      }).toList();
    } catch (e) {
      return value;
    }
  }
}

/// The instance of the non-file form field.
///
/// The value type is [String].
class NonFileField extends FormDataField {
  NonFileField(
    String name,
    String value,
  ) : super(name, value);

  set value(String x) {
    _value = x;
  }

  @override
  String get value => _value as String;
}

/// The instance of the file form field.
///
/// The value type is [Uint8List].
class FileField extends FormDataField {
  String fileName;
  String? mimeType;
  FileField(
    String name,
    Uint8List value,
    this.fileName, {
    this.mimeType,
  }) : super(name, value);

  set value(Uint8List x) {
    _value = x;
  }

  @override
  Uint8List get value => _value as Uint8List;
}

/// The request body builder.
class RequestBody<T> {
  final RequestBodyType type;
  final T? content;
  RequestBody({
    this.type = RequestBodyType.text,
    this.content,
  });

  static RequestBody<String> text(String body) => RequestBody<String>(
        type: RequestBodyType.text,
        content: body,
      );

  static RequestBody<Map<String, dynamic>> json(Map<String, dynamic> body) =>
      RequestBody<Map<String, dynamic>>(
        type: RequestBodyType.json,
        content: body,
      );

  static RequestBody<List<FormDataField>> formData(List<FormDataField> body) =>
      RequestBody<List<FormDataField>>(
        type: RequestBodyType.formData,
        content: body,
      );
}

/// The result of [fetch].
class FetchResponse {
  late Future<String> Function() _textFunc;
  late Future<List<FormDataField>> Function() _formDataFunc;
  late Future<dynamic> Function() _jsonFunc;
  late Map<String, String> Function() _headersFunc;
  late int Function() _statusFunc;

  /// Convert the response body to a plain text.
  ///
  /// - In web platform, it can be only consumed once when there is no [formData] or [json] method consumption before.
  Future<String> text() async => await _textFunc();

  /// Convert the response body to the [List] of [FormDataFieldEntry].
  ///
  /// - In web platform, it can be only consumed once when there is no [text] or [json] method consumption before.
  Future<List<FormDataField>> formData() async => await _formDataFunc();

  /// Convert the response body to the JSON object.
  ///
  /// - In web platform, it can be only consumed once when there is no [text] or [formData] method consumption before.
  Future<dynamic> json() async => await _jsonFunc();

  /// The response headers.
  Map<String, String> get headers => _headersFunc();

  /// The response status code.
  int get status => _statusFunc();
}

void setTextFunc(FetchResponse response, Future<String> Function() f) {
  response._textFunc = f;
}

void setFormDataFunc(
    FetchResponse response, Future<List<FormDataField>> Function() f) {
  response._formDataFunc = f;
}

void setJsonFunc(FetchResponse response, Future<dynamic> Function() f) {
  response._jsonFunc = f;
}

void setHeadersFunc(FetchResponse response, Map<String, String> Function() f) {
  response._headersFunc = f;
}

void setStatusFunc(FetchResponse response, int Function() f) {
  response._statusFunc = f;
}
