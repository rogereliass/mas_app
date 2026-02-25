import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/logic/auth_provider.dart';

/// Banner widget showing current admin's operational scope
/// 
/// Displays at top of admin pages to provide clarity about data visibility:
/// - System Admin/Moderator → "Managing: All Users" (blue)
/// - Troop Leader/Head → "Managing: [Troop Name]" (orange)
class AdminScopeBanner extends StatefulWidget {
  const AdminScopeBanner({super.key});

  @override
  State<AdminScopeBanner> createState() => _AdminScopeBannerState();
}

class _AdminScopeBannerState extends State<AdminScopeBanner> {
  String? _troopName;
  bool _loadingTroopName = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTroopNameIfNeeded();
  }

  Future<void> _loadTroopNameIfNeeded() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUserProfile;
    
    if (user == null || user.managedTroopId == null) {
      setState(() {
        _troopName = null;
      });
      return;
    }
    
    // Only load if we don't have the name yet
    if (_troopName != null || _loadingTroopName) return;
    
    setState(() {
      _loadingTroopName = true;
    });
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('troops')
          .select('name')
          .eq('id', user.managedTroopId!)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _troopName = response['name'] as String?;
          _loadingTroopName = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading troop name: $e');
      if (mounted) {
        setState(() {
          _loadingTroopName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUserProfile;
    
    if (user == null) return const SizedBox.shrink();
    
    final selectedRole = authProvider.selectedRoleName;
    final effectiveRank = selectedRole != null
        ? authProvider.getRankForRole(selectedRole)
        : user.roleRank;

    final String roleLabel;
    if (selectedRole != null && selectedRole.isNotEmpty) {
      roleLabel = selectedRole;
    } else if (effectiveRank == 100) {
      roleLabel = 'System Admin';
    } else if (effectiveRank == 90) {
      roleLabel = 'Moderator';
    } else if (effectiveRank == 70) {
      roleLabel = 'Troop Head';
    } else if (effectiveRank == 60) {
      roleLabel = 'Troop Leader';
    } else {
      roleLabel = 'User';
    }
    
    final bool isSystemWide = effectiveRank >= 90;
    
    // Determine scope text based on effective rank
    String scopeText;
    
    if (effectiveRank == 100) {
      scopeText = 'Managing: All Users & Troops';
    } else if (effectiveRank == 90) {
      scopeText = 'Managing: All Users & Troops';
    } else if (effectiveRank == 70 || effectiveRank == 60) {
      // Show troop name if available, otherwise fallback
      if (_troopName != null) {
        scopeText = 'Managing: $_troopName';
      } else if (_loadingTroopName) {
        scopeText = 'Managing: Loading...';
      } else {
        scopeText = 'Managing: Your Troop';
      }
    } else {
      scopeText = 'Limited Access';
    }
    
    final Color bannerColor = isSystemWide
        ? theme.colorScheme.primaryContainer
      : theme.colorScheme.tertiaryContainer;
    
    final Color textColor = isSystemWide
        ? theme.colorScheme.onPrimaryContainer
      : theme.colorScheme.onTertiaryContainer;
    
    final IconData icon = isSystemWide 
        ? Icons.admin_panel_settings 
        : Icons.groups;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        border: Border(
          bottom: BorderSide(
            color: textColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: textColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scopeText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Role: $roleLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!isSystemWide && user.managedTroopId == null)
            Tooltip(
              message: 'Warning: No troop assigned',
              child: Icon(
                Icons.warning_amber,
                size: 18,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
