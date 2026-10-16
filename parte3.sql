-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- PARTE III: ÍNDICES Y ESTRUCTURAS DE ACCESO (PUNTOS 11 AL 18)
-- Base de datos: hotel_db (PostgreSQL 16)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PUNTO 11: ESTRATEGIA GENERAL DE ÍNDICES (DDL)
-- -----------------------------------------------------------------------------

-- 1. Índices sobre Claves Foráneas (FK) para optimizar JOINs y validaciones de integridad
CREATE INDEX IF NOT EXISTS idx_habitacion_hotel_id 
    ON habitacion(hotel_id);

CREATE INDEX IF NOT EXISTS idx_reserva_id_huesped 
    ON reserva(id_huesped);

CREATE INDEX IF NOT EXISTS idx_reserva_id_habitacion 
    ON reserva(id_habitacion);

CREATE INDEX IF NOT EXISTS idx_habitacion_comodidad_comodidad 
    ON habitacion_comodidad(id_comodidad);

CREATE INDEX IF NOT EXISTS idx_hotel_punto_interes_punto 
    ON hotel_punto_interes(id_punto_interes);

CREATE INDEX IF NOT EXISTS idx_hotel_contacto_contacto 
    ON hotel_contacto(id_contacto);

CREATE INDEX IF NOT EXISTS idx_huesped_contacto_contacto 
    ON huesped_contacto(id_contacto);


-- -----------------------------------------------------------------------------
-- PUNTO 14: ÍNDICES COMPUESTOS Y REGLA DEL PREFIJO IZQUIERDO
-- -----------------------------------------------------------------------------

-- Creación del índice compuesto sobre (estado, fecha_inicio)
CREATE INDEX IF NOT EXISTS idx_reserva_compuesto_estado_fecha 
    ON reserva(estado, fecha_inicio);

-- Consulta A: Filtra por el prefijo izquierdo (estado) y por la segunda columna (fecha_inicio)
-- Usa Index Scan aprovechando ambas ramas del B-Tree compuesto
EXPLAIN 
SELECT id, id_huesped, id_habitacion, estado, fecha_inicio 
FROM reserva 
WHERE estado = 'CONFIRMADA' AND fecha_inicio >= '2026-11-01';

-- Consulta B: Filtra ÚNICAMENTE por el prefijo izquierdo (estado)
-- Usa Index Scan sobre el compuesto al respetar la regla del prefijo izquierdo
EXPLAIN 
SELECT id, id_huesped, id_habitacion, estado, fecha_inicio 
FROM reserva 
WHERE estado = 'CONFIRMADA';

-- Consulta C: Filtra ÚNICAMENTE por la segunda columna (fecha_inicio), omitiendo el prefijo
-- El optimizador descarta el índice compuesto y recurre a Seq Scan
EXPLAIN 
SELECT id, id_huesped, id_habitacion, estado, fecha_inicio 
FROM reserva 
WHERE fecha_inicio >= '2026-11-01';


-- -----------------------------------------------------------------------------
-- PUNTO 15: ÍNDICES DE COBERTURA (COVERING INDEX CON CLÁUSULA INCLUDE)
-- -----------------------------------------------------------------------------

-- Creación del índice de cobertura: incluye 'tarifa' como columna payload en las hojas
CREATE INDEX IF NOT EXISTS idx_reserva_cobertura_huesped_estado 
    ON reserva (id_huesped, estado) 
    INCLUDE (tarifa);

-- Consulta de cálculo de total facturado por huésped y estado
-- Con el índice: Ejecuta Index Only Scan (lee directamente de las hojas del índice sin acceder a las páginas de la tabla)
EXPLAIN 
SELECT id_huesped, estado, tarifa 
FROM reserva 
WHERE id_huesped = 101 AND estado = 'CONFIRMADA';


-- -----------------------------------------------------------------------------
-- PUNTO 16: ÍNDICES FUNCIONALES O BASADOS EN EXPRESIONES
-- -----------------------------------------------------------------------------

-- Índice funcional para búsquedas insensibles a mayúsculas/minúsculas sobre apellido
CREATE INDEX IF NOT EXISTS idx_huesped_apellido_lower 
    ON huesped (LOWER(apellido));

-- Consulta que aprovecha el índice funcional
EXPLAIN 
SELECT id, dni, nombre, apellido 
FROM huesped 
WHERE LOWER(apellido) = 'gonzalez';

-- Índice funcional sobre componente temporal (Año de inicio de reserva)
CREATE INDEX IF NOT EXISTS idx_reserva_anio_inicio 
    ON reserva ((EXTRACT(YEAR FROM fecha_inicio)));

-- Consulta que aprovecha la expresión indexada
EXPLAIN 
SELECT id, id_habitacion, tarifa 
FROM reserva 
WHERE EXTRACT(YEAR FROM fecha_inicio) = 2026;


-- -----------------------------------------------------------------------------
-- PUNTO 18: COMPARACIÓN DE ESCENARIOS DE INDEXACIÓN (SOBREINDEXACIÓN)
-- -----------------------------------------------------------------------------

-- Escenario de sobreindexación indiscriminada (desaconsejado para tablas transaccionales masivas):
-- Descomentar únicamente con fines experimentales para medir penalización en INSERT/UPDATE:
/*
CREATE INDEX idx_sobre_reserva_fecha_salida ON reserva(fecha_salida);
CREATE INDEX idx_sobre_reserva_tarifa ON reserva(tarifa);
CREATE INDEX idx_sobre_reserva_fechas ON reserva(fecha_inicio, fecha_salida);
*/
