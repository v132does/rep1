create or replace package it.pap_ser is
--TRFS-1331
v_tra_spi          varchar2(1) :='N';
v_mod_estado       ba_modulos.estado%TYPE;
/*funcion para controlar los limites de la operacion en relacion a la persona*/
  function fu_control_limite(p_cod_persona varchar2,
                             p_mon_bcp     number,
                             p_monto       number) return varchar2;

  FUNCTION fu_obt_deu_prest_cta(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                                p_moneda     IN ba_monedas.cod_mon_bco_central%TYPE)
    RETURN varchar2;

  /*cobro de cuota de prestamo cnb*/
  procedure pr_gen_cob_cuotas(p_cod_ente   in number,
                              p_mov_id     in varchar2,
                              p_nro_cuenta in varchar2,
                              p_cod_moneda in ba_monedas.cod_mon_bco_central%type,
                              p_monto      in number,
                              p_cod_error  out number,
                              p_msj_error  out varchar2);
  ---------------------------------------------------------------------------------------------
  /*procedimiento para obtener datos basicos de la persona*/
  procedure pr_obt_dat_persona(p_cod_pais             in number,
                               p_tip_documento        in number,
                               p_nro_documento        in varchar2,
                               p_cod_persona          out varchar2,
                               p_pri_nombre           out varchar2,
                               p_seg_nombre           out varchar2,
                               p_pri_apellido         out varchar2,
                               p_seg_apellido         out varchar2,
                               p_cod_sexo             out varchar2,
                               p_cod_pai_nacionalidad out number,
                               p_fec_nacimiento       in out date,
                               p_fec_vto_documento    out date,
                               p_telefono             in out varchar2,
                               p_email                out varchar2,
                               p_direccion            out varchar2,
                               p_cod_profesion        out number,
                               p_desc_prof            out varchar2,
                               p_desc_prof_ing        out varchar2,
                               p_tip_operacion        in varchar2,
                               p_cod_error            out number,
                               p_msj_error            out varchar2);
  ------------------------------------------------------------------------------------------                              
  --Procedimiento para generacion de pagos TC
  procedure pr_gen_pag_tarjetas(p_cod_ente    in varchar2,
                                p_monto       in number,
                                p_mon_bcp     in varchar2,
                                p_mov_id      in varchar2,
                                p_cuenta_tarj in varchar2,
                                p_error       out number,
                                p_respuesta   out varchar2);
  ------------------------------------------------------------------------------------------
  procedure pr_ver_mov_cnb_diario(p_cod_persona   in varchar2,
                                  p_nro_cuenta    in varchar2,
                                  p_cod_ente      in ge_entes.cod_ente%type,
                                  p_mon_bcp       in number,
                                  p_monto         in number,
                                  p_tip_operacion in varchar2,
                                  p_mto_total_gs  out number,
                                  p_mto_total_ext out number,
                                  p_mto_total     out number,
                                  p_mto_limite    out number,
                                  p_error         out number,
                                  p_respuesta     out varchar2);
  ------------------------------------------------------------------------------------------
  function fu_obt_lim_ente(p_cod_ente      in number,
                           p_cod_moneda    in varchar2,
                           p_tipo_servicio in varchar2) return number;

  procedure pr_val_per_excepcion(p_nro_documento     in VARCHAR2,
                                 p_cod_pais          in NUMBER,
                                 p_cod_tip_documento in NUMBER,
                                 p_primer_nombre     in VARCHAR2,
                                 p_segundo_nombre    in VARCHAR2,
                                 p_primer_apellido   in VARCHAR2,
                                 p_segundo_apellido  in VARCHAR2,
                                 p_tipo_cliente      in VARCHAR2,
                                 p_cod_error         out number,
                                 p_msj_error         out varchar2,
                                 p_retorno_persona   out varchar2);

  procedure pr_ver_sal_extracciones(p_nro_cuenta     in varchar2,
                                    p_monto          in number,
                                    p_mon_bcp        in number,
                                    p_respuesta      out varchar2,
                                    p_error          out number,
                                    p_mon_operacion  out number,
                                    p_sal_disponible out number);

  procedure pr_obt_mto_comision(p_cta_credito  in varchar2,
                                p_cod_moneda   in number,
                                p_mto_comision out number,
                                p_cod_error    out number,
                                p_msj_error    out varchar2);

  procedure pr_gen_mov_deposito(p_cod_ente       in number,
                                p_monto          in number,
                                p_nro_cuenta     in varchar2,
                                p_cod_moneda_bcp in ba_monedas.cod_mon_bco_central%type,
                                p_mov_id         in varchar2,
                                p_cod_error      out number,
                                p_msj_error      out varchar2);

  procedure pr_gen_pin_extracciones(p_cod_persona in varchar2,
                                    p_nro_celular in varchar2,
                                    p_pin         out number,
                                    p_respuesta   out varchar2);

  FUNCTION fu_cal_deu_prestamo(p_nro_cuenta IN pr_cuotas.nro_cuenta%TYPE,
                               p_cuota      IN pr_cuotas.nro_cuota%TYPE)
    RETURN varchar2;

  procedure pr_obt_saldo_cuenta(p_cod_ente       in ge_entes.cod_ente%type,
                                p_cod_moneda_bcp in ba_monedas.cod_mon_bco_central%type,
                                p_sal_disponible out ah_cta_vistas.sal_total%type,
                                p_cod_error      out number,
                                p_msj_error      out varchar2);

  procedure pr_gen_extraccion(p_cod_ente    in number,
                              p_cod_persona in varchar2,
                              p_mon_bcp     in number,
                              p_monto       in number,
                              p_nro_cuenta  in varchar2,
                              p_mov_id      in varchar2,
                              p_error       out number,
                              p_respuesta   out varchar2);
