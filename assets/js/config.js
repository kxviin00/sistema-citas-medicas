// Configuración pública de Supabase
export const SUPABASE_URL = 'https://abzpxzndupewyawgsjbs.supabase.co';

export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_ich4IEC5aW6P_bBg6Xs_OQ_PUnmP8Wj';

export const configurado =
  SUPABASE_URL.startsWith('https://') &&
  SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_');
