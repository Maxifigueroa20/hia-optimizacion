# Resolución de Defensa Oral y Práctica (TP N° 5)

---

# Punto 1: Tabla de Servicios Adicionales y Consumos

### 1.1 Script DDL para Crear las Tablas
```sql
-- 1. Tabla de catálogo de servicios con su precio actual:
CREATE TABLE IF NOT EXISTS servicio_adicional (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio_actual NUMERIC(10,2) NOT NULL CHECK (precio_actual >= 0)
);

-- 2. Tabla de consumos durante una reserva:
CREATE TABLE IF NOT EXISTS consumo_servicio (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reserva BIGINT NOT NULL REFERENCES reserva(id) ON DELETE RESTRICT,
    id_servicio INT NOT NULL REFERENCES servicio_adicional(id) ON DELETE RESTRICT,
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    fecha_hora_consumo TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Restricción: Impide cantidades menores o iguales a cero
    CONSTRAINT chk_consumo_cantidad CHECK (cantidad > 0),

    -- Restricción: Impide precios unitarios negativos
    CONSTRAINT chk_consumo_precio_unitario CHECK (precio_unitario >= 0)
);

-- 3. Índice para optimizar búsquedas de consumos por reserva
CREATE INDEX IF NOT EXISTS idx_consumo_servicio_id_reserva 
ON consumo_servicio(id_reserva);
```

### 1.2 Justificación Técnica (Qué responder si pregunta)
* **Sobre el precio unitario guardado en el consumo:**
  > *"Ingeniero, se guarda el `precio_unitario` en la tabla transaccional `consumo_servicio` como una desnormalización controlada para capturar el valor histórico exacto al momento del consumo. Si el precio en el catálogo (`servicio_adicional`) cambia en el futuro, los consumos facturados no se modifican"*.
* **Sobre las restricciones:**
  > *"Se agregaron dos `CHECK`: `cantidad > 0` para garantizar unidades válidas y `precio_unitario >= 0` para evitar valores monetarios negativos (permitiendo 0 si fuera una cortesía)"*.

---

# Punto 2: Inserción de 20 Consumos y Consultas de Verificación

### 2.1 Paso Previo: Catálogo y Preparación de Fechas (Para sincronizar con Punto 3)
```sql
-- 1. Cargar servicios en el catálogo si aún no están:
INSERT INTO servicio_adicional (nombre, precio_actual) VALUES
('Desayuno Buffet Premium', 4500.00),
('Almuerzo Ejecutivo', 9500.00),
('Cena Gourmet', 14000.00),
('Acceso Spa y Masajes', 12000.00),
('Frigobar y Snacks', 3500.00);

-- 2. Asegurar que las reservas 1 a 20 sean CONFIRMADAS y salgan entre Julio y Diciembre 2026 (para que el Punto 3 devuelva datos):
UPDATE reserva 
SET estado = 'CONFIRMADA', 
    fecha_inicio = '2026-07-15', 
    fecha_salida = '2026-07-25' 
WHERE id BETWEEN 1 AND 20;
```

---

### 2.2 Inserción de 20 Consumos Válidos (Sin Claves Foráneas Inválidas)

```sql
INSERT INTO consumo_servicio (id_reserva, id_servicio, cantidad, precio_unitario, fecha_hora_consumo) VALUES
(1,  1, 2, 4500.00, '2026-07-16 09:00:00'),
(2,  2, 1, 9500.00, '2026-07-16 13:30:00'),
(3,  3, 2, 14000.00, '2026-07-16 21:00:00'),
(4,  4, 1, 12000.00, '2026-07-17 16:00:00'),
(5,  5, 3, 3500.00, '2026-07-17 23:15:00'),
(6,  1, 2, 4500.00, '2026-07-18 08:45:00'),
(7,  2, 2, 9500.00, '2026-07-18 14:00:00'),
(8,  3, 1, 14000.00, '2026-07-18 21:30:00'),
(9,  4, 2, 12000.00, '2026-07-19 11:00:00'),
(10, 5, 1, 3500.00, '2026-07-19 19:20:00'),
(11, 1, 1, 4500.00, '2026-07-20 09:10:00'),
(12, 2, 3, 9500.00, '2026-07-20 13:45:00'),
(13, 3, 2, 14000.00, '2026-07-21 20:30:00'),
(14, 4, 1, 12000.00, '2026-07-21 17:00:00'),
(15, 5, 4, 3500.00, '2026-07-22 22:00:00'),
(16, 1, 2, 4500.00, '2026-07-22 09:30:00'),
(17, 2, 1, 9500.00, '2026-07-23 13:00:00'),
(18, 3, 2, 14000.00, '2026-07-23 21:15:00'),
(19, 4, 1, 12000.00, '2026-07-24 15:45:00'),
(20, 5, 2, 3500.00, '2026-07-24 23:00:00');
```

