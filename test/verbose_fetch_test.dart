import 'package:flutter_test/flutter_test.dart';
import 'package:verbose_fetch/verbose_fetch.dart';

void main() {
  String url = 'https://popcat.click';
  test('Doing HTTP request on ', () {
    // Put the URL here.
    fetch(url);
  });
}
