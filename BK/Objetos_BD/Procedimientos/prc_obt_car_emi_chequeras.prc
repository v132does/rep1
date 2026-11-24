CREATE OR REPLACE PROCEDURE IT.PRC_OBT_CAR_EMI_CHEQUERAS
 (p_cod_ofi_origen in  ba_oficinas.cod_oficina%type           --Oficina origen
 ,p_nro_cuenta     in  ge_cuentas.nro_cuenta%type
 ,p_tip_chequera   in  cc_tip_chequeras.cod_tip_chequera%type --Tipo de chequera
 ,p_can_cheques    in  cc_chequeras.can_cheques%type          --Cantidad de cheques
 ,p_montcar        out ge_movimientos.monto%type
 ,p_montimp        out ge_movimientos.monto%type
)
 IS
   v_cod_modulo       ge_cuentas.cod_modulo%type;
   v_cod_modalidad    ge_cuentas.cod_modalidad%type;
   v_cod_moneda       ge_cuentas.cod_moneda%type;
   v_cod_transaccion  cc_tip_chequeras.cod_transaccion%type;

   v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
   v_val_tas_cargo    ge_movimientos.val_tasa%type;
   v_val_cargo        ge_movimientos.val_tasa%type;
   v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
   v_val_tas_impuesto ge_movimientos.val_tasa%type;
   v_val_impuesto     ge_movimientos.val_tasa%type;
   v_monloc           ba_monedas.cod_moneda%type;
   v_redondeo         number(5);

begin
  --Obtener los datos de la cuenta
  /*PAG_CTA.PR_OBT_CUENTA(p_nro_cuenta);
  v_cod_moneda    := pag_cta.g_ctas.cod_moneda;
  v_cod_modulo    := pag_cta.g_ctas.cod_modulo;
  v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;*/
  begin
  select cod_modulo, cod_modalidad, cod_moneda
    into v_cod_modulo, v_cod_modalidad, v_cod_moneda
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
  exception
     when others then
      raise_application_error(-20000,'Error: en obtener ge_cuenta '||sqlerrm);
  end;
  if v_cod_modalidad = 41 then
      --Obtener el codigo de transaccion x el tipo de chequera
      begin
        select cod_transaccion
          into v_cod_transaccion
          from cc_tip_chequeras
         where cod_tip_chequera = p_tip_chequera;
      exception
        when no_data_found then
          raise_application_error(-20000,'Error: Al obtener la transaccion');
      end;

      PRG_OBT_CARGOS(p_cod_ofi_origen,
                     p_nro_cuenta,
                     v_cod_moneda,
                     NULL,
                     v_cod_modulo,
                     v_cod_modalidad,
                     v_cod_transaccion,
                     v_cod_tas_cargo,
                     v_val_tas_cargo,
                     v_val_cargo,
                     v_cod_tra_impuesto,
                     v_cod_tas_impuesto,
                     v_val_tas_impuesto,
                     v_val_impuesto);

      v_monloc  := pag_gen.fu_obt_mon_local;
      p_montcar := NVL(v_val_tas_cargo,0) *  p_can_cheques;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_cod_moneda);
      p_montcar := ROUND(to_number(p_montcar),v_redondeo);

      p_montimp := p_montcar * v_val_tas_impuesto/100;
      p_montimp := ROUND(p_montimp,v_redondeo);
  end if;
exception
  when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20000,'Error: En obtener cargos por emision de cheq. '||sqlerrm);
    End if;
end;
/

