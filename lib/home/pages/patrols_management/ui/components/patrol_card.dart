import 'package:flutter/material.dart';

import '../../data/models/patrol_with_members.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.patrol.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _CountChip(count: item.members.length),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.patrol.description?.trim().isNotEmpty == true
                  ? item.patrol.description!.trim()
                  : 'No description provided',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(
              'Patrol Leader: ${item.patrolLeader?.fullName ?? 'Not assigned'}',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              'Members',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (item.members.isEmpty)
              Text(
                'No members assigned yet',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              )
            else
              ...item.members.take(6).map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${member.fullName} • ${member.displayPhone}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
            if (item.members.length > 6)
              Text(
                '+${item.members.length - 6} more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onManageMembers,
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Manage Members'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Patrol'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                  ),
                  label: const Text('Delete Patrol'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;

  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count members',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
