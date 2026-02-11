import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../logic/admin_provider.dart';
import '../data/models/pending_profile.dart';
import '../data/models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import 'package:intl/intl.dart';

/// User Acceptance Page
/// 
/// Admin page for reviewing and approving/rejecting new user registrations
/// Shows pending profiles with detailed review capabilities
/// 
/// Access levels:
/// - System Admin (100) and Moderator (90): See ALL pending profiles
/// - Troop Head (70) and Troop Leader (60): See ONLY their troop's pending profiles
/// 
/// Supports role context: When navigating from HomePage with selectedRole argument,
/// filters data based on that specific role instead of user's highest rank
class UserAcceptancePage extends StatefulWidget {
  final String? selectedRole;
  
  const UserAcceptancePage({super.key, this.selectedRole});

  @override
  State<UserAcceptancePage> createState() => _UserAcceptancePageState();
}

class _UserAcceptancePageState extends State<UserAcceptancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final authProvider = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();
      
      // Get selected role from widget or navigation arguments
      String? roleContext = widget.selectedRole;
      if (roleContext == null) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        roleContext = args?['selectedRole'] as String?;
      }
      
      // SECURITY: Determine effective rank based on role context
      int effectiveRank;
      if (roleContext != null) {
        effectiveRank = authProvider.getRankForRole(roleContext);
        debugPrint('🎯 User Acceptance accessed with role context: $roleContext (rank $effectiveRank)');
        // Set role context in provider for filtering
        adminProvider.setRoleContext(roleContext);
      } else {
        effectiveRank = authProvider.currentUserRoleRank;
        debugPrint('🎯 User Acceptance accessed with default role (rank $effectiveRank)');
        adminProvider.clearRoleContext();
      }
      
      final user = authProvider.currentUserProfile;
      
      // Allow: System Admin (100), Moderator (90), Troop Head (70), Troop Leader (60)
      if (effectiveRank < 60) {
        debugPrint('❌ SECURITY: Unauthorized access attempt. Effective rank: $effectiveRank');
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
          debugPrint('⚠️ WARNING: Accessing as troop-scoped role (rank $effectiveRank) but no troop assigned');
          debugPrint('   User profile managedTroopId: ${user?.managedTroopId}');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Error: No troop assigned. Please contact an administrator.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        debugPrint('✅ Troop-scoped access validated. Managed troop: ${user?.managedTroopId}');
      }
      
      // Authorized - load scoped data based on effective role
      debugPrint('✅ User authorized for User Acceptance (effective rank $effectiveRank)');
      adminProvider.loadPendingProfiles();
      adminProvider.loadRoles();
    });
  }
  
  @override
  void dispose() {
    // Clear role context when leaving page
    context.read<AdminProvider>().clearRoleContext();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Get selected role from widget or route arguments
    String? roleContext = widget.selectedRole;
    if (roleContext == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      roleContext = args?['selectedRole'] as String?;
    }

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
                    : () => provider.refresh(),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Show current admin scope (system-wide or troop-specific)
          AdminScopeBanner(selectedRoleName: roleContext),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<AdminProvider>().refresh();
              },
              child: Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  // Loading state
                  if (provider.isLoadingPending) {
                    return const LoadingView(message: 'Loading pending profiles...');
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
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesList(AdminProvider provider, ColorScheme colorScheme, ThemeData theme) {
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
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: theme.textTheme.headlineMedium,
            ),
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

    // Profiles list
    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: colorScheme.primaryContainer,
          child: Text(
            '${provider.pendingCount} ${provider.pendingCount == 1 ? 'profile' : 'profiles'} awaiting review',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Profiles list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingProfiles.length,
            itemBuilder: (context, index) {
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
  Future<void> _showProfileDetailsDialog(BuildContext context, PendingProfile profile) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _ProfileDetailsDialog(profile: profile),
    );
    
    // Refresh the pending profiles list after dialog closes
    if (mounted) {
      context.read<AdminProvider>().loadPendingProfiles();
    }
  }
}

