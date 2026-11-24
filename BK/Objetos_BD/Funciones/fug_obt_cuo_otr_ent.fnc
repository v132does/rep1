CREATE OR REPLACE FUNCTION IT.FUG_OBT_CUO_OTR_ENT
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 )
 RETURN NUMBER
 IS
   --- Variables
   v_mto_cuota        pr_cuotas.mto_capital%type;
   v_tot_prom         pr_cuotas.mto_capital%type;
   v_cod_mon_local    ba_monedas.cod_moneda%type;
   v_promedio         pr_cuotas.mto_capital%type;
   v_cotizacion       ge_cotizaciones.val_compra%type;
   v_redondeo         number(5);
   --- Cursor de cuotas
   cursor c_cuotas is
   select nvl(cod_moneda,v_cod_mon_local) cod_moneda, nvl(sum(nvl(val_cuota,0)),0) val_cuota
     from cr_ref_comerciales
    where cod_persona = p_cod_persona
      and tip_referencia in ('B', 'C') -- Bancaria y Comercial
      and est_verificacion = 'V'
      and nvl(can_cuotas,0) > nvl(can_pagadas,0)
    group by nvl(cod_moneda,v_cod_mon_local);
   --- Cursor de administradoras
   cursor c_administradora is
   select nvl(cod_moneda,v_cod_mon_local) cod_moneda,
          round(nvl(sum(((decode(tip_referencia,'A',nvl(val_credito,0),nvl(mto_linea,0))))),0),0) val_credito
     from cr_ref_comerciales
    where cod_persona = p_cod_persona
      and tip_referencia in ('A','T')
      and est_verificacion = 'V'
    group by nvl(cod_moneda,v_cod_mon_local);
   v_por_pag_minimo number(5) := 0;
BEGIN
   v_tot_prom := 0;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_redondeo       := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,p_cod_moneda,null);
   for cuo in c_cuotas loop
      if cuo.cod_moneda = p_cod_moneda then
         v_tot_prom := v_tot_prom + cuo.val_cuota;
      else
         v_cotizacion := null;
         pag_gen.pr_con_mon_a_moneda(cuo.cod_moneda, p_cod_moneda,
                                     cuo.val_cuota, v_promedio,
                                     v_cotizacion, v_cotizacion);
         v_tot_prom := v_tot_prom + v_promedio;
      end if;
   end loop;
   --- Hallar finalmente el total
   v_mto_cuota := round(v_tot_prom,v_redondeo);
   v_tot_prom := 0;
   for adm in c_administradora loop
      if adm.cod_moneda = p_cod_moneda then
         v_tot_prom := v_tot_prom + adm.val_credito;
      else
         v_cotizacion := null;
         pag_gen.pr_con_mon_a_moneda(adm.cod_moneda, p_cod_moneda,
                                     adm.val_credito, v_promedio,
                                     v_cotizacion, v_cotizacion);
         v_tot_prom := v_tot_prom + v_promedio;
      end if;
   end loop;
   v_por_pag_minimo := fug_obt_pardinamico('POR_PAG_MINIMO',5,null);
   v_tot_prom := round((v_tot_prom*v_por_pag_minimo/100),v_redondeo);
   --- Hallar finalmente el total
   v_mto_cuota := nvl(v_mto_cuota,0) + round(v_tot_prom,v_redondeo);
   return v_mto_cuota;
END;
/

