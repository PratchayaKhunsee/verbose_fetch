import 'package:flutter_test/flutter_test.dart';
import 'package:verbose_fetch/verbose_fetch.dart';

void main() {
  /// Put the URL here.
  String url = 'https://popcat.click';
  test('Doing HTTP request on "$url"', () {
    fetch(url);
  });
}
