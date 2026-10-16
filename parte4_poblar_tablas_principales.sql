-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- SCRIPT 01: CARGA DE TABLAS MAESTRAS Y ASOCIATIVAS (TEAs)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. HOTELES (200 establecimientos con nombres, categorías y destinos reales)
-- -----------------------------------------------------------------------------
WITH data_hoteles AS (
    SELECT 
        ARRAY[
            'Grand Hotel', 'Hotel Boutique', 'Resort & Spa', 'Palace Hotel', 'Hostel & Suites', 
            'Eco Lodge', 'Hotel Real', 'Plaza Hotel', 'Posada de la Montaña', 'Hostería del Valle',
            'Hotel Internacional', 'Suites & Spa', 'Hotel del Bosque', 'Hotel Termas', 'Mirador Hotel'
        ] AS prefijos,
        ARRAY[
            'del Sol', 'del Valle', 'de las Sierras', 'del Mar', 'Andino', 
            'Patagonia', 'de la Candelaria', 'San Telmo', 'Recoleta', 'Libertador', 
            'Costanera', 'Austral', 'de los Glaciares', 'del Bosque', 'Cataratas', 
            'del Lago', 'Imperial', 'Aconcagua', 'del Parque', 'Alvear'
        ] AS sufijos,
        ARRAY[
            'Buenos Aires', 'San Carlos de Bariloche', 'Mendoza', 'Córdoba', 'Salta', 
            'Mar del Plata', 'Ushuaia', 'Puerto Iguazú', 'El Calafate', 'Villa La Angostura', 
            'San Martín de los Andes', 'Puerto Madryn', 'Rosario', 'Tandil', 'Villa Carlos Paz'
        ] AS ciudades,
        ARRAY[
            'Buenos Aires', 'Río Negro', 'Mendoza', 'Córdoba', 'Salta', 
            'Buenos Aires', 'Tierra del Fuego', 'Misiones', 'Santa Cruz', 'Neuquén', 
            'Neuquén', 'Chubut', 'Santa Fe', 'Buenos Aires', 'Córdoba'
        ] AS provincias,
        ARRAY[
            'Av. San Martín', 'Av. del Libertador', 'Calle Belgrano', 'Av. Corrientes', 
            'Av. Santa Fe', 'Calle Mitre', 'Av. Alvear', 'Calle Rivadavia', 
            'Av. Ezequiel Bustillo', 'Calle Florida', 'Av. Colón', 'Av. Costanera', 
            'Bv. San Juan', 'Calle Güemes', 'Av. Arrayanes'
        ] AS calles
)
INSERT INTO hotel (nombre, valoracion, direccion, ciudad, provincia, pais)
SELECT 
    d.prefijos[1 + (i % 15)] || ' ' || d.sufijos[1 + ((i * 7) % 20)] || (CASE WHEN i > 50 THEN ' ' || (i / 10)::TEXT ELSE '' END),
    (CASE WHEN i % 10 IN (0, 1) THEN 3 WHEN i % 10 BETWEEN 2 AND 7 THEN 4 ELSE 5 END)::SMALLINT,
    d.calles[1 + (i % 15)] || ' ' || (120 + ((i * 47) % 3800)),
    d.ciudades[1 + (i % 15)],
    d.provincias[1 + (i % 15)],
    'Argentina'
FROM generate_series(1, 200) AS i, data_hoteles d;


