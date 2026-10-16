-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE V: SQL Y CONSULTAS DEL SISTEMA (PUNTOS 24 AL 28)
-- Archivo: consultas_parte5.sql
-- =============================================================================

-- =============================================================================
-- PUNTO 24: CONSULTAS DE DIFICULTAD PROGRESIVA
-- =============================================================================

-- 24.1. Básica: Agregación simple y agrupación temporal por estado
SELECT 
    estado,
    COUNT(*) AS total_reservas,
    ROUND(AVG(tarifa), 2) AS tarifa_promedio,
    MIN(fecha_inicio) AS primer_ingreso,
    MAX(fecha_salida) AS ultimo_egreso
FROM reserva
GROUP BY estado
ORDER BY total_reservas DESC;

-- 24.2. Intermedia: Cruce con INNER JOIN, LEFT JOIN y clasificación con CASE WHEN
SELECT 
    h.nombre AS hotel,
    hab.numero AS habitacion,
    hab.capacidad,
    CASE 
        WHEN hab.capacidad = 1 THEN 'Individual'
        WHEN hab.capacidad = 2 THEN 'Doble'
        WHEN hab.capacidad = 3 THEN 'Triple'
        ELSE 'Suite Familiar'
    END AS tipo_habitacion,
    hab.precio_base
FROM habitacion hab
INNER JOIN hotel h ON h.id = hab.hotel_id
ORDER BY h.nombre, hab.numero
LIMIT 20;

-- 24.3. Avanzada: Subconsulta correlacionada con operador EXISTS
SELECT 
    cli.id,
    cli.dni,
    cli.apellido,
    cli.nombre,
    cli.nacionalidad
FROM huesped cli
WHERE EXISTS (
    SELECT 1 
    FROM reserva r 
    WHERE r.id_huesped = cli.id 
      AND r.estado = 'CONFIRMADA'
)
ORDER BY cli.apellido, cli.nombre
LIMIT 20;

-- 24.4. Completa: Top 5 destinos turísticos con mayor facturación confirmada
SELECT 
    h.ciudad,
    h.provincia,
    COUNT(r.id) AS cantidad_reservas,
    SUM(r.tarifa) AS facturacion_total
FROM hotel h
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'CONFIRMADA'
GROUP BY h.ciudad, h.provincia
ORDER BY facturacion_total DESC
LIMIT 5;


-- =============================================================================
-- PUNTO 25: 15 CONSULTAS COMPLEJAS DEL SISTEMA (AL MENOS 5 CON 4+ TABLAS)
-- =============================================================================

-- C1: Disponibilidad de habitaciones por hotel para un período solicitado
SELECT 
    h.nombre AS hotel,
    hab.id AS habitacion_id,
    hab.numero,
    hab.precio_base
FROM habitacion hab
INNER JOIN hotel h ON h.id = hab.hotel_id
WHERE h.id = 1
  AND NOT EXISTS (
      SELECT 1 
      FROM reserva r 
      WHERE r.id_habitacion = hab.id
        AND r.estado != 'CANCELADA'
        AND daterange(r.fecha_inicio, r.fecha_salida, '[]') && daterange('2026-03-01'::DATE, '2026-03-07'::DATE, '[]')
  );

-- C2: Ranking Top 10 hoteles con mayor recaudación en reservas finalizadas
SELECT 
    h.id,
    h.nombre,
    h.ciudad,
    COUNT(r.id) AS total_estadias,
    SUM(r.tarifa) AS total_recaudado
FROM hotel h
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA'
GROUP BY h.id, h.nombre, h.ciudad
ORDER BY total_recaudado DESC
LIMIT 10;

-- C3 [4+ TABLAS]: Huéspedes con reservas confirmadas, hotel, habitación y comodidades asignadas
SELECT 
    cli.apellido || ', ' || cli.nombre AS huesped,
    h.nombre AS hotel,
    hab.numero AS habitacion,
    r.fecha_inicio,
    r.tarifa,
    STRING_AGG(c.nombre, ', ') AS comodidades
FROM huesped cli
INNER JOIN reserva r ON r.id_huesped = cli.id
INNER JOIN habitacion hab ON hab.id = r.id_habitacion
INNER JOIN hotel h ON h.id = hab.hotel_id
INNER JOIN habitacion_comodidad hc ON hc.id_habitacion = hab.id
INNER JOIN comodidad c ON c.id = hc.id_comodidad
WHERE r.estado = 'CONFIRMADA'
GROUP BY cli.apellido, cli.nombre, h.nombre, hab.numero, r.fecha_inicio, r.tarifa
LIMIT 10;

