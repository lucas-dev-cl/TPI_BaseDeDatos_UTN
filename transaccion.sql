-- ============================================================================
-- 1. PRUEBA DE ATOMICIDAD (ROLLBACK AUTOMÁTICO EN SP)
-- ============================================================================

-- A) Verificar cantidad actual de pedidos
SELECT COUNT(*) AS total_pedidos_antes FROM pedido;

-- B) Ejecutar el procedimiento con un item inválido (cantidad = 0)
-- Debe lanzar una excepción / error.
CALL sp_crear_pedido(
    1,
    'EFECTIVO',
    '[{"producto_id": 1, "cantidad": 2}, {"producto_id": 1, "cantidad": 0}]'::jsonb
);

-- C) Verificar que NO se creó ningún pedido (el contador debe ser igual al inicial)
SELECT COUNT(*) AS total_pedidos_despues FROM pedido;

-- ============================================================================
-- 2. PRUEBA DE TRANSACCIÓN MANUAL (COMMIT VS ROLLBACK)
-- ============================================================================

-- --- CASO A: Secuencia con COMMIT ---
BEGIN;
    UPDATE producto SET precio_producto = 2500.00 WHERE id_producto = 1;
COMMIT;

-- Verificación: El precio SE ACTUALIZÓ a 2500.00
SELECT id_producto, nombre_producto, precio_producto FROM producto WHERE id_producto = 1;


-- --- CASO B: Secuencia con ROLLBACK ---
BEGIN;
    UPDATE producto SET precio_producto = 99999.00 WHERE id_producto = 1;
    -- Verificamos el cambio temporal dentro de la transacción
    SELECT id_producto, nombre_producto, precio_producto FROM producto WHERE id_producto = 1;
ROLLBACK;

-- Verificación: El precio VOLVIÓ a ser 2500.00 (se deshizo el cambio)
SELECT id_producto, nombre_producto, precio_producto FROM producto WHERE id_producto = 1;
