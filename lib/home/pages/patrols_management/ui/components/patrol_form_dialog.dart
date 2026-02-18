import 'package:flutter/material.dart';

import '../../data/models/patrol.dart';
import '../../data/models/troop_member.dart';

class PatrolFormResult {
  final String name;
  final String? description;
  final String? patrolLeaderProfileId;

  const PatrolFormResult({
    required this.name,
    required this.description,
    this.patrolLeaderProfileId,
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

  bool get _isEditMode => widget.initialPatrol != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPatrol?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialPatrol?.description ?? '',
    );
    _selectedLeaderId = widget.initialPatrol?.patrolLeaderProfileId;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Edit Patrol' : 'Create Patrol',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Patrol Name *',
                    hintText: 'Enter patrol name',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional patrol description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Leader dropdown only shown in edit mode, and only with patrol members
                if (_isEditMode && widget.leaderCandidates.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedLeaderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Patrol Leader (optional)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'No leader assigned',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                      ...widget.leaderCandidates.map(
                        (member) => DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_isEditMode ? 'Save Changes' : 'Create Patrol'),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      PatrolFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        patrolLeaderProfileId: _selectedLeaderId,
      ),
    );
  }
}
