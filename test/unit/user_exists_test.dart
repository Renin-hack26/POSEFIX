/// Auth existence gate — `userExists` must read the `FunctionResponse.data`
/// payload, not the response object itself.
///
/// Regression: `functions.invoke` resolves to `FunctionResponse`, so a
/// bare `is Map` check on it is always false — every sign-in (and every
/// forgot-password request) reported "User doesn't exist", including for
/// registered accounts. Faked client; no network.
library;

import 'package:fixpose/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late _MockSupabase client;
  late _MockFunctions functions;
  late AuthRemoteDataSource remote;

  setUp(() {
    client = _MockSupabase();
    functions = _MockFunctions();
    when(() => client.functions).thenReturn(functions);
    remote = AuthRemoteDataSource(client: client);
  });

  Map<String, String> checkBody(String email) =>
      {'action': 'check-user', 'email': email};

  test('registered account reports exists:true', () async {
    when(() => functions.invoke('send-otp', body: checkBody('a@b.c')))
        .thenAnswer((_) async => const FunctionResponse(
              data: {'ok': true, 'exists': true},
              status: 200,
            ));
    expect(await remote.userExists(email: 'a@b.c'), isTrue);
  });

  test('unknown account reports exists:false', () async {
    when(() => functions.invoke('send-otp', body: checkBody('ghost@x.io')))
        .thenAnswer((_) async => const FunctionResponse(
              data: {'ok': true, 'exists': false},
              status: 200,
            ));
    expect(await remote.userExists(email: 'ghost@x.io'), isFalse);
  });

  test('malformed payload never claims an account exists', () async {
    when(() => functions.invoke('send-otp', body: checkBody('odd@x.io')))
        .thenAnswer((_) async => const FunctionResponse(
              data: {'ok': true},
              status: 200,
            ));
    expect(await remote.userExists(email: 'odd@x.io'), isFalse);
  });
}
