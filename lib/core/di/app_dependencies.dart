import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/content/content_loader.dart';
import '../../data/datasources/local/chat_dao.dart';
import '../../data/datasources/local/exercise_dao.dart';
import '../../data/datasources/local/nutrition_dao.dart';
import '../../data/datasources/local/plan_dao.dart';
import '../../data/datasources/local/progress_dao.dart';
import '../../data/datasources/local/session_dao.dart';
import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/datasources/remote/email_service.dart';
import '../../data/repositories/content_repository_impl.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../data/repositories/plan_repository_impl.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../data/repositories/veda_repository_impl.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../domain/repositories/plan_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/veda_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/usecases/ask_veda.dart';
import '../../domain/usecases/end_session.dart';
import '../../domain/usecases/estimate_meal_calories.dart';
import '../../domain/usecases/forgot_password.dart';
import '../../domain/usecases/generate_progress_report.dart';
import '../../domain/usecases/generate_weekly_plan.dart';
import '../../domain/usecases/get_home_dashboard.dart';
import '../../domain/usecases/get_strike_state.dart';
import '../../domain/usecases/resend_otp.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/start_session.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../engines/strike_engine/strike_engine.dart';
import '../audio/sound_engine.dart';
import '../groq/groq_plan_service.dart';
import '../notification/notification_engine.dart';
import '../pose/exercise_definition.dart';
import '../pose/pose_analyzer.dart';
import '../storage/app_database.dart';
import '../storage/sync_engine.dart';

/// P1 auth/OTP dependency graph (Riverpod):
/// data sources → repository → use cases. Screens read only the use-case
/// providers; nothing else constructs the graph manually.
final emailServiceProvider = Provider<EmailService>(
  (ref) => EmailService(),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(emailServiceProvider),
  ),
);

final signUpProvider = Provider(
  (ref) => SignUp(ref.watch(userRepositoryProvider)),
);

final verifyOtpProvider = Provider(
  (ref) => VerifyOtp(ref.watch(userRepositoryProvider)),
);

final signInProvider = Provider(
  (ref) => SignIn(ref.watch(userRepositoryProvider)),
);

final forgotPasswordProvider = Provider(
  (ref) => ForgotPassword(ref.watch(userRepositoryProvider)),
);

final resendOtpProvider = Provider(
  (ref) => ResendOtp(ref.watch(userRepositoryProvider)),
);

final resetPasswordProvider = Provider(
  (ref) => ResetPassword(ref.watch(userRepositoryProvider)),
);

