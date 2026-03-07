import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:masapp/core/constants/app_colors.dart';

import '../../data/models/patrol_option.dart';
import '../../data/models/point_category.dart';
import '../../data/models/point_form_data.dart';

class PointEntryDialog extends StatefulWidget {
  final List<PatrolOption> patrolOptions;
  final List<PointCategory> categoryOptions;
  final Future<void> Function(PointFormData data) onSubmit;
  final PointFormData? initialData;
  final String? title;
  final bool canManageCategories;
  final Future<String?> Function()? onManageCategories;
  final List<PointCategory> Function()? categoryOptionsResolver;

  const PointEntryDialog({
    super.key,
    required this.patrolOptions,
    required this.categoryOptions,
    required this.onSubmit,
    this.initialData,
    this.title,
    this.canManageCategories = false,
    this.onManageCategories,
    this.categoryOptionsResolver,
  });

  @override
  State<PointEntryDialog> createState() => _PointEntryDialogState();
}

class _PointEntryDialogState extends State<PointEntryDialog> {
  static const int _chipLimit = 6;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _reasonController;
  late List<PointCategory> _categoryOptions;

  String? _selectedPatrolId;
  String? _selectedCategoryId;
  bool _showSelectionErrors = false;
  bool _isSubmitting = false;
  bool _expandReason = false;
  String? _submitError;

