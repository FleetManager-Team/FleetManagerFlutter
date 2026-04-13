import 'package:flutter_test/flutter_test.dart';

import 'package:fleetmanager/services/veicolo_service.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';

import '_service_test_helpers.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockSupabaseQueryBuilder mockQueryBuilder;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();

    when(() => mockSupabase.from(any()))
        .thenAnswer((_) => mockQueryBuilder);
  });

  VeicoloService build() => VeicoloService(supabaseClient: mockSupabase);

  test('fetchAllVeicoli ritorna lista', () async {
    final list = [
      {
        'targa': 'AA111AA',
        'tipo': 'auto',
        'marca': 'Fiat',
        'modello': 'Panda',
        'anno_immatricolazione': 2020,
        'stato': 'disponibile',
        'km': 100,
      }
    ];
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<List<dynamic>>(list));

    final service = build();
    final res = await service.fetchAllVeicoli();

    expect(res.length, 1);
    expect(res.first.targa, 'AA111AA');
  });

  test('updateStatoVeicolo aggiorna stato', () async {
    when(() => mockQueryBuilder.update(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.updateStatoVeicolo('AA111AA', StatoVeicolo.prenotato);

    verify(() => mockQueryBuilder.update({'stato': 'prenotato'})).called(1);
  });

  test('createVeicolo inserisce record', () async {
    when(() => mockQueryBuilder.insert(any()))
        .thenAnswer((_) => futureBuilder<void>(null));

    final service = build();
    await service.createVeicolo(Veicolo(
      targa: 'BB222BB',
      tipoVeicolo: TipoVeicolo.auto,
      marca: 'Ford',
      modello: 'Focus',
      annoImmatricolazione: 2021,
      statoVeicolo: StatoVeicolo.disponibile,
      km: 200,
    ));

    verify(() => mockQueryBuilder.insert(any())).called(1);
  });

  test('getVeicoloByTarga ritorna veicolo se trovato', () async {
    final json = {
      'targa': 'CC333CC',
      'tipo': 'auto',
      'marca': 'Tesla',
      'modello': '3',
      'anno_immatricolazione': 2022,
      'stato': 'disponibile',
      'km': 10,
    };
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<Map<String, dynamic>?>(json));

    final service = build();
    final res = await service.getVeicoloByTarga('cc333cc');

    expect(res, isNotNull);
    expect(res!.targa, 'CC333CC');
  });

  test('getVeicoloByTarga ritorna null se non trovato', () async {
    when(() => mockQueryBuilder.select())
        .thenAnswer((_) => futureBuilder<Map<String, dynamic>?>(null));

    final service = build();
    final res = await service.getVeicoloByTarga('xx');

    expect(res, isNull);
  });

  test('getVeicoloByTarga ritorna null su eccezione', () async {
    when(() => mockQueryBuilder.select())
        .thenThrow(Exception('fail'));

    final service = build();
    final res = await service.getVeicoloByTarga('xx');

    expect(res, isNull);
  });
}
