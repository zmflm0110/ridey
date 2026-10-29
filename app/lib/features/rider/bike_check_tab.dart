import 'package:flutter/material.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';

class RideyCheckRequest {
  RideyCheckRequest({
    required this.token,
    required this.bike,
    required this.updatedAt,
    required this.feed,
  });

  final Object token;
  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth feed;
}

/// Bike-check tab. The scanner stays under the shell, and a result or the
/// evidence page is pushed on a navigator that does not cover the tab bar.
class BikeCheckTab extends StatefulWidget {
  const BikeCheckTab({
    super.key,
    required this.repository,
    required this.readLocation,
    required this.cameraEnabled,
    required this.visible,
    this.request,
    this.onRequestHandled,
  });

  final LiveSnapshotRepository? repository;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool cameraEnabled;
  final bool visible;
  final RideyCheckRequest? request;
  final VoidCallback? onRequestHandled;

  @override
  State<BikeCheckTab> createState() => _BikeCheckTabState();
}

class _BikeCheckTabState extends State<BikeCheckTab> {
  final _navKey = GlobalKey<NavigatorState>();
  final _routes = RouteObserver<PageRoute<dynamic>>();
  late final LiveSnapshotRepository _repository =
      widget.repository ?? SupabaseLiveSnapshotRepository();
  late Future<LiveSnapshot> _snapshot = _repository.fetch();
  Object? _openedToken;

  @override
  void initState() {
    super.initState();
    _schedule(widget.request);
  }

  @override
  void didUpdateWidget(BikeCheckTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.request;
    if (request != null && request.token != _openedToken) _schedule(request);
  }

  void _retry() => setState(() => _snapshot = _repository.fetch());

  void _schedule(RideyCheckRequest? request) {
    if (request == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.request?.token != request.token) return;
      _open(request);
    });
  }

  void _open(RideyCheckRequest request) {
    final nav = _navKey.currentState;
    if (nav == null) {
      _schedule(request);
      return;
    }
    if (_openedToken == request.token) return;
    _openedToken = request.token;
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => BikeDetailPage(
          bike: request.bike,
          updatedAt: request.updatedAt,
          feed: request.feed,
          onCheckAnother: () => nav.popUntil((route) => route.isFirst),
        ),
      ),
    );
    widget.onRequestHandled?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        return _CheckScope(
          snapshot: snapshot,
          onRetry: _retry,
          repository: _repository,
          routes: _routes,
          readLocation: widget.readLocation,
          cameraEnabled: widget.cameraEnabled,
          visible: widget.visible,
          child: Navigator(
            key: _navKey,
            observers: [_routes],
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const _CheckEntry(),
              );
            },
          ),
        );
      },
    );
  }
}

class _CheckScope extends InheritedWidget {
  const _CheckScope({
    required this.snapshot,
    required this.onRetry,
    required this.repository,
    required this.routes,
    required this.readLocation,
    required this.cameraEnabled,
    required this.visible,
    required super.child,
  });

  final AsyncSnapshot<LiveSnapshot> snapshot;
  final VoidCallback onRetry;
  final LiveSnapshotRepository repository;
  final RouteObserver<PageRoute<dynamic>> routes;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool cameraEnabled;
  final bool visible;

  static _CheckScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CheckScope>();
    assert(scope != null, '_CheckEntry must sit under _CheckScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(_CheckScope oldWidget) {
    return snapshot.connectionState != oldWidget.snapshot.connectionState ||
        snapshot.hasData != oldWidget.snapshot.hasData ||
        snapshot.hasError != oldWidget.snapshot.hasError ||
        snapshot.data != oldWidget.snapshot.data ||
        cameraEnabled != oldWidget.cameraEnabled ||
        visible != oldWidget.visible ||
        readLocation != oldWidget.readLocation;
  }
}

class _CheckEntry extends StatelessWidget {
  const _CheckEntry();

  @override
  Widget build(BuildContext context) {
    final scope = _CheckScope.of(context);
    final snapshot = scope.snapshot;
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return BikeLookupLoadFailure(onRetry: scope.onRetry);
    }
    return BikeLookupPage(
      snapshot: snapshot.requireData,
      repository: scope.repository,
      routeObserver: scope.routes,
      readLocation: scope.readLocation,
      cameraEnabled: scope.cameraEnabled,
      visible: scope.visible,
    );
  }
}
