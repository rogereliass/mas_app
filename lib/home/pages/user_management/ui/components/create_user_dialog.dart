import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../auth/logic/auth_provider.dart';
import '../../../../../core/utils/error_translator.dart';
import '../../../../../auth/models/user_profile.dart';
import '../../logic/user_management_provider.dart';

/// Create User Dialog Component
///
/// A comprehensive dialog for creating new user profiles.
/// Supports form validation, email uniqueness check, and profile creation.
///
/// Features:
/// - All required profile fields (name, email, phone, address, etc.)
/// - Form validation with inline error messages
/// - Async email uniqueness validation
/// - Responsive layout for different screen sizes
/// - Theme-aware styling using AppColors and Material theme
///
/// Usage:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (context) => CreateUserDialog(
///     currentUserProfile: profile,
///     currentUserRank: 90,
///     availableTroops: troops,
///     onSuccess: () => loadUsers(),
///   ),
/// );
/// ```
class CreateUserDialog extends StatefulWidget {
  /// Current user profile (for permission checks)
  final UserProfile? currentUserProfile;

  /// Current user rank (for admin checks)
  final int currentUserRank;

  /// List of available troops {id, name}
  final List<Map<String, dynamic>> availableTroops;

  /// Callback when user is successfully created
  final VoidCallback? onSuccess;

  const CreateUserDialog({
    super.key,
    required this.currentUserProfile,
    required this.currentUserRank,
    required this.availableTroops,
    this.onSuccess,
  });

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _arabicNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _generationController;
  late final TextEditingController _birthdateController;

  // Other fields
  DateTime? _selectedBirthdate;
  String? _selectedGender;
  String? _selectedTroopId;

  // State
  Timer? _emailValidationDebounce;
  String? _emailValidationError;
  bool _isCheckingEmail = false;
  bool _isLoadingTroops = false;
  List<Map<String, dynamic>> _troops = [];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _arabicNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _generationController = TextEditingController();
    _birthdateController = TextEditingController();

    _troops = List<Map<String, dynamic>>.from(widget.availableTroops);
    if (widget.currentUserRank >= 90) {
      _loadTroops();
    }

