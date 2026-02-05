import 'package:flutter/material.dart';

/// Reusable custom text field component
/// 
/// Theme-aware text input with validation, obscured text, and suffix icons
/// Uses ThemeData for all styling - no hardcoded colors
class CustomTextField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final bool isRequired;
  final bool isObscured;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final int? maxLength;
  final void Function(String)? onChanged;
  final TextDirection? textDirection;
  final bool isMultiline;

  const CustomTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.isRequired = true,
    this.isObscured = false,
    this.keyboardType,
    this.controller,
    this.validator,
    this.suffixIcon,
    this.maxLength,
    this.onChanged,
    this.textDirection,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: textTheme.titleMedium,
            ),
            if (!isRequired) ...[
              const SizedBox(width: 8),
              Text(
                'Optional',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscured,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          textDirection: textDirection,
          maxLines: isMultiline ? 3 : 1,
          minLines: isMultiline ? 2 : 1,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: placeholder ?? 'Enter your $label',
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: textTheme.bodySmall?.color,
            ),
            suffixIcon: suffixIcon,
            counterText: '',
            alignLabelWithHint: isMultiline,
          ),
        ),
      ],
    );
  }
}
