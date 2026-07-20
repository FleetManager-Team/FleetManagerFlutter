import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/ui/screens/veicoli/lista_veicoli_screen.dart';

import '_widget_test_helpers.dart';

Veicolo _veicolo({
  required String targa,
  required String marca,
  required String modello,
  StatoVeicolo stato = StatoVeicolo.disponibile,
  TipoVeicolo tipo = TipoVeicolo.auto,
  int km = 1000,
  int anno = 2022,
}) {
  return Veicolo(
    targa: targa,
    tipoVeicolo: tipo,
    marca: marca,
    modello: modello,
    annoImmatricolazione: anno,
    statoVeicolo: stato,
    km: km,
  );
}

void main() {
  setUpAll(() {
    WidgetTestHarness.registerFallbacks();
  });

  testWidgets(
      'mostra i veicoli caricati con etichette targa e stato correttamente renderizzate',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.addAll([
      _veicolo(targa: 'AA111AA', marca: 'Fiat', modello: 'Panda'),
      _veicolo(
        targa: 'BB222BB',
        marca: 'Iveco',
        modello: 'Daily',
        tipo: TipoVeicolo.furgone,
        stato: StatoVeicolo.inManutenzione,
      ),
    ]);

    await tester.pumpWidget(
        wrapWithFleetProvider(harness.provider, const VehicleListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Parco Veicoli'), findsOneWidget);
    expect(find.text('Fiat Panda'), findsOneWidget);
    expect(find.text('Iveco Daily'), findsOneWidget);
    expect(find.textContaining('Targa: AA111AA'), findsOneWidget);
    expect(find.text('INMANUTENZIONE'), findsOneWidget);
  });

  testWidgets('tap su un chip filtro mostra solo i veicoli con quello stato',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.addAll([
      _veicolo(
          targa: 'AA111AA',
          marca: 'Fiat',
          modello: 'Panda',
          stato: StatoVeicolo.disponibile),
      _veicolo(
          targa: 'BB222BB',
          marca: 'Iveco',
          modello: 'Daily',
          stato: StatoVeicolo.inManutenzione),
    ]);

    await tester.pumpWidget(
        wrapWithFleetProvider(harness.provider, const VehicleListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Fiat Panda'), findsOneWidget);
    expect(find.text('Iveco Daily'), findsOneWidget);

    await tester.tap(find.text('IN SERVICE'));
    await tester.pumpAndSettle();

    expect(find.text('Fiat Panda'), findsNothing);
    expect(find.text('Iveco Daily'), findsOneWidget);
  });

  testWidgets('tap su un veicolo apre il popup con i dettagli corretti',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.add(_veicolo(
      targa: 'CC333CC',
      marca: 'Fiat',
      modello: '500',
      km: 5000,
      anno: 2021,
    ));

    await tester.pumpWidget(
        wrapWithFleetProvider(harness.provider, const VehicleListScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fiat 500'));
    await tester.pumpAndSettle();

    expect(find.text('CC333CC'), findsOneWidget);
    expect(find.text('5000 km'), findsOneWidget);
    expect(find.text('Nessuna prenotazione futura.'), findsOneWidget);
  });

  testWidgets(
      'la lista veicoli e scrollabile: elementi fuori schermo diventano visibili scorrendo',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.addAll(List.generate(
      20,
      (i) => _veicolo(
          targa: 'TARGA$i', marca: 'Marca', modello: 'Modello numero $i'),
    ));

    await tester.pumpWidget(
        wrapWithFleetProvider(harness.provider, const VehicleListScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Modello numero 19'), findsNothing);

    final listaPrincipale = find.descendant(
      of: find.byType(Expanded),
      matching: find.byType(ListView),
    );

    await tester.dragUntilVisible(
      find.textContaining('Modello numero 19'),
      listaPrincipale,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Modello numero 19'), findsOneWidget);
  });

  testWidgets(
      'un manager puo aggiungere un veicolo inserendo testo nel form e salvando',
      (tester) async {
    final harness = WidgetTestHarness.create();
    await harness.loginAs(RuoloUtente.manager);

    await tester.pumpWidget(
        wrapWithFleetProvider(harness.provider, const VehicleListScreen()));
    await tester.pumpAndSettle();

    // Il FAB "+" e' visibile solo per il manager
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Targa'), 'zz999zz');
    await tester.enterText(
        find.widgetWithText(TextField, 'Marca'), 'Toyota');
    await tester.enterText(
        find.widgetWithText(TextField, 'Modello'), 'Yaris');

    await tester.tap(find.text('SALVA VEICOLO'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => harness.queryBuilder.insert(captureAny())).captured;
    final insertedMap = captured.single as Map<String, dynamic>;

    expect(insertedMap['targa'], 'ZZ999ZZ');
    expect(insertedMap['marca'], 'Toyota');
    expect(insertedMap['modello'], 'Yaris');
    expect(insertedMap['stato'], 'disponibile');
    expect(find.text('Veicolo aggiunto con successo!'), findsOneWidget);
  });
}
