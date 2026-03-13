import 'package:flutter/material.dart';
import 'smart_stack_card_base.dart';

class SystemAlertsCard extends StatefulWidget {
  const SystemAlertsCard({super.key});

  @override
  State<SystemAlertsCard> createState() => _SystemAlertsCardState();
}

class _SystemAlertsCardState extends State<SystemAlertsCard> with AutomaticKeepAliveClientMixin {
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
        _subtitle = 'System is running smoothly.';
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
            colors: [Color(0xFFdc2626), Color(0xFF991b1b)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SmartStackCardBase(
      icon: Icons.admin_panel_settings_outlined,
      title: 'System Alerts',
      subtitle: _subtitle,
      colors: const [Color(0xFFdc2626), Color(0xFF991b1b)], // Red to Dark Red
      onColor: Colors.white,
    );
  }
}
