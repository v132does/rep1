CREATE OR REPLACE TYPE IT."TYP_MOVIMIENTOSTARJETA"                                          FORCE IS OBJECT
(
  -- Indica si es un mensaje de error
  error varchar2(1),
  -- Nombre de la respuesta
  nombreRespuesta varchar2(15),
  -- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
  -- Número y nombre de la tarjeta
  tarjeta varchar2(300),
  -- Tipo de tarjeta
  tipo varchar2(200),
  -- Código de la Moneda
  codigoMoneda varchar(3),
  -- Moneda de la Tarjeta
  moneda varchar2(100),
  -- Cuenta de Pago
  numeroCuenta varchar(15),
  -- Localidad
  localidad varchar2(35),
  -- Nombre del Cliente
  nombreCliente varchar2(120),
  -- Dirección
  direccion varchar2(80),
  -- Pago minimo
  pagoMinimo number(18),
  -- Vencimiento Actual
  vencimientoActual varchar2(8),
  -- Límite de Crédito
  limiteCredito number(18),
  -- fuw_obtenermovimientostarjetas
  fechaProximoCierre varchar2(8),
  -- Disponible
  disponible number(18),
  -- Deuda al Cierre Anterior
  deudaCierreAnterior number(18),
  -- Total de Débitos del mes
  totalDebitos number(18),
  -- Total de Créditos del mes
  totalCreditos number(18),
  -- Gastos Financieros
  gastosFinancieros number(18),
  -- Saldo Deuda Cuota
  deudaCuota number(18),
  -- Deuda Total
  deudaTotal number(18),
  -- Total Cashback
  cashbackTotal number(18),
  -- Fecha de última actualización de las operaciones de CashBack
  fechaCashback varchar2(8),
  -- Saldo de Puntos
  puntosDisponibles number(18),
  -- Puntos Canjeados
  puntosCanjeados number(18),
  -- Fecha del Cierre Anterior para las operaciones de Puntos Canjeados y Ganados
  fechaCierreAnterior varchar2(8),
  -- Listado de movimientos
  listaMovimientos typ_listaTarjetas,
  CONSTRUCTOR FUNCTION typ_movimientosTarjeta RETURN SELF AS RESULT
)
/

