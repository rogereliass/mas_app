import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../data/models/patrol_with_members.dart';
import '../../data/models/troop_member.dart';

class PatrolCard extends StatelessWidget {
  final PatrolWithMembers item;
  final VoidCallback onManageMembers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PatrolCard({
    super.key,
    required this.item,
    required this.onManageMembers,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.5),
          width: 1,
        ),
      ),
      color: isDark ? colorScheme.surfaceContainerLow : AppColors.cardLight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Builder(
              builder: (context) {
                final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(item.patrol.name);
                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.patrol.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: isArabic ? TextAlign.right : TextAlign.left,
                              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.patrol.description?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.patrol.description!.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCountBadge(context, item.members.length),
                    ],
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leader & Assistants Section
                  _buildLeadershipSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // Members Section
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 18, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Team Members',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (item.members.isEmpty)
                    _buildEmptyState(context)
                  else
                    Column(
                      children: item.members.map((member) {
                        int stars = 0;
                        if (member.id == item.patrol.patrolLeaderProfileId) {
                          stars = 3;
                        } else if (member.id == item.patrol.assistant1ProfileId) {
                          stars = 2;
                        } else if (member.id == item.patrol.assistant2ProfileId) {
                          stars = 1;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MemberListItem(
                            member: member,
                            stars: stars,
                            onTap: () => _makePhoneCall(member.phone ?? ''),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),
                  
                  // Actions Section
                  _buildActions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadershipSection(BuildContext context) {
    return Column(
      children: [
        _LeadershipRow(
          label: 'Patrol Leader',
          member: item.patrolLeader,
          icon: Icons.star,
          isLeader: true,
          onTap: item.patrolLeader != null ? () => _makePhoneCall(item.patrolLeader!.phone ?? '') : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LeadershipRow(
                label: 'Assistant 1',
                member: item.assistant1,
                icon: Icons.star_half,
                onTap: item.assistant1 != null ? () => _makePhoneCall(item.assistant1!.phone ?? '') : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LeadershipRow(
                label: 'Assistant 2',
                member: item.assistant2,
                icon: Icons.star_half,
                onTap: item.assistant2 != null ? () => _makePhoneCall(item.assistant2!.phone ?? '') : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
        shape: StadiumBorder(side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.person_add_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            'No members assigned yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onManageMembers,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.manage_accounts_outlined, size: 18),
            label: const Text('Manage Members'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: colorScheme.outline),
            ),
            child: const Icon(Icons.edit_outlined, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.delete_outline, size: 18),
          ),
        ),
      ],
    );
  }
}

class _LeadershipRow extends StatelessWidget {
  final String label;
  final TroopMember? member;
  final IconData icon;
  final bool isLeader;
  final VoidCallback? onTap;

  const _LeadershipRow({
    required this.label,
    this.member,
    required this.icon,
    this.isLeader = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final goldColor = isDark 
        ? AppColors.goldAccent.withValues(alpha: 0.8) // Less intense gold for dark theme
        : AppColors.goldAccent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark 
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
              : AppColors.cardLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLeader 
                ? goldColor.withValues(alpha: 0.4)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isLeader ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLeader ? goldColor : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                size: 16, 
                color: isLeader ? Colors.white : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isLeader ? goldColor : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member?.fullName ?? 'Not assigned',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: member == null ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6) : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLeader && member != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: ShapeDecoration(
                  color: goldColor,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'LEADER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberListItem extends StatelessWidget {
  final TroopMember member;
  final VoidCallback onTap;
  final int stars;

  const _MemberListItem({
    required this.member,
    required this.onTap,
    this.stars = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.person, size: 16, color: colorScheme.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      member.fullName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (stars > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            stars,
                            (_) => const Icon(
                              Icons.star,
                              size: 10,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.call_outlined, size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
