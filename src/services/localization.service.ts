import { withTransaction, query } from '../config/database';

export async function getLocalizedStrings(
  tenantId: string,
  userId: string,
  userRole: string,
  languageCode: string,
  keyPrefix?: string
) {
  return withTransaction(async (client) => {
    const params: unknown[] = [languageCode];
    let keyFilter = '';

    if (keyPrefix) {
      params.push(keyPrefix + '%');
      keyFilter = `AND lk.key_code LIKE $${params.length}`;
    }

    const result = await client.query(
      `SELECT lk.key_code, ls.value, ls.status, ls.language_code
       FROM localization_strings ls
       JOIN localization_keys lk ON lk.id = ls.key_id
       WHERE ls.language_code = $1
         AND ls.status IN ('VERIFIED', 'OFFICIAL_LOCKED')
         ${keyFilter}
       ORDER BY lk.key_code`,
      params
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
