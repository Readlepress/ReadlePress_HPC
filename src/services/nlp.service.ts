import { withTransaction } from '../config/database';

type Sentiment = 'POSITIVE' | 'NEUTRAL' | 'NEGATIVE';

interface SentimentResult {
  sentiment: Sentiment;
  confidence: number;
  themes: Array<{ theme: string; confidence: number }>;
}

interface ThemeSummary {
  theme: string;
  count: number;
  sampleQuotes: string[];
}

interface SummaryResult {
  summary: string;
  themes: ThemeSummary[];
  totalResponses: number;
  sentimentDistribution: Record<Sentiment, number>;
}

interface TranscriptionResult {
  text: string;
  confidence: number;
  language_detected: string;
}

const POSITIVE_KEYWORDS: Record<string, string[]> = {
  en: ['good', 'improved', 'happy', 'excellent', 'better', 'great', 'wonderful', 'progress', 'confident', 'love'],
  hi: ['अच्छा', 'सुधार', 'खुश', 'बेहतर', 'शानदार', 'प्रगति'],
};

const NEGATIVE_KEYWORDS: Record<string, string[]> = {
  en: ['struggling', 'difficult', 'worried', 'poor', 'bad', 'worse', 'failing', 'weak', 'concern', 'problem'],
  hi: ['कठिन', 'चिंता', 'कमज़ोर', 'मुश्किल', 'बुरा', 'कमजोर'],
};

const KEYWORD_THEME_MAP: Record<string, string> = {
  improved: 'ACADEMIC_IMPROVEMENT',
  better: 'ACADEMIC_IMPROVEMENT',
  progress: 'ACADEMIC_IMPROVEMENT',
  excellent: 'ACADEMIC_IMPROVEMENT',
  सुधार: 'ACADEMIC_IMPROVEMENT',
  बेहतर: 'ACADEMIC_IMPROVEMENT',
  प्रगति: 'ACADEMIC_IMPROVEMENT',

  confident: 'SOCIAL_CONFIDENCE',
  happy: 'SOCIAL_CONFIDENCE',
  love: 'SOCIAL_CONFIDENCE',
  खुश: 'SOCIAL_CONFIDENCE',

  worried: 'BEHAVIORAL_CONCERN',
  concern: 'BEHAVIORAL_CONCERN',
  problem: 'BEHAVIORAL_CONCERN',
  bad: 'BEHAVIORAL_CONCERN',
  चिंता: 'BEHAVIORAL_CONCERN',
  बुरा: 'BEHAVIORAL_CONCERN',

  struggling: 'READING_DIFFICULTY',
  difficult: 'READING_DIFFICULTY',
  कठिन: 'READING_DIFFICULTY',
  मुश्किल: 'READING_DIFFICULTY',

  poor: 'MATH_STRUGGLE',
  failing: 'MATH_STRUGGLE',
  weak: 'MATH_STRUGGLE',
  worse: 'MATH_STRUGGLE',
  कमज़ोर: 'MATH_STRUGGLE',
  कमजोर: 'MATH_STRUGGLE',

  good: 'CREATIVE_EXPRESSION',
  great: 'CREATIVE_EXPRESSION',
  wonderful: 'CREATIVE_EXPRESSION',
  अच्छा: 'CREATIVE_EXPRESSION',
  शानदार: 'CREATIVE_EXPRESSION',
};

function getAllKeywords(type: 'positive' | 'negative'): string[] {
  const source = type === 'positive' ? POSITIVE_KEYWORDS : NEGATIVE_KEYWORDS;
  return Object.values(source).flat();
}

function tokenize(text: string): string[] {
  return text.toLowerCase().split(/[\s,;.!?।]+/).filter(Boolean);
}

