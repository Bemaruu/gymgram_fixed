# CHANGELOG — GymGram

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).
Versiones siguiendo `versionName+versionCode` de Flutter (`pubspec.yaml`).

---

## [1.0.2+3] — 2026-05-07 — Beta cerrada (candidata a release)

### Seguridad
- Habilitado Row Level Security (RLS) en las 14 tablas de Supabase — todos los datos de usuario son privados por defecto
- Credenciales del keystore de firma Android movidas a `android/key.properties` (fuera del código fuente)
- `key.properties`, `*.keystore` y `*.jks` excluidos del repositorio vía `.gitignore`
- Edge Function `delete-user` desplegada en Supabase — elimina el usuario completo de `auth.users` usando Admin API

### Legal
- Política de Privacidad v1.0 Beta redactada y publicada (`aspectos_legales/politica_privacidad_gymgram_beta.md`)
  - Cumple Ley 19.628 Chile, compatible con App Store y Google Play
  - Supabase y Mixpanel nombrados explícitamente
  - Plazos de retención por categoría de dato
  - Referencia a Ley 21.719 (nueva ley chilena en vacancia)
- Reglas de Comunidad v1.0 Beta redactadas y publicadas (`aspectos_legales/reglas_comunidad_gymgram_beta.md`)
  - Cobertura específica para ecosistema fitness: body shaming, retos peligrosos, desinformación de salud, trastornos alimentarios, imágenes sin consentimiento
  - Sistema de moderación y consecuencias definido

### Funcionalidades
- **Eliminar cuenta in-app:** opción disponible en Editar Perfil con diálogo de confirmación (requerido por Google Play desde 2024)
- **Consentimiento en onboarding:** checkbox obligatorio en paso 12 antes de completar el registro — cubre datos de salud/fitness y analytics (Mixpanel)

### Pendiente (no bloquea Beta)
- Eliminación completa de `auth.users` depende de que la Edge Function `delete-user` esté activa; si falla, fallback elimina `profiles` con CASCADE

---

## [1.0.1+2] — 2025-09-02

### Añadido
- Pantallas principales de la app implementadas
- Feed social: publicaciones, likes, comentarios
- Perfil de usuario y edición de perfil
- Módulo de rutinas y ejercicios
- Módulo de alimentación y planes nutricionales
- Sistema de medallas y gamificación
- Onboarding de 13 pasos con recopilación de datos fitness
- Integración Mixpanel para analítica de comportamiento
- Assets visuales: imágenes, íconos y recursos de medallas

---

## [1.0.0+1] — 2025-07-28

### Añadido
- Proyecto Flutter inicializado con soporte Android, iOS, Web y macOS
- Integración base con Supabase (autenticación, base de datos, almacenamiento)
- Integración base con Firebase (Analytics, Cloud Messaging)
- Estructura de carpetas y arquitectura de servicios definida
- Schema inicial de base de datos en Supabase
- Configuración de firma de release para Android

---

## Versiones futuras — planificadas

### [1.1.0] — Pre-lanzamiento público
- [ ] Eliminación completa de cuenta verificada con Edge Function en producción
- [ ] Consentimiento granular por categoría (analytics, salud, marketing)
- [ ] Portabilidad de datos (exportar JSON/CSV)
- [ ] Canal de soporte in-app
- [ ] Actualización de Política de Privacidad conforme Ley 21.719

### [1.2.0] — Post-lanzamiento
- [ ] Funciones premium / suscripciones
- [ ] Expansión de idiomas (inglés)
- [ ] Expansión regional

---

*Mantenido por el equipo de GymGram. Responsable: Benjamín Rodriguez — gymgrambn@gmail.com*
