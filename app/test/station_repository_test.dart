import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/stations/station_repository.dart';

void main() {
  test('parses station rows and trims names', () {
    final stations = parseStations(
      '[{"id":"00102","name":" 망원역 1번출구 앞","gu":"마포구","lat":37.5,"lon":126.9}]',
    );

    expect(stations.single.id, '00102');
    expect(stations.single.name, '망원역 1번출구 앞');
    expect(stations.single.district, '마포구');
    expect(stations.single.latitude, 37.5);
    expect(stations.single.longitude, 126.9);
  });

  test('rejects a station payload that is not a list', () {
    expect(() => parseStations('{}'), throwsFormatException);
  });

  test('reads stations from the injected asset bundle', () async {
    final repository = BundledStationRepository(
      bundle: _MemoryBundle({
        stationsAssetPath:
            '[{"id":"02720","name":"힐스테이트에코","gu":"강남구","lat":37.1,"lon":127.1}]',
      }),
    );

    final stations = await repository.fetch();

    expect(stations.single.id, '02720');
    expect(stations.single.district, '강남구');
  });

  test('loads the bundled station list without the network', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final stations = await BundledStationRepository().fetch();

    expect(stations, hasLength(2789));
    expect(
      stations.firstWhere((station) => station.id == '00102').district,
      '마포구',
    );
  });
}

class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw Exception('missing asset $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
