import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Gender Selector Widget
///
/// A reusable component for selecting gender with radio button-style UI.
/// Can be used in user profiles, registration forms, and other contexts
/// requiring gender selection.
///
/// Features:
/// - Material 3 themed radio button-style selection
/// - Form validation support
/// - Theme-aware styling (dark/light mode)
/// - Customizable label and error handling
/// - Support for required/optional field
///
/// Usage:
/// ```dart
/// GenderSelector(
///   initialValue: 'Male',
///   onChanged: (value) => setState(() => _gender = value),
///   isRequired: true,
/// )
/// ```
class GenderSelector extends StatefulWidget {
  /// Initial selected gender value
  final String? initialValue;

  /// Callback when gender selection changes
  final ValueChanged<String?> onChanged;

  /// Whether the field is required (affects validation)
  final bool isRequired;

  /// Custom label for the field
  final String? label;

  /// Custom validator function (overrides default validation)
  final FormFieldValidator<String>? validator;

  const GenderSelector({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.isRequired = true,
    this.label,
    this.validator,
  });

  @override
  State<GenderSelector> createState() => _GenderSelectorState();
}

class _GenderSelectorState extends State<GenderSelector> {
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialValue;
  }

  @override
  void didUpdateWidget(GenderSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      setState(() {
        _selectedGender = widget.initialValue;
      });
    }
  }

  void _selectGender(String gender) {
    setState(() {
      _selectedGender = gender;
    });
    widget.onChanged(gender);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FormField<String>(
      initialValue: _selectedGender,
      validator: widget.validator ??
          (value) {
            if (widget.isRequired && (value == null || value.isEmpty)) {
              return 'Please select a gender';
            }
            return null;
          },
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label ?? (widget.isRequired ? 'Gender *' : 'Gender'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGenderOption(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    gender: 'Male',
                    field: field,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderOption(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    gender: 'Female',
                    field: field,
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
    );
  }

  /// Build a single gender option button
  Widget _buildGenderOption({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required String gender,
    required FormFieldState<String> field,
  }) {
    final isSelected = _selectedGender == gender;

    return InkWell(
      onTap: () {
        _selectGender(gender);
        field.didChange(gender);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : isDark
                  ? AppColors.cardDark
                  : AppColors.cardLight,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : isDark
                    ? theme.colorScheme.outline
                    : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryBlue : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                gender,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primaryBlue : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
