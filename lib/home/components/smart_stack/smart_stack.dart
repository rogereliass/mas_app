import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/logic/auth_provider.dart';
import 'smart_stack_card_base.dart';
import 'next_meeting_card.dart';
import 'latest_update_card.dart';
import 'system_alerts_card.dart';
import 'troop_overview_card.dart';
import 'user_score_card.dart';

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
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
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
        SmartStackCardBase(
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
    // Determine rank to know role type as in home_page.dart
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedRoleRank = authProvider.getRankForRole(role);
    final effectiveRank = selectedRoleRank > 0
        ? selectedRoleRank
        : authProvider.currentUserRoleRank;

    // --------------------------------------------------------------------------
    // ROLE-BASED CARD SELECTION
    //
    // Use this section to determine which cards show up for which roles.
    // `effectiveRank` holds the auth level for the selected role:
    //  - 100+: System Admin
    //  - 90-99: Admin
    //  - 70-89: Troop Head
    //  - 60-69: Troop Leader
    //  - <60: Members/Scouts
    // --------------------------------------------------------------------------

    List<Widget> cards = [];

    // 1. Common cards for everyone (No rank check needed)
    cards.add(const NextMeetingCard());
    cards.add(const LatestUpdateCard());

    // 2. Role-specific cards
    if (effectiveRank >= 90) {
      // Admin / System Admin cards
      cards.add(const SystemAlertsCard());
    } else if (effectiveRank == 60 || effectiveRank == 70) {
      // Troop Head / Leader cards
      cards.add(const TroopOverviewCard());
    } else {
      // Scout / General Member cards
      cards.add(const UserScoreCard());
    }

    return cards;
  }
}
