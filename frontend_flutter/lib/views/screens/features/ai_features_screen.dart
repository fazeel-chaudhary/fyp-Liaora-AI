import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/providers/bot/bot_provider.dart';
import 'package:frontend_flutter/providers/chat/chat_provider.dart';
import 'package:frontend_flutter/providers/feature/feature_provider.dart';
import 'package:frontend_flutter/providers/localization/localization_provider.dart';
import 'package:provider/provider.dart';

class AIFeaturesScreen extends StatefulWidget {
  const AIFeaturesScreen({super.key});

  @override
  State<AIFeaturesScreen> createState() => _AIFeaturesScreenState();
}

class _AIFeaturesScreenState extends State<AIFeaturesScreen> {
  final TextEditingController _botNameController = TextEditingController();
  final TextEditingController _botPersonalityController =
      TextEditingController();
  final TextEditingController _botDescriptionController =
      TextEditingController();
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String _selectedAvatar = '🤖';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      if (userId != null && userId.isNotEmpty) {
        context.read<FeatureProvider>().initialize(userId: userId);
      }
    });
  }

  @override
  void dispose() {
    _botNameController.dispose();
    _botPersonalityController.dispose();
    _botDescriptionController.dispose();
    _journalController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final botProvider = context.watch<BotProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final featureProvider = context.watch<FeatureProvider>();
    final localizationProvider = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId;

    final memoryStats = featureProvider.buildMemoryStats(
      messages: chatProvider.messages,
      emotionStats: chatProvider.emotionStats,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationProvider.t('features_lab')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Multi-Personality AI System',
            subtitle: '8 tones + adaptive switching based on detected emotion.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: chatProvider.activePersonality,
                  decoration: const InputDecoration(
                    labelText: 'Active personality',
                  ),
                  items: ChatProvider.personalityModes
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      chatProvider.setActivePersonality(value);
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Adaptive personality switching'),
                  subtitle: Text('Detected emotion: ${chatProvider.detectedEmotion}'),
                  value: chatProvider.adaptiveSwitching,
                  onChanged: chatProvider.setAdaptiveSwitching,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Memory Dashboard',
            subtitle: 'Conversation analytics and behavior insights.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: memoryStats.entries
                  .map(
                    (entry) => Chip(
                      label: Text('${entry.key}: ${entry.value}'),
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          _SectionCard(
            title: 'Custom Bot Creator',
            subtitle: 'Create bots with name, personality, and avatar.',
            child: Column(
              children: [
                TextField(
                  controller: _botNameController,
                  decoration: const InputDecoration(labelText: 'Bot name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _botPersonalityController,
                  decoration: const InputDecoration(labelText: 'Personality traits'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _botDescriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAvatar,
                  decoration: const InputDecoration(labelText: 'Avatar'),
                  items: const ['🤖', '🧠', '✨', '🌙', '🔥', '🌱']
                      .map(
                        (emoji) => DropdownMenuItem(
                          value: emoji,
                          child: Text(emoji),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedAvatar = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await botProvider.addCustomBot(
                      name: _botNameController.text,
                      personality: _botPersonalityController.text,
                      description: _botDescriptionController.text,
                      avatarEmoji: _selectedAvatar,
                      userId: userId,
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Custom bot saved')),
                    );
                  },
                  child: const Text('Save Custom Bot'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved custom bots: ${botProvider.customBots.length}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Private Journal Mode',
            subtitle: 'PIN-protected journal entries with secure PIN storage.',
            child: Column(
              children: [
                TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: 'Set/Update PIN',
                    hintText: '4-6 digits',
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await featureProvider.setJournalPin(
                              _pinController.text,
                            );
                          } on ArgumentError catch (error) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(error.message.toString())),
                            );
                            return;
                          }
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Journal PIN updated')),
                          );
                        },
                        child: const Text('Save PIN'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final valid = await featureProvider.verifyJournalPin(
                            _pinController.text,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                valid ? 'PIN verified' : 'Incorrect PIN',
                              ),
                            ),
                          );
                        },
                        child: const Text('Verify PIN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _journalController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Journal entry',
                    hintText: 'Write a private note...',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await featureProvider.addJournalEntry(
                      _journalController.text,
                      userId: userId,
                    );
                    _journalController.clear();
                  },
                  child: const Text('Save Entry'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Entries: ${featureProvider.journalEntries.length}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Memory File Uploads',
            subtitle: 'Attach local files as memory context references.',
            child: Column(
              children: [
                FilledButton.tonal(
                  onPressed: () => featureProvider.pickMemoryFile(userId: userId),
                  child: const Text('Upload Memory File'),
                ),
                const SizedBox(height: 8),
                ...featureProvider.memoryFiles.take(5).map(
                      (file) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(file),
                      ),
                    ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Daily Check-ins & Recommendations',
            subtitle: 'Capture mood and get adaptive suggestions.',
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _moodButton(featureProvider, 'happy', 'Happy'),
                    _moodButton(featureProvider, 'neutral', 'Neutral'),
                    _moodButton(featureProvider, 'stressed', 'Stressed'),
                    _moodButton(featureProvider, 'sad', 'Sad'),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    featureProvider.recommendationForMood(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            title: 'Multilingual Support',
            subtitle: 'Switch app language quickly.',
            child: DropdownButtonFormField<String>(
              initialValue: localizationProvider.languageCode,
              decoration: const InputDecoration(labelText: 'Language'),
              items: localizationProvider.supportedLanguages
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(code.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  localizationProvider.setLanguage(value);
                }
              },
            ),
          ),
          _SectionCard(
            title: 'Branching Conversations & Sync',
            subtitle: 'Create branch paths and track sync state.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          final branchName =
                              'branch_${DateTime.now().millisecondsSinceEpoch % 100000}';
                          chatProvider.createBranch(branchName);
                        },
                        child: const Text('Create branch'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: chatProvider.activeBranch,
                  decoration: const InputDecoration(labelText: 'Active branch'),
                  items: chatProvider.branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch,
                          child: Text(branch),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      chatProvider.switchBranch(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chatProvider.lastSyncedAt == null
                        ? 'Sync status: waiting for first sync'
                        : 'Last sync: ${chatProvider.lastSyncedAt}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodButton(FeatureProvider provider, String moodKey, String label) {
    final userId = context.read<AuthProvider>().userId;
    return ActionChip(
      label: Text(label),
      onPressed: () => provider.completeDailyCheckIn(moodKey, userId: userId),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
