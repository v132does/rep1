create or replace procedure it.prb_gen_dat_con_presupuesto(p_ano in number, p_mes in number) is
--Fechas de Inicio--
v_fec_ini_anual date := to_date('01/01/'||to_char(p_ano,'0009'),'dd/mm/yyyy');
v_fec_ini_mensual date := to_date('01/'||to_char(p_mes,'09')||'/'||to_char(p_ano,'0009'),'dd/mm/yyyy');
--Fechas de Fin--
v_fec_fin_anual date := last_day(v_fec_ini_mensual);
v_fec_fin_mensual date := last_day(v_fec_ini_mensual);
--Variables--
v_mto_presupuesto number(18,2);
v_mto_pre_acumulado number(18,2);
v_mto_acu_mov_del_mes number(18,2);
v_por_cum_mov_del_mes number(12,2);
v_mto_acu_mov_total number(18,2);
v_mto_dif_presupuesto number(18,2);
v_por_eje_presupuesto number(12,2);
--Cursor de Rubros del Presupuesto--
cursor c_rub_presupuesto is
  select a.ano, a.cod_rubro, a.monto
    from cb_rub_presupuesto a
   where a.ano = p_ano;
begin
  --Eliminar datos anteriores--
  delete from cb_con_presupuesto x
   where x.ano = p_ano
     and x.mes = p_mes;

  for rub in c_rub_presupuesto loop
      --Movimiento del Mes--
      select nvl(sum(nvl(b.deb_mon_local,0) - nvl(b.cre_mon_local,0)),0)
        into v_mto_acu_mov_del_mes
        from cb_sal_consolidados_dia b
       where b.fecha between v_fec_ini_mensual and v_fec_fin_mensual
         and b.cod_rubro = rub.cod_rubro;

      --Movimiento de todo el año--
      select nvl(sum(nvl(b.deb_mon_local,0) - nvl(b.cre_mon_local,0)),0)
        into v_mto_acu_mov_total
        from cb_sal_consolidados_dia b
       where b.fecha between v_fec_ini_anual and v_fec_fin_anual
         and b.cod_rubro = rub.cod_rubro;

      --Calculo de Variales--
      v_mto_presupuesto := rub.monto;
      v_mto_pre_acumulado := round((rub.monto/12) * p_mes,0);

      if v_mto_presupuesto = 0 then
         if v_mto_acu_mov_del_mes <> 0 then
            if v_mto_acu_mov_del_mes > 0 then
               v_por_cum_mov_del_mes := -100;
            else
               v_por_cum_mov_del_mes := 100;
            end if;
         else
            v_por_cum_mov_del_mes := 0;
         end if;
         if v_mto_acu_mov_total <> 0 then
            if v_mto_acu_mov_total > 0 then
               v_por_eje_presupuesto := -100;
            else
               v_por_eje_presupuesto := 100;
            end if;
         else
            v_por_eje_presupuesto := 0;
         end if;
      else
         v_por_cum_mov_del_mes := round((v_mto_acu_mov_del_mes/v_mto_presupuesto) * 100,2);
         v_por_eje_presupuesto := round((v_mto_acu_mov_total/v_mto_presupuesto) * 100,2);
      end if;

      v_mto_dif_presupuesto := v_mto_pre_acumulado - v_mto_acu_mov_total;

      --Inserta Datos del Presupuesto--
      insert into cb_con_presupuesto
      (ano,mes,cod_rubro,mto_presupuesto,mto_pre_acumulado,
       mto_acu_mov_del_mes,por_cum_mov_del_mes,mto_acu_mov_total,
       mto_dif_presupuesto, por_eje_presupuesto)
      values
      (p_ano,p_mes,rub.cod_rubro,v_mto_presupuesto,v_mto_pre_acumulado,
       v_mto_acu_mov_del_mes,v_por_cum_mov_del_mes,v_mto_acu_mov_total,
       v_mto_dif_presupuesto, v_por_eje_presupuesto);
  end loop;
exception
 when others then
      raise_application_error(-20000,'Error en prb_gen_dat_con_presupuesto.'||sqlerrm);
end prb_gen_dat_con_presupuesto;
/

