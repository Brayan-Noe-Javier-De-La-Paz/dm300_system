/// Esquema formal de base de datos relacional para el sistema DM300.
///
/// Define el dialecto SQLite para persistencia local offline (Windows/Android)
/// y el dialecto PostgreSQL / Supabase para sincronización remota en la nube.
class EsquemaSql {
  const EsquemaSql._();

  /// Versión actual del esquema local SQLite.
  static const int versionEsquema = 1;

  /// Nombre del archivo de base de datos local SQLite.
  static const String nombreBaseDatos = 'dm300_local_v1.db';

  // --- ESTRATEGIA DE SINCRONIZACIÓN OFFLINE-FIRST ---
  /// Estrategia de resolución de conflictos: Last-Write-Wins basado en UTC timestamp.
  static const String estrategiaResolucionConflictos = 'last_write_wins_timestamp';

  /// Intervalo sugerido en segundos para polling/sincronización con Supabase.
  static const int intervaloSincronizacionSegundos = 300;

  /// Política de sincronización: Local es la fuente inmediata de verdad; Supabase es el respaldo remoto.
  static const String politicaSincronizacion = 'offline_first_local_primary';

  // ==========================================
  // DIALECTO SQLITE LOCAL (Windows / Android)
  // ==========================================
  static const String esquemaSqlite = '''
-- Tabla: moto
CREATE TABLE IF NOT EXISTS moto (
  id TEXT PRIMARY KEY NOT NULL,
  modelo TEXT NOT NULL,
  ano INTEGER NOT NULL,
  cilindrada TEXT NOT NULL,
  tanque_l REAL NOT NULL,
  aceite_l REAL NOT NULL,
  creado_en TEXT NOT NULL,
  actualizado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 1
);

-- Tabla: datos_ficha
CREATE TABLE IF NOT EXISTS datos_ficha (
  clave TEXT PRIMARY KEY NOT NULL,
  seccion TEXT NOT NULL,
  titulo TEXT NOT NULL,
  pregunta TEXT NOT NULL,
  donde_verlo TEXT NOT NULL,
  opciones_json TEXT NOT NULL DEFAULT '[]',
  valor TEXT NOT NULL,
  estado TEXT NOT NULL,
  nota_foto TEXT,
  actualizado_en TEXT,
  sincronizado INTEGER NOT NULL DEFAULT 0
);

-- Tabla: lecturas_odometro
CREATE TABLE IF NOT EXISTS lecturas_odometro (
  id TEXT PRIMARY KEY NOT NULL,
  km REAL NOT NULL,
  fecha TEXT NOT NULL,
  origen TEXT NOT NULL,
  cambio_tablero INTEGER NOT NULL DEFAULT 0,
  nota TEXT,
  creado_en TEXT NOT NULL,
  actualizado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 0
);

-- Tabla: tareas_mantenimiento
CREATE TABLE IF NOT EXISTS tareas_mantenimiento (
  id TEXT PRIMARY KEY NOT NULL,
  zona TEXT NOT NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  intervalo_km REAL,
  intervalo_dias INTEGER,
  ultimo_km REAL,
  ultima_fecha TEXT,
  hecho_por TEXT,
  ultimo_costo REAL,
  actualizado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 0
);

-- Tabla: registros_servicio
CREATE TABLE IF NOT EXISTS registros_servicio (
  id TEXT PRIMARY KEY NOT NULL,
  tarea_id TEXT NOT NULL,
  titulo_tarea TEXT NOT NULL,
  zona TEXT NOT NULL,
  km REAL NOT NULL,
  fecha TEXT NOT NULL,
  realizado_por TEXT NOT NULL,
  costo REAL NOT NULL,
  notas TEXT,
  creado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (tarea_id) REFERENCES tareas_mantenimiento(id) ON DELETE CASCADE
);

-- Tabla: cargas_combustible
CREATE TABLE IF NOT EXISTS cargas_combustible (
  id TEXT PRIMARY KEY NOT NULL,
  km REAL NOT NULL,
  litros REAL NOT NULL,
  costo REAL NOT NULL,
  fecha TEXT NOT NULL,
  km_por_litro REAL,
  creado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 0
);

-- Tabla: mediciones_desgaste
CREATE TABLE IF NOT EXISTS mediciones_desgaste (
  id TEXT PRIMARY KEY NOT NULL,
  componente TEXT NOT NULL,
  unidad TEXT NOT NULL,
  valor REAL NOT NULL,
  minimo_seguro REAL NOT NULL,
  maximo_seguro REAL,
  km REAL NOT NULL,
  fecha TEXT NOT NULL,
  nota TEXT,
  creado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 0
);

-- Tabla: catalogo_refacciones
CREATE TABLE IF NOT EXISTS catalogo_refacciones (
  id TEXT PRIMARY KEY NOT NULL,
  sku TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  categoria TEXT NOT NULL,
  zona TEXT NOT NULL,
  precio_estimado REAL NOT NULL,
  depende_de_clave_ficha TEXT,
  valor_requerido TEXT,
  requiere_accesorio TEXT,
  notas TEXT,
  actualizado_en TEXT NOT NULL,
  sincronizado INTEGER NOT NULL DEFAULT 1
);

-- Tabla de cola de operaciones offline para sincronización
CREATE TABLE IF NOT EXISTS cola_sincronizacion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tabla TEXT NOT NULL,
  registro_id TEXT NOT NULL,
  operacion TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
  payload_json TEXT NOT NULL,
  creado_en TEXT NOT NULL,
  intentos INTEGER NOT NULL DEFAULT 0
);

-- Índices de consulta de alto rendimiento
CREATE INDEX IF NOT EXISTS idx_odo_fecha ON lecturas_odometro(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_serv_tarea ON registros_servicio(tarea_id);
CREATE INDEX IF NOT EXISTS idx_cargas_fecha ON cargas_combustible(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_ficha_seccion ON datos_ficha(seccion);
''';

