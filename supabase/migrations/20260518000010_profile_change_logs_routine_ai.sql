-- Agrega 'routine_ai_change' al check constraint de profile_change_logs.field.
-- Permite contar regeneraciones del plan IA dentro de la cuota anual combinada.

alter table public.profile_change_logs
  drop constraint if exists profile_change_logs_field_check;

alter table public.profile_change_logs
  add constraint profile_change_logs_field_check
  check (field in ('fitness_goal','training_location','routine_ai_change'));