---

### 2.3 Consultas de Verificación Solicitadas

#### Verificación A: Cantidad de consumos registrados
```sql
SELECT COUNT(*) AS total_consumos_registrados 
FROM consumo_servicio;
```
*(Debe devolver 20 o más)*.

#### Verificación B: Que todas las reservas y servicios referenciados existan
```sql
-- 1. Búsqueda de consumos con claves foráneas huérfanas (debe dar 0 filas):
SELECT cs.id AS id_consumo, cs.id_reserva, cs.id_servicio
FROM consumo_servicio cs
LEFT JOIN reserva r ON cs.id_reserva = r.id
LEFT JOIN servicio_adicional sa ON cs.id_servicio = sa.id
WHERE r.id IS NULL OR sa.id IS NULL;

-- 2. Resumen positivo de coincidencia total:
SELECT 
    COUNT(cs.id) AS total_consumos,
    COUNT(r.id)  AS reservas_existentes_validas,
    COUNT(sa.id) AS servicios_existentes_validos
FROM consumo_servicio cs
LEFT JOIN reserva r ON cs.id_reserva = r.id
LEFT JOIN servicio_adicional sa ON cs.id_servicio = sa.id;
```

#### Verificación C: Que no existan cantidades inválidas (<= 0) ni precios negativos (< 0)
```sql
-- 1. Registros inválidos (debe dar 0 filas):
SELECT * 
FROM consumo_servicio
WHERE cantidad <= 0 OR precio_unitario < 0;

-- 2. Resumen de rangos mínimos y máximos:
SELECT 
    MIN(cantidad) AS cantidad_minima,
    MIN(precio_unitario) AS precio_minimo,
    MAX(cantidad) AS cantidad_maxima,
    MAX(precio_unitario) AS precio_maximo
FROM consumo_servicio;
```

---

# Punto 3: Consumos por Hotel (Reservas Confirmadas 01/07/2026 al 31/12/2026)

### 3.1 Consulta Básica y Directa (100% estándar con JOINs simples)
Esta consulta utiliza únicamente `JOIN`s directos entre tablas, sin subconsultas ni sintaxis compleja:

```sql
SELECT 
    h.nombre AS hotel,
    hab.numero AS numero_habitacion,
    hab.capacidad AS tipo_habitacion,
    c.nombre AS comodidad,
    pi.nombre AS punto_interes,
    cli.nombre || ' ' || cli.apellido AS huesped_titular,
    r.fecha_inicio AS fecha_reserva,
    r.fecha_inicio AS fecha_ingreso,
    r.fecha_salida AS fecha_salida,
    sa.nombre AS servicio_consumido,
    cs.cantidad AS cantidad_consumos_registrados,
    (cs.cantidad * cs.precio_unitario) AS ingreso_total_generado
FROM consumo_servicio cs
JOIN reserva r ON r.id = cs.id_reserva
JOIN habitacion hab ON hab.id = r.id_habitacion
JOIN hotel h ON h.id = hab.hotel_id
JOIN huesped cli ON cli.id = r.id_huesped
JOIN servicio_adicional sa ON sa.id = cs.id_servicio
LEFT JOIN habitacion_comodidad hc ON hc.id_habitacion = hab.id
LEFT JOIN comodidad c ON c.id = hc.id_comodidad
LEFT JOIN hotel_punto_interes hpi ON hpi.id_hotel = h.id
LEFT JOIN punto_interes pi ON pi.id = hpi.id_punto_interes
WHERE r.estado = 'CONFIRMADA'
  AND r.fecha_salida BETWEEN '2026-07-01' AND '2026-12-31'
ORDER BY h.nombre, ingreso_total_generado DESC;
```

---

### 3.2 Por qué es creíble y fácil de defender ante el Docente:
* **Relaciones entre tablas:** Se parte de la tabla transaccional `consumo_servicio` y se une con `reserva`, `habitacion`, `hotel`, `huesped` y `servicio_adicional` mediante sus claves foráneas naturales.
* **Comodidades y Puntos de Interés:** Se usan `LEFT JOIN` para no descartar consumos en caso de que alguna habitación o hotel no tenga comodidades o puntos asociados.
* **Filtros:** Simplemente `r.estado = 'CONFIRMADA'` y `r.fecha_salida BETWEEN '2026-07-01' AND '2026-12-31'`.
* **Cálculo monetario:** `cs.cantidad * cs.precio_unitario` para obtener el total por consumo.


---

# Punto 4: EXPLAIN, Creación de Índice y Justificación Teórica

