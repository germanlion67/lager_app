// test/services/connectivity_service_test.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/services/connectivity_service.dart';

// Hilfsfunktionen — geben direkt Future zurück, kein IOOverrides nötig
DnsLookup _successLookup() =>
    (_) async => [InternetAddress('8.8.8.8')];

DnsLookup _emptyLookup() =>
    (_) async => [];

DnsLookup _socketExceptionLookup() =>
    (_) async => throw const SocketException('no network');

DnsLookup _timeoutLookup() =>
    (_) async => throw TimeoutException('timeout');

DnsLookup _unknownExceptionLookup() =>
    (_) async => throw Exception('unknown');

void main() {
  // Nach jedem Test Override zurücksetzen
  tearDown(() => ConnectivityService.dnsLookupOverride = null);

  group('ConnectivityService — _tcpCheck (Linux-Zweig)', () {
    test('isConnected() → true wenn Lookup eine Adresse zurückgibt', () async {
      ConnectivityService.dnsLookupOverride = _successLookup();
      expect(await ConnectivityService.isConnected(), isTrue);
    });

    test('isConnected() → false wenn Lookup leere Liste zurückgibt', () async {
      ConnectivityService.dnsLookupOverride = _emptyLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
    });

    test('isConnected() → false bei SocketException', () async {
      ConnectivityService.dnsLookupOverride = _socketExceptionLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
    });

    test('isConnected() → false bei Timeout', () async {
      ConnectivityService.dnsLookupOverride = _timeoutLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
    });

    test('isConnected() → false bei unbekannter Exception', () async {
      ConnectivityService.dnsLookupOverride = _unknownExceptionLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
    });
  });

  group('ConnectivityService — isWifi() Linux-Zweig', () {
    test('isWifi() → true wenn Lookup eine Adresse zurückgibt', () async {
      ConnectivityService.dnsLookupOverride = _successLookup();
      expect(await ConnectivityService.isWifi(), isTrue);
    });

    test('isWifi() → false bei SocketException', () async {
      ConnectivityService.dnsLookupOverride = _socketExceptionLookup();
      expect(await ConnectivityService.isWifi(), isFalse);
    });

    test('isWifi() → false bei Timeout', () async {
      ConnectivityService.dnsLookupOverride = _timeoutLookup();
      expect(await ConnectivityService.isWifi(), isFalse);
    });

    test('isWifi() → false bei unbekannter Exception', () async {
      ConnectivityService.dnsLookupOverride = _unknownExceptionLookup();
      expect(await ConnectivityService.isWifi(), isFalse);
    });

    test('isWifi() → false wenn Lookup leere Liste zurückgibt', () async {
      ConnectivityService.dnsLookupOverride = _emptyLookup();
      expect(await ConnectivityService.isWifi(), isFalse);
    });
  });

  group('ConnectivityService — Konsistenz isConnected / isWifi', () {
    test('beide geben true zurück wenn Netz vorhanden', () async {
      ConnectivityService.dnsLookupOverride = _successLookup();
      expect(await ConnectivityService.isConnected(), isTrue);
      expect(await ConnectivityService.isWifi(), isTrue);
    });

    test('beide geben false zurück bei SocketException', () async {
      ConnectivityService.dnsLookupOverride = _socketExceptionLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
      expect(await ConnectivityService.isWifi(), isFalse);
    });
  });

  group('ConnectivityService — Timeout-Verhalten', () {
    test('isConnected() schlägt nach AppConfig-Timeout fehl (nicht hängen)',
        () async {
      ConnectivityService.dnsLookupOverride = _timeoutLookup();
      expect(await ConnectivityService.isConnected(), isFalse);
    });

    test('isWifi() schlägt nach AppConfig-Timeout fehl (nicht hängen)',
        () async {
      ConnectivityService.dnsLookupOverride = _timeoutLookup();
      expect(await ConnectivityService.isWifi(), isFalse);
    });
  });
}