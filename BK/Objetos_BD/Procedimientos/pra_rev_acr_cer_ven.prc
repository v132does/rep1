CREATE OR REPLACE PROCEDURE IT.PRA_REV_ACR_CER_VEN
 IS

/* Acreditar cda */
   r_gmovi           ge_movimientos%rowtype;
   v_fec_actual      ge_calendarios.fec_actual%type;
   v_hora            ge_movimientos.hora%type;
   v_nro_secuencia   ge_movimientos.nro_secuencia%type;
   --- Cursor de certificados a vencer
   cursor c_certificados is
   select nro_cuenta, nro_certificado
     from ah_cta_certificados
    where fec_vencimiento = v_fec_actual
      and est_certificado = 'V'
      and estado not in ('C','T');

BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   v_hora          := to_char(sysdate,'HH24:MI:SS');
   v_nro_secuencia := 0;
   for r_cer in c_certificados loop
      --- Recuperar datos de la cuenta en el registro global g_ctas
      pag_cta.pr_obt_cuenta(r_cer.nro_cuenta);
      update AH_CTA_CERTIFICADOS
         set EST_CERTIFICADO = 'E'
       where NRO_CUENTA = pag_cta.g_ctas.nro_cuenta;
      --- Insertar movimiento de Cambio estado a vencido de la cuenta
      pag_cta.pr_set_variables(user, v_fec_actual, 313, 'N','N',v_nro_secuencia,'N');
      pag_cta.pr_act_estado(pag_cta.g_ctas.nro_cuenta,
                            'N',
                            v_fec_actual,
                            v_hora,
                            r_cer.nro_certificado);
      v_nro_secuencia := v_nro_secuencia + 1;
      --- Insertar movimiento de Cambio estado a normal del certificado
      v_nro_secuencia           := v_nro_secuencia + 1;
      r_gmovi.cod_usuario       := user;
      r_gmovi.hora              := v_hora;
      r_gmovi.nro_secuencia     := v_nro_secuencia;
      r_gmovi.cod_mod_padre     := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_mad_padre     := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.cod_oficina       := pag_cta.g_ctas.cod_oficina;
      r_gmovi.cod_modulo        := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad     := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.nro_cuenta        := pag_cta.g_ctas.nro_cuenta;
      r_gmovi.cod_moneda        := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_tra_padre     := 313;
      r_gmovi.cod_transaccion   := 403;
      r_gmovi.est_cuenta        := 'E';
      r_gmovi.estado            := 'N';
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.nro_documento     := r_cer.nro_certificado;
      r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.fec_valor         := v_fec_actual;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
      --- Insertar movimiento de traslado contable a No vencido
      v_nro_secuencia           := v_nro_secuencia + 1;
      r_gmovi.cod_usuario       := user;
      r_gmovi.hora              := v_hora;
      r_gmovi.nro_secuencia     := v_nro_secuencia;
      r_gmovi.cod_mod_padre     := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_mad_padre     := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.cod_modulo        := pag_cta.g_ctas.cod_modulo;
      r_gmovi.cod_modalidad     := pag_cta.g_ctas.cod_modalidad;
      r_gmovi.cod_oficina       := pag_cta.g_ctas.cod_oficina;
      r_gmovi.nro_cuenta        := pag_cta.g_ctas.nro_cuenta;
      r_gmovi.cod_moneda        := pag_cta.g_ctas.cod_moneda;
      r_gmovi.cod_tra_padre     := 313;
      r_gmovi.cod_transaccion   := 604;
      r_gmovi.est_cuenta        := 'N';
      r_gmovi.estado            := 'N';
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.monto             := (pag_cta.g_ctas.capital*-1);
      r_gmovi.nro_documento     := r_cer.nro_certificado;
      r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.fec_valor         := v_fec_actual;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
   end loop;
END;
/

