-- ============================================================================
-- CONCURRENCIA: AISLAMIENTO Y BLOQUEOS
-- ============================================================================
-- Estos escenarios necesitan DOS SESIONES simultáneas contra la misma base.
--
-- Cómo abrir dos sesiones:
--   · psql: dos terminales, cada uno con "psql -U <usuario> -d <base>".
--   · DBeaver: dos conexiones (o duplicar la conexión) abiertas en pestañas
--     distintas, con auto-commit DESACTIVADO en ambas (ícono del rayo).
--
-- Los pasos están numerados en el orden en que hay que ejecutarlos.
-- Cuando un paso dice "⏸ ESPERAR", no sigas con esa sesión hasta llegar
-- al paso que le corresponde más abajo.
-- ============================================================================


-- ============================================================================
-- 3) AISLAMIENTO — Lost Update: READ COMMITTED vs SERIALIZABLE
-- ============================================================================
-- Escenario: dos operadores leen el stock, calculan "stock - 1" y lo
-- graban, sin bloquear la fila (patrón típico de una app que hace
-- SELECT y después UPDATE por separado).

-- --- Preparación (ejecutar una sola vez, en cualquier sesión) ---
UPDATE producto SET stock_producto = 5 WHERE id_producto = 1;


-- ---------- CORRIDA A: READ COMMITTED (nivel por defecto) ----------

-- PASO 1 — SESIÓN A
BEGIN;
SELECT stock_producto FROM producto WHERE id_producto = 1;   -- A lee 5
-- ⏸ ESPERAR. No ejecutes todavía el UPDATE de A.

-- PASO 2 — SESIÓN B
BEGIN;
SELECT stock_producto FROM producto WHERE id_producto = 1;   -- B también lee 5
UPDATE producto SET stock_producto = 5 - 1 WHERE id_producto = 1;  -- B graba 4
COMMIT;

-- PASO 3 — SESIÓN A (retomar)
UPDATE producto SET stock_producto = 5 - 1 WHERE id_producto = 1;  -- A graba 4 (con el valor viejo que leyó)
COMMIT;

-- PASO 4 — verificar (cualquier sesión)
SELECT stock_producto FROM producto WHERE id_producto = 1;
-- Resultado: 4. Debería ser 3 (dos descuentos de a 1). Se "perdió" el
-- descuento de A porque no vio el cambio de B: esto es un LOST UPDATE,
-- posible bajo READ COMMITTED porque cada sentencia ve el commit más
-- reciente, pero A calculó su UPDATE con un dato que ya estaba viejo.


-- ---------- CORRIDA B: SERIALIZABLE ----------

-- --- Preparación: reiniciar el stock ---
UPDATE producto SET stock_producto = 5 WHERE id_producto = 1;

-- PASO 1 — SESIÓN A
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT stock_producto FROM producto WHERE id_producto = 1;   -- A lee 5
-- ⏸ ESPERAR.

-- PASO 2 — SESIÓN B
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT stock_producto FROM producto WHERE id_producto = 1;   -- B lee 5
UPDATE producto SET stock_producto = 5 - 1 WHERE id_producto = 1;  -- B graba 4
COMMIT;   -- B confirma sin problema

-- PASO 3 — SESIÓN A (retomar)
UPDATE producto SET stock_producto = 5 - 1 WHERE id_producto = 1;
-- Acá Postgres detecta que la fila cambió desde que A la leyó y
-- devuelve un error de tipo "could not serialize access due to
-- concurrent update". A NO puede grabar su cambio.
COMMIT;   -- falla / no hay nada que confirmar; corresponde hacer ROLLBACK

-- PASO 4 — verificar
SELECT stock_producto FROM producto WHERE id_producto = 1;
-- Resultado: 4, correcto (solo el descuento de B quedó aplicado).
-- Con SERIALIZABLE, Postgres evita el lost update: en vez de dejar
-- pasar el UPDATE de A con un dato desactualizado, aborta esa
-- transacción y obliga a reintentarla (leyendo el valor ya actualizado).


-- ============================================================================
-- 4) BLOQUEOS — SELECT ... FOR UPDATE evitando sobreventa
-- ============================================================================
-- Reutilizamos sp_crear_pedido tal cual está definido en objects.sql:
-- internamente hace "SELECT ... FOR UPDATE" sobre la fila del producto
-- antes de descontar stock, así que ya implementa el bloqueo por sí solo.

-- --- Preparación: dejar 1 sola unidad del producto 3 ---
UPDATE producto SET stock_producto = 1 WHERE id_producto = 3;

-- PASO 1 — SESIÓN A (compra la última unidad)
BEGIN;
CALL sp_crear_pedido(2, 'EFECTIVO', '[{"producto_id": 3, "cantidad": 1}]'::jsonb);
-- El FOR UPDATE dentro del procedimiento toma el lock de la fila del
-- producto 3 y lo retiene mientras la transacción de A siga abierta.
-- ⏸ ESPERAR. Todavía no hagas COMMIT en A.

-- PASO 2 — SESIÓN B (intenta comprar la misma última unidad)
BEGIN;
CALL sp_crear_pedido(3, 'EFECTIVO', '[{"producto_id": 3, "cantidad": 1}]'::jsonb);
-- Esta sesión queda BLOQUEADA (esperando) en el FOR UPDATE, porque A
-- todavía tiene la fila del producto 3 tomada. B no puede avanzar hasta
-- que A confirme o revierta.

-- PASO 3 — SESIÓN A (confirmar)
COMMIT;
-- Al confirmar A, se libera el lock. En ese instante B se desbloquea
-- automáticamente y continúa su CALL con el stock ya actualizado (0).

-- PASO 4 — SESIÓN B (se desbloquea sola)
-- Dentro del procedimiento, "IF v_stock < v_cantidad" ahora es TRUE
-- (stock=0, se pide 1), así que lanza:
--   RAISE EXCEPTION 'Stock insuficiente (producto %): hay %, se piden %'
-- y toda la transacción de B se revierte automáticamente. No hace
-- falta ROLLBACK manual: el CALL fallido ya deshizo lo suyo.

-- PASO 5 — verificar (cualquier sesión)
SELECT stock_producto FROM producto WHERE id_producto = 3;
-- Resultado: 0. Ninguna sobreventa: solo el pedido de A quedó creado.

SELECT COUNT(*) FROM detalle_pedido WHERE id_producto = 3;
-- Debe mostrar un solo detalle (el de A), no dos.
