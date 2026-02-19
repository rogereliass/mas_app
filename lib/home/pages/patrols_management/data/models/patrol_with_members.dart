import 'patrol.dart';
import 'troop_member.dart';

class PatrolWithMembers {
  final Patrol patrol;
  final TroopMember? patrolLeader;
  final TroopMember? assistant1;
  final TroopMember? assistant2;
  final List<TroopMember> members;

  const PatrolWithMembers({
    required this.patrol,
    required this.patrolLeader,
    this.assistant1,
    this.assistant2,
    required this.members,
  });
}
