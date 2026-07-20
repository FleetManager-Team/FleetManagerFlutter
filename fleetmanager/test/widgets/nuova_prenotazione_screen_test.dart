import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fleetmanager/models/enums/ruolo_utente.dart';
import 'package:fleetmanager/models/enums/stato_prenotazione.dart';
import 'package:fleetmanager/models/enums/stato_veicolo.dart';
import 'package:fleetmanager/models/enums/tipo_prenotazione.dart';
import 'package:fleetmanager/models/enums/tipo_veicolo.dart';
import 'package:fleetmanager/models/prenotazione.dart';
import 'package:fleetmanager/models/veicolo.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/provider/impostazioni_provider.dart';
import 'package:fleetmanager/ui/screens/prenotazioni/nuova_prenotazione_screen.dart';

import '_widget_test_helpers.dart';

Veicolo _veicolo({
  required String targa,
  String marca = 'Fiat',
  String modello = 'Panda',
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
    statoVeicolo: StatoVeicolo.disponibile,
    km: km,
  );
}

/// Una prenotazione che copre ampiamente la finestra "domani 09:00-18:00"
/// usata di default dalla schermata, cosi il veicolo risulta occupato
/// indipendentemente dai millisecondi esatti del test.
Prenotazione _prenotazioneOccupante(String targa) {
  final domani = DateTime.now().add(const Duration(days: 1));
  return Prenotazione(
    idPrenotazione: 1,
    idUtente: 99,
    targa: targa,
    dataInizio: DateTime(domani.year, domani.month, domani.day, 8, 0),
    dataFine: DateTime(domani.year, domani.month, domani.day, 19, 0),
    statoPrenotazione: StatoPrenotazione.confermata,
    tipoPrenotazione: TipoPrenotazione.utente,
  );
}

void main() {
  setUpAll(() {
    WidgetTestHarness.registerFallbacks();
  });

  testWidgets(
      'mostra solo i veicoli disponibili di default e rivela quelli occupati tramite lo switch',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.addAll([
      _veicolo(targa: 'AA111AA', marca: 'Fiat', modello: 'Panda'),
      _veicolo(
          targa: 'BB222BB',
          marca: 'Ford',
          modello: 'Transit',
          tipo: TipoVeicolo.furgone),
    ]);
    harness.provider.prenotazioni.add(_prenotazioneOccupante('BB222BB'));

    final impostazioni = await buildImpostazioniProvider();
    await tester.pumpWidget(wrapWithProviders(
        harness.provider, impostazioni, const NuovaPrenotazioneScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Fiat Panda'), findsOneWidget);
    expect(find.text('Ford Transit'), findsNothing);
    expect(find.text('LIBERO'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Ford Transit'), findsOneWidget);
    expect(find.text('OCCUPATO'), findsOneWidget);
  });

  testWidgets(
      'tap su un veicolo disponibile lo seleziona e abilita il bottone di conferma',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.add(_veicolo(targa: 'CC333CC', modello: '500'));

    final impostazioni = await buildImpostazioniProvider();
    await tester.pumpWidget(wrapWithProviders(
        harness.provider, impostazioni, const NuovaPrenotazioneScreen()));
    await tester.pumpAndSettle();

    final submitFinder = find.widgetWithText(
        ElevatedButton, 'INVIA RICHIESTA PRENOTAZIONE');

    ElevatedButton button = tester.widget(submitFinder);
    expect(button.onPressed, isNull,
        reason: 'nessun veicolo ancora selezionato');

    await tester.tap(find.text('Fiat 500'));
    await tester.pumpAndSettle();

    button = tester.widget(submitFinder);
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('Fiat 500 (CC333CC)'), findsOneWidget);
  });

  testWidgets(
      'la lista veicoli e scrollabile: si puo selezionare un veicolo scorrendo fino a renderlo visibile',
      (tester) async {
    final harness = WidgetTestHarness.create();
    harness.provider.veicoli.addAll(List.generate(
      20,
      (i) => _veicolo(targa: 'V$i', modello: 'Modello numero $i'),
    ));

    final impostazioni = await buildImpostazioniProvider();
    await tester.pumpWidget(wrapWithProviders(
        harness.provider, impostazioni, const NuovaPrenotazioneScreen()));
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

    await tester.tap(find.textContaining('Modello numero 19'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Modello numero 19 (V19)'), findsOneWidget);
  });

  testWidgets(
      'selezionando un veicolo e premendo invia la prenotazione viene creata',
      (tester) async {
    final harness = WidgetTestHarness.create();
    await harness.loginAs(RuoloUtente.driver, patente: 'B123456');
    harness.provider.veicoli.add(_veicolo(targa: 'DD444DD', modello: 'Doblo'));

    when(() => harness.prenotazioneService.creaPrenotazione(any()))
        .thenAnswer((_) async {});

    final impostazioni =
        await buildImpostazioniProvider(approvazioneRichiesta: true);

    await pumpPushedScreen(
      tester,
      screen: const NuovaPrenotazioneScreen(),
      providers: [
        ChangeNotifierProvider<FleetProvider>.value(value: harness.provider),
        ChangeNotifierProvider<ImpostazioniProvider>.value(
            value: impostazioni),
      ],
    );

    await tester.tap(find.text('Fiat Doblo'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(
        ElevatedButton, 'INVIA RICHIESTA PRENOTAZIONE'));
    await tester.pumpAndSettle();

    verify(() => harness.prenotazioneService.creaPrenotazione(any()))
        .called(1);
    expect(find.text('Richiesta inviata! In attesa di approvazione.'),
        findsOneWidget);
  });
}
