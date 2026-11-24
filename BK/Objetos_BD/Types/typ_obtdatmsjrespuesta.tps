CREATE OR REPLACE TYPE IT."TYP_OBTDATMSJRESPUESTA"                                          AS OBJECT
(nro_referencia                           VARCHAR2(33),  --Nro de referencia del mensaje que se recibe(ref bcp)
 nro_ref_externa                          VARCHAR2(33),  --Nro de referencia del mensaje que se esta respondiendo para caso de pacs.028( viene pacs.008)
 cod_msj_mx                               VARCHAR2(20),  --Version del tipo de mensaje que se recibe
 fec_valor                                DATE,
 msj_mx                                   VARCHAR2(4000),--Mensaje mx(xml)
 cod_moneda                               VARCHAR2(3),   --Moneda del mensaje( solo se utiliza para algunos mensajes
 monto                                    NUMBER(18,2),
 tip_msj_original                         VARCHAR2(20),  --Version del tipo de mensaje que se esta respondiendo con el mensaje que se recibe(para respuesta del pacs.028, se recibe la version del pacs.008)
 res_procesamiento                        VARCHAR2(4),   --ACSP o RJCT(para caso de tip msj original pacs.028 o pacs.008
 cod_motivo_rechazo                       VARCHAR2(8),
 mot_rechazo                              VARCHAR2(200),
 nro_ref_relacionado                      VARCHAR2(33),  --Nro referencia del mensaje que se esta respondiendo(ej:pacs028)
 tip_msj_relacionado                      VARCHAR2(20),  --Version del tipo de mensaje(pacs.028)
 can_lim_establecido                      NUMBER(18,2),  --Cantidad de Limite establecido. (para camt.010)
 can_lim_utilizada                        NUMBER(18,2),  --Cantidad de Limite utilizada. (para camt.010)
 por_lim_utilizado                        NUMBER(6,2),   --Porcentaje de limite utilizado. (para camt.010)
 fec_informe                              DATE,          --Fecha y hora de creación del informe - (camt.052)
 nro_cta_informe                          VARCHAR2(35),  --Código de cuenta del participante - (camt.052)
 imp_saldo_cta                            NUMBER(18,2),  --Saldo actual de la cuenta de reserva - (camt.052)
 cant_tot_op_sesion                       VARCHAR2(20),  --Cantidad total de operaciones dentro de la sesión - (camt.052)
 mon_tot_op_sesion                        NUMBER(18,2),  --Monto total de operaciones dentro de la sesion - (camt.052)
 mon_res_deb_cre                          NUMBER(18,2),  --Monto total resultante de la diferencia debito - credito - (camt.052)
 cant_liq_credito                         VARCHAR2(10),  --Cantidad  de entradas de crédito - (camt.052)
 mon_liq_credito                          NUMBER(18,2),  --Monto liquidado por el credito - (camt.052)
 cant_liq_debito                          VARCHAR2(10),  --Cantidad de entradas de débito - (camt.052)
 mon_liq_debito                           NUMBER(18,2),  --Monto liquidado por el debito - (camt.052)
 id_sesion                                VARCHAR2(10),   --Número de Id de sesión - (camt.052)
 cod_estado                               VARCHAR2(40),  --estado
 cod_acept_rechazo                        VARCHAR2(8)    --Mensaje rechazado RJCR / Mensaje confirmado CNCL  - (camt.029);
 );
/