-- -----------------------------------------------------------------------------
-- 2. PUNTOS DE INTERÉS (50 atractivos turísticos reales de Argentina)
-- -----------------------------------------------------------------------------
INSERT INTO punto_interes (nombre, categoria) VALUES
('Teatro Colón', 'Cultura'),
('Cataratas del Iguazú', 'Naturaleza'),
('Glaciar Perito Moreno', 'Naturaleza'),
('Cerro Catedral', 'Aventura'),
('Quebrada de Humahuaca', 'Paisaje'),
('Monumento Nacional a la Bandera', 'Histórico'),
('Valle de la Luna - Ischigualasto', 'Geología'),
('Caminito y La Boca', 'Paseo Urbano'),
('Parque Nacional Nahuel Huapi', 'Naturaleza'),
('Palacio Barolo', 'Arquitectura'),
('Faro del Fin del Mundo', 'Histórico'),
('Cementerio de la Recoleta', 'Patrimonio'),
('Cerro Aconcagua', 'Montañismo'),
('Jardín Japonés', 'Paseo Urbano'),
('Ruinas de San Ignacio Miní', 'Arqueología'),
('Península Valdés', 'Fauna Marina'),
('Tren a las Nubes', 'Turismo Ferroviario'),
('Museo de Arte Latinoamericano (MALBA)', 'Museo'),
('Cerro San Bernardo', 'Mirador'),
('Bosque de Arrayanes', 'Naturaleza'),
('Dique San Roque', 'Paseo'),
('Termas de Río Hondo', 'Termas'),
('Salinas Grandes', 'Paisaje'),
('Parque Nacional Los Alerces', 'Naturaleza'),
('Cerro Otto y Confitería Giratoria', 'Mirador'),
('Puerto Madero y Puente de la Mujer', 'Gastronomía'),
('Museo de La Plata', 'Museo'),
('Cueva de las Manos', 'Arte Rupestre'),
('Ruta del Vino en Luján de Cuyo', 'Enoturismo'),
('Parque Nacional El Palmar', 'Naturaleza'),
('Playa Grande y La Perla', 'Playa'),
('Cañón del Atuel', 'Aventura'),
('Parque Nacional Talampaya', 'Geología'),
('Centro Cívico de Bariloche', 'Arquitectura'),
('Valle de Las Leñas', 'Nieve'),
('Basílica Nuestra Señora de Luján', 'Religioso'),
('La Cumbrecita', 'Aldea Peatonal'),
('Parque Nacional Tierra del Fuego', 'Naturaleza'),
('Casa Histórica de la Independencia', 'Histórico'),
('Parque Nacional Lanín', 'Naturaleza'),
('Glaciar Upsala', 'Naturaleza'),
('Embalse Los Molinos', 'Náutica'),
('Termas de Cacheuta', 'Spa y Termas'),
('Cascada de los Duendes', 'Trekking'),
('Museo Histórico Nacional', 'Museo'),
('Cerro de la Gloria', 'Monumento'),
('Dunas de Fiambalá', 'Aventura'),
('Garganta del Diablo', 'Naturaleza'),
('Reserva Natural Villavicencio', 'Naturaleza'),
('Cerro Campanario', 'Mirador');


-- -----------------------------------------------------------------------------
-- 3. COMODIDADES (15 servicios hoteleros estándar)
-- -----------------------------------------------------------------------------
INSERT INTO comodidad (nombre, descripcion) VALUES
('WiFi Alta Velocidad', 'Conexión inalámbrica de fibra óptica en habitación y áreas comunes'),
('Piscina Climatizada', 'Piscina interior y exterior con control termostático'),
('Desayuno Buffet', 'Desayuno continental artesanal incluido'),
('Gimnasio', 'Sala de musculación y equipamiento aeróbico 24hs'),
('Estacionamiento Cubierto', 'Cochera privada monitoreada con seguridad permanente'),
('Aire Acondicionado', 'Climatización individual inverter frío/calor'),
('Spa y Sauna', 'Circuito hídrico, sauna seco y servicio de masajes'),
('Restaurante Gourmet', 'Servicio gastronómico internacional a la carta'),
('Bar y Coctelería', 'Coctelería de autor y cafetería especial'),
('Pet Friendly', 'Alojamiento adaptado para mascotas pequeñas'),
('Caja de Seguridad', 'Caja fuerte digital para custodia de valores'),
('Room Service', 'Servicio a la habitación las 24 horas'),
('Jacuzzi Privado', 'Bañera de hidromasaje en habitación'),
('Vista Panorámica', 'Balcón terraza con vista destacada'),
('Calefacción Central', 'Calefacción por radiadores y losa radiante');


