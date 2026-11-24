CREATE OR REPLACE FUNCTION IT.FUB_OBT_MTO_COMPUTABLE
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 )
 RETURN NUMBER
  IS
v_tot_prestamo NUMBER;  
v_tot_tarjeta  NUMBER;
v_tot_cx       NUMBER;
v_tot_cta_cte  NUMBER;
v_tot_vencidas NUMBER;
v_total        NUMBER;
BEGIN
    begin
      select  sum(pag_gen.fu_con_mon_a_moneda(fug_obt_mon_cta(a.nro_cuenta), p_cod_moneda, nvl(a.mto_con_computable,0)))
       into v_tot_prestamo
      from pr_cta_garantias a
      where a.nro_garantia = p_nro_garantia;
    EXCEPTION 
       when others then
        v_tot_prestamo := 0;
    end;
    
    begin
      select  sum(pag_gen.fu_con_mon_a_moneda(fug_obt_mon_cta(a.nro_cuenta), p_cod_moneda, nvl(a.mto_con_computable,0)))
       into v_tot_tarjeta
      from ta_cta_garantias a
      where a.nro_garantia = p_nro_garantia;
    EXCEPTION 
       when others then
        v_tot_tarjeta := 0;
    end;
          
    begin         
      select  sum(pag_gen.fu_con_mon_a_moneda(fug_obt_mon_cta(a.nro_cuenta), p_cod_moneda, nvl(a.mto_con_computable,0)))
       into v_tot_cx
      from cx_cta_garantias a
      where a.nro_garantia = p_nro_garantia;
    EXCEPTION 
       when others then
        v_tot_cx := 0;
    end;
          

    begin        
       select sum(pag_gen.fu_con_mon_a_moneda(fug_obt_mon_cta(a.nro_cuenta), p_cod_moneda, nvl(a.mto_con_computable,0)))
       into v_tot_cta_cte
      from cc_cta_garantias a
      where a.nro_garantia = p_nro_garantia;
    EXCEPTION 
       when others then
        v_tot_cta_cte := 0;
    end;
          

    begin              
       select sum(pag_gen.fu_con_mon_a_moneda(fug_obt_mon_cta(a.nro_cuenta), p_cod_moneda, nvl(a.mto_con_computable,0)))
       into v_tot_vencidas
      from ov_cta_garantias a
      where a.nro_garantia = p_nro_garantia;
    EXCEPTION 
       when others then
        v_tot_vencidas := 0;
    end;
          
        
      v_total := nvl(v_tot_prestamo,0) + nvl(v_tot_tarjeta,0) + nvl(v_tot_cx,0) + nvl(v_tot_cta_cte,0) + nvl(v_tot_vencidas,0);

      return v_total;


END;
/

