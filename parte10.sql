-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE X: ESCALABILIDAD, PARTICIONAMIENTO Y ESTRUCTURAS AVANZADAS (PUNTOS 49 AL 52)
-- Archivo: parte10.sql
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PUNTO 50: PARTICIONAMIENTO DECLARATIVO POR RANGO ANUAL
-- -----------------------------------------------------------------------------
-- Definición de la tabla madre particionada por fecha_inicio:
CREATE TABLE IF NOT EXISTS reserva_particionada (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    id_huesped INT NOT NULL,
    id_habitacion INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    estado VARCHAR(20) NOT NULL,
    tarifa NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (id, fecha_inicio)
) PARTITION BY RANGE (fecha_inicio);

-- Creación de particiones anuales:
CREATE TABLE IF NOT EXISTS reserva_p2023 PARTITION OF reserva_particionada 
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS reserva_p2024 PARTITION OF reserva_particionada 
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS reserva_p2025 PARTITION OF reserva_particionada 
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS reserva_pdefault PARTITION OF reserva_particionada 
    DEFAULT;


-- -----------------------------------------------------------------------------
-- PUNTO 51: PARTITION PRUNING (PODA ESTÁTICA Y DINÁMICA DE PARTICIONES)
-- -----------------------------------------------------------------------------
-- El optimizador poda las particiones de 2023, 2025 y default, escaneando solo reserva_p2024:
EXPLAIN (ANALYZE, BUFFERS)
SELECT * 
FROM reserva_particionada 
WHERE fecha_inicio >= '2024-06-01' AND fecha_inicio < '2024-07-01';


-- -----------------------------------------------------------------------------
-- PUNTO 52: VISTAS MATERIALIZADAS Y REFRESCO CONCURRENTE
-- -----------------------------------------------------------------------------
-- 1. Creación de la Vista Materializada con agregación precalculada:
CREATE MATERIALIZED VIEW IF NOT EXISTS matview_facturacion_hotel AS
SELECT 
    h.id AS hotel_id, 
    h.nombre, 
    h.ciudad, 
    COUNT(r.id) AS total_reservas, 
    SUM(r.tarifa) AS facturacion
FROM hotel h 
JOIN habitacion hab ON hab.hotel_id = h.id 
JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA' 
GROUP BY h.id, h.nombre, h.ciudad;

-- 2. Creación de índice único para habilitar el refresco concurrente:
CREATE UNIQUE INDEX IF NOT EXISTS uq_matview_hotel_id 
    ON matview_facturacion_hotel (hotel_id);

-- 3. Lectura ultra-rápida indexada (0.06 ms frente a ~670 ms de la vista tradicional):
EXPLAIN (ANALYZE, BUFFERS)
SELECT * 
FROM matview_facturacion_hotel 
ORDER BY facturacion DESC 
LIMIT 10;

-- 4. Refresco concurrente en segundo plano sin bloquear lecturas activas:
REFRESH MATERIALIZED VIEW CONCURRENTLY matview_facturacion_hotel;