-- -----------------------------------------------------------------------------
-- 4. HABITACIONES (10.000 habitaciones: 50 por cada uno de los 200 hoteles)
-- -----------------------------------------------------------------------------
INSERT INTO habitacion (hotel_id, numero, piso, capacidad, precio_base)
SELECT 
    (1 + ((i - 1) / 50))::INT AS hotel_id,
    -- Numeración realista: Piso * 100 + Puerta (ej. 101 a 110, 201 a 210, hasta 510)
    (((1 + (((i - 1) % 50) / 10)) * 100) + (1 + ((i - 1) % 10)))::VARCHAR AS numero,
    (1 + (((i - 1) % 50) / 10))::SMALLINT AS piso,
    (ARRAY[1, 2, 2, 2, 3, 4])[1 + (i % 6)]::SMALLINT AS capacidad,
    ROUND((50.00 + ((ARRAY[1, 2, 2, 2, 3, 4])[1 + (i % 6)] * 22.50) + ((i % 10) * 6.50))::NUMERIC, 2) AS precio_base
FROM generate_series(1, 10000) AS i;


-- -----------------------------------------------------------------------------
-- 5. HUÉSPEDES (50.000 clientes con nombres, DNI y domicilios realistas)
-- -----------------------------------------------------------------------------
WITH data_huespedes AS (
    SELECT 
        ARRAY[
            'Juan', 'María', 'Carlos', 'Ana', 'Lucas', 'Laura', 'Mateo', 'Sofía', 
            'Alejandro', 'Florencia', 'Diego', 'Camila', 'Agustín', 'Valentina', 
            'Gonzalo', 'Lucía', 'Martín', 'Julieta', 'Federico', 'Micaela', 
            'Nicolás', 'Paula', 'Joaquín', 'Daniela', 'Facundo', 'Mariana', 
            'Santiago', 'Carolina', 'Gabriel', 'Antonella'
        ] AS nombres,
        ARRAY[
            'González', 'Rodríguez', 'Gómez', 'Fernández', 'López', 'Díaz', 
            'Martínez', 'Pérez', 'García', 'Sánchez', 'Romero', 'Sosa', 
            'Álvarez', 'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Acosta', 
            'Benítez', 'Medina', 'Suárez', 'Herrera', 'Aguirre', 'Pereyra', 
            'Gutiérrez', 'Giménez', 'Molina', 'Silva', 'Castro', 'Rojas'
        ] AS apellidos,
        ARRAY[
            'Av. Rivadavia', 'Calle San Martín', 'Av. Belgrano', 'Calle Mitre', 
            'Av. Pueyrredón', 'Calle Sarmiento', 'Av. Santa Fe', 'Calle Lavalle', 
            'Calle Moreno', 'Av. Independencia', 'Calle Urquiza', 'Av. Cabildo', 
            'Calle España', 'Av. Maipú', 'Calle 9 de Julio'
        ] AS calles,
        ARRAY[
            'Argentina', 'Argentina', 'Argentina', 'Argentina', 'Brasil', 
            'Chile', 'Uruguay', 'Paraguay', 'España', 'Estados Unidos'
        ] AS nacionalidades
)
INSERT INTO huesped (dni, nombre, apellido, direccion, nacionalidad)
SELECT 
    -- DNI pseudoaleatorio de 8 dígitos (valores dispersos y realistas en rango 20M-48M garantizando unicidad estricta)
    LPAD((20000000 + ((i::BIGINT * 15485863 + 4956133) % 27999999))::TEXT, 8, '0'),
    d.nombres[1 + (i % 30)],
    d.apellidos[1 + ((i * 3) % 30)],
    d.calles[1 + (i % 15)] || ' ' || (100 + ((i * 37) % 4500)),
    d.nacionalidades[1 + (i % 10)]
