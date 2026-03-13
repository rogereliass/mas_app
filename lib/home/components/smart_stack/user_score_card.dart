/// USER SCORE CARD
/// Shows the Scout's current score, rank progression, or points.
/// TO BE IMPLEMENTED: Fetch the scout's points/attendance score from the database.
import 'package:flutter/material.dart';
import 'smart_stack_card_base.dart';

class UserScoreCard extends StatefulWidget {
  const UserScoreCard({super.key});

  @override
  State<UserScoreCard> createState() => _UserScoreCardState();
}

class _UserScoreCardState extends State<UserScoreCard> with AutomaticKeepAliveClientMixin {
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
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _subtitle = 'Keep up the good work!';
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
            colors: [Color(0xFFd97706), Color(0xFFb45309)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SmartStackCardBase(
      icon: Icons.emoji_events_outlined,
      title: 'Your Score',
      subtitle: _subtitle,
      colors: const [Color(0xFFd97706), Color(0xFFb45309)], // Amber
      onColor: Colors.white,
    );
  }
}
