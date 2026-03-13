/// TROOP OVERVIEW CARD
/// Shows a quick summary for Troop Heads/Leaders regarding their troop.
/// TO BE IMPLEMENTED: Fetch pending user approvals, total members, or other troop-specific stats.
import 'package:flutter/material.dart';
import 'smart_stack_card_base.dart';

class TroopOverviewCard extends StatefulWidget {
  const TroopOverviewCard({super.key});

  @override
  State<TroopOverviewCard> createState() => _TroopOverviewCardState();
}

class _TroopOverviewCardState extends State<TroopOverviewCard> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String _subtitle = 'Loading...';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _subtitle = 'Pending approvals: 0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF059669), Color(0xFF047857)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SmartStackCardBase(
      icon: Icons.groups_outlined,
      title: 'Troop Overview',
      subtitle: _subtitle,
      colors: const [Color(0xFF059669), Color(0xFF047857)], // Emerald
      onColor: Colors.white,
    );
  }
}
