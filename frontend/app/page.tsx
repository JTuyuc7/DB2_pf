'use client'

import { useState, useEffect, useCallback } from 'react'

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000'

// ── Consultas distribuidas ────────────────────────────────

const QUERIES = [
  { id: 'q1', label: 'Q1 — Ventas por sucursal con nombre de producto', motores: ['SQL Server / Oracle', 'PostgreSQL'] },
  { id: 'q2', label: 'Q2 — Inventario actual vs unidades vendidas', motores: ['PostgreSQL', 'SQL Server / Oracle'] },
  { id: 'q3', label: 'Q3 — Top productos más vendidos', motores: ['SQL Server / Oracle', 'PostgreSQL'] },
  { id: 'q4', label: 'Q4 — Desempeño de empleados en ventas', motores: ['SQL Server / Oracle', 'PostgreSQL', 'Oracle'] },
  { id: 'q5', label: 'Q5 — Reporte integrado (los 3 motores)', motores: ['SQL Server / Oracle', 'PostgreSQL', 'Oracle'] },
  { id: 'q6', label: 'Q6 — Todas las ventas unificadas (fragmentos físicos)', motores: ['SQL Server / Oracle', 'PostgreSQL'] },
]

const MOTOR_COLOR: Record<string, string> = {
  'SQL Server': 'bg-purple-100 text-purple-800',
  'SQL Server 2022': 'bg-purple-100 text-purple-800',
  'PostgreSQL': 'bg-blue-100 text-blue-800',
  'PostgreSQL 16': 'bg-blue-100 text-blue-800',
  'Oracle': 'bg-amber-100 text-amber-800',
  'Oracle XE': 'bg-amber-100 text-amber-800',
  'Oracle XE (backup)': 'bg-orange-200 text-orange-900',
  'N/A (failover activo)': 'bg-red-100 text-red-700',
}

// ── Tipos ─────────────────────────────────────────────────

type ApiResult = {
  consulta: string
  motores: string[]
  failover?: boolean
  total: number
  datos: Record<string, unknown>[]
}

type Catalogo = {
  id: number
  nombre: string
  puesto?: string
  precio?: number
}

type Catalogos = {
  clientes: Catalogo[]
  empleados: Catalogo[]
  productos: Catalogo[]
  sucursales: Catalogo[]
}

type VentaResult = {
  ok: boolean
  id_venta: number
  sucursal: string
  fragmento: string
  motor: string
  failover: boolean
  total: number
}

type EstadoSistema = {
  failover_activo: boolean
  motor_ventas_capital: string
  motor_ventas_occidente: string
  motor_admin_empleados: string
  motor_inventario: string
  motor_clientes: string
  mensaje: string
}

// ── Componente principal ──────────────────────────────────

