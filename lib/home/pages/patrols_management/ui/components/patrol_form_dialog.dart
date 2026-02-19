import 'package:flutter/material.dart';

import '../../data/models/patrol.dart';
import '../../data/models/troop_member.dart';

class PatrolFormResult {
  final String name;
  final String? description;
  final String? patrolLeaderProfileId;
  final String? assistant1ProfileId;
  final String? assistant2ProfileId;

  const PatrolFormResult({
    required this.name,
    required this.description,
    this.patrolLeaderProfileId,
    this.assistant1ProfileId,
    this.assistant2ProfileId,
  });
}

class PatrolFormDialog extends StatefulWidget {
  final Patrol? initialPatrol;
  /// Members eligible to be patrol leader.
  /// Pass an empty list (or omit via create path) to hide the leader field.
  final List<TroopMember> leaderCandidates;

  const PatrolFormDialog({
    super.key,
    this.initialPatrol,
    this.leaderCandidates = const [],
  });

  @override
  State<PatrolFormDialog> createState() => _PatrolFormDialogState();
}

class _PatrolFormDialogState extends State<PatrolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _selectedLeaderId;
  String? _selectedAssistant1Id;
  String? _selectedAssistant2Id;

  bool get _isEditMode => widget.initialPatrol != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPatrol?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialPatrol?.description ?? '',
    );
    _selectedLeaderId = widget.initialPatrol?.patrolLeaderProfileId;
    _selectedAssistant1Id = widget.initialPatrol?.assistant1ProfileId;
    _selectedAssistant2Id = widget.initialPatrol?.assistant2ProfileId;

    // Refresh on type to update RTL/LTR alignment
    _nameController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
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

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditMode ? Icons.edit_note_outlined : Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _isEditMode ? 'Edit Patrol' : 'Create New Patrol',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General Info',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        maxLength: 50,
                        textAlign: RegExp(r'[\u0600-\u06FF]').hasMatch(_nameController.text) ? TextAlign.right : TextAlign.left,
                        textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(_nameController.text) ? TextDirection.rtl : TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'Patrol Name *',
                          hintText: 'e.g. Eagle Patrol',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Patrol name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                        maxLength: 180,
                        textAlign: RegExp(r'[\u0600-\u06FF]').hasMatch(_descriptionController.text) ? TextAlign.right : TextAlign.left,
                        textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(_descriptionController.text) ? TextDirection.rtl : TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Tell us a bit about this patrol',
                          prefixIcon: const Icon(Icons.description_outlined, size: 20),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                      ),
                      
                      if (_isEditMode && widget.leaderCandidates.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Leadership',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          value: _selectedLeaderId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Patrol Leader',
                            prefixIcon: const Icon(Icons.star_outline, size: 20),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'No leader assigned',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                            ...widget.leaderCandidates
                                .where((member) =>
                                    member.id != _selectedAssistant1Id &&
                                    member.id != _selectedAssistant2Id)
                                .map(
                              (member) => DropdownMenuItem<String?>(
                                value: member.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        member.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (member.id == widget.initialPatrol?.patrolLeaderProfileId)
                                      _buildStarBadge(3, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant1ProfileId)
                                      _buildStarBadge(2, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant2ProfileId)
                                      _buildStarBadge(1, Colors.amber),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedLeaderId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          value: _selectedAssistant1Id,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Patrol Assistant 1',
                            prefixIcon: const Icon(Icons.star_half_outlined, size: 20),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'No assistant assigned',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                            ...widget.leaderCandidates
                                .where((member) =>
                                    member.id != _selectedLeaderId &&
                                    member.id != _selectedAssistant2Id)
                                .map(
                              (member) => DropdownMenuItem<String?>(
                                value: member.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        member.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (member.id == widget.initialPatrol?.patrolLeaderProfileId)
                                      _buildStarBadge(3, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant1ProfileId)
                                      _buildStarBadge(2, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant2ProfileId)
                                      _buildStarBadge(1, Colors.amber),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAssistant1Id = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          value: _selectedAssistant2Id,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Patrol Assistant 2',
                            prefixIcon: const Icon(Icons.star_half_outlined, size: 20),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'No assistant assigned',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                            ...widget.leaderCandidates
                                .where((member) =>
                                    member.id != _selectedLeaderId &&
                                    member.id != _selectedAssistant1Id)
                                .map(
                              (member) => DropdownMenuItem<String?>(
                                value: member.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        member.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (member.id == widget.initialPatrol?.patrolLeaderProfileId)
                                      _buildStarBadge(3, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant1ProfileId)
                                      _buildStarBadge(2, Colors.amber)
                                    else if (member.id == widget.initialPatrol?.assistant2ProfileId)
                                      _buildStarBadge(1, Colors.amber),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAssistant2Id = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isEditMode ? 'Save Changes' : 'Create Patrol'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarBadge(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (index) => Icon(Icons.star, size: 10, color: color),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      PatrolFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        patrolLeaderProfileId: _selectedLeaderId,
        assistant1ProfileId: _selectedAssistant1Id,
        assistant2ProfileId: _selectedAssistant2Id,
      ),
    );
  }
}
