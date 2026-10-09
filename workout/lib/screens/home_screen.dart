import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

/// Bottom navigation shell hosting the three main screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      WorkoutScreen(onGoToSettings: () => _goToTab(2)),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: surfaceColor,
        items: const [
          BottomNavigationBarItem(
            icon: Text('💪', style: TextStyle(fontSize: 20)),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Text('📊', style: TextStyle(fontSize: 20)),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Text('⚙️', style: TextStyle(fontSize: 20)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
