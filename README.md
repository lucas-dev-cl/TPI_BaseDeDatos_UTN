# TPI Base de Datos — Guía de uso

Base de datos de un e-commerce simple: categorías, productos, usuarios (con sus
celulares), pedidos y detalles de pedido. Implementada en PostgreSQL.

## Estructura del repositorio

| Archivo | Contenido |
|---|---|
| `schema.sql` | Tipos ENUM, tablas, claves foráneas e índices. |
| `data.sql` | Datos semilla (seed) para poder probar el resto de los scripts. |
| `objects.sql` | Vistas, función, triggers y stored procedure. |
| `queries.sql` | Consultas de ejemplo, una por cada Historia de Usuario (HU). |
| `transaccion.sql` | Pruebas de atomicidad y de transacciones manuales (COMMIT/ROLLBACK). |
| `tpi_db_diagram.png` | Diagrama entidad-relación de referencia. |

## Orden de ejecución

Los scripts tienen dependencias entre sí, así que deben correrse en este orden:

1. **`schema.sql`** — crea los tipos ENUM y las tablas. Tiene que ejecutarse
   primero porque el resto de los scripts necesita que las tablas ya existan.
2. **`data.sql`** — carga los datos semilla (categorías, productos, usuarios,
   celulares, pedidos y detalles). A partir de acá ya hay datos con los que
   trabajar.
3. **`objects.sql`** — crea las vistas, la función de cálculo de totales, los
   triggers que la disparan y el stored procedure `sp_crear_pedido`. Estos
   objetos son los que usan varias de las consultas de `queries.sql`.
4. **`queries.sql`** — consultas de ejemplo que resuelven cada Historia de
   Usuario (listar, crear, editar, eliminar). No es necesario correr todo el
   archivo de una vez: cada bloque está identificado con su HU (`HU-CAT-01`,
   `HU-PROD-02`, etc.) para poder ejecutarlo de forma individual. En DBeaver,
   parado con el cursor sobre la sentencia deseada (o seleccionándola), usar
   `Execute SQL Statement` (`Ctrl+Enter` / `⌘+Enter`) en vez de ejecutar todo
   el script.
5. **`transaccion.sql`** — escenarios de prueba sobre atomicidad y control de
   transacciones (COMMIT/ROLLBACK), pensados para correrse después de tener
   la base ya poblada.

### Cómo crear la base desde cero (en DBeaver)

1. **Crear la conexión**: `Database > New Database Connection`, elegir
   PostgreSQL y completar host, puerto, usuario y contraseña. Si la base
   todavía no existe, conectarse primero a la base `postgres` por defecto y
   crearla con:
   ```sql
   CREATE DATABASE <nombre_base>;
   ```
   Después crear (o editar) la conexión para que apunte a esa base nueva.

2. **Abrir cada script**: con la conexión ya seleccionada en el panel de la
   izquierda, ir a `File > Open File...` (o simplemente arrastrar el archivo
   a la ventana de DBeaver) y abrir `schema.sql`. Esto lo abre en un SQL
   Editor ya asociado a esa conexión.

3. **Ejecutar el script completo**: con el archivo abierto, usar
   `Execute SQL Script` (ícono de flecha con varias rayitas, o `Alt+X` /
   `⌥+X` en Mac) para correr todas las sentencias del archivo de una sola
   vez, en orden. Repetir este paso en este orden:
   1. `schema.sql`
   2. `data.sql`
   3. `objects.sql`

   > Nota: usar siempre "Execute SQL Script" (todo el archivo) y no
   > "Execute SQL Statement" (una sola sentencia), salvo que quieras correr
   > un bloque puntual — ver más abajo.

Con esos tres pasos la base queda lista para ejecutar `queries.sql` y
`transaccion.sql` desde DBeaver.

## Cómo reproducir las pruebas de `transaccion.sql`

El archivo tiene dos partes independientes, pensadas para ejecutarse en orden
y observar el resultado de cada paso:

**1. Atomicidad del stored procedure**
Se llama a `sp_crear_pedido` con un ítem inválido (`cantidad = 0`, que viola
el `CHECK` de `detalle_pedido`). El conteo de pedidos antes y después del
`CALL` debe ser el mismo, porque al fallar una fila dentro del procedimiento
se revierte toda la transacción (ningún pedido ni detalle queda insertado).

**2. Transacciones manuales (COMMIT vs ROLLBACK)**
- *Caso A*: se actualiza el precio de un producto dentro de un
  `BEGIN...COMMIT`. Al confirmar, el cambio queda persistido.
- *Caso B*: se actualiza el mismo precio dentro de un `BEGIN...ROLLBACK`. El
  `SELECT` intermedio muestra el valor modificado *dentro* de la transacción,
  pero al hacer `ROLLBACK` el precio vuelve al valor anterior (el fijado en
  el Caso A).

Para reproducirlas en DBeaver hay dos formas:

- **Rápida**: abrir `transaccion.sql` y correr `Execute SQL Script`
  (`Alt+X` / `⌥+X`) para que se ejecute todo en orden y ver los resultados
  de cada `SELECT` en pestañas sucesivas del panel de resultados.
- **Paso a paso** (recomendada para ver bien el efecto de cada `SELECT`):
  ejecutar sentencia por sentencia con `Ctrl+Enter` / `⌘+Enter`, siguiendo
  el orden en que están escritas. Esto es útil sobre todo en el Caso B, para
  ver el valor "temporal" del precio antes del `ROLLBACK` y confirmar que
  después vuelve al anterior.

> Importante: DBeaver por defecto suele tener activado *auto-commit*. Para
> que los bloques `BEGIN ... COMMIT` / `BEGIN ... ROLLBACK` de este archivo
> se comporten como transacciones explícitas, conviene desactivar el
> auto-commit de la conexión (ícono con un rayo en la barra de la pestaña
> SQL, o `Edit Connection > PostgreSQL > desmarcar Auto-commit`) antes de
> correr esta prueba.

## Convención de nombres de columnas

Todas las columnas están nombradas como `<atributo>_<tabla>`
(por ejemplo `id_categoria`, `nombre_producto`, `eliminado_usuario`). Esto es
así para que ninguna columna quede ambigua cuando se hace `JOIN` entre varias
tablas: alcanza con ver el nombre de la columna para saber a qué tabla
pertenece, sin necesidad de calificarla con el alias.

Excepción: las columnas que son claves foráneas se llaman igual que la clave
primaria a la que referencian (por ejemplo `id_categoria` en `producto`,
`id_usuario` en `pedido` y `celular`), ya que de esa forma el nombre de la
columna ya indica con qué tabla se relaciona.
