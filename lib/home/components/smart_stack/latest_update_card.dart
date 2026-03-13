/// LATEST UPDATE CARD
/// Shows the most recent notification or system update for the user.
/// TO BE IMPLEMENTED: Fetch the latest notification/announcement from the database.
import 'package:flutter/material.dart';
import 'smart_stack_card_base.dart';

class LatestUpdateCard extends StatefulWidget {
  const LatestUpdateCard({super.key});

  @override
  State<LatestUpdateCard> createState() => _LatestUpdateCardState();
}

class _LatestUpdateCardState extends State<LatestUpdateCard> with AutomaticKeepAliveClientMixin {
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _subtitle = 'You are all caught up!';
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
            colors: [Color(0xFF0ea5e9), Color(0xFF2563eb)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SmartStackCardBase(
      icon: Icons.notifications_active_outlined,
      title: 'Latest Update',
      subtitle: _subtitle,
      colors: const [Color(0xFF0ea5e9), Color(0xFF2563eb)], // Sky to Blue
      onColor: Colors.white,
    );
  }
}
