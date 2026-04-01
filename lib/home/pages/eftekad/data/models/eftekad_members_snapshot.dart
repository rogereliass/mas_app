import '../../../patrols_management/data/models/patrol.dart';
import 'eftekad_member.dart';

class EftekadMembersSnapshot {
  const EftekadMembersSnapshot({required this.patrols, required this.members});

  final List<Patrol> patrols;
  final List<EftekadMember> members;
}
