import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fleetmanager/provider/fleet_provider.dart';
import 'package:fleetmanager/ui/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final fleetProvider = Provider.of<FleetProvider>(context, listen: false);

    // Chiamiamo il metodo login del provider
    final bool success = await fleetProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Se fallisce, mostriamo un errore (Logica ripresa da GestoreLoginImpl)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email o password errati")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<FleetProvider>().isLoading;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Fleet Manager Pro",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 30),
            isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text("Accedi"),
                ),
          ],
        ),
      ),
    );
  }
}