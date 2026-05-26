-- ============================================================
-- unindexed_foreign_keys — agrega índices de cobertura a las 22 FKs sin índice.
-- Crítico para escala: rutas calientes del feed social (posts.user_id,
-- comments.post_id, likes.post_id) hacían full scan en JOINs/borrados en cascada.
-- Todos IF NOT EXISTS; no cambian comportamiento, solo aceleran. (2026-05-24)
-- ============================================================

-- Social (hot paths)
CREATE INDEX IF NOT EXISTS idx_fk_posts_user_id            ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_fk_comments_post_id         ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_fk_comments_user_id         ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_fk_likes_post_id            ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_fk_notifications_actor_id   ON public.notifications(actor_id);
CREATE INDEX IF NOT EXISTS idx_fk_notifications_post_id    ON public.notifications(post_id);
CREATE INDEX IF NOT EXISTS idx_fk_messages_receiver_id     ON public.messages(receiver_id);

-- Rutinas / ejercicios
CREATE INDEX IF NOT EXISTS idx_fk_routine_exercises_routine_id ON public.routine_exercises(routine_id);
CREATE INDEX IF NOT EXISTS idx_fk_routines_source_routine_id   ON public.routines(source_routine_id);
CREATE INDEX IF NOT EXISTS idx_fk_workout_logs_routine_id      ON public.workout_logs(routine_id);
CREATE INDEX IF NOT EXISTS idx_fk_user_strength_records_exercise_id ON public.user_strength_records(exercise_id);

-- Nutrición / recetas
CREATE INDEX IF NOT EXISTS idx_fk_meal_items_meal_plan_id   ON public.meal_items(meal_plan_id);
CREATE INDEX IF NOT EXISTS idx_fk_meal_plans_user_id        ON public.meal_plans(user_id);
CREATE INDEX IF NOT EXISTS idx_fk_saved_recipes_recipe_id   ON public.saved_recipes(recipe_id);
CREATE INDEX IF NOT EXISTS idx_fk_user_recipe_ingredients_food_id ON public.user_recipe_ingredients(food_id);

-- Onboarding
CREATE INDEX IF NOT EXISTS idx_fk_user_onboarding_data_user_id ON public.user_onboarding_data(user_id);

-- Ranked
CREATE INDEX IF NOT EXISTS idx_fk_rp_transactions_season_id        ON public.rp_transactions(season_id);
CREATE INDEX IF NOT EXISTS idx_fk_season_rewards_season_id         ON public.season_rewards(season_id);
CREATE INDEX IF NOT EXISTS idx_fk_user_mission_progress_mission_id ON public.user_mission_progress(mission_id);
CREATE INDEX IF NOT EXISTS idx_fk_user_ranked_profile_current_season_id ON public.user_ranked_profile(current_season_id);

-- Moderación
CREATE INDEX IF NOT EXISTS idx_fk_reports_target_message_id ON public.reports(target_message_id);
CREATE INDEX IF NOT EXISTS idx_fk_reports_target_user_id    ON public.reports(target_user_id);

-- ============================================================
-- PENDIENTE (optimización mayor, hacer con cuidado policy-by-policy):
--  - auth_rls_initplan (140): envolver auth.uid() como (select auth.uid()) en las
--    políticas RLS para que se evalúe 1 vez por query y no por fila. Gran ganancia
--    a escala, pero requiere reescribir cada política con su definición exacta;
--    NO se automatiza aquí por riesgo de romper RLS.
--  - multiple_permissive_policies (208): consolidar políticas permisivas
--    redundantes por rol/acción. Impacto menor.
-- ============================================================
