CREATE OR REPLACE TYPE IT."TYP_TRANSFERENCIASLOTE"                                          IS OBJECT
(
  -- Author  : XPY0040
  -- Created : 26/09/2018 10:59:23 a.m.
  -- Purpose : Retorno de una solicitud de transferencia
  
  --Resultado de la consulta
  error                 VARCHAR2(1),
  --Codigo del resultado
  nombreRespuesta       VARCHAR2(15),
  --Descripcion del resultado
  descripcionRespuesta  VARCHAR2(200),
  -- Respuesta de limites de operaciones
  resLimite             VARCHAR2(2),
  --Numero de cuenta de debito
  numeroCuenta          varchar2(16),
  --Agrupados del lote
  NumeroLote            NUMBER(10),
  -- Suma de los montos cargados en este lote
  Total                 NUMBER(18, 2),
  -- Cantidad pagaos cargados en este lote  
  Cantidad              NUMBER(5),
 -- listado de transferencias
  ListaTransferencias TYP_LISTATRANSFERENCIALOTE,
  CONSTRUCTOR FUNCTION TYP_TRANSFERENCIASLOTE RETURN SELF AS RESULT
)
/

