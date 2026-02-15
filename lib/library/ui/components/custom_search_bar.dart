import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable search bar component
/// 
/// Used throughout the library screens for searching resources
/// Styled with Scout Elite design system
class CustomSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextEditingController? controller;

  const CustomSearchBar({
    super.key,
    this.hintText = 'Search resources...',
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.controller,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: _isFocused && !widget.readOnly
            ? Border.all(color: AppColors.goldAccent, width: 2)
            : null,
      ),
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        child: TextField(
          controller: widget.controller,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: isDark 
                  ? AppColors.sectionHeaderGray 
                  : theme.textTheme.bodySmall?.color,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: _isFocused 
                  ? (isDark ? AppColors.goldAccent : theme.colorScheme.primary)
                  : (isDark ? AppColors.sectionHeaderGray : theme.iconTheme.color?.withValues(alpha: 0.6)),
              size: 24,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}

