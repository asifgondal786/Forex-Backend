# Phase 1 Component Showcase & Code Examples

## Quick Component Usage Examples

Copy-paste ready code for integrating Phase 1 components into any Flutter widget.

---

## 1️⃣ AuthHeader - Copy & Use

### Minimal Example
```dart
import 'widgets/auth_header.dart';

// In your build method:
AuthHeader(
  isLoggedIn: true,
  userName: 'John Trader',
  riskLevel: 'Moderate',
  onSignIn: () => print('Sign in tapped'),
  onCreateAccount: () => print('Create account tapped'),
  onLogout: () => print('Logout tapped'),
)
```

### With Provider Integration
```dart
import 'package:provider/provider.dart';
import 'widgets/auth_header.dart';

// In your build method:
Consumer<UserProvider>(
  builder: (context, userProvider, _) {
    return AuthHeader(
      isLoggedIn: userProvider.isAuthenticated,
      userName: userProvider.user?.name,
      userEmail: userProvider.user?.email,
      riskLevel: 'Moderate', // TODO: Get from user data
      onSignIn: () => Navigator.pushNamed(context, '/login'),
      onCreateAccount: () => Navigator.pushNamed(context, '/signup'),
      onLogout: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  userProvider.logout();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  },
)
```

---

## 2️⃣ TrustBar - Copy & Use

### Minimal Example
```dart
import 'widgets/trust_bar.dart';

// At the bottom of your dashboard:
TrustBar(
  readOnlyMode: false,
  withdrawalEnabled: false,
  tradesWithinLimits: true,
  riskLevel: 'Moderate',
)
```

### In a Column
```dart
Column(
  children: [
    Expanded(
      child: DashboardContent(), // Your main content
    ),
    // Trust bar at bottom
    TrustBar(
      readOnlyMode: false,
      withdrawalEnabled: false,
      tradesWithinLimits: true,
      riskLevel: 'Moderate',
    ),
  ],
)
```

### Custom Status Colors
```dart
// You can modify TrustBar widget to accept custom settings:
TrustBar(
  readOnlyMode: userProvider.user?.readOnly ?? false,
  withdrawalEnabled: userProvider.user?.canWithdraw ?? false,
  tradesWithinLimits: taskProvider.allTradesWithinLimits,
  riskLevel: userProvider.user?.riskLevel ?? 'Moderate',
)
```

---

## 3️⃣ AIStatusBanner - Copy & Use

### Minimal Example
```dart
import 'widgets/ai_status_banner.dart';

AIStatusBanner(
  aiEnabled: true,
  aiMode: 'Full Auto',
  dataSourcesMonitored: 12,
  confidenceScore: 82.0,
  onAITapped: () {
    print('AI settings tapped');
    // Open AI settings dialog
  },
)
```

### With Real Data
```dart
Consumer2<TaskProvider, UserProvider>(
  builder: (context, taskProvider, userProvider, _) {
    return AIStatusBanner(
      aiEnabled: taskProvider.aiEnabled,
      aiMode: taskProvider.currentAIMode, // 'Full Auto', etc
      dataSourcesMonitored: taskProvider.dataSourceCount,
      confidenceScore: taskProvider.currentConfidence,
      onAITapped: () {
        // Show AI settings bottom sheet
        showModalBottomSheet(
          context: context,
          builder: (context) => const AISettingsSheet(),
        );
      },
    );
  },
)
```

### Confidence Score Animation
```dart
// Confidence score updates smoothly:
AIStatusBanner(
  aiEnabled: true,
  aiMode: 'Full Auto',
  dataSourcesMonitored: 12,
  confidenceScore: 82.0, // Change this value and watch it update
  onAITapped: () {},
)

// Animation happens automatically - no extra code needed!
```

---

## 4️⃣ EmergencyStopButton - Copy & Use

### Minimal Example
```dart
import 'widgets/emergency_stop_button.dart';

// In a Stack or Overlay:
EmergencyStopButton(
  onStop: () {
    print('AI has been stopped');
    // Handle stop
  },
  isStopped: false,
)
```

### With State Management
```dart
class DashboardState extends State<DashboardScreen> {
  bool _aiStopped = false;

  void _handleStopAI() {
    setState(() {
      _aiStopped = true;
    });
    // Call backend to stop AI
    apiService.stopAI();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your dashboard content
        DashboardContent(),
        
        // Emergency stop button
        EmergencyStopButton(
          onStop: _handleStopAI,
          isStopped: _aiStopped,
        ),
      ],
    );
  }
}
```

### Conditional Display
```dart
Stack(
  children: [
    DashboardContent(),
    
    // Only show stop button if:
    // 1. User is logged in
    // 2. AI is enabled
    // 3. AI has not been stopped
    if (isLoggedIn && _aiEnabled && !_aiStopped)
      EmergencyStopButton(
        onStop: _handleStopAI,
        isStopped: _aiStopped,
      ),
  ],
)
```

---

## 🔗 Full Dashboard Integration

### Complete Enhanced Dashboard Example
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/auth_header.dart';
import 'widgets/trust_bar.dart';
import 'widgets/ai_status_banner.dart';
import 'widgets/emergency_stop_button.dart';

class MyDashboard extends StatefulWidget {
  @override
  State<MyDashboard> createState() => _MyDashboardState();
}

