CREATE OR REPLACE PROCEDURE IT.PRG_OBT_CARGOS
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRA_CARGO IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_CARGO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_CARGO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
v_mto_exonerado number(21,2);
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1);
v_tas_personalizada varchar2(1);
begin
  -- veo si la cuenta tiene transaccion prohibida
  if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                 p_cod_tra_cargo,
                                 p_cod_modulo,
                                 p_cod_modalidad) = 'N' then
    if p_nro_cuenta is not null then                             
        -- no tiene transaccion prohibida, se calcula
        begin
           select tas_personalizada
             into v_tas_personalizada
             from ge_cuentas
             where nro_cuenta = p_nro_cuenta;
        exception
           when no_data_found then
              raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
        end;
    end if;
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,p_cod_moneda);
    -- busco el valor de la tasa
    pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
         p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
         v_val_base, nvl(v_tas_personalizada,'N'), p_cod_tas_cargo,
         p_cod_tra_cargo, trunc(sysdate),
         p_val_tas_cargo, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
    if v_tip_valor = 'V' then
       -- si es un valor, se toma directamente
       p_val_cargo := nvl(p_val_tas_cargo,0);
    else
       -- es un porcentaje
       p_val_cargo := round(nvl(v_val_base,0)*
                               nvl(p_val_tas_cargo,0)/100,v_redondeo);
      --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
      p_val_cargo := pag_gen.FU_OBT_VAL_FINAL(p_val_cargo);
    end if;

    -- busco el impuesto asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_impuesto
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_tra_cargo
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and cod_tra_hijo <> p_cod_tra_cargo -- Que la transacción hijo sea diferente de la padre PV 02/11/09
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de impuestos
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_impuesto,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontro impuesto asociado, se calcula
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
               p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
               p_val_cargo, nvl(v_tas_personalizada,'N'), p_cod_tas_impuesto,
               p_cod_tra_impuesto, trunc(sysdate),
               p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
         if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_impuesto := nvl(p_val_tas_impuesto,0);
         else
            --
            -- es un porcentaje, se considera incluido en el cargo
            p_val_impuesto := round(nvl(p_val_cargo,0)*
                                    nvl(p_val_tas_impuesto,0)/(100+p_val_tas_impuesto),v_redondeo);

            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            p_val_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_val_impuesto);
         end if;
        
         -- resto el monto del impuesto al cargo, porque va incluido
         p_val_cargo := nvl(p_val_cargo,0) - nvl(p_val_impuesto,0);
         if p_val_cargo < 0 then
            raise_application_error(-20000,'Impuesto mas alto que el Cargo');
         end if;
       else
          p_val_impuesto := 0;
       end if;
    exception
       when no_data_found then
          p_val_impuesto := 0;
       when others then
          raise_application_error(-20000,'Al leer Impuesto '||sqlerrm);
    end;
  end if;
end ;
/