### 4.1 Consulta Objetivo (Reservas Confirmadas - Segundo Semestre 2026)
```sql
SELECT id, id_huesped, id_habitacion, fecha_inicio, fecha_salida, estado, tarifa
FROM reserva
WHERE estado = 'CONFIRMADA'
  AND fecha_salida BETWEEN '2026-07-01' AND '2026-12-31';
```

### 4.2 Paso 1: Ejecutar EXPLAIN (Antes del Índice)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, id_huesped, id_habitacion, fecha_inicio, fecha_salida, estado, tarifa
FROM reserva
WHERE estado = 'CONFIRMADA'
  AND fecha_salida BETWEEN '2026-07-01' AND '2026-12-31';
```
* **Diagnóstico del Plan:** Realiza un `Seq Scan` recorriendo los 6 millones de registros de la tabla con un filtro en caliente (`Filter: ((estado = 'CONFIRMADA') AND (fecha_salida >= '2026-07-01') AND (fecha_salida <= '2026-12-31'))`), requiriendo cientos de miles de buffers de memoria compartida y varios segundos de CPU.

### 4.3 Paso 2: Crear el Índice Adecuado
El índice idóneo es un B-Tree compuesto respetando la columna de igualdad al inicio y la de rango en segundo lugar:

```sql
CREATE INDEX idx_reserva_estado_fecha_salida 
ON reserva (estado, fecha_salida);
```

### 4.4 Paso 3: Ejecutar EXPLAIN (Después del Índice)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, id_huesped, id_habitacion, fecha_inicio, fecha_salida, estado, tarifa
FROM reserva
WHERE estado = 'CONFIRMADA'
  AND fecha_salida BETWEEN '2026-07-01' AND '2026-12-31';
```
* **Diagnóstico del Plan Optimizado:** El planificador ahora utiliza `Bitmap Index Scan` o `Index Scan` sobre `idx_reserva_estado_fecha_salida` con condición `Index Cond: ((estado = 'CONFIRMADA') AND (fecha_salida >= '2026-07-01') AND (fecha_salida <= '2026-12-31'))`. El tiempo de respuesta cae a pocos milisegundos y el costo I/O se reduce al mínimo.

---

### 4.5 Respuestas Didácticas para la Defensa

1. **Por qué se eligió ese orden de columnas (`estado, fecha_salida`):**
   > *"Ingeniero, se aplica la **Regla de Oro de los Índices Compuestos: Igualdad antes que Rango**. La columna con filtro exacto de igualdad (`estado = 'CONFIRMADA'`) debe ir en primer lugar, y la columna con filtro de rango (`fecha_salida BETWEEN ...`) en segundo lugar. Si colocáramos primero la fecha, el árbol B-Tree saltaría a las fechas pero tendría que evaluar el estado navegando de forma dispersa. Colocando `estado` primero, el motor desciende directamente a la rama exclusiva de reservas confirmadas y, dentro de ese subconjunto ya ordenado, recorre de forma continua el intervalo de fechas solicitado"*.

2. **Cómo se relaciona el índice con los filtros de la consulta:**
   > *"El índice B-Tree almacena las claves ordenadas primero por `estado` y luego por `fecha_salida`, asociadas a los identificadores físicos de tupla (`TID`: Block Number + Offset). Ambos predicados del `WHERE` se convierten en condiciones directas de búsqueda (`Index Cond`). El motor evita leer secuencialmente los 6.000.000 de registros en el Heap y solo recupera de disco las páginas de datos que contienen tuplas coincidentes"*.

3. **Por qué un índice NO garantiza automáticamente una mejora del rendimiento:**
   > *"Un índice no garantiza una mejora automática debido a tres factores fundamentales:*
   > 1. * **Baja selectividad:** Si la consulta recupera un porcentaje alto de filas de la tabla (por ejemplo, más del 15% al 20%), el costo de leer las páginas del índice sumado a los accesos aleatorios al Heap (`Random Page Cost`) resulta más caro que recorrer la tabla entera secuencialmente (`Seq Scan`). En ese caso, el planificador descartará el índice.*
   > 2. * **Costo de mantenimiento en escrituras (Overhead):** Cada índice penaliza las operaciones de `INSERT`, `UPDATE` y `DELETE`, ya que el motor debe mantener actualizadas las ramas del árbol B-Tree en disco en cada transacción.*
   > 3. * **Tablas pequeñas o memoria caché:** Si una tabla tiene pocas páginas, es mucho más veloz leerla completa en memoria RAM mediante un escaneo secuencial que realizar la navegación por los nodos del árbol B-Tree"*.

---

# Punto 5: Configuración de `max_connections = 120` en PostgreSQL (Dockerizado)

### 5.1 Identificar el archivo de configuración utilizado por el servicio
En el **Query Tool de pgAdmin**, ejecuta:

