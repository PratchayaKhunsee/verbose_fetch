import 'dart:convert';
import 'dart:typed_data';

// import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

import '_error.dart';
import '_enum.dart';
import '_instance.dart';

// enum _MultipartReadingMode {
//   header,
//   body,
// }

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

RegExp _bothLetterCase(String pattern) => RegExp(pattern.splitMapJoin(
      RegExp("[A-Za-z]"),
      onMatch: (p0) {
        String c = p0.group(0) ?? "";
        return "(${c.toLowerCase()}|${c.toUpperCase()})";
      },
    ));

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

  setTextFunc(result, () async {
    try {
      return await response.stream.bytesToString();
    } catch (e) {
      throw UnreadableException();
    }
  });
  setFormDataFunc(result, () async {
    Uint8List byteList = await response.stream.toBytes();
    String? contentType =
        getHeader(_bothLetterCase("Content-Type"), response.headers);

    if (contentType == null ||
        !contentType
            .contains(RegExp(r"multipart/form-data\s*;\s*boundary\s*=\s*.+"))) {
      throw UnreadableException();
    }

    String boundary = contentType
        .split(RegExp("(boundary\\s*=\\s*(\"|))"))[1]
        .replaceAll(RegExp("\"\$"), "");

    // ignore: constant_identifier_names
    const int CR = 0x0d;
    // ignore: constant_identifier_names
    const int LF = 0x0a;
    // ignore: constant_identifier_names
    const int DASH = 0x2d;
    final List<int> boundaryBytes = utf8.encode(boundary);

    /// The state of form data processing.
    ///
    /// 0 = On first line, next state requires the first dash character
    /// 1 = Detect the first boundary, next state requires the followed DASH character
    /// 2 = Read the first boundary, next state requires the READ BOUNDARY needs to be same as the HEADER BOUNDARY
    /// 3 = Detect the end of the first boundary, next state requires the "CARTRIDGE RETURN" escape character
    /// 4 = End of checking the first boundary, next state reqiures the followed "LINE FEED" escape character
    /// 5 = Read the form header, next state requires the first "CARTIDGE RETURN" escape character
    /// 6 = Detect the form header seperator, next state requires the followed "LINE FEED" escape character
    /// 7 = Detect the form body leading, next state requires the second "CARTRIDGE RETURN" escape character
    /// 8 = End of the form header, next state requires the followed "LINE FEDD' escape character
    /// 9 = Read the form body, next state requires the opening "CARTRIDGE RETURN" escape character
    /// 10 = Detect the line seperator, next state requires the followed "LINE FEED" escape character
    /// 11 = Detect the boundary, next state requires the leading DASH character
    /// 12 = Detect the boundary detection, next state requires the followed DASH character
    /// 12 = End of the boundary, next state requires the READ BOUNDARY needs to be same as the HEADER BOUNDARY
    /// 13 = Detect the last boundary or the next form field, next state requires the leading DASH character or the leading
    /// 14 = End of form data, it requires the followed DASH character to finish the process
    int state = 0;
    int readBoundaryAt = 0;
    bool lineSeperatorDetected = true;

    List<FormDataField> formDataFields = [];
    List<int> formHeaderBytes = [];
    List<int> formBodyBytes = [];
    String? formFieldName;
    String? formFileName;
    String? formContentType;

    /* I'm going to have to create the new logic for form data processing. */
    for (int i = 0; i < byteList.length; i++) {
      int byte = byteList[i];

      /// ignore: non_constant_identifier_names
      bool EOF = false;
      switch (state) {
        case 0:
        case 1:
          if (byte != DASH) throw UnreadableException();
          state++;
          readBoundaryAt = i + 1;
          break;
        case 2:
          if (byte != boundaryBytes[i - readBoundaryAt]) throw 0;
          if (boundaryBytes.length - i + readBoundaryAt == 1) state++;
          break;
        case 3:
          if (byte != CR) throw UnreadableException();
          state++;
          break;
        case 4:
          if (byte != LF) throw UnreadableException();
          state++;
          break;
        case 5:
          if (byte == CR) {
            state++;
          } else {
            formHeaderBytes.add(byte);
          }
          break;
        case 6:
          if (byte == LF) {
            state++;
          } else {
            formHeaderBytes.addAll([CR, byte]);
            state--;
          }
          break;
        case 7:
          if (byte == CR) {
            state++;
          } else {
            formHeaderBytes.addAll([CR, LF, byte]);
            state -= 2;
          }
          break;
        case 8:
          if (byte == LF) {
            String formHeader =
                utf8.decode(formHeaderBytes, allowMalformed: true);

            List<String> n = formHeader.split(
              RegExp("Content-Disposition\\s*:.+?name\\s*=\\s*\""),
            );

            List<String> fn = formHeader.split(
              RegExp("Content-Disposition\\s*:.+?filename\\s*=\\s*\""),
            );

            List<String> m = formHeader.split(
              RegExp("${_bothLetterCase("Content-Type").pattern}\\s*:\\s*"),
            );

            if (n.length < 2) throw UnreadableException();

            formFieldName = n[1].replaceAll(RegExp("\"(.|\\s)*\$"), "");

            formFileName = fn.length < 2
                ? null
                : fn[1].replaceAll(RegExp("\"(.|\\s)*\$"), "");
            formContentType =
                m.length < 2 ? null : m[1].split(RegExp("((\r|)\n|\\s*;)"))[0];

            formHeaderBytes = [];

            state++;
          } else {
            formHeaderBytes.addAll([CR, LF, CR, byte]);
            state -= 3;
          }
          break;
        case 9:
          if (byte == CR) {
            state++;
          } else {
            formBodyBytes.add(byte);
          }
          break;
        case 10:
          if (byte == LF) {
            state++;
          } else {
            state--;
            formBodyBytes.addAll([CR, byte]);
          }
          break;
        case 11:
          if (byte == DASH) {
            state++;
          } else {
            state -= 2;
            formBodyBytes.addAll([CR, LF, byte]);
          }
          break;
        case 12:
          if (byte == DASH) {
            state++;
            readBoundaryAt = i + 1;
          } else {
            state -= 3;
            formBodyBytes.addAll([CR, LF, DASH, byte]);
          }
          break;
        case 13:
          if (byte != boundaryBytes[i - readBoundaryAt]) {
            state -= 4;
            formBodyBytes.addAll([CR, LF, DASH, DASH]);
            for (int c = readBoundaryAt; c <= i; c++) {
              formBodyBytes.add(byteList[c]);
            }
            break;
          }

          if (boundaryBytes.length - i + readBoundaryAt == 1) state++;
          break;
        case 14:
          if (byte == DASH) {
            state++;
          } else if (byte == CR) {
            state++;
            lineSeperatorDetected = true;
          }
          break;
        case 15:
          if (byte == DASH) {
            EOF = true;
          } else if (byte == LF && lineSeperatorDetected) {
            lineSeperatorDetected = false;
            state -= 10;
          } else {
            throw UnreadableException();
          }

          if (formContentType != null) {
            formDataFields.add(FileField(
              formFieldName!,
              Uint8List.fromList(formBodyBytes),
              formFileName ?? "",
              mimeType: formContentType,
            ));
          } else {
            formDataFields.add(NonFileField(
              formFieldName!,
              utf8.decode(formBodyBytes),
            ));
          }
          formFieldName = null;
          formFileName = null;
          formBodyBytes = [];
          formHeaderBytes = [];
          break;
      }

      if (EOF) break;
    }

    return formDataFields;
  });
  setJsonFunc(result, () async {
    String? contentType = getHeader(
      _bothLetterCase("Content-Type"),
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
