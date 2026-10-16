-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE VIII: TRANSACCIONES Y CONCURRENCIA (PUNTOS 38 AL 42)
-- Archivo: parte8.sql
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PUNTO 38: BLOQUEOS A NIVEL DE FILA Y DE TABLA
-- -----------------------------------------------------------------------------
-- Bloqueo exclusivo de fila (SELECT FOR UPDATE):
BEGIN;
SELECT id, numero, precio_base FROM habitacion WHERE id = 10 FOR UPDATE;
COMMIT;

-- Bloqueo exclusivo de tabla (LOCK TABLE en modo exclusivo):
BEGIN;
LOCK TABLE habitacion IN ACCESS EXCLUSIVE MODE;
COMMIT;


-- -----------------------------------------------------------------------------
-- PUNTO 39: CONCURRENCIA ENTRE SESIONES (MVCC Y BLOQUEOS DE ESCRITURA)
-- -----------------------------------------------------------------------------
-- Sesión 1: Inicia transacción y modifica la fila 15 sin confirmar
-- BEGIN; UPDATE habitacion SET precio_base = 999.00 WHERE id = 15;

-- Sesión 2: Lectura inmediata sin bloqueo gracias a MVCC (lee la versión previa del snapshot)
SELECT id, precio_base FROM habitacion WHERE id = 15;

-- Sesión 2: Intento de escritura sobre la misma fila (queda bloqueada en espera de Sesión 1)
-- BEGIN; UPDATE habitacion SET precio_base = 550.00 WHERE id = 15;

-- Sesión 1: Confirma y libera el candado, permitiendo que Sesión 2 despierte
-- COMMIT;


-- -----------------------------------------------------------------------------
-- PUNTO 40: NIVELES DE AISLAMIENTO
-- -----------------------------------------------------------------------------
-- Nivel REPEATABLE READ: garantiza un snapshot inmutable para toda la transacción
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT SUM(tarifa) FROM reserva WHERE estado = 'CONFIRMADA';
COMMIT;

-- Nivel SERIALIZABLE (SSI): previene anomalías de Write Skew mediante predicados
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM reserva WHERE estado = 'PENDIENTE';
COMMIT;


-- -----------------------------------------------------------------------------
-- PUNTO 41: DEADLOCKS (INTERBLOQUEOS MUTUOS)
-- -----------------------------------------------------------------------------
-- Simulación de interbloqueo cruzado entre dos sesiones:
-- Sesión 1:
--   BEGIN;
--   UPDATE habitacion SET precio_base = precio_base + 1 WHERE id = 1;
--   -- (espera a que Sesión 2 ejecute su primer paso)
--   UPDATE habitacion SET precio_base = precio_base + 1 WHERE id = 2; -- Queda en espera

-- Sesión 2:
--   BEGIN;
--   UPDATE habitacion SET precio_base = precio_base + 2 WHERE id = 2;
--   -- (intenta bloquear el recurso 1 retenido por Sesión 1)
--   UPDATE habitacion SET precio_base = precio_base + 2 WHERE id = 1;

-- Resultado automático del motor tras 1 segundo (deadlock_timeout):
-- ERROR: deadlock detected (SQLSTATE 40P01)


-- -----------------------------------------------------------------------------
-- PUNTO 42: IDENTIFICACIÓN Y DIAGNÓSTICO DE BLOQUEOS
-- -----------------------------------------------------------------------------
-- Diagnóstico en tiempo real mediante pg_blocking_pids():
SELECT 
    pid, 
    pg_blocking_pids(pid) AS bloqueado_por_pids, 
    state,
    wait_event_type, 
    wait_event, 
    now() - query_start AS tiempo_espera, 
    query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
