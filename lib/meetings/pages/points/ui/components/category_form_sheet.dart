import 'package:flutter/material.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/points/data/models/point_category.dart';

/// Bottom sheet form used to create or edit a point category.
class CategoryFormSheet extends StatefulWidget {
  final PointCategory? initialCategory;
  final String? title;
  final Future<void> Function(String name, String? description) onSubmit;

  const CategoryFormSheet({
    super.key,
    required this.onSubmit,
    this.initialCategory,
    this.title,
  });

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _isSubmitting = false;
  String? _submitError;

  bool get _isEditMode => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialCategory?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialCategory?.description ?? '',
    );
  }

  @override
  void didUpdateWidget(CategoryFormSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != oldWidget.initialCategory) {
      _nameController.text = widget.initialCategory?.name ?? '';
      _descriptionController.text = widget.initialCategory?.description ?? '';
      _submitError = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final title =
        widget.title ?? (_isEditMode ? 'Edit Category' : 'New Category');

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Material(
          color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          _isEditMode
                              ? Icons.drive_file_rename_outline
                              : Icons.add_box_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Category name *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Discipline, Leadership',
                      ),
                      validator: (value) {
                        final normalized = value?.trim() ?? '';
                        if (normalized.isEmpty) {
                          return 'Category name is required.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_submitError != null) {
                          setState(() => _submitError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 240,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_submitError != null) {
                          setState(() => _submitError = null);
                        }
                      },
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _submitError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : Text(
                                    _isEditMode ? 'Save' : 'Create',
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
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _descriptionController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = _toInlineError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _toInlineError(Object error) {
    final value = error.toString().trim();
    if (value.startsWith('Exception:')) {
      return value.replaceFirst('Exception:', '').trim();
    }
    return value;
  }
}
