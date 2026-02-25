import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/meeting_creation/logic/meetings_provider.dart';

/// Dialog for scheduling a new meeting.
/// Uses a [Dialog] widget (not AlertDialog) with constrained max width.
class CreateMeetingDialog extends StatefulWidget {
  const CreateMeetingDialog({super.key});

  @override
  State<CreateMeetingDialog> createState() => _CreateMeetingDialogState();
}

class _CreateMeetingDialogState extends State<CreateMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _meetingDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Display controllers for the read-only date/time fields
  final _dateDisplayController = TextEditingController();
  final _startTimeDisplayController = TextEditingController();
  final _endTimeDisplayController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _dateDisplayController.dispose();
    _startTimeDisplayController.dispose();
    _endTimeDisplayController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _meetingDate = picked;
        _dateDisplayController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _startTimeDisplayController.text = _formatTime(picked);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          (_startTime != null
              ? TimeOfDay(
                  hour: (_startTime!.hour + 2) % 24,
                  minute: _startTime!.minute,
                )
              : const TimeOfDay(hour: 20, minute: 0)),
    );
    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
        _endTimeDisplayController.text = _formatTime(picked);
      });
    }
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit(MeetingsProvider provider) async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Validate form fields (this triggers field-level validators which
    // render red borders / helper text). If invalid, abort — do not use
    // SnackBar for validation failures because the dialog can obscure it.
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    // At this point validators guarantee non-null values
    final startsAt = _combine(_meetingDate!, _startTime!);
    final endsAt = _combine(_meetingDate!, _endTime!);

    try {
      await provider.createMeeting(
        title: _titleController.text.trim(),
        location: _locationController.text.trim(),
        meetingDate: _meetingDate!,
        startsAt: startsAt,
        endsAt: endsAt,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      if (mounted && provider.error == null) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Surface unexpected errors via SnackBar
      _showError('Failed to create meeting: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Consumer<MeetingsProvider>(
              builder: (context, provider, _) {
                // Show provider-level error if any
                if (provider.error != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showError(provider.error!);
                      provider.clearError();
                    }
                  });
                }

                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Schedule Meeting',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Meeting Title field
                      _buildTextField(
                        context: context,
                        controller: _titleController,
                        label: 'Meeting Title',
                        hint: 'e.g. Weekly Troop Meeting',
                        isDark: isDark,
                        theme: theme,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Please enter a meeting title' : null,
                      ),
                      const SizedBox(height: 14),

                      // Location field
                      _buildTextField(
                        context: context,
                        controller: _locationController,
                        label: 'Location',
                        hint: 'e.g. Community Hall',
                        isDark: isDark,
                        theme: theme,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Please enter a location' : null,
                      ),
                      const SizedBox(height: 14),

                      // Date field (read-only, tap to pick)
                      TextFormField(
                        controller: _dateDisplayController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: _inputDecoration(
                          label: 'Date',
                          hint: 'Select date',
                          suffixIcon: Icons.calendar_today_outlined,
                          isDark: isDark,
                          theme: theme,
                        ),
                        validator: (_) {
                          if (_meetingDate == null) return 'Please select a date';
                          final now = DateTime.now();
                          final selected = DateTime(_meetingDate!.year, _meetingDate!.month, _meetingDate!.day);
                          final today = DateTime(now.year, now.month, now.day);
                          if (selected.isBefore(today)) return 'Date cannot be in the past';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Start time & End time in a row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startTimeDisplayController,
                              readOnly: true,
                              onTap: _pickStartTime,
                              decoration: _inputDecoration(
                                label: 'Start Time',
                                hint: '18:00',
                                suffixIcon: Icons.access_time_outlined,
                                isDark: isDark,
                                theme: theme,
                              ),
                              validator: (_) => _startTime == null ? 'Please select a start time' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _endTimeDisplayController,
                              readOnly: true,
                              onTap: _pickEndTime,
                              decoration: _inputDecoration(
                                label: 'End Time',
                                hint: '20:00',
                                suffixIcon: Icons.access_time_outlined,
                                isDark: isDark,
                                theme: theme,
                              ),
                              validator: (_) {
                                if (_endTime == null) return 'Please select an end time';
                                if (_meetingDate != null && _startTime != null && _endTime != null) {
                                  final startsAt = _combine(_meetingDate!, _startTime!);
                                  final endsAt = _combine(_meetingDate!, _endTime!);
                                  if (!endsAt.isAfter(startsAt)) return 'End time must be after start time';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description field (optional)
                      _buildTextField(
                        context: context,
                        controller: _descriptionController,
                        label: 'Description (optional)',
                        hint: 'Any additional details...',
                        isDark: isDark,
                        theme: theme,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: provider.isCreating
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: provider.isCreating
                                ? null
                                : () => _submit(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.goldAccent
                                  : AppColors.primaryBlue,
                              foregroundColor: isDark
                                  ? AppColors.textPrimaryLight
                                  : theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: provider.isCreating
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  )
                                : const Text('Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required ThemeData theme,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        isDark: isDark,
        theme: theme,
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required bool isDark,
    required ThemeData theme,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, size: 18, color: theme.colorScheme.onSurfaceVariant)
          : null,
    );
  }
}
