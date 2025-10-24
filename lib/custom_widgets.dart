import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🔹 Campo de texto customizado
class CustomRadiusTextfield extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final FocusNode focusNode;
  final VoidCallback? onEditingComplete;
  final TextInputType keyboardType;
  final int? maxLines;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;

  const CustomRadiusTextfield({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.focusNode,
    this.onEditingComplete,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.obscureText = false,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onEditingComplete: onEditingComplete,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
        fillColor: Colors.white,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(color: Colors.black87),
      cursorColor: Colors.red,
    );
  }
}

// 🔹 Botão customizado
class CustomRadiusButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool expandedinWeb;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? icon;

  const CustomRadiusButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.expandedinWeb = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expandedinWeb ? double.infinity : null,
      child: ElevatedButton.icon(
        icon: icon ?? const SizedBox(),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.white,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
