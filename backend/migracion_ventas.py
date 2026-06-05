"""
migracion_ventas.py — Migración de ventas sucursal_id=2 de SQL Server → PostgreSQL.

PREREQUISITO: Ejecutar sql/postgres/03_ventas.sql en el contenedor PG primero.
PRECAUCIÓN: Este script mueve datos y elimina registros de SS. Ejecutar UNA SOLA VEZ.

Pasos que realiza:
  1. Lee ventas sucursal_id=2 de SQL Server
  2. Lee detalle_ventas correspondiente de SQL Server
  3. Inserta ambas tablas en PostgreSQL (preservando los IDs originales)
  4. Ajusta las secuencias SERIAL de PostgreSQL
  5. Elimina los registros migrados de SQL Server

Uso:
    cd backend
    python migracion_ventas.py
"""

import os, sys
from dotenv import load_dotenv
import psycopg
import pyodbc

load_dotenv()


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


def main():
    print("=" * 60)
    print("Migración: ventas sucursal_id=2 — SQL Server → PostgreSQL")
    print("=" * 60)

    ss = get_sqlserver()
    pg = get_postgres()

    try:
        cur_ss = ss.cursor()

        # 1. Verificar que no se haya migrado ya
        with pg.cursor() as cur_pg:
            cur_pg.execute("SELECT COUNT(*) FROM inventario.ventas")
            ya_migrado = cur_pg.fetchone()[0]

        if ya_migrado > 0:
            print(f"\n  AVISO: PostgreSQL ya tiene {ya_migrado} ventas.")
            resp = input("  ¿Continuar de todas formas? Esto puede duplicar datos. [s/N]: ").strip().lower()
            if resp != "s":
                print("  Migración cancelada.")
                return

        # 2. Leer ventas sucursal_id=2 de SQL Server
        cur_ss.execute(
            "SELECT id_venta, id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado "
            "FROM ventas WHERE sucursal_id = 2"
        )
        ventas = cur_ss.fetchall()

        if not ventas:
            print("\n  No se encontraron ventas con sucursal_id=2 en SQL Server.")
            print("  Posiblemente ya fue migrado o los datos no existen.")
            return

        venta_ids = [v[0] for v in ventas]
        print(f"\n  Paso 1/5 — {len(ventas)} ventas encontradas en SQL Server (sucursal_id=2)")

        # 3. Leer detalle_ventas de esas ventas
        placeholders = ",".join(["?" for _ in venta_ids])
        cur_ss.execute(
            f"SELECT id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal "
            f"FROM detalle_ventas WHERE id_venta IN ({placeholders})",
            venta_ids,
        )
        detalles = cur_ss.fetchall()
        print(f"  Paso 2/5 — {len(detalles)} registros detalle_ventas encontrados")

        # 4. Insertar en PostgreSQL con los mismos IDs (OVERRIDING SYSTEM VALUE)
        with pg.cursor() as cur_pg:
            for v in ventas:
                cur_pg.execute(
                    """
                    INSERT INTO inventario.ventas
                      (id_venta, id_cliente, id_empleado, fecha_venta, total, sucursal_id, estado)
                    OVERRIDING SYSTEM VALUE
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (v[0], v[1], v[2], v[3], float(v[4]), v[5], v[6]),
                )

            for d in detalles:
                cur_pg.execute(
                    """
                    INSERT INTO inventario.detalle_ventas
                      (id_detalle, id_venta, id_producto, cantidad, precio_unitario, subtotal)
                    OVERRIDING SYSTEM VALUE
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (d[0], d[1], d[2], d[3], float(d[4]), float(d[5])),
                )

            # Resetear secuencias SERIAL al máximo ID insertado
            cur_pg.execute(
                "SELECT setval('inventario.ventas_id_venta_seq', "
                "(SELECT MAX(id_venta) FROM inventario.ventas))"
            )
            cur_pg.execute(
                "SELECT setval('inventario.detalle_ventas_id_detalle_seq', "
                "(SELECT MAX(id_detalle) FROM inventario.detalle_ventas))"
            )

        pg.commit()
        print(f"  Paso 3/5 — Datos insertados en PostgreSQL (IDs preservados)")

        # 5. Eliminar de SQL Server (primero detalle, luego ventas por FK)
        cur_ss.execute(
            f"DELETE FROM detalle_ventas WHERE id_venta IN ({placeholders})",
            venta_ids,
        )
        cur_ss.execute("DELETE FROM ventas WHERE sucursal_id = 2")
        ss.commit()
        print(f"  Paso 4/5 — Registros sucursal_id=2 eliminados de SQL Server")

        # 6. Verificar
        with pg.cursor() as cur_pg:
            cur_pg.execute("SELECT COUNT(*) FROM inventario.ventas")
            total_pg = cur_pg.fetchone()[0]

        cur_ss.execute("SELECT COUNT(*) FROM ventas WHERE sucursal_id = 1")
        total_ss = cur_ss.fetchone()[0]

        print(f"  Paso 5/5 — Verificación:")
        print(f"             SQL Server ventas (sucursal_id=1): {total_ss}")
        print(f"             PostgreSQL ventas (sucursal_id=2): {total_pg}")

        print("\n" + "=" * 60)
        print("  Migración completada exitosamente.")
        print("  SQL Server: Capital (sucursal_id=1) — fragmento físico")
        print("  PostgreSQL: Occidente (sucursal_id=2) — fragmento físico")
        print("=" * 60)

    except Exception as e:
        print(f"\n  ERROR durante la migración: {e}")
        print("  Realizando rollback...")
        ss.rollback()
        pg.rollback()
        sys.exit(1)
    finally:
        ss.close()
        pg.close()


if __name__ == "__main__":
    main()
