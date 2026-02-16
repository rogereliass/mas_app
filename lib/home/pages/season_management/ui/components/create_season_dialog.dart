import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/season_management_provider.dart';

class CreateSeasonDialog extends StatefulWidget {
  const CreateSeasonDialog({super.key});

  @override
  State<CreateSeasonDialog> createState() => _CreateSeasonDialogState();
}

class _CreateSeasonDialogState extends State<CreateSeasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _selectedYear = DateTime.now().year.toString();
  String _selectedSeasonType = 'F'; // Default to Fall
  DateTime? _startDate;
  DateTime? _endDate;
  String? _validationError; // Local validation error message

  final List<String> _years = [
    (DateTime.now().year - 1).toString(),
    DateTime.now().year.toString(),
    (DateTime.now().year + 1).toString(),
  ];

  final Map<String, Map<String, String>> _seasonDetails = {
    'F': {'name': 'Fall', 'range': 'Sep - Jan'},
    'W': {'name': 'Winter', 'range': 'Feb - May'},
    'S': {'name': 'Summer', 'range': 'June - Aug'},
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? (_startDate?.add(const Duration(days: 90)) ?? DateTime.now())),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Auto-adjust end date if it's before start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
        // Clear validation error when user selects a date
        _validationError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SeasonManagementProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.calendar_today_rounded, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'New Season',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Selection Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildDropdownField(
                        label: 'Year',
                        value: _selectedYear,
                        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                        onChanged: (v) => setState(() => _selectedYear = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildDropdownField(
                        label: 'Season',
                        value: _selectedSeasonType,
                        items: _seasonDetails.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center, // Center in menu
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.value['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(e.value['range']!, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 10)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedSeasonType = v!),
                        selectedItemBuilder: (context) {
                          return _seasonDetails.entries.map((e) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                e.value['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Generated Code Display
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.secondary.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Season ID: $_selectedYear-$_selectedSeasonType',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Descriptive Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Season Display Name',
                    hintText: 'e.g. Winter Training Phase 1',
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                    helperText: 'Optional descriptive name for this season',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Mandatory Dates Header
                Row(
                  children: [
                    Icon(Icons.date_range_outlined, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Season Duration', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('*Required', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.error)),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerTile(
                        context,
                        label: 'Start Date',
                        selectedDate: _startDate,
                        onTap: () => _selectDate(context, true),
                        isValid: provider.error == null || _startDate != null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDatePickerTile(
                        context,
                        label: 'End Date',
                        selectedDate: _endDate,
                        onTap: () => _selectDate(context, false),
                        isValid: provider.error == null || _endDate != null,
                      ),
                    ),
                  ],
                ),
                
                // Validation Message Display (Subtle)
                if (_validationError != null || provider.hasError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _validationError ?? provider.error ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              height: 1.2,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.isProcessing ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: provider.isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Create Season', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    List<Widget> Function(BuildContext)? selectedItemBuilder,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      selectedItemBuilder: selectedItemBuilder,
      itemHeight: 60, // Increased to fit the two-line premium menu items
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDatePickerTile(
    BuildContext context, {
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    bool isValid = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedDate != null
                ? colorScheme.primary
                : (isValid ? colorScheme.outline : colorScheme.error),
          ),
          color: selectedDate != null ? colorScheme.primaryContainer.withOpacity(0.1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_available, size: 16, color: selectedDate != null ? colorScheme.primary : colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null ? selectedDate.toString().split(' ')[0] : 'Pick Date',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selectedDate != null ? FontWeight.bold : FontWeight.normal,
                    color: selectedDate != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() async {
    final provider = context.read<SeasonManagementProvider>();
    
    // Clear previous validation errors
    setState(() => _validationError = null);
    
    // Manual validation for dates
    if (_startDate == null && _endDate == null) {
      setState(() => _validationError = 'Please select both Start Date and End Date to create a season.');
      return;
    }
    
    if (_startDate == null) {
      setState(() => _validationError = 'Start Date is required. Please select a start date for the season.');
      return;
    }
    
    if (_endDate == null) {
      setState(() => _validationError = 'End Date is required. Please select an end date for the season.');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _validationError = 'Invalid date range. The End Date cannot be before the Start Date.');
      return;
    }

    if (_formKey.currentState!.validate()) {
      final success = await provider.createSeason(
        year: _selectedYear,
        seasonType: _selectedSeasonType,
        name: _nameController.text,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }
}
