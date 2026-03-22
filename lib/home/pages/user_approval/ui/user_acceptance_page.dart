import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../logic/admin_provider.dart';
import '../data/models/pending_profile.dart';
import '../data/models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import 'package:intl/intl.dart';
import '../../user_management/data/models/managed_user_profile.dart';
import '../../user_management/ui/components/role_assignment_section.dart';

/// User Acceptance Page
///
/// Admin page for reviewing and approving/rejecting new user registrations
/// Shows pending profiles with detailed review capabilities
///
/// Access levels:
/// - System Admin (100) and Moderator (90): See ALL pending profiles
/// - Troop Head (70) and Troop Leader (60): See ONLY their troop's pending profiles
///
class UserAcceptancePage extends StatefulWidget {
  const UserAcceptancePage({super.key});

  @override
  State<UserAcceptancePage> createState() => _UserAcceptancePageState();
}

class _UserAcceptancePageState extends State<UserAcceptancePage> {
  final ScrollController _scrollController = ScrollController();
  AdminProvider? _adminProvider;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();
      _adminProvider = adminProvider;

      // Resolve selected role from global app state.
      final String? roleContext = authProvider.selectedRoleName;

      // SECURITY: Determine effective rank based on role context
      int effectiveRank;
      if (roleContext != null) {
        effectiveRank = authProvider.getRankForRole(roleContext);
        debugPrint(
          '🎯 User Acceptance accessed with role context: $roleContext (rank $effectiveRank)',
        );
        // Set role context in provider for filtering
        adminProvider.setRoleContext(roleContext);
      } else {
        effectiveRank = authProvider.currentUserRoleRank;
        debugPrint(
          '🎯 User Acceptance accessed with default role (rank $effectiveRank)',
        );
        adminProvider.clearRoleContext();
      }

      final user = authProvider.currentUserProfile;

