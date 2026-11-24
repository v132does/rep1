CREATE OR REPLACE PROCEDURE IT.PRG_ACT_MOV_PEN
 IS

V_HOR_ACTUAL VARCHAR2(8);
V_FEC_ACTUAL DATE;
V_COD_MONEDA GE_MOVIMIENTOS.COD_MONEDA%TYPE;
V_COD_OFICINA GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;


cursor mov is
  select nro_cuenta, fecha, hora,cod_modulo, cod_modalidad,
         cod_transaccion, cod_mod_padre, cod_mad_padre,
         cod_tra_padre, monto
    from ge_mov_pendientes;

begin
  v_fec_actual    := pag_cal.fu_obt_fec_actual(3); -- fecha de hoy
  V_HOR_ACTUAL    := to_char(sysdate,'HH24:MI:SS');
  v_nro_secuencia := 0;
  for i in mov loop
      PAG_CTA.PR_OBT_CUENTA(i.nro_cuenta);
      v_cod_oficina         := pag_cta.g_ctas.COD_OFICINA;
      v_cod_moneda          := pag_cta.g_ctas.COD_MONEDA;
      v_nro_secuencia       := v_nro_secuencia + 1;
      pag_cta.pr_act_operacion(i.nro_cuenta,
                               v_hor_actual,
                               'D', -- debito a la cuenta del cliente
                               v_cod_moneda,
                               i.monto,
                               i.cod_tra_padre,
                               i.cod_transaccion, -- trans. hijo
                               null,
                               null, -- cotizacion
                               v_cod_oficina,
                               i.cod_mod_padre,
                               i.cod_mad_padre,
                               null, -- tasa
                               null, -- valor de tasa
                               'Act.de mov.pendientes', --concepto
                               'N', -- emitir aviso
                               v_nro_secuencia, -- nro de secuencia
                               v_fec_actual);
       if pag_cta.g_cod_error <> 0 then
            raise_application_error(-20000,'No pudo debitar de la cuenta '||i.nro_cuenta|| ' por '||pag_cta.g_msj_error);
       end if;                               
      if pag_cta.g_cod_error = 0 then
        delete ge_mov_pendientes where nro_cuenta = i.nro_cuenta
                                   and fecha = i.fecha
                                   and hora = i.hora
                                   and cod_tra_padre = i.cod_tra_padre;
      End if;
  end loop;
end;
/

