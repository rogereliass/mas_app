import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../logic/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../routing/app_router.dart';
import 'components/custom_text_field.dart';
import 'components/auth_buttons.dart';
import 'components/auth_error_dialog.dart';

/// Comprehensive Registration Page
///
/// Collects all user information for profile creation
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for all fields
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _arabicNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // State variables
  DateTime? _selectedBirthdate;
  String? _selectedGender;
  String? _selectedTroopId;  // Store the UUID of selected troop
  List<Map<String, dynamic>> _troops = [];  // List of {id, name}
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTroops();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _arabicNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Load troops from Supabase
  Future<void> _loadTroops() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final troops = await authProvider.getTroops();
      
      if (mounted) {
        if (troops.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load troops from database. Please check your connection.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _troops = troops;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading troops: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Validate Arabic text
  String? _validateArabic(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    // Check if contains Arabic characters
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(value)) {
      return '$fieldName must contain Arabic characters';
    }
    return null;
  }

  /// Validate address (no Arabic requirement)
  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address is required';
    }
    return null;
  }

  /// Validate phone number
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?\d+$').hasMatch(cleanNumber)) {
      return 'Please enter a valid phone number';
    }
    final digitsOnly = cleanNumber.replaceAll('+', '');
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    return null;
  }

  /// Validate email (required)
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate password
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one digit';
    }
    return null;
  }

  /// Validate confirm password
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Select birthdate
  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  /// Handle registration
  Future<void> _handleRegistration() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate birthdate
    if (_selectedBirthdate == null) {
      await AuthErrorDialog.showError(
        context: context,
        message: 'Please select your birthdate',
      );
      return;
    }

    // Validate gender
    if (_selectedGender == null) {
      await AuthErrorDialog.showError(
        context: context,
        message: 'Please select your gender',
      );
      return;
    }

    // Validate troop
    if (_selectedTroopId == null) {
      await AuthErrorDialog.showError(
        context: context,
        message: 'Please select your troop',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Prepare metadata matching exact Supabase profiles table columns
      final metadata = {
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'name_ar': _arabicNameController.text.trim(),
        'birthdate': intl.DateFormat('yyyy-MM-dd').format(_selectedBirthdate!),
        'gender': _selectedGender!.toLowerCase(), // 'male' or 'female' for gender_enum
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'signup_troop': _selectedTroopId,  // Store the troop UUID
        'generation': 'U',  // Default generation until assigned by leader
        'signup_completed': true,
        'email': _emailController.text.trim(),  // Email is required
      };

      debugPrint('=== STARTING REGISTRATION ===');
      debugPrint('Phone: ${_phoneController.text.trim()}');
      debugPrint('Has email: ${_emailController.text.trim().isNotEmpty}');
      debugPrint('Troop ID: $_selectedTroopId');

      // Attempt registration - this will send OTP
      final success = await authProvider.signUpWithPhone(
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
        metadata: metadata,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to OTP verification page with metadata
        Navigator.pushNamed(
          context,
          AppRouter.otpVerification,
          arguments: {
            'phoneNumber': _phoneController.text.trim(),
            'password': _passwordController.text,
            'isSignUp': true,
            'metadata': metadata,
          },
        );
      } else {
        // Show error dialog
        await AuthErrorDialog.showError(
          context: context,
          message:
              authProvider.errorMessage ??
              'Failed to send OTP. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      await AuthErrorDialog.showError(
        context: context,
        message: 'An unexpected error occurred during registration.',
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
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Register',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in your details to create an account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Personal Information Section
                _buildSectionHeader('Personal Information'),
                const SizedBox(height: 16),

                // First Name
                CustomTextField(
                  label: 'First Name',
                  placeholder: 'Enter your first name',
                  controller: _firstNameController,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'First name is required' : null,
                ),
                const SizedBox(height: 16),

                // Middle Name (Optional)
                CustomTextField(
                  label: 'Middle Name (Optional)',
                  placeholder: 'Enter your middle name',
                  controller: _middleNameController,
                ),
                const SizedBox(height: 16),

                // Last Name
                CustomTextField(
                  label: 'Last Name',
                  placeholder: 'Enter your last name',
                  controller: _lastNameController,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Last name is required' : null,
                ),
                const SizedBox(height: 16),

                // Name in Arabic
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: CustomTextField(
                    label: 'الاسم بالعربية',
                    placeholder: 'أدخل اسمك بالعربية',
                    controller: _arabicNameController,
                    validator: (value) => _validateArabic(value, 'Arabic name'),
                  ),
                ),
                const SizedBox(height: 16),

                // Birthdate
                InkWell(
                  onTap: _selectBirthdate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthdate',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedBirthdate == null
                          ? 'Select your birthdate'
                          : intl.DateFormat('dd MMM yyyy').format(_selectedBirthdate!),
                      style: TextStyle(
                        color: _selectedBirthdate == null
                            ? Colors.grey[600]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender Radio Buttons
                FormField<String>(
                  validator: (value) {
                    if (_selectedGender == null) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> field) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedGender = 'Male';
                                  });
                                  field.didChange('Male');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'Male'
                                        ? AppColors.primaryBlue.withOpacity(0.1)
                                        : theme.brightness == Brightness.dark
                                            ? AppColors.cardDark
                                            : AppColors.cardLight,
                                    border: Border.all(
                                      color: _selectedGender == 'Male'
                                          ? AppColors.primaryBlue
                                          : theme.brightness == Brightness.dark
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                      width: _selectedGender == 'Male' ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedGender == 'Male'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _selectedGender == 'Male'
                                            ? AppColors.primaryBlue
                                            : Colors.grey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Male',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: _selectedGender == 'Male'
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: _selectedGender == 'Male'
                                              ? AppColors.primaryBlue
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedGender = 'Female';
                                  });
                                  field.didChange('Female');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'Female'
                                        ? AppColors.primaryBlue.withOpacity(0.1)
                                        : theme.brightness == Brightness.dark
                                            ? AppColors.cardDark
                                            : AppColors.cardLight,
                                    border: Border.all(
                                      color: _selectedGender == 'Female'
                                          ? AppColors.primaryBlue
                                          : theme.brightness == Brightness.dark
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                      width: _selectedGender == 'Female' ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedGender == 'Female'
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _selectedGender == 'Female'
                                            ? AppColors.primaryBlue
                                            : Colors.grey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Female',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: _selectedGender == 'Female'
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: _selectedGender == 'Female'
                                              ? AppColors.primaryBlue
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              field.errorText!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Contact Information Section
                _buildSectionHeader('Contact Information'),
                const SizedBox(height: 16),

                // Phone Number
                CustomTextField(
                  label: 'Phone Number',
                  placeholder: '01001234567',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),

                // Email
                CustomTextField(
                  label: 'Email Address',
                  placeholder: 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                // Address
                CustomTextField(
                  label: 'Address',
                  placeholder: 'Enter your address',
                  controller: _addressController,
                  isMultiline: true,
                  validator: _validateAddress,
                ),
                const SizedBox(height: 24),

                // Troop Information Section
                _buildSectionHeader('Troop Information'),
                const SizedBox(height: 16),

                // Troop Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedTroopId,
                  decoration: InputDecoration(
                    labelText: 'Signup Troop',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _troops.map((troop) {
                    return DropdownMenuItem<String>(
                      value: troop['id'] as String,
                      child: Text(troop['name'] as String),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTroopId = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select your troop' : null,
                ),
                const SizedBox(height: 24),

                // Security Section
                _buildSectionHeader('Security'),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  label: 'Password',
                  placeholder: 'At least 8 characters',
                  controller: _passwordController,
                  isObscured: !_isPasswordVisible,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  label: 'Confirm Password',
                  placeholder: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  isObscured: !_isConfirmPasswordVisible,
                  validator: _validateConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Register Button
                PrimaryButton(
                  text: 'Register',
                  icon: Icons.arrow_forward,
                  onPressed: _handleRegistration,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.publicAccessBadge,
                      ),
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
