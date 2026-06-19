-- Fix notificaciones: el cron de coaching-notifications (y el batch del reporte
-- mensual) enviaban 'Bearer ' || vault.service_role_key, pero las edges lo
-- comparaban contra la env SUPABASE_SERVICE_ROLE_KEY auto-inyectada. Tras una
-- rotación de llaves, ambas dejaron de coincidir → 401/403 en CADA corrida del
-- cron → las notificaciones de motivación nunca se enviaron desde la instalación.
--
-- Esta función deja que la edge valide el bearer contra la MISMA fuente que usa
-- el cron (el service_role_key del vault), eliminando la dependencia de que la
-- env coincida. SECURITY DEFINER para poder leer vault; solo service_role la
-- puede ejecutar. Aplicada via MCP; backup del DDL.
CREATE OR REPLACE FUNCTION public.is_cron_authorized(p_auth text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT p_auth IS NOT NULL
     AND p_auth = 'Bearer ' || (
       SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key'
     );
$$;

REVOKE ALL ON FUNCTION public.is_cron_authorized(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_cron_authorized(text) TO service_role;
