# Guía de defensa oral — TecnoChapina S.A.

> Preguntas probables del catedrático con respuestas completas.
> Estudia las respuestas pero respóndelas con tus propias palabras.

---

## Bloque 1 — Conceptos fundamentales

---

**¿Por qué usaste tres motores diferentes en lugar de uno solo?**

Porque cada motor tiene fortalezas distintas. Oracle lo usamos para los datos administrativos (empleados, proveedores) porque tiene el mejor sistema de roles, auditoría y tablespaces para datos críticos. PostgreSQL lo usamos para inventario porque maneja bien tipos de datos complejos y es el estándar en muchas empresas de logística. SQL Server lo usamos para ventas porque es el motor más común en entornos Windows corporativos y tiene excelente integración con herramientas de reportes.

En la vida real, una empresa que crece por adquisiciones termina con exactamente esta situación: tres sistemas heredados de tres áreas distintas que hay que integrar.

---

**¿Qué es una base de datos distribuida?**

Es un sistema donde los datos físicamente están en más de un nodo (servidor o proceso), pero para el usuario o la aplicación se comportan como si fueran una sola base de datos. La distribución puede ser por ubicación geográfica, por tipo de dato, o por carga de trabajo. En nuestro caso, distribuimos por dominio de negocio: administración en Oracle, inventario en PostgreSQL, ventas en SQL Server.

---

**¿Cuál es la diferencia entre fragmentación horizontal y vertical?**

- **Fragmentación horizontal:** dividir una tabla por filas. Por ejemplo, las ventas de la sucursal Capital van a un nodo y las de Occidente a otro. Cada fragmento tiene las mismas columnas pero distintas filas. Es útil cuando diferentes usuarios o regiones acceden a subconjuntos distintos de los datos.

- **Fragmentación vertical:** dividir una tabla por columnas. Por ejemplo, los datos de contacto de clientes van a un nodo y su historial de compras a otro. Cada fragmento tiene las mismas filas pero distintas columnas. Es útil cuando ciertos datos son confidenciales o se acceden con frecuencias muy distintas.

En este proyecto usamos **fragmentación horizontal**: la tabla `ventas` se divide por `sucursal_id = 1` (Capital) y `sucursal_id = 2` (Occidente), implementada con vistas en SQL Server.

---

**¿Cómo implementaste la fragmentación?**

Con vistas en SQL Server:

```sql
CREATE VIEW dbo.ventas_capital AS
  SELECT * FROM dbo.ventas WHERE sucursal_id = 1;

CREATE VIEW dbo.ventas_occidente AS
  SELECT * FROM dbo.ventas WHERE sucursal_id = 2;
```

Esto simula el escenario donde cada sucursal consultaría solo sus propias ventas. En un sistema real con SQL Server distribuido, estas vistas podrían apuntar a tablas en servidores físicamente distintos mediante Linked Servers o particionamiento nativo.

---

**¿Qué es la replicación y cómo la hiciste?**

La replicación es el proceso de copiar datos de un nodo a otro para que estén disponibles localmente. Existen varios tipos:

- **Snapshot:** se copia toda la tabla de una vez, periódicamente.
- **Transaccional:** cada cambio (INSERT, UPDATE, DELETE) se replica en tiempo real.
- **Merge:** ambos nodos pueden modificar los datos y se sincronizan periódicamente.

Nosotros implementamos **replicación snapshot** con Python: el script `backend/replicacion.py` lee la tabla `inventario.productos` de PostgreSQL y la copia completa a `productos_replica` en SQL Server. El proceso es: conectar a PostgreSQL → leer todos los registros → conectar a SQL Server → truncar la tabla réplica → insertar los registros nuevos.

---

## Bloque 2 — Operaciones sobre los datos

---

**¿Cómo agregarías un nuevo producto al sistema?**

Un producto vive en PostgreSQL (`inventario_db`). Para agregarlo:

```sql
-- Conectar a PostgreSQL y ejecutar:
INSERT INTO inventario.productos (nombre, descripcion, precio_unitario, id_categoria)
VALUES ('Galaxy S25', 'Smartphone Samsung 2025', 2499.99, 2);

-- Luego ejecutar la replicación para que SQL Server tenga la copia actualizada:
-- (desde la carpeta backend/)
python replicacion.py
```

Después de la replicación, las consultas distribuidas Q1, Q2, Q3 ya verán el nuevo producto.

