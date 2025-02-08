import 'package:get_it/get_it.dart';
import '../services/aws/aws_service.dart';
import '../services/aws/aws_cli_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // AWS Service
  getIt.registerLazySingleton<AwsService>(
    () => AwsCliService(
      profile: 'default', // You can load this from environment variables
      region: 'us-east-1', // You can load this from environment variables
    ),
  );
}
