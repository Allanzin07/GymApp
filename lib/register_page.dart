import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 Import do Storage
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'custom_widgets.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  final String userType; // 'Usuário', 'Academia' ou 'Profissional'
  const RegisterPage({super.key, required this.userType});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _cpfCnpjController = TextEditingController();

  File? _profileImage;
  bool _loading = false;

  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _cnpjMask = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  MaskTextInputFormatter getDynamicMask(String value) {
    String numbers = value.replaceAll(RegExp(r'\D'), '');
    return numbers.length > 11 ? _cnpjMask : _cpfMask;
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  bool _validateCpfCnpj(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 || digits.length == 14;
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return null;

    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(_profileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro ao fazer upload da imagem: $e");
      return null;
    }
  }

  Future<void> _onRegisterPressed() async {
    if (!_validateCpfCnpj(_cpfCnpjController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CPF/CNPJ inválido')));
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senhas não coincidem')));
      return;
    }

    setState(() => _loading = true);
    try {
      // Verifica se já existe o e-mail com outro tipo de conta
      final existingQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final existingType = existingQuery.docs.first['userType'];
        if (existingType != widget.userType) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Este e-mail já está vinculado a uma conta do tipo "$existingType".'),
          ));
          setState(() => _loading = false);
          return;
        }
      }

      // Cria conta no Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user!;
      final uid = user.uid;

      // 🔹 Upload da imagem para o Storage
      String? imageUrl = await _uploadProfileImage(uid);

      // 🔹 Salva dados no Firestore na collection 'users'
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'cpfCnpj': _cpfCnpjController.text.trim(),
        'userType': widget.userType,
        'fotoPerfilUrl': imageUrl ?? '',
        'descricao': '',
        'localizacao': '',
        'whatsapp': '',
        'link': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔹 Cria documento na collection específica baseado no tipo de usuário
      if (widget.userType == 'Academia') {
        await _firestore.collection('academias').doc(uid).set({
          'nome': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'fotoPerfilUrl': imageUrl ?? '',
          'capaUrl': '', // Será preenchido quando o usuário editar o perfil
          'descricao': '',
          'localizacao': '',
          'whatsapp': '',
          'link': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (widget.userType == 'Profissional') {
        await _firestore.collection('professionals').doc(uid).set({
          'nome': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'fotoUrl': imageUrl ?? '',
          'capaUrl': '', // Será preenchido quando o usuário editar o perfil
          'especialidade': '',
          'descricao': '',
          'localizacao': '',
          'whatsapp': '',
          'link': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Envia e-mail de verificação
      await user.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada! Verifique seu e-mail antes de fazer login.')),
      );

      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(userType: widget.userType)),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Erro ao registrar')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Criar Conta - ${widget.userType}'), backgroundColor: Colors.red),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
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
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.camera_alt, size: 40, color: Colors.red.shade700)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              CustomRadiusTextfield(controller: _nameController, hintText: 'Nome completo', focusNode: FocusNode()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(controller: _emailController, hintText: 'E-mail', keyboardType: TextInputType.emailAddress, focusNode: FocusNode()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(controller: _passwordController, hintText: 'Senha', obscureText: true, focusNode: FocusNode()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(controller: _confirmPasswordController, hintText: 'Confirmar senha', obscureText: true, focusNode: FocusNode()),
              const SizedBox(height: 16),
              TextField(
                controller: _cpfCnpjController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    MaskTextInputFormatter mask = getDynamicMask(newValue.text);
                    return mask.formatEditUpdate(oldValue, newValue);
                  }),
                ],
                decoration: InputDecoration(
                  hintText: 'CPF ou CNPJ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              _loading
                  ? const CircularProgressIndicator(color: Colors.red)
                  : CustomRadiusButton(onPressed: _onRegisterPressed, text: 'Cadastrar'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Voltar para o login', style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