---------------------------------------------------------------------------------------------  
  procedure pr_cta_control(p_nro_cuenta    in ge_cuentas.nro_cuenta%type,
                           p_nro_documento in ba_personas.nro_documento%type,
                           p_monto         in number,
                           p_moneda        in number,
                           p_nombre        in varchar2,
                           p_apellido      in varchar2,
                           p_cod_swf       in varchar2,
                           p_cod_error     out number,
                           p_msj_error     out varchar2);
---------------------------------------------------------------------------------------------
  function fu_bus_men_error(p_codigo in number) return varchar2;                           
---------------------------------------------------------------------------------------------                                                          
  /*procedimiento para obtener los datos en caso de que deba imprimir declaracion jurada Sin Inserts*/
  procedure pr_obt_datos_dec_jur(p_cod_persona     in varchar2,
                                 p_moneda_bcp      in number,
                                 p_monto           in number,
                                 p_fecha_mov       in date,
                                 p_nombre          out varchar2,
                                 p_nro_doc_cliente out varchar2,
                                 p_nacionalidad    out varchar2,
                                 p_direccion       out varchar2,
                                 p_ciudad          out varchar2,
                                 p_ingreso         out number,
                                 p_egreso          out number,
                                 v_respuesta       out varchar2,
                                 v_importe_usd     out number);
------------------------------------------------------------------------------------------
  procedure pr_act_dat_apn(p_mtcn           in varchar2,
                           p_referencia     in varchar2,
                           p_cod_err_ope    in number, --workflow 1000
                           p_est_transf     in varchar2, --estado de la transferencia ge_snp_transferencia
                           p_est_notificado in varchar2, -- Notificado
                           p_cod_err_not    in varchar2, -- respuesta del servicio ej 200 entonces update Confriamdp
                           p_sub_cod_error  in varchar2, --0000
                           p_desc_error     in varchar2, -- OK
                           p_cod_err        out number,
                           p_msj_error      out varchar2);
  ------------------------------------------------------------------------------------------
  procedure pr_ins_dat_apn(p_cod_mtcn        in varchar2,
                           p_referencia      in number,
                           p_fec_operacion   in date,
                           p_est_notificado  in varchar2,
                           p_fec_notificado  in date,
                           p_cod_err_not     in varchar2,
                           p_sub_cod_err_not in varchar2,
                           p_desc_err_not    in varchar2,
                           p_est_transf      in varchar2,
                           p_cod_err_ope     in number,
                           p_nom_solicitante in varchar2,
                           p_ape_solicitante in varchar2,
                           --p_doc_solicitante      in varchar2,
                           -- p_dir_solicitante      in varchar2,
                           --p_ciu_solicitante      in varchar2,
                           -- p_est_solicitante      in varchar2,
                           --p_cod_pos_solicitante  in varchar2,
                           --p_cod_pai_solicitante  in varchar2,
                           p_pri_nom_beneficiario in varchar2,
                           --p_seg_nom_beneficiario in varchar2,
                           p_ape_beneficiario in varchar2,
                           --p_fec_nac_beneficiario in date,
                           p_ciu_beneficiario in varchar2,
                           --p_tel_beneficiario     in varchar2,
                           p_est_beneficiario in varchar2,
                           p_doc_beneficiario in varchar2,
                           p_cta_beneficiario in varchar2,
                           p_mto_transf       in number,
                           p_cod_moneda       in varchar2,
                           p_cod_mot_transf   in varchar2,
                           p_swf_bco_destino  in varchar2,
                           --p_nomb_bco_destino     in varchar2,
                           p_des_mot_tranf in varchar2,
                           p_msgid         in varchar2,
                           p_pai_sol       in varchar2,
                           p_cod_err       out number,
                           p_msj_error     out varchar2);  

