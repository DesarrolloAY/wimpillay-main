import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wimpillay_main/screens/auth/auth_gate.dart';
import 'firebase_options.dart';
import 'package:wimpillay_main/utils/styles.dart';
import 'screens/passenger/passenger_tickets_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tu inicialización de Firebase existente...
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- AGREGA ESTA LÍNEA PARA CORREGIR EL ERROR ---
  await initializeDateFormatting('es');
  // ------------------------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wimpillay Transportes',

      // --- Nuevo Tema Elegante, Atractivo y Moderno ---
      theme: ThemeData(
        brightness:
            Brightness.dark, // Seguimos con un fondo oscuro, pero más "cálido"
        primaryColor:
            AppColors.primaryGreenLight, // Verde principal para interacciones
        colorScheme: const ColorScheme.dark(
          // Definir un ColorScheme oscuro
          primary: Color(0xFF7CBF39),
          secondary: AppColors.accentOrange,
          background: AppColors.primaryBackground,
          surface: AppColors.cardBackground, // Para Cards y Surfaces
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: AppColors.lightText,
          onSurface: AppColors.lightText,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.primaryBackground, // Fondo de la app
        cardColor: AppColors.cardBackground, // Color de las tarjetas

        // Estilo de botones
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                AppColors.primaryGreenLight, // Botones con el verde más claro
            foregroundColor: AppColors.lightText, // Texto de botón blanco
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // Estilo de campos de texto
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBackground, // Fondo de campos de texto
          hintStyle: const TextStyle(color: AppColors.secondaryText),
          labelStyle: const TextStyle(color: AppColors.secondaryText),
          prefixIconColor: AppColors.secondaryText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            // Borde cuando el campo está enfocado
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryGreenLight, width: 2),
          ),
        ),

        // Estilo del AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor:
              AppColors.primaryBackground, // AppBar coincide con el fondo
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.lightText,
            fontSize: 22, // Títulos un poco más grandes
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
          iconTheme:
              IconThemeData(color: AppColors.lightText), // Iconos blancos
        ),

        // Estilo del texto
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.lightText),
          displayMedium: TextStyle(color: AppColors.lightText),
          displaySmall: TextStyle(color: AppColors.lightText),
          headlineLarge: TextStyle(color: AppColors.lightText),
          headlineMedium: TextStyle(color: AppColors.lightText),
          headlineSmall:
              TextStyle(color: AppColors.lightText), // Para "Bienvenido"
          titleLarge: TextStyle(color: AppColors.lightText),
          titleMedium: TextStyle(color: AppColors.lightText), // Para labels
          titleSmall: TextStyle(color: AppColors.lightText),
          bodyLarge: TextStyle(color: AppColors.lightText),
          bodyMedium: TextStyle(color: AppColors.lightText),
          bodySmall:
              TextStyle(color: AppColors.secondaryText), // Para texto más tenue
          labelLarge: TextStyle(color: AppColors.lightText),
          labelMedium: TextStyle(color: AppColors.secondaryText),
          labelSmall: TextStyle(color: AppColors.secondaryText),
        ),
      ),
      // --- Fin del Tema ---

      home: const AuthGate(),

      routes: {
        '/passenger-tickets': (context) => const PassengerTicketsScreen(),
      },
    );
  }
}
