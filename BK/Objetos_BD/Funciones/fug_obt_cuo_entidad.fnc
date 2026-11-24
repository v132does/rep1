CREATE OR REPLACE FUNCTION IT.FUG_OBT_CUO_ENTIDAD
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 )
 RETURN NUMBER
 IS
--- Cursor de cuotas
   cursor c_cuotas is
   select pre.cod_moneda,
          SUM(promedio) promedio
     from ge_cta_clientes cli, pr_cta_prestamos pre, (select cuo.nro_cuenta nro_cta_cuo,
                                                             round(nvl(sum(nvl(cuo.mto_capital,0)+nvl(cuo.mto_interes,0))/count(*),0),0) promedio
                                                        from pr_cuotas cuo, ge_cta_clientes cc
                                                       where cuo.nro_cuenta = cc.nro_cuenta
                                                         and cc.relacion = 'P'
                                                         and cc.cod_persona = p_cod_persona
                                                         and cuo.nro_cuota > 0
                                                         group by cuo.nro_cuenta)
    where cli.cod_persona = p_cod_persona
      and cli.relacion = 'P'
      and cli.nro_cuenta = nro_cta_cuo
      and pre.nro_cuenta = nro_cta_cuo
      and cli.nro_cuenta = pre.nro_cuenta
      and pre.estado <> 'N' --- Todo lo vigente
    group by pre.cod_moneda;
   --- Variables
   v_mto_cuota        pr_cuotas.mto_capital%type;
   v_cantidad         number(03);
   v_tot_prom         pr_cuotas.mto_capital%type;
   v_cod_mon_local    ba_monedas.cod_moneda%type;
   v_promedio         pr_cuotas.mto_capital%type;
   v_cotizacion       ge_cotizaciones.val_compra%type;
BEGIN
   v_cantidad := 0;
   v_tot_prom := 0;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   for cuo in c_cuotas loop
      v_cantidad := v_cantidad + 1;
      if cuo.cod_moneda = p_cod_moneda then
         v_tot_prom := v_tot_prom + cuo.promedio;
      else
         v_cotizacion := null;
         pag_gen.pr_con_mon_a_moneda(cuo.cod_moneda, p_cod_moneda,
                                     cuo.promedio, v_promedio,
                                     v_cotizacion, v_cotizacion);
         v_tot_prom := v_tot_prom + v_promedio;
      end if;
   end loop;
   --- Hallar finalmente el promedio de los promedios por moneda
/*   if v_cantidad > 0 then
      v_mto_cuota := round(v_tot_prom / v_cantidad,0);
   else
      v_mto_cuota := 0;
   end if;
*/   RETURN v_mto_cuota;
END;
/

