import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../data/models/patrol_with_members.dart';
import '../../data/models/troop_member.dart';

class PatrolCard extends StatelessWidget {
  final PatrolWithMembers item;
  final VoidCallback? onManageMembers;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PatrolCard({
    super.key,
    required this.item,
    this.onManageMembers,
    this.onEdit,
    this.onDelete,
  });

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shadowColor: isDark ? Colors.black54 : Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Premium Header
          _buildCompactHeader(theme, isDark),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Condensed Leadership Section
                _buildLeadershipSection(isDark, theme),

                const SizedBox(height: 16),

                // Command Team Header
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 14, 
                        color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      'COMMAND TEAM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Micro Member List
                if (item.members.isEmpty)
                  _buildEmptyState(theme)
                else
                  ...item.members.map((member) {
                    int stars = 0;
                    if (member.id == item.patrol.patrolLeaderProfileId) stars = 3;
                    else if (member.id == item.patrol.assistant1ProfileId) stars = 2;
                    else if (member.id == item.patrol.assistant2ProfileId) stars = 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _MemberListItemCompact(
                        member: member,
                        stars: stars,
                        isDark: isDark,
                        onTap: () => _makePhoneCall(member.phone ?? ''),
                      ),
                    );
                  }),

                const SizedBox(height: 16),

                // Simpler Actions
                if (onManageMembers != null || onEdit != null || onDelete != null)
                  _buildCompactActions(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(ThemeData theme, bool isDark) {
    final name = item.patrol.name;
    final isArabic = _isArabic(name);
    final description = item.patrol.description ?? '';
    final isDescArabic = _isArabic(description);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [AppColors.leaderboardHeaderStart, AppColors.leaderboardHeaderEnd]
              : [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.members.length} MEMBERS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.2,
                fontSize: 12,
              ),
              textAlign: isDescArabic ? TextAlign.right : TextAlign.left,
              textDirection: isDescArabic ? TextDirection.rtl : TextDirection.ltr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadershipSection(bool isDark, ThemeData theme) {
    return Column(
      children: [
        _LeadershipSpotlightCompact(
          label: 'PATROL LEADER',
          member: item.patrolLeader,
          isLeader: true,
          isDark: isDark,
          onTap: item.patrolLeader != null 
              ? () => _makePhoneCall(item.patrolLeader!.phone ?? '') : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _LeadershipSpotlightCompact(
                label: 'ASSISTANT 1',
                member: item.assistant1,
                isDark: isDark,
                onTap: item.assistant1 != null 
                    ? () => _makePhoneCall(item.assistant1!.phone ?? '') : null,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _LeadershipSpotlightCompact(
                label: 'ASSISTANT 2',
                member: item.assistant2,
                isDark: isDark,
                onTap: item.assistant2 != null 
                    ? () => _makePhoneCall(item.assistant2!.phone ?? '') : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'UNIT AWAITING PERSONNEL',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActions(ThemeData theme, bool isDark) {
    return Row(
      children: [
        if (onManageMembers != null)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 38,
              child: FilledButton(
                onPressed: onManageMembers!,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('MANAGE UNIT', 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
              ),
            ),
          ),
        const SizedBox(width: 6),
        if (onEdit != null)
          _SmallIconButton(
            onPressed: onEdit!,
            icon: Icons.edit_note_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        if (onDelete != null) ...[
          const SizedBox(width: 6),
          _SmallIconButton(
            onPressed: onDelete!,
            icon: Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
        ],
      ],
    );
  }
}

class _LeadershipSpotlightCompact extends StatelessWidget {
  final String label;
  final TroopMember? member;
  final bool isLeader;
  final bool isDark;
  final VoidCallback? onTap;

  const _LeadershipSpotlightCompact({
    required this.label,
    this.member,
    this.isLeader = false,
    required this.isDark,
    this.onTap,
  });

  bool _isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLeader ? AppColors.goldAccent : theme.colorScheme.primary.withValues(alpha: isDark ? 0.6 : 0.7);
    final memberName = member?.fullName ?? 'NOT ASSIGNED';
    final isNameArabic = _isArabic(memberName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isLeader ? 0.2 : 0.05),
            width: isLeader ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: isNameArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              textDirection: isNameArabic ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Icon(isLeader ? Icons.stars_rounded : Icons.star_outline_rounded, 
                    size: 10, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 7.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              memberName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: member == null ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : null,
              ),
              textDirection: isNameArabic ? TextDirection.rtl : TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberListItemCompact extends StatelessWidget {
  final TroopMember member;
  final int stars;
  final bool isDark;
  final VoidCallback onTap;

  const _MemberListItemCompact({
    required this.member,
    required this.stars,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(member.fullName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.03)),
        ),
        child: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Icon(Icons.person_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                member.fullName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (stars > 0) ...[
              const SizedBox(width: 6),
              _StarsCompact(stars: stars),
            ],
            const SizedBox(width: 8),
            Icon(Icons.call_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _StarsCompact extends StatelessWidget {
  final int stars;
  const _StarsCompact({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.goldAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(stars, (_) => const Icon(Icons.star_rounded, size: 7, color: AppColors.goldAccent)),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;

  const _SmallIconButton({
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

