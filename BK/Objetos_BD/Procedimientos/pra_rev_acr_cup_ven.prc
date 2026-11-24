CREATE OR REPLACE PROCEDURE IT.PRA_REV_ACR_CUP_VEN
 IS
v_fec_actual     ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   r_gmovi          ge_movimientos%rowtype;
   --- Cursor de cupones vencidos
   cursor c_cupon is
   select NRO_CUENTA, NRO_CUPON, NVL(MTO_INTERES,0) MTO_INTERES, FEC_VENCIMIENTO, ROWID linea
     from AH_CUPONES
    where ESTADO = 'V'
      and FEC_VENCIMIENTO = v_fec_actual;
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   v_hora       := pag_gen.fu_obt_sig_segundo(to_char(sysdate,'HH24:MI:SS'));
   v_nro_secuencia := 0;
   for r_cup in c_cupon loop
      -- actualiza el saldo total on line de certificados --
      update AH_CTA_CERTIFICADOS
         set SAL_TOTAL = nvl(SAL_TOTAL,0) - r_cup.mto_interes,
             FEC_ULT_CAPITALIZACION = r_cup.fec_vencimiento
       where NRO_CUENTA = r_cup.nro_cuenta;
      --- Recuperar datos de la cuenta en el registro global g_ctas
      pag_cta.pr_obt_cuenta(r_cup.nro_cuenta);
      --- Insertar mvto de cambio estado cupon
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
      r_gmovi.monto             := null;
      r_gmovi.cod_tra_padre     := 314;
      r_gmovi.cod_transaccion   := 423;
      r_gmovi.est_cuenta        := 'E';
      r_gmovi.estado            := 'N';
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.nro_documento     := r_cup.nro_cupon;
      r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
      r_gmovi.monto             := null;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.fec_valor         := v_fec_actual;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
      --- Insertar mvto de Crédito por vencimiento de cupón
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
      r_gmovi.cod_tra_padre     := 314;
      r_gmovi.cod_transaccion   := 609;
      r_gmovi.estado            := 'N';
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.nro_documento     := r_cup.nro_cupon;
      r_gmovi.monto             := (r_cup.mto_interes*-1);
      r_gmovi.cod_ofi_origen    := pag_cta.g_ctas.cod_oficina;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.fec_valor         := v_fec_actual;
      pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
      --------
      update AH_CUPONES
         set ESTADO = 'E'
       where rowid = r_cup.linea;
   end loop;
END;
/

