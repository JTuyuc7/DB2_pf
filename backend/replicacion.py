"""
replicacion.py — Replicación snapshot de productos PostgreSQL → SQL Server

Copia la tabla inventario.productos (PostgreSQL) hacia productos_replica (SQL Server).
Tipo: snapshot — trunca y reinser ta en cada ejecución.

Uso:
    cd backend
    pip install -r requirements.txt
    copy .env.example .env
    python replicacion.py
"""

import os
from datetime import datetime

import psycopg
import pyodbc
from dotenv import load_dotenv

load_dotenv()


def conectar_postgres():
    return psycopg.connect(
        host=os.getenv("PG_HOST", "localhost"),
        port=int(os.getenv("PG_PORT", "5432")),
        dbname=os.getenv("PG_DB", "inventario_db"),
        user=os.getenv("PG_USER", "admin_inventario"),
        password=os.getenv("PG_PASSWORD", "PostgresPass123"),
    )


def conectar_sqlserver():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={os.getenv('SS_HOST', 'localhost')},{os.getenv('SS_PORT', '1433')};"
        f"DATABASE={os.getenv('SS_DB', 'ventas_db')};"
        f"UID={os.getenv('SS_USER', 'sa')};"
        f"PWD={os.getenv('SS_PASSWORD', 'SqlServerPass123!')};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def crear_tabla_replica(cursor):
    cursor.execute("""
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'productos_replica')
        CREATE TABLE productos_replica (
            id_producto     INT            PRIMARY KEY,
            nombre          NVARCHAR(150)  NOT NULL,
            descripcion     NVARCHAR(500),
            precio_unitario DECIMAL(10,2),
            id_categoria    INT,
            id_proveedor    INT,
            replicado_en    DATETIME       DEFAULT GETDATE()
        )
    """)


def replicar():
    inicio = datetime.now()
    print(f"[{inicio:%Y-%m-%d %H:%M:%S}] Iniciando replicación productos...")

    # 1. Leer desde PostgreSQL (fuente)
    pg = conectar_postgres()
    with pg.cursor() as cur:
        cur.execute("""
            SELECT id_producto, nombre, descripcion,
                   precio_unitario, id_categoria, id_proveedor
            FROM inventario.productos
            ORDER BY id_producto
        """)
        productos = cur.fetchall()
    pg.close()
    print(f"  [PG]  {len(productos)} productos leídos desde PostgreSQL (inventario.productos)")

    # 2. Escribir en SQL Server (destino)
    ss = conectar_sqlserver()
    cur = ss.cursor()

    crear_tabla_replica(cur)
    cur.execute("TRUNCATE TABLE productos_replica")

    for p in productos:
        cur.execute(
            """
            INSERT INTO productos_replica
                (id_producto, nombre, descripcion, precio_unitario, id_categoria, id_proveedor)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            p,
        )

    ss.commit()
    cur.close()
    ss.close()

    fin = datetime.now()
    duracion = (fin - inicio).total_seconds()
    print(f"  [SS]  {len(productos)} productos escritos en SQL Server (productos_replica)")
    print(f"[{fin:%Y-%m-%d %H:%M:%S}] Replicación completada en {duracion:.2f}s.")


if __name__ == "__main__":
    replicar()
