import 'package:flutter/material.dart';

/// Configuration model for dynamic form fields
/// 
/// Allows forms to be built dynamically from configuration
/// without hardcoding field definitions
class FormFieldConfig {
  final String key;
  final String label;
  final String? placeholder;
  final FormFieldType type;
  final bool isRequired;
  final bool isObscured;
  final String? validationMessage;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final int? maxLength;

  const FormFieldConfig({
    required this.key,
    required this.label,
    this.placeholder,
    this.type = FormFieldType.text,
    this.isRequired = true,
    this.isObscured = false,
    this.validationMessage,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
    this.maxLength,
  });

  /// Create a copy with modified fields
  FormFieldConfig copyWith({
    String? key,
    String? label,
    String? placeholder,
    FormFieldType? type,
    bool? isRequired,
    bool? isObscured,
    String? validationMessage,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    int? maxLength,
  }) {
    return FormFieldConfig(
      key: key ?? this.key,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      isObscured: isObscured ?? this.isObscured,
      validationMessage: validationMessage ?? this.validationMessage,
      validator: validator ?? this.validator,
      keyboardType: keyboardType ?? this.keyboardType,
      suffixIcon: suffixIcon ?? this.suffixIcon,
      maxLength: maxLength ?? this.maxLength,
    );
  }
}

/// Types of form fields
enum FormFieldType {
  text,
  email,
  password,
  number,
  phone,
  url,
  multiline,
}

/// Extension to get keyboard type from field type
extension FormFieldTypeExtension on FormFieldType {
  TextInputType get keyboardType {
    switch (this) {
      case FormFieldType.email:
        return TextInputType.emailAddress;
      case FormFieldType.number:
        return TextInputType.number;
      case FormFieldType.phone:
        return TextInputType.phone;
      case FormFieldType.url:
        return TextInputType.url;
      case FormFieldType.multiline:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }
}
