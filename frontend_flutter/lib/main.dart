import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/providers/bot/bot_provider.dart';
import 'package:frontend_flutter/providers/chat/chat_provider.dart';
import 'package:frontend_flutter/providers/settings/settings_provider.dart';
import 'package:frontend_flutter/utils/theme/themes.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/views/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BotProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Initialize MediaQuery helper
          SizeConfig.init(context);

          final settingsProvider = Provider.of<SettingsProvider>(context);

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Liora AI",
            theme: lightMode,
            darkTheme: darkMode,
            themeMode: settingsProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
