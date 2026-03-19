import 'package:flutter/material.dart';

/// A shared premium dashboard section wrapper.
/// 
/// Standardizes the layout for role-based dashboards, providing a section header,
/// a horizontally scrollable row of action cards with a progress pill, 
/// and a compact statistics block below.
///
/// **How to use:**
/// ```dart
/// PremiumDashboardSection(
///   title: 'System Overview',
///   headerIcon: Icons.admin_panel_settings_rounded,
///   actionCards: [
///     PremiumActionCard(
///       title: 'Action',
///       subtitle: 'Description',
///       icon: Icons.add,
///       color: Colors.blue,
///       onTap: () {},
///     ),
///   ],
///   stats: [
///     PremiumStat(
///       icon: Icons.people,
///       label: 'Users',
///       value: '120',
///       color: Colors.green,
///     ),
///   ],
/// )
/// ```
class PremiumDashboardSection extends StatefulWidget {
  final String title;
  final IconData? headerIcon;
  final List<PremiumActionCard> actionCards;
  final List<PremiumStat> stats;

  const PremiumDashboardSection({
    super.key,
    required this.title,
    this.headerIcon,
    required this.actionCards,
    required this.stats,
  });

  @override
  State<PremiumDashboardSection> createState() => _PremiumDashboardSectionState();
}

class _PremiumDashboardSectionState extends State<PremiumDashboardSection> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (maxScroll > 0) {
        setState(() {
          _scrollProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colorScheme.onSurface,
                ),
              ),
              if (widget.headerIcon != null)
                Icon(
                  widget.headerIcon,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  size: 24,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Premium Horizontal Scrollable Action Cards
        if (widget.actionCards.isNotEmpty) ...[
          SizedBox(
            height: 150,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.actionCards.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => widget.actionCards[index],
            ),
          ),
          
          // Scroll Progress Pill
          if (widget.actionCards.length > 2) ...[
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (_scrollController.hasClients) {
                    final maxScroll = _scrollController.position.maxScrollExtent;
                    // The pill track is 48px wide, the pill is 16px wide.
                    // Max travel distance for the pill is 48 - 16 = 32px.
                    final travelDistance = details.delta.dx;
                    final scrollPercentageChange = travelDistance / 32.0;
                    
                    final newScrollOffset = (_scrollController.offset + (scrollPercentageChange * maxScroll))
                        .clamp(0.0, maxScroll);
                    
                    _scrollController.jumpTo(newScrollOffset);
                  }
                },
                child: Container(
                  width: 48,
                  height: 16, // Increase hit area height for better touch target
                  color: Colors.transparent, // Invisible expanded hit area
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 50),
                            left: _scrollProgress * (48 - 16), // Max travel distance (width - pill width)
                            child: Container(
                              width: 16,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 32),
        ],

        // Premium Compact Statistics Section
        if (widget.stats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          PremiumStatGroup(stats: widget.stats),
        ],
      ],
    );
  }
}

/// A premium, glass-like actionable card intended for horizontal scroll views.
///
/// **How to use:**
/// Pass this widget into the `actionCards` list of [PremiumDashboardSection].
/// ```dart
/// PremiumActionCard(
///   title: 'User Management',
///   subtitle: 'Edit member profiles & roles',
///   icon: Icons.manage_accounts_rounded,
///   color: const Color(0xFF14B8A6), // Teal
///   onTap: () => Navigator.pushNamed(context, '/user-management'),
/// )
/// ```
class PremiumActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const PremiumActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          highlightColor: color.withValues(alpha: 0.05),
          splashColor: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: color.withValues(alpha: 0.3),
                      size: 14,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}

/// A container that groups multiple [PremiumStat] widgets together inline.
///
/// **How to use:**
/// This is used internally by [PremiumDashboardSection], but can be used standalone.
/// Pass a list of [PremiumStat] widgets, and it handles the floating container, shadows,
/// and gradient dividers automatically.
class PremiumStatGroup extends StatelessWidget {
  final List<PremiumStat> stats;

  const PremiumStatGroup({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Create a new list interleaving dividers between the stats
    final List<Widget> children = [];
    for (int i = 0; i < stats.length; i++) {
      children.add(Expanded(child: stats[i]));
      if (i < stats.length - 1) {
        children.add(_buildDivider(colorScheme));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      height: 48,
      width: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.outlineVariant.withValues(alpha: 0.0),
            colorScheme.outlineVariant.withValues(alpha: 0.4),
            colorScheme.outlineVariant.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// An individual compact statistic display intended for [PremiumStatGroup].
///
/// **How to use:**
/// Pass this widget into the `stats` list of [PremiumDashboardSection].
/// ```dart
/// PremiumStat(
///   icon: Icons.people_rounded,
///   label: 'Members',
///   value: '24',
///   color: const Color(0xFF3B82F6), // Blue
/// )
/// ```
class PremiumStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const PremiumStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 9.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
