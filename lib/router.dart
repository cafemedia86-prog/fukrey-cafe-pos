import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/customer_login_screen.dart';
import 'features/auth/customer_register_screen.dart';
import 'features/home_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/customer/customer_home.dart';
import 'features/customer/customer_menu.dart';
import 'features/customer/customer_checkout.dart';
import 'features/customer/customer_order_status.dart';
import 'repositories/auth_repository.dart';
import 'core/navigator_key.dart';

import 'package:flutter/services.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  
  // Read native flavor or fallback to web dart-define environment variable
  const String webFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'customer');
  final String activeFlavor = appFlavor ?? webFlavor;
  
  // Decide initial route based on the flavor
  final String initialRoute = (activeFlavor == 'admin') ? '/login' : '/customer';
  
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialRoute,
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
    redirect: (context, state) async {
      final isLoggedIn = authRepo.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        // Allow guest access to customer routes
        if (state.matchedLocation.startsWith('/customer')) {
          return null;
        }
        return isLoggingIn ? null : '/login';
      }

      // User IS logged in.
      // If they are on Login page, send them to home (which will decide where else to go)
      if (isLoggingIn) {
         return '/';
      }

      // We can do Role checks here by reading the repo directly if we want synchronous-like feel
      // or we accept that "/" might be a "Loader/Dispatcher" page.
      
      return null;
    },
    routes: [

      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      // Customer Routes
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerHomeScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const CustomerLoginScreen(),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => const CustomerRegisterScreen(),
          ),
          GoRoute(
            path: 'menu/:outletId',
            builder: (context, state) => CustomerMenuScreen(
              outletId: state.pathParameters['outletId']!,
              initialCategoryId: state.uri.queryParameters['categoryId'],
              searchQuery: state.uri.queryParameters['search'],
            ),
          ),
          GoRoute(
            path: 'checkout',
            builder: (context, state) => const CustomerCheckoutScreen(),
          ),
          GoRoute(
            path: 'order-status/:orderId',
            builder: (context, state) => CustomerOrderStatusScreen(
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

