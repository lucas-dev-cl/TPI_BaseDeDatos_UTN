-- ==========================================
-- Insertar CATEGORÍAS
-- ==========================================
INSERT INTO categoria (nombre_categoria, descripcion_categoria) VALUES
('Pizzas', 'Pizzas artesanales a la piedra, individuales y grandes'),
('Empanadas', 'Empanadas caseras al horno y fritas, por docena'),
('Bebidas y Postres', 'Bebidas frías y postres caseros para acompañar el pedido');

-- ==========================================
-- Insertar PRODUCTOS
-- ==========================================
INSERT INTO producto (nombre_producto, precio_producto, descripcion_producto, stock_producto, imagen_producto, disponible_producto, id_categoria) VALUES
('Pizza Muzzarella', 3200.00, 'Pizza grande de muzzarella con aceitunas', 30, 'https://example.com/muzzarella.jpg', TRUE, 1),
('Pizza Napolitana', 3600.00, 'Pizza grande con muzzarella, tomate, ajo y albahaca', 20, 'https://example.com/napolitana.jpg', TRUE, 1),
('Empanadas de Carne (docena)', 4200.00, 'Docena de empanadas caseras de carne cortada a cuchillo', 100, 'https://example.com/empanadas.jpg', TRUE, 2),
('Flan Casero', 1500.00, 'Flan casero con dulce de leche y crema', 15, 'https://example.com/flan.jpg', TRUE, 3);

-- ==========================================
-- Insertar USUARIOS
-- ==========================================
INSERT INTO usuario (nombre_usuario, apellido_usuario, mail_usuario, contrasena_usuario, rol_usuario) VALUES
('Carlos', 'Gómez', 'carlos.gomez@email.com', '$2a$12$eImiTXuWVxfM37uY4JANjO39c8g6...hash', 'ADMIN'),
('Laura', 'Martínez', 'laura.martinez@email.com', '$2a$12$eImiTXuWVxfM37uY4JANjO39c8g6...hash', 'USUARIO'),
('Juan', 'Pérez', 'juan.perez@email.com', '$2a$12$eImiTXuWVxfM37uY4JANjO39c8g6...hash', 'USUARIO');

-- ==========================================
-- Insertar CELULARES (1:N con Usuario)
-- ==========================================
INSERT INTO celular (numero_celular, principal_celular, id_usuario) VALUES
('+5491122334455', TRUE, 1),   -- Teléfono principal de Carlos
('+5491199887766', FALSE, 1),  -- Teléfono secundario de Carlos
('+5491155667788', TRUE, 2),   -- Teléfono principal de Laura
('+5491133445566', TRUE, 3);   -- Teléfono principal de Juan

-- ==========================================
-- Insertar PEDIDOS
-- ==========================================
INSERT INTO pedido (fecha_pedido, estado_pedido, total_pedido, forma_pago_pedido, id_usuario) VALUES
(now() - INTERVAL '2 days', 'TERMINADO', 3600.00, 'TARJETA', 2),        -- Pedido de Laura
(now() - INTERVAL '1 day',  'CONFIRMADO', 7400.00, 'TRANSFERENCIA', 3), -- Pedido de Juan
(now(),                    'PENDIENTE',  1500.00, 'EFECTIVO', 2);      -- Pedido reciente de Laura

-- ==========================================
-- Insertar DETALLES DE PEDIDO
-- ==========================================
INSERT INTO detalle_pedido (cantidad_detalle_pedido, precio_unitario_detalle_pedido, id_pedido, id_producto) VALUES
-- Pedido 1 (Laura pidió 1 Pizza Napolitana)
(1, 3600.00, 1, 2),

-- Pedido 2 (Juan pidió 1 Pizza Muzzarella y 1 docena de Empanadas de Carne)
(1, 3200.00, 2, 1),
(1, 4200.00, 2, 3),

-- Pedido 3 (Laura pidió 1 Flan Casero)
(1, 1500.00, 3, 4);
