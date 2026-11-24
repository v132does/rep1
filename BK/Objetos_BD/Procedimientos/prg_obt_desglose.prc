CREATE OR REPLACE PROCEDURE IT.PRG_OBT_DESGLOSE
 (P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN NUMBER
 ,P_COD_TRA_DESGLOSE OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_COD_TAS_DESGLOSE OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TAS_DESGLOSE OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_VAL_DESGLOSE OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
 )
 IS
v_mto_exonerado number(21,2);
v_val_base      number(18,2) := p_monto;
v_fec_vigencia  date;
v_tip_valor     varchar2(1);
v_tipo          varchar2(1);
v_redondeo      number(1) := 0;
v_tas_personalizada varchar2(1);
begin
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,p_cod_moneda);
    -- busco el desglose asociado a este cargo
    begin
      select cod_tra_hijo
        into p_cod_tra_desglose
        from ge_transacciones_det
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_transaccion
         and cod_mod_hijo = p_cod_modulo
         and cod_mad_hijo = p_cod_modalidad
         and rownum = 1;
      -- veo si la cuenta tiene exoneracion de desgloses
      if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                      p_cod_tra_desglose,
                                      p_cod_modulo,
                                      p_cod_modalidad) = 'N' then
         -- Se encontro desglose asociado, se calcula
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad,
               p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda,
               p_monto, nvl(v_tas_personalizada,'N'), p_cod_tas_desglose,
               p_cod_tra_desglose, trunc(sysdate),
               p_val_tas_desglose, v_fec_vigencia, v_tip_valor, v_tipo);    ---OUT
         if v_tip_valor = 'V' then
            -- si es un valor, se toma directamente
            p_val_desglose := nvl(p_val_tas_desglose,0);
         else
            --
            -- es un porcentaje, se considera incluido en el cargo
            p_val_desglose := round(nvl(p_monto,0)*
                                    nvl(p_val_tas_desglose,0)/(100+p_val_tas_desglose),v_redondeo);

            --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
            p_val_desglose := pag_gen.FU_OBT_VAL_FINAL(p_val_desglose);
         end if;
        
        
       else
          p_val_desglose := 0;
       end if;
    exception
       when no_data_found then
          p_val_desglose := 0;
       when others then
          raise_application_error(-20000,'Al leer desglose '||sqlerrm);
    end;

end ;
/

