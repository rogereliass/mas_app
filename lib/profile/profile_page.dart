import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/logic/auth_provider.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import '../core/widgets/settings_dialog.dart';
import 'package:intl/intl.dart';

/// User Profile Page
/// 
/// Displays comprehensive user information in a modern, card-based layout
/// Features:
/// - User avatar with gradient background
/// - Personal information cards
/// - Role and access level display
/// - Account details
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.currentUserProfile;
    final profileLoadError = authProvider.profileLoadError;
    final profileLoading = authProvider.profileLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () {
              // TODO: Navigate to edit profile page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit profile coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            profile == null
                ? _buildLoadingOrError(context, profileLoading, profileLoadError, authProvider)
                : RefreshIndicator(
                    onRefresh: () => authProvider.refreshProfile(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        children: [
                          // Header with Avatar
                          _buildProfileHeader(context, profile, authProvider),
                          
                          const SizedBox(height: 24),
                          
                          // Content Cards
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Personal Information
                                _buildSectionTitle(context, 'Personal Information'),
                                const SizedBox(height: 12),
                                _buildPersonalInfoCard(context, profile),
                                
                                const SizedBox(height: 24),
                                
                                // Role & Access
                                _buildSectionTitle(context, 'Role & Access'),
                                const SizedBox(height: 12),
                                _buildRoleCard(context, profile, authProvider),
                                
                                const SizedBox(height: 24),
                                
                                // Account Details
                                _buildSectionTitle(context, 'Account Details'),
                                const SizedBox(height: 12),
                                _buildAccountCard(context, profile),
                                
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            // Floating Navbar at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNavBar(
                currentPage: 'profile',
                isAuthenticated: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile header with avatar and name
  Widget _buildProfileHeader(BuildContext context, dynamic profile, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: colorScheme.primary,
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          _getInitials(profile.fullName ?? 'U'),
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Name
              Text(
                profile.fullName ?? 'User',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (profile.nameAr != null) ...[
                const SizedBox(height: 4),
                Text(
                  profile.nameAr!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    fontFamily: 'Arial', // Better Arabic support
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Email/Phone
              if (profile.email != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 16,
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.email!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build personal information card
  Widget _buildPersonalInfoCard(BuildContext context, dynamic profile) {
    return _buildCard(
      context,
      child: Column(
        children: [
          if (profile.phone != null)
            _buildInfoRow(
              context,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: profile.phone!,
            ),
          if (profile.phone != null && profile.birthdate != null)
            const Divider(height: 24),
          if (profile.birthdate != null)
            _buildInfoRow(
              context,
              icon: Icons.cake_outlined,
              label: 'Birth Date',
              value: DateFormat('MMM dd, yyyy').format(profile.birthdate!),
            ),
          if (profile.birthdate != null && profile.gender != null)
            const Divider(height: 24),
          if (profile.gender != null)
            _buildInfoRow(
              context,
              icon: Icons.person_outline,
              label: 'Gender',
              value: _formatGender(profile.gender!),
            ),
          if (profile.gender != null && profile.address != null)
            const Divider(height: 24),
          if (profile.address != null)
            _buildInfoRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: profile.address!,
            ),
        ],
      ),
    );
  }

  /// Build role card
  Widget _buildRoleCard(BuildContext context, dynamic profile, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roles = authProvider.userRoles;

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Level',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getAccessLevelName(profile.roleRank),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Rank ${profile.roleRank}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (roles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Your Roles',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roles.map((role) {
                return Chip(
                  avatar: Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  label: Text(role.name),
                  backgroundColor: colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Build account card
  Widget _buildAccountCard(BuildContext context, dynamic profile) {
    return _buildCard(
      context,
      child: Column(
        children: [
          _buildInfoRow(
            context,
            icon: Icons.badge_outlined,
            label: 'User ID',
            value: profile.userId.substring(0, 8) + '...',
          ),
          if (profile.signupTroopId != null) ...[
            const Divider(height: 24),
            _buildInfoRow(
              context,
              icon: Icons.groups_outlined,
              label: 'Signup Troop',
              value: profile.signupTroopId!,
            ),
          ],
          if (profile.generation != null) ...[
            const Divider(height: 24),
            _buildInfoRow(
              context,
              icon: Icons.school_outlined,
              label: 'Generation',
              value: '${profile.generation!} -',
            ),
          ],
          const Divider(height: 24),
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_outlined,
            label: 'Joined App On',
            value: DateFormat('MMM dd, yyyy').format(profile.createdAt),
          ),
        ],
      ),
    );
  }

  /// Build reusable card wrapper
  Widget _buildCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Build info row
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build section title
  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Get user initials for avatar
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Get access level name based on rank
  String _getAccessLevelName(int rank) {
    if (rank == 0) return 'Public';
    if (rank < 20) return 'Basic';
    if (rank < 40) return 'Member';
    if (rank < 60) return 'Advanced';
    if (rank < 80) return 'Senior';
    if (rank < 100) return 'Admin';
    return 'System Admin';
  }

  /// Format gender value for display
  String _formatGender(String gender) {
    return gender[0].toUpperCase() + gender.substring(1).toLowerCase();
  }

  /// Build loading or error state
  Widget _buildLoadingOrError(
    BuildContext context,
    bool isLoading,
    String? error,
    AuthProvider authProvider,
  ) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to Load Profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => authProvider.refreshProfile(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
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

    // No error but no profile - still loading
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Show settings dialog
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }
}

