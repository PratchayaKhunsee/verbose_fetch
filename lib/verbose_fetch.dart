library verbose_fetch;

export 'verbose_fetch/none.dart'
    if (dart.library.html) 'verbose_fetch/web.dart'
    if (dart.library.io) 'verbose_fetch/io.dart';

export 'verbose_fetch/_instance.dart'
    show
        FetchResponse,
        FormDataField,
        NonFileField,
        FileField,
        RequestBody,
        RequestIntergrity;
export 'verbose_fetch/_enum.dart';
