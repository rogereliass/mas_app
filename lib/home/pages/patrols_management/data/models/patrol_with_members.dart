import 'patrol.dart';
import 'troop_member.dart';

class PatrolWithMembers {
  final Patrol patrol;
  final TroopMember? patrolLeader;
  final List<TroopMember> members;

  const PatrolWithMembers({
    required this.patrol,
    required this.patrolLeader,
    required this.members,
  });
}