class _MyDashboardState extends State<MyDashboard> {
  bool _aiStopped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Auth Header
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  return AuthHeader(
                    isLoggedIn: userProvider.isAuthenticated,
                    userName: userProvider.user?.name,
                    riskLevel: 'Moderate',
                    onSignIn: () => Navigator.pushNamed(context, '/login'),
                    onCreateAccount: () => Navigator.pushNamed(context, '/signup'),
                    onLogout: () => userProvider.logout(),
                  );
                },
              ),

              // 2. AI Status Banner (if logged in)
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  if (!userProvider.isAuthenticated) {
                    return const SizedBox.shrink();
                  }
                  return AIStatusBanner(
                    aiEnabled: true,
                    aiMode: 'Full Auto',
                    dataSourcesMonitored: 12,
                    confidenceScore: 82.0,
                    onAITapped: () {
                      // Show AI settings
                    },
                  );
                },
              ),

              // 3. Main Content
              Expanded(
                child: DashboardContent(), // Your main widget
              ),

              // 4. Trust Bar (if logged in)
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  if (!userProvider.isAuthenticated) {
                    return const SizedBox.shrink();
                  }
                  return TrustBar(
                    readOnlyMode: false,
                    withdrawalEnabled: false,
                    tradesWithinLimits: true,
                    riskLevel: 'Moderate',
                  );
                },
              ),
            ],
          ),

          // 5. Emergency Stop Button (floating)
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              if (!userProvider.isAuthenticated) {
                return const SizedBox.shrink();
              }
              return EmergencyStopButton(
                onStop: () {
                  setState(() => _aiStopped = true);
                  // Call backend
                },
                isStopped: _aiStopped,
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

## 🎨 Styling Customization

### Change Primary Colors
```dart
// In app_colors.dart
class AppColors {
  static const Color primaryBlue = Color(0xFF3B82F6);    // Change this
  static const Color statusRunning = Color(0xFF10B981);   // Change this
  static const Color priorityHigh = Color(0xFFEF4444);    // Change this
}
```

### Adjust Component Sizes
```dart
// In auth_header.dart
Container(
  width: 32,    // ← Change avatar size
  height: 32,
  ...
)

// In emergency_stop_button.dart
Container(
  width: 64,    // ← Change stop button size
  height: 64,
  ...
)
```

### Modify Animations
```dart
// In ai_status_banner.dart
_pulseController = AnimationController(
  duration: const Duration(seconds: 2),  // ← Change pulse speed
  vsync: this,
)..repeat();

// In emergency_stop_button.dart
Container(
  width: 64 + (12 * _pulseController.value),  // ← Adjust glow size
  height: 64 + (12 * _pulseController.value),
  ...
)
```

---

## 🧪 Testing Components in Isolation

### Test AuthHeader Alone
```dart
// In a separate test widget
class AuthHeaderTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AuthHeader(
          isLoggedIn: true,  // Toggle to test both states
          userName: 'John Trader',
          riskLevel: 'Moderate',
          onSignIn: () => print('Sign In'),
          onCreateAccount: () => print('Create'),
          onLogout: () => print('Logout'),
        ),
      ),
    );
  }
}
```

### Test StopButton Alone
```dart
class StopButtonTest extends StatefulWidget {
  @override
  State<StopButtonTest> createState() => _StopButtonTestState();
}

class _StopButtonTestState extends State<StopButtonTest> {
  bool _stopped = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: Center(
          child: Stack(
            children: [
              const Center(
                child: Text(
                  'Tap the stop button →',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              EmergencyStopButton(
                onStop: () => setState(() => _stopped = true),
                isStopped: _stopped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 📱 Responsive Examples

### Mobile Optimized
```dart
// For mobile (< 768px)
Column(
  children: [
    AuthHeader(...),
    if (isLoggedIn) AIStatusBanner(...),
    Expanded(child: DashboardContent()),
    if (isLoggedIn) TrustBar(...),
  ],
)
// Emergency button positioned for mobile
```

### Tablet Optimized
```dart
// For tablet (768px - 1200px)
Column(
  children: [
    AuthHeader(...),
    if (isLoggedIn) AIStatusBanner(...),
    Expanded(
      child: Row(
        children: [
          CollapsedSidebar(),
          Expanded(child: DashboardContent()),
        ],
      ),
    ),
    if (isLoggedIn) TrustBar(...),
  ],
)
```

### Desktop Optimized
```dart
// For desktop (> 1200px)
Column(
  children: [
    AuthHeader(...),
    if (isLoggedIn) AIStatusBanner(...),
    Expanded(
      child: Row(
        children: [
          FullSidebar(),
          Expanded(flex: 3, child: DashboardContent()),
          Expanded(flex: 1, child: LivePanel()),
        ],
      ),
    ),
    if (isLoggedIn) TrustBar(...),
  ],
)
```

---

## 🚀 Production Checklist

Before deploying to production:

- [ ] All 4 components render without errors
- [ ] AuthHeader shows correct user data
- [ ] Stop button responds instantly
- [ ] Animations are smooth (60 FPS)
- [ ] No console warnings
- [ ] Tested on 3+ devices
- [ ] Backend endpoints validated
- [ ] Responsive design tested
- [ ] User feedback collected
- [ ] Performance profiled

---

**These examples cover 95% of use cases. Adapt as needed for your specific requirements!** 🎉
