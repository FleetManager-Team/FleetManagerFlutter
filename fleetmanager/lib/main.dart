import 'package:fleetmanager/services/veicolo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;
import 'package:fleetmanager/ui/screens/login_screen.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';

void main() async {
  // Necessario per inizializzazioni asincrone prima di runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Supabase con le tue credenziali reali
  await Supabase.initialize(
    url: 'https://zkmolzwrnuglwbogsrjv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprbW9sendybnVnbHdib2dzcmp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwMTgzNDYsImV4cCI6MjA4OTU5NDM0Nn0.DtQ3ENR2QJsE8Jo0Sg-GJ1nMBMoEUhbztFPQiN5q_m0',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FleetProvider()),
        Provider(create: (_) => VeicoloService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fleet Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue[900]!),
        useMaterial3: true,
      ),
      locale: const Locale('it', 'IT'),
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainEntryWrapper(),
    );
  }
}

class MainEntryWrapper extends StatefulWidget {
  const MainEntryWrapper({super.key});

  @override
  State<MainEntryWrapper> createState() => _MainEntryWrapperState();
}

class _MainEntryWrapperState extends State<MainEntryWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Solo se c'è già una sessione attiva carichiamo i dati
      if (Supabase.instance.client.auth.currentSession != null) {
        context.read<FleetProvider>().inizializzaDati();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
