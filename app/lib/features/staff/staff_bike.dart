import 'package:flutter/material.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/staff/staff_session.dart';

/// 직원 모드에서 자전거 상세를 연다(직원용 안내 문구).
Future<void> openStaffBike(
  BuildContext context,
  StaffSession session,
  LiveBike bike,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => BikeDetailPage(
      bike: bike,
      updatedAt: session.updatedAt ?? DateTime.now(),
      feed: session.feed,
      forStaff: true,
    ),
  ),
);
