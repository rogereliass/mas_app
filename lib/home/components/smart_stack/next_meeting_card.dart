/// NEXT MEETING CARD
/// Shows the date and details of the user's upcoming meeting.
/// TO BE IMPLEMENTED: Query the meetings table to find the next scheduled meeting for the user's troop/patrol.
import 'package:flutter/material.dart';
import 'smart_stack_card_base.dart';

class NextMeetingCard extends StatefulWidget {
  const NextMeetingCard({super.key});

  @override
  State<NextMeetingCard> createState() => _NextMeetingCardState();
}

class _NextMeetingCardState extends State<NextMeetingCard> with AutomaticKeepAliveClientMixin {
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
        _subtitle = 'No upcoming meetings scheduled.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const _LoadingCardBase(
        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      );
    }

    return SmartStackCardBase(
      icon: Icons.event_available_rounded,
      title: 'Next Meeting',
      subtitle: _subtitle,
      colors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)], // Indigo to Violet
      onColor: Colors.white,
    );
  }
}

class _LoadingCardBase extends StatelessWidget {
  final List<Color> colors;
  const _LoadingCardBase({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
