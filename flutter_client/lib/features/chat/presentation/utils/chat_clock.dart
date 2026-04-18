/// 与 `RoomChat.tsx` `toClock` 对齐。
String formatChatClock(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '--:--';
  final now = DateTime.now();
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
