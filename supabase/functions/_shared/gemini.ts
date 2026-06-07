// Minimal Google Gemini (Generative Language API) wrapper for vision + JSON.
// Mirrors openai.ts so swapping providers per-feature is a one-line change.

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

export class GeminiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/** Lanzada cuando Gemini bloquea por safety (NSFW/violencia/etc). */
export class GeminiSafetyBlocked extends Error {
  category: string;
  constructor(category: string) {
    super(`Gemini blocked by safety: ${category}`);
    this.name = 'GeminiSafetyBlocked';
    this.category = category;
  }
}

export type GeminiVisionOptions = {
  /** Flash is the cheapest vision model; good enough for food estimation. */
  model?: 'gemini-2.0-flash' | 'gemini-2.0-flash-lite' | 'gemini-2.5-flash';
  /** System instruction defining the task and output contract. */
  system: string;
  /** User instruction sent alongside the image. */
  prompt: string;
  /** Raw base64 of the image (no data: prefix). */
  imageBase64: string;
  /** e.g. image/jpeg, image/png, image/webp. */
  mimeType: string;
  maxTokens?: number;
  /** Optional OpenAPI-subset schema to force the JSON shape. */
  schema?: Record<string, unknown>;
  /** Activa safety settings al maximo (BLOCK_LOW_AND_ABOVE para NSFW). */
  strictSafety?: boolean;
};

const STRICT_SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_LOW_AND_ABOVE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_LOW_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
  { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
];

/** Vision call that returns a parsed JSON object. Forces JSON output. */
export async function visionJson<T>(opts: GeminiVisionOptions): Promise<T> {
  if (!GEMINI_API_KEY) {
    throw new GeminiError(
      500,
      'GEMINI_API_KEY is not set. Run: supabase secrets set GEMINI_API_KEY=...',
    );
  }

  const model = opts.model ?? 'gemini-2.0-flash';
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

  const generationConfig: Record<string, unknown> = {
    temperature: 0,
    maxOutputTokens: opts.maxTokens ?? 800,
    responseMimeType: 'application/json',
  };
  if (opts.schema) generationConfig.responseSchema = opts.schema;

  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: opts.system }] },
    contents: [
      {
        role: 'user',
        parts: [
          { text: opts.prompt },
          { inline_data: { mime_type: opts.mimeType, data: opts.imageBase64 } },
        ],
      },
    ],
    generationConfig,
  };
  if (opts.strictSafety) body.safetySettings = STRICT_SAFETY_SETTINGS;

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new GeminiError(res.status, `Gemini ${res.status}: ${text}`);
  }

  const data = await res.json();

  // Bloqueo por safety: el prompt entero pudo ser bloqueado (promptFeedback)
  // o solo el candidato (finishReason === 'SAFETY').
  const promptBlock = data?.promptFeedback?.blockReason;
  if (promptBlock) {
    throw new GeminiSafetyBlocked(String(promptBlock));
  }
  const candidate = data?.candidates?.[0];
  const finishReason = candidate?.finishReason;
  if (finishReason === 'SAFETY' || finishReason === 'PROHIBITED_CONTENT') {
    const blockedCat = candidate?.safetyRatings?.find?.(
      (r: { blocked?: boolean; category?: string }) => r?.blocked,
    )?.category;
    throw new GeminiSafetyBlocked(String(blockedCat ?? finishReason));
  }

  const content = candidate?.content?.parts?.[0]?.text;
  if (typeof content !== 'string') {
    throw new GeminiError(500, 'Gemini returned no text content');
  }
  return JSON.parse(content) as T;
}
