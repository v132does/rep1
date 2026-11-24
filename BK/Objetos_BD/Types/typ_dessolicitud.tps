CREATE OR REPLACE TYPE IT."TYP_DESSOLICITUD"                                          AS OBJECT
(
   error                VARCHAR2(3),                      --Indicador de error
   nombreRespuesta      VARCHAR2(250),                    --Nombre del mensaje
   descripcionRespuesta VARCHAR2(4000),                    --Descripcion de la respuesta
   nro_solicitud        NUMBER(11),                       --Nro de la Solicitud
   cod_persona          VARCHAR2(10),                     --Codigo de Persona
   cod_modulo           NUMBER(3),                        --Códigode Modulo
   cod_modalidad        NUMBER(3),                        --Codigo de Modalidad
   des_modalidad        VARCHAR2(60),                     --Descripcion de modalidad
   cod_moneda           VARCHAR2(3),                      --Moneda
   monto                NUMBER(18,2),                     --Importe
   plazo                NUMBER(4),                        --Plazo
   cod_oficina          NUMBER(3),                        --Sucursal
   fec_inicio           DATE,                             --Fecha de la Solicitud
   can_documento        NUMBER(10),                       --Cantidad de documentos
   fec_pri_vencimiento  DATE,                             --Fecha de primer vencimiento
   cod_tasa             number(10),                       --Codigo de tasa
   val_tasa             number(18,2),                      --Valor de tasa
   fec_vencimiento      DATE,                              --Fecha de Envio
   descripcion          VARCHAR2(500),                    --Explicación
   tot_cargos           number(18,2),                     --Total Cargos
   tot_interes          number(18,2),                      --Total Interes
   tot_a_desembolsar    number(18,2),                      --Total a Desembolsar
   tot_prestamo         number(18,2),                      --Total Préstamo
  -- listaDescuotas       typ_descuotas,               --Detalles de Cuotas
   CONSTRUCTOR FUNCTION typ_dessolicitud RETURN SELF AS RESULT
)
/

