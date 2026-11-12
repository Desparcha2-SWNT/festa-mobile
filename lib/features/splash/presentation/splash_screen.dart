import 'package:flutter/material.dart';

/// Pantalla de splash (Etiqueta 1 · Splash del Figma).
///
/// Se muestra mientras el router decide si el usuario ya tiene sesión.
/// No hace ninguna lógica: el router la reemplaza en cuanto el [sessionControllerProvider]
/// resuelve su estado inicial.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo de Festa (texto negro + corona rosa sobre fondo blanco)
              Image(image: AssetImage('assets/images/logo_festa.png'), width: 180, semanticLabel: 'Festa'),
              SizedBox(height: 24),
              Text(
                'Menos buscar, más vivir la ciudad.',
                style: TextStyle(fontSize: 15, color: Color(0xFF555555), letterSpacing: 0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
