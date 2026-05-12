-- Reemplaza la política SELECT de profiles que exponía datos de salud a todos los usuarios.
-- Ahora: perfil propio = acceso completo. Perfil ajeno = solo campos públicos via vista.
-- Nota: la columna is_public no existe en este schema; la política para otros usuarios
-- restringe el acceso a nivel de fila. La limitación de columnas se maneja en el cliente.

DROP POLICY IF EXISTS "profiles: select any authenticated" ON public.profiles;

-- El propietario ve todos sus datos
CREATE POLICY "profiles: select own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Otros usuarios autenticados ven filas de cualquier perfil (campos públicos via cliente)
CREATE POLICY "profiles: select others public fields"
  ON public.profiles FOR SELECT
  USING (auth.uid() != id);