  // ==========================================
  // DIALECTO POSTGRESQL / SUPABASE (Cloud)
  // ==========================================
  static const String esquemaSupabase = '''
-- Extensión para generación de identificadores UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla: moto
CREATE TABLE IF NOT EXISTS public.moto (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  modelo TEXT NOT NULL,
  ano INTEGER NOT NULL,
  cilindrada TEXT NOT NULL,
  tanque_l NUMERIC(5,2) NOT NULL,
  aceite_l NUMERIC(4,2) NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: datos_ficha
CREATE TABLE IF NOT EXISTS public.datos_ficha (
  clave TEXT PRIMARY KEY,
  seccion TEXT NOT NULL,
  titulo TEXT NOT NULL,
  pregunta TEXT NOT NULL,
  donde_verlo TEXT NOT NULL,
  opciones_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  valor TEXT NOT NULL DEFAULT '',
  estado TEXT NOT NULL DEFAULT 'pendiente',
  nota_foto TEXT,
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- Tabla: lecturas_odometro
CREATE TABLE IF NOT EXISTS public.lecturas_odometro (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  km NUMERIC(10,2) NOT NULL,
  fecha TIMESTAMPTZ NOT NULL,
  origen TEXT NOT NULL,
  cambio_tablero BOOLEAN NOT NULL DEFAULT false,
  nota TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: tareas_mantenimiento
CREATE TABLE IF NOT EXISTS public.tareas_mantenimiento (
  id TEXT PRIMARY KEY,
  zona TEXT NOT NULL,
  titulo TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  intervalo_km NUMERIC(10,2),
  intervalo_dias INTEGER,
  ultimo_km NUMERIC(10,2),
  ultima_fecha TIMESTAMPTZ,
  hecho_por TEXT,
  ultimo_costo NUMERIC(10,2),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: registros_servicio
CREATE TABLE IF NOT EXISTS public.registros_servicio (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  tarea_id TEXT NOT NULL REFERENCES public.tareas_mantenimiento(id) ON DELETE CASCADE,
  titulo_tarea TEXT NOT NULL,
  zona TEXT NOT NULL,
  km NUMERIC(10,2) NOT NULL,
  fecha TIMESTAMPTZ NOT NULL,
  realizado_por TEXT NOT NULL,
  costo NUMERIC(10,2) NOT NULL DEFAULT 0.0,
  notas TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: cargas_combustible
CREATE TABLE IF NOT EXISTS public.cargas_combustible (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  km NUMERIC(10,2) NOT NULL,
  litros NUMERIC(6,2) NOT NULL,
  costo NUMERIC(10,2) NOT NULL,
  fecha TIMESTAMPTZ NOT NULL,
  km_por_litro NUMERIC(6,2),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: mediciones_desgaste
CREATE TABLE IF NOT EXISTS public.mediciones_desgaste (
  id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  componente TEXT NOT NULL,
  unidad TEXT NOT NULL,
  valor NUMERIC(6,2) NOT NULL,
  minimo_seguro NUMERIC(6,2) NOT NULL,
  maximo_seguro NUMERIC(6,2),
  km NUMERIC(10,2) NOT NULL,
  fecha TIMESTAMPTZ NOT NULL,
  nota TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla: catalogo_refacciones
CREATE TABLE IF NOT EXISTS public.catalogo_refacciones (
  id TEXT PRIMARY KEY,
  sku TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  categoria TEXT NOT NULL,
  zona TEXT NOT NULL,
  precio_estimado NUMERIC(10,2) NOT NULL,
  depende_de_clave_ficha TEXT,
  valor_requerido TEXT,
  requiere_accesorio TEXT,
  notas TEXT,
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Políticas de Seguridad a Nivel de Fila (RLS) habilitadas por defecto
ALTER TABLE public.moto ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.datos_ficha ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lecturas_odometro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tareas_mantenimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registros_servicio ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cargas_combustible ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mediciones_desgaste ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_refacciones ENABLE ROW LEVEL SECURITY;
''';
}
