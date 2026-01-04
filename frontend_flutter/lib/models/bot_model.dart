class Bot {
  final String botname;
  final String personality;
  final String description;

  Bot({
    required this.botname,
    required this.personality,
    required this.description,
  });

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      botname: json['bot_name'] ?? 'Unknown',
      personality: json['personality'] ?? 'N/A',
      description: json['description'] ?? 'No description available',
    );
  }

  Map<String, dynamic> toJson() => {
    "bot_name": botname,
    "personality": personality,
    "description": description,
  };
}