-- C4 [4+ TABLAS]: Hoteles cercanos a Puntos de Interés de 'Naturaleza' con ocupación finalizada
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

-- C5 [4+ TABLAS]: Auditoría de reservas con contacto del huésped y del hotel
SELECT 
    r.id AS reserva_id,
    cli.apellido || ', ' || cli.nombre AS huesped,
    con_cli.valor AS contacto_huesped,
    h.nombre AS hotel,
    con_hot.valor AS contacto_hotel,
    r.tarifa
FROM reserva r
INNER JOIN huesped cli ON cli.id = r.id_huesped
INNER JOIN huesped_contacto hc ON hc.id_huesped = cli.id
INNER JOIN contacto con_cli ON con_cli.id = hc.id_contacto
INNER JOIN habitacion hab ON hab.id = r.id_habitacion
INNER JOIN hotel h ON h.id = hab.hotel_id
INNER JOIN hotel_contacto hot_c ON hot_c.id_hotel = h.id
INNER JOIN contacto con_hot ON con_hot.id = hot_c.id_contacto
WHERE r.id = 50000;

-- C6 [4+ TABLAS]: Facturación y demanda discriminada por nacionalidad del cliente y categoría del hotel
SELECT 
    cli.nacionalidad,
    h.valoracion AS estrellas_hotel,
    COUNT(r.id) AS total_reservas,
    ROUND(AVG(r.tarifa), 2) AS tarifa_promedio,
    SUM(r.tarifa) AS ingreso_total
FROM huesped cli
INNER JOIN reserva r ON r.id_huesped = cli.id
INNER JOIN habitacion hab ON hab.id = r.id_habitacion
INNER JOIN hotel h ON h.id = hab.hotel_id
WHERE r.estado IN ('CONFIRMADA', 'FINALIZADA')
GROUP BY cli.nacionalidad, h.valoracion
ORDER BY cli.nacionalidad, h.valoracion DESC;

-- C7 [4+ TABLAS]: Puntos de interés más visitados indirectamente según volumen de reservas
SELECT 
    pi.categoria,
    pi.nombre AS punto_interes,
    COUNT(DISTINCT h.id) AS hoteles_asociados,
    COUNT(r.id) AS volumen_reservas_hotel
FROM punto_interes pi
INNER JOIN hotel_punto_interes hpi ON hpi.id_punto_interes = pi.id
INNER JOIN hotel h ON h.id = hpi.id_hotel
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA'
GROUP BY pi.categoria, pi.nombre
ORDER BY volumen_reservas_hotel DESC
LIMIT 10;

-- C8: Distribución temporal histórica de reservas agrupadas por año
SELECT 
    EXTRACT(YEAR FROM fecha_inicio)::INT AS anio,
    COUNT(*) AS total_reservas,
    ROUND(SUM(tarifa) / 1000000.0, 2) AS millones_recaudados
FROM reserva
WHERE estado = 'FINALIZADA'
GROUP BY EXTRACT(YEAR FROM fecha_inicio)
ORDER BY anio;

-- C9: Promedio de duración de estadía (días) según la capacidad de la habitación
SELECT 
    hab.capacidad,
    COUNT(r.id) AS total_estadias,
    ROUND(AVG(r.fecha_salida - r.fecha_inicio), 2) AS promedio_dias_estadia,
    ROUND(AVG(r.tarifa), 2) AS tarifa_promedio
FROM habitacion hab
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA'
GROUP BY hab.capacidad
ORDER BY hab.capacidad;

-- C10: Clientes frecuentes: Huéspedes con más de 120 reservas acumuladas
SELECT 
    cli.id,
    cli.dni,
    cli.apellido,
    cli.nombre,
    COUNT(r.id) AS cantidad_reservas,
    SUM(r.tarifa) AS total_consumido
FROM huesped cli
INNER JOIN reserva r ON r.id_huesped = cli.id
GROUP BY cli.id, cli.dni, cli.apellido, cli.nombre
HAVING COUNT(r.id) > 120
ORDER BY cantidad_reservas DESC
LIMIT 10;

-- C11: Tasa de cancelación por hotel (porcentaje de canceladas vs confirmadas)
SELECT 
    h.nombre AS hotel,
    COUNT(r.id) AS total_reservas,
    COUNT(CASE WHEN r.estado = 'CANCELADA' THEN 1 END) AS canceladas,
    ROUND(
        COUNT(CASE WHEN r.estado = 'CANCELADA' THEN 1 END) * 100.0 / NULLIF(COUNT(r.id), 0), 
        2
    ) AS porcentaje_cancelacion
