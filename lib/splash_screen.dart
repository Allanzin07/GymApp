import 'dart:async';
import 'package:flutter/material.dart';
import 'choose_login_type_page.dart'; // Mantido, garantindo a funcionalidade

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador da animação
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Animação de fade (0 → 1)
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Inicia a animação de fade logo que o app abre
    _fadeController.forward();

    // Timer para transição de página após 3 segundos (FUNCIONALIDADE PRESERVADA)
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        _createFadeRoute(const ChooseLoginTypePage()),
      );
    });
  }

  // Função para criar a rota com efeito de fade (FUNCIONALIDADE PRESERVADA)
  Route _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 1000),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: _fadeAnimation,
          // Adiciona um Container para aplicar o Gradiente
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                // Gradiente do vermelho (topo) para o branco (base)
                colors: [Color(0xFFC62828), Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
            // Imagem Centralizada
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: Image.asset(
                'assets/logo_nome_fundo.png', // O nome do arquivo da imagem
                fit: BoxFit.contain,
                // Define uma largura máxima de 70% da tela para a imagem
                width: MediaQuery.of(context).size.width * 0.7, 
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}