/// Profile card widget
class _ProfileCard extends StatelessWidget {
  final PendingProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: profile.photoUrl != null
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: profile.photoUrl == null
                        ? Text(
                            profile.fullName.isNotEmpty 
                                ? profile.fullName[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.titleLarge,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Registered ${_formatDate(profile.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.5),
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
              ),
              if (profile.phone != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: profile.phone!,
                ),
              ],
              if (profile.signupTroopName != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.group_outlined,
                  label: profile.signupTroopName!,
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

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
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
  bool _showApprovalHistory = false;
  bool _rolesInitialized = false;
  bool _commentInitialized = false;

  @override
  void initState() {
    super.initState();
    _generationController.text = widget.profile.generation ?? '';
    
    // Load profile details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().selectProfile(widget.profile.id);
      }
    });
  }

  @override
  void dispose() {
    _generationController.dispose();
    _commentsController.dispose();
    // Clear selection when dialog closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminProvider>().clearSelection();
      }
    });
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
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Review Registration',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile.fullName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
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
                  if (!_rolesInitialized && provider.selectedProfileRoles.isNotEmpty) {
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

                  // Initialize comment field with existing comment if any
                  // Since each profile has only ONE approval record, just get the first one
                  if (!_commentInitialized && provider.selectedProfileApprovals.isNotEmpty) {
                    _commentInitialized = true;
                    // Get the single approval record for this profile
                    final existingRecord = provider.selectedProfileApprovals.first;
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
                        _buildDetailSection(
                          context,
                          title: 'Personal Information',
                          children: [
                            _buildDetailRow('Full Name', widget.profile.fullName),
                            if (widget.profile.nameAr != null)
                              _buildDetailRow('Arabic Name', widget.profile.nameAr!),
                            if (widget.profile.email != null)
                              _buildDetailRow('Email', widget.profile.email!),
                            if (widget.profile.phone != null)
                              _buildDetailRow('Phone', widget.profile.phone!),
                            if (widget.profile.birthdate != null)
                              _buildDetailRow(
                                'Age',
                                '${widget.profile.age} years (${DateFormat('MMM d, yyyy').format(widget.profile.birthdate!)})',
                              ),
                            if (widget.profile.gender != null)
                              _buildDetailRow('Gender', widget.profile.gender!),
                            if (widget.profile.address != null)
                              _buildDetailRow('Address', widget.profile.address!),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Scout information
                        _buildDetailSection(
                          context,
                          title: 'Scout Information',
                          children: [
                            if (widget.profile.scoutOrgId != null)
                              _buildDetailRow('Scout Org ID', widget.profile.scoutOrgId!),
                            if (widget.profile.scoutCode != null)
                              _buildDetailRow('Scout Code', widget.profile.scoutCode!),
                            if (widget.profile.signupTroopName != null)
                              _buildDetailRow('Signup Troop', widget.profile.signupTroopName!),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Medical information
                        if (widget.profile.medicalNotes != null || widget.profile.allergies != null) ...[
                          _buildDetailSection(
                            context,
                            title: 'Medical Information',
                            children: [
                              if (widget.profile.medicalNotes != null)
                                _buildDetailRow('Medical Notes', widget.profile.medicalNotes!),
                              if (widget.profile.allergies != null)
                                _buildDetailRow('Allergies', widget.profile.allergies!),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Role selection (REQUIRED)
                        _buildRoleDropdown(theme, provider),

                        const SizedBox(height: 20),

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
                            _buildApprovalHistory(provider.selectedProfileApprovals, theme),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Add Comment button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isProcessing ? null : _handleAddComment,
                          icon: const Icon(Icons.comment),
                          label: const Text('Add Comment'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.secondary,
                            side: BorderSide(color: colorScheme.secondary),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Accept button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isProcessing ? null : _handleAccept,
                          icon: provider.isProcessing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
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
        Row(
          children: [
            Text(
              'Assign Generation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '*',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Required - Enter the generation for this user',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _generationController,
          decoration: InputDecoration(
            hintText: 'e.g., 2024, Gen 25, etc.',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.groups),
            helperText: 'Generation or cohort identifier',
          ),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _buildRoleDropdown(ThemeData theme, AdminProvider provider) {
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assign Roles',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '*',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          provider.selectedProfileRoles.isEmpty
              ? 'Required - Select one or more roles to assign to this user'
              : 'Required - User has ${provider.selectedProfileRoles.length} role(s) already assigned (checked below)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: provider.selectedProfileRoles.isEmpty 
                ? colorScheme.error 
                : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoadingRoles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.assignableRoles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No roles available for assignment. Please contact system administrator.',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: provider.assignableRoles.map((role) {
                final isSelected = _selectedRoles.contains(role);
                final wasAlreadyAssigned = provider.selectedProfileRoles.contains(role);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedRoles.add(role);
                      } else {
                        _selectedRoles.remove(role);
                      }
                    });
                  },
                  title: Text(
                    role.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (role.description != null)
                        Text(
                          role.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      if (wasAlreadyAssigned) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Currently assigned',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  secondary: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${role.rank}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentsInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional - Add notes about this profile review',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentsController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Add notes or comments about this profile...',
            border: OutlineInputBorder(),
            helperText: 'Comments can be saved without accepting/rejecting',
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildApprovalHistory(List<ProfileApproval> approvals, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: approvals.length,
        separatorBuilder: (_, __) => Divider(
          height: 1, 
          color: colorScheme.outline.withOpacity(0.3),
        ),
        itemBuilder: (context, index) {
          final approval = approvals[index];
          final statusColor = approval.status 
              ? theme.colorScheme.primary
              : theme.colorScheme.error;
              
          return ListTile(
            dense: true,
            leading: Icon(
              approval.status ? Icons.check_circle : Icons.cancel,
              color: statusColor,
              size: 20,
            ),
            title: Text(
              approval.statusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (approval.approvedByName != null)
                  Text('By: ${approval.approvedByName}'),
                if (approval.comments != null)
                  Text('Comment: ${approval.comments}'),
                Text(
                  DateFormat('MMM d, yyyy h:mm a').format(approval.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAccept() async {
    // Validate role selection
    if (_selectedRoles.isEmpty) {
      _showErrorDialog('Please select at least one role before accepting the profile');
      return;
    }

    // Validate generation
    final generation = _generationController.text.trim();
    if (generation.isEmpty) {
      _showErrorDialog('Please enter a generation before accepting the profile');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept Profile'),
        content: Text(
          'Are you sure you want to accept ${widget.profile.fullName}\'s registration?\n\n'
          'Roles (${_selectedRoles.length}): ${_selectedRoles.map((r) => r.name).join(', ')}\n'
          'Generation: $generation'
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

    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();

    final adminProfile = authProvider.currentUserProfile;
    debugPrint('🔍 Accept - Admin Profile: id=${adminProfile?.id}, userId=${adminProfile?.userId}');
    
    final adminProfileId = adminProfile?.id;
    if (adminProfileId == null || adminProfileId.isEmpty) {
      debugPrint('❌ Admin profile ID is null or empty');
      if (mounted) {
        _showErrorDialog('Error: Admin user profile not properly loaded');
      }
      return;
    }

    final success = await adminProvider.acceptProfile(
      profileId: widget.profile.id,
      approvedBy: adminProfileId,
      roleIds: _selectedRoles.map((r) => r.id).toList(),
      generation: generation,
      comments: _commentsController.text.trim().isEmpty
          ? null
          : _commentsController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      _showSnackBar('✅ Profile accepted with ${_selectedRoles.length} role(s)');
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

    debugPrint('🔄 Proceeding with add comment...'); 
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();

    final adminProfile = authProvider.currentUserProfile;
    debugPrint('🔍 Admin Profile: id=${adminProfile?.id}, userId=${adminProfile?.userId}');
    
    final adminProfileId = adminProfile?.id;
    if (adminProfileId == null || adminProfileId.isEmpty) {
      debugPrint('❌ Admin profile ID is null or empty');
      if (mounted) {
        _showErrorDialog('Error: Admin user profile not properly loaded');
      }
      return;
    }

    debugPrint('📤 Adding comment with approvedBy: $adminProfileId');
    
    final success = await adminProvider.addComment(
      profileId: widget.profile.id,
      approvedBy: adminProfileId,
      comments: comments,
    );

    debugPrint('📥 Add comment completed: success=$success');
    
    if (!mounted) {
      debugPrint('⚠️ Widget no longer mounted, aborting');
      return;
    }

    if (success) {
      debugPrint('✅ Comment added successfully');
      Navigator.pop(context);  // Close the dialog
      _showSnackBar('Comment added - Profile remains pending');
    } else {
      debugPrint('❌ Comment failed: ${adminProvider.error}');
      _showErrorDialog(
        adminProvider.error ?? 'Failed to add comment. Please try again.'
      );
    }
  }


  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    // Use root scaffold messenger to show above dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// Show error dialog that appears on top of everything
  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('Validation Error'),
          ],
        ),
        content: Text(message),
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
