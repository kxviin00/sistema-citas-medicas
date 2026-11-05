// Solo valores PUBLICABLES. Nunca pegar una clave secret ni service_role.
export const SUPABASE_URL = https://abzpxzndupewyawgsjbs.supabase.co/rest/v1/
export const SUPABASE_PUBLISHABLE_KEY = sb_publishable_ich4IEC5aW6P_bBg6Xs_OQ_PUnmP8Wj
export const configurado = !SUPABASE_URL.includes('TU-PROYECTO') && !SUPABASE_PUBLISHABLE_KEY.includes('REEMPLAZAR');