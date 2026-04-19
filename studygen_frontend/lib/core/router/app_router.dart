import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/generate/screens/generate_screen.dart';
import '../../features/quiz/screens/summary_screen.dart';
import '../../features/quiz/screens/quiz_screen.dart';
import '../../features/quiz/screens/result_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/generate/models/quiz_model.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final provider = user?.appMetadata['provider']?.toString();
    final emailVerified = user?.emailConfirmedAt != null;
    final socialLogin = provider == 'google';
    final loggedIn = user != null && (emailVerified || socialLogin);
    final onSplash = state.matchedLocation == '/splash';
    final onAuth  = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (onSplash) return null;

    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/generate',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: GenerateScreen(),
      ),
    ),
    GoRoute(
      path: '/summary',
      builder: (context, state) {
        final quiz = state.extra as QuizModel;
        return SummaryScreen(quiz: quiz);
      },
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) {
        final quiz = state.extra as QuizModel;
        return QuizScreen(quiz: quiz);
      },
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final args    = state.extra as Map<String, dynamic>;
        final quiz    = args['quiz'] as QuizModel;
        final score   = args['score'] as int;
        final correct = args['correct'] as int;
        return ResultScreen(quiz: quiz, score: score, correct: correct);
      },
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: HistoryScreen(),
      ),
    ),
  ],
);