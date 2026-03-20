import '../models/mastery_event_draft.dart';
import 'capture_service.dart';
import 'on_device_ai_service.dart';

/// Wraps [CaptureService] with [OnDeviceAiService] to provide AI-assisted
/// observation capture. Generates a draft observation note from templates,
/// marks it as AI-assisted, and returns the draft for teacher review.
class SmartCaptureService {
  SmartCaptureService({
    required this.captureService,
    required this.onDeviceAiService,
  });

  final CaptureService captureService;
  final OnDeviceAiService onDeviceAiService;

  /// Capture an observation with AI-assisted note suggestion.
  ///
  /// 1. Gets AI suggestion for the observation note
  /// 2. Creates the draft via [CaptureService]
  /// 3. Marks `ai_assisted = true` on the draft metadata
  /// 4. Returns the draft with the AI suggestion pre-filled
  ///
  /// The teacher must review and edit the note before syncing.
  Future<SmartCaptureDraft> captureWithAiAssist({
    required String studentId,
    required String competencyId,
    required String descriptorLevel,
    required double numericValue,
    String? competencyName,
    String? studentName,
  }) async {
    if (!onDeviceAiService.isModelLoaded) {
      await onDeviceAiService.initializeModels();
    }

    final suggestion = await onDeviceAiService.suggestObservationNote(
      competencyName: competencyName ?? 'General',
      descriptorLevel: descriptorLevel,
      studentContext: studentName,
    );

    final draft = await captureService.captureObservation(
      studentId: studentId,
      competencyId: competencyId,
      numericValue: numericValue,
      observationNote: suggestion.suggestedNote,
      sourceType: 'DIRECT_OBSERVATION',
    );

    return SmartCaptureDraft(
      draft: draft,
      suggestion: suggestion,
      aiAssisted: true,
    );
  }
}

/// A draft observation that includes AI suggestion metadata.
class SmartCaptureDraft {
  const SmartCaptureDraft({
    required this.draft,
    required this.suggestion,
    required this.aiAssisted,
  });

  final MasteryEventDraft draft;
  final ObservationSuggestion suggestion;
  final bool aiAssisted;
}
