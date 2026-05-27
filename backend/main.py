"""
main.py — Backend FastAPI para TecnoChapina S.A.

Orquesta 5 consultas distribuidas entre Oracle, PostgreSQL y SQL Server.
Cada endpoint consulta los motores necesarios y une los resultados en memoria.
También expone /catalogos (catálogos de referencia) y POST /ventas (inserción
distribuida que demuestra que la fragmentación horizontal opera en tiempo real).

Uso:
    cd backend
    uvicorn main:app --reload --port 8000
    Docs: http://localhost:8000/docs
"""

import os
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
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


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
        "consultas_disponibles": {
            "/q1": "Ventas por sucursal con nombre de producto  [SS + PG]",
            "/q2": "Inventario actual vs unidades vendidas       [PG + SS]",
            "/q3": "Top productos más vendidos                   [SS + PG]",
            "/q4": "Desempeño de empleados en ventas             [SS + Oracle]",
            "/q5": "Reporte integrado — últimas 10 ventas        [SS + PG + Oracle]",
        },
    }


# ──────────────────────────────────────────────────────────
# Q1 — Ventas por sucursal con nombre de producto
# Motores: SQL Server (ventas/detalle) + PostgreSQL (nombres)
# ──────────────────────────────────────────────────────────

@app.get("/q1")
def ventas_por_sucursal():
    """
    Agrupa las unidades vendidas e ingresos por producto y sucursal.
    SQL Server aporta los montos; PostgreSQL aporta los nombres de producto.
    """
    try:
        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("""
            SELECT
                dv.id_producto,
                v.sucursal_id,
                CASE WHEN v.sucursal_id = 1 THEN 'Capital' ELSE 'Occidente' END AS sucursal,
                SUM(dv.cantidad)  AS unidades_vendidas,
                SUM(dv.subtotal)  AS ingresos
            FROM detalle_ventas dv
            JOIN ventas v ON dv.id_venta = v.id_venta
            GROUP BY dv.id_producto, v.sucursal_id
            ORDER BY ingresos DESC
        """)
        filas = [
            {
                "id_producto": r[0], "sucursal_id": r[1], "sucursal": r[2],
                "unidades_vendidas": r[3], "ingresos": float(r[4]),
            }
            for r in cur.fetchall()
        ]
        ss.close()

        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("SELECT id_producto, nombre, precio_unitario FROM inventario.productos")
            productos = {r[0]: {"nombre": r[1], "precio_unitario": float(r[2])} for r in c.fetchall()}
        pg.close()

        for f in filas:
            p = productos.get(f["id_producto"], {})
            f["producto"] = p.get("nombre", "—")
            f["precio_unitario"] = p.get("precio_unitario", 0)

        return {
            "consulta": "Ventas por sucursal con nombre de producto",
            "motores": ["SQL Server", "PostgreSQL"],
            "total": len(filas),
            "datos": filas,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q2 — Inventario actual vs unidades vendidas
# Motores: PostgreSQL (stock) + SQL Server (ventas)
# ──────────────────────────────────────────────────────────

@app.get("/q2")
def inventario_vs_ventas():
    """
    Compara el stock disponible en bodega contra las unidades vendidas.
    PostgreSQL aporta el inventario; SQL Server aporta las cantidades vendidas.
    """
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
                r[0]: {"id_producto": r[0], "producto": r[1], "stock_disponible": r[2], "bodega": r[3]}
                for r in c.fetchall()
            }
        pg.close()

        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("""
            SELECT id_producto, SUM(cantidad) AS total_vendido
            FROM detalle_ventas
            GROUP BY id_producto
        """)
        vendido = {r[0]: r[1] for r in cur.fetchall()}
        ss.close()

        resultado = []
        for id_prod, datos in stock.items():
            datos["unidades_vendidas"] = vendido.get(id_prod, 0)
            datos["diferencia"] = datos["stock_disponible"] - datos["unidades_vendidas"]
            resultado.append(datos)

        return {
            "consulta": "Inventario actual vs unidades vendidas",
            "motores": ["PostgreSQL", "SQL Server"],
            "total": len(resultado),
            "datos": resultado,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q3 — Top productos más vendidos
# Motores: SQL Server (cantidades) + PostgreSQL (nombres/categoría)
# ──────────────────────────────────────────────────────────

@app.get("/q3")
def top_productos():
    """
    Ranking de productos ordenado por unidades vendidas.
    SQL Server aporta las cantidades; PostgreSQL aporta nombre y categoría.
    """
    try:
        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("""
            SELECT id_producto, SUM(cantidad) AS total_vendido, SUM(subtotal) AS ingresos
            FROM detalle_ventas
            GROUP BY id_producto
            ORDER BY total_vendido DESC
        """)
        ranking = [
            {"id_producto": r[0], "total_vendido": r[1], "ingresos": float(r[2])}
            for r in cur.fetchall()
        ]
        ss.close()

        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("""
                SELECT p.id_producto, p.nombre, p.precio_unitario, cat.nombre AS categoria
                FROM inventario.productos p
                JOIN inventario.categorias cat ON p.id_categoria = cat.id_categoria
            """)
            productos = {
                r[0]: {"nombre": r[1], "precio_unitario": float(r[2]), "categoria": r[3]}
                for r in c.fetchall()
            }
        pg.close()

        for i, f in enumerate(ranking):
            p = productos.get(f["id_producto"], {})
            f["posicion"] = i + 1
            f["producto"] = p.get("nombre", "—")
            f["precio_unitario"] = p.get("precio_unitario", 0)
            f["categoria"] = p.get("categoria", "—")

        return {
            "consulta": "Top productos más vendidos",
            "motores": ["SQL Server", "PostgreSQL"],
            "total": len(ranking),
            "datos": ranking,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q4 — Desempeño de empleados en ventas
# Motores: SQL Server (ventas) + Oracle (empleados)
# ──────────────────────────────────────────────────────────

@app.get("/q4")
def ventas_por_empleado():
    """
    Cuántas ventas generó cada empleado y el total en quetzales.
    SQL Server aporta las ventas; Oracle aporta nombre y puesto del empleado.
    """
    try:
        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("""
            SELECT
                id_empleado,
                CASE WHEN sucursal_id = 1 THEN 'Capital' ELSE 'Occidente' END AS sucursal,
                COUNT(*)   AS total_ventas,
                SUM(total) AS ingresos
            FROM ventas
            GROUP BY id_empleado, sucursal_id
            ORDER BY ingresos DESC
        """)
        ventas_emp = [
            {"id_empleado": r[0], "sucursal": r[1], "total_ventas": r[2], "ingresos": float(r[3])}
            for r in cur.fetchall()
        ]
        ss.close()

        ora = get_oracle()
        cur_ora = ora.cursor()
        cur_ora.execute("SELECT id_empleado, nombre, apellido, puesto, sede FROM empleados")
        empleados = {
            r[0]: {"nombre": f"{r[1]} {r[2]}", "puesto": r[3], "sede": r[4]}
            for r in cur_ora.fetchall()
        }
        ora.close()

        for f in ventas_emp:
            emp = empleados.get(f["id_empleado"], {})
            f["empleado"] = emp.get("nombre", "—")
            f["puesto"] = emp.get("puesto", "—")
            f["sede_oracle"] = emp.get("sede", "—")

        return {
            "consulta": "Desempeño de empleados en ventas",
            "motores": ["SQL Server", "Oracle"],
            "total": len(ventas_emp),
            "datos": ventas_emp,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# Q5 — Reporte integrado (los 3 motores)
# Motores: SQL Server + PostgreSQL + Oracle
# ──────────────────────────────────────────────────────────

@app.get("/q5")
def reporte_integrado():
    """
    Las 10 ventas más recientes con cliente, producto y empleado.
    SQL Server aporta venta+cliente; PostgreSQL el catálogo; Oracle el personal.
    """
    try:
        ss = get_sqlserver()
        cur = ss.cursor()
        cur.execute("""
            SELECT TOP 10
                v.id_venta,
                c.nombre + ' ' + c.apellido  AS cliente,
                v.id_empleado,
                CASE WHEN v.sucursal_id = 1 THEN 'Capital' ELSE 'Occidente' END AS sucursal,
                CONVERT(VARCHAR, v.fecha_venta, 23)  AS fecha_venta,
                v.total,
                dv.id_producto,
                dv.cantidad,
                dv.subtotal
            FROM ventas v
            JOIN clientes        c  ON v.id_cliente = c.id_cliente
            JOIN detalle_ventas dv  ON v.id_venta   = dv.id_venta
            ORDER BY v.fecha_venta DESC
        """)
        cols = ["id_venta", "cliente", "id_empleado", "sucursal",
                "fecha_venta", "total", "id_producto", "cantidad", "subtotal"]
        filas = [dict(zip(cols, r)) for r in cur.fetchall()]
        ss.close()

        for f in filas:
            f["total"] = float(f["total"])
            f["subtotal"] = float(f["subtotal"])

        pg = get_postgres()
        with pg.cursor() as c:
            c.execute("SELECT id_producto, nombre FROM inventario.productos")
            productos = {r[0]: r[1] for r in c.fetchall()}
        pg.close()

        ora = get_oracle()
        cur_ora = ora.cursor()
        cur_ora.execute("SELECT id_empleado, nombre || ' ' || apellido, puesto FROM empleados")
        empleados = {r[0]: {"nombre": r[1], "puesto": r[2]} for r in cur_ora.fetchall()}
        ora.close()

        for f in filas:
            f["producto"] = productos.get(f["id_producto"], "—")
            emp = empleados.get(f["id_empleado"], {})
            f["empleado"] = emp.get("nombre", "—")
            f["puesto"] = emp.get("puesto", "—")

        return {
            "consulta": "Reporte integrado — últimas 10 ventas",
            "motores": ["SQL Server", "PostgreSQL", "Oracle"],
            "total": len(filas),
            "datos": filas,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ──────────────────────────────────────────────────────────
# CATALOGOS — Datos de referencia para el formulario de ventas
# Motores: SQL Server (clientes) + Oracle (empleados) + PostgreSQL (productos)
# ──────────────────────────────────────────────────────────

@app.get("/catalogos")
def catalogos():
    """
    Devuelve clientes, empleados y productos para poblar los dropdowns
    del formulario de nueva venta. Cada motor falla de forma independiente.
    """
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
            {"id": 1, "nombre": "Capital"},
            {"id": 2, "nombre": "Occidente"},
        ],
    }


# ──────────────────────────────────────────────────────────
# POST /ventas — Insertar una nueva venta
# Motores: PostgreSQL (precio) + SQL Server (INSERT ventas + detalle_ventas)
# Demuestra que la fragmentación horizontal es dinámica:
#   sucursal_id=1 → el registro aparece automáticamente en ventas_capital
#   sucursal_id=2 → el registro aparece automáticamente en ventas_occidente
# ──────────────────────────────────────────────────────────

class NuevaVenta(BaseModel):
    id_cliente:  int
    id_empleado: int
    id_producto: int
    cantidad:    int
    sucursal_id: int


@app.post("/ventas")
def nueva_venta(body: NuevaVenta):
    """
    Registra una nueva venta y su detalle en SQL Server.
    El sucursal_id determina en qué fragmento lógico queda el registro.
    """
    if body.sucursal_id not in (1, 2):
        raise HTTPException(status_code=400, detail="sucursal_id debe ser 1 (Capital) o 2 (Occidente)")
    if body.cantidad < 1:
        raise HTTPException(status_code=400, detail="La cantidad debe ser al menos 1")

    # Obtener precio desde PostgreSQL (fuente de verdad del catálogo)
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
        raise HTTPException(status_code=500, detail=f"Error al consultar PostgreSQL: {e}")

    if not row:
        raise HTTPException(status_code=404, detail=f"Producto {body.id_producto} no encontrado en PostgreSQL")

    precio_unitario = float(row[0])
    subtotal = precio_unitario * body.cantidad
    total = subtotal

    # Insertar en SQL Server
    try:
        ss = get_sqlserver()
        cur = ss.cursor()

        cur.execute(
            """
            INSERT INTO ventas (id_cliente, id_empleado, sucursal_id, total)
            OUTPUT INSERTED.id_venta
            VALUES (?, ?, ?, ?)
            """,
            (body.id_cliente, body.id_empleado, body.sucursal_id, total),
        )
        id_venta = int(cur.fetchone()[0])

        cur.execute(
            """
            INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario, subtotal)
            VALUES (?, ?, ?, ?, ?)
            """,
            (id_venta, body.id_producto, body.cantidad, precio_unitario, subtotal),
        )
        ss.commit()
        ss.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al insertar en SQL Server: {e}")

    nombre_sucursal = "Capital" if body.sucursal_id == 1 else "Occidente"
    fragmento = "ventas_capital" if body.sucursal_id == 1 else "ventas_occidente"

    return {
        "ok": True,
        "id_venta": id_venta,
        "sucursal": nombre_sucursal,
        "fragmento": fragmento,
        "total": total,
    }
