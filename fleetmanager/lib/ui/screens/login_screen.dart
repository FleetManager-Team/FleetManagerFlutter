import 'package:fleetmanager/ui/screens/dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;

        debugPrint("SUPABASE EVENT: $event");

        if (event == AuthChangeEvent.passwordRecovery ||
            event == AuthChangeEvent.signedIn && _isRecoveryUrl()) {
          _mostraDialogNuovaPassword();
        }
      });
    });
  }

  bool _isRecoveryUrl() {
    final Uri uri = Uri.base;
    // Controlla sia l'URL standard che la parte dopo il cancelletto (#)
    final bool hasRecoveryType = uri.toString().contains('type=recovery') ||
        uri.fragment.contains('type=recovery');
    final bool hasAccessToken = uri.fragment.contains('access_token=');

    return hasRecoveryType || hasAccessToken;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<FleetProvider>();

      try {
        // 1. Esegui il login su Supabase
        final success = await provider.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (success) {
          // 2. Carica i dati dal database prima di entrare
          await provider.inizializzaDati();

          if (mounted) {
            // 3. Navigazione alla dashboard con la tua animazione originale
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomeScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          }
        } else {
          // 4. Gestione errore credenziali
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Email o password errati'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      } catch (e) {
        // 5. Gestione errori di rete/connessione
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore di connessione: $e'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _mostraDialogRecupero(BuildContext context) {
    final TextEditingController _recoveryEmailController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Recupero Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Inserisci la tua email per ricevere il link di reset."),
            const SizedBox(height: 15),
            TextField(
              controller: _recoveryEmailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () async {
              final email = _recoveryEmailController.text.trim();
              if (email.isNotEmpty) {
                // NUOVO CODICE
                final success =
                    await context.read<FleetProvider>().recuperaPassword(
                          email,
                          // Prende l'indirizzo attuale (localhost, github o dominio finale) in automatico
                          redirectTo: kIsWeb
                              ? Uri.base.origin + Uri.base.path
                              : "io.supabase.flutter://reset-callback/",
                        );
                Navigator.pop(context); // Chiude il dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? "Email di reset inviata! Controlla la tua posta."
                        : "Errore: verifica l'email inserita."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text("Invia"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<FleetProvider>().isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo/Icona
                            Icon(
                              Icons.directions_car,
                              size: 80,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fleet Manager',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Accedi al tuo account',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Campo Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Inserisci la tua email',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci l\'email';
                                }
                                if (value == 'a' || value == 'b') {
                                  return null;
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                                  return 'Email non valida';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Campo Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Inserisci la password',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci la password';
                                }
                                if ((value == 'a' || value == 'b') &&
                                    (_emailController.text == 'a' ||
                                        _emailController.text == 'b')) {
                                  return null;
                                }
                                if (value.length < 6) {
                                  return 'Password troppo corta';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Pulsante Login
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Accedi',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => _mostraDialogRecupero(
                                  context), // <--- Cambia qui
                              child: Text(
                                'Password dimenticata?',
                                style:
                                    TextStyle(color: theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostraDialogNuovaPassword() {
    final _formKeyReset = GlobalKey<FormState>();
    final _passController = TextEditingController();
    final _confirmPassController = TextEditingController();
    bool _obscureText = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(Icons.security_rounded,
                  size: 50, color: Theme.of(context).primaryColor),
              const SizedBox(height: 10),
              const Text("Metti in sicurezza l'account",
                  textAlign: TextAlign.center),
            ],
          ),
          content: Form(
            key: _formKeyReset,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scegli una password forte che non hai usato in precedenza.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Nuova Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "Inserisci la password";
                      if (value.length < 6) return "Minimo 6 caratteri";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPassController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: "Conferma Password",
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value != _passController.text)
                        return "Le password non coincidono";
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (_formKeyReset.currentState!.validate()) {
                  try {
                    final success = await context
                        .read<FleetProvider>()
                        .aggiornaPassword(_passController.text);
                    if (success && mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("✅ Password aggiornata! Ora puoi accedere."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    String erroreMessaggio = "Errore durante l'aggiornamento";
                    if (e.toString().contains("same as the old one")) {
                      erroreMessaggio =
                          "La nuova password non può essere uguale alla vecchia!";
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(erroreMessaggio),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text("AGGIORNA PASSWORD"),
            ),
          ],
        ),
      ),
    );
  }
}