final signOutProvider = Provider(
  (ref) => SignOut(ref.watch(userRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Local database + DAOs (offline-first primary store)
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // driftDatabase hands back a DatabaseConnection; the generated database
  // constructor wants its QueryExecutor.
  final db = AppDatabase(driftDatabase(name: 'fixpose').executor);
  ref.onDispose(db.close);
  return db;
});

final contentLoaderProvider = Provider<ContentLoader>(
  (ref) => ContentLoader(),
);

final sessionDaoProvider = Provider<SessionDao>(
  (ref) => ref.watch(appDatabaseProvider).sessionDao,
);
final planDaoProvider = Provider<PlanDao>(
  (ref) => ref.watch(appDatabaseProvider).planDao,
);
final nutritionDaoProvider = Provider<NutritionDao>(
  (ref) => ref.watch(appDatabaseProvider).nutritionDao,
);
final progressDaoProvider = Provider<ProgressDao>(
  (ref) => ref.watch(appDatabaseProvider).progressDao,
);
final chatDaoProvider = Provider<ChatDao>(
  (ref) => ref.watch(appDatabaseProvider).chatDao,
);
final exerciseDaoProvider = Provider<ExerciseDao>(
  (ref) => ref.watch(appDatabaseProvider).exerciseDao,
);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepositoryImpl(ref.watch(contentLoaderProvider)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepositoryImpl(
    ref.watch(contentLoaderProvider),
    ref.watch(exerciseDaoProvider),
  ),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepositoryImpl(
    ref.watch(contentLoaderProvider),
    ref.watch(sessionDaoProvider),
  ),
);

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => PlanRepositoryImpl(ref.watch(planDaoProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(ref.watch(sessionDaoProvider)),
);

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepositoryImpl(
    ref.watch(contentLoaderProvider),
    ref.watch(nutritionDaoProvider),
  ),
);

final vedaRepositoryProvider = Provider<VedaRepository>(
  (ref) => VedaRepositoryImpl(ref.watch(chatDaoProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepositoryImpl(ref.watch(progressDaoProvider)),
);

// ---------------------------------------------------------------------------
// Engines + account sync
// ---------------------------------------------------------------------------

final strikeEngineProvider = Provider<StrikeEngine>(
  (ref) => const StrikeEngine(),
);

/// Spoken cues + synthesized SFX (TTS pre-warmed at boot for <0.5 s cues).
final soundEngineProvider = Provider<SoundEngine>((ref) {
  final engine = SoundEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Scheduled workout reminders (device-local, timezone-aware).
final notificationEngineProvider = Provider<NotificationEngine>((ref) {
  return NotificationEngine.instance;
});

/// Live vision pipeline per exercise — isolated analyzer + FSM each.
/// Reads the bundled catalog registered at boot; unknown ids throw.
/// Resolves content-pack ids (`pushup`, `jumpingJack`, `glute-bridge`) to the
/// FSM ids (`push_up`, `jumping_jack`, `glute_bridge`) via [ExerciseRegistry.resolve].
final poseAnalyzerProvider =
    Provider.family<PoseAnalyzer, String>((ref, exerciseId) {
  final def = ExerciseRegistry.instance.resolve(exerciseId);
  if (def == null) throw ArgumentError('Unknown exercise: $exerciseId');
  final analyzer = PoseAnalyzer(def);
  ref.onDispose(analyzer.dispose);
  return analyzer;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    ref.watch(appDatabaseProvider),
    Supabase.instance.client,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

// ---------------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------------

final getStrikeStateProvider = Provider(
  (ref) => GetStrikeState(
    ref.watch(progressRepositoryProvider),
    ref.watch(strikeEngineProvider),
  ),
);

final startSessionProvider = Provider(
  (ref) => StartSession(
    ref.watch(sessionRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
  ),
);

final endSessionProvider = Provider(
  (ref) => EndSession(
    ref.watch(sessionRepositoryProvider),
    ref.watch(progressRepositoryProvider),
    ref.watch(planRepositoryProvider),
    ref.watch(strikeEngineProvider),
  ),
);

final generateWeeklyPlanProvider = Provider(
  (ref) => GenerateWeeklyPlan(
    ref.watch(contentRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
    ref.watch(planRepositoryProvider),
    ref.watch(groqPlanServiceProvider),
  ),
);

final homeDashboardProvider = Provider(
  (ref) => GetHomeDashboard(
    ref.watch(getStrikeStateProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(planRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
    ref.watch(contentRepositoryProvider),
    ref.watch(strikeEngineProvider),
  ),
);

/// Meal page — free-text description → GROQ calorie estimate
/// (null on failure → manual entry fallback in the meal page).
final estimateMealCaloriesProvider = Provider(
  (ref) => EstimateMealCalories(ref.watch(vedaRepositoryProvider)),
);

final askVedaProvider = Provider(
  (ref) => AskVeda(
    ref.watch(vedaRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(planRepositoryProvider),
    ref.watch(progressRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
    ref.watch(nutritionRepositoryProvider),
  ),
);

/// Home → Progress report: personal details + training history + AI
/// suggestions (GROQ-first, rule-based fallback).
final generateProgressReportProvider = Provider(
  (ref) => GenerateProgressReport(
    ref.watch(userRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(progressRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
    ref.watch(vedaRepositoryProvider),
    ref.watch(nutritionRepositoryProvider),
  ),
);
