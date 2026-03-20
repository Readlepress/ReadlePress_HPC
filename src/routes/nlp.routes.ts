import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  analyzeFeedbackSentiment,
  summarizeParentResponses,
  transcribeVoiceNote,
} from '../services/nlp.service';

export default async function nlpRoutes(app: FastifyInstance) {
  app.post('/nlp/analyze-sentiment', { preHandler: [authenticate] }, async (request) => {
    const { text, languageCode } = request.body as { text: string; languageCode: string };
    if (!text) throw new Error('MISSING_TEXT');
    const result = analyzeFeedbackSentiment(text, languageCode || 'en');
    return result;
  });

  app.post('/nlp/summarize-feedback', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { feedbackRequestIds, targetLanguage } = request.body as {
      feedbackRequestIds: string[];
      targetLanguage: string;
    };
    if (!feedbackRequestIds || !Array.isArray(feedbackRequestIds)) {
      throw new Error('MISSING_FEEDBACK_REQUEST_IDS');
    }
    return summarizeParentResponses(
      user.tenantId, user.userId, user.role,
      feedbackRequestIds, targetLanguage || 'en'
    );
  });

  app.post('/nlp/transcribe', { preHandler: [authenticate] }, async (request) => {
    const { languageCode } = request.body as { languageCode?: string };
    const result = transcribeVoiceNote(Buffer.alloc(0), languageCode || 'en');
    return result;
  });
}
