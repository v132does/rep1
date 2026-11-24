create or replace procedure it.prs_gen_desencajes (
   p_fecha           in  date default null,
   p_tipo            in  varchar2 default null, --'D/Dia, H/Historico'
   p_sal_cap_cov_pyg out number,
   p_cantidad_pyg    out number,
   p_sal_cap_cov_usd out number,
   p_cantidad_usd    out number)
is
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(6);
   v_redondeo   NUMBER(10);
   v_cod_moneda ba_monedas.cod_moneda%type;
begin
   if p_fecha is not null then
      v_fec_actual := p_fecha;
   end if;
   --- por si sea reproceso
   delete sb_desencajes a
    where a.fec_proceso = v_fec_actual;
   ---
   begin
      insert into sb_desencajes (nro_cuenta, fec_proceso, cod_moneda, sal_capital, mto_bruto, porcentaje)
      select p.nro_cuenta, v_fec_actual, p.cod_moneda, p.sal_cap_batch, p.mto_capital, fug_con_numero(g.val_parametro)
        from pr_cta_prestamos p, ge_cta_dat_adicionales g
       where p.nro_cuenta = g.nro_cuenta
         and g.parametro = 'POR_DESENCAJE';
   exception
      when others then
         raise_application_error(-20000,'Al Ins.SB_DESENCAJES: '||sqlerrm);
   end;
   --- Actualizar saldo de Capital
   if nvl(p_tipo,'D') = 'H' then
      update sb_desencajes d
         set d.sal_capital = (select b.sal_actual
                                from cb_sal_inventarios_his a, cb_sal_inventarios_det_his b
                               where a.nro_referencia = b.nro_referencia
                                 and a.fecha = b.fecha
                                 and a.tip_saldo = 'C'
                                 and a.fecha = d.fec_proceso
                                 and b.nro_cuenta = d.nro_cuenta)
       where d.fec_proceso = v_fec_actual
         and exists (select 1
                       from cb_sal_inventarios_his a, cb_sal_inventarios_det_his b
                      where a.nro_referencia = b.nro_referencia
                        and a.fecha = b.fecha
                        and a.tip_saldo = 'C'
                        and a.fecha = d.fec_proceso
                        and b.nro_cuenta = d.nro_cuenta);
   else
       update sb_desencajes d
          set d.sal_capital = 0
        where d.fec_proceso = v_fec_actual
          and exists (select 1 from pr_cta_prestamos p
                       where p.nro_cuenta = d.nro_cuenta
                         and p.estado in ('N','I'));
   end if;
   --- Actualizar monto de la Prevision.
   update sb_desencajes d
      set d.mto_prevision = (select nvl(a.tot_cap_pri_prevision,0) + nvl(a.tot_cap_seg_prevision,0)
                               from pr_previsiones a
                              where a.fecha = (select max(p.fecha)
                                                 from pr_previsiones p
                                                where p.fecha <= d.fec_proceso
                                                  and p.nro_cuenta = d.nro_cuenta)
                                and a.nro_cuenta = d.nro_cuenta)
    where d.fec_proceso = v_fec_actual
      and exists (select 1
                    from pr_previsiones a
                   where a.fecha = (select max(p.fecha)
                                      from pr_previsiones p
                                     where p.fecha <= d.fec_proceso
                                       and p.nro_cuenta = d.nro_cuenta)
                     and a.nro_cuenta = d.nro_cuenta);
   --- Actualizar saldo total
   update sb_desencajes a
      set a.sal_total = nvl(sal_capital,0) - nvl(mto_prevision,0)
    where a.fec_proceso = v_fec_actual;
   ---
   --- GS
   v_cod_moneda := pag_gen.FU_OBT_MON_LOCAL;
   v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, v_cod_moneda);
   --- Calcular Monto de Desencaje
   update sb_desencajes a
      set a.monto = round(nvl(sal_total,0) * nvl(porcentaje,0) / 100,v_redondeo)
    where a.cod_moneda = v_cod_moneda
      and a.fec_proceso = v_fec_actual;
   --- devolver montos calculados
   select round(nvl(sum(nvl(monto,0)),0),v_redondeo), count(*)
     into p_sal_cap_cov_pyg, p_cantidad_pyg
     from sb_desencajes
    where fec_proceso = v_fec_actual
      and cod_moneda = v_cod_moneda;

   --- USD
   v_cod_moneda := pag_gen.FU_OBT_MON_FUERTE;
   v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, v_cod_moneda);
   --- Calcular Monto de Desencaje
   update sb_desencajes a
      set a.monto = round(nvl(sal_total,0) * nvl(porcentaje,0) / 100,v_redondeo)
    where a.cod_moneda = v_cod_moneda
      and a.fec_proceso = v_fec_actual;
   --- devolver montos calculados
   select round(nvl(sum(nvl(monto,0)),0),v_redondeo), count(*)
     into p_sal_cap_cov_usd, p_cantidad_usd
     from sb_desencajes
    where fec_proceso = v_fec_actual
      and cod_moneda = v_cod_moneda;
end;
/

