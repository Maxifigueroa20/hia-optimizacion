-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE IX: MEMORIA, SERVIDOR Y RENDIMIENTO (PUNTOS 43 AL 48)
-- Archivo: parte9.sql
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PUNTO 43: PARÁMETROS CRÍTICOS DEL SERVIDOR EN PG_SETTINGS
-- -----------------------------------------------------------------------------
SELECT name, setting, unit, short_desc 
FROM pg_settings 
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size', 'random_page_cost')
ORDER BY name;


-- -----------------------------------------------------------------------------
-- PUNTO 44: CACHE HIT RATIO EN DATOS E ÍNDICES (SHARED BUFFERS)
-- -----------------------------------------------------------------------------
SELECT 
    relname,
    ROUND(heap_blks_hit * 100.0 / NULLIF(heap_blks_hit + heap_blks_read, 0), 2) AS hit_ratio_datos,
    ROUND(idx_blks_hit * 100.0 / NULLIF(idx_blks_hit + idx_blks_read, 0), 2) AS hit_ratio_indices
FROM pg_statio_user_tables 
WHERE relname = 'reserva';


-- -----------------------------------------------------------------------------
-- PUNTO 45: TELEMETRÍA DEL HOST EN VIVO CON SYSTEM_STATS (CPU Y MEMORIA)
-- -----------------------------------------------------------------------------
-- Información de memoria física del host:
SELECT total_memory, used_memory, free_memory, cache_total 
FROM pg_sys_memory_info();

-- Información de CPU del host:
SELECT cpu_count, cpu_user, cpu_system, cpu_idle 
FROM pg_sys_cpu_info();


-- -----------------------------------------------------------------------------
-- PUNTO 46: CONEXIONES ACTIVAS Y CONNECTION POOL
-- -----------------------------------------------------------------------------
SELECT 
    count(*) AS total_conexiones, 
    count(CASE WHEN state = 'active' THEN 1 END) AS activas,
    count(CASE WHEN state = 'idle' THEN 1 END) AS inactivas,
    count(CASE WHEN state = 'idle in transaction' THEN 1 END) AS en_transaccion_ociosa
FROM pg_stat_activity;


-- -----------------------------------------------------------------------------
-- PUNTO 47: AUDITORÍA DE CONSULTAS LENTAS (> 200 MS)
-- -----------------------------------------------------------------------------
SELECT 
    pid, 
    now() - query_start AS duracion, 
    state, 
    query 
FROM pg_stat_activity 
WHERE state = 'active' 
  AND (now() - query_start) > INTERVAL '200 milliseconds';


-- -----------------------------------------------------------------------------
-- PUNTO 48: TUPLAS MUERTAS, HINCHAMIENTO (BLOAT) Y CALIBRACIÓN DE AUTOVACUUM
-- -----------------------------------------------------------------------------
-- Diagnóstico de tuplas vivas y muertas en la tabla principal:
SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum 
FROM pg_stat_user_tables 
WHERE relname = 'reserva';

-- Calibración agresiva de autovacuum para tabla de 6 millones de filas:
ALTER TABLE reserva SET (
    autovacuum_vacuum_scale_factor = 0.05, 
    autovacuum_vacuum_threshold = 1000
);
