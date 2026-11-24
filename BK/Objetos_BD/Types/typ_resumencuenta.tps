CREATE OR REPLACE TYPE IT."TYP_RESUMENCUENTA"                                          force                                        is OBJECT
(
-- Numero de la cuenta
  nroCuenta  varchar2(17),
-- Codigo de la cuenta
  codigoCuenta  varchar2(5),
 /*Codigo de tipo de cuenta
 *              <ul><li> <b>AH:</b> Ahorro a la Vista</li>
 *              <li> <b>CD:</b> CDA</li>
 *              <li> <b>AP:</b> Ahorros a Plazo Fijo</li>
 *              <li> <b>TI:</b> Titulos de Inversion</li>
 *              <li> <b>CC:</b> Cuenta Corriente</li>
 *              <li> <b>PT:</b> Prestamos</li>
 *              <li> <b>TJ:</b> Tarjetas</li>
 *              <li> <b>SV:</b> Sobregiros Vencidos</li>
 *              <li> <b>BA:</b> Venta a Plazo de Bienes Adjudicados</li></ul>
 */
  tipoCuenta  varchar2(2),
--Descripcion del tipo de cuenta
  descTipoCuenta  varchar2(35),
--Denominacion de la cuenta
  denominacion  varchar2(70),
--Codigo de la Moneda de la cuenta
  codMoneda  varchar2(16),
--Saldo Actual de la cuenta
   saldoActual  varchar2(16),
  --Indica la relacion de la cuenta con el usuario logueado  <ul><li> <b>P:</b> Principal </li><li> <b>Y:</b>Firmante conj.</li><li> <b>O:</b>Firmante ind.</li><li> <b>G:</b>Garante</li><li> <b>C:</b>codDeudor</li><li> <b>A:</b>Adicional</li></ul>
  relacion varchar2(1),
-- alias de la cuenta
   alias varchar2(200),     --NVB-2232
-- Modalidad
   codModalidad number(3),   --NVB-2232
-- Sud-Modalidad
   codSubModalidad number(3),  --NVB-2232
      CONSTRUCTOR FUNCTION typ_resumencuenta RETURN SELF AS RESULT
  )
/

