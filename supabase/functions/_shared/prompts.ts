// Prompts compartidos. Todos en espanol neutro / LatAm.

export type Tier = 'free' | 'plus' | 'premium';

export type UserProfile = {
  id: string;
  fitness_goal?: string | null;       // LOSE_WEIGHT | GAIN_MUSCLE | MAINTAIN
  training_location?: string | null;  // GYM | HOME
  experience_level?: string | null;
  weight?: number | null;
  height?: number | null;
  age?: number | null;
  gender?: string | null;
  training_days_per_week?: number | null;
  session_duration_min?: number | null;
};

export type TrainerConfig = {
  trainer_name: string;
  tone: string;   // motivador | directo | relajado | exigente
  focus: string;  // entrenamiento | nutricion | ambos
};

/** Persona del entrenador IA. Reusable para chat, post-workout y reportes. */
export function trainerPersona(cfg: TrainerConfig): string {
  const toneInstr: Record<string, string> = {
    motivador:
      'Tu tono es motivador, calido y energico. Celebras los esfuerzos del usuario y lo impulsas a seguir.',
    directo:
      'Tu tono es directo y conciso. Vas al grano, sin rodeos, con feedback claro y accionable.',
    relajado:
      'Tu tono es relajado y empatico. Sin presion, escuchas y guias con calma.',
    exigente:
      'Tu tono es exigente y sin excusas. Esperas alto compromiso y das feedback firme.',
  };
  const focusInstr: Record<string, string> = {
    entrenamiento:
      'Tu foco es ENTRENAMIENTO: rutinas, tecnica, recuperacion, progresion.',
    nutricion:
      'Tu foco es NUTRICION: alimentacion, macros, habitos, suplementacion basica.',
    ambos:
      'Tu foco abarca entrenamiento y nutricion por igual.',
  };
  return `Eres ${cfg.trainer_name}, el entrenador personal IA de un usuario de GymGram. ${toneInstr[cfg.tone] ?? toneInstr.motivador} ${focusInstr[cfg.focus] ?? focusInstr.ambos}

Reglas estrictas:
- Responde SIEMPRE en espanol neutro/latinoamericano.
- Mantente en temas de fitness, nutricion y bienestar fisico.
- No des diagnosticos medicos. Si el usuario reporta dolor agudo o sintomas, recomienda consultar a un profesional.
- Respuestas breves: maximo 3-4 oraciones por defecto. Solo extiende si el usuario te pide profundidad.
- No inventes datos del usuario que no esten en su perfil.
- Usa solo informacion del contexto que se te entrega.`;
}

/** Devuelve un bloque legible con datos del perfil para incluir en prompts. */
export function profileContext(p: UserProfile): string {
  const lines: string[] = ['Perfil del usuario:'];
  if (p.fitness_goal) lines.push(`- Objetivo: ${p.fitness_goal}`);
  if (p.training_location) lines.push(`- Lugar de entreno: ${p.training_location}`);
  if (p.experience_level) lines.push(`- Nivel: ${p.experience_level}`);
  if (p.weight) lines.push(`- Peso: ${p.weight} kg`);
  if (p.height) lines.push(`- Altura: ${p.height} cm`);
  if (p.age) lines.push(`- Edad: ${p.age}`);
  if (p.gender) lines.push(`- Genero: ${p.gender}`);
  if (p.training_days_per_week) {
    lines.push(`- Dias/semana: ${p.training_days_per_week}`);
  }
  if (p.session_duration_min) {
    lines.push(`- Duracion sesion: ${p.session_duration_min} min`);
  }
  return lines.join('\n');
}
