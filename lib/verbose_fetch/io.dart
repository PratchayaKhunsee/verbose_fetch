import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

import '_error.dart';
import '_enum.dart';
import '_instance.dart';

enum _MultipartReadingMode {
  header,
  body,
}

dynamic _createBody(RequestBody body) {
  switch (body.type) {
    case RequestBodyType.formData:
      {
        if (body.content is! List<FormDataField>) {
          throw InvalidPayloadException();
        }
        return body.content;
      }
    case RequestBodyType.json:
      {
        try {
          return json.encode(body.content);
        } catch (e) {
          throw InvalidPayloadException();
        }
      }
    default:
      {
        return '${body.content}';
      }
  }
}

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
  dynamic _body = method == RequestMethod.get ||
          method == RequestMethod.head ||
          method == null
      ? null
      : _createBody(body!);

  Client client = Client();
  Uri uri = Uri.parse(url);
  String _method = <RequestMethod, String>{
        RequestMethod.post: 'POST',
        RequestMethod.patch: 'PATCH',
        RequestMethod.put: 'PUT',
        RequestMethod.head: 'HEAD',
        RequestMethod.delete: 'DELETE',
      }[method] ??
      'GET';

  late StreamedResponse response;

  if (body != null) {
    switch (body.type) {
      case RequestBodyType.formData:
        MultipartRequest multipartRequest = MultipartRequest(_method, uri);

        for (var e in (_body as List<FormDataField>)) {
          if (e is FileField) {
            multipartRequest.files.add(MultipartFile.fromBytes(
              e.name,
              e.value.toList(),
              contentType:
                  e.mimeType is String ? MediaType.parse(e.mimeType!) : null,
              filename: e.fileName,
            ));
          } else {
            multipartRequest.fields[e.name] = '${e.value}';
          }
        }

        if (headers != null) multipartRequest.headers.addAll(headers);
        response = await client.send(multipartRequest);
        break;
      default:
        Request request = Request(_method, uri);
        if (body.type == RequestBodyType.json) {
          request.headers['Content-Type'] = 'application/json';
        }
        if (headers != null) request.headers.addAll(headers);

        request.body = _body;

        response = await client.send(request);
    }
  } else {
    Request request = Request('GET', uri);
    if (headers != null) request.headers.addAll(headers);
    response = await client.send(request);
  }

  FetchResponse result = FetchResponse();

  String? getHeader(Pattern headerName, Map<String, String> headers) {
    for (MapEntry<String, String> e in headers.entries) {
      if (e.key.contains(headerName)) return e.value;
    }
    return null;
  }

  RegExp letterCase(String pattern) => RegExp(pattern.splitMapJoin(
        RegExp("[A-Za-z]"),
        onMatch: (p0) {
          String c = p0.group(0) ?? "";
          return "(${c.toLowerCase()}|${c.toUpperCase()})";
        },
      ));

  setTextFunc(result, () async {
    try {
      return await response.stream.bytesToString();
    } catch (e) {
      throw UnreadableException();
    }
  });
  setFormDataFunc(result, () async {
    try {
      Uint8List byteList = await response.stream.toBytes();
      String? contentType =
          getHeader(letterCase("Content-Type"), response.headers);

      if (contentType == null ||
          !contentType.contains(
              RegExp(r"multipart/form-data\s*;\s*boundary\s*=\s*.+"))) {
        throw UnreadableException();
      }

      String boundary = contentType
          .split(RegExp("(boundary\\s*=\\s*(\"|))"))[1]
          .replaceAll(RegExp("\"\$"), "");

      List<int> bodyByteList = byteList.toList();
      List<FormDataField> fields = [];

      _MultipartReadingMode phase = _MultipartReadingMode.header;

      /// The current line as a byte list.
      List<int> currentLine = [];
      bool isFile = false;
      bool isFirstLine = true;
      String? fileName;
      String? fieldName;
      String? mime;
      List<int> content = [];

      bool isHeaderReadingPhase() => phase == _MultipartReadingMode.header;
      bool isBodyReadingPhase() => phase == _MultipartReadingMode.body;

      void createField() {
        if (isFile) {
          fields.add(FileField(
            fieldName!,
            Uint8List.fromList(content),
            fileName ?? "",
            mimeType: mime,
          ));
        } else {
          fields.add(NonFileField(
            fieldName!,
            utf8.decode(content, allowMalformed: true),
          ));
        }
      }

      for (int i = 0; i < bodyByteList.length; i++) {
        if (bodyByteList[i] == 0x0d && bodyByteList[i + 1] == 0x0a) {
          String lineString = utf8.decode(currentLine, allowMalformed: true);

          if (isFirstLine) {
            if (lineString != "--$boundary") throw 0;
          }

          // Go to form field's information reading phase.
          else if (lineString == "--$boundary") {
            createField();
            phase = _MultipartReadingMode.header;
            fileName = fieldName = mime = null;
            isFile = false;
            content = [];
          }
          // End the entire reading process, and put the remaining form field.
          else if (lineString == "--$boundary--") {
            createField();
            break;
          }
          // Read the content from each line of payload.
          else if (isBodyReadingPhase()) {
            if (content.isNotEmpty) {
              content.addAll([0x0d, 0x0a]);
            }
            content.addAll(currentLine);
          }
          // Get form field's name and file name.
          else if (isHeaderReadingPhase() &&
              lineString.contains(RegExp(
                "Content-Disposition\\s*:\\s*form-data.+?name\\s*=\\s*\".*\"",
              ))) {
            List<String> n = lineString.split(
              RegExp("Content-Disposition\\s*:.+?name\\s*=\\s*\""),
            );

            List<String> fn = lineString.split(
              RegExp("Content-Disposition\\s*:.+?filename\\s*=\\s*\""),
            );

            if (n.length < 2) throw 0;

            fieldName = n[1].replaceAll(RegExp("\"*\$"), "");

            fileName =
                fn.length < 2 ? null : fn[1].replaceAll(RegExp("\"*\$"), "");
          }
          // Find form field mime type and determine this current form field is file form field.
          else if (isHeaderReadingPhase() &&
              lineString.contains(RegExp("Content-Type\\s*:.+"))) {
            List<String> m = lineString.split(RegExp("Content-Type\\s*:\\s*"));
            if (m.length > 1) {
              List<String> h = m[1].split(RegExp("\\/"));

              if (m.length < 2) continue;
              String front = h[0];
              String back = h[1];
              for (var i = 0; i < back.length; i++) {
                if (!back[i].contains(RegExp("([A-Za-z]|-)"))) {
                  back = back.substring(0, i + 1);
                  continue;
                }
              }

              mime = "$front/$back";
              isFile = front.isNotEmpty &&
                  front.isNotEmpty &&
                  fileName != null &&
                  fileName.isNotEmpty;
            }
          } else if (isHeaderReadingPhase() && lineString.isEmpty) {
            phase = _MultipartReadingMode.body;

            if (fieldName == null) {
              throw 1;
            }
          }

          isFirstLine = false;
          i++;
          currentLine = [];
          continue;
        } else {
          currentLine.add(bodyByteList[i]);
        }
      }

      return fields;
    } catch (e) {
      throw UnreadableException();
    }
  });
  setJsonFunc(result, () async {
    String? contentType = getHeader(
      letterCase("Content-Type"),
      response.headers,
    );
    if (contentType == null ||
        !contentType.contains(RegExp(r"application\/json"))) {
      throw UnreadableException();
    }

    try {
      return json.decode(await response.stream.bytesToString());
    } catch (e) {
      throw UnreadableException();
    }
  });
  setHeadersFunc(result, () => response.headers);
  setStatusFunc(result, () => response.statusCode);

  return result;
}
