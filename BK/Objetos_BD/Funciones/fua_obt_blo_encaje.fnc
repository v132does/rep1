CREATE OR REPLACE FUNCTION IT.FUA_OBT_BLO_ENCAJE
 (P_NRO_CUENTA IN AH_CTA_CERTIFICADOS.NRO_CUENTA%TYPE
 ,P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE
 ,P_FEC_APERTURA IN AH_CTA_CERTIFICADOS.FEC_APERTURA%TYPE
 ,P_FEC_VENCIMIENTO IN AH_CTA_CERTIFICADOS.FEC_VENCIMIENTO%TYPE
 ,P_COD_MONEDA IN AH_CTA_CERTIFICADOS.COD_MONEDA%TYPE
 )
 RETURN NUMBER
 IS
 
v_monto       number := 0;
v_cod_modulo  ba_modulos.cod_modulo%type := 3;
v_val_tasa    ge_tas_fechas.val_tasa%type := 0;
v_tip_valor   ge_tasas.tip_valor%type;
v_cod_tasa    ge_tasas.cod_tasa%type := fug_obt_pardinamico('COD_TAS_ENC_LEG_ESPECIAL', v_cod_modulo);
v_plazo       number := p_fec_vencimiento - p_fec_apertura;
v_redondeo    number(2) := fug_obt_pardinamico(P_PARAMETRO => 'VAL_RED_MON_EXTRANJERA',
                                               P_COD_MONEDA => P_COD_MONEDA);
                                               
BEGIN    
   begin
      select a.tip_valor,
             b.val_tasa
        into v_tip_valor,
             v_val_tasa
        from ge_tasas a,
             ge_tas_fechas b
       where a.cod_tasa = v_cod_tasa
         and a.cod_tasa = b.cod_tasa
         and b.cod_moneda = P_COD_MONEDA
         and b.cod_modulo = v_cod_modulo
         and v_plazo between b.val_minimo and b.val_maximo
         and b.fec_vigencia <= pag_cal.fu_obt_fec_actual(v_cod_modulo);
   exception
      when others then
         v_val_tasa := 0;  
   end;
   
   if v_tip_valor = 'P'
     and nvl(v_val_tasa, 0) != 0 then
      v_monto := round((nvl(p_capital,0) * v_val_tasa) / 100, v_redondeo);  
   elsif v_tip_valor = 'V' then
      v_monto := v_val_tasa;
   end if;
   
   return v_monto;
END;
/

