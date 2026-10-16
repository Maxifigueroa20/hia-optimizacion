-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 02: CARGA MASIVA DE 6 MILLONES DE REGISTROS EN RESERVA
-- =============================================================================

-- 1. Optimizaciones de sesión para evitar sobrecarga de disco y WAL durante bulk insert
SET synchronous_commit = off;
SET maintenance_work_mem = '512MB';
SET max_parallel_maintenance_workers = 4;

-- 2. Eliminar temporalmente índices secundarios y restricción GiST para no castigar I/O
ALTER TABLE reserva DROP CONSTRAINT IF EXISTS no_superposicion_fechas_habitacion;
DROP INDEX IF EXISTS idx_reserva_id_huesped;
DROP INDEX IF EXISTS idx_reserva_id_habitacion;
DROP INDEX IF EXISTS idx_reserva_compuesto_estado_fecha;
DROP INDEX IF EXISTS idx_reserva_cobertura_huesped_estado;
DROP INDEX IF EXISTS idx_reserva_anio_inicio;

-- 3. Inserción masiva de 6.000.000 de tuplas en una sola pasada secuencial
-- Utiliza generación matemática libre de solapamientos entre turnos por habitación:
-- - 10.000 habitaciones (id_habitacion = 1 a 10.000)
-- - 600 turnos por habitación (6.000.000 / 10.000)
-- - Cada estadía dura entre 2 y 6 días, con salto de 8 días entre turnos (gap de al menos 1 día)
INSERT INTO reserva (id_huesped, id_habitacion, fecha_inicio, fecha_salida, estado, tarifa)
SELECT 
    (1 + ((i * 37) % 50000))::BIGINT AS id_huesped,
    (1 + ((i - 1) % 10000))::INT AS id_habitacion,
    (DATE '2012-01-01' + (((i - 1) / 10000) * 8) * INTERVAL '1 day')::DATE AS fecha_inicio,
    (DATE '2012-01-01' + (((i - 1) / 10000) * 8 + (2 + (i % 5))) * INTERVAL '1 day')::DATE AS fecha_salida,
    (CASE 
        WHEN i % 20 = 0 THEN 'CANCELADA'
        WHEN i % 20 = 1 THEN 'PENDIENTE'
        WHEN i % 20 BETWEEN 2 AND 14 THEN 'FINALIZADA'
        ELSE 'CONFIRMADA'
    END)::VARCHAR AS estado,
    ROUND((75.00 + ((i % 250) * 2.50))::NUMERIC, 2) AS tarifa
FROM generate_series(1, 6000000) AS i;

-- 4. Reconstrucción masiva de índices secundarios (PostgreSQL los construye en paralelo y ordenados)
CREATE INDEX idx_reserva_id_huesped ON reserva(id_huesped);
CREATE INDEX idx_reserva_id_habitacion ON reserva(id_habitacion);
CREATE INDEX idx_reserva_compuesto_estado_fecha ON reserva(estado, fecha_inicio);
CREATE INDEX idx_reserva_cobertura_huesped_estado ON reserva(id_huesped, estado) INCLUDE (tarifa);
CREATE INDEX idx_reserva_anio_inicio ON reserva ((EXTRACT(YEAR FROM fecha_inicio)));

-- 5. Reinstalación de la restricción de exclusión GiST
ALTER TABLE reserva ADD CONSTRAINT no_superposicion_fechas_habitacion
EXCLUDE USING gist (
    id_habitacion WITH =,
    daterange(fecha_inicio, fecha_salida, '[]') WITH &&
) WHERE (estado != 'CANCELADA');

-- 6. Mantenimiento y actualización de metadatos en pg_statistic
VACUUM ANALYZE reserva;

-- 7. Consulta de verificación final (Métricas para captura en pgAdmin)
SELECT 
    relname AS tabla,
    reltuples::BIGINT AS total_filas,
    pg_size_pretty(pg_relation_size(c.oid)) AS tamano_tabla,
    pg_size_pretty(pg_indexes_size(c.oid)) AS tamano_indices,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano_total
FROM pg_class c
WHERE relname = 'reserva';
