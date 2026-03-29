import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/logic/auth_provider.dart';
import '../../auth/models/role.dart';
import '../../auth/models/user_profile.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/settings_dialog.dart';
import 'profile_qr_code_screen.dart';

import 'components/future_modules_section.dart';
import 'components/profile_hero_section.dart';
import 'components/profile_info_row.dart';
import 'components/profile_section.dart';

/// Profile page role visibility guide.
///
/// What this page always shows for all authenticated users:
/// - Hero: full name, email, avatar, and profile QR action.
/// - Personal Info: primary role, patrol role (if any), troop name,
///   phone, birth date, and address.
/// - Roles & Permissions: all assigned role chips and highest rank badge.
/// - Account Specs: joined date, generation, and managed troop scope name.
///
/// Role-specific value behavior:
/// - Patrol roles (rank 20-30 range): Patrol field shows the patrol role name.
/// - Troop-scoped leaders (rank 60/70): Managed Troop Scope resolves from
///   `managedTroopId` and shows the troop name.
/// - System-wide roles (rank 90+): Managed Troop Scope displays
///   `System-wide access` unless an explicit troop context exists.
/// - Public/basic roles without troop mapping: Troop and Managed Troop Scope
///   display `Not assigned`.
///
/// Troop identifiers should never be rendered directly to the user. Any
/// unresolved id is shown as `Unknown troop` while the page tries to resolve
/// the troop name via lookup.
/// Highly refined, premium profile screen utilizing structured cards.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Map<String, dynamic>> _troops = [];
  final Map<String, String> _troopNamesById = {};
  final Set<String> _troopNameLookupAttempted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTroops();
    });
  }

  Future<void> _loadTroops() async {
    final authProvider = context.read<AuthProvider>();
    final troops = await authProvider.getTroops();
    final troopNames = <String, String>{};
    for (final troop in troops) {
      final id = troop['id']?.toString();
      final name = troop['name'] as String?;
      if (id != null && id.isNotEmpty && name != null && name.trim().isNotEmpty) {
        troopNames[id] = name;
      }
    }

    if (mounted) {
      setState(() {
        _troops = troops;
        _troopNamesById
          ..clear()
          ..addAll(troopNames);
      });
    }

    final profile = authProvider.currentUserProfile;
    if (profile != null) {
      await _resolveMissingTroopNames(
        profile,
        authProvider: authProvider,
      );
    }
  }

  String _resolveTroopName(
    String? troopId, {
    required String emptyLabel,
    required String unresolvedLabel,
  }) {
    if (troopId == null) return emptyLabel;
    final normalizedTroopId = troopId.trim();
    if (normalizedTroopId.isEmpty) {
      return emptyLabel;
    }

    final cached = _troopNamesById[normalizedTroopId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    return _troops.isEmpty ? 'Loading troop...' : unresolvedLabel;
  }

  String _resolveManagedTroopScopeValue(UserProfile profile) {
    return _resolveTroopName(
      profile.managedTroopId,
      emptyLabel: _isSystemWideRole(profile)
          ? 'System-wide access'
          : 'Not assigned',
      unresolvedLabel: _isSystemWideRole(profile)
          ? 'Scope troop unavailable'
          : 'Managed troop unavailable',
    );
  }

  bool _isSystemWideRole(UserProfile profile) => profile.roleRank >= 90;

  Future<void> _resolveMissingTroopNames(
    UserProfile profile, {
    AuthProvider? authProvider,
  }) async {
    final provider = authProvider ?? context.read<AuthProvider>();
    final idsToResolve = <String>{
      if (profile.signupTroopId != null) profile.signupTroopId!.trim(),
      if (profile.managedTroopId != null) profile.managedTroopId!.trim(),
    }.where(
      (id) =>
          id.isNotEmpty &&
          !_troopNamesById.containsKey(id) &&
          !_troopNameLookupAttempted.contains(id),
    ).toList();

    if (idsToResolve.isEmpty) {
      return;
    }

    final resolved = <String, String>{};
    for (final troopId in idsToResolve) {
      _troopNameLookupAttempted.add(troopId);
      final name = await provider.getTroopNameById(troopId);
      if (name != null && name.trim().isNotEmpty) {
        resolved[troopId] = name;
      }
    }

    if (!mounted || resolved.isEmpty) {
      return;
    }

    setState(() {
      _troopNamesById.addAll(resolved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authProvider = Provider.of<AuthProvider>(context);
    final UserProfile? profile = authProvider.currentUserProfile;
    final String? profileLoadError = authProvider.profileLoadError;
    final bool profileLoading = authProvider.profileLoading;

    if (profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveMissingTroopNames(profile, authProvider: authProvider);
      });
    }

    // Use a slightly different background to make the white/dark cards pop
    final bgColor = isDark
        ? AppColors.scoutEliteNavy
        : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? AppColors.goldAccent : AppColors.rankBronze,
            ),
            tooltip: 'Edit Profile',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit profile coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? AppColors.goldAccent : AppColors.rankBronze,
            ),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(child: _buildDecorativeBackground(context)),
            profile == null
                ? _buildLoadingOrError(
                    context,
                    profileLoading,
                    profileLoadError,
                    authProvider,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileHeroSection(
                          fullName:
                              profile.fullName ??
                              authProvider.fullName ??
                              'User',
                          email: profile.email,
                          avatarUrl: profile.avatarUrl,
                          onQrTap: () => _showProfileQrCode(
                            context,
                            profile.id,
                            profile.fullName ??
                                authProvider.fullName ??
                                'Member',
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildProfileInfoSection(
                          context,
                          profile,
                          authProvider,
                        ),
                        const SizedBox(height: 32),
                        _buildAccessSection(
                          context,
                          profile,
                          authProvider.userRoles,
                        ),
                        const SizedBox(height: 32),
                        _buildAccountSection(context, profile),
                        const SizedBox(height: 32),
                        const FutureModulesSection(),
                      ],
                    ),
                  ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNavBar(
                currentPage: 'profile',
                isAuthenticated: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoSection(
    BuildContext context,
    UserProfile profile,
    AuthProvider authProvider,
  ) {
    return ProfileSection(
      title: 'Personal Info',
      children: [
        ProfileInfoRow(
          icon: Icons.badge_outlined,
          label: 'Primary Role',
          value: _resolvePrimaryRole(profile.roleRank, authProvider.userRoles),
        ),
        ProfileInfoRow(
          icon: Icons.flag_outlined,
          label: 'Patrol',
          value: _resolvePatrolValue(authProvider.userRoles),
        ),
        ProfileInfoRow(
          icon: Icons.groups_outlined,
          label: 'Troop',
          value: _resolveTroopValue(profile),
        ),
        ProfileInfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile.phone ?? authProvider.userPhone ?? 'Not provided',
        ),
        ProfileInfoRow(
          icon: Icons.cake_outlined,
          label: 'Birth Date',
          value: profile.birthdate != null
              ? DateFormat('MMM dd, yyyy').format(profile.birthdate!)
              : 'Not provided',
        ),
        ProfileInfoRow(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: profile.address ?? 'Not provided',
          isMultiline: true,
        ),
      ],
    );
  }

  Widget _buildAccessSection(
    BuildContext context,
    UserProfile profile,
    List<Role> roles,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final highestRank = _resolveHighestRank(profile.roleRank, roles);

    return ProfileSection(
      title: 'Roles & Permissions',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldAccent.withValues(alpha: isDark ? 0.24 : 0.16),
              AppColors.rankBronze.withValues(alpha: isDark ? 0.2 : 0.12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: AppColors.goldAccent.withValues(alpha: isDark ? 0.38 : 0.24),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Highest Rank $highestRank',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are the roles you hold.',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (roles.isEmpty)
                Text(
                  'You do not hold any roles yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roles.map((role) {
                    final roleAccent = _getRoleAccentColor(role.rank);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: roleAccent.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: roleAccent.withValues(
                            alpha: isDark ? 0.34 : 0.24,
                          ),
                        ),
                      ),
                      child: Text(
                        role.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, UserProfile profile) {
    return ProfileSection(
      title: 'Account Specs',
      children: [
        ProfileInfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Joined On',
          value: DateFormat('MMM dd, yyyy').format(profile.createdAt),
        ),
        ProfileInfoRow(
          icon: Icons.school_outlined,
          label: 'Generation',
          value: profile.generation ?? 'Not provided',
        ),
        ProfileInfoRow(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Managed Troop Scope',
          value: _resolveManagedTroopScopeValue(profile),
          isMultiline: true,
          trailing: _isSystemWideRole(profile)
              ? _buildManagedScopeHelpIcon(context)
              : null,
        ),
      ],
    );
  }

  Widget _buildManagedScopeHelpIcon(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message:
          'System-wide roles are not limited to a single troop, so this value is shown as System-wide access.',
      child: Icon(
        Icons.help_outline,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _resolvePrimaryRole(int roleRank, List<Role> roles) {
    if (roles.isNotEmpty) {
      return roles.first.name;
    }
    return _getAccessLevelName(roleRank);
  }

  int _resolveHighestRank(int fallbackRank, List<Role> roles) {
    if (roles.isEmpty) return fallbackRank;
    return roles.map((role) => role.rank).reduce((a, b) => a > b ? a : b);
  }

  String _resolveTroopValue(UserProfile profile) {
    return _resolveTroopName(
      profile.signupTroopId ?? profile.managedTroopId,
      emptyLabel: 'Not assigned',
      unresolvedLabel: _isSystemWideRole(profile)
          ? 'Troop not applicable'
          : 'Troop unavailable',
    );
  }

  String _resolvePatrolValue(List<Role> roles) {
    for (final role in roles) {
      if (role.name.toLowerCase().contains('patrol')) {
        return role.name;
      }
    }
    return 'Not assigned';
  }

  String _getAccessLevelName(int rank) {
    if (rank == 0) return 'Public';
    if (rank < 20) return 'Basic';
    if (rank < 40) return 'Member';
    if (rank < 60) return 'Advanced';
    if (rank < 80) return 'Senior';
    if (rank < 100) return 'Admin';
    return 'System Admin';
  }

  Color _getRoleAccentColor(int rank) {
    if (rank >= 90) return AppColors.goldAccent;
    if (rank >= 70) return AppColors.rankBronze;
    if (rank >= 50) return AppColors.badgeTeal;
    if (rank >= 30) return AppColors.sectionHeaderGray;
    return AppColors.rankBronze;
  }

  Widget _buildDecorativeBackground(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppColors.scoutEliteNavy,
                        AppColors.cardDarkElevated,
                        AppColors.scoutEliteNavy,
                      ]
                    : [
                        AppColors.backgroundLight,
                        AppColors.surfaceLight,
                        AppColors.backgroundLight,
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: _buildAmbientOrb(
              color: AppColors.goldAccent.withValues(
                alpha: isDark ? 0.2 : 0.12,
              ),
              width: 280,
              height: 220,
              blurSigma: 40,
            ),
          ),
          Positioned(
            top: 190,
            left: -80,
            child: _buildAmbientOrb(
              color: AppColors.badgeTeal.withValues(
                alpha: isDark ? 0.14 : 0.08,
              ),
              width: 250,
              height: 190,
              blurSigma: 36,
            ),
          ),
          Positioned(
            bottom: 120,
            right: 30,
            child: _buildAmbientOrb(
              color: AppColors.rankBronze.withValues(
                alpha: isDark ? 0.12 : 0.07,
              ),
              width: 170,
              height: 140,
              blurSigma: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientOrb({
    required Color color,
    required double width,
    required double height,
    required double blurSigma,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width),
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            stops: const [0.2, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError(
    BuildContext context,
    bool isLoading,
    String? error,
    AuthProvider authProvider,
  ) {
    if (isLoading) {
      return const LoadingView(message: 'Loading profile...');
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorView(message: error, onRetry: authProvider.refreshProfile),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showSettingsDialog(context),
                icon: const Icon(Icons.settings),
                label: const Text('Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return const LoadingView(message: 'Loading profile...');
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }

  void _showProfileQrCode(
    BuildContext context,
    String profileId,
    String profileName,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark
              ? AppColors.cardDarkElevated
              : AppColors.cardLight,
          child: ProfileQrCodeScreen(
            profileId: profileId,
            profileName: profileName,
          ),
        );
      },
    );
  }
}
