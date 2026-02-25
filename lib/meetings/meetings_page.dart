import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import 'pages/meeting_creation/logic/meetings_provider.dart';
import 'pages/attendance/logic/attendance_provider.dart';
import 'pages/meeting_creation/ui/management_tab.dart';
import 'pages/attendance/ui/attendance_tab.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({
    super.key,
  });

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stored in didChangeDependencies â€” never accessed from dispose()
  MeetingsProvider? _meetingsProvider;
  AttendanceProvider? _attendanceProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _meetingsProvider?.init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _meetingsProvider = Provider.of<MeetingsProvider>(context, listen: false);
    _attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    // Attempt to auto-save any pending attendance edits when the page is
    // disposed (user navigated away from Meetings). This is fire-and-forget
    // to avoid blocking dispose; provider will handle errors internally.
    if (_attendanceProvider?.hasUnsavedChanges ?? false) {
      _attendanceProvider?.saveChanges();
    }
    _tabController.dispose();
    super.dispose();
  }

  /// When the user navigates away from the Attendance tab, warn about unsaved
  /// changes via a SnackBar and offer to switch back.
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    // When leaving the Attendance tab (index 1), auto-save any pending
    // changes and show user feedback so edits are not lost.
    if (_tabController.previousIndex == 1) {
      final hasUnsaved = _attendanceProvider?.hasUnsavedChanges ?? false;
      if (hasUnsaved && mounted) {
        // Kick off async save and show interim SnackBar.
        _saveAttendanceAndNotify();
      }
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
    
    // We use a Scaffold with a Stack, similar to homepage, to float the bottom nav bar
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
          labelColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          indicatorColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
          tabs: const [
            Tab(text: 'Management'),
            Tab(text: 'Attendance'),
            Tab(text: 'Scoring'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Use Consumer so AttendanceTab receives updated troop/season
          // whenever an admin changes troop selection in ManagementTab.
          Consumer<MeetingsProvider>(
            builder: (context, meetingsProvider, _) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // â”€â”€ Tab 1: Management â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const ManagementTab(),

                  // â”€â”€ Tab 2: Attendance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  // Pass resolved scope so AttendanceTab can load (and reload
                  // via didUpdateWidget when admin changes troop).
                  AttendanceTab(
                    troopId: meetingsProvider.effectiveTroopId,
                    seasonId: meetingsProvider.activeSeasonId,
                  ),

                  // â”€â”€ Tab 3: Scoring (stub) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const _ScoringTabStub(),
                ],
              );
            },
          ),

          // Floating bottom nav bar
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Scoring tab â€” intentional stub (scoring feature not yet implemented)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ScoringTabStub extends StatelessWidget {
  const _ScoringTabStub();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(height: 16),
              Text(
                'Scoring',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Scoring feature coming soon.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