FROM generate_series(1, 50000) AS i, data_huespedes d;


-- -----------------------------------------------------------------------------
-- 6. CONTACTOS (15.000 correos y teléfonos móviles con prefijos y dominios reales)
-- -----------------------------------------------------------------------------
WITH data_contactos AS (
    SELECT 
        ARRAY['juan', 'maria', 'carlos', 'ana', 'lucas', 'laura', 'mateo', 'sofia', 'diego', 'camila', 'martin', 'florencia', 'nicolas', 'valentina', 'agustin'] AS nombres,
        ARRAY['gonzalez', 'rodriguez', 'gomez', 'fernandez', 'lopez', 'diaz', 'martinez', 'perez', 'garcia', 'sanchez', 'romero', 'sosa', 'alvarez', 'torres', 'ruiz'] AS apellidos,
        ARRAY['gmail.com', 'outlook.com', 'hotmail.com', 'yahoo.com.ar', 'icloud.com'] AS dominios,
        ARRAY['+54 9 11', '+54 9 351', '+54 9 261', '+54 9 294', '+54 9 387', '+54 9 223'] AS prefijos_tel
)
INSERT INTO contacto (tipo, valor)
SELECT 
    CASE WHEN i % 2 = 0 THEN 'EMAIL' ELSE 'TELEFONO' END,
    CASE 
        WHEN i % 2 = 0 THEN 
            d.nombres[1 + (i % 15)] || '.' || d.apellidos[1 + ((i * 3) % 15)] || (10 + (i % 89))::TEXT || '@' || d.dominios[1 + (i % 5)]
        ELSE 
            d.prefijos_tel[1 + (i % 6)] || ' ' || (420 + (i % 450))::TEXT || '-' || LPAD(((i * 73) % 10000)::TEXT, 4, '0')
    END
FROM generate_series(1, 15000) AS i, data_contactos d;


-- -----------------------------------------------------------------------------
-- 7. TABLAS ASOCIATIVAS (TEAs)
-- -----------------------------------------------------------------------------

-- 7.1. Hotel - Punto de Interés (3 atractivos asignados por hotel)
INSERT INTO hotel_punto_interes (id_hotel, id_punto_interes)
SELECT DISTINCT
    h.id,
    (1 + ((h.id * 3 + j) % 50))::INT
FROM hotel h
CROSS JOIN generate_series(1, 3) AS j;

-- 7.2. Habitación - Comodidad (4 comodidades por habitación)
INSERT INTO habitacion_comodidad (id_habitacion, id_comodidad)
SELECT DISTINCT
    hab.id,
    (1 + ((hab.id * 2 + j) % 15))::INT
FROM habitacion hab
CROSS JOIN generate_series(1, 4) AS j;

-- 7.3. Hotel - Contacto (2 contactos institucionales por hotel)
INSERT INTO hotel_contacto (id_hotel, id_contacto, descripcion)
SELECT 
    i,
    i,
    CASE WHEN i % 2 = 0 THEN 'Recepción y Reservas' ELSE 'Administración Central' END
FROM generate_series(1, 200) AS i;

-- 7.4. Huésped - Contacto (1 contacto personal por cliente en los primeros 14.800)
INSERT INTO huesped_contacto (id_huesped, id_contacto, descripcion)
SELECT 
    i,
    (200 + i),
    'Contacto Personal'
FROM generate_series(1, 14800) AS i;

COMMIT;

-- Actualizar estadísticas en el catálogo
ANALYZE hotel;
ANALYZE punto_interes;
ANALYZE comodidad;
ANALYZE habitacion;
ANALYZE huesped;
ANALYZE contacto;
ANALYZE hotel_punto_interes;
ANALYZE habitacion_comodidad;
ANALYZE hotel_contacto;
ANALYZE huesped_contacto;
