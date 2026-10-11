import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mewar_guardian/services/api_service.dart';
import 'package:mewar_guardian/screens/home_screen.dart';
import 'package:mewar_guardian/screens/report_screen.dart';
import 'package:mewar_guardian/screens/tracking_screen.dart';
import 'package:mewar_guardian/screens/map_screen.dart';
import 'package:mewar_guardian/screens/auth_screen.dart';
import 'package:mewar_guardian/screens/forgot_password_screen.dart';
import 'package:mewar_guardian/screens/ai_chat_screen.dart';
import 'package:mewar_guardian/screens/my_emergencies_screen.dart';
import 'package:mewar_guardian/config/campus_locations_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen', () {
    Widget buildHome() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: HomeScreen()),
    );

    testWidgets('Shows Mewar Guardian branding & SOS button', (WidgetTester tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();
      expect(find.text('MEWAR GUARDIAN'), findsOneWidget);
      expect(find.text('REPORT EMERGENCY (SOS)'), findsOneWidget);
    });

    testWidgets('Shows Quick Emergency Categories and Campus Services', (WidgetTester tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pump();
      expect(find.text('Medical Aid'), findsOneWidget);
      expect(find.text('Fire Alert'), findsOneWidget);
      expect(find.text('Campus Security'), findsOneWidget);
      expect(find.text('Accident'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Campus Map & Directory'), 200);
      expect(find.text('Campus Map & Directory'), findsOneWidget);
      expect(find.text('Rakshak AI Assistant'), findsOneWidget);
      expect(find.text('My Submitted Reports'), findsOneWidget);
    });
  });

  group('ReportScreen Quick Emergency Preselection & Locations', () {
    Widget buildReportWithCat(String? cat) => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: MaterialApp(home: ReportScreen(initialCategory: cat)),
    );

    testWidgets('Preselects Fire emergency category when opened from Quick Fire', (WidgetTester tester) async {
      await tester.pumpWidget(buildReportWithCat('Fire'));
      await tester.pump();
      // The ChoiceChip for Fire should be selected
      final fireChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fire'));
      expect(fireChip.selected, isTrue);
    });

    testWidgets('Preselects Medical Emergency category when opened from Quick Medical Aid', (WidgetTester tester) async {
      await tester.pumpWidget(buildReportWithCat('Medical Emergency'));
      await tester.pump();
      final medChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Medical Emergency'));
      expect(medChip.selected, isTrue);
    });

    testWidgets('Displays manual location selector and GPS option', (WidgetTester tester) async {
      await tester.pumpWidget(buildReportWithCat(null));
      await tester.pump();
      expect(find.text('Select Campus Location Manually'), findsOneWidget);
      expect(find.text('Detect Location via GPS'), findsOneWidget);
    });

    test('Campus Locations Dataset has all 33 canonical locations', () {
      expect(CampusLocationsData.allLocations.length, 33);
      expect(CampusLocationsData.findByName('Engineering Block'), isNotNull);
      expect(CampusLocationsData.findByName('Sanga Hostel'), isNotNull);
      expect(CampusLocationsData.findByName('Hospital'), isNotNull);
      expect(CampusLocationsData.findByName('main building'), isNotNull);
    });

    test('Campus Locations search filters correctly', () {
      final results = CampusLocationsData.search('Hostel');
      expect(results.length, greaterThan(3));
      for (final r in results) {
        expect(r.name.toLowerCase().contains('hostel') || r.category == 'Hostel', isTrue);
      }
    });

    testWidgets('Renders smart auto-voice input and photo evidence section', (WidgetTester tester) async {
      await tester.pumpWidget(buildReportWithCat(null));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('Describe by Voice'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Describe by Voice'), findsOneWidget);
      expect(find.textContaining('Smart Voice • Auto-Detects'), findsOneWidget);
    });
  });

  group('AuthScreen & Registration', () {
    Widget buildAuth() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: AuthScreen()),
    );

    testWidgets('Renders Login, Register tabs and Emergency Bypass', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuth());
      await tester.pump();
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Register Student'), findsOneWidget);
      expect(find.text('IMMEDIATE EMERGENCY SOS'), findsOneWidget);
    });

    testWidgets('Shows Forgot Password button on Login tab', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuth());
      await tester.pump();
      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    Widget buildForgotPassword() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: ForgotPasswordScreen()),
    );

    testWidgets('Renders step 1 with enrollment, email, and send recovery code button', (WidgetTester tester) async {
      await tester.pumpWidget(buildForgotPassword());
      await tester.pump();

      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.text('Identify Your Account'), findsOneWidget);
      expect(find.text('Enrollment Number'), findsOneWidget);
      expect(find.text('Registered Personal Email'), findsOneWidget);
      expect(find.text('Send Recovery Code via Email'), findsOneWidget);
    });

    testWidgets('Validates empty inputs before sending OTP', (WidgetTester tester) async {
      await tester.pumpWidget(buildForgotPassword());
      await tester.pump();

      // Tap Send Recovery Code with empty inputs
      await tester.tap(find.text('Send Recovery Code via Email'));
      await tester.pump();

      expect(find.text('Please enter a valid university enrollment number (e.g., MUR2500001).'), findsOneWidget);
    });
  });

  group('CampusMapScreen', () {
    Widget buildMap() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: CampusMapScreen()),
    );

    testWidgets('Renders dual tabs for Map View and Directory List', (WidgetTester tester) async {
      await tester.pumpWidget(buildMap());
      await tester.pump();
      expect(find.text('Map View'), findsOneWidget);
      expect(find.text('Directory List'), findsOneWidget);
    });
  });

  group('MyEmergenciesScreen', () {
    Widget buildMyEmergencies() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: MyEmergenciesScreen()),
    );

    testWidgets('Renders app bar and refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(buildMyEmergencies());
      await tester.pump();
      expect(find.text('My Emergency Reports'), findsOneWidget);
    });
  });

  group('TrackingScreen', () {
    Widget buildTracking() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(
        home: TrackingScreen(
          emergencyId: 1,
          initialData: {
            'id': 1,
            'emergency_type': 'Medical Emergency',
            'status': 'Pending',
            'location': 'Hospital',
            'responder': 'Medical Team',
            'estimated_minutes': 5,
            'priority': 'HIGH',
            'student_name': 'Aarav Sharma',
            'mobile_number': '9000000001',
            'description': 'Test emergency',
            'time': '2026-01-01 12:00:00',
            'recommendation': 'Stay calm.',
          },
        ),
      ),
    );

    testWidgets('Shows incident details and response progress', (WidgetTester tester) async {
      await tester.pumpWidget(buildTracking());
      await tester.pump();
      expect(find.text('Emergency Incident #1'), findsOneWidget);
      expect(find.text('RESPONSE PROGRESS'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });
  });

  group('AiChatScreen', () {
    Widget buildChat() => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ApiService())],
      child: const MaterialApp(home: AiChatScreen()),
    );

    testWidgets('Renders Mewar Guardian AI Chat title and initial greeting', (WidgetTester tester) async {
      await tester.pumpWidget(buildChat());
      await tester.pump();
      expect(find.text('Mewar Guardian AI Chat'), findsOneWidget);
      expect(find.textContaining('Main Mewar Guardian AI hoon'), findsOneWidget);
    });
  });
}
