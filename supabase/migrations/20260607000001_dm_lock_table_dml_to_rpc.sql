-- ============================================================
-- DM HARDENING 3 (auditoría seguridad mensajería 2026-06-07)
-- Defensa en profundidad: bloquear DML directo a nivel de tabla.
--
-- Hoy toda escritura pasa por RPCs SECURITY DEFINER (send_message,
-- mark_chat_read, soft_delete_message, find_or_create_chat, create_report)
-- y RLS bloquea el DML ad-hoc porque NO existen policies de escritura.
-- Pero los GRANT de tabla por defecto (INSERT/UPDATE/DELETE para anon y
-- authenticated) siguen presentes: si en el futuro se agrega por error una
-- policy permisiva de escritura, la tabla quedaría abierta. Estos REVOKE
-- eliminan ese riesgo latente y sacan a `anon` por completo de la superficie DM.
-- ============================================================

-- anon: cero acceso a la superficie de mensajería
REVOKE ALL ON public.messages          FROM anon;
REVOKE ALL ON public.chats             FROM anon;
REVOKE ALL ON public.chat_participants FROM anon;
REVOKE ALL ON public.blocked_users     FROM anon;
REVOKE ALL ON public.reports           FROM anon;

-- messages: solo lectura a nivel de tabla (escritura solo via send_message RPC)
REVOKE INSERT, UPDATE, DELETE ON public.messages FROM authenticated;

-- chats: solo lectura (last_message lo escribe el trigger / RPC, no el cliente)
REVOKE INSERT, UPDATE, DELETE ON public.chats FROM authenticated;

-- chat_participants: lectura + únicamente update de last_read_at
REVOKE INSERT, UPDATE, DELETE ON public.chat_participants FROM authenticated;
GRANT  UPDATE (last_read_at)  ON public.chat_participants TO authenticated;

-- reports: insert solo via create_report RPC; se conserva SELECT (policy own)
REVOKE INSERT, UPDATE, DELETE ON public.reports FROM authenticated;

-- blocked_users: el cliente gestiona su propia lista directamente
-- (insert/delete con RLS blocker_id = auth.uid()). Se conservan esos grants.
-- Pero no hay caso de uso para editar un bloqueo: se revoca UPDATE.
REVOKE UPDATE ON public.blocked_users FROM authenticated;
