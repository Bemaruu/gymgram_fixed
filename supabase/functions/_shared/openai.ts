// Minimal OpenAI Chat Completions wrapper. Avoids pulling the full openai npm
// package to keep cold-start fast in Deno.

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

export type ChatMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export type ChatOptions = {
  model?: 'gpt-4o-mini' | 'gpt-4o';
  messages: ChatMessage[];
  temperature?: number;
  maxTokens?: number;
  /** If true, force JSON response (response_format=json_object). */
  json?: boolean;
};

export class OpenAIError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function chat(opts: ChatOptions): Promise<string> {
  if (!OPENAI_API_KEY) {
    throw new OpenAIError(
      500,
      'OPENAI_API_KEY is not set. Run: supabase secrets set OPENAI_API_KEY=sk-...',
    );
  }

  const body: Record<string, unknown> = {
    model: opts.model ?? 'gpt-4o-mini',
    messages: opts.messages,
    temperature: opts.temperature ?? 0.7,
  };
  if (opts.maxTokens) body.max_tokens = opts.maxTokens;
  if (opts.json) body.response_format = { type: 'json_object' };

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new OpenAIError(res.status, `OpenAI ${res.status}: ${text}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') {
    throw new OpenAIError(500, 'OpenAI returned no message content');
  }
  return content;
}

/** Convenience: parse a JSON response from the model. Throws on bad JSON. */
export async function chatJson<T>(opts: ChatOptions): Promise<T> {
  const raw = await chat({ ...opts, json: true });
  return JSON.parse(raw) as T;
}

export type VisionOptions = {
  model?: 'gpt-4o-mini' | 'gpt-4o';
  /** System prompt that defines the verification criteria. */
  system: string;
  /** User instruction sent alongside the image. */
  prompt: string;
  /** Image as a data URL (data:image/jpeg;base64,...) or public/signed URL. */
  imageUrl: string;
  /** 'low' keeps the image at ~85 tokens — enough for yes/no verification. */
  detail?: 'low' | 'high' | 'auto';
  maxTokens?: number;
};

/** Vision call that returns a parsed JSON object. Forces response_format=json. */
export async function visionJson<T>(opts: VisionOptions): Promise<T> {
  if (!OPENAI_API_KEY) {
    throw new OpenAIError(
      500,
      'OPENAI_API_KEY is not set. Run: supabase secrets set OPENAI_API_KEY=sk-...',
    );
  }

  const body = {
    model: opts.model ?? 'gpt-4o',
    temperature: 0,
    max_tokens: opts.maxTokens ?? 300,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: opts.system },
      {
        role: 'user',
        content: [
          { type: 'text', text: opts.prompt },
          {
            type: 'image_url',
            image_url: { url: opts.imageUrl, detail: opts.detail ?? 'low' },
          },
        ],
      },
    ],
  };

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new OpenAIError(res.status, `OpenAI ${res.status}: ${text}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') {
    throw new OpenAIError(500, 'OpenAI returned no message content');
  }
  return JSON.parse(content) as T;
}
