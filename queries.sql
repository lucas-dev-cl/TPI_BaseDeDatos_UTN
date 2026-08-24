-- ============================================================================
-- ÉPICA 1: GESTIÓN DE CATEGORÍAS
-- ============================================================================

-- HU-CAT-01: Listar categorías vigentes
SELECT id_categoria, nombre_categoria, descripcion_categoria
FROM categoria
WHERE eliminado_categoria = FALSE
ORDER BY id_categoria;

-- HU-CAT-02: Crear una nueva categoría
INSERT INTO categoria (nombre_categoria, descripcion_categoria)
VALUES ('Empanadas', 'Variedad de empanadas al horno y fritas')
RETURNING id_categoria;

-- HU-CAT-03: Editar una categoría existente
UPDATE categoria
SET nombre_categoria = 'Pizzas y Empanadas',
    descripcion_categoria = 'Catálogo ampliado de masas'
WHERE id_categoria = 1 AND eliminado_categoria = FALSE;

-- HU-CAT-04: Eliminar categoría (Baja Lógica)
UPDATE categoria
SET eliminado_categoria = TRUE
WHERE id_categoria = 2 AND eliminado_categoria = FALSE;

-- ============================================================================
-- ÉPICA 2: GESTIÓN DE PRODUCTOS
-- ============================================================================

-- HU-PROD-01: Listar productos con su categoría
SELECT p.id_producto, p.nombre_producto, p.precio_producto, p.stock_producto,
       c.nombre_categoria AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.eliminado_producto = FALSE
-- AND p.id_categoria = 1 -- Filtro opcional por categoría
ORDER BY p.id_producto;

-- HU-PROD-02: Crear un producto asegurando categoría vigente
INSERT INTO producto (nombre_producto, descripcion_producto, precio_producto, stock_producto, imagen_producto, disponible_producto, id_categoria)
SELECT 'Fugazzeta', 'Pizza de cebolla y queso', 1800.00, 10, NULL, TRUE, c.id_categoria
FROM categoria c
WHERE c.id_categoria = 1 AND c.eliminado_categoria = FALSE
RETURNING id_producto;

-- HU-PROD-03: Editar producto (actualización parcial con COALESCE)
UPDATE producto
SET precio_producto = COALESCE(2000.00, precio_producto),
    stock_producto  = COALESCE(NULL, stock_producto)
WHERE id_producto = 1 AND eliminado_producto = FALSE;

-- HU-PROD-04: Eliminar producto (Baja Lógica)
UPDATE producto
SET eliminado_producto = TRUE
WHERE id_producto = 1 AND eliminado_producto = FALSE;

-- ============================================================================
-- ÉPICA 3: GESTIÓN DE USUARIOS
-- ============================================================================

-- HU-USR-01: Listar usuarios vigentes
SELECT id_usuario, nombre_usuario, apellido_usuario, mail_usuario, rol_usuario
FROM usuario
WHERE eliminado_usuario = FALSE
ORDER BY id_usuario;

-- HU-USR-02: Crear un nuevo usuario (el celular es una tabla aparte, 1:N con usuario)
INSERT INTO usuario (nombre_usuario, apellido_usuario, mail_usuario, contrasena_usuario)
VALUES ('Juan', 'Pérez', 'juan@x.com', 'hash')
RETURNING id_usuario; -- Lanza error de restricción UNIQUE si el mail ya existe

-- A continuación, se registra el celular asociado a ese id_usuario devuelto arriba
INSERT INTO celular (numero_celular, principal_celular, id_usuario)
VALUES ('2611234567', TRUE, 1); -- Reemplazar 1 por el id_usuario recién creado

-- HU-USR-03: Editar el celular principal de un usuario
UPDATE celular
SET numero_celular = '2617654321'
WHERE id_usuario = 1 AND principal_celular = TRUE AND eliminado_celular = FALSE;

-- HU-USR-04: Eliminar usuario (Baja Lógica)
UPDATE usuario
SET eliminado_usuario = TRUE
WHERE id_usuario = 1 AND eliminado_usuario = FALSE;

-- ============================================================================
-- ÉPICA 4: GESTIÓN DE PEDIDOS Y DETALLES
-- ============================================================================

-- HU-PED-01: Listar pedidos
SELECT id_pedido, usuario, fecha_pedido, estado_pedido, forma_pago_pedido, total_pedido
FROM v_pedidos_resumen
-- WHERE usuario = 'Ana Garis' -- Filtro opcional
ORDER BY id_pedido;

-- HU-PED-02: Crear pedido con detalles (invocación del Stored Procedure)
-- Nota: 'subtotal' no se persiste en detalle_pedido, se calcula (cantidad_detalle_pedido * precio_unitario_detalle_pedido)
CALL sp_crear_pedido(
    1, -- id_usuario (debe estar vigente)
    'EFECTIVO',
    '[{"producto_id": 1, "cantidad": 2}, {"producto_id": 2, "cantidad": 1}]'::jsonb
);

-- HU-PED-03: Actualizar estado y/o forma de pago de un pedido
UPDATE pedido
SET estado_pedido = 'CONFIRMADO',
    forma_pago_pedido = 'TARJETA'
WHERE id_pedido = 1 AND eliminado_pedido = FALSE;

-- HU-PED-04: Eliminar pedido y sus detalles (Baja Lógica en Transacción)
BEGIN;
    UPDATE detalle_pedido
    SET eliminado_detalle_pedido = TRUE
    WHERE id_pedido = 1;

    UPDATE pedido
    SET eliminado_pedido = TRUE
    WHERE id_pedido = 1;
COMMIT;
