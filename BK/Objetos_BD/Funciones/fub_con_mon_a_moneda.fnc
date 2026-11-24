CREATE OR REPLACE FUNCTION IT.FUB_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_COT_MON_ORIGINAL IN NUMBER default null
 ,P_FECHA IN DATE DEFAULT NULL
 )
 RETURN NUMBER
  IS
v_cod_mon_base     ba_monedas.cod_moneda%type;
v_mto_mon_destino  NUMBER;
v_cot_mon_destino  number;
v_cot_mon_original number := p_cot_mon_original;
v_lugar            varchar2(100);
v_fecha date := NVL(P_FECHA,PAG_CAL.FU_OBT_FEC_ACTUAL(2));
v_redondeo number(2);
BEGIN
    v_lugar := 'obtener moneda base';
    v_cod_mon_base  := pag_gen.fu_obt_mon_local();
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,p_cod_mon_destino);
    if p_cod_mon_original = p_cod_mon_destino  then
        v_mto_mon_destino := P_mto_mon_original;
        if p_cod_mon_original <> v_cod_mon_base then
           if v_cot_mon_original is null and v_cot_mon_destino is not null then
              v_cot_mon_original := v_cot_mon_destino;
           elsif v_cot_mon_original is null then
              v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original,v_fecha);
           end if;
           v_cot_mon_destino := v_cot_mon_original;
        else
           v_cot_mon_destino := 1;
           v_cot_mon_original := 1;
        end if;
   else
       if  p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base then
           --convertir moneda original a base o destino
           if v_cot_mon_original is null then
              v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original,v_fecha);
           end if;
           v_cot_mon_destino := 1;
           v_mto_mon_destino := round(p_mto_mon_original * v_cot_mon_original,v_redondeo);
       elsif p_cod_mon_original = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           -- pasar moneda original a moneda base
           if v_cot_mon_destino is null then
              v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino,v_fecha);
           end if;
           v_cot_mon_original := 1;

           v_mto_mon_destino := ROUND(p_mto_mon_original/v_cot_mon_destino,v_redondeo);
       elsif p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           if v_cot_mon_original is null then
              v_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original,v_fecha);
           end if;
           v_mto_mon_destino := p_mto_mon_original * v_cot_mon_original;
           v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino,v_fecha);
           v_mto_mon_destino := ROUND(v_mto_mon_destino/v_cot_mon_destino,v_redondeo);
       end if;
   end if;
   return v_mto_mon_destino;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;
/

