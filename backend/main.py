"""
main.py — Backend FastAPI para TecnoChapina S.A.

Fragmentación física real:
  sucursal_id=1 (Capital)   → SQL Server  (failover: Oracle backup)
  sucursal_id=2 (Occidente) → PostgreSQL  (siempre disponible)

Endpoints de consulta distribuida: /q1 – /q6
Endpoints de failover: /backup-oracle, /simular-fallo, /restaurar, /estado-sistema
Endpoints de operación: /catalogos, POST /ventas

Uso:
    cd backend
    uvicorn main:app --reload --port 8000
    Docs: http://localhost:8000/docs
"""

import os
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import oracledb
import psycopg
import pyodbc

load_dotenv()

app = FastAPI(
    title="TecnoChapina API",
    description="Mini plataforma de ventas distribuida — BD2 UMG",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────────────────
# Estado global de failover
# True = SQL Server "caído"; ventas Capital → Oracle backup
# ──────────────────────────────────────────────────────────

_failover_ss: bool = False


# ──────────────────────────────────────────────────────────
# Helpers de conexión
# ──────────────────────────────────────────────────────────

def get_oracle():
    return oracledb.connect(
        host=os.getenv("ORA_HOST", "localhost"),
        port=int(os.getenv("ORA_PORT", "1521")),
        service_name=os.getenv("ORA_SERVICE", "XEPDB1"),
        user=os.getenv("ORA_USER", "admin_central"),
        password=os.getenv("ORA_PASSWORD", "AdminPass123"),
    )


def get_postgres():
    return psycopg.connect(
        host=os.getenv("PG_HOST", "localhost"),
        port=int(os.getenv("PG_PORT", "5432")),
        dbname=os.getenv("PG_DB", "inventario_db"),
        user=os.getenv("PG_USER", "admin_inventario"),
        password=os.getenv("PG_PASSWORD", "PostgresPass123"),
    )


def get_sqlserver():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={os.getenv('SS_HOST', 'localhost')},{os.getenv('SS_PORT', '1433')};"
        f"DATABASE={os.getenv('SS_DB', 'ventas_db')};"
        f"UID={os.getenv('SS_USER', 'sa')};"
        f"PWD={os.getenv('SS_PASSWORD', 'SqlServerPass123!')};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


# ──────────────────────────────────────────────────────────
# Raíz
# ──────────────────────────────────────────────────────────

@app.get("/")
def raiz():
    return {
        "sistema": "TecnoChapina S.A.",
        "fragmentacion": {
            "Capital (sucursal_id=1)":   "SQL Server 2022  (failover: Oracle XE)",
            "Occidente (sucursal_id=2)": "PostgreSQL 16",
        },
        "consultas_disponibles": {
            "/q1": "Ventas por sucursal con nombre de producto  [SS/Oracle + PG]",
            "/q2": "Inventario actual vs unidades vendidas       [PG + SS/Oracle]",
            "/q3": "Top productos más vendidos                   [SS/Oracle + PG]",
            "/q4": "Desempeño de empleados en ventas             [SS/Oracle + PG + Oracle]",
            "/q5": "Reporte integrado — últimas 10 ventas        [SS/Oracle + PG + Oracle]",
            "/q6": "Todas las ventas unificadas — fragmentos físicos [SS/Oracle + PG]",
        },
        "failover": {
            "/estado-sistema":  "GET  — estado actual de los motores",
            "/backup-oracle":   "POST — copia SS→Oracle (ejecutar antes de simular fallo)",
            "/simular-fallo":   "POST — marca SQL Server como caído",
            "/restaurar":       "POST — restaura SQL Server como motor activo",
        },
    }


# ──────────────────────────────────────────────────────────
# FAILOVER — Estado y control
# ──────────────────────────────────────────────────────────

@app.get("/estado-sistema")
def estado_sistema():
    return {
        "failover_activo":          _failover_ss,
        "motor_ventas_capital":     "Oracle XE (backup)" if _failover_ss else "SQL Server 2022",
        "motor_ventas_occidente":   "PostgreSQL 16",
        "motor_admin_empleados":    "Oracle XE",
        "motor_inventario":         "PostgreSQL 16",
        "motor_clientes":           "N/A (failover activo)" if _failover_ss else "SQL Server 2022",
        "mensaje": (
            "FAILOVER ACTIVO — SQL Server simulado como caído. Oracle absorbe Capital."
            if _failover_ss else
            "Sistema normal — todos los motores operando."
        ),
    }


@app.post("/simular-fallo")
def simular_fallo():
    global _failover_ss
    _failover_ss = True
    return {
        "ok": True,
        "failover_activo": True,
        "mensaje": "SQL Server marcado como CAÍDO. Capital redirigida a Oracle (backup).",
    }


@app.post("/restaurar")
def restaurar():
    global _failover_ss
    _failover_ss = False
    return {
        "ok": True,
        "failover_activo": False,
        "mensaje": "SQL Server restaurado. Sistema operando con motores originales.",
    }


@app.post("/backup-oracle")
def backup_oracle():
    """
    Copia ventas+detalle_ventas de SQL Server (sucursal_id=1) a Oracle (tablas de backup).
    Idempotente: borra el backup anterior antes de copiar.
    Ejecutar ANTES de /simular-fallo para que el backup esté disponible.
    """
    try:
        ss = get_sqlserver()
        cur_ss = ss.cursor()

        cur_ss.execute(
            "SELECT id_venta, id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado "
            "FROM ventas WHERE sucursal_id = 1"
        )
        ventas = cur_ss.fetchall()

        if not ventas:
            ss.close()
            return {"ok": False, "mensaje": "No hay ventas en SQL Server para respaldar."}

        venta_ids = [v[0] for v in ventas]
        id_list   = ",".join(str(i) for i in venta_ids)

        cur_ss.execute(
            f"SELECT id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal "
            f"FROM detalle_ventas WHERE id_venta IN ({id_list})"
        )
        detalles = cur_ss.fetchall()
        ss.close()

        ora = get_oracle()
        cur_ora = ora.cursor()

        cur_ora.execute("DELETE FROM detalle_ventas_backup")
        cur_ora.execute("DELETE FROM ventas_backup")

        for v in ventas:
            cur_ora.execute(
                "INSERT INTO ventas_backup "
                "(id_venta, id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado, backup_ts) "
                "VALUES (:1, :2, :3, :4, :5, :6, :7, SYSTIMESTAMP)",
                [v[0], v[1], v[2], v[3], float(v[4]), v[5], v[6]],
            )

        for d in detalles:
            cur_ora.execute(
                "INSERT INTO detalle_ventas_backup "
                "(id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal) "
                "VALUES (:1, :2, :3, :4, :5, :6)",
                [d[0], d[1], d[2], d[3], float(d[4]), float(d[5])],
            )

        ora.commit()
        ora.close()

        return {
            "ok": True,
            "mensaje": f"Backup completado en Oracle: {len(ventas)} ventas, {len(detalles)} detalles.",
            "ventas_respaldadas":  len(ventas),
            "detalles_respaldados": len(detalles),
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q1 — Ventas por sucursal con nombre de producto
# Capital:   SQL Server  (o Oracle backup en failover)
# Occidente: PostgreSQL  (siempre)
# Catálogo:  PostgreSQL
# ──────────────────────────────────────────────────────────

@app.get("/q1")
def ventas_por_sucursal():
    try:
        # Motor Capital
        if not _failover_ss:
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute("""
                SELECT dv.id_producto, SUM(dv.cantidad) AS unidades, SUM(dv.subtotal) AS ingresos
                FROM detalle_ventas dv
                JOIN ventas v ON dv.id_venta = v.id_venta
                WHERE v.sucursal_id = 1
                GROUP BY dv.id_producto
            """)
            cap = {r[0]: {"unidades_vendidas": r[1], "ingresos": float(r[2])} for r in cur.fetchall()}
            ss.close()
        else:
            ora = get_oracle()
            cur = ora.cursor()
            cur.execute("""
                SELECT dv.id_producto, SUM(dv.cantidad) AS unidades, SUM(dv.subtotal) AS ingresos
                FROM detalle_ventas_backup dv
                JOIN ventas_backup v ON dv.id_venta = v.id_venta
                WHERE v.sucursal_id = 1
                GROUP BY dv.id_producto
            """)
            cap = {r[0]: {"unidades_vendidas": r[1], "ingresos": float(r[2])} for r in cur.fetchall()}
            ora.close()

        # Motor Occidente + catálogo productos
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT dv.id_producto, SUM(dv.cantidad) AS unidades, SUM(dv.subtotal) AS ingresos
                FROM inventario.detalle_ventas dv
                JOIN inventario.ventas v ON dv.id_venta = v.id_venta
                WHERE v.sucursal_id = 2
                GROUP BY dv.id_producto
            """)
            occ = {r[0]: {"unidades_vendidas": r[1], "ingresos": float(r[2])} for r in c.fetchall()}

            c.execute("SELECT id_producto, nombre, precio_unitario FROM inventario.productos")
            productos = {r[0]: {"nombre": r[1], "precio_unitario": float(r[2])} for r in c.fetchall()}
        pg.close()

        # Merge por sucursal
        filas = []
        for id_p, datos in cap.items():
            p = productos.get(id_p, {})
            filas.append({
                "id_producto": id_p, "sucursal_id": 1, "sucursal": "Capital",
                "producto": p.get("nombre", "—"), "precio_unitario": p.get("precio_unitario", 0),
                **datos,
            })
        for id_p, datos in occ.items():
            p = productos.get(id_p, {})
            filas.append({
                "id_producto": id_p, "sucursal_id": 2, "sucursal": "Occidente",
                "producto": p.get("nombre", "—"), "precio_unitario": p.get("precio_unitario", 0),
                **datos,
            })

        filas.sort(key=lambda x: x["ingresos"], reverse=True)

        motores = (["Oracle XE (backup)", "PostgreSQL"] if _failover_ss
                   else ["SQL Server", "PostgreSQL"])
        return {
            "consulta": "Ventas por sucursal con nombre de producto",
            "motores": motores, "failover": _failover_ss,
            "total": len(filas), "datos": filas,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q2 — Inventario actual vs unidades vendidas
# Stock:      PostgreSQL
# Vendido:    SS+PG (o Oracle backup+PG en failover)
# ──────────────────────────────────────────────────────────

@app.get("/q2")
def inventario_vs_ventas():
    try:
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT p.id_producto, p.nombre, i.cantidad_disponible, i.bodega
                FROM inventario.productos p
                JOIN inventario.inventario i ON p.id_producto = i.id_producto
                ORDER BY p.id_producto
            """)
            stock = {
                r[0]: {"id_producto": r[0], "producto": r[1],
                        "stock_disponible": r[2], "bodega": r[3]}
                for r in c.fetchall()
            }
            c.execute("""
                SELECT id_producto, SUM(cantidad) FROM inventario.detalle_ventas GROUP BY id_producto
            """)
            vendido_occ = {r[0]: r[1] for r in c.fetchall()}
        pg.close()

        if not _failover_ss:
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute("SELECT id_producto, SUM(cantidad) FROM detalle_ventas GROUP BY id_producto")
            vendido_cap = {r[0]: r[1] for r in cur.fetchall()}
            ss.close()
        else:
            ora = get_oracle()
            cur = ora.cursor()
            cur.execute("SELECT id_producto, SUM(cantidad) FROM detalle_ventas_backup GROUP BY id_producto")
            vendido_cap = {r[0]: r[1] for r in cur.fetchall()}
            ora.close()

        resultado = []
        for id_p, datos in stock.items():
            v_cap = vendido_cap.get(id_p, 0)
            v_occ = vendido_occ.get(id_p, 0)
            total_v = v_cap + v_occ
            resultado.append({
                **datos,
                "vendido_capital":   v_cap,
                "vendido_occidente": v_occ,
                "total_vendido":     total_v,
                "diferencia":        datos["stock_disponible"] - total_v,
            })

        motores = (["PostgreSQL", "Oracle XE (backup)"] if _failover_ss
                   else ["PostgreSQL", "SQL Server"])
        return {
            "consulta": "Inventario actual vs unidades vendidas",
            "motores": motores, "failover": _failover_ss,
            "total": len(resultado), "datos": resultado,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q3 — Top productos más vendidos
# Detalle: SS+PG (o Oracle backup+PG en failover)
# Catálogo: PostgreSQL
# ──────────────────────────────────────────────────────────

@app.get("/q3")
def top_productos():
    try:
        if not _failover_ss:
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute("SELECT id_producto, SUM(cantidad), SUM(subtotal) FROM detalle_ventas GROUP BY id_producto")
            ventas_cap = {r[0]: {"unidades": r[1], "ingresos": float(r[2])} for r in cur.fetchall()}
            ss.close()
        else:
            ora = get_oracle()
            cur = ora.cursor()
            cur.execute("SELECT id_producto, SUM(cantidad), SUM(subtotal) FROM detalle_ventas_backup GROUP BY id_producto")
            ventas_cap = {r[0]: {"unidades": r[1], "ingresos": float(r[2])} for r in cur.fetchall()}
            ora.close()

        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("SELECT id_producto, SUM(cantidad), SUM(subtotal) FROM inventario.detalle_ventas GROUP BY id_producto")
            ventas_occ = {r[0]: {"unidades": r[1], "ingresos": float(r[2])} for r in c.fetchall()}

            c.execute("""
                SELECT p.id_producto, p.nombre, p.precio_unitario, cat.nombre
                FROM inventario.productos p
                JOIN inventario.categorias cat ON p.id_categoria = cat.id_categoria
            """)
            productos = {r[0]: {"nombre": r[1], "precio_unitario": float(r[2]), "categoria": r[3]}
                         for r in c.fetchall()}
        pg.close()

        all_ids = set(ventas_cap) | set(ventas_occ)
        ranking = []
        for id_p in all_ids:
            cap = ventas_cap.get(id_p, {"unidades": 0, "ingresos": 0.0})
            occ = ventas_occ.get(id_p, {"unidades": 0, "ingresos": 0.0})
            p   = productos.get(id_p, {})
            ranking.append({
                "id_producto":     id_p,
                "producto":        p.get("nombre", "—"),
                "categoria":       p.get("categoria", "—"),
                "precio_unitario": p.get("precio_unitario", 0),
                "total_vendido":   cap["unidades"] + occ["unidades"],
                "ingresos":        cap["ingresos"] + occ["ingresos"],
            })

        ranking.sort(key=lambda x: x["total_vendido"], reverse=True)
        for i, r in enumerate(ranking):
            r["posicion"] = i + 1

        motores = (["Oracle XE (backup)", "PostgreSQL"] if _failover_ss
                   else ["SQL Server", "PostgreSQL"])
        return {
            "consulta": "Top productos más vendidos",
            "motores": motores, "failover": _failover_ss,
            "total": len(ranking), "datos": ranking,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q4 — Desempeño de empleados en ventas
# Capital:   SS o Oracle backup
# Occidente: PostgreSQL
# Empleados: Oracle
# ──────────────────────────────────────────────────────────

@app.get("/q4")
def ventas_por_empleado():
    try:
        if not _failover_ss:
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute("""
                SELECT id_empleado, COUNT(*) AS total_ventas, SUM(total) AS ingresos
                FROM ventas WHERE sucursal_id = 1
                GROUP BY id_empleado
            """)
            ventas_cap = [
                {"id_empleado": r[0], "sucursal": "Capital",
                 "total_ventas": r[1], "ingresos": float(r[2])}
                for r in cur.fetchall()
            ]
            ss.close()

            ora = get_oracle()
            cur_ora = ora.cursor()
        else:
            ora = get_oracle()
            cur_ora = ora.cursor()
            cur_ora.execute("""
                SELECT id_empleado, COUNT(*) AS total_ventas, SUM(total) AS ingresos
                FROM ventas_backup WHERE sucursal_id = 1
                GROUP BY id_empleado
            """)
            ventas_cap = [
                {"id_empleado": r[0], "sucursal": "Capital",
                 "total_ventas": r[1], "ingresos": float(r[2])}
                for r in cur_ora.fetchall()
            ]

        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT id_empleado, COUNT(*) AS total_ventas, SUM(total) AS ingresos
                FROM inventario.ventas WHERE sucursal_id = 2
                GROUP BY id_empleado
            """)
            ventas_occ = [
                {"id_empleado": r[0], "sucursal": "Occidente",
                 "total_ventas": r[1], "ingresos": float(r[2])}
                for r in c.fetchall()
            ]
        pg.close()

        cur_ora.execute("SELECT id_empleado, nombre || ' ' || apellido, puesto, sede FROM empleados")
        empleados = {r[0]: {"nombre": r[1], "puesto": r[2], "sede": r[3]}
                     for r in cur_ora.fetchall()}
        ora.close()

        todos = ventas_cap + ventas_occ
        todos.sort(key=lambda x: x["ingresos"], reverse=True)
        for f in todos:
            emp = empleados.get(f["id_empleado"], {})
            f["empleado"]    = emp.get("nombre", "—")
            f["puesto"]      = emp.get("puesto", "—")
            f["sede_oracle"] = emp.get("sede", "—")

        motores = (["Oracle XE (backup)", "PostgreSQL", "Oracle XE"] if _failover_ss
                   else ["SQL Server", "PostgreSQL", "Oracle XE"])
        return {
            "consulta": "Desempeño de empleados en ventas",
            "motores": motores, "failover": _failover_ss,
            "total": len(todos), "datos": todos,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q5 — Reporte integrado (últimas 10 ventas, los 3 motores)
# Capital:   SS (o Oracle backup en failover)
# Occidente: PostgreSQL
# Clientes:  SS (N/D en failover — SS simulado como caído)
# Productos: PostgreSQL
# Empleados: Oracle
# ──────────────────────────────────────────────────────────

@app.get("/q5")
def reporte_integrado():
    _COLS_PG = ["id_venta", "id_cliente", "id_empleado", "sucursal",
                "fecha_venta", "total", "id_producto", "cantidad", "subtotal"]

    try:
        # --- Occidente desde PostgreSQL ---
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT v.id_venta, v.id_cliente, v.id_empleado, 'Occidente' AS sucursal,
                       v.fecha_venta::varchar, v.total,
                       dv.id_producto, dv.cantidad, dv.subtotal
                FROM inventario.ventas v
                JOIN inventario.detalle_ventas dv ON v.id_venta = dv.id_venta
            """)
            filas_occ = [dict(zip(_COLS_PG, r)) for r in c.fetchall()]

            c.execute("SELECT id_producto, nombre FROM inventario.productos")
            productos = {r[0]: r[1] for r in c.fetchall()}
        pg.close()

        # --- Capital (SS normal o Oracle failover) ---
        if not _failover_ss:
            ss = get_sqlserver()
            cur = ss.cursor()
            _COLS_SS = ["id_venta", "cliente", "id_empleado", "sucursal",
                        "fecha_venta", "total", "id_producto", "cantidad", "subtotal"]
            cur.execute("""
                SELECT v.id_venta, c.nombre + ' ' + c.apellido, v.id_empleado,
                       'Capital' AS sucursal,
                       CONVERT(VARCHAR, v.fecha_venta, 120), v.total,
                       dv.id_producto, dv.cantidad, dv.subtotal
                FROM ventas v
                JOIN clientes c ON v.id_cliente = c.id_cliente
                JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
                WHERE v.sucursal_id = 1
            """)
            filas_cap = [dict(zip(_COLS_SS, r)) for r in cur.fetchall()]
            for f in filas_cap:
                f["total"]    = float(f["total"])
                f["subtotal"] = float(f["subtotal"])

            # Nombres de clientes para las ventas de Occidente
            client_ids = list({f["id_cliente"] for f in filas_occ})
            clientes_occ = {}
            if client_ids:
                ph = ",".join(["?" for _ in client_ids])
                cur.execute(
                    f"SELECT id_cliente, nombre + ' ' + apellido FROM clientes WHERE id_cliente IN ({ph})",
                    client_ids,
                )
                clientes_occ = {r[0]: r[1] for r in cur.fetchall()}
            ss.close()

            for f in filas_occ:
                f["cliente"] = clientes_occ.get(f["id_cliente"], f"Cliente #{f['id_cliente']}")
                f["fecha_venta"] = str(f["fecha_venta"])[:19] if f["fecha_venta"] else "—"
                f["total"]    = float(f["total"]) if f["total"] else 0.0
                f["subtotal"] = float(f["subtotal"]) if f["subtotal"] else 0.0
                del f["id_cliente"]

            ora = get_oracle()
        else:
            # Failover: SS caído → Capital desde Oracle backup
            _COLS_ORA = ["id_venta", "id_cliente", "id_empleado", "sucursal",
                         "fecha_venta", "total", "id_producto", "cantidad", "subtotal"]
            ora = get_oracle()
            cur_ora = ora.cursor()
            cur_ora.execute("""
                SELECT v.id_venta, v.id_cliente, v.id_empleado, 'Capital' AS sucursal,
                       v.fecha_venta, v.total,
                       dv.id_producto, dv.cantidad, dv.subtotal
                FROM ventas_backup v
                JOIN detalle_ventas_backup dv ON v.id_venta = dv.id_venta
            """)
            filas_cap = [dict(zip(_COLS_ORA, r)) for r in cur_ora.fetchall()]
            for f in filas_cap:
                f["cliente"]    = "N/D (failover)"
                f["fecha_venta"] = str(f["fecha_venta"])[:19] if f["fecha_venta"] else "—"
                f["total"]      = float(f["total"]) if f["total"] else 0.0
                f["subtotal"]   = float(f["subtotal"]) if f["subtotal"] else 0.0
                del f["id_cliente"]

            for f in filas_occ:
                f["cliente"]    = "N/D (failover)"
                f["fecha_venta"] = str(f["fecha_venta"])[:19] if f["fecha_venta"] else "—"
                f["total"]      = float(f["total"]) if f["total"] else 0.0
                f["subtotal"]   = float(f["subtotal"]) if f["subtotal"] else 0.0
                del f["id_cliente"]

        # --- Empleados desde Oracle ---
        cur_ora = ora.cursor()
        cur_ora.execute("SELECT id_empleado, nombre || ' ' || apellido, puesto FROM empleados")
        empleados = {r[0]: {"nombre": r[1], "puesto": r[2]} for r in cur_ora.fetchall()}
        ora.close()

        # --- Merge, sort, top 10 ---
        todas = filas_cap + filas_occ
        todas.sort(key=lambda x: x.get("fecha_venta", ""), reverse=True)
        top10 = todas[:10]

        for f in top10:
            f["producto"] = productos.get(f["id_producto"], "—")
            emp = empleados.get(f["id_empleado"], {})
            f["empleado"] = emp.get("nombre", "—")
            f["puesto"]   = emp.get("puesto", "—")

        motores = (["Oracle XE (backup)", "PostgreSQL", "Oracle XE"] if _failover_ss
                   else ["SQL Server", "PostgreSQL", "Oracle XE"])
        return {
            "consulta": "Reporte integrado — últimas 10 ventas",
            "motores": motores, "failover": _failover_ss,
            "total": len(top10), "datos": top10,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q6 — Todas las ventas unificadas (ambos fragmentos físicos)
# Muestra de qué motor físico proviene cada fila.
# Capital:   SQL Server  (o Oracle backup en failover)
# Occidente: PostgreSQL  (siempre)
# Clientes:  SQL Server  (N/D en failover)
# Empleados: Oracle
# ──────────────────────────────────────────────────────────

@app.get("/q6")
def todas_las_ventas():
    try:
        _COLS = ["id_venta", "id_cliente", "id_empleado", "sucursal",
                 "motor", "fecha_venta", "total", "estado"]

        # Occidente — siempre desde PostgreSQL
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT id_venta, id_cliente, id_empleado,
                       'Occidente' AS sucursal, 'PostgreSQL' AS motor,
                       fecha_venta::varchar, total, estado
                FROM inventario.ventas
                WHERE sucursal_id = 2
            """)
            ventas_occ = [dict(zip(_COLS, r)) for r in c.fetchall()]
        pg.close()

        # Empleados — siempre desde Oracle
        ora = get_oracle()
        cur_ora = ora.cursor()
        cur_ora.execute("SELECT id_empleado, nombre || ' ' || apellido FROM empleados")
        empleados = {r[0]: r[1] for r in cur_ora.fetchall()}
        ora.close()

        if not _failover_ss:
            # Capital desde SQL Server + nombres de clientes para ambas sucursales
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute("""
                SELECT id_venta, id_cliente, id_empleado,
                       'Capital' AS sucursal, 'SQL Server' AS motor,
                       CONVERT(VARCHAR, fecha_venta, 120), total, estado
                FROM ventas
                WHERE sucursal_id = 1
            """)
            ventas_cap = [dict(zip(_COLS, r)) for r in cur.fetchall()]

            all_client_ids = list({v["id_cliente"] for v in ventas_cap + ventas_occ})
            clientes = {}
            if all_client_ids:
                ph = ",".join(["?" for _ in all_client_ids])
                cur.execute(
                    f"SELECT id_cliente, nombre + ' ' + apellido FROM clientes WHERE id_cliente IN ({ph})",
                    all_client_ids,
                )
                clientes = {r[0]: r[1] for r in cur.fetchall()}
            ss.close()
        else:
            # Capital desde Oracle backup
            ora2 = get_oracle()
            cur2 = ora2.cursor()
            cur2.execute("""
                SELECT id_venta, id_cliente, id_empleado,
                       'Capital' AS sucursal, 'Oracle (backup)' AS motor,
                       fecha_venta, total, estado
                FROM ventas_backup
                WHERE sucursal_id = 1
            """)
            ventas_cap = [dict(zip(_COLS, r)) for r in cur2.fetchall()]
            ora2.close()
            clientes = {}

        # Enriquecer con nombres y limpiar IDs
        for v in ventas_cap + ventas_occ:
            v["cliente"]     = clientes.get(v["id_cliente"], "N/D" if _failover_ss else f"Cliente #{v['id_cliente']}")
            v["empleado"]    = empleados.get(v["id_empleado"], "—")
            v["total"]       = float(v["total"]) if v["total"] else 0.0
            v["fecha_venta"] = str(v["fecha_venta"])[:19] if v["fecha_venta"] else "—"
            del v["id_cliente"], v["id_empleado"]

        todas = ventas_cap + ventas_occ
        todas.sort(key=lambda x: x["fecha_venta"], reverse=True)

        motores = (["Oracle XE (backup)", "PostgreSQL"] if _failover_ss
                   else ["SQL Server", "PostgreSQL"])
        return {
            "consulta": "Todas las ventas — fragmentos físicos unificados",
            "motores": motores, "failover": _failover_ss,
            "total": len(todas),
            "capital": len(ventas_cap),
            "occidente": len(ventas_occ),
            "datos": todas,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# CATÁLOGOS — Datos de referencia para el formulario
# Clientes:  SQL Server  |  Empleados: Oracle  |  Productos: PostgreSQL
# ──────────────────────────────────────────────────────────

@app.get("/catalogos")
def catalogos():
    clientes = []
    empleados = []
    productos = []

    try:
        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("SELECT id_cliente, nombre + ' ' + apellido FROM clientes ORDER BY nombre")
        clientes = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        ss.close()
    except Exception:
        pass

    try:
        ora = get_oracle()
        cur_ora = ora.cursor()
        cur_ora.execute("SELECT id_empleado, nombre || ' ' || apellido, puesto FROM empleados ORDER BY nombre")
        empleados = [{"id": r[0], "nombre": r[1], "puesto": r[2]} for r in cur_ora.fetchall()]
        ora.close()
    except Exception:
        pass

    try:
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("SELECT id_producto, nombre, precio_unitario FROM inventario.productos ORDER BY nombre")
            productos = [{"id": r[0], "nombre": r[1], "precio": float(r[2])} for r in c.fetchall()]
        pg.close()
    except Exception:
        pass

    return {
        "clientes": clientes,
        "empleados": empleados,
        "productos": productos,
        "sucursales": [
            {"id": 1, "nombre": "Capital (SQL Server / Oracle backup)"},
            {"id": 2, "nombre": "Occidente (PostgreSQL)"},
        ],
    }


# ──────────────────────────────────────────────────────────
# POST /ventas — Inserción con routing por fragmento
# sucursal_id=1 → SQL Server  (o Oracle backup en failover)
# sucursal_id=2 → PostgreSQL  (siempre)
# ──────────────────────────────────────────────────────────

class NuevaVenta(BaseModel):
    id_cliente:  int
    id_empleado: int
    id_producto: int
    cantidad:    int
    sucursal_id: int


@app.post("/ventas")
def nueva_venta(body: NuevaVenta):
    if body.sucursal_id not in (1, 2):
        raise HTTPException(status_code=400, detail="sucursal_id debe ser 1 (Capital) o 2 (Occidente)")
    if body.cantidad < 1:
        raise HTTPException(status_code=400, detail="La cantidad debe ser al menos 1")

    # Precio desde PostgreSQL (fuente de verdad del catálogo — siempre disponible)
    try:
        pg = get_postgres()
        with pg.cursor() as c:
            c.execute(
                "SELECT precio_unitario FROM inventario.productos WHERE id_producto = %s",
                (body.id_producto,),
            )
            row = c.fetchone()
        pg.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error PostgreSQL al obtener precio: {e}")

    if not row:
        raise HTTPException(status_code=404, detail=f"Producto {body.id_producto} no encontrado")

    precio_unitario = float(row[0])
    subtotal = precio_unitario * body.cantidad
    total    = subtotal

    # ── Sucursal 2: siempre PostgreSQL ──
    if body.sucursal_id == 2:
        try:
            pg = get_postgres()
            with pg.cursor() as c:
                c.execute(
                    "INSERT INTO inventario.ventas (id_cliente, id_empleado, sucursal_id, total) "
                    "VALUES (%s, %s, 2, %s) RETURNING id_venta",
                    (body.id_cliente, body.id_empleado, total),
                )
                id_venta = c.fetchone()[0]
                c.execute(
                    "INSERT INTO inventario.detalle_ventas "
                    "(id_venta, id_producto, cantidad, precio_unitario, subtotal) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (id_venta, body.id_producto, body.cantidad, precio_unitario, subtotal),
                )
            pg.commit()
            pg.close()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error PostgreSQL al insertar: {e}")

        return {
            "ok": True, "id_venta": id_venta,
            "sucursal": "Occidente", "motor": "PostgreSQL",
            "fragmento": "inventario.ventas (PostgreSQL)", "failover": False,
            "total": total,
        }

    # ── Sucursal 1: SQL Server (normal) o Oracle backup (failover) ──
    if not _failover_ss:
        try:
            ss = get_sqlserver()
            cur = ss.cursor()
            cur.execute(
                "INSERT INTO ventas (id_cliente, id_empleado, sucursal_id, total) "
                "OUTPUT INSERTED.id_venta VALUES (?, ?, 1, ?)",
                (body.id_cliente, body.id_empleado, total),
            )
            id_venta = int(cur.fetchone()[0])
            cur.execute(
                "INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario, subtotal) "
                "VALUES (?, ?, ?, ?, ?)",
                (id_venta, body.id_producto, body.cantidad, precio_unitario, subtotal),
            )
            ss.commit()
            ss.close()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error SQL Server al insertar: {e}")

        return {
            "ok": True, "id_venta": id_venta,
            "sucursal": "Capital", "motor": "SQL Server",
            "fragmento": "dbo.ventas (SQL Server)", "failover": False,
            "total": total,
        }
    else:
        # Failover activo: insertar en Oracle backup
        try:
            ora = get_oracle()
            cur_ora = ora.cursor()
            cur_ora.execute("SELECT ventas_backup_seq.NEXTVAL FROM dual")
            id_venta = cur_ora.fetchone()[0]

            cur_ora.execute(
                "INSERT INTO ventas_backup "
                "(id_venta, id_cliente, id_empleado, sucursal_id, total, estado) "
                "VALUES (:1, :2, :3, 1, :4, 'completada')",
                [id_venta, body.id_cliente, body.id_empleado, total],
            )

            cur_ora.execute("SELECT detalle_ventas_backup_seq.NEXTVAL FROM dual")
            id_detalle = cur_ora.fetchone()[0]

            cur_ora.execute(
                "INSERT INTO detalle_ventas_backup "
                "(id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal) "
                "VALUES (:1, :2, :3, :4, :5, :6)",
                [id_detalle, id_venta, body.id_producto, body.cantidad, precio_unitario, subtotal],
            )
            ora.commit()
            ora.close()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error Oracle (failover) al insertar: {e}")

        return {
            "ok": True, "id_venta": int(id_venta),
            "sucursal": "Capital (FAILOVER)", "motor": "Oracle XE (backup)",
            "fragmento": "ventas_backup (Oracle)", "failover": True,
            "total": total,
        }