    // Add email listener for async validation
    _emailController.addListener(_debounceEmailValidation);
  }

  Future<void> _loadTroops() async {
    setState(() {
      _isLoadingTroops = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final fetchedTroops = await authProvider.getTroops();
      if (!mounted) return;

      final troopMap = <String, String>{};
      for (final troop in _troops) {
        final id = troop['id']?.toString();
        final name = troop['name']?.toString();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          troopMap[id] = name;
        }
      }
      for (final troop in fetchedTroops) {
        final id = troop['id']?.toString();
        final name = troop['name']?.toString();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          troopMap[id] = name;
        }
      }

      final mergedTroops =
          troopMap.entries
              .map((entry) => {'id': entry.key, 'name': entry.value})
              .toList()
            ..sort(
              (a, b) => (a['name'] as String).toLowerCase().compareTo(
                (b['name'] as String).toLowerCase(),
              ),
            );

      setState(() {
        _troops = mergedTroops;
        _isLoadingTroops = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingTroops = false;
      });
    }
  }

  @override
  void dispose() {
    _emailValidationDebounce?.cancel();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _arabicNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _generationController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  /// Debounce email uniqueness check
  void _debounceEmailValidation() {
    _emailValidationDebounce?.cancel();
    _emailValidationDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _checkEmailUniqueness(),
    );
  }

  /// Async email uniqueness validation
  Future<void> _checkEmailUniqueness() async {
    if (!mounted) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailValidationError = null;
        _isCheckingEmail = false;
      });
      return;
    }

    // Skip if email format is invalid
    if (_validateEmail(email) != null) {
      setState(() {
        _emailValidationError = null;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final exists = await authProvider.checkEmailExists(email);

      if (mounted) {
        setState(() {
          _emailValidationError = exists ? 'Email already in use' : null;
          _isCheckingEmail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailValidationError = null;
          _isCheckingEmail = false;
        });
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

  /// Validate generation format (1-2 alphabetic characters, e.g. T, u, TT)
  String? _validateGeneration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Generation is required';
    }
    if (!RegExp(r'^[A-Za-z]{1,2}$').hasMatch(value.trim())) {
      return 'Generation must be 1-2 letters (e.g. T, u, TT)';
    }
    return null;
  }

  /// Select birthdate
  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime(2000),
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
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Handle form submission
  Future<void> _handleSubmit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check async email validation error
    if (_emailValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorTranslator.toUserMessage(_emailValidationError)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Validate birthdate
    if (_selectedBirthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a birthdate'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Validate gender
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a gender'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Validate troop selection for admin
    String troopId;
    if (widget.currentUserRank >= 90) {
      if (_selectedTroopId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a troop'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      troopId = _selectedTroopId!;
    } else {
      // Use user's assigned troop
      troopId = widget.currentUserProfile?.managedTroopId ?? '';
      if (troopId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No troop assigned to your account'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    // Prepare profile data
    final profileData = {
      'first_name': _firstNameController.text.trim(),
      'middle_name': _middleNameController.text.trim().isEmpty
          ? null
          : _middleNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'name_ar': _arabicNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'birthdate': DateFormat('yyyy-MM-dd').format(_selectedBirthdate!),
      'gender': _selectedGender!.toLowerCase(),
      'generation': _generationController.text.trim(),
    };

    // Call provider to create user
    if (!mounted) return;

    final provider = Provider.of<UserManagementProvider>(
      context,
      listen: false,
    );
    final success = await provider.createUser(
      profileData: profileData,
      assignedTroopId: troopId,
    );

    if (!mounted) return;

    if (success) {
      // Close dialog
      Navigator.of(context).pop();

      // Call success callback
      widget.onSuccess?.call();
    } else {
      // Show user-friendly error message
      final technicalError =
          provider.createUserError ?? 'Failed to create user';
      final userMessage = ErrorTranslator.toUserMessage(technicalError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystemAdmin = widget.currentUserRank >= 90;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Create New User'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Consumer<UserManagementProvider>(
            builder: (context, provider, _) {
              final isLoading = provider.isCreatingUser;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // First Name
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name *',
                            hintText: 'Enter first name',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Middle Name
                        TextFormField(
                          controller: _middleNameController,
                          decoration: InputDecoration(
                            labelText: 'Middle Name',
                            hintText: 'Enter middle name (optional)',
                            border: const OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name *',
                            hintText: 'Enter last name',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Last name is required';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Arabic Name
                        TextFormField(
                          controller: _arabicNameController,
                          decoration: InputDecoration(
                            labelText: 'Arabic Name *',
                            hintText: 'الاسم بالعربية',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              _validateArabic(value, 'Arabic Name'),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Email
                        Stack(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email *',
                                hintText: 'Enter email address',
                                border: const OutlineInputBorder(),
                                errorText: _emailValidationError,
                              ),
                              validator: _validateEmail,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            if (_isCheckingEmail)
                              Positioned(
                                right: 12,
                                top: 18,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone *',
                            hintText: 'Enter phone number',
                            border: const OutlineInputBorder(),
                          ),
                          validator: _validatePhone,
                          enabled: !isLoading,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Address *',
                            hintText: 'Enter address',
                            border: const OutlineInputBorder(),
                          ),
                          validator: _validateAddress,
                          enabled: !isLoading,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Birthdate
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Birthdate *',
                            hintText: 'Select birthdate',
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          controller: _birthdateController,
                          onTap: isLoading ? null : _selectBirthdate,
                          validator: (value) {
                            if (_selectedBirthdate == null) {
                              return 'Birthdate is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Gender
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Gender *',
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text('Female'),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedGender = value;
                                  });
                                },
                          isExpanded: true,
                          validator: (value) {
                            if (value == null) {
                              return 'Gender is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Generation
                        TextFormField(
                          controller: _generationController,
                          decoration: InputDecoration(
                            labelText: 'Generation *',
                            hintText: 'e.g., T, u, TT',
                            border: const OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(2),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z]'),
                            ),
                          ],
                          validator: _validateGeneration,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Troop Selection (only for admins)
                        if (isSystemAdmin) ...[
                          if (_isLoadingTroops)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTroopId,
                            decoration: InputDecoration(
                              labelText: 'Assigned Troop *',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              ..._troops.map(
                                (troop) => DropdownMenuItem(
                                  value: troop['id']?.toString(),
                                  child: Text(troop['name']?.toString() ?? ''),
                                ),
                              ),
                            ],
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedTroopId = value;
                                    });
                                  },
                            isExpanded: true,
                            validator: (value) {
                              if (value == null) {
                                return 'Troop is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isLoading || _isCheckingEmail
                                  ? null
                                  : _handleSubmit,
                              child: isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : const Text('Create User'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
