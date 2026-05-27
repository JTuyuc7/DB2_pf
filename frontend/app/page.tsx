'use client'

import { useState, useEffect } from 'react'

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000'

// ── Consultas distribuidas ────────────────────────────────

const QUERIES = [
  { id: 'q1', label: 'Q1 — Ventas por sucursal con nombre de producto', motores: ['SQL Server', 'PostgreSQL'] },
  { id: 'q2', label: 'Q2 — Inventario actual vs unidades vendidas',      motores: ['PostgreSQL', 'SQL Server'] },
  { id: 'q3', label: 'Q3 — Top productos más vendidos',                  motores: ['SQL Server', 'PostgreSQL'] },
  { id: 'q4', label: 'Q4 — Desempeño de empleados en ventas',            motores: ['SQL Server', 'Oracle'] },
  { id: 'q5', label: 'Q5 — Reporte integrado (los 3 motores)',           motores: ['SQL Server', 'PostgreSQL', 'Oracle'] },
]

const MOTOR_COLOR: Record<string, string> = {
  'SQL Server': 'bg-purple-100 text-purple-800',
  'PostgreSQL': 'bg-blue-100 text-blue-800',
  'Oracle':     'bg-amber-100 text-amber-800',
}

const FRAGMENTO_COLOR: Record<string, string> = {
  ventas_capital:   'bg-purple-100 text-purple-800',
  ventas_occidente: 'bg-green-100 text-green-800',
}

// ── Tipos ─────────────────────────────────────────────────

type ApiResult = {
  consulta: string
  motores:  string[]
  total:    number
  datos:    Record<string, unknown>[]
}

type Catalogo = {
  id:      number
  nombre:  string
  puesto?: string
  precio?: number
}

type Catalogos = {
  clientes:   Catalogo[]
  empleados:  Catalogo[]
  productos:  Catalogo[]
  sucursales: Catalogo[]
}

type VentaResult = {
  ok:       boolean
  id_venta: number
  sucursal: string
  fragmento: string
  total:    number
}

// ── Componente principal ──────────────────────────────────

export default function Page() {
  const [vista, setVista] = useState<'consultas' | 'nueva_venta'>('consultas')

  // — Vista consultas
  const [queryId, setQueryId] = useState('q1')
  const [result, setResult]   = useState<ApiResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState<string | null>(null)

  // — Vista nueva venta
  const [catalogos, setCatalogos]         = useState<Catalogos | null>(null)
  const [catLoading, setCatLoading]       = useState(false)
  const [idCliente, setIdCliente]         = useState('')
  const [idEmpleado, setIdEmpleado]       = useState('')
  const [idProducto, setIdProducto]       = useState('')
  const [cantidad, setCantidad]           = useState('1')
  const [sucursalId, setSucursalId]       = useState('1')
  const [ventaResult, setVentaResult]     = useState<VentaResult | null>(null)
  const [ventaError, setVentaError]       = useState<string | null>(null)
  const [ventaLoading, setVentaLoading]   = useState(false)

  // Cargar catálogos al montar
  useEffect(() => {
    setCatLoading(true)
    fetch(`${API}/catalogos`)
      .then(r => r.json())
      .then((data: Catalogos) => {
        setCatalogos(data)
        if (data.clientes[0])  setIdCliente(String(data.clientes[0].id))
        if (data.empleados[0]) setIdEmpleado(String(data.empleados[0].id))
        if (data.productos[0]) setIdProducto(String(data.productos[0].id))
      })
      .catch(() => {/* backend puede no estar corriendo aún */})
      .finally(() => setCatLoading(false))
  }, [])

  // — Ejecutar consulta distribuida (puede forzar un queryId específico)
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
          id_cliente:  Number(idCliente),
          id_empleado: Number(idEmpleado),
          id_producto: Number(idProducto),
          cantidad:    Number(cantidad),
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

  const cols = result?.datos[0] ? Object.keys(result.datos[0]) : []

  const precioProducto = catalogos?.productos.find(p => String(p.id) === idProducto)?.precio ?? 0
  const totalEstimado  = precioProducto * Number(cantidad)

  return (
    <main className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">

        {/* Encabezado */}
        <h1 className="text-2xl font-bold text-gray-900 mb-1">TecnoChapina S.A.</h1>
        <p className="text-sm text-gray-500 mb-6">
          Mini Plataforma de Ventas Distribuida — Base de Datos II · UMG
        </p>

        {/* Tab bar */}
        <div className="flex gap-1 mb-6 border-b border-gray-200">
          {(['consultas', 'nueva_venta'] as const).map(v => (
            <button
              key={v}
              onClick={() => setVista(v)}
              className={`px-4 py-2 text-sm font-medium rounded-t border-b-2 transition-colors cursor-pointer ${
                vista === v
                  ? 'border-blue-600 text-blue-600 bg-white'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              {v === 'consultas' ? 'Consultas distribuidas' : 'Nueva venta'}
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
                          {cols.map(col => (
                            <td key={col} className="whitespace-nowrap px-3 py-2 text-gray-700">
                              {fila[col] != null ? String(fila[col]) : '—'}
                            </td>
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
              La venta se inserta en SQL Server. El campo <strong>Sucursal</strong> determina
              en qué fragmento lógico queda el registro (<code>ventas_capital</code> o <code>ventas_occidente</code>).
            </p>

            {catLoading && (
              <p className="text-sm text-gray-400 mb-4">Cargando catálogos…</p>
            )}

            {!catLoading && (
              <div className="space-y-4">

                {/* Sucursal */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Sucursal <span className="font-normal text-gray-400">(fragmento destino)</span>
                  </label>
                  <select
                    value={sucursalId}
                    onChange={e => setSucursalId(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  >
                    <option value="1">Capital → ventas_capital</option>
                    <option value="2">Occidente → ventas_occidente</option>
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
                    type="number"
                    min={1}
                    value={cantidad}
                    onChange={e => setCantidad(e.target.value)}
                    className="w-full rounded border border-gray-300 bg-white px-3 py-2 text-sm"
                  />
                </div>

                {/* Total estimado */}
                {precioProducto > 0 && (
                  <p className="text-sm text-gray-500">
                    Total estimado:{' '}
                    <strong>Q {totalEstimado.toLocaleString('es-GT', { minimumFractionDigits: 2 })}</strong>
                  </p>
                )}

                {/* Botón */}
                <button
                  onClick={registrarVenta}
                  disabled={ventaLoading || !idCliente || !idEmpleado || !idProducto}
                  className="w-full py-2 rounded bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 cursor-pointer"
                >
                  {ventaLoading ? 'Registrando…' : 'Registrar venta'}
                </button>

                {/* Error */}
                {ventaError && (
                  <div className="rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {ventaError}
                  </div>
                )}

                {/* Éxito */}
                {ventaResult?.ok && (
                  <div className="rounded border border-green-200 bg-green-50 px-4 py-4 space-y-2">
                    <p className="text-sm font-semibold text-green-800">
                      ✓ Venta #{ventaResult.id_venta} registrada en {ventaResult.sucursal}
                    </p>
                    <div className="flex items-center gap-2 text-sm text-green-700">
                      <span>Fragmento:</span>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${FRAGMENTO_COLOR[ventaResult.fragmento] ?? 'bg-gray-100 text-gray-700'}`}>
                        {ventaResult.fragmento}
                      </span>
                    </div>
                    <p className="text-sm text-green-700">
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

      </div>
    </main>
  )
}
