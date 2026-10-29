import 'package:flutter/material.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';

/// Opens a suspect bike on the check tab without covering the shell.
class RideyActions extends InheritedWidget {
  const RideyActions({super.key, required this.openBike, required super.child});

  final void Function(LiveBike bike, LiveSnapshot snapshot) openBike;

  static RideyActions? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RideyActions>();
  }

  @override
  bool updateShouldNotify(RideyActions oldWidget) =>
      openBike != oldWidget.openBike;
}
