const String kReviewDemoAccountEmail = 'support.masdigitalteam@gmail.com';
const String kReviewDemoAccountEmailAlias = 'support.masdigitalteam.com';
const String kReviewModeSuccessMessage =
    'Action completed in review mode. This is a demo account, so the production database was not changed.';

bool isReviewDemoEmail(String? email) {
  final normalized = email?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  return normalized == kReviewDemoAccountEmail ||
      normalized == kReviewDemoAccountEmailAlias;
}
