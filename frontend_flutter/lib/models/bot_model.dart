class Bot {
  final String botname;
  final String personality;
  final String description;
  final bool isCustom;
  final String? avatarEmoji;

  Bot({
    required this.botname,
    required this.personality,
    required this.description,
    this.isCustom = false,
    this.avatarEmoji,
  });

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      botname: json['bot_name'] ?? 'Unknown',
      personality: json['personality'] ?? 'N/A',
      description: json['description'] ?? 'No description available',
      isCustom: json['is_custom'] ?? false,
      avatarEmoji: json['avatar_emoji'],
    );
  }

  Map<String, dynamic> toJson() => {
    "bot_name": botname,
    "personality": personality,
    "description": description,
    "is_custom": isCustom,
    "avatar_emoji": avatarEmoji,
  };
}
