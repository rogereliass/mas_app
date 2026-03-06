import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';
import 'package:masapp/meetings/pages/meeting_creation/logic/meetings_provider.dart';

/// Dialog for editing an existing [Meeting].
///
/// Mirrors [CreateMeetingDialog] UX but starts prefilled and keeps the
/// save action disabled until changes are detected.
class EditMeetingDialog extends StatefulWidget {
  final Meeting meeting;

  const EditMeetingDialog({super.key, required this.meeting});

  @override
  State<EditMeetingDialog> createState() => _EditMeetingDialogState();
}

class _EditMeetingDialogState extends State<EditMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  final _dateDisplayController = TextEditingController();
  final _startTimeDisplayController = TextEditingController();
  final _endTimeDisplayController = TextEditingController();

  DateTime? _meetingDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  late final String _initialTitle;
  late final String _initialLocation;
  late final String? _initialDescription;
  late final int? _initialPrice;
  late final DateTime? _initialMeetingDate;
  late final TimeOfDay? _initialStartTime;
  late final TimeOfDay? _initialEndTime;

  bool _hasChanges = false;
  String? _modalError;

  @override
  void initState() {
    super.initState();
    _initializeFromMeeting();
    _titleController.addListener(_onFormChanged);
    _locationController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _priceController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _locationController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _priceController.removeListener(_onFormChanged);
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _dateDisplayController.dispose();
    _startTimeDisplayController.dispose();
    _endTimeDisplayController.dispose();
    super.dispose();
  }

  void _initializeFromMeeting() {
    final meeting = widget.meeting;

    _initialTitle = meeting.title.trim();
    _initialLocation = (meeting.location ?? '').trim();
    _initialDescription = _normalizeOptionalText(meeting.description);
    _initialPrice = _normalizeModelPrice(meeting.price);
    _initialMeetingDate = DateTime(
      meeting.meetingDate.year,
      meeting.meetingDate.month,
      meeting.meetingDate.day,
    );
    _initialStartTime = meeting.startsAt != null
        ? TimeOfDay.fromDateTime(meeting.startsAt!)
        : null;
    _initialEndTime = meeting.endsAt != null
        ? TimeOfDay.fromDateTime(meeting.endsAt!)
        : null;

    _meetingDate = _initialMeetingDate;
    _startTime = _initialStartTime;
    _endTime = _initialEndTime;

    _titleController.text = meeting.title;
    _locationController.text = meeting.location ?? '';
    _descriptionController.text = meeting.description ?? '';
    _priceController.text = _initialPrice?.toString() ?? '';
    _dateDisplayController.text = _meetingDate != null
        ? _formatDate(_meetingDate!)
        : '';
    _startTimeDisplayController.text = _startTime != null
        ? _formatTime(_startTime!)
        : '';
    _endTimeDisplayController.text = _endTime != null
        ? _formatTime(_endTime!)
        : '';
  }

  void _onFormChanged() {
    final hasChanges = _computeHasChanges();
    if (hasChanges != _hasChanges && mounted) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  bool _computeHasChanges() {
    final currentTitle = _titleController.text.trim();
    final currentLocation = _locationController.text.trim();
    final currentDescription = _normalizeOptionalText(
      _descriptionController.text,
    );

    final rawPrice = _priceController.text.trim();
    final parsedPrice = _parsePrice(rawPrice);
    final isInvalidPrice = rawPrice.isNotEmpty && parsedPrice == null;

    final titleChanged = currentTitle != _initialTitle;
    final locationChanged = currentLocation != _initialLocation;
    final descriptionChanged = currentDescription != _initialDescription;
    final priceChanged = isInvalidPrice || parsedPrice != _initialPrice;
    final meetingDateChanged = !_sameDate(_meetingDate, _initialMeetingDate);
    final startChanged = !_sameTime(_startTime, _initialStartTime);
    final endChanged = !_sameTime(_endTime, _initialEndTime);

    return titleChanged ||
        locationChanged ||
        descriptionChanged ||
        priceChanged ||
        meetingDateChanged ||
        startChanged ||
        endChanged;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$min $period';
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  int? _normalizeModelPrice(double? value) {
    if (value == null) return null;
    if (value % 1 != 0) return null;
    return value.toInt();
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parsePrice(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^-?\d+$').hasMatch(normalized)) return null;
    return int.tryParse(normalized);
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameTime(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return a == b;
    return a.hour == b.hour && a.minute == b.minute;
  }

  String _mapUpdateError(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('smallint') ||
        lower.contains('22p02') ||
        lower.contains('invalid input syntax for type')) {
      return 'Price must be a whole number between 1 and 32,767 EGP.';
    }
    if (lower.contains('between 0 and 32767') ||
        lower.contains('between 1 and 32767') ||
        lower.contains('greater than 0')) {
      return 'Price must be a whole number between 1 and 32,767 EGP.';
    }
    return 'Failed to update meeting. Please review the form and try again.';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null && mounted) {
      setState(() {
        _meetingDate = picked;
        _dateDisplayController.text = _formatDate(picked);
        _hasChanges = _computeHasChanges();
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
        _hasChanges = _computeHasChanges();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 20, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
        _endTimeDisplayController.text = _formatTime(picked);
        _hasChanges = _computeHasChanges();
      });
    }
  }

  Future<void> _submit(MeetingsProvider provider) async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_hasChanges) return;

    setState(() {
      _modalError = null;
    });

    await provider.updateMeeting(
      meetingId: widget.meeting.id,
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      meetingDate: _meetingDate!,
      startsAt: _combine(_meetingDate!, _startTime!),
      endsAt: _combine(_meetingDate!, _endTime!),
      description: _normalizeOptionalText(_descriptionController.text),
      price: _parsePrice(_priceController.text),
    );

    if (!mounted) return;

    if (provider.error != null) {
      setState(() {
        _modalError = _mapUpdateError(provider.error!);
      });
      provider.clearError();
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? AppColors.cardDarkElevated
          : AppColors.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Consumer<MeetingsProvider>(
              builder: (context, provider, _) {
                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Meeting',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_modalError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _modalError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _titleController,
                        label: 'Meeting Title',
                        hint: 'e.g. Weekly Troop Meeting',
                        theme: theme,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Please enter a meeting title'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _locationController,
                        label: 'Location',
                        hint: 'e.g. Community Hall',
                        theme: theme,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Please enter a location'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dateDisplayController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: _inputDecoration(
                          label: 'Date',
                          hint: 'Select date',
                          suffixIcon: Icons.calendar_today_outlined,
                          theme: theme,
                        ),
                        validator: (_) {
                          if (_meetingDate == null) {
                            return 'Please select a date';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startTimeDisplayController,
                              readOnly: true,
                              onTap: _pickStartTime,
                              decoration: _inputDecoration(
                                label: 'Start Time',
                                hint: '6:00 PM',
                                suffixIcon: Icons.access_time_outlined,
                                theme: theme,
                              ),
                              validator: (_) => _startTime == null
                                  ? 'Please select a start time'
                                  : null,
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
                                hint: '8:00 PM',
                                suffixIcon: Icons.access_time_outlined,
                                theme: theme,
                              ),
                              validator: (_) {
                                if (_endTime == null) {
                                  return 'Please select an end time';
                                }
                                if (_meetingDate != null &&
                                    _startTime != null &&
                                    _endTime != null) {
                                  final startsAt = _combine(
                                    _meetingDate!,
                                    _startTime!,
                                  );
                                  final endsAt = _combine(
                                    _meetingDate!,
                                    _endTime!,
                                  );
                                  if (!endsAt.isAfter(startsAt)) {
                                    return 'End time must be after start time';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'Price (optional)',
                          hint: '5',
                          theme: theme,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = _parsePrice(v);
                          if (parsed == null) {
                            return 'Enter a valid whole number';
                          }
                          if (parsed <= 0) {
                            return 'Price must be greater than 0';
                          }
                          if (parsed > 32767) {
                            return 'Price must be 32,767 or less';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description (optional)',
                        hint: 'Any additional details...',
                        theme: theme,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: provider.isUpdating
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (provider.isUpdating || !_hasChanges)
                                ? null
                                : () => _submit(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.goldAccent
                                  : AppColors.primaryBlue,
                              foregroundColor: isDark
                                  ? AppColors.textPrimaryLight
                                  : theme.colorScheme.onPrimary,
                              disabledBackgroundColor:
                                  (isDark
                                          ? AppColors.goldAccent
                                          : AppColors.primaryBlue)
                                      .withValues(alpha: 0.45),
                              disabledForegroundColor:
                                  (isDark
                                          ? AppColors.textPrimaryLight
                                          : theme.colorScheme.onPrimary)
                                      .withValues(alpha: 0.8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            child: provider.isUpdating
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  )
                                : const Text('Save Changes'),
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
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeData theme,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(label: label, hint: hint, theme: theme),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required ThemeData theme,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffixIcon != null
          ? Icon(
              suffixIcon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}
