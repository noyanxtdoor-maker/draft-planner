import 'package:flutter/widgets.dart';

/// Observes routes in the authenticated shell navigator.
///
/// This is intentionally UI-only. It is used for transient screen state such
/// as Weekly Planning management mode and is never persisted or synchronized.
final shellRouteObserver = RouteObserver<ModalRoute<void>>();
