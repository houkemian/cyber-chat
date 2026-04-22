/// 与 `RoomChat.tsx` `toClock` 对齐，统一显示 UTC+8 时间。
String formatChatClock(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '--:--';
  // 将 UTC 时间转换为 UTC+8（无论设备本地时区如何，均强制显示北京时间）
  final date = parsed.toUtc().add(const Duration(hours: 8));
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  final hhmm = '$hh:$mm';
  if (isToday) return hhmm;
  final m2 = date.month.toString().padLeft(2, '0');
  final d2 = date.day.toString().padLeft(2, '0');
  return '$m2-$d2 $hhmm';
}
