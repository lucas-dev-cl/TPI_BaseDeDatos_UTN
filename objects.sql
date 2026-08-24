-- ==========================================
-- Vistas
-- ==========================================
CREATE VIEW v_productos_vigentes AS
SELECT p.id_producto, p.nombre_producto, p.precio_producto, p.stock_producto,
       c.nombre_categoria AS categoria
FROM   producto p
JOIN   categoria c ON c.id_categoria = p.id_categoria
WHERE  p.eliminado_producto = FALSE AND c.eliminado_categoria = FALSE;

CREATE VIEW v_pedidos_resumen AS
SELECT  ped.id_pedido,
        u.nombre_usuario || ' ' || u.apellido_usuario AS usuario,
        ped.fecha_pedido, ped.estado_pedido, ped.forma_pago_pedido, ped.total_pedido
FROM    pedido ped
JOIN    usuario u ON u.id_usuario = ped.id_usuario
WHERE   ped.eliminado_pedido = FALSE;

CREATE VIEW v_pedido_detalle AS
SELECT  dp.id_pedido,
        pr.nombre_producto AS producto,
        dp.cantidad_detalle_pedido AS cantidad,
        dp.precio_unitario_detalle_pedido AS precio_unitario
FROM    detalle_pedido dp
JOIN    producto pr ON pr.id_producto = dp.id_producto
WHERE   dp.eliminado_detalle_pedido = FALSE;

CREATE VIEW v_categorias_vigentes AS
SELECT id_categoria, nombre_categoria, descripcion_categoria
FROM   categoria
WHERE  eliminado_categoria = FALSE;

-- ==========================================
-- Función y triggers
-- ==========================================

CREATE OR REPLACE FUNCTION calcular_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(12,2) AS $$
    SELECT COALESCE(SUM(cantidad_detalle_pedido * precio_unitario_detalle_pedido), 0)
    FROM   detalle_pedido
    WHERE  id_pedido = p_pedido_id AND eliminado_detalle_pedido = FALSE;
$$ LANGUAGE sql STABLE;

-- AFTER ... FOR EACH STATEMENT: recalcula el total de los pedidos afectados
CREATE OR REPLACE FUNCTION fn_recalcular_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalcula el total de cada pedido afectado (una sola pasada por sentencia)
    UPDATE pedido p
    SET total_pedido = calcular_total_pedido(p.id_pedido)
    WHERE p.id_pedido IN (SELECT id_pedido FROM afectados);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Un trigger por evento: la transition table no admite
-- declarar varios eventos en un mismo CREATE TRIGGER
CREATE TRIGGER trg_total_ins
AFTER INSERT ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_recalcular_total();

CREATE TRIGGER trg_total_upd
AFTER UPDATE ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_recalcular_total();

-- ==========================================
-- Procedimiento
-- ==========================================

CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_usuario_id BIGINT,
    p_forma_pago forma_pago,
    p_items      JSONB   -- [{"producto_id":1,"cantidad":2}, ...]
) AS $$
DECLARE
    v_pedido_id   BIGINT;
    v_item        JSONB;
    v_producto_id BIGINT;
    v_cantidad    INTEGER;
    v_stock       INTEGER;
    v_disponible  BOOLEAN;
    v_precio      NUMERIC(10,2);
BEGIN
    -- El usuario debe existir y no estar eliminado
    IF NOT EXISTS (SELECT 1 FROM usuario
                  WHERE id_usuario = p_usuario_id AND eliminado_usuario = FALSE) THEN
        RAISE EXCEPTION 'Usuario % inexistente o eliminado', p_usuario_id;
    END IF;

    INSERT INTO pedido(id_usuario, forma_pago_pedido)
    VALUES (p_usuario_id, p_forma_pago)
    RETURNING id_pedido INTO v_pedido_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_producto_id := (v_item->>'producto_id')::BIGINT;
        v_cantidad    := (v_item->>'cantidad')::INTEGER;

        -- Bloquea la fila del producto para evitar sobreventa concurrente
        SELECT stock_producto, disponible_producto, precio_producto
        INTO   v_stock, v_disponible, v_precio
        FROM producto WHERE id_producto = v_producto_id AND eliminado_producto = FALSE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % inexistente o eliminado', v_producto_id;
        END IF;
        IF NOT v_disponible THEN
            RAISE EXCEPTION 'Producto % no disponible', v_producto_id;
        END IF;
        IF v_stock < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente (producto %): hay %, se piden %',
                            v_producto_id, v_stock, v_cantidad;
        END IF;

        INSERT INTO detalle_pedido(id_pedido, id_producto, cantidad_detalle_pedido, precio_unitario_detalle_pedido)
        VALUES (v_pedido_id, v_producto_id, v_cantidad, v_precio);

        -- Descuenta stock dentro de la misma transacción
        UPDATE producto SET stock_producto = stock_producto - v_cantidad WHERE id_producto = v_producto_id;
    END LOOP;
    -- Si alguna inserción falla, toda la transacción se revierte (rollback).
END;
$$ LANGUAGE plpgsql;
