-- pg_cron schedule para invocar la edge function `generate-monthly-report`
-- el dia 1 de cada mes a las 03:00 UTC.
--
-- Requiere:
--   1. Extensiones `pg_cron`, `pg_net` y `supabase_vault` habilitadas
--      (dashboard -> Database -> Extensions).
--   2. Dos secrets en Vault:
--        select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--        select vault.create_secret('<service-role-key>', 'service_role_key');
--      Se configuran via SQL Editor antes de aplicar esta migracion.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Borrar schedule previo si existiera (idempotente)
do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname = 'generate-monthly-report-cron';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end $$;

-- Agendar: dia 1 de cada mes a las 03:00 UTC
select cron.schedule(
  'generate-monthly-report-cron',
  '0 3 1 * *',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/generate-monthly-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' ||
        (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := jsonb_build_object('batch', true)
  );
  $cron$
);
