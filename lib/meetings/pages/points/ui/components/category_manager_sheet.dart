import 'package:flutter/material.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/points/data/models/point_category.dart';

import 'category_form_sheet.dart';

typedef CreateCategoryCallback =
    Future<PointCategory> Function({required String name, String? description});

typedef UpdateCategoryCallback =
    Future<PointCategory> Function({
      required String categoryId,
      required String name,
      String? description,
    });

/// Bottom sheet for viewing and managing point categories.
class CategoryManagerSheet extends StatefulWidget {
  final List<PointCategory> categories;
  final bool canManageCategories;
  final CreateCategoryCallback? onCreateCategory;
  final UpdateCategoryCallback? onUpdateCategory;

  const CategoryManagerSheet({
    super.key,
    required this.categories,
    required this.canManageCategories,
    this.onCreateCategory,
    this.onUpdateCategory,
  });

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  late List<PointCategory> _categories;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _categories = _sorted(widget.categories);
  }

  @override
  void didUpdateWidget(CategoryManagerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _categories = _sorted(widget.categories);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final globalCategories = _categories.where((c) => c.isGlobal).toList();
    final troopCategories = _categories.where((c) => !c.isGlobal).toList();

    return SafeArea(
      top: false,
      child: Material(
        color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 720),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                      Icon(Icons.category_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.canManageCategories
                              ? 'Manage Categories'
                              : 'Categories',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () =>
                            Navigator.of(context).pop<String?>(null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.canManageCategories
                        ? 'Create or edit troop categories. Global categories are read-only.'
                        : 'Global and troop categories for this scope.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: _inlineError!),
                  ],
                  if (widget.canManageCategories) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openCreateForm,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Category'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _CategorySection(
                    title: 'Global Categories',
                    emptyMessage: 'No global categories configured.',
                    categories: globalCategories,
                    isEditable: false,
                    onEdit: null,
                  ),
                  const SizedBox(height: 14),
                  _CategorySection(
                    title: 'Troop Categories',
                    emptyMessage: widget.canManageCategories
                        ? 'No troop categories yet. Create your first category.'
                        : 'No troop categories yet.',
                    categories: troopCategories,
                    isEditable: widget.canManageCategories,
                    onEdit: _openEditForm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm() async {
    final createCallback = widget.onCreateCategory;
    if (createCallback == null) return;

    PointCategory? savedCategory;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CategoryFormSheet(
          onSubmit: (name, description) async {
            final created = await createCallback(
              name: name,
              description: description,
            );
            savedCategory = created;
          },
        );
      },
    );

    if (!mounted || savedCategory == null) return;

    _upsertCategory(savedCategory!);
    Navigator.of(context).pop<String>(savedCategory!.id);
  }

  Future<void> _openEditForm(PointCategory category) async {
    final updateCallback = widget.onUpdateCategory;
    if (updateCallback == null) return;

    PointCategory? savedCategory;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CategoryFormSheet(
          initialCategory: category,
          onSubmit: (name, description) async {
            final updated = await updateCallback(
              categoryId: category.id,
              name: name,
              description: description,
            );
            savedCategory = updated;
          },
        );
      },
    );

    if (!mounted || savedCategory == null) return;

    _upsertCategory(savedCategory!);
    Navigator.of(context).pop<String>(savedCategory!.id);
  }

  void _upsertCategory(PointCategory category) {
    final next = [..._categories];
    final index = next.indexWhere((item) => item.id == category.id);
    if (index >= 0) {
      next[index] = category;
    } else {
      next.add(category);
    }

    setState(() {
      _inlineError = null;
      _categories = _sorted(next);
    });
  }

  List<PointCategory> _sorted(List<PointCategory> categories) {
    final next = [...categories];
    next.sort((a, b) {
      if (a.isGlobal != b.isGlobal) {
        return a.isGlobal ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return next;
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<PointCategory> categories;
  final bool isEditable;
  final ValueChanged<PointCategory>? onEdit;

  const _CategorySection({
    required this.title,
    required this.emptyMessage,
    required this.categories,
    required this.isEditable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              emptyMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  _CategoryTile(
                    category: categories[i],
                    isEditable: isEditable,
                    onEdit: onEdit,
                  ),
                  if (i != categories.length - 1)
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final PointCategory category;
  final bool isEditable;
  final ValueChanged<PointCategory>? onEdit;

  const _CategoryTile({
    required this.category,
    required this.isEditable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(
        category.isGlobal ? Icons.public_outlined : Icons.shield_outlined,
        color: colorScheme.primary,
      ),
      title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        category.description?.trim().isNotEmpty == true
            ? category.description!
            : (category.isGlobal ? 'Global category' : 'Troop category'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isEditable
          ? IconButton(
              tooltip: 'Edit category',
              onPressed: () => onEdit?.call(category),
              icon: const Icon(Icons.edit_outlined),
            )
          : Text(
              'Read-only',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