--------------------------------------------------------------------------------
  procedure pr_gen_apn_tra_fielco(p_nom_beneficiario      in varchar2,
                                  p_ape_beneficiario      in varchar2,
                                  p_ciu_beneficiario      in VARCHAR2,
                                  p_est_beneficiario      in VARCHAR,
                                  p_nro_doc_beneficiario  in VARCHAR2,
                                  p_cta_beneficiario      in VARCHAR2,
                                  p_cod_swift             in varchar2,
                                  p_nom_remitente         in VARCHAR,
                                  p_ape_remitente         in VARCHAR,
                                  p_tra_monto             in number,
                                  p_tra_moneda            in VARCHAR2, --formato iso
                                  p_cod_motivo            in VARCHAR2,
                                  p_des_motivo            in varchar2,
                                  p_cod_mtcn              in varchar2,
                                  p_msgid                 in varchar2,
                                  p_pai_sol               in varchar2,
                                  p_cod_error             out number,
                                  p_respuesta             out varchar2,
                                  p_est_transferencia     out varchar2,
                                  p_des_est_transferencia out varchar2);

 --------------------------------------------------------------------------------
  function fu_obt_men_estado(p_cod in varchar2) return varchar2;
 --------------------------------------------------------------------------------
  /*procedimiento para obtener los datos en caso de que deba imprimir declaracion jurada*/
  procedure pr_obt_datos_dec_jurada(p_cod_persona     in varchar2,
                                    p_moneda_bcp      in number,
                                    p_monto           in number,
                                    p_fecha_mov       in date,
                                    p_movimiento_id   in number,
                                    p_nombre          out varchar2,
                                    p_nro_doc_cliente out varchar2,
                                    p_nacionalidad    out varchar2,
                                    p_direccion       out varchar2,
                                    p_ciudad          out varchar2,
                                    p_ingreso         out number,
                                    p_egreso          out number,
                                    p_respuesta       out varchar2);   

  -------------------------------------------------------------------------------
  procedure pr_gen_apn_tra_sipap(p_nom_sol               in varchar2,
                                 p_ape_sol               in varchar2,
                                 p_nom_ben               in varchar2,
                                 p_ape_ben               in varchar2,
                                 p_nro_doc_ben           in varchar2,
                                 p_ciu_ben               in varchar2,
                                 p_est_ben               in varchar2,
                                 p_cta_ben               in varchar2,
                                 p_cod_swf_ben           in varchar2,
                                 p_monto                 in ge_snp_transferencias.monto%type,
                                 p_moneda                in ba_monedas.cod_mon_iso%type,
                                 p_cod_mot               in it.ge_apn_datos.cod_mot_transf%type,
                                 p_fec                   in date,
                                 p_mtcn                  in it.ge_apn_datos.cod_mtcn%type,
                                 p_des_motivo            in varchar2,
                                 p_hora                  in varchar2,
                                 p_msgid                 in varchar2,
                                 p_pai_sol               in varchar2,
                                 p_est_transferencia     out varchar2,
                                 p_des_est_transferencia out varchar2,
                                 p_cod_error             out number,
                                 p_msj_error             out varchar2);

--------------------------------------------------------------------------------
  function fu_ver_mov_es_tra_apn(p_mtcn              in varchar2,
                                 p_referencia        in varchar2,
                                 p_tip_transferencia in varchar2)
    return varchar2;                                                                                                                                                                

  procedure pr_gen_pag_ser_app(p_cod_serv   in number,
                               p_cod_proc   in number,
                               p_monto_op   in number,
                               p_moneda     in number,
                               p_mov_id     in varchar2,
                               p_cta_ahorro in varchar2,
                               p_error      out number,
                               p_respuesta  out varchar2);   

  procedure pr_gen_rev_operaciones(p_referencia in varchar2,
                                   p_cod_error  out number,
                                   p_msj_error  out varchar2);
  
  procedure pr_obt_usu_hor_rev_wepa(p_usuario    in varchar2,
                                    p_usu_mov    out varchar2,
                                    p_hor_mov    out varchar2);
  
  procedure pr_gen_rev_ope_wepa(p_mov_id    in varchar2,
                                p_cod_error out number,
                                p_msj_error out varchar2);  
                                   
   /*Actualizacion de transaccion para pagos de servicios por bancard*/
  procedure pr_act_cod_tra_bancard(p_movimiento_id   in number,
                                   p_cod_servicio    in number,
                                   p_nro_transaccion in number,
                                   p_cod_error       out number,
                                   p_msj_error       out varchar2);   
                                   
  procedure pr_gen_pag_ser_fielco(p_cod_ente      in varchar2,
                                  p_cod_serv      in number,
                                  p_cod_proc      in number,
                                  p_monto_op      in number,
                                  p_moneda        in number,
                                  p_tip_ser       in varchar2,
                                  p_mov_id        in varchar2,
                                  p_usuario       in varchar2,
                                  p_nro_documento in varchar2,
                                  p_nombre        in varchar2,
                                  p_error         out number,
                                  p_respuesta     out varchar2,
                                  p_nro_factura   out varchar2);
                                  
  PROCEDURE lp_reg_persona(p_nombre        in varchar2,
                           p_nro_documento in varchar2);
                           
  procedure pr_gen_fac_ope(p_referencia in varchar2,
                           p_persona    in varchar2,
                           p_tipo_ente  in number,
                           p_cod_error  out number,
                           p_msj_error  out varchar2,
                           p_factura    out varchar2);

end pap_ser;
/
