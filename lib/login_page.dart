import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'home_usuario_page.dart';
import 'home_academia_page.dart';
import 'home_profissional_page.dart';
import 'choose_login_type_page.dart';
import 'custom_widgets.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  final String userType;
  const LoginPage({super.key, required this.userType});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Widget _getHomePageByType({bool guestMode = false}) {
    switch (widget.userType) {
      case 'Usuário':
        return HomeUsuarioPage(guestMode: guestMode);
      case 'Academia':
        return const HomeAcademiaPage();
      case 'Profissional':
        return const HomeProfissionalPage();
      default:
        return HomeUsuarioPage(guestMode: guestMode);
    }
  }

  Future<void> _onLoginClick() async {
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não encontrado.')),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      final savedType = doc['userType'];
      if (savedType != widget.userType) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Este e-mail está cadastrado como "$savedType", não como "${widget.userType}".'),
        ));
        await FirebaseAuth.instance.signOut();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifique seu e-mail antes de fazer login.')),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _getHomePageByType()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erro ao fazer login')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user!;
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await userDoc.get();

      if (snapshot.exists) {
        final savedType = snapshot['userType'];
        if (savedType != widget.userType) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Esta conta Google já está cadastrada como "$savedType".'),
          ));
          await FirebaseAuth.instance.signOut();
          return;
        }
      } else {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? '',
          'userType': widget.userType,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _getHomePageByType()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no login com Google: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChooseLoginTypePage()),
    );
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterPage(userType: widget.userType)),
    );
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  void _continueAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _getHomePageByType(guestMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo_fundo.png', width: 300, height: 300),
                const SizedBox(height: 25),

                CustomRadiusTextfield(controller: _emailController, hintText: 'E-mail'),
                const SizedBox(height: 16),
                CustomRadiusTextfield(controller: _passwordController, hintText: 'Senha', obscureText: true),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _goToForgotPassword,
                    child: const Text('Esqueci a senha', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),

                _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : CustomRadiusButton(
                        onPressed: _onLoginClick,
                        text: 'Entrar como ${widget.userType}',
                      ),
                const SizedBox(height: 8),

                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white54)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('ou', style: TextStyle(color: Colors.white)),
                    ),
                    Expanded(child: Divider(color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 8),

                CustomRadiusButton(
                  onPressed: _onGoogleSignIn,
                  text: 'Entrar com Google',
                  expandedinWeb: true,
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                  icon: Image.asset('assets/google_logo.png', width: 20, height: 20),
                ),
                const SizedBox(height: 8),

                CustomRadiusButton(onPressed: _goToRegister, text: 'Registrar-se'),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: _continueAsGuest,
                  child: const Text(
                    'Continuar sem logar',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
