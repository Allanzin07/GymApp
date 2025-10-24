import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'login_page.dart';
import 'custom_widgets.dart';

// --- Funções de validação CPF/CNPJ ---
bool isValidCpf(String cpf) {
  cpf = cpf.replaceAll(RegExp(r'\D'), '');
  if (cpf.length != 11 || RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;

  List<int> digits = cpf.split('').map(int.parse).toList();

  // Validação primeiro dígito verificador
  int sum = 0;
  for (int i = 0; i < 9; i++) sum += digits[i] * (10 - i);
  int firstCheck = (sum * 10 % 11) % 10;
  if (digits[9] != firstCheck) return false;

  // Validação segundo dígito verificador
  sum = 0;
  for (int i = 0; i < 10; i++) sum += digits[i] * (11 - i);
  int secondCheck = (sum * 10 % 11) % 10;
  return digits[10] == secondCheck;
}

bool isValidCnpj(String cnpj) {
  cnpj = cnpj.replaceAll(RegExp(r'\D'), '');
  if (cnpj.length != 14 || RegExp(r'^(\d)\1*$').hasMatch(cnpj)) return false;

  List<int> digits = cnpj.split('').map(int.parse).toList();

  List<int> calcDigits(List<int> d, List<int> multipliers) {
    int sum = 0;
    for (int i = 0; i < multipliers.length; i++) sum += d[i] * multipliers[i];
    int r = sum % 11;
    return [(r < 2 ? 0 : 11 - r)];
  }

  List<int> firstMultipliers = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  List<int> secondMultipliers = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int firstCheck = calcDigits(digits, firstMultipliers)[0];
  if (digits[12] != firstCheck) return false;

  int secondCheck = calcDigits(digits, secondMultipliers)[0];
  return digits[13] == secondCheck;
}

// --- Register Page ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _cpfCnpjController = TextEditingController();

  // Focus Nodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _cpfCnpjFocus = FocusNode();

  // Imagem de perfil
  File? _profileImage;

  // Máscaras CPF/CNPJ
  final MaskTextInputFormatter _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final MaskTextInputFormatter _cnpjMask = MaskTextInputFormatter(
      mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});

  MaskTextInputFormatter getDynamicMask(String value) {
    String numbers = value.replaceAll(RegExp(r'\D'), '');
    return numbers.length > 11 ? _cnpjMask : _cpfMask;
  }

  Future<void> _pickProfileImage() async {
    // Implementação de escolha de imagem
  }

  void _onRegisterPressed() {
    String cpfCnpjRaw = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');

    bool validCpfCnpj = false;
    String type = '';
    if (cpfCnpjRaw.length <= 11) {
      validCpfCnpj = isValidCpf(cpfCnpjRaw);
      type = 'CPF';
    } else {
      validCpfCnpj = isValidCnpj(cpfCnpjRaw);
      type = 'CNPJ';
    }

    if (!validCpfCnpj) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type inválido!')),
      );
      return;
    }

    // Validação de senha
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senhas não coincidem')),
      );
      return;
    }

    // Registro simulado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Registro válido! $type: $cpfCnpjRaw')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cpfCnpjController.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _cpfCnpjFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removido backgroundColor do Scaffold para que o Container abaixo cubra tudo.
      appBar:
          AppBar(title: const Text('Criar Conta'), backgroundColor: Colors.red),
      body: Container(
        // Adicionado Container para o gradiente
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red,
              Colors.white
            ], // O mesmo gradiente da outra tela
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          // O ConstrainedBox foi removido para que o Column possa usar toda a largura da tela.
          child: Column(
            // Removida a limitação de ConstrainedBox(maxWidth: 400)
            children: [
              const SizedBox(height: 24),
              // Avatar
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
              // Campos
              CustomRadiusTextfield(
                  controller: _nameController,
                  hintText: 'Nome completo',
                  focusNode: _nameFocus,
                  onEditingComplete: () => _emailFocus.requestFocus()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(
                  controller: _emailController,
                  hintText: 'E-mail',
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  onEditingComplete: () => _passwordFocus.requestFocus()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(
                  controller: _passwordController,
                  hintText: 'Senha',
                  focusNode: _passwordFocus,
                  obscureText: true,
                  onEditingComplete: () =>
                      _confirmPasswordFocus.requestFocus()),
              const SizedBox(height: 16),
              CustomRadiusTextfield(
                  controller: _confirmPasswordController,
                  hintText: 'Confirmar senha',
                  focusNode: _confirmPasswordFocus,
                  obscureText: true,
                  onEditingComplete: () => _cpfCnpjFocus.requestFocus()),
              const SizedBox(height: 16),
              // CPF/CNPJ com máscara dinâmica
              TextField(
                controller: _cpfCnpjController,
                focusNode: _cpfCnpjFocus,
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              CustomRadiusButton(
                  onPressed: _onRegisterPressed, text: 'Cadastrar'),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Voltar para o login',
                      style: TextStyle(color: Colors.red.shade700))),
            ],
          ),
        ),
      ),
    );
  }
}
