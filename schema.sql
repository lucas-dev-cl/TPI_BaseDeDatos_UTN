-- ==========================================
-- Tipos enumerados
-- ==========================================
CREATE TYPE rol AS ENUM ('ADMIN', 'USUARIO');
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE', 'CONFIRMADO', 'TERMINADO', 'CANCELADO');
CREATE TYPE forma_pago AS ENUM ('TARJETA', 'TRANSFERENCIA', 'EFECTIVO');

-- ==========================================
-- Tabla CATEGORIA
-- ==========================================
CREATE TABLE categoria (
    id_categoria          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_categoria      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion_categoria VARCHAR(255),
    eliminado_categoria   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at_categoria  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Índice parcial para categorías activas por nombre
CREATE INDEX idx_nombre_categoria ON categoria (nombre_categoria) 
WHERE eliminado_categoria = FALSE;


-- ==========================================
-- Tabla PRODUCTO
-- ==========================================
CREATE TABLE producto (
    id_producto          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_producto      VARCHAR(120) NOT NULL,
    precio_producto      NUMERIC(10,2) NOT NULL CHECK (precio_producto >= 0),
    descripcion_producto VARCHAR(255),
    stock_producto       INTEGER      NOT NULL DEFAULT 0 CHECK (stock_producto >= 0),
    imagen_producto      VARCHAR(255),
    disponible_producto  BOOLEAN      NOT NULL DEFAULT TRUE,
    id_categoria         BIGINT       NOT NULL REFERENCES categoria(id_categoria),
    eliminado_producto   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at_producto  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Índice parcial para productos activos por categoría
CREATE INDEX idx_id_y_categoria_vigente ON producto (id_categoria) 
WHERE eliminado_producto = FALSE OR disponible_producto = TRUE;


-- ==========================================
-- Tabla USUARIO
-- ==========================================
CREATE TABLE usuario (
    id_usuario          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_usuario      VARCHAR(80)  NOT NULL,
    apellido_usuario    VARCHAR(80)  NOT NULL,
    mail_usuario        VARCHAR(120) NOT NULL UNIQUE,
    contrasena_usuario  VARCHAR(255) NOT NULL,
    rol_usuario         rol          NOT NULL DEFAULT 'USUARIO',
    eliminado_usuario   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at_usuario  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Índice parcial para administradores activos
CREATE INDEX idx_admin ON usuario (rol_usuario) 
WHERE rol_usuario = 'ADMIN' AND eliminado_usuario = FALSE;


-- ==========================================
-- Tabla CELULAR (Relación 1:N con Usuario)
-- ==========================================
CREATE TABLE celular (
    id_celular          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_celular      VARCHAR(30)  NOT NULL,
    principal_celular   BOOLEAN      NOT NULL DEFAULT FALSE,
    id_usuario          BIGINT       NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    eliminado_celular   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at_celular  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (numero_celular, id_usuario)
);

-- Índice parcial para buscar teléfonos vigentes de un usuario
CREATE INDEX idx_celular_usuario ON celular (id_usuario) 
WHERE eliminado_celular = FALSE;


-- ==========================================
-- Tabla PEDIDO
-- ==========================================
CREATE TABLE pedido (
    id_pedido          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_pedido       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    estado_pedido      estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    total_pedido       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_pedido >= 0),
    forma_pago_pedido  forma_pago    NOT NULL,
    id_usuario         BIGINT        NOT NULL REFERENCES usuario(id_usuario),
    eliminado_pedido   BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at_pedido  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Índice parcial para pedidos por usuario ordenados por fecha
CREATE INDEX idx_pedido_usuario_fecha ON pedido (id_usuario, fecha_pedido) 
WHERE eliminado_pedido = FALSE;


-- ==========================================
-- Tabla DETALLE_PEDIDO
-- ==========================================
CREATE TABLE detalle_pedido (
    id_detalle_pedido               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cantidad_detalle_pedido          INTEGER       NOT NULL CHECK (cantidad_detalle_pedido > 0),
    precio_unitario_detalle_pedido  NUMERIC(10,2) NOT NULL CHECK (precio_unitario_detalle_pedido >= 0),
    id_pedido                       BIGINT        NOT NULL REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
    id_producto                     BIGINT        NOT NULL REFERENCES producto(id_producto),
    eliminado_detalle_pedido        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at_detalle_pedido       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (id_pedido, id_producto)
);

-- Índice parcial para detalles vigentes por producto
CREATE INDEX idx_detalle_producto ON detalle_pedido (id_producto) 
WHERE eliminado_detalle_pedido = FALSE;