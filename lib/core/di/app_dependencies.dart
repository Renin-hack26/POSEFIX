import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/auth_remote_data_source.dart';
import '../../data/datasources/remote/email_service.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/forgot_password.dart';
import '../../domain/usecases/resend_otp.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/verify_otp.dart';

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