---

**¿Cómo agregarías una nueva venta?**

Las ventas viven en SQL Server. Se insertan en dos tablas:

```sql
-- Conectar a SQL Server (ventas_db) y ejecutar:

-- 1. Registrar la venta principal
INSERT INTO dbo.ventas (id_cliente, id_empleado, sucursal_id, total)
VALUES (3, 2, 1, 2499.99);

-- 2. Registrar el detalle (qué producto y cuántos)
INSERT INTO dbo.detalle_ventas (id_venta, id_producto, cantidad, precio_unitario)
VALUES (SCOPE_IDENTITY(), 5, 1, 2499.99);
```

`SCOPE_IDENTITY()` devuelve el ID de la venta que se acaba de insertar.

---

**¿Cómo agregarías un nuevo empleado?**

Los empleados están en Oracle. Conectar a `XEPDB1` con el usuario `admin_central`:

```sql
INSERT INTO empleados (nombre, apellido, puesto, sede, salario, fecha_contratacion)
VALUES ('María', 'López', 'Vendedora', 'Capital', 8500.00, SYSDATE);
```

En Oracle `SYSDATE` es la función para la fecha/hora actual (equivalente a `NOW()` en PostgreSQL o `GETDATE()` en SQL Server).

---

**¿Cómo agregarías una nueva sucursal al sistema?**

Implicaría cambios en varios niveles:

1. **SQL Server:** agregar `sucursal_id = 3` en los datos de ventas y crear una nueva vista de fragmentación:
   ```sql
   CREATE VIEW dbo.ventas_norte AS
     SELECT * FROM dbo.ventas WHERE sucursal_id = 3;
   ```

2. **Oracle:** agregar los empleados de la nueva sucursal con `sede = 'Norte'`.

3. **PostgreSQL:** si la nueva sucursal maneja su propio inventario, se agregarían registros en `inventario` con el nuevo `id_sucursal`.

4. **Backend:** los endpoints de FastAPI no necesitarían cambios porque las consultas ya agregan todos los registros independientemente de la sucursal.

---

**¿Cómo harías la distribución de datos desde cero?**

El proceso completo sería:

1. **Definir los dominios de negocio:** qué datos pertenecen a qué área.
2. **Elegir el motor adecuado para cada dominio:** según el tipo de dato, frecuencia de acceso y equipo que lo administra.
3. **Diseñar el esquema en cada motor:** crear tablespaces, roles y tablas.
4. **Definir la fragmentación:** decidir si es horizontal (por filas) o vertical (por columnas) y qué campo es el criterio de corte.
5. **Definir la replicación:** qué tablas necesitan estar en más de un motor y con qué frecuencia.
6. **Crear la capa de integración:** el backend que orquesta las consultas cross-motor.
7. **Poblar los datos (seed):** insertar los datos iniciales en cada motor.
8. **Verificar la integración:** ejecutar las consultas distribuidas y confirmar que los JOINs son correctos.

---

## Bloque 3 — Decisiones de diseño

---

**¿Por qué no usaste Linked Servers o Database Links?**

Los Database Links de Oracle y los Linked Servers de SQL Server resuelven el mismo problema que nuestra capa Python, pero con más fricción para este entorno:

- Requieren configuración de red directa entre los contenedores Docker.
- Linked Servers en SQL Server necesita drivers ODBC instalados dentro del contenedor de SQL Server, no en el host.
- Database Links de Oracle requieren configurar `tnsnames.ora` con las IPs de los otros motores.

La capa Python es más portable, más fácil de depurar (los errores aparecen con stack trace completo) y suficiente para demostrar el concepto pedagógico de consultas distribuidas.

---

**¿Por qué Docker Compose y no instalar los motores directamente?**

Tres razones principales:

1. **Reproducibilidad:** cualquier persona puede levantar el entorno exacto con `docker compose up -d`, sin importar su sistema operativo.
2. **Aislamiento:** los tres motores corren en sus propios procesos sin interferirse. Si se desinstala el proyecto, se elimina el entorno completo sin rastros.
3. **Versiones fijas:** el `compose.yaml` especifica exactamente qué versión de cada motor se usa, eliminando el problema de "en mi máquina funciona".

---

**¿Qué motor usarías si solo pudieras usar uno?**