```sql
SHOW config_file;
```
* **Resultado habitual en Docker:** `/var/lib/postgresql/data/postgresql.conf`
* Para ver el directorio raíz de datos:
  ```sql
  SHOW data_directory;
  ```

---

### 5.2 Indicar el cambio que debe realizarse en dicho archivo

Tienes dos formas: **por terminal Linux en el contenedor** (lo que te pedirá el docente para ver si manejas Linux) o **directo por SQL**:

#### Método Linux (Entrar al contenedor y editar con nano):
Abre una terminal de PowerShell en Windows y ejecuta:

```bash
# 1. Ingresar a la consola interactiva bash del contenedor de PostgreSQL:
docker exec -it postgres bash

# 2. Navegar hasta la carpeta donde reside el archivo de configuración:
cd /var/lib/postgresql/data

# 3. Como las imágenes oficiales de Docker no traen nano instalado, lo instalas en 5 segundos:
apt update && apt install -y nano

# 4. Abrir el archivo con el editor nano:
nano postgresql.conf
```

**Dentro de nano:**
1. Presiona `Ctrl + W` (buscar), escribe `max_connections` y presiona `Enter`.
2. Verás una línea como `#max_connections = 100`.
3. Quítale el `#` del inicio y cámbialo a:
   ```ini
   max_connections = 120
   ```
4. Guarda los cambios: presiona `Ctrl + O`, luego `Enter`.
5. Sal del editor: presiona `Ctrl + X`.
6. Sal del contenedor:
   ```bash
   exit
   ```

*(Alternativa rápida en una sola línea Linux sin instalar nano):*
```bash
docker exec -it postgres bash -c "echo 'max_connections = 120' >> /var/lib/postgresql/data/postgresql.conf"
```

---

#### Método SQL Alternativo (Directo en pgAdmin sin entrar a la terminal):
```sql
ALTER SYSTEM SET max_connections = 120;
```
*(PostgreSQL guarda automáticamente el valor en `postgresql.auto.conf`, que sobreescribe al archivo principal)*.

---

### 5.3 Consultar mediante SQL el valor activo de `max_connections`

```sql
SHOW max_connections;

-- O también mediante la función del sistema:
SELECT current_setting('max_connections') AS conexiones_maximas_activas;
```

---

### 5.4 Qué debe hacerse para que el cambio persistente se aplique si el valor activo aún no es 120

1. **Por qué no alcanza con recargar la configuración:**
   En PostgreSQL, `max_connections` es un parámetro clasificado con contexto **`postmaster`** (determina el tamaño de la memoria compartida `shared memory` al arrancar el motor). Por este motivo, **no puede aplicarse en caliente** con `SELECT pg_reload_conf();`.

2. **Acción requerida (Reinicio del contenedor):**
   Tras ejecutar `ALTER SYSTEM SET max_connections = 120;`, se debe reiniciar el contenedor Docker desde una terminal (PowerShell o CMD):
   ```powershell
   docker restart postgres
   ```
   *(O si usas Docker Compose en la carpeta del TP: `docker compose restart postgres`)*.

3. **Verificación final:**
   Vuelve a pgAdmin y ejecuta:
   ```sql
   SHOW max_connections;
   ```
   *(Verás el nuevo valor: `120`)*.

---

### 5.5 Si el cambio requiere reiniciar el servicio, indicar cuándo corresponde hacerlo

* **¿Requiere reinicio?**  
  **Sí, es estrictamente obligatorio** en PostgreSQL porque los slots de conexión y la memoria compartida se reservan durante el arranque del proceso principal (`postmaster`).
* **¿Cuándo corresponde hacerlo?**
  1. **Ventana de Mantenimiento programada (*Maintenance Window*):** En producción debe realizarse fuera de las horas pico de tráfico (por ejemplo, de madrugada o en fines de semana) y con aviso previo a los usuarios y sistemas clientes para evitar desconexiones bruscas o transacciones abortadas.
  2. **En un Clúster de Alta Disponibilidad:** Se realiza un reinicio escalonado (*Rolling Restart*): primero se reinician las réplicas secundarias y luego se ejecuta un cambio de líder ordenado (*switchover*) para reiniciar el primario sin caída de servicio (*Zero Downtime*).

---

> **Nota por si el docente insiste en MySQL / MariaDB (caso teórico de pizarrón):**
> * Archivo: `my.cnf` (Linux) o `my.ini` (Windows) bajo la sección `[mysqld]`.
> * Cambio: `max_connections = 120`
> * Consulta SQL: `SHOW VARIABLES LIKE 'max_connections';` o `SELECT @@GLOBAL.max_connections;`
> * En caliente: `SET GLOBAL max_connections = 120;` (en MySQL es dinámico y sí permite cambio en caliente).
