CREATE OR REPLACE FUNCTION IT.FUL_OBT_REL_MONEDAS (P_COD_MON_VENTA IN VARCHAR2,
                                                P_COD_MON_COMPRA IN VARCHAR2,
                                                P_VAL_COT_VENTA IN NUMBER,
                                                P_VAL_COT_COMPRA IN NUMBER) RETURN NUMBER IS
                                                
  /*Obteiene relacion de monedas para cambios segun monedas fuerte definidas */
  /*Proyecto DDARBDIG-1-Arbitraje Digital*/
  
  v_relacion number := 0;
  v_tie_mon_fue_venta ge_par_dinamicos.val_parametro%type;
  v_tie_mon_fue_compra ge_par_dinamicos.val_parametro%type;
  v_cod_mon_fue_nivel2 ba_monedas.cod_moneda%type;
BEGIN
  v_tie_mon_fue_venta := NVL(fug_obt_pardinamico('ARB_DIG_COD_MON_FUERTE',NULL,NULL,P_COD_MON_VENTA),'N');
  v_tie_mon_fue_compra := NVL(fug_obt_pardinamico('ARB_DIG_COD_MON_FUERTE',NULL,NULL,P_COD_MON_COMPRA),'N');
  v_cod_mon_fue_nivel2 := pag_gen.FU_OBT_MON_FUERTE;
  
  if (v_tie_mon_fue_venta = 'N') and (v_tie_mon_fue_compra = 'N') then
     if (P_COD_MON_VENTA = v_cod_mon_fue_nivel2) then
        v_relacion := P_VAL_COT_VENTA / P_VAL_COT_COMPRA;
     elsif (P_COD_MON_COMPRA = v_cod_mon_fue_nivel2) then
        v_relacion := P_VAL_COT_COMPRA / P_VAL_COT_VENTA;
     else
        v_relacion := P_VAL_COT_COMPRA / P_VAL_COT_VENTA;
     end if;
  elsif v_tie_mon_fue_venta = 'S' then
     v_relacion := P_VAL_COT_VENTA / P_VAL_COT_COMPRA;
  else
     v_relacion := P_VAL_COT_COMPRA / P_VAL_COT_VENTA;
  end if;
  return v_relacion;

exception
  when others then 
     raise_application_error(-20000,'Error en FUL_OBT_REL_MONEDAS '||sqlerrm); 
END;
/

