-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE VII: OPTIMIZACIÓN DE CONSULTAS (PUNTOS 34 AL 37)
-- Archivo: parte7.sql
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================
-- En este script se contrastan las 8 consultas seleccionadas de la Parte 5 
-- (versiones originales no optimizadas) contra sus versiones optimizadas, 
-- auditando el plan de ejecución y consumo de memoria/búfers con EXPLAIN ANALYZE.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CASO Q1: SARGABILIDAD EN FILTRO TEMPORAL
-- Origen: Consulta C8 / Punto 27 de Parte 5
-- Técnica: Sustitución de expresión temporal envolvente por rango directo
-- -----------------------------------------------------------------------------

-- Versión Original (No SARGable: evaluación por tupla, scan masivo):
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(tarifa) FROM reserva
WHERE estado = 'CONFIRMADA'
  AND (fecha_inicio + INTERVAL '10 days') >= '2025-01-01'
  AND (fecha_inicio + INTERVAL '10 days') < '2025-02-01';
-- Resultado original: ~1260 ms | Buffers: 57.394 bloques | Seq/Bitmap Scan tardío

-- Versión Optimizada (SARGable: búsqueda binaria en B-Tree sobre rango directo):
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(tarifa) FROM reserva
WHERE estado = 'CONFIRMADA'
  AND fecha_inicio >= '2024-12-22'
  AND fecha_inicio < '2025-01-22';
-- Resultado optimizado: ~2.85 ms | Buffers: 387 bloques | Mejora: ~440x más rápida


-- -----------------------------------------------------------------------------
-- CASO Q2: PAGINACIÓN EN PROFUNDIDAD (KEYSET PAGINATION VS OFFSET)
-- Origen: Punto 28.1 de Parte 5
-- Técnica: Sustitución de OFFSET por paginación indexada por cursor
-- -----------------------------------------------------------------------------

-- Versión Original (Paginación clásica con OFFSET: descarta 500.000 tuplas):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, id_huesped, id_habitacion, fecha_inicio, tarifa 
FROM reserva 
ORDER BY id 
LIMIT 20 OFFSET 500000;
-- Resultado original: ~110.8 ms | Buffers: 6.043 bloques leídos y descartados

-- Versión Optimizada (Keyset Pagination: acceso en tiempo constante O(1)):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, id_huesped, id_habitacion, fecha_inicio, tarifa
FROM reserva 
WHERE id > 500000 
ORDER BY id 
LIMIT 20;
-- Resultado optimizado: ~0.12 ms | Buffers: 8 bloques | Mejora: ~900x más rápida


-- -----------------------------------------------------------------------------
-- CASO Q3: EXCLUSIÓN Y DISPONIBILIDAD (NOT EXISTS VS NOT IN / LEFT JOIN)
-- Origen: Consulta C13 de Parte 5
-- Técnica: Reestructuración a Anti-Join con NOT EXISTS
-- -----------------------------------------------------------------------------

-- Versión Original (Subconsulta con NOT IN: desborda a disco por lógica trivaluada):
EXPLAIN (ANALYZE, BUFFERS)
SELECT hab.id, hab.numero, hab.precio_base
FROM habitacion hab
WHERE hab.hotel_id = 1
  AND hab.id NOT IN (
      SELECT r.id_habitacion 
      FROM reserva r 
      WHERE r.estado = 'CONFIRMADA'
  );
-- Resultado original: ~6.374 ms | Temp disk blocks: 99.997 bloques | Desborde a disco

-- Versión Optimizada (Nested Loop Anti-Join con corte temprano):
EXPLAIN (ANALYZE, BUFFERS)
SELECT hab.id, hab.numero, hab.precio_base
FROM habitacion hab
WHERE hab.hotel_id = 1
  AND NOT EXISTS (
      SELECT 1 
      FROM reserva r 
      WHERE r.id_habitacion = hab.id 
        AND r.estado = 'CONFIRMADA'
  );
-- Resultado optimizado: ~62.7 ms | Buffers: 0 bloques en disco | Mejora: ~100x más rápida


-- -----------------------------------------------------------------------------
-- CASO Q4: ACCESO AL MONTÍCULO (COVERING INDEX CON INCLUDE)
-- Origen: Consulta C10 / Agregación por Huésped de Parte 5
-- Técnica: Inclusión de columna de carga útil (tarifa) en el índice B-Tree
-- -----------------------------------------------------------------------------

-- Versión Original (Índice normal: requiere acceder al montículo por cada tupla):
-- SELECT id_huesped, estado, SUM(tarifa) FROM reserva WHERE id_huesped = 4 AND estado = 'CONFIRMADA' GROUP BY id_huesped, estado;
-- Resultado original: Requiere Heap Fetches para resolver la columna tarifa

-- Versión Optimizada (Index Only Scan aprovechando INCLUDE (tarifa)):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_huesped, estado, SUM(tarifa)
FROM reserva
WHERE id_huesped = 4 AND estado = 'CONFIRMADA'
GROUP BY id_huesped, estado;
-- Resultado optimizado: ~1.86 ms | Heap Fetches: 0 | Buffers: 10 bloques


-- -----------------------------------------------------------------------------
-- CASO Q5: BÚSQUEDA INSENSIBLE A MAYÚSCULAS (ÍNDICE FUNCIONAL)
-- Origen: Punto 24.3 de Parte 5 (Filtro por huésped)
-- Técnica: Alineación con índice sobre expresión UPPER/LOWER
-- -----------------------------------------------------------------------------