  bool get _isEditMode => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    _selectedPatrolId = widget.initialData?.patrolId;
    _selectedCategoryId = widget.initialData?.categoryId;
    _categoryOptions = widget.categoryOptions;
    _valueController = TextEditingController(
      text: widget.initialData?.value.toString() ?? '0',
    );
    _reasonController = TextEditingController(
      text: widget.initialData?.reason ?? '',
    );
    _expandReason = (widget.initialData?.reason?.trim().isNotEmpty ?? false);
  }

  @override
  void didUpdateWidget(PointEntryDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialData != oldWidget.initialData) {
      _selectedPatrolId = widget.initialData?.patrolId;
      _selectedCategoryId = widget.initialData?.categoryId;
      _valueController.text = widget.initialData?.value.toString() ?? '0';
      _reasonController.text = widget.initialData?.reason ?? '';
      _submitError = null;
      _showSelectionErrors = false;
    }

    if (_selectedPatrolId != null &&
        !widget.patrolOptions.any((patrol) => patrol.id == _selectedPatrolId)) {
      _selectedPatrolId = null;
    }
    if (_selectedCategoryId != null &&
        !_categoryOptions.any(
          (category) => category.id == _selectedCategoryId,
        )) {
      _selectedCategoryId = null;
    }

    if (!listEquals(widget.categoryOptions, oldWidget.categoryOptions)) {
      _categoryOptions = widget.categoryOptions;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final title = widget.title ?? (_isEditMode ? 'Edit Point' : 'Add Point');

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 720),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                                ? Icons.edit_note_outlined
                                : Icons.add_circle_outline,
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
                      const SizedBox(height: 10),
                      _buildPatrolQuickSelect(context),
                      const SizedBox(height: 14),
                      _buildCategoryQuickSelect(context),
                      const SizedBox(height: 14),
                      _buildValueEditor(context),
                      const SizedBox(height: 10),
                      _buildReasonSection(context),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
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
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: _isSubmitting
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(_isSubmitting ? 'Saving...' : 'Save'),
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
      ),
    );
  }

  Widget _buildPatrolQuickSelect(BuildContext context) {
    final selected = _selectedPatrolId;
    final options = widget.patrolOptions;

    return _QuickSelectBlock<PatrolOption>(
      title: 'Patrol',
      requiredLabel: true,
      options: options,
      selectedId: selected,
      chipLimit: _chipLimit,
      idOf: (item) => item.id,
      labelOf: (item) => item.name,
      subtitleBuilder: null,
      errorText: _showSelectionErrors && (selected == null || selected.isEmpty)
          ? 'Please select a patrol.'
          : null,
      onSelect: (id) {
        setState(() {
          _selectedPatrolId = id;
          _submitError = null;
        });
      },
      onOpenPicker: () => _showQuickPicker<PatrolOption>(
        context,
        title: 'Select Patrol',
        options: options,
        selectedId: selected,
        idOf: (item) => item.id,
        labelOf: (item) => item.name,
      ),
    );
  }

  Widget _buildCategoryQuickSelect(BuildContext context) {
    final selected = _selectedCategoryId;
    final options = _categoryOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickSelectBlock<PointCategory>(
                title: 'Category',
                requiredLabel: true,
                options: options,
                selectedId: selected,
                chipLimit: _chipLimit,
                idOf: (item) => item.id,
                labelOf: (item) => item.name,
                subtitleBuilder: (item) =>
                    item.troopId == null ? 'Global' : null,
                errorText:
                    _showSelectionErrors &&
                        (selected == null || selected.isEmpty)
                    ? 'Please select a category.'
                    : null,
                onSelect: (id) {
                  setState(() {
                    _selectedCategoryId = id;
                    _submitError = null;
                  });
                },
                onOpenPicker: () => _showQuickPicker<PointCategory>(
                  context,
                  title: 'Select Category',
                  options: options,
                  selectedId: selected,
                  idOf: (item) => item.id,
                  labelOf: (item) => item.name,
                  subtitleOf: (item) => item.troopId == null ? 'Global' : null,
                ),
              ),
            ),
          ],
        ),
        if (widget.onManageCategories != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : _openCategoryManager,
              icon: Icon(
                widget.canManageCategories
                    ? Icons.tune_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(
                widget.canManageCategories
                    ? 'Manage Categories'
                    : 'View Categories',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCategoryManager() async {
    final openManager = widget.onManageCategories;
    if (openManager == null || _isSubmitting) return;

    try {
      final selectedCategoryId = await openManager();
      if (!mounted) return;

      final latestCategories =
          widget.categoryOptionsResolver?.call() ?? widget.categoryOptions;

      setState(() {
        _categoryOptions = latestCategories;
        if (selectedCategoryId != null && selectedCategoryId.isNotEmpty) {
          _selectedCategoryId = selectedCategoryId;
        } else if (_selectedCategoryId != null &&
            !_categoryOptions.any(
              (category) => category.id == _selectedCategoryId,
            )) {
          _selectedCategoryId = null;
        }
        _submitError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = _toInlineError(e);
      });
    }
  }

  Widget _buildValueEditor(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Value',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _isSubmitting ? null : () => _adjustValue(-1),
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease by 1',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. 5 or -2',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Value is required.';
                  final parsed = int.tryParse(trimmed);
                  if (parsed == null) return 'Enter a valid integer value.';
                  return null;
                },
                onChanged: (_) {
                  if (_submitError != null) {
                    setState(() => _submitError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _isSubmitting ? null : () => _adjustValue(1),
              icon: const Icon(Icons.add),
              tooltip: 'Increase by 1',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ValueChip(
              label: '-5',
              onTap: _isSubmitting ? null : () => _adjustValue(-5),
            ),
            _ValueChip(
              label: '-1',
              onTap: _isSubmitting ? null : () => _adjustValue(-1),
            ),
            _ValueChip(
              label: '+1',
              onTap: _isSubmitting ? null : () => _adjustValue(1),
            ),
            _ValueChip(
              label: '+5',
              onTap: _isSubmitting ? null : () => _adjustValue(5),
            ),
            _ValueChip(
              label: '+10',
              onTap: _isSubmitting ? null : () => _adjustValue(10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonSection(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      initiallyExpanded: _expandReason,
      onExpansionChanged: (expanded) {
        setState(() {
          _expandReason = expanded;
        });
      },
      title: Text(
        'Reason (optional)',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        TextFormField(
          controller: _reasonController,
          maxLength: 240,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What happened in this meeting?',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_submitError != null) {
              setState(() => _submitError = null);
            }
          },
        ),
      ],
    );
  }

  void _adjustValue(int delta) {
    final current = int.tryParse(_valueController.text.trim()) ?? 0;
    _valueController.text = (current + delta).toString();
    if (_submitError != null) {
      setState(() => _submitError = null);
    } else {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _showSelectionErrors = true;
      _submitError = null;
    });

    final selectedPatrolId = _selectedPatrolId;
    final selectedCategoryId = _selectedCategoryId;

    if (selectedPatrolId == null || selectedPatrolId.isEmpty) {
      setState(() => _submitError = 'Please select a patrol.');
      return;
    }
    if (selectedCategoryId == null || selectedCategoryId.isEmpty) {
      setState(() => _submitError = 'Please select a category.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final value = int.tryParse(_valueController.text.trim());
    if (value == null) {
      setState(() => _submitError = 'Value must be a valid integer.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.onSubmit(
        PointFormData(
          patrolId: selectedPatrolId,
          categoryId: selectedCategoryId,
          value: value,
          reason: _reasonController.text,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = _toInlineError(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _showQuickPicker<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String? selectedId,
    required String Function(T item) idOf,
    required String Function(T item) labelOf,
    String? Function(T item)? subtitleOf,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final item = options[index];
                      final id = idOf(item);
                      final selected = id == selectedId;
                      final subtitle = subtitleOf?.call(item);

                      return ListTile(
                        leading: selected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                        title: Text(
                          labelOf(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitle == null
                            ? null
                            : Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => Navigator.of(context).pop(id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _toInlineError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }
    return text;
  }
}

class _QuickSelectBlock<T> extends StatelessWidget {
  final String title;
  final bool requiredLabel;
  final List<T> options;
  final String? selectedId;
  final int chipLimit;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final String? Function(T item)? subtitleBuilder;
  final String? errorText;
  final ValueChanged<String> onSelect;
  final Future<String?> Function() onOpenPicker;

  const _QuickSelectBlock({
    required this.title,
    required this.requiredLabel,
    required this.options,
    required this.selectedId,
    required this.chipLimit,
    required this.idOf,
    required this.labelOf,
    required this.subtitleBuilder,
    required this.errorText,
    required this.onSelect,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleOptions = _visibleOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredLabel ? '$title *' : title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text(
            'No options available',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in visibleOptions)
                FilterChip(
                  selected: idOf(item) == selectedId,
                  label: Text(
                    labelOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onSelected: (_) => onSelect(idOf(item)),
                  showCheckmark: true,
                ),
              if (options.length > visibleOptions.length)
                ActionChip(
                  avatar: const Icon(Icons.expand_more, size: 18),
                  label: const Text('More'),
                  onPressed: () async {
                    final value = await onOpenPicker();
                    if (value != null && value.isNotEmpty) {
                      onSelect(value);
                    }
                  },
                ),
              if (selectedId != null &&
                  selectedId!.isNotEmpty &&
                  !visibleOptions.any((item) => idOf(item) == selectedId))
                ActionChip(
                  label: Text(
                    _selectedLabel() ?? 'Selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () async {
                    final value = await onOpenPicker();
                    if (value != null && value.isNotEmpty) {
                      onSelect(value);
                    }
                  },
                ),
            ],
          ),
        if (subtitleBuilder != null && selectedId != null) ...[
          const SizedBox(height: 4),
          _selectedSubtitle(context),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  List<T> _visibleOptions() {
    if (options.length <= chipLimit) return options;

    final head = options.take(chipLimit).toList();
    if (selectedId == null || selectedId!.isEmpty) return head;

    final hasSelectedInHead = head.any((item) => idOf(item) == selectedId);
    if (hasSelectedInHead) return head;

    final selectedOption = options.where((item) => idOf(item) == selectedId);
    if (selectedOption.isEmpty) return head;

    final next = [...head];
    next.removeLast();
    next.add(selectedOption.first);
    return next;
  }

  String? _selectedLabel() {
    if (selectedId == null || selectedId!.isEmpty) return null;
    for (final item in options) {
      if (idOf(item) == selectedId) {
        return labelOf(item);
      }
    }
    return null;
  }

  Widget _selectedSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    if (selectedId == null || selectedId!.isEmpty) {
      return const SizedBox.shrink();
    }

    for (final item in options) {
      if (idOf(item) == selectedId) {
        final subtitle = subtitleBuilder?.call(item);
        if (subtitle == null || subtitle.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ValueChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
