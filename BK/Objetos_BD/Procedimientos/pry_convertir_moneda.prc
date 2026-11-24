CREATE OR REPLACE PROCEDURE IT.PRY_CONVERTIR_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COT_MON_ORIGINAL IN OUT NUMBER
 ,P_COT_MON_DESTINO IN OUT NUMBER
 ,P_MTO_MON_ORIGINAL IN NUMBER := 0
 ,P_MTO_MON_DESTINO OUT NUMBER
 )
 IS
BEGIN
DECLARE
   v_mto_mon_destino number;
   v_cod_mon_base varchar2(10);
   v_cod_mon_dolar varchar2(10);
v_lugar varchar2(100);
BEGIN
    v_lugar := 'obtener moneda base y dolar';
    v_cod_mon_base := fuy_obt_mon_base();
    v_cod_mon_dolar := fuy_obt_mon_dolar();

    if p_cod_mon_original = p_cod_mon_destino  then
        p_mto_mon_destino := P_mto_mon_original;
        if p_cod_mon_original <> v_cod_mon_base then
           p_cot_mon_destino := nvl(p_cot_mon_original,fuy_obt_cot_moneda(p_cod_mon_original));
           p_cot_mon_original := p_cot_mon_destino;
        else
           p_cot_mon_destino := 1;
           p_cot_mon_original := 1;
        end if;
   else
       if  p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base then
           --convertir moneda original a base o destino
           p_cot_mon_original := fuy_obt_cot_moneda(p_cod_mon_original);
           p_cot_mon_destino := 1;
           p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
       elsif p_cod_mon_original = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           -- pasar moneda original a moneda base
           p_cot_mon_original := 1;
           p_cot_mon_destino := fuy_obt_cot_moneda(p_cod_mon_destino);
           p_mto_mon_destino := ROUND(p_mto_mon_original/p_cot_mon_destino,0);
       elsif p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           p_cot_mon_original := fuy_obt_cot_moneda(p_cod_mon_original);
           p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
           p_cot_mon_destino := fuy_obt_cot_moneda(p_cod_mon_destino);
           p_mto_mon_destino := ROUND(p_mto_mon_destino/p_cot_mon_destino,2);
       end if;
/*
       if (p_cot_mon_original is null or
           p_cot_mon_original = 0) and p_cod_mon_original <> v_cod_mon_base then
           v_lugar := 'Cargo la cotizacion de la moneda';
           p_cot_mon_original := fuy_obt_cot_moneda(p_cod_mon_original);
       elsif (p_cot_mon_original is null or
           p_cot_mon_original = 0) and p_cod_mon_original = v_cod_mon_base then
           p_cot_mon_original := 1;
       else
           p_cot_mon_original := p_cot_mon_original;
       end if;
       if p_cot_mon_destino is null or
          p_cot_mon_destino = 0 then
          if  p_cod_mon_destino = v_cod_mon_dolar then
             v_lugar := 'Obtener la cotizacion del dolar';
             p_cot_mon_destino := fuy_obt_val_num('COTDOLAR');
          else
             v_lugar := 'Obtener la cotizacion de la moneda destino';
             p_cot_mon_destino := fuy_obt_cot_moneda(p_cod_mon_destino);
          end if;
       else
          p_cot_mon_destino := p_cot_mon_destino;
       end if;
       if p_cod_mon_original <> v_cod_mon_base  then
          v_lugar := 'cambio de moneda';
          v_mto_mon_destino    := nvl(p_mto_mon_original,0) * p_cot_mon_original;
          p_mto_mon_destino := round(v_mto_mon_destino/p_cot_mon_destino,0);
       elsif p_cod_mon_original = v_cod_mon_base then
          --v_mto_mon_destino := nvl(p_mto_mon_original,0);
          v_lugar := 'moneda guarani';
          p_mto_mon_destino := round(p_mto_mon_original/p_cot_mon_destino,0);
       end if;*/
   end if;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;
END;
/