-- Versión Original (Función no indexada: invalida B-Tree y genera Seq Scan):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, dni, apellido, nombre 
FROM huesped 
WHERE UPPER(apellido) = 'PEREZ';
-- Resultado original: ~14.39 ms | Buffers: 579 bloques | Seq Scan sobre 50.000 tuplas

-- Versión Optimizada (Búsqueda sobre LOWER alineada con idx_huesped_apellido_lower):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, dni, apellido, nombre 
FROM huesped 
WHERE LOWER(apellido) = 'perez';
-- Resultado optimizado: ~0.20 ms | Buffers: 2 bloques | Mejora: ~70x más rápida


-- -----------------------------------------------------------------------------
-- CASO Q6: ORDENAMIENTO EXPLÍCITO Y CORTE TEMPRANO (EARLY EXIT CON LIMIT)
-- Origen: Consulta 24.3 de Parte 5
-- Técnica: Soporte de ordenamiento mediante índice compuesto en (apellido, nombre)
-- -----------------------------------------------------------------------------

-- Versión Original (Sin índice de orden: ejecuta Top-N Heapsort sobre 50.000 filas):
EXPLAIN (ANALYZE, BUFFERS)
SELECT cli.id, cli.dni, cli.apellido, cli.nombre
FROM huesped cli
WHERE EXISTS (
    SELECT 1 FROM reserva r WHERE r.id_huesped = cli.id AND r.estado = 'CONFIRMADA'
)
ORDER BY cli.apellido, cli.nombre
LIMIT 20;
-- Resultado original: ~364.4 ms | Buffers: 200.583 bloques | Top-N heapsort en RAM

-- Versión Optimizada (Aprovecha índice compuesto y corta al hallar 20 coincidencias):
-- Con índice: CREATE INDEX IF NOT EXISTS idx_huesped_apellido_nombre ON huesped(apellido, nombre);
EXPLAIN (ANALYZE, BUFFERS)
SELECT cli.id, cli.dni, cli.apellido, cli.nombre
FROM huesped cli
WHERE EXISTS (
    SELECT 1 FROM reserva r WHERE r.id_huesped = cli.id AND r.estado = 'CONFIRMADA'
)
ORDER BY cli.apellido, cli.nombre
LIMIT 20;
-- Resultado optimizado: ~0.45 ms | Buffers: 173 bloques | Mejora: ~800x más rápida


-- -----------------------------------------------------------------------------
-- CASO Q7: PRE-AGREGACIÓN TEMPRANA EN CRUCES MASIVOS
-- Origen: Consulta C4 de Parte 5 (5 tablas relacionales)
-- Técnica: Reducción de cardinalidad mediante subconsulta / CTE previa al JOIN
-- -----------------------------------------------------------------------------

-- Versión Original (Cruza 6 millones de reservas con 4 tablas descriptivas):
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    h.nombre AS hotel,
    h.ciudad,
    pi.nombre AS atractivo_turistico,
    COUNT(r.id) AS total_reservas
FROM hotel h
INNER JOIN hotel_punto_interes hpi ON hpi.id_hotel = h.id
INNER JOIN punto_interes pi ON pi.id = hpi.id_punto_interes
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE pi.categoria = 'Naturaleza' AND r.estado = 'FINALIZADA'
GROUP BY h.nombre, h.ciudad, pi.nombre
ORDER BY total_reservas DESC
LIMIT 15;
-- Resultado original: ~1025.4 ms | Buffers: 56.333 bloques | Hash Join masivo de 852.000 tuplas

-- Versión Optimizada (Pre-agregación en CTE a 6.500 tuplas antes del JOIN):
EXPLAIN (ANALYZE, BUFFERS)
WITH resumen_reservas AS (
    SELECT id_habitacion, COUNT(*) AS total_hab
    FROM reserva 
    WHERE estado = 'FINALIZADA' 
    GROUP BY id_habitacion
)
SELECT 
    h.nombre AS hotel,
    h.ciudad,
    pi.nombre AS atractivo_turistico,
    SUM(rr.total_hab) AS total_reservas
FROM punto_interes pi
INNER JOIN hotel_punto_interes hpi ON hpi.id_punto_interes = pi.id
INNER JOIN hotel h ON h.id = hpi.id_hotel
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN resumen_reservas rr ON rr.id_habitacion = hab.id
WHERE pi.categoria = 'Naturaleza'
GROUP BY h.nombre, h.ciudad, pi.nombre
ORDER BY total_reservas DESC
LIMIT 15;
-- Resultado optimizado: ~339.4 ms | Buffers: 56.152 bloques | Mejora: 3x más rápida (67% menos tiempo)


-- -----------------------------------------------------------------------------
-- CASO Q8: PODA DE PROYECCIÓN (COLUMN PRUNING)
-- Origen: Consulta C5 / Auditoría de reservas de Parte 5
-- Técnica: Restricción de columnas proyectadas en lugar de SELECT *
-- -----------------------------------------------------------------------------

-- Versión Original (SELECT * proyecta 180 bytes por tupla):
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM reserva WHERE id_huesped = 4 ORDER BY id LIMIT 50;
-- Ancho promedio: ~180 bytes/fila | Alto consumo de red y descarte de Index Only Scan

-- Versión Optimizada (Proyección acotada a columnas estrictas: 24 bytes por tupla):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, fecha_inicio, tarifa FROM reserva WHERE id_huesped = 4 ORDER BY id LIMIT 50;
-- Ancho promedio: ~24 bytes/fila | Reducción del 86% en ancho de banda de red
