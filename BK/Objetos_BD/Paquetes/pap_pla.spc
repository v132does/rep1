CREATE OR REPLACE PACKAGE IT.PAP_PLA is
  /**
   Creacion: 21/12/2020
   Descripcion: Paquete de Procesamiento de Prestamo para proveer a la plataforma
  **/
  v_cod_msg_exito number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_pro_cor_pen   number := nvl(fug_obt_pardinamico('COD_MEN_PRO_PEN'), 1);
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;

  /** Obtiene datos de la deuda para la plataforma **/
  procedure pr_obt_deu_pre_plataforma(p_nro_cuenta       in pr_cta_prestamos.nro_cuenta%type,
                                      p_cuo_desde        in pr_cuotas.nro_cuota%type,
                                      p_cuo_hasta        in pr_cuotas.nro_cuota%type,
                                      p_mto_capital      out pr_cuotas.mto_capital%type,
                                      p_mto_interes      out pr_cuotas.mto_interes%type,
                                      p_mto_int_ade      out pr_cuotas.mto_interes%type,
                                      p_mto_cargos       out pr_cuotas.sal_capital%type,
                                      p_mto_pagar        out pr_cuotas.sal_capital%type,
                                      p_dia_mora         out pr_cobros.dia_mora%type,
                                      p_mto_mora         out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_mora_int     out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_mora_int_ade out pr_cobros.mto_int_mor_interes%type,
                                      p_mto_punitor      out pr_cobros.mto_int_punitorio%type,
                                      p_mto_impuest      out pr_cobros.mto_impuesto%type,
                                      p_mto_cargo        out pr_cobros.mto_cargo%type,
                                      p_tot_car_iva      out pr_cobros.mto_cargo%type,
                                      p_mto_descont      out pr_cobros.mto_int_documentado%type,
                                      p_mto_iva_dev      out pr_cobros.mto_int_documentado%type,
                                      p_cod_error        out number,
                                      p_men_error        out varchar2);

  /** Realiza el cobro de cuotas del prestamo **/
  procedure pr_cob_pre_plataforma(p_nro_cuenta       in pr_cta_prestamos.nro_cuenta%type,
                                  p_nro_cta_debito   in pr_cta_prestamos.nro_cta_debito%type,
                                  p_mto_cobrado      in pr_cobros.mto_capital%type,
                                  p_cuo_desde        in pr_cuotas.nro_cuota%type,
                                  p_cuo_hasta        in pr_cuotas.nro_cuota%type,
                                  p_concepto         in pr_cta_prestamos.descripcion%type,
                                  p_cod_error        out number,
                                  p_men_error        out varchar2,
                                  p_pag_parcial      in varchar2,
                                  p_pago_funcionario in varchar2 default 'N',
                                  p_cod_canal        in varchar2 default 'N',
                                  p_for_pago         in varchar2 default null,
                                  p_modo             in varchar2 default 'C');

  /** Actualiza el nro de cuenta para debito automatico del prestamo **/
  procedure pr_act_cta_deb_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_cod_error      out number,
                                      p_men_error      out varchar2);

  /** Cancelacion de Prestamo por plataforma **/
  procedure pr_can_pre_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                  p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                  p_cod_canal      in varchar2 default 'N',
                                  p_cod_error      out number,
                                  p_men_error      out varchar2);
  /**Calculo de Cuota por plataforma**/
  procedure pr_cal_cuo_plataforma(p_tip_prestamo    in varchar2 default 'CONSUMO', --CONSUMO, HIPOTECARIO, ETC
                                  p_cod_moneda      in varchar2,
                                  p_dia_vencimiento in number, --1, 10, 15 (vto cada mes)
                                  p_monto           in number,
                                  p_can_cuotas      in number,
                                  p_mto_cuota       out number,
                                  p_error           out varchar2);
  /**Genera la solicitud de prestamo**/
  PROCEDURE pr_gen_sol_con_plataforma(p_cod_persona         IN VARCHAR2, -- codigo de la persona,
                                      p_tipo_prestamo       IN VARCHAR2, -- tipo de credito
                                      p_cod_moneda          IN VARCHAR2, -- moneda
                                      p_monto               IN NUMBER, -- monto del credito
                                      p_can_cuotas          IN NUMBER, -- nro de cuotas
                                      p_fec_pri_vencimiento IN DATE DEFAULT NULL, -- primer vencimiento
                                      p_nro_solicitud       OUT pr_solicitudes.nro_solicitud%TYPE,
                                      p_cod_error           OUT NUMBER, -- 0 = Exito
                                      p_msj_error           OUT VARCHAR2);

  /**Actualiza el estado a pendiente de aprobacion**/
  PROCEDURE pr_act_sol_con_plataforma(p_nro_solicitud in pr_solicitudes.nro_solicitud%TYPE,
                                      p_cod_canal     in varchar2 default 'N',
                                      p_cod_error     out number,
                                      p_men_error     out varchar2);

  /**Cancelacion anticipada de cuotas**/
  PROCEDURE pr_can_cuo_pre_plataforma(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_cuo_desde      in pr_cuotas.nro_cuota%type,
                                      p_cuo_hasta      in pr_cuotas.nro_cuota%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_monto          in pr_cta_prestamos.monto%type default null,
                                      p_cod_error      out number,
                                      p_men_error      out varchar2,
                                      p_modo           in varchar2 default 'C',
                                      p_notas          in varchar2 default null);

  /**Obtener deuda por monto**/
  PROCEDURE pr_obt_deu_pre_monto_plat(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_monto          in pr_cta_prestamos.sal_capital%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_cod_error      out number,
                                      p_men_error      out varchar2);

  /**Realizar cobro por monto**/
  PROCEDURE pr_cob_pre_monto_platafor(p_nro_cuenta     in pr_cta_prestamos.nro_cuenta%type,
                                      p_nro_cta_debito in pr_cta_prestamos.nro_cta_debito%type,
                                      p_monto          in pr_cta_prestamos.sal_capital%type,
                                      p_cod_canal      in varchar2 default 'N',
                                      p_cod_error      out number,
                                      p_men_error      out varchar2,
                                      p_modo           in varchar2 default 'C',
                                      p_notas          in varchar2 default null);

end PAP_PLA;
/
