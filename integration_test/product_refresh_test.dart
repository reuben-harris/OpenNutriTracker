import 'package:integration_test/integration_test.dart';

import '../test/features/meal_detail/product_refresh_test.dart' as refresh;

// Exercise the same controlled HTTP responses and real Hive cache on-device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  refresh.main();
}
