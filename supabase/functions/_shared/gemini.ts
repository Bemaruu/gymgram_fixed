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
};

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

  const body = {
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
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof content !== 'string') {
    throw new GeminiError(500, 'Gemini returned no text content');
  }
  return JSON.parse(content) as T;
}
