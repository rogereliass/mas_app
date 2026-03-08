import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import 'components/troop_selector_banner.dart';
import 'pages/attendance/logic/attendance_provider.dart';
import 'pages/attendance/ui/attendance_tab.dart';
import 'pages/meeting_creation/logic/meetings_provider.dart';
import 'pages/meeting_creation/ui/management_tab.dart';
import 'pages/points/ui/points_tab.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _lastTabIndex = 0;

  // Stored in didChangeDependencies and never accessed from dispose via context.
  MeetingsProvider? _meetingsProvider;
  AttendanceProvider? _attendanceProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _lastTabIndex = _tabController.index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _meetingsProvider?.init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _meetingsProvider = Provider.of<MeetingsProvider>(context, listen: false);
    _attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);

    // Fire-and-forget save to avoid losing unsaved attendance edits.
    if (_attendanceProvider?.hasUnsavedChanges ?? false) {
      _attendanceProvider?.saveChanges();
    }

    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final currentIndex = _tabController.index;

    // Print once whenever tab selection actually changes (tap or swipe).
    if (currentIndex != _lastTabIndex && !_tabController.indexIsChanging) {
      if (kDebugMode) {
        final tabName = _tabNameForIndex(currentIndex);
        debugPrint('[TAB] $tabName');
      }
      _lastTabIndex = currentIndex;
    }

    // Leaving Attendance tab.
    if (_tabController.previousIndex == 1 &&
        _tabController.indexIsChanging) {
      final hasUnsaved = _attendanceProvider?.hasUnsavedChanges ?? false;
      if (hasUnsaved && mounted) {
        _saveAttendanceAndNotify();
      }
    }
  }

  String _tabNameForIndex(int index) {
    switch (index) {
      case 0:
        return 'MANAGEMENT';
      case 1:
        return 'ATTENDANCE';
      case 2:
        return 'POINTS';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> _saveAttendanceAndNotify() async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving attendance changes...'),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      await _attendanceProvider?.saveChanges();
      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Attendance saved.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Meetings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (!kDebugMode) return;
            debugPrint('[TAB_TAP] ${_tabNameForIndex(index)}');
          },
          labelColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
          tabs: const [
            Tab(text: 'Management'),
            Tab(text: 'Attendance'),
            Tab(text: 'Points'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Consumer<MeetingsProvider>(
            builder: (context, meetingsProvider, _) {
              return Column(
                children: [
                  if (meetingsProvider.isAdmin)
                    TroopSelectorBanner(
                      troops: meetingsProvider.troops,
                      selectedTroopId: meetingsProvider.selectedTroopId,
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        const ManagementTab(),
                        AttendanceTab(
                          troopId: meetingsProvider.effectiveTroopId,
                          seasonId: meetingsProvider.activeSeasonId,
                        ),
                        PointsTab(
                          troopId: meetingsProvider.effectiveTroopId,
                          seasonId: meetingsProvider.activeSeasonId,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNavBar(
              currentPage: 'meetings',
              isAuthenticated: true,
            ),
          ),
        ],
      ),
    );
  }
}
