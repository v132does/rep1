create or replace procedure it.PRL_DEV_OPE_FUT_VALECO(p_nro_operacion in number default null) is
  
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  
  r_lofut           lc_ope_futuras%rowtype;
  v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local ;
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_int_devengado   number(18,2);
  v_cantidad        number(18);
  v_descuento       varchar2(1);
  v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;
  v_mto_gan_per_ml    lc_for_dat_val_economico.mto_gan_per_ml%type;
  v_nro_cuenta      ge_cuentas.nro_cuenta%type;
  v_cod_modulo      ba_modulos.cod_modulo%type;
  v_cod_modalidad   ge_modalidades.cod_modalidad%type;
  v_cod_oficina     ba_oficinas.cod_oficina%type;
  v_nro_operacion   lc_ope_futuras.nro_operacion%type;
  v_cod_mad_transaccion lc_ope_futuras.cod_mad_transaccion%type;
  v_cod_mad_padre  lc_ope_futuras.cod_mad_padre%type;
  v_cod_ofi_origen lc_ope_futuras.cod_ofi_origen%type;
  --
  cursor fut is
       select f.cotizacion, f.cot_vencimiento, f.monto, f.plazo,
              f.fec_liquidacion, f.fec_operacion, f.fec_vencimiento, f.cod_moneda,
              f.cod_mad_padre, f.cod_ofi_origen,
              f.nro_cuenta, f.cod_modulo, f.cod_modalidad, f.cod_oficina,
              f.nro_operacion, f.cod_mad_transaccion, f.cod_mad_padre, f.cod_ofi_origen,
              sum(nvl(x.mto_gan_per_ml,0)) mto_gan_per_ml
         from lc_ope_futuras f, lc_for_dat_val_economico x
        where f.cod_mad_padre = 76
          and ((f.estado = 'N' and f.fec_liquidacion is null) or 
               (f.estado = 'L' and f.fec_liquidacion = v_Fec_actual))
          and x.nro_cuenta = f.nro_cuenta
          and x.nro_operacion = f.nro_operacion
          and x.fecha = v_Fec_actual
          and f.fec_vencimiento >= v_Fec_actual
          and ((f.nro_operacion = p_nro_operacion) or (p_nro_operacion is null))
          and v_ind_dev_val_economico = 'S'
          and not exists (select 1 
                            from ba_cod_referencias x
                           where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                             and x.val_minimo = f.nro_cuenta||'#'||f.nro_operacion)
 group by f.cotizacion, f.cot_vencimiento, f.monto, f.plazo,
              f.fec_liquidacion, f.fec_operacion, f.fec_vencimiento, f.cod_moneda,
              f.cod_mad_padre, f.cod_ofi_origen,
              f.nro_cuenta, f.cod_modulo, f.cod_modalidad, f.cod_oficina,
              f.nro_operacion, f.cod_mad_transaccion, f.cod_mad_padre, f.cod_ofi_origen;
   --
BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 7; end;
  Begin PAG_CAL.PR_OBT_DAT_CALENDAR(7);End;
  v_Fec_actual  := pag_cal.g_fec_actual;
  v_cantidad    := 0;
  v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
  OPEN fut;
  LOOP
    FETCH fut INTO r_lofut.cotizacion, r_lofut.cot_vencimiento, r_lofut.monto, r_lofut.plazo,
                   r_lofut.fec_liquidacion, r_lofut.fec_operacion, r_lofut.fec_vencimiento, r_lofut.cod_moneda,
                   r_lofut.cod_mad_transaccion, r_lofut.cod_ofi_origen,
                   v_nro_cuenta, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_operacion,
                   v_cod_mad_transaccion, v_cod_mad_padre, v_cod_ofi_origen,
                   v_mto_gan_per_ml;
    EXIT WHEN fut%NOTFOUND;
    v_cantidad := v_cantidad + 1;
    IF NVL(r_lofut.cot_vencimiento,0) >= NVL(r_lofut.cotizacion,0) THEN
       v_descuento := 'N';
    ELSE
       v_descuento := 'S';
    END IF;
    v_int_devengado := v_mto_gan_per_ml;
    INSERT INTO lc_devengados
      (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_moneda, cod_oficina, nro_operacion, estado,
       can_dia_interes, mto_interes, mto_dev_acumulado,
       cod_mad_transaccion, cod_mad_padre, cod_ofi_origen, descuento,val_tasa)
    VALUES
     (v_nro_cuenta, v_Fec_actual, v_cod_modulo, v_cod_modalidad, v_cod_mon_local, v_cod_oficina, v_nro_operacion, 'M',
      1, v_int_devengado, v_int_devengado,
      v_cod_mad_transaccion, v_cod_mad_padre, v_cod_ofi_origen, v_descuento,0);
    ------------------------------------------------------
  END LOOP;
  
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error en PRL_DEV_OPE_FUT_VALECO - '||SQLERRM);
end PRL_DEV_OPE_FUT_VALECO;
/

