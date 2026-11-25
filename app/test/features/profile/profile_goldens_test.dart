// Golden for the Account artboard (Profile & settings). Regenerate after an
// intended change:
//   flutter test --update-goldens test/features/profile/profile_goldens_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wardline/app/app.dart';
import 'package:wardline/app/router.dart';

import '../history/history_harness.dart';

void main() {
  testWidgets('profile, nurse', (tester) async {
    phone(tester);
    await pumpApp(tester, repo: clockedRepository(), location: Routes.profile);
    await expectLater(
      find.byType(WardlineApp),
      matchesGoldenFile('goldens/profile.png'),
    );
  });
}
