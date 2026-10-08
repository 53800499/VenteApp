/// Représente le résultat d'une évaluation de règle par le Policy Engine.
class PolicyDecision {
  const PolicyDecision.allow()
      : isAllowed = true,
        reason = null,
        errorCode = null,
        requiredPermission = null;

  const PolicyDecision.deny({
    required this.reason,
    this.errorCode,
    this.requiredPermission,
  }) : isAllowed = false;

  final bool isAllowed;
  final String? reason;
  final String? errorCode;
  final String? requiredPermission;

  @override
  String toString() {
    if (isAllowed) return 'PolicyDecision.allow()';
    return 'PolicyDecision.deny(reason: $reason, errorCode: $errorCode, requiredPermission: $requiredPermission)';
  }
}
