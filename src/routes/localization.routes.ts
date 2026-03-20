import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getLocalizedStrings } from '../services/localization.service';
import { withTransaction } from '../config/database';

export default async function localizationRoutes(app: FastifyInstance) {
  app.get('/localization/strings', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { language, prefix } = request.query as { language: string; prefix?: string };
    const strings = await getLocalizedStrings(user.tenantId, user.userId, user.role, language, prefix);
    return { strings };
  });

  app.post('/localization/bulk-resolve', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { keys, language, fallbackLanguage } = request.body as {
      keys: string[];
      language: string;
      fallbackLanguage?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT key, language, value FROM localization_strings
         WHERE key = ANY($1) AND language IN ($2, $3)
         ORDER BY key, CASE WHEN language = $2 THEN 0 ELSE 1 END`,
        [keys, language, fallbackLanguage || 'en']
      );
      const resolved: Record<string, { value: string; language: string; fallback: boolean }> = {};
      const fallbackLog: string[] = [];
      for (const row of result.rows as Array<{ key: string; language: string; value: string }>) {
        if (!resolved[row.key]) {
          const isFallback = row.language !== language;
          resolved[row.key] = { value: row.value, language: row.language, fallback: isFallback };
          if (isFallback) fallbackLog.push(row.key);
        }
      }
      return { resolved, fallbackKeys: fallbackLog };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/localization/resolve', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { key, language, fallbackLanguage } = request.query as {
      key: string;
      language: string;
      fallbackLanguage?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT key, language, value FROM localization_strings
         WHERE key = $1 AND language IN ($2, $3)
         ORDER BY CASE WHEN language = $2 THEN 0 ELSE 1 END
         LIMIT 1`,
        [key, language, fallbackLanguage || 'en']
      );
      if (result.rows.length === 0) {
        return { key, value: null, resolved: false };
      }
      const row = result.rows[0] as { key: string; language: string; value: string };
      return {
        key: row.key,
        value: row.value,
        language: row.language,
        fallback: row.language !== language,
        resolved: true,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/localization/fallback-report', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { language, since, limit, offset } = request.query as {
      language?: string;
      since?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (language) { conditions.push(`fl.requested_language = $${params.length + 1}`); params.push(language); }
      if (since) { conditions.push(`fl.created_at >= $${params.length + 1}`); params.push(since); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT fl.key, fl.requested_language, fl.fallback_language, fl.occurrence_count,
                fl.first_seen, fl.last_seen
         FROM localization_fallback_log fl
         ${where}
         ORDER BY fl.occurrence_count DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { fallbacks: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });
}
