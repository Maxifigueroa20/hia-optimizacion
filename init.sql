-- =============================================================================
-- TRABAJO PRÁCTICO N° 5: DISEÑO Y OPTIMIZACIÓN DE BASES DE DATOS
-- Script DDL de Implementación Física (PostgreSQL 16)
-- Cátedra: Bases de Datos Avanzadas / APU - Facultad de Ingeniería
-- =============================================================================

-- 1. Extensión para operadores de rango e índices GiST sobre tipos escalares (INT)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. Limpieza previa en orden inverso de dependencias
DROP TABLE IF EXISTS reserva CASCADE;
DROP TABLE IF EXISTS huesped_contacto CASCADE;
DROP TABLE IF EXISTS hotel_contacto CASCADE;
DROP TABLE IF EXISTS habitacion_comodidad CASCADE;
DROP TABLE IF EXISTS hotel_punto_interes CASCADE;
DROP TABLE IF EXISTS habitacion CASCADE;
DROP TABLE IF EXISTS huesped CASCADE;
DROP TABLE IF EXISTS contacto CASCADE;
DROP TABLE IF EXISTS comodidad CASCADE;
DROP TABLE IF EXISTS punto_interes CASCADE;
DROP TABLE IF EXISTS hotel CASCADE;

-- =============================================================================
-- MÓDULO 1: ENTIDADES BASE
-- =============================================================================

CREATE TABLE hotel (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    valoracion SMALLINT NOT NULL CHECK (valoracion BETWEEN 1 AND 5),
    direccion VARCHAR(150) NOT NULL,
    ciudad VARCHAR(80) NOT NULL,
    provincia VARCHAR(80) NOT NULL,
    pais VARCHAR(80) NOT NULL
);

CREATE TABLE punto_interes (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    categoria VARCHAR(50) NOT NULL
);

CREATE TABLE comodidad (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

CREATE TABLE habitacion (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hotel_id INT NOT NULL REFERENCES hotel(id) ON DELETE RESTRICT,
    numero VARCHAR(10) NOT NULL,
    piso SMALLINT NOT NULL,
    capacidad SMALLINT NOT NULL CHECK (capacidad >= 1),
    precio_base NUMERIC(10,2) NOT NULL CHECK (precio_base > 0),
    CONSTRAINT uq_habitacion_hotel_numero UNIQUE (hotel_id, numero)
);

CREATE TABLE huesped (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dni VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    direccion VARCHAR(150) NOT NULL,
    nacionalidad VARCHAR(50) NOT NULL
);

CREATE TABLE contacto (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('TELEFONO', 'EMAIL')),
    valor VARCHAR(120) NOT NULL
);

-- =============================================================================
-- MÓDULO 2: TABLAS DE ENTIDAD ASOCIATIVA (TEAs / N:M)
-- =============================================================================

CREATE TABLE hotel_punto_interes (
    id_hotel INT NOT NULL REFERENCES hotel(id) ON DELETE RESTRICT,
    id_punto_interes INT NOT NULL REFERENCES punto_interes(id) ON DELETE RESTRICT,
    PRIMARY KEY (id_hotel, id_punto_interes)
);

CREATE TABLE habitacion_comodidad (
    id_habitacion INT NOT NULL REFERENCES habitacion(id) ON DELETE RESTRICT,
    id_comodidad INT NOT NULL REFERENCES comodidad(id) ON DELETE RESTRICT,
    PRIMARY KEY (id_habitacion, id_comodidad)
);

CREATE TABLE hotel_contacto (
    id_hotel INT NOT NULL REFERENCES hotel(id) ON DELETE RESTRICT,
    id_contacto BIGINT NOT NULL REFERENCES contacto(id) ON DELETE RESTRICT,
    descripcion VARCHAR(100),
    PRIMARY KEY (id_hotel, id_contacto)
);

CREATE TABLE huesped_contacto (
    id_huesped BIGINT NOT NULL REFERENCES huesped(id) ON DELETE RESTRICT,
    id_contacto BIGINT NOT NULL REFERENCES contacto(id) ON DELETE RESTRICT,
    descripcion VARCHAR(100),
    PRIMARY KEY (id_huesped, id_contacto)
);

-- =============================================================================
-- MÓDULO 3: TABLA TRANSACCIONAL PRINCIPAL
-- =============================================================================

CREATE TABLE reserva (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_huesped BIGINT NOT NULL REFERENCES huesped(id) ON DELETE RESTRICT,
    id_habitacion INT NOT NULL REFERENCES habitacion(id) ON DELETE RESTRICT,
    fecha_inicio DATE NOT NULL,
    fecha_salida DATE NOT NULL,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('PENDIENTE', 'CONFIRMADA', 'CANCELADA', 'FINALIZADA')),
    tarifa NUMERIC(10,2) CHECK (tarifa IS NULL OR tarifa > 0),
    
    -- Restricción 1: Coherencia temporal del período
    CONSTRAINT chk_reserva_fechas CHECK (fecha_salida > fecha_inicio),
    
    -- Restricción 2: Tarifa obligatoria únicamente cuando la reserva es confirmada
    CONSTRAINT chk_reserva_tarifa_confirmada CHECK (
        (estado = 'CONFIRMADA' AND tarifa IS NOT NULL) OR (estado != 'CONFIRMADA')
    ),
    
    -- Restricción 3: No superposición de reservas para una misma habitación (límites inclusivos '[]')
    CONSTRAINT no_superposicion_fechas_habitacion EXCLUDE USING gist (
        id_habitacion WITH =,
        daterange(fecha_inicio, fecha_salida, '[]') WITH &&
    ) WHERE (estado != 'CANCELADA')
);
