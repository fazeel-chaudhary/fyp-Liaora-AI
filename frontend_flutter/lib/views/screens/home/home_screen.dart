import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/providers/bot/bot_provider.dart';
import 'package:frontend_flutter/providers/localization/localization_provider.dart';
import 'package:frontend_flutter/utils/navigation/navigator.dart';
import 'package:frontend_flutter/views/screens/chat/chat_screen.dart';
import 'package:frontend_flutter/views/screens/features/ai_features_screen.dart';
import 'package:frontend_flutter/views/screens/settings/settings.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/views/reusables/app_icon.dart';
import 'package:frontend_flutter/views/reusables/bot_widget.dart';
import 'package:frontend_flutter/views/reusables/icon_box.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, Map<String, dynamic>> botVisuals = {
    "Aura": {"color": const Color(0xFFD72638), "image": "assets/Aura.png"},
    "Blaze": {"color": const Color(0xFFF77F00), "image": "assets/Blaze.png"},
    "Jovi": {"color": const Color(0xFF2A9D8F), "image": "assets/Jovi.png"},
    "Lumen": {"color": const Color(0xFF264653), "image": "assets/Lumen.png"},
    "Echo": {"color": const Color(0xFFF6BD60), "image": "assets/Echo.png"},
    "OrionBot": {"color": const Color(0xFF7209B7), "image": "assets/Orion.png"},
    "Sera": {"color": const Color(0xFF6D4C41), "image": "assets/Sera.png"},
    "Zippy": {"color": const Color(0xFFE94097), "image": "assets/Zippy.png"},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBots();
    });
  }

  Future<void> _loadBots() async {
    final botProvider = Provider.of<BotProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await botProvider.fetchBots(context, userId: authProvider.userId);
    } catch (_) {
      if (mounted) {
        SnackbarHelper.show(context, "Failed to load bots");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final botProvider = Provider.of<BotProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localizationProvider = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBots,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        localizationProvider.t('app_name'),
                        style: TextStyle(
                          fontSize: SizeConfig.height * 0.02,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          IconBox(
                            icon: Icons.auto_awesome_rounded,
                            onTap: () {
                              Navigator.of(
                                context,
                              ).push(elegantRoute(const AIFeaturesScreen()));
                            },
                          ),
                          const SizedBox(width: 8),
                          IconBox(
                            icon: Icons.tune_rounded,
                            onTap: () {
                              Navigator.of(
                                context,
                              ).push(elegantRoute(const SettingsScreen()));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const AppIcon(),
                      SizedBox(height: SizeConfig.height * 0.02),
                      Text(
                        localizationProvider.t('choose_companion'),
                        style: TextStyle(
                          fontSize: SizeConfig.height * 0.02,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: SizeConfig.height * 0.02),
                      Text(
                        "Each companion brings a unique personality\nand perspective to guide your journey",
                        style: TextStyle(
                          fontSize: SizeConfig.height * 0.016,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Bots
              if (botProvider.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (botProvider.bots.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      "No bots found",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: SizeConfig.height * 0.018,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final bot = botProvider.bots[index];
                      final visuals =
                          botVisuals[bot.botname] ??
                          {
                            "color": Colors.grey,
                            "image": "assets/default_bot.png",
                          };

                      return BotWidget(
                        color: visuals["color"],
                        imagePath: visuals["image"],
                        name: bot.botname,
                        description: bot.description,
                        index: index,
                        onTap: () {
                          final userId = authProvider.userId;
                          if (userId == null || userId.isEmpty) {
                            SnackbarHelper.show(
                              context,
                              "User ID missing — please login again",
                            );
                            return;
                          }

                          Navigator.of(context).push(
                            elegantRoute(
                              ChatScreen(
                                userId: userId,
                                botName: bot.botname,
                                botColor: visuals["color"],
                              ),
                            ),
                          );
                        },
                      );
                    }, childCount: botProvider.bots.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
