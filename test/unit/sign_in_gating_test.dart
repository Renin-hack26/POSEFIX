/// P1 auth E2E — sign-in distinguishes "no account" from "wrong password".
/// Supabase answers "Invalid login credentials" for both, so the
/// repository gates on the `check-user` existence check first (same
/// mechanism as the forgot flow). Faked remote + mailer; no network.
library;

import 'package:fixpose/core/errors/app_exception.dart';
import 'package:fixpose/data/datasources/remote/auth_remote_data_source.dart';
import 'package:fixpose/data/datasources/remote/email_service.dart';
import 'package:fixpose/data/repositories/user_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockEmail extends Mock implements EmailService {}

void main() {
  late _MockRemote remote;
  late UserRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = UserRepositoryImpl(remote, _MockEmail());
  });

  test('unknown email fails fast with UserNotFoundException', () async {
    when(() => remote.userExists(email: any(named: 'email')))
        .thenAnswer((_) async => false);
    await expectLater(
      repo.signIn(email: 'ghost@example.com', password: 'Abcd1234'),
      throwsA(isA<UserNotFoundException>()),
    );
    verifyNever(() => remote.signIn(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  test('known email attempts password auth (wrong → WrongPassword)', () async {
    when(() => remote.userExists(email: any(named: 'email')))
        .thenAnswer((_) async => true);
    when(() => remote.signIn(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const WrongPasswordException());
    await expectLater(
      repo.signIn(email: 'you@example.com', password: 'wrongpass1'),
      throwsA(isA<WrongPasswordException>()),
    );
    verify(() => remote.signIn(
        email: 'you@example.com', password: 'wrongpass1')).called(1);
  });

  test('known email + right password signs in', () async {
    when(() => remote.userExists(email: any(named: 'email')))
        .thenAnswer((_) async => true);
    when(() => remote.signIn(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async {});
    await repo.signIn(email: 'you@example.com', password: 'Abcd1234');
    verify(() => remote.signIn(
        email: 'you@example.com', password: 'Abcd1234')).called(1);
  });
}
