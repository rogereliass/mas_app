import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/eftekad_config.dart';
import '../data/models/eftekad_member.dart';
import '../data/models/eftekad_record.dart';
import '../logic/eftekad_provider.dart';

class EftekadPage extends StatefulWidget {
  const EftekadPage({super.key});

  @override
  State<EftekadPage> createState() => _EftekadPageState();
}

class _EftekadPageState extends State<EftekadPage> {
  final TextEditingController _searchController = TextEditingController();

  AuthProvider? _authProvider;
  bool _initialized = false;
  bool _isAuthListenerAttached = false;
  String? _lastResolvedRoleContext;
  bool _accessDeniedHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryInitialize();
  }

  void _tryInitialize() {
    _authProvider ??= context.read<AuthProvider>();
    final authProvider = _authProvider!;

    if (authProvider.profileLoading ||
        authProvider.currentUserProfile == null) {
      if (!_isAuthListenerAttached) {
        authProvider.addListener(_onAuthChanged);
        _isAuthListenerAttached = true;
      }
      return;
    }

    if (_isAuthListenerAttached) {
      authProvider.removeListener(_onAuthChanged);
      _isAuthListenerAttached = false;
    }

    final roleContext = authProvider.selectedRoleName;
    var effectiveRank = roleContext != null
        ? authProvider.getRankForRole(roleContext)
        : authProvider.currentUserRoleRank;

    if (effectiveRank <= 0) {
      effectiveRank = authProvider.currentUserRoleRank;
    }

    if (effectiveRank < 60) {
      if (_accessDeniedHandled) {
        return;
      }

      _accessDeniedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Access Denied: Eftekad requires rank 60 or above.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      });
      return;
    }

    _accessDeniedHandled = false;

    if (_initialized && roleContext == _lastResolvedRoleContext) {
      return;
    }

    _lastResolvedRoleContext = roleContext;

    if (!_initialized) {
      setState(() {
        _initialized = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<EftekadProvider>().initialize(selectedRoleName: roleContext);
    });
  }

  void _onAuthChanged() {
    if (!mounted) {
      return;
    }

    final authProvider = _authProvider;
    if (authProvider == null) {
      return;
    }

    if (!authProvider.profileLoading &&
        authProvider.currentUserProfile != null) {
      if (_isAuthListenerAttached) {
        authProvider.removeListener(_onAuthChanged);
        _isAuthListenerAttached = false;
      }
      _tryInitialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    if (_isAuthListenerAttached && _authProvider != null) {
      _authProvider!.removeListener(_onAuthChanged);
      _isAuthListenerAttached = false;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_initialized) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Eftekad')),
        body: const LoadingView(message: 'Loading Eftekad...'),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Eftekad'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<EftekadProvider>(
            builder: (context, provider, _) {
              return IconButton(
                onPressed: provider.isLoading ? null : provider.refresh,
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const AdminScopeBanner(),
                _buildGlassFilters(),
                Expanded(
                  child: Consumer<EftekadProvider>(
                    builder: (context, provider, _) {
                      final requiresTroopSelection =
                          provider.isSystemScoped &&
                          provider.selectedTroopId == null;

                      if (requiresTroopSelection) {
                        return const EmptyView(
                          icon: Icons.groups_rounded,
                          title: 'Select a troop',
                          message:
                              'Pick a troop first to load Eftekad members.',
                        );
                      }

                      if (provider.isLoading) {
                        return const LoadingView(message: 'Loading members...');
                      }

                      if (provider.hasError &&
                          provider.visibleMembers.isEmpty) {
                        return ErrorView(
                          message:
                              provider.error ?? 'Unable to load EFTEKAD data.',
                          onRetry: provider.refresh,
                        );
                      }

                      final groups = provider.groupedMembers;
                      if (groups.isEmpty) {
                        return const EmptyView(
                          icon: Icons.person_search_rounded,
                          title: 'No members found',
                          message: 'Try changing search or filters.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: groups.length,
                        separatorBuilder: (_, unused) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _PatrolMembersSection(
                            group: group,
                            onMemberTap: (member) => _openProfileModal(member),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.scoutEliteNavy, AppColors.cardDarkElevated]
                  : [AppColors.backgroundLight, AppColors.surfaceLight],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        AppColors.goldAccent.withValues(alpha: 0.08),
                        AppColors.goldAccent.withValues(alpha: 0.0),
                      ]
                    : [
                        AppColors.goldAccent.withValues(alpha: 0.1),
                        AppColors.goldAccent.withValues(alpha: 0.0),
                      ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -60,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [
                        AppColors.primaryBlue.withValues(alpha: 0.06),
                        AppColors.primaryBlue.withValues(alpha: 0.0),
                      ]
                    : [
                        AppColors.primaryBlue.withValues(alpha: 0.08),
                        AppColors.primaryBlue.withValues(alpha: 0.0),
                      ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassFilters() {
    return Consumer<EftekadProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.06,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (provider.isSystemScoped) ...[
                      _buildGlassDropdown<String>(
                        value: provider.selectedTroopId,
                        hint: 'Select Troop',
                        items: provider.troops
                            .map(
                              (troop) => DropdownMenuItem<String>(
                                value: troop['id']?.toString(),
                                child: Text(
                                  troop['name']?.toString() ?? 'Unknown troop',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null || value.isEmpty) {
                            return;
                          }
                          provider.setSelectedTroop(value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassDropdown<String?>(
                            value: provider.selectedPatrolFilter,
                            hint: 'All patrols',
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All patrols'),
                              ),
                              ...provider.patrolFilterOptions.map(
                                (item) => DropdownMenuItem<String?>(
                                  value: item['id'],
                                  child: Text(
                                    item['name'] ?? 'Unknown patrol',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: provider.setPatrolFilter,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildGlassSwitch(provider),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGlassSearch(provider),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          dropdownColor: isDark
              ? AppColors.cardDarkElevated
              : AppColors.cardLight,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.goldAccent,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGlassSwitch(EftekadProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: provider.notContactedOnly
            ? AppColors.goldAccent.withValues(alpha: 0.15)
            : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.notContactedOnly
              ? AppColors.goldAccent.withValues(alpha: 0.6)
              : isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_missed_rounded,
            size: 18,
            color: provider.notContactedOnly
                ? AppColors.goldAccent
                : isDark
                ? AppColors.textSecondaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            '${EftekadConfig.notContactedThreshold.inDays}d+',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: provider.notContactedOnly
                  ? AppColors.goldAccent
                  : isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            value: provider.notContactedOnly,
            onChanged: provider.setNotContactedOnly,
            activeTrackColor: AppColors.goldAccent,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSearch(EftekadProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: provider.setSearchQuery,
        style: TextStyle(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textTertiaryLight,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.goldAccent),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _openProfileModal(EftekadMember member) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EftekadProfileDialog(member: member),
    );
  }
}

class _PatrolMembersSection extends StatelessWidget {
  const _PatrolMembersSection({required this.group, required this.onMemberTap});

  final EftekadPatrolGroup group;
  final ValueChanged<EftekadMember> onMemberTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.goldAccent.withValues(
                        alpha: isDark ? 0.12 : 0.08,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        group.isUnassigned
                            ? Icons.person_outline_rounded
                            : Icons.groups_rounded,
                        color: AppColors.goldAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${group.members.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: group.members
                      .map(
                        (member) => _EftekadMemberTile(
                          member: member,
                          onTap: () => onMemberTap(member),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EftekadMemberTile extends StatelessWidget {
  const _EftekadMemberTile({required this.member, required this.onTap});

  final EftekadMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<EftekadProvider>();
    final lastContact = provider.lastContactForProfile(member.id);

    final daysSinceContact = lastContact != null
        ? DateTime.now().difference(lastContact).inDays
        : null;
    final needsContact =
        daysSinceContact != null &&
        daysSinceContact >= EftekadConfig.notContactedThreshold.inDays;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(member.fullName, needsContact),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.fullName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!member.approved)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pending',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.phone?.trim().isNotEmpty == true
                        ? member.phone!
                        : 'No phone number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        lastContact != null
                            ? Icons.access_time_rounded
                            : Icons.phone_missed_rounded,
                        size: 14,
                        color: needsContact
                            ? AppColors.error
                            : isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lastContact != null
                            ? '${daysSinceContact}d ago'
                            : 'Never contacted',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: needsContact
                              ? AppColors.error
                              : isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                          fontWeight: needsContact
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.goldAccent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, bool needsContact) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.goldAccent.withValues(alpha: 0.3),
                AppColors.primaryBlue.withValues(alpha: 0.2),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.goldAccent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.goldAccent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (needsContact)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _EftekadProfileDialog extends StatefulWidget {
  const _EftekadProfileDialog({required this.member});

  final EftekadMember member;

  @override
  State<_EftekadProfileDialog> createState() => _EftekadProfileDialogState();
}

class _EftekadProfileDialogState extends State<_EftekadProfileDialog> {
  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<EftekadProvider>().loadProfileRecords(
        widget.member.id,
        reset: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Consumer<EftekadProvider>(
          builder: (context, provider, _) {
            final records = provider.recordsForProfile(widget.member.id);
            final lastContact = provider.lastContactForProfile(
              widget.member.id,
            );
            final isLoading = provider.isLoadingRecordsForProfile(
              widget.member.id,
            );
            final hasMore = provider.hasMoreRecordsForProfile(widget.member.id);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(lastContact, isDark),
                        const SizedBox(height: 20),
                        _buildRecordsSection(
                          records,
                          isLoading,
                          hasMore,
                          provider,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.goldAccent.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(widget.member.fullName, false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.member.patrolName ?? 'No patrol',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.goldAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool needsContact) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.goldAccent,
            AppColors.primaryBlue.withValues(alpha: 0.6),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(DateTime? lastContact, bool isDark) {
    final member = widget.member;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          if (member.phone != null && member.phone!.trim().isNotEmpty)
            _buildInfoRow(
              Icons.phone_rounded,
              'Phone',
              member.phone!,
              isDark,
              onTap: () => _makePhoneCall(member.phone!),
            )
          else
            _buildInfoRow(
              Icons.phone_rounded,
              'Phone',
              'Not available',
              isDark,
            ),
          const Divider(height: 20),
          _buildInfoRow(
            Icons.location_on_rounded,
            'Address',
            member.address ?? 'Not available',
            isDark,
          ),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      lastContact != null
                          ? Icons.access_time_rounded
                          : Icons.phone_missed_rounded,
                      'Last contact',
                      lastContact != null
                          ? _formatDateTime(lastContact)
                          : 'Never',
                      isDark,
                      isMultiLine: lastContact != null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow(
                  Icons.badge_rounded,
                  'Scout Code',
                  member.scoutCode ?? '-',
                  isDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildAddressMapsRow(isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isMultiLine = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: isMultiLine
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.goldAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.goldAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: onTap,
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: onTap != null
                        ? AppColors.primaryBlue
                        : isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: isMultiLine ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressMapsRow(bool isDark) {
    final member = widget.member;
    final theme = Theme.of(context);
    final hasLink =
        member.addressMaps != null && member.addressMaps!.trim().isNotEmpty;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasLink
                ? AppColors.primaryBlue.withValues(alpha: 0.15)
                : AppColors.goldAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            hasLink ? Icons.map_rounded : Icons.add_location_alt_rounded,
            size: 18,
            color: hasLink ? AppColors.primaryBlue : AppColors.goldAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasLink ? 'Tap to open in Maps' : 'No location set',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: hasLink
                      ? AppColors.primaryBlue
                      : isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (hasLink)
          IconButton(
            onPressed: () => _openMapsLink(member.addressMaps!),
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 20,
              color: AppColors.primaryBlue,
            ),
            tooltip: 'Open in Google Maps',
          )
        else
          IconButton(
            onPressed: () => _showAddAddressMapsDialog(context),
            icon: Icon(
              Icons.add_rounded,
              size: 20,
              color: AppColors.goldAccent,
            ),
            tooltip: 'Add location link',
          ),
      ],
    );
  }

  void _openMapsLink(String url) {
    // Handle url_launcher - will use provider to launch URL
    // For now, this will be handled via a service
    context.read<EftekadProvider>().openMapsLink(url);
  }

  Future<void> _showAddAddressMapsDialog(BuildContext context) async {
    final controller = TextEditingController(text: widget.member.addressMaps);
    String? errorMessage;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Location Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a Google Maps or Apple Maps link:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'https://maps.google.com/...',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (_) {
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Supported: maps.google.com, goo.gl/maps, apple.co/maps',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final input = controller.text.trim();
                final validation = _validateMapsLink(input);
                if (validation != null) {
                  setState(() => errorMessage = validation);
                  return;
                }
                Navigator.of(ctx).pop(input);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      await context.read<EftekadProvider>().updateMemberAddressMaps(
        profileId: widget.member.id,
        addressMaps: result,
      );
    }
  }

  String? _validateMapsLink(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a location link';
    }

    String normalizedUrl = trimmed;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      normalizedUrl = 'https://$trimmed';
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Invalid URL format';
    }

    final host = uri.host.toLowerCase();
    final validHosts = [
      'maps.google.com',
      'www.google.com',
      'goo.gl',
      'goo.gl.maps',
      'maps.apple.com',
      'apple.co',
      'shorturl.at',
      'bit.ly',
      'tinyurl.com',
    ];

    final isValidHost = validHosts.any(
      (h) => host == h || host.endsWith('.$h'),
    );
    if (!isValidHost) {
      return 'Only Google Maps or Apple Maps links are allowed';
    }

    final validPaths = ['/maps', '/maps/', '/', ''];
    if (!validPaths.any(
      (p) => uri.path == p || uri.path.startsWith('/maps/'),
    )) {
      return 'Invalid maps URL path';
    }

    return null;
  }

  Widget _buildRecordsSection(
    List<EftekadRecord> records,
    bool isLoading,
    bool hasMore,
    EftekadProvider provider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.2),
                    AppColors.goldAccent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Follow-up Records',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: provider.isSavingRecord
                  ? null
                  : () async {
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => _AddEftekadRecordDialog(
                          profileId: widget.member.id,
                        ),
                      );
                    },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.goldAccent.withValues(alpha: 0.2),
                foregroundColor: AppColors.goldAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoading && records.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: CircularProgressIndicator(color: AppColors.goldAccent),
            ),
          ),
        if (!isLoading && records.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 48,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No follow-up records yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...records.map((record) => _RecordTile(record: record)),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => provider.loadProfileRecords(widget.member.id),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(isLoading ? 'Loading...' : 'Load more'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.goldAccent,
                  side: BorderSide(
                    color: AppColors.goldAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddEftekadRecordDialog extends StatefulWidget {
  const _AddEftekadRecordDialog({required this.profileId});

  final String profileId;

  @override
  State<_AddEftekadRecordDialog> createState() =>
      _AddEftekadRecordDialogState();
}

class _AddEftekadRecordDialogState extends State<_AddEftekadRecordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _outcomeController = TextEditingController();

  EftekadRecordType _selectedType = EftekadRecordType.call;
  DateTime? _nextFollowUpDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final saveError = context.watch<EftekadProvider>().error;

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Follow-up Record',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTypeSelector(isDark),
                const SizedBox(height: 16),
                _buildReasonField(isDark),
                const SizedBox(height: 16),
                _buildFormTextField(
                  controller: _notesController,
                  label: 'Notes',
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Notes are required'
                      : null,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildFormTextField(
                  controller: _outcomeController,
                  label: 'Outcome (optional)',
                  minLines: 2,
                  maxLines: 4,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildDatePicker(isDark),
                if (saveError != null && saveError.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            saveError,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.goldAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text(_isSubmitting ? 'Saving...' : 'Save'),
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

  Widget _buildTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: EftekadRecordType.values.map((type) {
            final isSelected = _selectedType == type;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != EftekadRecordType.other ? 8 : 0,
                ),
                child: InkWell(
                  onTap: () => setState(() => _selectedType = type),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.goldAccent.withValues(alpha: 0.15)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.goldAccent.withValues(alpha: 0.6)
                            : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getTypeIcon(type),
                          size: 22,
                          color: isSelected
                              ? AppColors.goldAccent
                              : isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textTertiaryLight,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.goldAccent
                                : isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static const List<String> _commonReasons = [
    'Normal follow-up',
    'Multiple absence',
    'Personal check',
    'Attendance issue',
    'Behavior concern',
    'Missing meeting',
  ];

  Widget _buildReasonField(bool isDark) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _reasonController,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.goldAccent),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
          ),
          validator: (value) =>
              (value?.trim().isEmpty ?? true) ? 'Reason is required' : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonReasons.map((reason) {
            return InkWell(
              onTap: () {
                final current = _reasonController.text.trim();
                _reasonController.text = current.isEmpty
                    ? reason
                    : '$current, $reason';
                _reasonController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _reasonController.text.length),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  '+ $reason',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.goldAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getTypeIcon(EftekadRecordType type) {
    switch (type) {
      case EftekadRecordType.call:
        return Icons.phone_rounded;
      case EftekadRecordType.inPerson:
        return Icons.person_rounded;
      case EftekadRecordType.message:
        return Icons.message_rounded;
      case EftekadRecordType.other:
        return Icons.more_horiz_rounded;
    }
  }

  Widget _buildFormTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldAccent),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
      ),
      validator: validator,
    );
  }

  Widget _buildDatePicker(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.goldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.event_rounded,
              size: 18,
              color: AppColors.goldAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nextFollowUpDate == null
                  ? 'No next follow-up date'
                  : 'Next: ${_formatDateTime(_nextFollowUpDate!)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _nextFollowUpDate != null
                    ? AppColors.goldAccent
                    : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontWeight: _nextFollowUpDate != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: _pickDate,
            child: Text(
              _nextFollowUpDate == null ? 'Pick date' : 'Change',
              style: const TextStyle(color: AppColors.goldAccent),
            ),
          ),
          if (_nextFollowUpDate != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _nextFollowUpDate = null;
                });
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.goldAccent,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _nextFollowUpDate ?? now,
    );
    if (selectedDate == null) {
      return;
    }

    final currentTime = _nextFollowUpDate ?? now;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentTime.hour,
        minute: currentTime.minute,
      ),
    );
    if (selectedTime == null) {
      return;
    }

    setState(() {
      _nextFollowUpDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final provider = context.read<EftekadProvider>();
    final success = await provider.addRecord(
      profileId: widget.profileId,
      type: _selectedType,
      reason: _reasonController.text,
      notes: _notesController.text,
      outcome: _outcomeController.text,
      nextFollowUpDate: _nextFollowUpDate,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
    });
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final EftekadRecord record;

  String _getShortName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Unknown';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last}';
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.goldAccent.withValues(alpha: 0.2),
                      AppColors.primaryBlue.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(record.type),
                      size: 14,
                      color: AppColors.goldAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      record.type.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDateTime(record.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (record.createdByName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _getShortName(record.createdByName),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecordDetail(context, 'Reason', record.reason, isDark),
          const SizedBox(height: 8),
          _buildRecordDetail(context, 'Notes', record.notes, isDark),
          if (record.outcome != null && record.outcome!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildRecordDetail(context, 'Outcome', record.outcome!, isDark),
          ],
          if (record.nextFollowUpDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Follow-up: ${_formatDateTime(record.nextFollowUpDate!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTypeIcon(EftekadRecordType type) {
    switch (type) {
      case EftekadRecordType.call:
        return Icons.phone_rounded;
      case EftekadRecordType.inPerson:
        return Icons.person_rounded;
      case EftekadRecordType.message:
        return Icons.message_rounded;
      case EftekadRecordType.other:
        return Icons.more_horiz_rounded;
    }
  }

  Widget _buildRecordDetail(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
