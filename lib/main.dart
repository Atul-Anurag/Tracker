import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_tracker/services/transaction_service.dart';
import 'package:travel_tracker/ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelTrackerApp());
}

class TravelTrackerApp extends StatelessWidget {
  const TravelTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: MultiProvider(
        providers: [
          Provider<TransactionService>(create: (_) => TransactionService()),
        ],
        child: const HomeScreen(),
      ),
    );
  }
}
