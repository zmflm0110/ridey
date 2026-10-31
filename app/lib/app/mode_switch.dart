import 'package:flutter/material.dart';
import 'package:ridey_app/app/user_mode.dart';

Future<bool> confirmModeSwitch(
  BuildContext context, {
  required UserMode next,
}) async {
  final toStaff = next == UserMode.staff;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(toStaff ? '직원 모드로 바꿀까요?' : '시민 모드로 바꿀까요?'),
        content: const Text('담당 구 설정은 이 기기에 그대로 둡니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('바꾸기'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