export default function Page() {
  const [vista, setVista] = useState<'consultas' | 'nueva_venta' | 'sistema'>('consultas')

  // — Vista consultas
  const [queryId, setQueryId] = useState('q1')
  const [result, setResult] = useState<ApiResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // — Vista nueva venta
  const [catalogos, setCatalogos] = useState<Catalogos | null>(null)
  const [catLoading, setCatLoading] = useState(false)
  const [idCliente, setIdCliente] = useState('')
  const [idEmpleado, setIdEmpleado] = useState('')
  const [idProducto, setIdProducto] = useState('')
  const [cantidad, setCantidad] = useState('1')
  const [sucursalId, setSucursalId] = useState('1')
  const [ventaResult, setVentaResult] = useState<VentaResult | null>(null)
  const [ventaError, setVentaError] = useState<string | null>(null)
  const [ventaLoading, setVentaLoading] = useState(false)

  // — Vista sistema
  const [estado, setEstado] = useState<EstadoSistema | null>(null)
  const [estadoLoading, setEstadoLoading] = useState(false)
  const [backupMsg, setBackupMsg] = useState<string | null>(null)
  const [backupErr, setBackupErr] = useState<string | null>(null)
  const [backupLoading, setBackupLoading] = useState(false)
  const [failoverMsg, setFailoverMsg] = useState<string | null>(null)
  const [failoverErr, setFailoverErr] = useState<string | null>(null)
  const [failoverLoading, setFailoverLoading] = useState(false)

  // Cargar catálogos al montar
  useEffect(() => {
    setCatLoading(true)
    fetch(`${API}/catalogos`)
      .then(r => r.json())
      .then((data: Catalogos) => {
        setCatalogos(data)
        if (data.clientes[0]) setIdCliente(String(data.clientes[0].id))
        if (data.empleados[0]) setIdEmpleado(String(data.empleados[0].id))
        if (data.productos[0]) setIdProducto(String(data.productos[0].id))
      })
      .catch(() => { })
      .finally(() => setCatLoading(false))
  }, [])

  // Cargar estado del sistema al entrar al tab
  const cargarEstado = useCallback(async () => {
    setEstadoLoading(true)
    try {
      const res = await fetch(`${API}/estado-sistema`)
      setEstado(await res.json())
    } catch {
      setEstado(null)
    } finally {
      setEstadoLoading(false)
    }
  }, [])

  useEffect(() => {
    if (vista === 'sistema') cargarEstado()
  }, [vista, cargarEstado])

  // — Ejecutar consulta distribuida
  async function ejecutar(qid?: string) {
    const target = qid ?? queryId
    if (qid) setQueryId(qid)
    setVista('consultas')
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const res = await fetch(`${API}/${target}`)
      if (!res.ok) throw new Error(`Error ${res.status}: ${res.statusText}`)
      setResult(await res.json())
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error desconocido')
    } finally {
      setLoading(false)
    }
  }

  // — Registrar nueva venta
  async function registrarVenta() {
    setVentaLoading(true)
    setVentaError(null)
    setVentaResult(null)
    try {
      const res = await fetch(`${API}/ventas`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_cliente: Number(idCliente),
          id_empleado: Number(idEmpleado),
          id_producto: Number(idProducto),
          cantidad: Number(cantidad),
          sucursal_id: Number(sucursalId),
        }),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.detail ?? `Error ${res.status}`)
      }
      setVentaResult(await res.json())
    } catch (e) {
      setVentaError(e instanceof Error ? e.message : 'Error desconocido')
    } finally {
      setVentaLoading(false)
    }
  }

  // — Acciones de failover
  async function accionFailover(endpoint: string) {
    setFailoverLoading(true)
    setFailoverMsg(null)
    setFailoverErr(null)
    try {
      const res = await fetch(`${API}/${endpoint}`, { method: 'POST' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.detail ?? `Error ${res.status}`)
      setFailoverMsg(data.mensaje)
      await cargarEstado()
    } catch (e) {
      setFailoverErr(e instanceof Error ? e.message : 'Error desconocido')
    } finally {
      setFailoverLoading(false)
    }
  }

  async function hacerBackup() {
    setBackupLoading(true)
    setBackupMsg(null)
    setBackupErr(null)
    try {
      const res = await fetch(`${API}/backup-oracle`, { method: 'POST' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.detail ?? `Error ${res.status}`)
      setBackupMsg(data.mensaje)
    } catch (e) {
      setBackupErr(e instanceof Error ? e.message : 'Error desconocido')
    } finally {
      setBackupLoading(false)
    }
  }

  const cols = result?.datos[0] ? Object.keys(result.datos[0]) : []
  const precioProducto = catalogos?.productos.find(p => String(p.id) === idProducto)?.precio ?? 0
  const totalEstimado = precioProducto * Number(cantidad)

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">

        {/* Encabezado */}
        <h1 className="text-2xl font-bold text-gray-900 mb-1">TecnoChapina S.A.</h1>
        <p className="text-sm text-gray-500 mb-6">
          Mini Plataforma de Ventas Distribuida — Base de Datos II · UMG
        </p>

        {/* Indicador de failover global */}
        {estado?.failover_activo && (
          <div className="mb-4 flex items-center gap-2 rounded border border-orange-300 bg-orange-50 px-4 py-2 text-sm text-orange-800">
            <span className="font-bold">FAILOVER ACTIVO</span>
            <span>— SQL Server simulado como caído. Capital redirigida a Oracle backup.</span>
          </div>
        )}

        {/* Tab bar */}
        <div className="flex gap-1 mb-6 border-b border-gray-200">
          {(['consultas', 'nueva_venta', 'sistema'] as const).map(v => (
            <button
              key={v}
              onClick={() => setVista(v)}
              className={`px-4 py-2 text-sm font-medium rounded-t border-b-2 transition-colors cursor-pointer ${vista === v
                  ? 'border-blue-600 text-blue-600 bg-white'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
                }`}
            >
              {v === 'consultas' ? 'Consultas distribuidas'
                : v === 'nueva_venta' ? 'Nueva venta'
                  : 'Sistema / Failover'}
            </button>
          ))}
        </div>

        {/* ── Vista A: Consultas ── */}
        {vista === 'consultas' && (
          <div>
            <div className="flex gap-3 mb-6">
              <select
                value={queryId}
                onChange={e => setQueryId(e.target.value)}
                className="flex-1 rounded border border-gray-300 bg-white px-3 py-2 text-sm"
              >
                {QUERIES.map(q => (
                  <option key={q.id} value={q.id}>{q.label}</option>
                ))}
              </select>
              <button
                onClick={() => ejecutar()}
                disabled={loading}
                className="px-5 py-2 rounded bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 cursor-pointer"
              >
                {loading ? 'Cargando…' : 'Ejecutar'}
              </button>
            </div>

            {error && (
              <div className="mb-4 rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {error}
              </div>
            )}

            {result && (
              <div>
                <div className="flex flex-wrap items-center gap-2 mb-3">
                  <span className="text-sm font-medium text-gray-800">{result.consulta}</span>
                  <span className="text-xs text-gray-400">· {result.total} filas</span>
                  {result.failover && (
                    <span className="rounded-full px-2 py-0.5 text-xs font-medium bg-orange-200 text-orange-900">
                      FAILOVER
                    </span>
                  )}
                  {result.motores.map(m => (
                    <span
                      key={m}
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${MOTOR_COLOR[m] ?? 'bg-gray-100 text-gray-700'}`}
                    >
                      {m}
                    </span>
                  ))}
                </div>

                <div className="overflow-x-auto rounded border border-gray-200">
                  <table className="w-full text-xs">
                    <thead className="bg-gray-100">

                      <tr>
                        <th className="whitespace-nowrap px-3 py-2 text-left font-semibold text-gray-600">#</th>
                        {cols.map(col => (
                          <th key={col} className="whitespace-nowrap px-3 py-2 text-left font-semibold text-gray-600">
                            {col}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {result.datos.map((fila, i) => (
                        <tr key={i} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                          <td className="whitespace-nowrap px-3 py-2 text-gray-700">{i + 1}</td>
                          {cols.map((col, idx) => (
                            <>

                              <td key={idx} className="whitespace-nowrap px-3 py-2 text-gray-700">
                                {fila[col] != null ? String(fila[col]) : '—'}
                              </td>
                            </>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ── Vista B: Nueva venta ── */}
        {vista === 'nueva_venta' && (
          <div className="max-w-lg">
            <p className="text-sm text-gray-500 mb-5">
              El campo <strong>Sucursal</strong> determina el motor destino:{' '}
              <span className="font-medium text-purple-700">Capital → SQL Server</span>{' '}
              (o Oracle en failover),{' '}
              <span className="font-medium text-blue-700">Occidente → PostgreSQL</span>.
            </p>

            {catLoading && <p className="text-sm text-gray-400 mb-4">Cargando catálogos…</p>}

            {!catLoading && (
              <div className="space-y-4">

                {/* Sucursal */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Sucursal <span className="font-normal text-gray-400">(motor destino)</span>
                  </label>
                  <select
                    value={sucursalId}
                    onChange={e => setSucursalId(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  >
                    <option value="1">Capital → SQL Server {estado?.failover_activo ? '(FAILOVER: Oracle)' : ''}</option>
                    <option value="2">Occidente → PostgreSQL</option>
                  </select>
                </div>

                {/* Cliente */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Cliente{' '}
                    <span className="rounded-full px-2 py-0.5 text-xs font-medium bg-purple-100 text-purple-800">SQL Server</span>
                  </label>
                  <select
                    value={idCliente}
                    onChange={e => setIdCliente(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  >
                    {(catalogos?.clientes ?? []).map(c => (
                      <option key={c.id} value={c.id}>{c.nombre}</option>
                    ))}
                  </select>
                </div>

                {/* Empleado */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Empleado{' '}
                    <span className="rounded-full px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-800">Oracle</span>
                  </label>
                  <select
                    value={idEmpleado}
                    onChange={e => setIdEmpleado(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  >
                    {(catalogos?.empleados ?? []).map(e => (
                      <option key={e.id} value={e.id}>{e.nombre} — {e.puesto}</option>
                    ))}
                  </select>
                </div>

                {/* Producto */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Producto{' '}
                    <span className="rounded-full px-2 py-0.5 text-xs font-medium bg-blue-100 text-blue-800">PostgreSQL</span>
                  </label>
                  <select
                    value={idProducto}
                    onChange={e => setIdProducto(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  >
                    {(catalogos?.productos ?? []).map(p => (
                      <option key={p.id} value={p.id}>
                        {p.nombre} — Q {p.precio?.toLocaleString('es-GT', { minimumFractionDigits: 2 })}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Cantidad */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Cantidad</label>
                  <input
                    type="number" min={1} value={cantidad}
                    onChange={e => setCantidad(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  />
                </div>

                {precioProducto > 0 && (
                  <p className="text-sm text-gray-500">
                    Total estimado:{' '}
                    <strong>Q {totalEstimado.toLocaleString('es-GT', { minimumFractionDigits: 2 })}</strong>
                  </p>
                )}

                <button
                  onClick={registrarVenta}
                  disabled={ventaLoading || !idCliente || !idEmpleado || !idProducto}
                  className="w-full py-2 rounded bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 cursor-pointer"
                >
                  {ventaLoading ? 'Registrando…' : 'Registrar venta'}
                </button>

                {ventaError && (
                  <div className="rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {ventaError}
                  </div>
                )}

                {ventaResult?.ok && (
                  <div className={`rounded border px-4 py-4 space-y-2 ${ventaResult.failover
                      ? 'border-orange-200 bg-orange-50'
                      : 'border-green-200 bg-green-50'
                    }`}>
                    <p className={`text-sm font-semibold ${ventaResult.failover ? 'text-orange-800' : 'text-green-800'}`}>
                      {ventaResult.failover ? '⚡ ' : '✓ '}
                      Venta #{ventaResult.id_venta} registrada en {ventaResult.sucursal}
                    </p>
                    <p className="text-xs text-gray-600">
                      Motor: <span className="font-medium">{ventaResult.motor}</span>
                    </p>
                    <p className="text-xs text-gray-600">
                      Fragmento: <span className="font-medium">{ventaResult.fragmento}</span>
                    </p>
                    <p className={`text-sm ${ventaResult.failover ? 'text-orange-700' : 'text-green-700'}`}>
                      Total:{' '}
                      <strong>Q {ventaResult.total.toLocaleString('es-GT', { minimumFractionDigits: 2 })}</strong>
                    </p>
                    <button
                      onClick={() => ejecutar('q1')}
                      className="mt-1 text-xs underline text-blue-600 hover:text-blue-800 cursor-pointer"
                    >
                      Ver en Q1 →
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* ── Vista C: Sistema / Failover ── */}
        {vista === 'sistema' && (
          <div className="max-w-2xl space-y-6">

            {/* Estado del sistema */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-base font-semibold text-gray-800">Estado de los motores</h2>
                <button
                  onClick={cargarEstado}
                  disabled={estadoLoading}
                  className="text-xs text-blue-600 underline cursor-pointer"
                >
                  {estadoLoading ? 'Actualizando…' : 'Actualizar'}
                </button>
              </div>

              {estado ? (
                <div className="rounded border border-gray-200 divide-y divide-gray-100 text-sm">
                  {[
                    { label: 'Ventas Capital (sucursal_id=1)', valor: estado.motor_ventas_capital },
                    { label: 'Ventas Occidente (sucursal_id=2)', valor: estado.motor_ventas_occidente },
                    { label: 'Empleados / Admin', valor: estado.motor_admin_empleados },
                    { label: 'Inventario / Productos', valor: estado.motor_inventario },
                    { label: 'Clientes', valor: estado.motor_clientes },
                  ].map(({ label, valor }) => (
                    <div key={label} className="flex items-center justify-between px-4 py-2">
                      <span className="text-gray-600">{label}</span>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${MOTOR_COLOR[valor] ?? 'bg-gray-100 text-gray-700'}`}>
                        {valor}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-gray-400">Sin datos — ¿está corriendo el backend?</p>
              )}
            </div>

            {/* Paso 1: Backup */}
            <div className="rounded border border-blue-100 bg-blue-50 p-4">
              <h3 className="text-sm font-semibold text-blue-900 mb-1">Paso 1 — Crear backup en Oracle</h3>
              <p className="text-xs text-blue-700 mb-3">
                Copia las ventas de Capital (SQL Server) a Oracle. Ejecutar ANTES de simular el fallo.
                La operación es idempotente — puede repetirse.
              </p>
              <button
                onClick={hacerBackup}
                disabled={backupLoading}
                className="px-4 py-2 rounded bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 cursor-pointer"
              >
                {backupLoading ? 'Copiando…' : 'Backup SQL Server → Oracle'}
              </button>
              {backupMsg && (
                <p className="mt-2 text-xs text-blue-800 font-medium">{backupMsg}</p>
              )}
              {backupErr && (
                <p className="mt-2 text-xs text-red-700">{backupErr}</p>
              )}
            </div>

            {/* Paso 2: Failover */}
            <div className={`rounded border p-4 ${estado?.failover_activo
                ? 'border-orange-300 bg-orange-50'
                : 'border-gray-200 bg-gray-50'
              }`}>
              <h3 className={`text-sm font-semibold mb-1 ${estado?.failover_activo ? 'text-orange-900' : 'text-gray-800'
                }`}>
                Paso 2 — Simular fallo de SQL Server
              </h3>
              <p className="text-xs text-gray-600 mb-3">
                Marca SQL Server como caído. El backend redirige automáticamente las consultas de Capital
                a Oracle (backup). La UI no cambia de comportamiento.
              </p>

              <div className="flex gap-3">
                <button
                  onClick={() => accionFailover('simular-fallo')}
                  disabled={failoverLoading || estado?.failover_activo}
                  className="px-4 py-2 rounded bg-red-600 text-white text-sm font-medium hover:bg-red-700 disabled:opacity-40 cursor-pointer"
                >
                  Simular fallo SQL Server
                </button>
                <button
                  onClick={() => accionFailover('restaurar')}
                  disabled={failoverLoading || !estado?.failover_activo}
                  className="px-4 py-2 rounded bg-green-600 text-white text-sm font-medium hover:bg-green-700 disabled:opacity-40 cursor-pointer"
                >
                  Restaurar SQL Server
                </button>
              </div>

              {failoverMsg && (
                <p className={`mt-2 text-xs font-medium ${estado?.failover_activo ? 'text-orange-800' : 'text-green-800'
                  }`}>
                  {failoverMsg}
                </p>
              )}
              {failoverErr && (
                <p className="mt-2 text-xs text-red-700">{failoverErr}</p>
              )}

              {estado?.failover_activo && (
                <div className="mt-3 rounded bg-orange-100 border border-orange-200 px-3 py-2 text-xs text-orange-900">
                  <strong>FAILOVER ACTIVO</strong> — Q1-Q5 y nuevas ventas de Capital usan Oracle (backup).
                  Ejecuta las consultas para ver el comportamiento transparente.
                </div>
              )}
            </div>

            {/* Demo rápida */}
            <div className="rounded border border-gray-200 p-4">
              <h3 className="text-sm font-semibold text-gray-700 mb-2">Demo rápida</h3>
              <p className="text-xs text-gray-500 mb-3">
                Después de simular el fallo, ejecuta estas consultas para ver el failover en acción:
              </p>
              <div className="flex flex-wrap gap-2">
                {['q1', 'q4', 'q5', 'q6'].map(q => (
                  <button
                    key={q}
                    onClick={() => ejecutar(q)}
                    className="px-3 py-1.5 rounded border border-gray-300 bg-white text-xs font-medium text-gray-700 hover:bg-gray-50 cursor-pointer"
                  >
                    Ejecutar {q.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

          </div>
        )}

      </div>
    </main>
  )
}
