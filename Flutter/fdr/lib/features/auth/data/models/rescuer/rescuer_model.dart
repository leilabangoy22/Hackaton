// rescuer_model.dart
import 'package:fdr/features/auth/data/models/user_model.dart';

class Rescuer {
  final User user;
  final String team;
  final List<String> skills;
  final int completedOperations;
  final double rating;
  final RescuerStatus status;

  const Rescuer({
    required this.user,
    required this.team,
    this.skills = const [],
    this.completedOperations = 0,
    this.rating = 0.0,
    required this.status,
  });

  int get id => user.id;
  String get name => user.name;
  String get email => user.email;
  String get phone => user.phone;
  double? get currentLatitude => user.latitude;
  double? get currentlongitude => user.longitude;
  bool get isActive => user.isActive;

  factory Rescuer.fromUser(
    User user, {
    String team = 'No Team',
    List<String> skills = const [],
    int completedOperations = 0,
    double rating = 0.0,
    RescuerStatus? status,
  }) {
    return Rescuer(
      user: user,
      team: team,
      skills: skills,
      completedOperations: completedOperations,
      rating: rating,
      status:
          status ??
          (user.isActive ? RescuerStatus.online : RescuerStatus.offline),
    );
  }

  factory Rescuer.fromJson(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    return Rescuer(
      user: user,
      team: json['team'] ?? 'No Team',
      skills: List<String>.from(json['skills'] ?? []),
      completedOperations: json['completed_operations'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      status: _parseStatusFromUser(user),
    );
  }

  static RescuerStatus _parseStatusFromUser(User user) {
    if (!user.isActive) return RescuerStatus.offline;
    return RescuerStatus.online;
  }

  Rescuer copyWith({
    User? user,
    String? team,
    List<String>? skills,
    int? completedOperations,
    double? rating,
    RescuerStatus? status,
  }) {
    return Rescuer(
      user: user ?? this.user,
      team: team ?? this.team,
      skills: skills ?? this.skills,
      completedOperations: completedOperations ?? this.completedOperations,
      rating: rating ?? this.rating,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...user.toJson(),
      'team': team,
      'skills': skills,
      'completed_operations': completedOperations,
      'rating': rating,
    };
  }

  // Helper methods
  bool get isOnline => status == RescuerStatus.online && user.isActive;
  bool get isOnMission => status == RescuerStatus.busy;
  bool get isOffline => status == RescuerStatus.offline || !user.isActive;

  String get statusDisplayText {
    if (!user.isActive) return 'Inactive';
    switch (status) {
      case RescuerStatus.online:
        return 'Available';
      case RescuerStatus.busy:
        return 'On Mission';
      case RescuerStatus.offline:
        return 'Offline';
    }
  }

  @override
  String toString() {
    return 'Rescuer(user: $user, team: $team, status: $status)';
  }
}

enum RescuerStatus { online, busy, offline }
