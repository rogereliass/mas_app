import 'package:flutter/material.dart';
import '../data/form_field_config.dart';
import '../../core/constants/app_colors.dart';
import '../../routing/app_router.dart';
import 'components/custom_text_field.dart';
import 'components/auth_buttons.dart';

/// Registration Page with Dynamic Form
/// 
/// Builds form fields dynamically from configuration
/// Allows easy addition/removal of fields without code changes
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _passwordVisibility = {};
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // TODO: Load this from remote config or database
  // This allows dynamic form fields without code changes
  late final List<FormFieldConfig> _registrationFields;

  @override
  void initState() {
    super.initState();
    _initializeFormFields();
    _initializeControllers();
  }

  void _initializeFormFields() {
    // TODO: Fetch from remote configuration
    // Example: await RemoteConfig.getRegistrationFields();
    
    _registrationFields = [
      const FormFieldConfig(
        key: 'fullName',
        label: 'Full Name',
        placeholder: 'e.g. Jane Doe',
        type: FormFieldType.text,
        isRequired: true,
      ),
      const FormFieldConfig(
        key: 'email',
        label: 'Email Address',
        placeholder: 'name@example.com',
        type: FormFieldType.email,
        isRequired: true,
      ),
      const FormFieldConfig(
        key: 'libraryCard',
        label: 'Library Card Number',
        placeholder: 'XXX-XXXX-XXXX',
        type: FormFieldType.text,
        isRequired: false,
        maxLength: 13,
      ),
      const FormFieldConfig(
        key: 'password',
        label: 'Password',
        type: FormFieldType.password,
        isRequired: true,
        isObscured: true,
      ),
      const FormFieldConfig(
        key: 'confirmPassword',
        label: 'Confirm Password',
        type: FormFieldType.password,
        isRequired: true,
        isObscured: true,
      ),
    ];
  }

  void _initializeControllers() {
    for (final field in _registrationFields) {
      _controllers[field.key] = TextEditingController();
      if (field.isObscured) {
        _passwordVisibility[field.key] = false;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateField(FormFieldConfig field, String? value) {
    if (field.isRequired && (value == null || value.isEmpty)) {
      return '${field.label} is required';
    }

    // Custom validation rules
    if (field.type == FormFieldType.email && value != null && value.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email';
      }
    }

    if (field.key == 'password' && value != null && value.isNotEmpty) {
      if (value.length < 8) {
        return 'Password must be at least 8 characters';
      }
      // TODO: Add more password strength requirements
    }

    if (field.key == 'confirmPassword') {
      final password = _controllers['password']?.text;
      if (value != password) {
        return 'Passwords do not match';
      }
    }

    // Use custom validator if provided
    if (field.validator != null) {
      return field.validator!(value);
    }

    return null;
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service and Privacy Policy'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement Supabase registration
      // final response = await Supabase.instance.client.auth.signUp(
      //   email: _controllers['email']!.text.trim(),
      //   password: _controllers['password']!.text,
      //   data: {
      //     'full_name': _controllers['fullName']!.text.trim(),
      //     'library_card': _controllers['libraryCard']?.text.trim(),
      //   },
      // );
      //
      // if (response.user != null) {
      //   Navigator.pushReplacementNamed(context, AppRouter.registerSuccess);
      // }

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Navigate to success page
      Navigator.pushReplacementNamed(context, AppRouter.registerSuccess);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.startup,
            (route) => false,
          ),
        ),
        title: Text(
          'SCOUT LOGO',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                _buildLogo(),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Start your reading\njourney',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Register to access thousands of digital\nresources and join our community.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Dynamic form fields
                ...buildDynamicFormFields(),

                const SizedBox(height: 24),

                // Terms checkbox
                _buildTermsCheckbox(),

                const SizedBox(height: 32),

                // Register button
                PrimaryButton(
                  text: 'Create Account',
                  icon: Icons.arrow_forward,
                  onPressed: _handleRegistration,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already a member? ',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.publicAccessBadge,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.menu_book,
        size: 56,
        color: colorScheme.onPrimary,
      ),
    );
  }

  /// Build form fields dynamically from configuration
  List<Widget> buildDynamicFormFields() {
    final List<Widget> widgets = [];

    for (int i = 0; i < _registrationFields.length; i++) {
      final field = _registrationFields[i];
      final controller = _controllers[field.key]!;

      widgets.add(
        CustomTextField(
          label: field.label,
          placeholder: field.placeholder,
          controller: controller,
          isRequired: field.isRequired,
          isObscured: field.isObscured && !(_passwordVisibility[field.key] ?? false),
          keyboardType: field.keyboardType ?? field.type.keyboardType,
          maxLength: field.maxLength,
          validator: (value) => _validateField(field, value),
          suffixIcon: field.isObscured
              ? IconButton(
                  icon: Icon(
                    _passwordVisibility[field.key] == true
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisibility[field.key] = 
                          !(_passwordVisibility[field.key] ?? false);
                    });
                  },
                )
              : (field.key == 'email'
                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary)
                  : null),
        ),
      );

      // Add spacing between fields
      if (i < _registrationFields.length - 1) {
        widgets.add(const SizedBox(height: 20));
      }
    }

    return widgets;
  }

  Widget _buildTermsCheckbox() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (value) {
              setState(() {
                _agreedToTerms = value ?? false;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy\nPolicy',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