PostgreSQL. Tiene el mejor equilibrio entre funcionalidades avanzadas (tipos de datos ricos, extensiones, FDW para conectarse a otros motores) y facilidad de operación. Si necesitara conectarme a los otros motores desde PostgreSQL, usaría las extensiones `oracle_fdw` y `tds_fdw` para hacer los JOINs directamente en SQL sin capa Python.

---

## Bloque 4 — Problemas y fallas

---

**¿Qué pasa si Oracle se cae mientras ejecutas una consulta?**

Las consultas Q4 y Q5 dependen de Oracle. Si Oracle no responde:

- **Q4** fallaría completamente porque necesita Oracle para traer los nombres de empleados.
- **Q5** también fallaría por la misma razón.
- **Q1, Q2, Q3** seguirían funcionando porque solo usan PostgreSQL y SQL Server.

Para hacerlo tolerante a fallos, se podría agregar un `try/except` en el backend que devuelva los datos parciales disponibles cuando un motor falla, marcando en el JSON qué motor no respondió.

---

**¿Qué pasa si la replicación no se ha ejecutado y consultas Q1, Q2 o Q3?**

Si `productos_replica` no existe o está vacía en SQL Server, las consultas que la usan devolverán resultados incompletos (sin nombre de producto) o un error de tabla inexistente.

La solución correcta sería ejecutar `python replicacion.py` antes de levantar el backend, o agregar un endpoint `/replicar` en FastAPI que ejecute la replicación bajo demanda.

---

**¿Cómo sabes que los datos en la réplica están actualizados?**

No hay garantía automática. La réplica refleja el estado de `productos` en el momento en que se ejecutó `replicacion.py` por última vez. Si se agrega un producto nuevo en PostgreSQL y no se re-ejecuta el script, la réplica estará desactualizada.

En producción, esto se resuelve con:
- Un job programado (cron o Windows Task Scheduler) que ejecute la replicación cada X minutos.
- Replicación transaccional nativa del motor (más compleja pero en tiempo real).

---

**¿Cuál fue el problema técnico más difícil que encontraste?**

El error de `ODBC Driver 18 not found`. El script `replicacion.py` estaba configurado para usar ODBC Driver 18, pero la máquina solo tenía instalado el Driver 17. El error `pyodbc.InterfaceError IM002` no es muy descriptivo. La solución fue ejecutar `Get-OdbcDriver` en PowerShell para ver qué drivers estaban realmente instalados y actualizar el string de conexión. Aprendizaje: siempre verificar el entorno antes de asumir qué software está instalado.

---

## Bloque 5 — Mejoras y extensiones

---

**¿Qué mejorarías si tuvieras más tiempo?**

1. **Replicación automática:** agregar un scheduler en el backend que ejecute la replicación cada 5 minutos en segundo plano.
2. **Manejo de errores por motor:** si un motor falla, devolver los datos parciales disponibles en lugar de un error completo.
3. **Caché en el backend:** almacenar los resultados de consultas pesadas por 30 segundos para no golpear los tres motores en cada request.
4. **Autenticación en la API:** agregar un token JWT para que solo la UI pueda llamar los endpoints.
5. **Migrar a FDW:** usar `oracle_fdw` y `tds_fdw` en PostgreSQL para hacer los JOINs en SQL puro, eliminando la capa Python de orquestación.

---

**¿Cómo escalarías este sistema para manejar más sucursales?**

La arquitectura actual escala horizontalmente en SQL Server: agregar `sucursal_id = 4, 5, 6...` y crear las vistas correspondientes. El backend FastAPI no necesitaría cambios.

Para escalar a nivel de motor, se podría:
- Agregar más nodos de PostgreSQL con replicación primaria-réplica para el inventario.
- Usar SQL Server Always On Availability Groups para las ventas.
- Mantener Oracle como nodo central único (es el más costoso de escalar).

---

## Hoja de referencia rápida — comandos para la demo

```powershell
# Levantar toda la infraestructura
docker compose up -d

# Ver estado de los contenedores
docker compose ps

# Ejecutar la replicación
cd backend
python replicacion.py

# Levantar el backend
uvicorn main:app --reload --port 8000

# Levantar el frontend (en otra terminal)
cd ../frontend
pnpm dev
```

**URLs importantes:**
- UI: `http://localhost:3000`
- API docs (Swagger): `http://localhost:8000/docs`
- Q5 directa: `http://localhost:8000/q5`