      // Allow: System Admin (100), Moderator (90), Troop Head (70), Troop Leader (60)
      if (effectiveRank < 60) {
        debugPrint(
          '❌ SECURITY: Unauthorized access attempt. Effective rank: $effectiveRank',
        );
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Admin privileges required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Additional check: Troop-scoped roles (60-70) must have a troop assigned
      // Only validate if user is accessing as a troop-scoped role
      if (effectiveRank >= 60 && effectiveRank < 90) {
        if (user?.managedTroopId == null) {
          debugPrint(
            '⚠️ WARNING: Accessing as troop-scoped role (rank $effectiveRank) but no troop assigned',
          );
          debugPrint('   User profile managedTroopId: ${user?.managedTroopId}');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Access Error: No troop assigned. Please contact an administrator.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        debugPrint(
          '✅ Troop-scoped access validated. Managed troop: ${user?.managedTroopId}',
        );
      }

      // Authorized - load scoped data based on effective role
      debugPrint(
        '✅ User authorized for User Acceptance (effective rank $effectiveRank)',
      );
      adminProvider.loadPendingProfiles();
      adminProvider.loadRoles();

      // Error listener
      adminProvider.addListener(_errorHandler);
    });
  }

  void _errorHandler() {
    if (!mounted || _adminProvider == null) return;

    if (_adminProvider!.hasError &&
        _adminProvider!.pendingProfiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_adminProvider!.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _adminProvider!.loadMorePendingProfiles(),
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<AdminProvider>().loadMorePendingProfiles();
    }
  }

  @override
  void dispose() {
    _adminProvider?.removeListener(_errorHandler);
    _scrollController.dispose();
    // Don't call clearRoleContext() here - it triggers notifyListeners() during dispose
    // The role context will be cleared when needed (e.g., when navigating to the page again)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve selected role from global app state.
    final authProvider = context.watch<AuthProvider>();
    final String? roleContext = authProvider.selectedRoleName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Acceptance'),
        actions: [
          Consumer<AdminProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.isLoadingPending
                    ? null
                    : () => provider.refresh(forceRefresh: true),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Show current admin scope (system-wide or troop-specific)
          const AdminScopeBanner(),

          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, _) {
                // Loading state
                if (provider.isLoadingPending) {
                  return const LoadingView(
                    message: 'Loading pending profiles...',
                  );
                }

                // Error state
                if (provider.hasError) {
                  return ErrorView(
                    message: provider.error ?? 'Unknown error occurred',
                    onRetry: () => provider.loadPendingProfiles(),
                  );
                }

                // Profiles list
                return _buildProfilesList(provider, colorScheme, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesList(
    AdminProvider provider,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUserProfile;
    final isTroopScoped = user?.isTroopScoped ?? false;

    // Empty state
    if (provider.pendingProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('All Caught Up!', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              isTroopScoped
                  ? 'No pending registrations in your troop'
                  : 'No pending user registrations',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${provider.pendingCount} ${provider.pendingCount == 1 ? 'profile' : 'profiles'} awaiting review',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Profiles list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount:
                provider.pendingProfiles.length +
                (provider.hasMorePending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.pendingProfiles.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final profile = provider.pendingProfiles[index];
              return _ProfileCard(
                profile: profile,
                onTap: () => _showProfileDetailsDialog(context, profile),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Show detailed profile review dialog
  Future<void> _showProfileDetailsDialog(
    BuildContext context,
    PendingProfile profile,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _ProfileDetailsDialog(profile: profile),
    );
  }
}

/// Profile card widget
class _ProfileCard extends StatelessWidget {
  final PendingProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                                colorScheme.secondaryContainer
                                    .withValues(alpha: 0.08),
                              ]
                            : [
                                colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                                colorScheme.secondaryContainer
                                    .withValues(alpha: 0.25),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName.substring(0, 1).toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Registered ${_formatDate(profile.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Quick info
              _InfoRow(
                icon: Icons.email_outlined,
                label: profile.email ?? 'No email',
                iconColor: colorScheme.secondary,
              ),
              if (profile.phone != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: profile.phone!,
                  iconColor: colorScheme.secondary,
                ),
              ],
              if (profile.signupTroopName != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.group_outlined,
                  label: profile.signupTroopName!,
                  iconColor: colorScheme.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor ?? colorScheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Profile details dialog with accept/reject actions
class _ProfileDetailsDialog extends StatefulWidget {
  final PendingProfile profile;

  const _ProfileDetailsDialog({required this.profile});

  @override
  State<_ProfileDetailsDialog> createState() => _ProfileDetailsDialogState();
}

class _ProfileDetailsDialogState extends State<_ProfileDetailsDialog> {
  final _generationController = TextEditingController();
  final _commentsController = TextEditingController();
  final List<Role> _selectedRoles = [];
  final List<Map<String, dynamic>> _troops = [];
  bool _showApprovalHistory = false;
  bool _rolesInitialized = false;
  bool _commentInitialized = false;
  bool _troopContextInitialized = false;
  bool _isLoadingTroops = false;
  final Map<String, String?> _roleTroopContextMap = {};

  @override
  void initState() {
    super.initState();
    _generationController.text = widget.profile.generation ?? '';

    // Load profile details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().selectProfile(widget.profile.id);

      final adminProvider = context.read<AdminProvider>();
      if (adminProvider.isEffectiveSystemWideAccess) {
        _loadTroops();
      }
    });
  }

  @override
  void dispose() {
    _generationController.dispose();
    _commentsController.dispose();
    // Don't call clearSelection() here - it will be cleared when needed
    // Calling provider methods in dispose() causes lifecycle errors
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (widget.profile.photoUrl != null && widget.profile.photoUrl!.isNotEmpty)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(widget.profile.photoUrl!),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.how_to_reg,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Registration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.profile.fullName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingProfile) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Initialize selected roles with profile's current roles (only once)
                  if (!_rolesInitialized &&
                      provider.selectedProfileRoles.isNotEmpty) {
                    _rolesInitialized = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedRoles.clear();
                          _selectedRoles.addAll(provider.selectedProfileRoles);
                        });
                      }
                    });
                  }

                  // Initialize troop context from existing role assignments (only once)
                  if (!_troopContextInitialized &&
                      provider.selectedProfileTroopContext != null) {
                    _troopContextInitialized = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          for (final role in _selectedRoles) {
                            if (role.rank == 60 || role.rank == 70) {
                              _roleTroopContextMap[role.id] = provider.selectedProfileTroopContext;
                            }
                          }
                        });
                      }
                    });
                  }

                  // Initialize comment field with existing comment if any
                  // Since each profile has only ONE approval record, just get the first one
                  if (!_commentInitialized &&
                      provider.selectedProfileApprovals.isNotEmpty) {
                    _commentInitialized = true;
                    // Get the single approval record for this profile
                    final existingRecord =
                        provider.selectedProfileApprovals.first;
                    if (existingRecord.comments != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _commentsController.text = existingRecord.comments!;
                        }
                      });
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile details
                        _buildSectionHeader(
                          context,
                          title: 'Personal Information',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Full Name',
                                widget.profile.fullName,
                              ),
                              if (widget.profile.nameAr?.isNotEmpty == true) ...[
                                const Divider(height: 24),
                                _buildDetailRow(
                                  'Arabic Name',
                                  widget.profile.nameAr!,
                                ),
                              ],
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Email',
                                widget.profile.email?.isNotEmpty == true ? widget.profile.email! : 'Not provided',
                              ),
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Phone',
                                widget.profile.phone?.isNotEmpty == true ? widget.profile.phone! : 'Not provided',
                              ),
                              if (widget.profile.birthdate != null) ...[
                                const Divider(height: 24),
                                _buildDetailRow(
                                  'Age',
                                  '${widget.profile.age} years (${DateFormat('MMM d, yyyy').format(widget.profile.birthdate!)})',
                                ),
                              ],
                              if (widget.profile.gender != null) ...[
                                const Divider(height: 24),
                                _buildDetailRow(
                                  'Gender',
                                  widget.profile.gender!,
                                ),
                              ],
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Address',
                                widget.profile.address?.isNotEmpty == true ? widget.profile.address! : 'Not provided',
                              ),
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Registration Date',
                                DateFormat('MMM d, yyyy h:mm a').format(widget.profile.createdAt),
                              ),
                              const Divider(height: 24),
                              _buildDetailRow(
                                'Signup Status',
                                widget.profile.signupCompleted ? 'Completed' : 'Incomplete',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Scout information
                        _buildSectionHeader(
                          context,
                          title: 'Scout Information',
                          icon: Icons.scuba_diving_outlined,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              if (widget.profile.scoutOrgId?.isNotEmpty == true)
                                _buildDetailRow(
                                  'Scout Org ID',
                                  widget.profile.scoutOrgId!,
                                ),
                              if (widget.profile.scoutCode?.isNotEmpty == true) ...[
                                if (widget.profile.scoutOrgId?.isNotEmpty == true)
                                  const Divider(height: 24),
                                _buildDetailRow(
                                  'Scout Code',
                                  widget.profile.scoutCode!,
                                ),
                              ],
                              if (widget.profile.signupTroopName?.isNotEmpty == true) ...[
                                if (widget.profile.scoutOrgId?.isNotEmpty == true ||
                                    widget.profile.scoutCode?.isNotEmpty == true)
                                  const Divider(height: 24),
                                _buildDetailRow(
                                  'Signup Troop',
                                  widget.profile.signupTroopName!,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Medical information
                        if (widget.profile.medicalNotes?.isNotEmpty == true ||
                            widget.profile.allergies?.isNotEmpty == true) ...[
                          _buildDetailSection(
                            context,
                            title: 'Medical Information',
                            children: [
                              if (widget.profile.medicalNotes?.isNotEmpty == true)
                                _buildDetailRow(
                                  'Medical Notes',
                                  widget.profile.medicalNotes!,
                                ),
                              if (widget.profile.allergies?.isNotEmpty == true)
                                _buildDetailRow(
                                  'Allergies',
                                  widget.profile.allergies!,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Role selection (REQUIRED for Admins)
                        if (provider.isEffectiveSystemWideAccess) ...[
                          RoleAssignmentSection(
                            selectedRoles: _selectedRoles,
                            availableRoles: provider.assignableRoles,
                            profile: ManagedUserProfile(
                              id: widget.profile.id,
                              userId: widget.profile.userId,
                              firstName: widget.profile.firstName,
                              middleName: widget.profile.middleName,
                              lastName: widget.profile.lastName,
                              createdAt: widget.profile.createdAt,
                              roles: const [],
                              roleAssignments: const [],
                            ),
                            troops: _troops,
                            roleTroopContext: _roleTroopContextMap,
                            canEditRole: true,
                            isLoadingTroops: _isLoadingTroops,
                            isRolesReady: provider.isRolesReady,
                            onRoleToggled: (role, isSelected) {
                              setState(() {
                                if (isSelected) {
                                  if (!_selectedRoles.any((r) => r.id == role.id)) {
                                    _selectedRoles.add(role);
                                  }
                                  if ((role.rank == 60 || role.rank == 70) && widget.profile.signupTroopId != null) {
                                    _roleTroopContextMap[role.id] = widget.profile.signupTroopId;
                                  }
                                } else {
                                  _selectedRoles.removeWhere((r) => r.id == role.id);
                                  _roleTroopContextMap.remove(role.id);
                                }
                              });
                            },
                            onTroopContextChanged: (roleId, troopId) {
                              setState(() {
                                _roleTroopContextMap[roleId] = troopId;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Generation input
                        _buildGenerationInput(theme),

                        const SizedBox(height: 20),

                        // Comments input
                        _buildCommentsInput(theme),

                        const SizedBox(height: 20),

                        // Approval history toggle
                        if (provider.selectedProfileApprovals.isNotEmpty) ...[
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showApprovalHistory = !_showApprovalHistory;
                              });
                            },
                            icon: Icon(
                              _showApprovalHistory
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(
                              'Approval History (${provider.selectedProfileApprovals.length})',
                            ),
                          ),
                          if (_showApprovalHistory) ...[
                            const SizedBox(height: 12),
                            _buildApprovalHistory(
                              provider.selectedProfileApprovals,
                              theme,
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Consumer<AdminProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isProcessing
                              ? null
                              : _handleAddComment,
                          icon:
                              const Icon(Icons.add_comment_outlined, size: 20),
                          label: const Text('Add Comment'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              provider.isProcessing ? null : _handleAccept,
                          icon: provider.isProcessing
                              ? const SizedBox.shrink()
                              : const Icon(Icons.check_circle_outline,
                                  size: 20),
                          label: provider.isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Accept'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // Use dark navy blue for better readability in light mode
    final headerColor = isDark ? colorScheme.onSurface : const Color(0xFF001F3F);

    return Row(
      children: [
        Icon(icon, size: 18, color: headerColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isNotProvided = value == 'Not provided';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isNotProvided ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                fontWeight: isNotProvided ? FontWeight.normal : FontWeight.w600,
                fontStyle: isNotProvided ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationInput(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Assign Generation',
          icon: Icons.groups_outlined,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _generationController,
          decoration: InputDecoration(
            hintText: 'e.g., 2024, Gen 25, etc.',
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.tag_outlined, color: colorScheme.primary),
            helperText: 'Required - Generation or cohort identifier',
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }



  /// Open email client to contact support
  Future<void> _contactSupport() async {
    final emailAddress =
        dotenv.env['ISSUE_EMAIL_ADDRESS'] ?? 'support.masdigitalteam@gmail.com';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserProfile;

    final uri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      query:
          'subject=MAS App - No Roles Available&body=Hello,%0A%0AI am unable to see assignable roles in the User Acceptance page.%0A%0AUser: ${user?.fullName ?? 'Unknown'}%0AEmail: ${user?.email ?? 'Not set'}%0A%0APlease help me resolve this issue.%0A%0AThank you.',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open email client. Please email: $emailAddress',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email. Please contact: $emailAddress'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildCommentsInput(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          title: 'Comments',
          icon: Icons.notes_outlined,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentsController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Add notes or comments about this profile review...',
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            prefixIcon:
                Icon(Icons.notes_outlined, color: colorScheme.primary),
            helperText: 'Comments can be saved without accepting',
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildApprovalHistory(
    List<ProfileApproval> approvals,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: approvals.length,
        separatorBuilder: (_, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          final approval = approvals[index];
          final statusColor =
              approval.status ? colorScheme.primary : colorScheme.error;

          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                approval.status
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: statusColor,
                size: 18,
              ),
            ),
            title: Text(
              approval.statusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (approval.approvedByName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'By: ${approval.approvedByName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (approval.comments != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        approval.comments!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('MMM d, yyyy h:mm a').format(approval.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAccept() async {
    final adminProvider = context.read<AdminProvider>();
    
    List<String> roleIdsToAssign = _selectedRoles.map((r) => r.id).toList();

    // Default to Scout role for non-moderators/non-admins
    if (!adminProvider.isEffectiveSystemWideAccess && roleIdsToAssign.isEmpty) {
      try {
        final scoutRole = adminProvider.assignableRoles.firstWhere(
          (r) => r.name.toLowerCase() == 'scout',
        );
        roleIdsToAssign = [scoutRole.id];
      } catch (e) {
        debugPrint('⚠️ Scout role not found in assignableRoles');
      }
    }

    // Validate role selection
    if (roleIdsToAssign.isEmpty) {
      _showErrorDialog(
        'Please select at least one role before accepting the profile',
      );
      return;
    }

    if (adminProvider.isEffectiveSystemWideAccess) {
      for (final roleId in roleIdsToAssign) {
        final role = _selectedRoles.firstWhere(
          (r) => r.id == roleId, 
          orElse: () => adminProvider.assignableRoles.firstWhere((r) => r.id == roleId)
        );
        final requiresTroopContext = role.rank == 60 || role.rank == 70;
        final contextTroopId = _roleTroopContextMap[roleId] ?? widget.profile.signupTroopId;

        if (requiresTroopContext && contextTroopId == null) {
          _showErrorDialog('Please select a troop for Troop Head/Leader roles');
          return;
        }
      }
    }

    // Validate generation
    final generation = _generationController.text.trim();
    if (generation.isEmpty) {
      _showErrorDialog(
        'Please enter a generation before accepting the profile',
      );
      return;
    }

    final selectedTroopName = null;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept Profile'),
        content: Text(
          'Are you sure you want to accept ${widget.profile.fullName}\'s registration?\n\n'
          'Roles (${roleIdsToAssign.length}): ${adminProvider.isEffectiveSystemWideAccess ? _selectedRoles.map((r) => r.name).join(', ') : 'Scout'}\n'
          'Generation: $generation'
          '${selectedTroopName != null ? '\nTroop Context: $selectedTroopName' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    final authProvider = context.read<AuthProvider>();

    final adminProfile = authProvider.currentUserProfile;
    debugPrint(
      '🔍 Accept - Admin Profile: id=${adminProfile?.id}, userId=${adminProfile?.userId}',
    );

    final adminProfileId = adminProfile?.id;
    if (adminProfileId == null || adminProfileId.isEmpty) {
      debugPrint('❌ Admin profile ID is null or empty');
      if (!context.mounted) return;
      _showErrorDialog('Error: Admin user profile not properly loaded');
      return;
    }

    final troopContextToSend = adminProvider.isEffectiveSystemWideAccess
        ? _roleTroopContextMap
        : null;

    final success = await adminProvider.acceptProfile(
      profileId: widget.profile.id,
      approvedBy: adminProfileId,
      roleIds: roleIdsToAssign,
      generation: generation,
      comments: _commentsController.text.trim().isEmpty
          ? null
          : _commentsController.text.trim(),
      roleTroopContextMap: troopContextToSend,
    );

    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
      _showSnackBar('✅ Profile accepted with ${roleIdsToAssign.length} role(s)');
    } else {
      _showSnackBar(
        adminProvider.error ?? 'Failed to accept profile',
        isError: true,
      );
    }
  }

  Future<void> _handleAddComment() async {
    debugPrint('🔘 Add Comment button pressed');
    final comments = _commentsController.text.trim();
    debugPrint('📝 Comment text: "$comments"');

    if (comments.isEmpty) {
      debugPrint('⚠️ Comment is empty, showing error');
      _showErrorDialog('Please enter a comment before saving');
      return;
    }

    debugPrint('📋 Showing confirmation dialog');
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Comment'),
        content: Text(
          'Add comment to ${widget.profile.fullName}\'s profile?\n\n'
          'The profile will remain pending for future review.\n\n'
          'Comment: $comments',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    debugPrint('✅ Confirmation result: $confirmed');
    if (confirmed != true) {
      debugPrint('❌ User cancelled or dialog dismissed');
      return;
    }

    if (!context.mounted) return;

    debugPrint('🔄 Proceeding with add comment...');
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();

    final adminProfile = authProvider.currentUserProfile;
    debugPrint(
      '🔍 Admin Profile: id=${adminProfile?.id}, userId=${adminProfile?.userId}',
    );

    final adminProfileId = adminProfile?.id;
    if (adminProfileId == null || adminProfileId.isEmpty) {
      debugPrint('❌ Admin profile ID is null or empty');
      if (!context.mounted) return;
      _showErrorDialog('Error: Admin user profile not properly loaded');
      return;
    }

    debugPrint('📤 Adding comment with approvedBy: $adminProfileId');

    final success = await adminProvider.addComment(
      profileId: widget.profile.id,
      approvedBy: adminProfileId,
      comments: comments,
    );

    debugPrint('📥 Add comment completed: success=$success');

    if (!context.mounted) return;

    if (success) {
      debugPrint('✅ Comment added successfully');
      Navigator.pop(context); // Close the dialog
      _showSnackBar('Comment added - Profile remains pending');
    } else {
      debugPrint('❌ Comment failed: ${adminProvider.error}');
      _showErrorDialog(
        adminProvider.error ?? 'Failed to add comment. Please try again.',
      );
    }
  }

  Future<void> _loadTroops() async {
    if (_isLoadingTroops) return;
    setState(() {
      _isLoadingTroops = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final troops = await authProvider.getTroops();

      if (!context.mounted) return;
      setState(() {
        _troops
          ..clear()
          ..addAll(troops);
        final validTroopIds = _troops.map((t) => t['id']).toSet();
        for (final key in _roleTroopContextMap.keys.toList()) {
          final troopId = _roleTroopContextMap[key];
          if (troopId != null && !validTroopIds.contains(troopId)) {
            _roleTroopContextMap.remove(key);
          }
        }
        _isLoadingTroops = false;
      });

      if (troops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No troops available to select.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isLoadingTroops = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading troops: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  void _showSnackBar(String message, {bool isError = false}) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Validation Error'),
          ],
        ),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
