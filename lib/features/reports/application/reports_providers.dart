import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_providers.dart';
import '../data/reports_api.dart';

final reportsApiProvider = Provider<ReportsApi>((ref) => ReportsApi(ref.watch(authenticatedDioProvider)));
