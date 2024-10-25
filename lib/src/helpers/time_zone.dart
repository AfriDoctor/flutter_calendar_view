import 'package:flutter/material.dart';
import 'package:timezone/standalone.dart' as tz;
import 'package:timezone/timezone.dart';

class TimeZoneHelper {
  static DateTime? getTzDateFromDateTime(
      DateTime? dateTime, String locationName) {
    if (dateTime == null) {
      return null;
    }
    final Location location = tz.getLocation(locationName);
    return TZDateTime.from(dateTime, location);
  }

  static int getTimeZoneOffset(String location) {
    final now = DateTime.now();
    return now.timeZoneOffset.inHours -
        getTzDateFromDateTime(now, location)!.timeZoneOffset.inHours;
  }

  static TimeOfDay addHour(TimeOfDay time, int hour) {
    return TimeOfDay(hour: time.hour + hour, minute: time.minute);
  }
}
