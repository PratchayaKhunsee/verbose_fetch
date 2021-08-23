import 'package:flutter_test/flutter_test.dart';
import 'package:verbose_fetch/verbose_fetch.dart';

void main() {
  test('Doing HTTP request', () {
    // Put the URL here.
    fetch('https://dart-simple-fetch-test-ws.herokuapps.com/');
  });
}