export function analyzeFeedbackSentiment(text: string, languageCode: string): SentimentResult {
  const tokens = tokenize(text);
  const allPositive = getAllKeywords('positive');
  const allNegative = getAllKeywords('negative');

  let positiveCount = 0;
  let negativeCount = 0;
  const themeScores = new Map<string, number>();

  for (const token of tokens) {
    if (allPositive.includes(token)) positiveCount++;
    if (allNegative.includes(token)) negativeCount++;

    const theme = KEYWORD_THEME_MAP[token];
    if (theme) {
      themeScores.set(theme, (themeScores.get(theme) || 0) + 1);
    }
  }

  const total = positiveCount + negativeCount;
  let sentiment: Sentiment;
  let confidence: number;

  if (total === 0) {
    sentiment = 'NEUTRAL';
    confidence = 0.5;
  } else if (positiveCount > negativeCount) {
    sentiment = 'POSITIVE';
    confidence = Math.min(0.95, 0.5 + (positiveCount - negativeCount) / (total * 2));
  } else if (negativeCount > positiveCount) {
    sentiment = 'NEGATIVE';
    confidence = Math.min(0.95, 0.5 + (negativeCount - positiveCount) / (total * 2));
  } else {
    sentiment = 'NEUTRAL';
    confidence = 0.5;
  }

  const themes = Array.from(themeScores.entries())
    .map(([theme, count]) => ({
      theme,
      confidence: Math.min(0.9, count / Math.max(tokens.length, 1)),
    }))
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 3);

  return { sentiment, confidence, themes };
}

export async function summarizeParentResponses(
  tenantId: string,
  userId: string,
  userRole: string,
  feedbackRequestIds: string[],
  targetLanguage: string
): Promise<SummaryResult> {
  return withTransaction(async (client) => {
    const responses: Array<{ text: string; languageCode: string }> = [];

    if (feedbackRequestIds.length > 0) {
      const result = await client.query(
        `SELECT fri.text_value, fr.feedback_type
         FROM feedback_response_items fri
         JOIN feedback_responses fre ON fre.id = fri.response_id
         JOIN feedback_requests fr ON fr.id = fre.request_id
         WHERE fr.id = ANY($1) AND fri.text_value IS NOT NULL`,
        [feedbackRequestIds]
      );

      for (const row of result.rows) {
        responses.push({ text: row.text_value, languageCode: targetLanguage });
      }
    }

    return aggregateResponses(responses, targetLanguage);
  }, tenantId, userId, userRole);
}

export function aggregateResponses(
  responses: Array<{ text: string; languageCode: string }>,
  _targetLanguage: string
): SummaryResult {
  const sentimentDistribution: Record<Sentiment, number> = {
    POSITIVE: 0,
    NEUTRAL: 0,
    NEGATIVE: 0,
  };

  const themeAgg = new Map<string, { count: number; sampleQuotes: string[] }>();

  for (const resp of responses) {
    const analysis = analyzeFeedbackSentiment(resp.text, resp.languageCode);
    sentimentDistribution[analysis.sentiment]++;

    for (const t of analysis.themes) {
      const existing = themeAgg.get(t.theme) || { count: 0, sampleQuotes: [] };
      existing.count++;
      if (existing.sampleQuotes.length < 3) {
        existing.sampleQuotes.push(resp.text.substring(0, 200));
      }
      themeAgg.set(t.theme, existing);
    }
  }

  const themes: ThemeSummary[] = Array.from(themeAgg.entries())
    .map(([theme, data]) => ({ theme, count: data.count, sampleQuotes: data.sampleQuotes }))
    .sort((a, b) => b.count - a.count);

  const dominant = Object.entries(sentimentDistribution)
    .sort(([, a], [, b]) => b - a)[0];

  const summary = responses.length === 0
    ? 'No responses to summarize.'
    : `Analyzed ${responses.length} responses. Dominant sentiment: ${dominant[0]} (${dominant[1]} responses). ` +
      `Top themes: ${themes.slice(0, 3).map(t => `${t.theme} (${t.count})`).join(', ') || 'none detected'}.`;

  return { summary, themes, totalResponses: responses.length, sentimentDistribution };
}

export function transcribeVoiceNote(
  _audioBuffer: Buffer,
  languageCode: string
): TranscriptionResult {
  return {
    text: '[Placeholder] Voice transcription not yet implemented. Whisper integration pending.',
    confidence: 0.0,
    language_detected: languageCode || 'unknown',
  };
}
