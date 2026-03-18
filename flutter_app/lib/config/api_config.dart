/// API configuration matching the Node.js server's /api/v1/ routes.
class ApiConfig {
  ApiConfig({
    this.baseUrl = 'http://localhost:3000',
    this.apiVersion = 'v1',
  });

  final String baseUrl;
  final String apiVersion;

  String get apiBase => '$baseUrl/api/$apiVersion';

  // Auth
  String get login => '$apiBase/auth/login';

  // Capture (offline sync)
  String get captureSync => '$apiBase/capture/sync';

  // Evidence
  String get evidence => '$apiBase/evidence';
  String evidenceById(String id) => '$apiBase/evidence/$id';

  // Reference data
  String get uiSchema => '$apiBase/ui-schema';
  String get academicYears => '$apiBase/academic-years';
  String academicYearClose(String id) => '$apiBase/academic-years/$id/close';
  String get competencies => '$apiBase/competencies';
  String get localizationStrings => '$apiBase/localization/strings';

  // Students
  String get students => '$apiBase/students';
  String studentEnrolments(String id) => '$apiBase/students/$id/enrolments';
  String studentAssessmentContext(String id) =>
      '$apiBase/students/$id/assessment-context';
  String studentMasterySummary(String id) =>
      '$apiBase/students/$id/mastery-summary';
  String studentOverlays(String id) => '$apiBase/students/$id/overlays';
  String studentOverlaysActive(String id) =>
      '$apiBase/students/$id/overlays/active';

  // Mastery
  String masteryEventVerify(String id) => '$apiBase/mastery-events/$id/verify';

  // Rubric
  String get rubricCompletions => '$apiBase/rubric-completions';

  // Feedback
  String get feedbackRequestsBatch => '$apiBase/feedback-requests/batch';
  String feedbackRequestResponse(String id) =>
      '$apiBase/feedback-requests/$id/response';

  // Moderation & interventions
  String get moderationQueue => '$apiBase/moderation-queue';
  String get interventionAlerts => '$apiBase/intervention-alerts';
  String interventionAlertConvert(String id) =>
      '$apiBase/intervention-alerts/$id/convert';

  // Overlays
  String overlayApprove(String id) => '$apiBase/overlays/$id/approve';

  // Consent
  String get consentInitiate => '$apiBase/consent/initiate';
  String get consentVerify => '$apiBase/consent/verify';
}
