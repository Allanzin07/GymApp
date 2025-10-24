import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Homes
import 'package:gym_app/home_usuario_page.dart';
import 'package:gym_app/home_academia_page.dart';
import 'package:gym_app/home_profissional_page.dart';

// Extras
import 'package:gym_app/register_page.dart';
import 'package:gym_app/choose_login_type_page.dart';
import 'custom_widgets.dart';

class LoginPage extends StatefulWidget {
  final String userType;

  const LoginPage({super.key, required this.userType});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Widget _getHomePageByType() {
    switch (widget.userType) {
      case 'Usuário':
        return const HomeUsuarioPage();
      case 'Academia':
        return const HomeAcademiaPage();
      case 'Profissional':
        return const HomeProfissionalPage();
      default:
        return const HomeUsuarioPage();
    }
  }

  Future<void> _onLoginClick() async {
    setState(() => _loading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("E-mail não verificado. Um link foi enviado."),
          ),
        );
        FirebaseAuth.instance.signOut();
      } else {
        final nextPage = _getHomePageByType();
        _navigateWithSlideTransition(nextPage);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erro ao fazer login";
      if (e.code == 'user-not-found')
        message = "Usuário não encontrado.";
      else if (e.code == 'wrong-password') message = "Senha incorreta.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _loading = false);
          return;
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final nextPage = _getHomePageByType();
      _navigateWithSlideTransition(nextPage);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao autenticar com o Google: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onRegisterClick() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  void _onForgetPasswordClick() {
    if (_emailController.text.isNotEmpty) {
      FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-mail de recuperação enviado.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe seu e-mail.")),
      );
    }
  }

  void _navigateWithSlideTransition(Widget page) {
    Navigator.pushReplacement(
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
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove o backgroundColor do Scaffold
      // backgroundColor: Colors.white, 
      body: Container( // Adiciona o Container para o gradiente
        decoration: const BoxDecoration(
          // Gradiente copiado da ChooseLoginTypePage
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
                  CustomRadiusTextfield(
                    focusNode: _emailFocus,
                    onEditingComplete: () => _passwordFocus.requestFocus(),
                    controller: _emailController,
                    hintText: 'E-mail',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CustomRadiusTextfield(
                    focusNode: _passwordFocus,
                    controller: _passwordController,
                    hintText: 'Senha',
                    onEditingComplete: _onLoginClick,
                    maxLines: 1,
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                  ),
                  InkWell(
                    splashColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    onTap: _onForgetPasswordClick,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Esqueci minha senha?',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _loading
                      ? const CircularProgressIndicator(color: Colors.red)
                      : CustomRadiusButton(
                          onPressed: _onLoginClick,
                          text: 'Entrar como ${widget.userType}',
                          expandedinWeb: true,
                        ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.red)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('ou',
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                      const Expanded(child: Divider(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CustomRadiusButton(
                    onPressed: _onGoogleSignIn,
                    text: 'Entrar com Google',
                    expandedinWeb: true,
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                    icon: Image.asset('assets/google_logo.png',
                        width: 20, height: 20),
                  ),
                  const SizedBox(height: 8),
                  CustomRadiusButton(
                    onPressed: _onRegisterClick,
                    text: 'Registrar-se',
                    expandedinWeb: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HomeUsuarioPage()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Continuar sem Logar',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
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