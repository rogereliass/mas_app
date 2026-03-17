import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/logic/auth_provider.dart';
import '../pages/patrols_management/logic/patrols_management_provider.dart';
import '../pages/patrols_management/ui/components/patrol_card.dart';

class HomePatrolCard extends StatefulWidget {
  const HomePatrolCard({super.key});

  @override
  State<HomePatrolCard> createState() => _HomePatrolCardState();
}

class _HomePatrolCardState extends State<HomePatrolCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final provider = Provider.of<PatrolsManagementProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Set role context to ensure scoped data fetching
    if (auth.selectedRoleName != null) {
      provider.setRoleContext(auth.selectedRoleName!);
    }
    
    await provider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final provider = Provider.of<PatrolsManagementProvider>(context);

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final userId = auth.currentUserProfile?.id;
    if (userId == null) return const SizedBox.shrink();

    // Find the patrol where the user is either the leader or an assistant
    final userPatrols = provider.patrolsWithMembers.where((p) {
      return p.patrol.patrolLeaderProfileId == userId ||
             p.patrol.assistant1ProfileId == userId ||
             p.patrol.assistant2ProfileId == userId;
    }).toList();

    if (userPatrols.isEmpty) {
      // If not a leader, check if they are just a member
      final memberPatrols = provider.patrolsWithMembers.where((p) {
        return p.members.any((m) => m.id == userId);
      }).toList();
      
      if (memberPatrols.isEmpty) return const SizedBox.shrink();
      
      final myPatrol = memberPatrols.first;
      return _buildHeader(context, myPatrol);
    }

    final myPatrol = userPatrols.first;
    return _buildHeader(context, myPatrol);
  }

  Widget _buildHeader(BuildContext context, dynamic myPatrol) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Your Patrol',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        PatrolCard(
          item: myPatrol,
        ),
      ],
    );
  }
}
