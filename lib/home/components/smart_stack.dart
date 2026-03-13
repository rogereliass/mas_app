import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/logic/auth_provider.dart';

class SmartStack extends StatefulWidget {
  const SmartStack({super.key});

  @override
  State<SmartStack> createState() => _SmartStackState();
}

class _SmartStackState extends State<SmartStack> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  Timer? _timer;
  int _cardCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageChange);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_cardCount > 1 && _pageController.hasClients) {
        int nextPage = (_currentPageIndex + 1) % _cardCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handlePageChange() {
    final currentPage = _pageController.page?.round() ?? 0;
    if (!mounted || currentPage == _currentPageIndex) {
      return;
    }

    setState(() {
      _currentPageIndex = currentPage;
    });
    
    // Reset timer on manual swipe so it doesn't jump immediately
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final selectedRole = authProvider.selectedRoleName;

    // Based on role, determine which cards to show
    List<Widget> cards = _buildCardsForRole(selectedRole ?? '');

    if (cards.isEmpty) {
      cards = [
        _SmartStackCard(
          icon: Icons.info_outline,
          title: 'Welcome',
          subtitle: 'No specific data for your role.',
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer],
          onColor: theme.colorScheme.onPrimaryContainer,
        ),
      ];
    }
    
    _cardCount = cards.length;

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_currentPageIndex == index) {
                return;
              }

              setState(() {
                _currentPageIndex = index;
              });
            },
            children: cards,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: List.generate(
            cards.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: _currentPageIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPageIndex == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCardsForRole(String role) {
    final theme = Theme.of(context);
    // Determine rank to know role type as in home_page.dart
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedRoleRank = authProvider.getRankForRole(role);
    final effectiveRank = selectedRoleRank > 0
        ? selectedRoleRank
        : authProvider.currentUserRoleRank;

    // Example cards
    List<Widget> cards = [];

    // General user stats (Next Meeting example)
    cards.add(
      _SmartStackCard(
        icon: Icons.event_available_rounded,
        title: 'Next Meeting',
        subtitle: 'No upcoming meetings scheduled.',
        colors: [const Color(0xFF4F46E5), const Color(0xFF7C3AED)], // Indigo to Violet
        onColor: Colors.white,
      ),
    );

    cards.add(
      _SmartStackCard(
        icon: Icons.notifications_active_outlined,
        title: 'Latest Update',
        subtitle: 'You are all caught up!',
        colors: [const Color(0xFF0ea5e9), const Color(0xFF2563eb)], // Sky to Blue
        onColor: Colors.white,
      ),
    );

    if (effectiveRank >= 90) {
      // Admin
      cards.add(
        _SmartStackCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'System Alerts',
          subtitle: 'System is running smoothly.',
          colors: [const Color(0xFFdc2626), const Color(0xFF991b1b)], // Red to Dark Red
          onColor: Colors.white,
        ),
      );
    } else if (effectiveRank == 60 || effectiveRank == 70) {
      // Troop Head / Leader
      cards.add(
        _SmartStackCard(
          icon: Icons.groups_outlined,
          title: 'Troop Overview',
          subtitle: 'Pending approvals: 0',
          colors: [const Color(0xFF059669), const Color(0xFF047857)], // Emerald
          onColor: Colors.white,
        ),
      );
    } else {
      // Scout
      cards.add(
        _SmartStackCard(
          icon: Icons.emoji_events_outlined,
          title: 'Your Score',
          subtitle: 'Keep up the good work!',
          colors: [const Color(0xFFd97706), const Color(0xFFb45309)], // Amber
          onColor: Colors.white,
        ),
      );
    }

    return cards;
  }
}

class _SmartStackCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color onColor;

  const _SmartStackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(icon, size: 120, color: onColor.withValues(alpha: 0.15)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: onColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: onColor),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onColor.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
