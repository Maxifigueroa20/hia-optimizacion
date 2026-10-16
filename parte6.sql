-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE VI: OPTIMIZADOR, SARGABILIDAD Y PLANES DE EJECUCIÓN (PUNTOS 29 AL 33)
-- Archivo: parte6.sql
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PUNTO 29: EXPLAIN Y EXPLAIN ANALYZE CON BUFFERS Y ORDENAMIENTO EN RAM
-- -----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.id, r.id_huesped, r.tarifa, r.fecha_inicio
FROM reserva r
WHERE r.id_huesped = 4 AND r.estado = 'CONFIRMADA'
ORDER BY r.fecha_inicio;


-- -----------------------------------------------------------------------------
-- PUNTO 30: SARGABILIDAD (NO SARGABLE VS SARGABLE)
-- -----------------------------------------------------------------------------
-- Forma A: No SARGable (función/operación sobre columna, escanea 57k bloques)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(tarifa) FROM reserva
WHERE estado = 'CONFIRMADA'
  AND (fecha_inicio + INTERVAL '10 days') >= '2025-01-01'
  AND (fecha_inicio + INTERVAL '10 days') < '2025-02-01';

-- Forma B: SARGable (rango algebraico directo, 387 bloques, 95x más rápido)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(tarifa) FROM reserva
WHERE estado = 'CONFIRMADA'
  AND fecha_inicio >= '2024-12-22'
  AND fecha_inicio < '2025-01-22';


-- -----------------------------------------------------------------------------
-- PUNTO 31: ESTADÍSTICAS DEL OPTIMIZADOR EN PG_STATS
-- -----------------------------------------------------------------------------
SELECT attname, n_distinct, most_common_vals, most_common_freqs, correlation
FROM pg_stats
WHERE tablename = 'reserva' AND attname IN ('estado', 'fecha_inicio', 'tarifa');


-- -----------------------------------------------------------------------------
-- PUNTO 32: COSTO Y SELECCIÓN DE PLAN POR SELECTIVIDAD (TIPPING POINT)
-- -----------------------------------------------------------------------------
-- Alta selectividad (~5% CANCELADA -> Bitmap Index Scan):
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(tarifa) FROM reserva WHERE estado = 'CANCELADA';

-- Baja selectividad (~65% FINALIZADA -> Parallel Seq Scan masivo):
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(tarifa) FROM reserva WHERE estado = 'FINALIZADA';


-- -----------------------------------------------------------------------------
-- PUNTO 33: OPTIMIZACIÓN DE JOIN MULTITABLA
-- -----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT h.id, h.nombre, COUNT(r.id) AS total_reservas, SUM(r.tarifa) AS ingresos
FROM hotel h
JOIN habitacion hab ON hab.hotel_id = h.id
JOIN reserva r ON r.id_habitacion = hab.id
WHERE h.id = 10
GROUP BY h.id, h.nombre;
