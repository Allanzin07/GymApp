// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'custom_widgets.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final String userType;
  const RegisterPage({super.key, required this.userType});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _cpfCnpjController = TextEditingController();

  File? _profileImage;
  bool _loading = false;

  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _cnpjMask = MaskTextInputFormatter(
      mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  MaskTextInputFormatter getDynamicMask(String value) {
    final numbers = value.replaceAll(RegExp(r'\D'), '');
    return numbers.length > 11 ? _cnpjMask : _cpfMask;
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  bool _validateCpfCnpj(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 || digits.length == 14;
  }

  // SUPABASE UPLOAD — PASTA FIXA
  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return null;

    final path = 'users/$uid/perfil.jpg';

    try {
      final bytes = await _profileImage!.readAsBytes();

      final response = await _supabase.storage.from('uploads').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      if (response.isEmpty) return null;

      return _supabase.storage.from('uploads').getPublicUrl(path);
    } catch (e) {
      debugPrint("Erro upload supabase: $e");
      return null;
    }
  }

  // REGISTRO
  Future<void> _onRegisterPressed() async {
    if (!_validateCpfCnpj(_cpfCnpjController.text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CPF/CNPJ inválido')));
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senhas não coincidem')));
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();

      // Checar e-mail já existente
      final existingQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final type = existingQuery.docs.first['userType'];
        if (type != widget.userType) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Este e-mail já pertence a uma conta "$type". Use outro.')),
          );
          setState(() => _loading = false);
          return;
        }
      }

      // Criar usuário Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // UPLOAD SUPABASE
      final fotoUrl = await _uploadProfileImage(uid);

      // SALVAR EM USERS (sempre)
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': email,
        'cpfCnpj': _cpfCnpjController.text.trim(),
        'userType': widget.userType,
        'fotoPerfilUrl': fotoUrl ?? '',
        'descricao': '',
        'localizacao': '',
        'whatsapp': '',
        'link': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // SALVAR EM COLEÇÃO ESPECÍFICA
      if (widget.userType == 'Academia') {
        await _firestore.collection('academias').doc(uid).set({
          'nome': _nameController.text.trim(),
          'email': email,
          'fotoPerfilUrl': fotoUrl ?? '',
          'capaUrl': '',
          'descricao': '',
          'localizacao': '',
          'whatsapp': '',
          'link': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (widget.userType == 'Profissional') {
        await _firestore.collection('professionals').doc(uid).set({
          'nome': _nameController.text.trim(),
          'email': email,
          'fotoUrl': fotoUrl ?? '',
          'especialidade': '',
          'descricao': '',
          'localizacao': '',
          'whatsapp': '',
          'link': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _auth.currentUser!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada! Verifique seu e-mail.')),
      );

      await _auth.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => LoginPage(userType: widget.userType)),
      );
    } catch (e) {
      debugPrint("Erro register: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Criar Conta - ${widget.userType}'),
          backgroundColor: Colors.red,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.red.shade100,
                  backgroundImage:
                      _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.camera_alt,
                          size: 40, color: Colors.red.shade700)
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              CustomRadiusTextfield(
                controller: _nameController,
                hintText: 'Nome completo',
                focusNode: FocusNode(),
              ),
              const SizedBox(height: 16),

              CustomRadiusTextfield(
                controller: _emailController,
                hintText: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                focusNode: FocusNode(),
              ),
              const SizedBox(height: 16),

              CustomRadiusTextfield(
                controller: _passwordController,
                hintText: 'Senha',
                obscureText: true,
                focusNode: FocusNode(),
              ),
              const SizedBox(height: 16),

              CustomRadiusTextfield(
                controller: _confirmPasswordController,
                hintText: 'Confirmar senha',
                obscureText: true,
                focusNode: FocusNode(),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _cpfCnpjController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final mask = getDynamicMask(newValue.text);
                    return mask.formatEditUpdate(oldValue, newValue);
                  }),
                ],
                decoration: InputDecoration(
                  hintText: 'CPF ou CNPJ',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 32),

              _loading
                  ? const CircularProgressIndicator(color: Colors.red)
                  : CustomRadiusButton(
                      onPressed: _onRegisterPressed,
                      text: 'Cadastrar',
                    ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Voltar para o login',
                  style: TextStyle(color: Colors.red.shade700),
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