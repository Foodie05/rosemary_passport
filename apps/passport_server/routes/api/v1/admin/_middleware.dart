import 'package:dart_frog/dart_frog.dart';

import '../../../../lib/src/middleware/guards.dart';

Handler middleware(Handler handler) => handler.use(requireAdmin());
