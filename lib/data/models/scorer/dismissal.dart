enum DismissalType {
  bowled, caught, lbw, runOut, stumped, hitWicket, retiredOut, obstructingField
}

class Dismissal {
  final DismissalType type;
  final String batsmanId;
  final String? bowlerId;
  final String? fielderId;
  final String? runOutEnd;

  const Dismissal({
    required this.type,
    required this.batsmanId,
    this.bowlerId,
    this.fielderId,
    this.runOutEnd,
  });

  String describe(String batsmanName, {String? bowlerName, String? fielderName}) {
    switch (type) {
      case DismissalType.bowled:
        return 'b ${bowlerName ?? 'Unknown'}';
      case DismissalType.caught:
        return 'c ${fielderName ?? 'Unknown'} b ${bowlerName ?? 'Unknown'}';
      case DismissalType.lbw:
        return 'lbw b ${bowlerName ?? 'Unknown'}';
      case DismissalType.runOut:
        return 'run out (${fielderName ?? 'Unknown'})';
      case DismissalType.stumped:
        return 'st ${fielderName ?? 'Unknown'} b ${bowlerName ?? 'Unknown'}';
      case DismissalType.hitWicket:
        return 'hit wicket b ${bowlerName ?? 'Unknown'}';
      case DismissalType.retiredOut:
        return 'retired out';
      case DismissalType.obstructingField:
        return 'obstructing the field';
    }
  }
}
