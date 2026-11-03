import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Times travel in UTC and are shown in IST (UTC+5:30), whatever zone the
/// phone is set to. Formats follow the app locale, as registration does
/// (`Nov 2, 2026` in English).
DateTime toIst(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: 5, minutes: 30));

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// `Nov 2, 2026` for a calendar date that is already on the Indian
/// calendar: a UTC-midnight date value such as `istToday()` returns or an
/// API `YYYY-MM-DD` date. For an instant (`paid_at`), use [istDayOf].
String istDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(_locale(context)).format(date);

/// `Nov 2, 2026`: the Indian date of a UTC instant (19:00 UTC is already
/// the next day in India).
String istDayOf(BuildContext context, DateTime utc) =>
    DateFormat.yMMMd(_locale(context)).format(toIst(utc));

/// `Nov 2, 2026 11:40 AM` for a UTC instant.
String istDateTime(BuildContext context, DateTime utc) =>
    DateFormat.yMMMd(_locale(context)).add_jm().format(toIst(utc));

/// `11:40 AM` for a UTC instant.
String istTime(BuildContext context, DateTime utc) =>
    DateFormat.jm(_locale(context)).format(toIst(utc));
