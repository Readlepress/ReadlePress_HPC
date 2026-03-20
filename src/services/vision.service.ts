import exifr from 'exifr';

type EvidenceCategory =
  | 'WRITTEN_WORK'
  | 'SCIENCE_EXPERIMENT'
  | 'ART_PROJECT'
  | 'GROUP_ACTIVITY'
  | 'FIELD_TRIP'
  | 'CLASSROOM_SCENE'
  | 'CERTIFICATE'
  | 'OTHER';

interface ClassificationResult {
  category: EvidenceCategory;
  confidence: number;
  tags: string[];
}

interface HandwritingResult {
  hasHandwriting: boolean;
  extractedText: string;
  language: string;
  confidence: number;
}

interface ProgressionComparisonResult {
  similarityScore: number;
  improvements: string[];
  analysis: string;
}

interface ClassroomAssessmentResult {
  qualityScore: number;
  factors: {
    lighting: number;
    organization: number;
    materials: number;
    displays: number;
  };
}

async function extractExifData(imageBuffer: Buffer): Promise<Record<string, unknown> | null> {
  try {
    const data = await exifr.parse(imageBuffer, {
      tiff: true,
      exif: true,
      gps: true,
      ifd0: {} as Record<string, never>,
    } as Parameters<typeof exifr.parse>[1]);
    return data || null;
  } catch {
    return null;
  }
}

function inferCategoryFromMetadata(
  exifData: Record<string, unknown> | null,
  width: number | null,
  height: number | null
): { category: EvidenceCategory; confidence: number; tags: string[] } {
  const tags: string[] = [];
  let category: EvidenceCategory = 'OTHER';
  let confidence = 0.2;

  const isLandscape = width && height && width > height;
  const isPortrait = width && height && height > width;
  const isSquare = width && height && Math.abs(width - height) < 50;

  if (isLandscape) tags.push('landscape');
  if (isPortrait) tags.push('portrait');
  if (isSquare) tags.push('square');

  const flashFired = exifData?.Flash !== undefined && exifData.Flash !== 0;
  if (flashFired) tags.push('flash_used', 'indoor');

  if (exifData?.GPSLatitude) tags.push('geotagged');
  if (exifData?.Make) tags.push(`camera:${String(exifData.Make).toLowerCase()}`);

  if (flashFired) {
    category = 'CLASSROOM_SCENE';
    confidence = 0.35;
    tags.push('likely_indoor');
  } else if (exifData?.GPSLatitude) {
    category = 'FIELD_TRIP';
    confidence = 0.3;
    tags.push('has_location');
  } else if (isPortrait) {
    category = 'WRITTEN_WORK';
    confidence = 0.25;
    tags.push('portrait_orientation');
  } else if (isLandscape) {
    category = 'GROUP_ACTIVITY';
    confidence = 0.25;
    tags.push('landscape_orientation');
  }

  return { category, confidence, tags };
}

export async function classifyEvidence(imageBuffer: Buffer): Promise<ClassificationResult> {
  const exifData = await extractExifData(imageBuffer);

  let width: number | null = null;
  let height: number | null = null;

  if (exifData) {
    width = (exifData.ImageWidth ?? exifData.ExifImageWidth ?? null) as number | null;
    height = (exifData.ImageHeight ?? exifData.ExifImageHeight ?? null) as number | null;
  }

  const result = inferCategoryFromMetadata(exifData, width, height);

  return {
    category: result.category,
    confidence: result.confidence,
    tags: result.tags,
  };
}

export function detectHandwriting(_imageBuffer: Buffer): HandwritingResult {
  return {
    hasHandwriting: false,
    extractedText: '[Placeholder] OCR not yet implemented. Tesseract/cloud OCR integration pending.',
    language: 'unknown',
    confidence: 0.0,
  };
}

export function compareProgressionPhotos(
  _imageBuffer1: Buffer,
  _imageBuffer2: Buffer
): ProgressionComparisonResult {
  return {
    similarityScore: 0.0,
    improvements: [
      'Visual comparison not yet implemented.',
      'Requires ML-based image diff integration.',
      'Template-based placeholder response.',
    ],
    analysis:
      'This is a placeholder comparison. A production implementation would use perceptual hashing ' +
      'and feature matching to detect structural improvements in student work samples over time.',
  };
}

export function assessClassroomEnvironment(_imageBuffer: Buffer): ClassroomAssessmentResult {
  return {
    qualityScore: 0.0,
    factors: {
      lighting: 0.0,
      organization: 0.0,
      materials: 0.0,
      displays: 0.0,
    },
  };
}
