import '../l10n/app_localizations.dart';

const String repeatRuleDaily = 'daily';
const String repeatRuleWeekly = 'weekly';
const String repeatRuleMonthly = 'monthly';
const String repeatRuleYearly = 'yearly';
const String repeatRuleCustom = 'custom';

bool hasRepeatRule(String? rule) => rule != null && rule.isNotEmpty;

String repeatRuleLabel(AppLocalizations l, String? rule) {
  switch (rule) {
    case repeatRuleDaily:
      return l.repeatDaily;
    case repeatRuleWeekly:
      return l.repeatWeekly;
    case repeatRuleMonthly:
      return l.repeatMonthly;
    case repeatRuleYearly:
      return l.repeatYearly;
    case repeatRuleCustom:
      return l.repeatCustom;
    default:
      return l.repeatNone;
  }
}
