create or replace procedure it.prg_obt_impuesto
 (P_COD_OFI_ORIGEN   IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA       IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA       IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO            IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO       IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD    IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
v_val_base          number(18,2) := p_monto;
v_fec_vigencia      date;
v_tip_valor         varchar2(1);
v_tipo              varchar2(1);
v_redondeo          number(1);
v_tas_personalizada varchar2(1);

begin
    p_cod_tra_impuesto := 571;  ---- se debe cambiar luego LEY 125 !!! 
    
    -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_impuesto,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    -- no tiene transaccion prohibida, se calcula
    begin
       select tas_personalizada
         into v_tas_personalizada
         from ge_cuentas
         where nro_cuenta = p_nro_cuenta;
    exception
       when no_data_found then
          raise_application_error(-20005,'Cuenta '||p_nro_cuenta||' no registrada');
    end;

    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,p_cod_moneda);
    -- busco el valor de la tasa

    pag_gen.pr_obt_val_tasa(p_cod_modulo,
                            p_cod_modalidad,
                            p_cod_ofi_origen, 
                            p_nro_cuenta, 
                            p_cod_moneda,
                            v_val_base, 
                            nvl(v_tas_personalizada,'N'), 
                            p_cod_tas_impuesto,
                            p_cod_tra_impuesto,
                            trunc(sysdate),
                            p_val_tas_impuesto,
                            v_fec_vigencia, 
                            v_tip_valor,
                            v_tipo);   

    if v_tip_valor = 'V' then
       -- si es un valor, se toma directamente
       p_val_impuesto := nvl(p_val_tas_impuesto,0);
    else
       -- es un porcentaje
       p_val_impuesto := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_impuesto,0)/100,v_redondeo);

       --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
       p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
    end if;

 end if;
end;
/

