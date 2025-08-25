import 'package:flutter/material.dart';
import 'package:tkt/screens/navi/tools_screen.dart';
import '../dashboard_screen.dart';

import 'settings_screen.dart';

class NaviScreen extends StatefulWidget {
  const NaviScreen({super.key});

  @override
  State<NaviScreen> createState() => _NaviScreenState();
}

class _NaviScreenState extends State<NaviScreen> {
  int _selectedIndex = 0;

  // 使用簡單的小部件列表，避免初始化複雜的頁面
  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ToolsScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const Center(child: Text('頁面不存在'));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用簡化版的 scaffold
    return Scaffold(
      body: _getPageForIndex(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: '儀表板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: '工具',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
} 