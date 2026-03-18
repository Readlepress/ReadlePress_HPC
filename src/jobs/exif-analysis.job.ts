import { query } from '../config/database';
import { insertAuditLog } from '../services/audit.service';

interface ExifData {
  DateTimeOriginal?: Date;
  GPSLatitude?: number;
  GPSLongitude?: number;
  Make?: string;
  Model?: string;
  Software?: string;
}

const EDITING_SOFTWARE_PATTERNS = [
  'photoshop', 'gimp', 'snapseed', 'lightroom', 'pixlr',
  'afterlight', 'vsco', 'canva', 'picsart',
];

export function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export async function analyzeEvidenceExif(evidenceId: string, fileBuffer: Buffer, schoolLat?: number, schoolLon?: number): Promise<void> {
  let exifData: ExifData = {};

  try {
    const exifr = await import('exifr');
    const parsed = await exifr.default.parse(fileBuffer, {
      pick: ['DateTimeOriginal', 'GPSLatitude', 'GPSLongitude', 'Make', 'Model', 'Software'],
    });
    exifData = parsed || {};
  } catch {
    await query(
      `UPDATE evidence_records SET
         integrity_flags = array_append(integrity_flags, 'NO_EXIF_DATA'),
         integrity_score = 0.5,
         integrity_recommendation = 'REVIEW',
         exif_analysis_completed_at = now()
       WHERE id = $1`,
      [evidenceId]
    );
    return;
  }

  const flags: string[] = [];
  let score = 1.0;

  // Check EXIF timestamp vs upload timestamp
  if (exifData.DateTimeOriginal) {
    const exifTime = new Date(exifData.DateTimeOriginal);
    const now = new Date();
    const hoursDiff = Math.abs(now.getTime() - exifTime.getTime()) / (1000 * 60 * 60);

    if (hoursDiff > 24) {
      flags.push('TIMESTAMP_GAP_OVER_24H');
      score -= 0.15;
    }
  } else {
    flags.push('NO_EXIF_TIMESTAMP');
    score -= 0.10;
  }

  // Check GPS distance from school
  let distanceKm: number | null = null;
  if (exifData.GPSLatitude && exifData.GPSLongitude && schoolLat && schoolLon) {
    distanceKm = calculateDistance(schoolLat, schoolLon, exifData.GPSLatitude, exifData.GPSLongitude);
    if (distanceKm > 1) {
      flags.push('DISTANT');
      score -= 0.20;
    }
  } else if (!exifData.GPSLatitude) {
    flags.push('NO_GPS_DATA');
    score -= 0.05;
  }

  // Check for editing software
  if (exifData.Software) {
    const softwareLower = exifData.Software.toLowerCase();
    const isEdited = EDITING_SOFTWARE_PATTERNS.some(p => softwareLower.includes(p));
    if (isEdited) {
      flags.push('EDITING_SOFTWARE_DETECTED');
      score -= 0.25;
    }
  }

  score = Math.max(0, Math.min(1, score));

  let recommendation: string;
  if (score >= 0.7) recommendation = 'ACCEPT';
  else if (score >= 0.4) recommendation = 'REVIEW';
  else recommendation = 'QUERY_TEACHER';

  await query(
    `UPDATE evidence_records SET
       exif_timestamp = $2,
       exif_gps_lat = $3,
       exif_gps_lon = $4,
       exif_device_make = $5,
       exif_device_model = $6,
       exif_editing_software = $7,
       integrity_score = $8,
       integrity_flags = $9,
       integrity_recommendation = $10,
       gps_distance_from_school_km = $11,
       exif_analysis_completed_at = now()
     WHERE id = $1`,
    [
      evidenceId,
      exifData.DateTimeOriginal || null,
      exifData.GPSLatitude || null,
      exifData.GPSLongitude || null,
      exifData.Make || null,
      exifData.Model || null,
      exifData.Software || null,
      score,
      flags,
      recommendation,
      distanceKm,
    ]
  );
}
