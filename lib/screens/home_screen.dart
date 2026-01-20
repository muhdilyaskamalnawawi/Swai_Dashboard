import 'dart:ui';

import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/fish_info_screen.dart';
import '../screens/settings_screen.dart';

class _HomeTab {
  const _HomeTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const HistoryScreen(),
      const FishInfoScreen(),
      const SettingsScreen(),
    ];
  }

  static const List<_HomeTab> _tabs = [
    _HomeTab(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
    ),
    _HomeTab(
      label: 'History',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
    ),
    _HomeTab(
      label: 'Fish Info',
      icon: Icons.info_outline,
      activeIcon: Icons.info,
    ),
    _HomeTab(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  final List<String> _titles = [
    'Dashboard',
    'History',
    'Fish Info',
    'Settings',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/swai_inapp.png',
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        elevation: 2,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _dashboardKey.currentState?.refreshLatestReading();
              },
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _FloatingTabBar(
        selectedIndex: _selectedIndex,
        onSelected: _onItemTapped,
        tabs: _tabs,
      ),
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.tabs,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_HomeTab> tabs;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // More generous sizing for smooth appearance
    final isCompact = screenWidth < 320;
    const floatOffset = 28.0; // more breathing room
    final activeButtonSize = isCompact ? 60.0 : 70.0; // larger active button
    final inactiveButtonSize = isCompact ? 50.0 : 56.0; // larger inactive
    final buttonSpacing = isCompact ? 12.0 : 16.0; // more space between buttons

    // Keep this widget's height tight; don't let it expand and cover the body.
    final height = bottomInset + floatOffset + activeButtonSize + 12;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: bottomInset + floatOffset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isActive = index == selectedIndex;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: buttonSpacing / 2,
                  ),
                  child: _FloatingTabButton(
                    label: tab.label,
                    icon: isActive ? tab.activeIcon : tab.icon,
                    isActive: isActive,
                    onTap: () => onSelected(index),
                    activeSize: activeButtonSize,
                    inactiveSize: inactiveButtonSize,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingTabButton extends StatefulWidget {
  const _FloatingTabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.activeSize = 64.0,
    this.inactiveSize = 48.0,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final double activeSize;
  final double inactiveSize;

  static const _activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0EA5E9), // sky-500 (matches app theme)
      Color(0xFF0284C7), // sky-600
    ],
  );

  @override
  State<_FloatingTabButton> createState() => _FloatingTabButtonState();
}

class _FloatingTabButtonState extends State<_FloatingTabButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  static const _inactiveColor = Color(0xFF94A3B8); // slate-400
  static const _hoverColor = Color(0xFF0284C7); // sky-600
  static const _pressedColor = Color(0xFF0369A1); // sky-700

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.isActive;
    final double size = isActive ? widget.activeSize : widget.inactiveSize;
    final double iconSize = isActive ? 28 : 22;

    final Color targetIconColor = isActive
        ? Colors.white
        : (_isPressed
            ? _pressedColor
            : (_isHovered ? _hoverColor : _inactiveColor));

    return Semantics(
      button: true,
      selected: isActive,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovered) {
            if (isActive) return;
            if (_isHovered == hovered) return;
            setState(() => _isHovered = hovered);
          },
          onHighlightChanged: (pressed) {
            if (isActive) return;
            if (_isPressed == pressed) return;
            setState(() => _isPressed = pressed);
          },
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            width: size,
            height: size,
            transformAlignment: Alignment.center,
            transform: Matrix4.translationValues(0, isActive ? -12 : 0, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive ? _FloatingTabButton._activeGradient : null,
              color: isActive ? null : Colors.white.withValues(alpha: 0.90),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: isActive ? 20 : 12,
                  offset: Offset(0, isActive ? 6 : 4),
                  spreadRadius: isActive ? 2 : 0,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isActive) const _PulseOverlay(),
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: targetIconColor),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      builder: (context, color, _) {
                        return Icon(
                          widget.icon,
                          size: iconSize,
                          color: color,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseOverlay extends StatefulWidget {
  const _PulseOverlay();

  @override
  State<_PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<_PulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final scale = 1.0 + (_t.value * 0.5);
          final opacity = 0.20 * (1.0 - _t.value);
          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(opacity),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}
