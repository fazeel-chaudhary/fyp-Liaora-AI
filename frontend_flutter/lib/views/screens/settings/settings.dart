import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/localization/localization_provider.dart';
import 'package:frontend_flutter/providers/settings/settings_provider.dart';
import 'package:frontend_flutter/utils/navigation/navigator.dart';
import 'package:frontend_flutter/views/screens/features/ai_features_screen.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().loadUserProfile(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final localizationProvider = Provider.of<LocalizationProvider>(context);
    final userInfo = settingsProvider.getUserInfo(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Settings List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // User Profile Tile (from AuthProvider)
                    _buildSettingsTile(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: settingsProvider.isProfileLoading
                          ? "Loading profile..."
                          : (userInfo["name"] ?? "User"),
                      subtitle: settingsProvider.profileError ??
                          (userInfo["email"] ?? "user@liora.ai"),
                      onTap: () {
                        // TODO: Navigate to profile edit
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildSettingsTile(
                      context,
                      icon: Icons.auto_awesome_rounded,
                      title: localizationProvider.t('features_lab'),
                      subtitle:
                          "Manage personality, memory, journal, files, branches and check-ins",
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(elegantRoute(const AIFeaturesScreen()));
                      },
                    ),

                    const SizedBox(height: 12),

                    // Theme Switcher
                    _buildSettingsTile(
                      context,
                      icon: Icons.palette_outlined,
                      title: "Dark Mode",
                      subtitle: "Switch between light and dark theme",
                      trailing: Switch(
                        value: settingsProvider.isDarkMode,
                        onChanged: (value) {
                          settingsProvider.toggleTheme(value);
                        },
                        activeThumbColor: theme.colorScheme.primary,
                        inactiveThumbColor: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                        inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                      onTap: null,
                    ),

                    const SizedBox(height: 12),

                    _buildSettingsTile(
                      context,
                      icon: Icons.language_rounded,
                      title: "Language",
                      subtitle:
                          "Current: ${localizationProvider.languageCode.toUpperCase()}",
                      trailing: DropdownButton<String>(
                        value: localizationProvider.languageCode,
                        underline: const SizedBox.shrink(),
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
                      onTap: null,
                    ),

                    const SizedBox(height: 12),

                    // Delete Conversations
                    _buildSettingsTile(
                      context,
                      icon: Icons.delete_outline_rounded,
                      iconColor: theme.colorScheme.error,
                      title: "Delete All Conversations",
                      subtitle: "Clear your entire chat history",
                      onTap: () {
                        // TODO: Show confirmation dialog
                      },
                    ),

                    const SizedBox(height: 12),

                    // Logout
                    _buildSettingsTile(
                      context,
                      icon: Icons.logout_rounded,
                      iconColor: theme.colorScheme.error,
                      title: "Logout",
                      subtitle: "Sign out of your account",
                      onTap: () => settingsProvider.logout(context),
                    ),

                    const SizedBox(height: 12),

                    // About Us
                    _buildSettingsTile(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: "About Us",
                      subtitle: "Learn more about Liora AI",
                      onTap: () {
                        // TODO: Navigate to about page
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
