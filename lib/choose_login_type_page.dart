import 'package:flutter/material.dart';
import 'package:gym_app/login_page.dart';
import 'custom_widgets.dart'; // seus botões e campos customizados

class ChooseLoginTypePage extends StatelessWidget {
  const ChooseLoginTypePage({super.key});

  void _navigateToLogin(BuildContext context, String userType) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, animation, __) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: LoginPage(userType: userType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo_fundo.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'Selecione o tipo de login',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CustomRadiusButton(
                    onPressed: () => _navigateToLogin(context, 'Usuário'),
                    text: 'Logar como Usuário',
                    expandedinWeb: true,
                  ),
                  const SizedBox(height: 16),
                  CustomRadiusButton(
                    onPressed: () => _navigateToLogin(context, 'Academia'),
                    text: 'Logar como Academia',
                    expandedinWeb: true,
                  ),
                  const SizedBox(height: 16),
                  CustomRadiusButton(
                    onPressed: () => _navigateToLogin(context, 'Profissional'),
                    text: 'Logar como Profissional',
                    expandedinWeb: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
