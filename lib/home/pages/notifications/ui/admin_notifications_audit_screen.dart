import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../data/models/notification_audit_models.dart';
import '../data/models/notification_models.dart';
import '../data/notification_audit_service.dart';
import 'components/notification_audit_item.dart';
import 'components/notification_audit_modal.dart';

class AdminNotificationsAuditScreen extends StatefulWidget {
  const AdminNotificationsAuditScreen({super.key});

  @override
  State<AdminNotificationsAuditScreen> createState() =>
      _AdminNotificationsAuditScreenState();
}

class _AdminNotificationsAuditScreenState
    extends State<AdminNotificationsAuditScreen> {
  final NotificationAuditService _service = NotificationAuditService.instance();

  List<NotificationAuditEntry> _entries = const <NotificationAuditEntry>[];
  bool _isLoading = false;
  String? _error;
  NotificationType? _selectedType;
  NotificationTargetType? _selectedTargetType;
  String? _selectedTroopId;
  List<NotificationTargetOption> _troopOptions = const <NotificationTargetOption>[];
  bool _hasLoaded = false;
  bool _isLoadingTroops = false;
  int _activeLoadToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasLoaded) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final isAuthorized = authProvider.selectedRoleRank >= 90;
    if (!isAuthorized) {
      _hasLoaded = true;
      return;
    }

    _hasLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadTroops();
      _load();
    });
  }

  Future<void> _loadTroops() async {
    setState(() => _isLoadingTroops = true);
    try {
      final troops = await _service.fetchFilterTroops();
      if (!mounted) return;
      setState(() {
        _troopOptions = troops;
        _isLoadingTroops = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTroops = false;
        _error = _mapUserFacingError(
          e,
          fallback: 'Could not load troop scope options.',
        );
      });
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final int requestToken = ++_activeLoadToken;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _service.fetchAuditEntries(
        limit: 40,
        type: _selectedType,
        targetType: _selectedTargetType,
        troopId: _selectedTroopId,
        forceRefresh: forceRefresh,
      );

      if (!mounted || requestToken != _activeLoadToken) {
        return;
      }

      setState(() {
        _entries = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestToken != _activeLoadToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _mapUserFacingError(
          e,
          fallback: 'Failed to load notification audit data.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();

    final isAuthorized = authProvider.selectedRoleRank >= 90;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications Audit'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _load(forceRefresh: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !isAuthorized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Access denied. This screen is limited to Management Roles.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<NotificationType?>(
                              value: _selectedType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Sender Type',
                              ),
                              items: _buildTypeItems(),
                              onChanged: _isLoading ? null : (value) {
                                setState(() => _selectedType = value);
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<NotificationTargetType?>(
                              value: _selectedTargetType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Target Type',
                              ),
                              items: _buildTargetTypeItems(),
                              onChanged: _isLoading ? null : (value) {
                                setState(() {
                                  _selectedTargetType = value;
                                  if (value == NotificationTargetType.all) {
                                    _selectedTroopId = null;
                                  }
                                });
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_selectedTargetType != NotificationTargetType.all) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: _selectedTroopId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Specific Troop Scope',
                            suffixIcon: _isLoadingTroops 
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : null,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Troops'),
                            ),
                            ..._troopOptions.map((t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(t.label),
                                )),
                          ],
                          onChanged: _isLoading ? null : (value) {
                            setState(() => _selectedTroopId = value);
                            _load();
                          },
                        ),
                        if (!_isLoadingTroops && _troopOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'No troop options available for filtering.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No sent notifications found for the selected filter.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return NotificationAuditItem(
            key: ValueKey(entry.id),
            entry: entry,
            onTap: () => _openDetails(context, entry),
          );
        },
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    NotificationAuditEntry entry,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => NotificationAuditModal(entry: entry),
    );
  }

  List<DropdownMenuItem<NotificationType?>> _buildTypeItems() {
    return [
      const DropdownMenuItem<NotificationType?>(
        value: null,
        child: Text('All Senders'),
      ),
      ...NotificationType.values.map((type) => DropdownMenuItem<NotificationType?>(
            value: type,
            child: Text(_typeLabel(type)),
          )),
    ];
  }

  List<DropdownMenuItem<NotificationTargetType?>> _buildTargetTypeItems() {
    return [
      const DropdownMenuItem<NotificationTargetType?>(
        value: null,
        child: Text('All Targets'),
      ),
      ...NotificationTargetType.values.map((type) => DropdownMenuItem<NotificationTargetType?>(
            value: type,
            child: Text(_targetTypeLabel(type)),
          )),
    ];
  }

  String _targetTypeLabel(NotificationTargetType type) {
    switch (type) {
      case NotificationTargetType.all:
        return 'Broadcast';
      case NotificationTargetType.troop:
        return 'Troops';
      case NotificationTargetType.patrol:
        return 'Patrols';
      case NotificationTargetType.individual:
        return 'Members';
    }
  }

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return 'System';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.meeting:
        return 'Meeting';
      case NotificationType.attendance:
        return 'Attendance';
      case NotificationType.points:
        return 'Points';
    }
  }

  String _mapUserFacingError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return fallback;
    }

    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('row-level security') ||
        lower.contains('rls') ||
        lower.contains('denied')) {
      return 'You are not allowed to view this audit data.';
    }

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'Network issue. Please check your connection and try again.';
    }

    return fallback;
  }
}
