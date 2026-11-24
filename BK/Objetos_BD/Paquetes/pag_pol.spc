create or replace package it.pag_pol is

  -- Author  : CNOGUERA
  -- Created : 17/03/2015 02:41:24 p.m.
  -- Purpose : Actualizaciones de Pólizas de Seguros a partir de los datos proveídos por SEBAOT

  -- Funcion para el Alta de Póliza --
  /**
    Función a ser utilizado por el servicio Web para dar de alta en ITGF
    las solicitudes de seguro emitidas por la corredora.
  **/
  function fu_ins_poliza( p_codigo           in number,      -- Número de Solicitud en SEBAOT
                          p_cod_persona      in varchar2,    -- Documento de Identidad o RUC en SEBAOT
                          p_cod_ente         in number,      -- Código de Compañia en SEBAOT
                          p_cod_oficina      in number,      -- Código de Oficina en SEBAOT
                          p_canal            in varchar2,    -- Canal en SEBAOT
                          p_seccion          in varchar2,    -- Sección de la póliza en SEBAOT
                          p_sub_seccion      in varchar2,    -- Sub-Sección al que corresponde póliza.
                          p_nro_poliza       in varchar2,    -- Número de la Póliza.
                          p_producto         in varchar2,     -- Descripcion del Producto
                          p_mto_capital      in number,      -- Capital Asegurado.
                          p_mto_premio       in number,      -- Monto del premio de la póliza.
                          p_mto_prima        in number,      -- Monto de la prima de la póliza.
                          p_cuo_inicial      in number,      -- Monto de la cuota Inicial.
                          p_mto_cuota        in number,      -- Monto de la Cuota
                          p_can_cuota        in number,      -- Cantidad de Cuotas.
                          p_for_pago         in varchar2,    -- Forma de Pago.
                          p_fec_inicial      in date,        -- Fecha de inicio de Vigencia.
                          p_fec_final        in date,        -- Fecha de fin de Vigencia.
                          p_fec_propuesta    in date,        -- Fecha de ingreso de la propuesta.
                          p_fec_envio        in date,        -- Fecha de envío de la póliza a la aseguradora.
                          p_fec_entrega      in date,        -- Fecha de entrega de la póliza al Cliente.
                          p_observaciones    in varchar2,    -- Observaciones (Descripción del Riesgo).
                          p_estado           in varchar2,    -- Estado de la Póliza en SEBAOT
                          p_referencia       in varchar2,    -- Referencia del número de la póliza que fué renovada.
                          p_cod_usu_ges_interno in varchar2, -- Gestor Interno.
                          p_cod_irene        in varchar2,    -- Código Irene.
                          p_cod_moneda       in varchar2,    -- Código de la moneda
                          p_situacion        in varchar2,    -- Situación de la Póliza en SEBAOT
                          p_tip_movimiento   in varchar2,    -- Tipo de Movimiento de Seguro en SEBAOT
                          p_tip_anulacion    in varchar2,    -- Tipo de Anulación en SEBAOT
                          p_cod_sub_seccion  in varchar2 default null  -- codigo de la subseccion o detalle de la poliza
                        ) return typ_mensajeRespuesta;

  -- Funcion para la Actualizacion de la Póliza a Estado Emitida --
  /**
    Función a ser utilizado por el servicio Web para actualizar en ITGF
    las solicitudes de seguro cuyas pólizas se han emitido.
  **/
  function fu_act_pol_emitida( p_codigo           in number,       -- Número de Solicitud en SEBAOT
                               p_cod_persona      in varchar2,    -- Documento de Identidad o RUC en SEBAOT
                               p_cod_oficina      in number,      -- Código de Oficina en SEBAOT
                               p_seccion          in varchar2,    -- Sección de la póliza en SEBAOT
                               p_sub_seccion      in varchar2,    -- Sub-Sección al que corresponde póliza.
                               p_nro_poliza       in varchar2,    -- Número de la Póliza.
                               p_producto         in varchar2,    -- Descripcion del Producto
                               p_mto_capital      in number,      -- Capital Asegurado.
                               p_mto_premio       in number,      -- Monto del premio de la póliza.
                               p_mto_prima        in number,      -- Monto de la prima de la póliza.
                               p_cuo_inicial      in number,      -- Monto de la cuota Inicial.
                               p_mto_cuota        in number,      -- Monto de la Cuota
                               p_can_cuota        in number,      -- Cantidad de Cuotas.
                               p_for_pago         in varchar2,    -- Forma de Pago.
                               p_fec_inicial      in date,        -- Fecha de inicio de Vigencia.
                               p_fec_final        in date,        -- Fecha de fin de Vigencia.
                               p_fec_entrega      in date,        -- Fecha de entrega de la póliza al Cliente.
                               p_observaciones    in varchar2,    -- Observaciones (Descripción del Riesgo).
                               p_estado           in varchar2,    -- Estado de la Póliza en SEBAOT
                               p_referencia       in varchar2,    -- Referencia del número de la póliza que fué renovada.
                               p_cod_irene        in varchar2,    -- Código Irene.
                               p_cod_moneda       in varchar2,    -- Código de la moneda
                               p_situacion        in varchar2,    -- Situación de la Póliza en SEBAOT
                               p_tip_movimiento   in varchar2,    -- Tipo de Movimiento de Seguro en SEBAOT
                               p_tip_anulacion    in varchar2,     -- Tipo de Anulación en SEBAOT
                               p_fec_emision      in date
                             ) return typ_mensajeRespuesta;

  -- Funcion para la Actualizacion de la Póliza a Situacion Anulada --
  /**
    Función a ser utilizado por el servicio Web para actualizar en ITGF
    las solicitudes de seguro que cambian de Situación.
  **/
  function fu_act_sit_poliza( p_codigo      in number,      -- Número de Solicitud en SEBAOT
                              p_situacion   in varchar2    -- Situación de la Póliza en SEBAOT
                             ) return typ_mensajeRespuesta;

  -- Funcion para la Actualizacion de la Fecha de Entrega de la Póliza --
  /**
    Función a ser utilizado por el servicio Web para actualizar en ITGF
    las solicitudes que se entregaran a determinada fecha.
  **/
  function fu_act_ent_poliza( p_codigo       in number,   -- Número de Solicitud en SEBAOT
                              p_fec_entrega  in date      -- Fecha de entrega de la póliza al Cliente.
                            ) return typ_mensajeRespuesta;
  /**Funcion a ser utilizada por el servicio WEB para actualizar en ITGF
     las cuotas de las polizas enviadas por SEBAOT**/
  function fu_ins_cuota(  p_codigo           in number,               -- Numero de Solicitud en SEBAOT
                          p_nro_cuota        in number,               -- Numero de Cuota
                          p_monto            in number,               -- Monto de Cuota
                          p_fec_vencimiento  in date,                 -- Fecha de Vencimiento
                          p_observacion      in varchar2 default null --Observacion
                        ) return typ_mensajeRespuesta;
  /**Funcion a ser utilizada por el servicio WEB para actualizar en ITGF
     los cobros de las cuotas de las polizas enviadas por SEBAOT**/
  function fu_ins_cobro( p_codigo           in number,                -- Numero de Solicitud en SEBAOT
                          p_nro_cuota        in number,               -- Numero de Cuota
                          p_nro_pago         in number,               -- Numero de Pago(1,2,3...)
                          p_fec_cobro        in date,                 -- Fecha de Cobro
                          p_importe          in number,               -- Monto de Cuota
                          p_tip_cobro        in number,               -- Tipo de Cobro
                          p_nro_recibo       in number,               -- Nro.de Recibo
                          p_observacion      in varchar2 default null -- Observacion
                        ) return typ_mensajeRespuesta;

end pag_pol;
/

