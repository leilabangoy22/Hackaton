// rescue_personnel_model.dart
class RescuePersonnel {
  final int rescuePersonnelId;
  final List<int> rescuerIds;
  final int responseId;

  const RescuePersonnel({
    required this.rescuePersonnelId,
    required this.rescuerIds,
    required this.responseId,
  });

  factory RescuePersonnel.fromJson(Map<String, dynamic> json) {
    return RescuePersonnel(
      rescuePersonnelId: json['rescue_personel_id'] ?? 0,
      rescuerIds: List<int>.from(json['rescuer_id'] ?? []),
      responseId: json['response_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rescue_personel_id': rescuePersonnelId,
      'rescuer_id': rescuerIds,
      'response_id': responseId,
    };
  }

  @override
  String toString() {
    return 'RescuePersonnel(rescuePersonnelId: $rescuePersonnelId, rescuerIds: $rescuerIds, responseId: $responseId)';
  }
}