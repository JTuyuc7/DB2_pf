# Arquitectura del Sistema — TecnoChapina S.A. (v2)

Actualización que implementa **fragmentación horizontal física real** y **failover transparente**.

---

## Diagrama de arquitectura

```mermaid
graph TD
    UI["🖥️  Frontend\nNext.js 15 + Tailwind\nlocalhost:3000"]

    API["⚙️  Backend — FastAPI\nPython 3.11  |  localhost:8000\nOrquesta consultas · Routing por sucursal · Failover"]

    subgraph SS ["🟣  SQL Server 2022 — Sucursal Capital"]
        direction TB
        SS_V["ventas\n(sucursal_id = 1)"]
        SS_D["detalle_ventas"]
        SS_C["clientes"]
        SS_V --- SS_D
        SS_V --- SS_C
    end

    subgraph PG ["🔵  PostgreSQL 16 — Sucursal Occidente"]
        direction TB
        PG_V["inventario.ventas\n(sucursal_id = 2)"]
        PG_D["inventario.detalle_ventas"]
        PG_P["inventario.productos"]
        PG_I["inventario.inventario"]
        PG_CAT["inventario.categorias"]
        PG_V --- PG_D
        PG_P --- PG_I
        PG_P --- PG_CAT
    end

    subgraph ORA ["🟡  Oracle XE 21c — Sede Central"]
        direction TB
        ORA_E["empleados"]
        ORA_PR["proveedores"]
        ORA_AU["auditoria"]
        ORA_BV["ventas_backup ⚡"]
        ORA_BD["detalle_ventas_backup ⚡"]
        ORA_BV --- ORA_BD
    end

    UI -->|"HTTP / JSON"| API

    API -->|"sucursal_id=1\n(escritura + lectura normal)"| SS
    API -->|"sucursal_id=2\n(escritura + lectura siempre)"| PG
    API -->|"empleados\nproveedores"| ORA

    SS -.->|"POST /backup-oracle\nsnapshot periódico"| ORA_BV

    API -.->|"failover activo\n(POST /simular-fallo)"| ORA_BV
    API -.->|"failover activo\n(POST /simular-fallo)"| ORA_BD

    style SS fill:#ede9fe,stroke:#7c3aed,color:#1e1b4b
    style PG fill:#dbeafe,stroke:#2563eb,color:#1e3a5f
    style ORA fill:#fef3c7,stroke:#d97706,color:#451a03
    style ORA_BV fill:#fed7aa,stroke:#ea580c,color:#431407
    style ORA_BD fill:#fed7aa,stroke:#ea580c,color:#431407
```

---

## Routing de escritura (POST /ventas)

```mermaid
flowchart LR
    NV["Nueva Venta\n(id, sucursal_id)"]
    PX["PostgreSQL\nObtiene precio"]
    R{sucursal_id?}
    F{Failover\nactivo?}

    NV --> PX --> R
    R -->|"= 2"| PG2["PostgreSQL\ninventario.ventas"]
    R -->|"= 1"| F
    F -->|"No"| SS2["SQL Server\ndbo.ventas"]
    F -->|"Sí"| ORA2["Oracle\nventas_backup"]
```

---

## Flujo de failover

```mermaid
sequenceDiagram
    actor Admin
    participant UI as Frontend
    participant API as FastAPI
    participant SS as SQL Server
    participant ORA as Oracle

    Admin->>UI: Clic "Backup → Oracle"
    UI->>API: POST /backup-oracle
    API->>SS: SELECT ventas (sucursal_id=1)
    SS-->>API: 10 ventas + 13 detalles
    API->>ORA: INSERT ventas_backup + detalle_ventas_backup
    ORA-->>API: OK
    API-->>UI: backup_ok: true

    Admin->>UI: Clic "Simular fallo SQL Server"
    UI->>API: POST /simular-fallo
    API-->>API: _failover_ss = True
    API-->>UI: failover_activo: true

    Note over UI,ORA: A partir de aquí, Q1-Q6 usan Oracle para Capital
    UI->>API: GET /q6
    API->>ORA: SELECT ventas_backup
    API->>PG: SELECT inventario.ventas
    ORA-->>API: ventas Capital
    PG-->>API: ventas Occidente
    API-->>UI: datos unificados (motor visible)

    Admin->>UI: Clic "Restaurar SQL Server"
    UI->>API: POST /restaurar
    API-->>API: _failover_ss = False
    API-->>UI: sistema normal
```

---

## Distribución de tablas por motor

| Motor | Puerto | Tablas | Rol en fragmentación |
|---|---|---|---|
| SQL Server 2022 | 1433 | `ventas` (id=1), `detalle_ventas`, `clientes` | Fragmento Capital + catálogo de clientes |
| PostgreSQL 16 | 5432 | `ventas` (id=2), `detalle_ventas`, `productos`, `inventario`, `categorias` | Fragmento Occidente + catálogo de productos |
| Oracle XE 21c | 1521 | `empleados`, `proveedores`, `auditoria`, `ventas_backup`, `detalle_ventas_backup` | Admin central + backup para failover |

---

## Consultas distribuidas — motores involucrados

| Endpoint | Motor A | Motor B | Motor C | Failover A |
|---|---|---|---|---|
| GET /q1 | SQL Server | PostgreSQL | — | Oracle backup |
| GET /q2 | PostgreSQL | SQL Server | — | Oracle backup |
| GET /q3 | SQL Server | PostgreSQL | — | Oracle backup |
| GET /q4 | SQL Server | PostgreSQL | Oracle | Oracle backup |
| GET /q5 | SQL Server | PostgreSQL | Oracle | Oracle backup |
| GET /q6 | SQL Server | PostgreSQL | Oracle (empleados) | Oracle backup |
| POST /ventas | SS o PG | PostgreSQL (precio) | Oracle (failover) | Oracle backup |
| POST /backup-oracle | SQL Server (lectura) | — | Oracle (escritura) | — |

---

## Diferencia con la versión anterior (v1)

| Aspecto | v1 | v2 |
|---|---|---|
| Fragmentación | Lógica (vistas en SS) | **Física** (tablas en motores distintos) |
| ventas Occidente | Vista filtrada en SQL Server | Tabla real en PostgreSQL |
| POST /ventas | Siempre a SQL Server | Routing por `sucursal_id` |
| Tolerancia a fallos | Ninguna | Failover SS → Oracle (backup) |
| Consulta Q6 | No existía | Vista unificada con columna `motor` |
