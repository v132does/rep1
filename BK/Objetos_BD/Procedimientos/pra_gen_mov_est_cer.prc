CREATE OR REPLACE PROCEDURE IT.PRA_GEN_MOV_EST_CER
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_ESTADO IN AH_CTA_CERTIFICADOS.EST_CERTIFICADO%TYPE
 ,P_NRO_CERTIFICADO IN AH_CTA_CERTIFICADOS.NRO_CERTIFICADO%TYPE
 )
 IS
v_fec_actual      ge_calendarios.fec_actual%type;
   v_cod_mon_local   ba_monedas.cod_moneda%type;
   v_hora            ge_movimientos.hora%type;
   v_nro_secuencia   ge_movimientos.nro_secuencia%type;
   r_gmovi           ge_movimientos%rowtype;
BEGIN
   v_fec_actual    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_hora          := to_char(sysdate,'HH24:MI:SS');
   v_nro_secuencia := 0;
   --- Recuperar datos de la cuenta en el registro global g_ctas
   pag_cta.pr_obt_cuenta(p_nro_cuenta);
   --- Insertar movimiento de Cambio estado a vencido
   v_nro_secuencia := v_nro_secuencia + 1;
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
   r_gmovi.cod_tra_padre     := 403;
   r_gmovi.cod_transaccion   := 403;
   r_gmovi.est_cuenta        := p_estado;
   r_gmovi.estado            := 'N';
   r_gmovi.reversado         := 'N';
   r_gmovi.emi_aviso         := 'N';
   r_gmovi.protegido         := 'N';
   r_gmovi.nro_documento     := p_nro_certificado;
   r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
   r_gmovi.fecha             := v_fec_actual;
   r_gmovi.fec_valor         := v_fec_actual;
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
END;
/

