import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Times travel in UTC and are shown in IST (UTC+5:30), whatever zone the
/// phone is set to.
DateTime toIst(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: 5, minutes: 30));

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// `2 Nov 2026` for an IST calendar date (a UTC-midnight date value).
String istDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(_locale(context)).format(date);

/// `2 Nov 2026, 11:40 AM` for a UTC instant.
String istDateTime(BuildContext context, DateTime utc) =>
    DateFormat.yMMMd(_locale(context)).add_jm().format(toIst(utc));

/// `11:40 AM` for a UTC instant.
String istTime(BuildContext context, DateTime utc) =>
    DateFormat.jm(_locale(context)).format(toIst(utc));
