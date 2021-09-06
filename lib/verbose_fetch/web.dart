import 'dart:convert';
import 'dart:typed_data';

// import 'package:flutter/widgets.dart';
import 'package:js/js_util.dart';

import '_error.dart';
import '_enum.dart';
import '_instance.dart';
import 'js.dart' as js;

/// Create the request payload by a [RequestBody] instance for using in Javascript Web API.
dynamic _createBody(RequestBody body) {
  switch (body.type) {
    case RequestBodyType.formData:
      {
        if (body.content is! List<FormDataField>) {
          throw InvalidPayloadException();
        }

        var formData = js.createFormData();

        for (var e in (body.content as List<FormDataField>)) {
          if (e is FileField) {
            Uint8List byteList = e.value;
            var byteArray = js.createArray(byteList);

            var bytes = js.createUint8ArrayFrom(byteArray);

            var array = js.createArray([bytes]);
            var options = newObject();
            if (e.mimeType != null) {
              setProperty(options, 'type', e.mimeType);
            }
            setProperty(options, 'filename', e.fileName);

            final blob = js.createBlob(array, options);

            js.appendFormDataField(formData, e.name, blob, e.fileName);
          } else {
            js.appendFormDataField(formData, e.name, e.value);
          }
        }

        return formData;
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
  dynamic _body = method == RequestMethod.get || method == RequestMethod.head
      ? null
      : _createBody(body!);

  var _headers = js.createHeaders();
  if (headers != null) {
    headers.forEach((name, value) {
      js.setHeaders(_headers, name, value);
    });
  }

  if (body?.type == RequestBodyType.json) {
    js.setHeaders(_headers, 'Content-Type', 'application/json');
  }

  Map<String, dynamic> initMap = {
    'keepalive': keepAlive,
    'method': <RequestMethod, String>{
      RequestMethod.get: 'GET',
      RequestMethod.post: 'POST',
      RequestMethod.put: 'PUT',
      RequestMethod.delete: 'DELETE',
      RequestMethod.head: 'HEAD',
    }[method],
    'mode': <RequestMode, String>{
      RequestMode.cors: 'cors',
      RequestMode.noCors: 'no-cors',
      RequestMode.navigate: 'navigate',
      RequestMode.sameOrigin: 'same-origin',
    }[mode],
    'referrer': referrer,
    'referrerPolicy': <RequestReferrerPolicy, String>{
      RequestReferrerPolicy.noReferrer: 'no-referrer',
      RequestReferrerPolicy.noReferrerWhenDowngrade:
          'no-referrer-when-downgrade',
      RequestReferrerPolicy.origin: 'origin',
      RequestReferrerPolicy.originWhenCrossOrigin: 'origin-when-cross-origin',
      RequestReferrerPolicy.sameOrigin: 'same-origin',
      RequestReferrerPolicy.strictOrigin: 'strict-origin',
      RequestReferrerPolicy.strictOriginWhenCrossOrigin:
          'strict-origin-when-cross-origin',
      RequestReferrerPolicy.unsafeUrl: 'unsafe-url',
    }[referrerPolicy],
    'cache': <RequestCacheMode, String>{
      RequestCacheMode.normal: 'dafault',
      RequestCacheMode.forceCache: 'force-cache',
      RequestCacheMode.noCache: 'no-cache',
      RequestCacheMode.onlyIfCached: 'only-if-cache',
      RequestCacheMode.noStore: 'no-store',
      RequestCacheMode.reload: 'reload',
    }[cacheMode],
    'credentials': <RequestCredentials, String>{
      RequestCredentials.sameOrigin: 'same-origin',
      RequestCredentials.include: 'include',
      RequestCredentials.omit: 'omit',
    }[credentials],
    'redirect': <RequestRedirectMode, String>{
      RequestRedirectMode.follow: 'follow',
      RequestRedirectMode.manual: 'manual',
      RequestRedirectMode.error: 'error',
    }[redirect],
    'intergrity': intergrity?.text(),
    'headers': _headers,
    'body': _body,
  };

  var init = newObject();
  initMap.forEach((name, value) {
    if (value != null) setProperty(init, name, value);
  });

  var _response =
      await promiseToFuture(js.callFetch(js.createRequest(url, init)));

  FetchResponse result = FetchResponse();
  setTextFunc(result, () async {
    return await promiseToFuture(callMethod(_response, 'text', []));
  });
  setFormDataFunc(result, () async {
    List<FormDataField> fields = [];
    var jsFormData = await promiseToFuture(
      callMethod(_response, 'formData', []),
    );

    var entries = callMethod(jsFormData, 'entries', []);
    var entry = callMethod(entries, 'next', []);
    while (getProperty(entry, 'done') == false) {
      var x = getProperty(entry, 'value');
      var name = getProperty(x, 0);
      var value = getProperty(x, 1);

      if (!(value is String ||
              value is num ||
              value is bool ||
              value == null) &&
          hasProperty(value, 'arrayBuffer')) {
        var arrayBuffer = await promiseToFuture(
          callMethod(value, 'arrayBuffer', []),
        );

        var uint8Array = js.createUint8Array(arrayBuffer);
        String fileName = getProperty(value, 'name') ?? '';
        String? mime = getProperty(value, 'type');
        int length = getProperty(arrayBuffer, 'byteLength') ?? 0;

        List<int> list = [];
        for (int i = 0; i < length; i++) {
          list.add(getProperty(uint8Array, i));
        }

        fields.add(FileField(
          name,
          Uint8List.fromList(list),
          fileName,
          mimeType: mime,
        ));
      } else {
        fields.add(NonFileField(name, value));
      }

      entry = callMethod(entries, 'next', []);
    }

    return fields;
  });
  setJsonFunc(result, () async {
    dynamic determineValue(
      v,
      List<dynamic> Function(dynamic v) arrayToList,
      Map<String, dynamic> Function(dynamic v) objectToMap,
    ) {
      return v is num || v is String || v is bool || v == null
          ? v
          : (js.isArray(v)
              ? arrayToList(v)
                  .map((_) => determineValue(_, arrayToList, objectToMap))
                  .toList()
              : objectToMap(v));
    }

    List jsArrayToList(arr) {
      List list = [];
      var a = js.createArrayFrom(arr);
      while (js.getLength(a) > 0) {
        list.add(js.removeFirstFromArray(a));
      }

      return list;
    }

    Map<String, dynamic> jsObjectToMap(obj) {
      var entries = js.getObjectEntryIterator(obj);
      Map<String, dynamic> m = {};

      var kV = js.removeFirstFromArray(entries);
      while (kV != null) {
        var key = getProperty(kV, 0);
        var value = getProperty(kV, 1);
        m["$key"] = determineValue(value, jsArrayToList, jsObjectToMap);
        kV = js.removeFirstFromArray(entries);
      }
      return m;
    }

    dynamic jsObjectToValue(obj) {
      if (js.isArray(obj)) {
        return jsArrayToList(obj)
            .map((v) => determineValue(v, jsArrayToList, jsObjectToMap))
            .toList();
      }

      return determineValue(obj, jsArrayToList, jsObjectToMap);
    }

    var json = await promiseToFuture(callMethod(_response, 'json', []));
    if (json == null) return null;
    return jsObjectToValue(json);
  });
  setHeadersFunc(result, () {
    Map<String, String> headers = {};
    var jsHeaders = getProperty(_response, 'headers');
    if (jsHeaders != null) {
      var entries = callMethod(jsHeaders, 'entries', []);
      var instance = callMethod(entries, 'next', []);
      while (getProperty(instance, 'done') == false) {
        var x = getProperty(instance, 'value');
        var name = getProperty(x, 0);
        var value = getProperty(x, 1);

        headers[name] = value;

        instance = callMethod(entries, 'next', []);
      }
    }
    return headers;
  });
  setStatusFunc(result, () => getProperty(_response, 'status'));

  return result;
}
