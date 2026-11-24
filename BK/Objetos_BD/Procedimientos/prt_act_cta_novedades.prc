create or replace procedure it.prt_act_cta_novedades(p_cuenta      varchar2,
                                                     p_cta_global  varchar2,
                                                     p_fec_novedad date,
                                                     p_enviado     varchar2,
                                                     p_det_error   varchar2) is

 v_cuenta      ta_glp_cuentas_nov.nro_cuenta%type;
 v_cta_global  ta_glp_cuentas_nov.nro_cta_global%type;
 v_fec_novedad ta_glp_cuentas_nov.fec_novedad%type;
 v_enviado     ta_glp_cuentas_nov.enviado%type;
 v_det_error   ta_glp_cuentas_nov.det_error%type;
 v_fec_envio   ta_glp_cuentas_nov.fec_envio%type;
 v_no_update   exception;

 begin
   -- setea las variables
   v_cuenta      := p_cuenta;
   v_cta_global  := p_cta_global;
   v_fec_novedad := p_fec_novedad;
   v_enviado     := p_enviado;
   v_det_error   := p_det_error;
   v_fec_envio   := pag_cal.fu_obt_fec_actual(5);

  BEGIN
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 1;
  END;

  -- actualiza la tabla de novedades de global
  update ta_glp_cuentas_nov a
     set a.enviado   = v_enviado,
         a.det_error = v_det_error,
         a.fec_envio = v_fec_envio
   where a.nro_cuenta = v_cuenta
     and a.nro_cta_global = v_cta_global
     and a.fec_novedad = v_fec_novedad;

  if sql%notfound then
    raise v_no_update;
  end if;

 exception
   when v_no_update then
     prg_ins_log_programas('PRT_ACT_CTA_NOVEDADES','No se encontro el registro para actualizar la Novedad de Global.
                                                    Cta: '||v_cuenta||
                                          '. Cta Global: '||v_cta_global||
                                             '. Enviado: '||v_enviado||
                                           '. Det Error: '||v_det_error||
                                           '. Fec Envio: '||v_fec_envio);
   
   when others then
     prg_ins_log_programas('PRT_ACT_CTA_NOVEDADES',substr(sqlerrm,1,4000));
 end;
/