FROM hotel h
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
GROUP BY h.id, h.nombre
ORDER BY porcentaje_cancelacion DESC
LIMIT 10;

-- C12: Facturación confirmada anual acumulada por provincia y ciudad
SELECT 
    h.provincia,
    h.ciudad,
    COUNT(r.id) AS reservas_confirmadas,
    SUM(r.tarifa) AS total_facturado
FROM hotel h
INNER JOIN habitacion hab ON hab.hotel_id = h.id
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'CONFIRMADA'
GROUP BY h.provincia, h.ciudad
ORDER BY total_facturado DESC;

-- C13: Habitaciones sin reservas activas en un rango de fechas (Disponibilidad global)
SELECT 
    h.nombre AS hotel,
    hab.numero,
    hab.piso,
    hab.precio_base
FROM habitacion hab
INNER JOIN hotel h ON h.id = hab.hotel_id
LEFT JOIN reserva r ON r.id_habitacion = hab.id 
   AND r.estado != 'CANCELADA'
   AND r.fecha_inicio <= '2026-06-30'::DATE 
   AND r.fecha_salida >= '2026-06-01'::DATE
WHERE r.id IS NULL
ORDER BY h.nombre, hab.numero
LIMIT 20;

-- C14: Ranking de comodidades más demandadas según reservas finalizadas
SELECT 
    c.nombre AS comodidad,
    COUNT(r.id) AS total_reservas_asociadas
FROM comodidad c
INNER JOIN habitacion_comodidad hc ON hc.id_comodidad = c.id
INNER JOIN habitacion hab ON hab.id = hc.id_habitacion
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA'
GROUP BY c.id, c.nombre
ORDER BY total_reservas_asociadas DESC;

-- C15: Análisis de ocupación mensual y tarifa promedio por piso de habitación
SELECT 
    hab.piso,
    EXTRACT(MONTH FROM r.fecha_inicio)::INT AS mes,
    COUNT(r.id) AS total_estadias,
    ROUND(AVG(r.tarifa), 2) AS tarifa_promedio
FROM habitacion hab
INNER JOIN reserva r ON r.id_habitacion = hab.id
WHERE r.estado = 'FINALIZADA'
GROUP BY hab.piso, EXTRACT(MONTH FROM r.fecha_inicio)
ORDER BY hab.piso, mes;


-- =============================================================================
-- PUNTO 26: CONSULTAS SOBRE DISPONIBILIDAD
-- =============================================================================

-- Determinación de disponibilidad con operador de superposición de intervalos (&&)
-- Parámetros: Habitación 105, Estadía del 2026-04-10 al 2026-04-15
SELECT 
    h.id AS habitacion_id,
    h.numero,
    hot.nombre AS hotel,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM reserva r 
            WHERE r.id_habitacion = h.id 
              AND r.estado != 'CANCELADA'
              AND daterange(r.fecha_inicio, r.fecha_salida, '[]') && daterange('2026-04-10'::DATE, '2026-04-15'::DATE, '[]')
        ) THEN 'NO DISPONIBLE'
        ELSE 'DISPONIBLE'
    END AS estado_disponibilidad
FROM habitacion h
INNER JOIN hotel hot ON hot.id = h.hotel_id
WHERE h.id = 105;


-- =============================================================================
-- PUNTO 27: CONSULTAS HISTÓRICAS Y TEMPORALES
-- =============================================================================

-- Comparativa de expresiones temporales:
-- Forma A: No SARGable (invoca función por cada tupla, inhabilita B-Tree estándar)
SELECT COUNT(*), SUM(tarifa) 
FROM reserva 
WHERE EXTRACT(YEAR FROM fecha_inicio) = 2024;

-- Forma B: SARGable (rango abierto/cerrado sobre columna directa, permite Index Scan)
SELECT COUNT(*), SUM(tarifa) 
FROM reserva 
WHERE fecha_inicio >= '2024-01-01' AND fecha_inicio < '2025-01-01';


-- =============================================================================
-- PUNTO 28: TRANSPORTE DE DATOS Y PAGINACIÓN
-- =============================================================================

-- 28.1. Paginación clásica por OFFSET (costosa en páginas profundas, lee y descarta filas)
SELECT id, id_huesped, id_habitacion, fecha_inicio, tarifa 
FROM reserva 
ORDER BY id 
LIMIT 20 OFFSET 500000;

-- 28.2. Paginación eficiente por Keyset / Cursor (búsqueda indexada directa en O(1))
SELECT id, id_huesped, id_habitacion, fecha_inicio, tarifa 
FROM reserva 
WHERE id > 500000 
ORDER BY id 
LIMIT 20;
