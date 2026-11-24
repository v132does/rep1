CREATE OR REPLACE PROCEDURE IT.PRB_ESP_BALBBVA(p_fecha in date,p_es_borrador in varchar2 default 'N') is
--Desarrollado por Simgia Agosto 2011
v_paginas number := 0;
v_cont number := 0;
v_cont2 number := 0;
v_cant number := 0;
v_ini number := 0;
v_fin number := 0;
V_NOM varchar2(100) := '';
V_SQL varchar2(1000) := '';
p_corte number:= 9000;
v_success boolean:=true;
v_mes_inf varchar2(1) := null; -- A: Actual ; P: Pasado
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
v_mes  number;
v_anho number;
-- Variables para envío de mail
 c_dir_mail      ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
 v_dir_mail_deb  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_DIF_CONTABLE') ;
 v_texto         varchar2(4000);--dydmr-8737
 v_error         varchar2(1) := 'N';
 v_hor_ini varchar2(8);
 v_hor_fin varchar2(8);

--verificar si existe registros con cod_cosolidacion null y cod_gestion null
  cursor c_datos is
   select r.cod_rubro, r.cod_gestion, r.cod_consolidacion
    from cb_rubros r,
      (select a.cod_rubro,
         sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
         sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
          from cb_sal_oficinas_dia a
          where a.fecha=p_fecha
         group by a.cod_rubro)c,

       (select d.cod_rubro,
         (sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))prom_loc,
         (sum(case when cr.cod_moneda = v_cod_mon_local then 0 else ((nvl(d.tot_acu_mon_local,0)/pag_gen.fu_obt_cotizacion(cr.cod_moneda,p_fecha))/d.can_dia_acumulado) end))prom_ext
          from cb_sal_promedios d, cb_rubros cr
          where d.mes = v_mes and d.ano = v_anho
            and d.cod_rubro = cr.cod_rubro
         group by d.cod_rubro)x
    where r.cod_rubro=c.cod_rubro(+)
    and r.cod_rubro=x.cod_rubro(+)
    and r.imputable='S'
    and (r.cod_consolidacion is null or r.cod_gestion is null)
    and r.cod_rubro not in ('310604180100199','799998999900199','310604220100199')--cuentas perdidas y ganancias excluido a pedido de Silvia Lezcano
    and (c.mon_loc <>0 or c.mon_ext<>0 or x.prom_loc<>0 or x.prom_ext<>0)
    group by r.cod_rubro, r.cod_rubro, r.cod_gestion, r.cod_consolidacion;

   cursor c_control is
   select max(abs(mon_loc)) v_dif_total, cod_oficina
       from (
              select x.cod_oficina,  sum(saldo_puntual) mon_loc, 0 mon_ext
              from (
              select  c.cod_oficina,
              decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)) cod_iso,
              sum (decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',c.mon_loc,
                                   c.mon_ext) ) saldo_puntual,
              decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0')) tip_sal_pun

                   from (select a.cod_oficina,a.cod_rubro,
                     sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
                     sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
                      from cb_sal_oficinas_dia a
                      where a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
                      and a.fecha=p_fecha
                     group by a.cod_oficina,a.cod_rubro) c,
                     cb_rubros r, ba_monedas b
                where c.cod_rubro=r.cod_rubro
                and r.cod_moneda=b.cod_moneda
                and r.imputable='S'
                and (c.mon_loc <>0 or c.mon_ext<>0 )
                group by c.cod_oficina,
                decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),
                decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0'))
                ) x
                group by x.cod_oficina, x.cod_iso) t
                group by cod_oficina;

  procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRB_ESP_BALBBVA',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end;

begin
  v_mes := to_number(to_char(p_fecha, 'mm'));
  v_anho := to_number(to_char(p_fecha, 'yyyy'));
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
--descomentar para poner en produccion
   for x in c_datos loop
      begin
         dbms_output.put_line(c_datos%rowcount);
         v_success := false;
      end;
   end loop;

   if p_es_borrador <> 'S' then
     if v_success = false then
         RAISE_APPLICATION_ERROR(-20000,'Existen rubros contables que no tienen cod_consolidacion y/o cod_gestion');
        return;
     end if;

     Begin
       for reg in c_control loop
         if nvl(reg.v_dif_total,0) >=500 then
            --RAISE_APPLICATION_ERROR(-20000,'Las diferencias entre créditos y débitos superan los 500 GS');
            v_error     := 'S' ;
            v_texto := v_texto || ' Oficina: '|| reg.cod_oficina  || chr(9) ||
                                  ' Monto Diferencia: ' || to_char(nvl(reg.v_dif_total,0),'999G999G999G999G999') ||
                                   chr(9) ||  chr(10)|| chr(13) ;
         end if;
       end loop;
      end;
   end if;
  --se cera la tabla temporal en caso de que tenga datos
  begin
    execute immediate 'truncate table cb_bal_bbv_esp_tmp';
    exception when others then null;
  end;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  lp_logeo('CodeSection-1',v_hor_ini,v_hor_fin);
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');

  --se evalua si es mes actual o anterior, para calculo de promedios
  if to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'mm') = to_char(p_fecha,'mm') then
     v_mes_inf := 'A'; --Actual
  else
     v_mes_inf := 'P'; --Pasado
  end if;

  --tipo 1
--  execute immediate('insert into cb_bal_bbv_esp_tmp select ''01''||7714|| '''||to_char(p_fecha ,'yyyymmdd')||'''||''000001''||1  from dual');
  execute immediate('insert into cb_bal_bbv_esp_tmp select ''01''||7714|| '''||to_char(p_fecha ,'yyyymmdd')||'''||''5''  from dual');

 --tipo 2
  insert into cb_bal_bbv_esp_tmp
     select balbbva from (
  select '02'||lpad(nvl(r.cod_rubro,'0'),15,0)
  ||lpad(nvl(r.cod_consolidacion,'0'),5,0)
  ||lpad(nvl(r.cod_gestion,0),5,0)
  ||rpad(r.descripcion,31,CHR(32))
  ||decode(r.tipo,1,1,2,2,0)
  ||case when r.tipo = 1 or r.tipo=2 or r.tipo=3 then
      1
     when r.tipo=4 or r.tipo=5 then
      3
     else 2 end
  balbbva
  from cb_rubros r,
     (select a.cod_rubro,
       sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
       sum(nvl(abs(a.sal_mon_loc_ant),0)+nvl(abs(a.deb_mon_local),0)-nvl(abs(a.cre_mon_local),0))mon_loc_ctrl,
       sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext,
       sum(nvl(abs(a.sal_mon_rub_ant),0)+nvl(abs(a.deb_mon_rubro),0)-nvl(abs(a.cre_mon_rubro),0))mon_ext_ctrl
        from cb_sal_oficinas_dia a
        where a.fecha = p_fecha
        and a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
       group by a.cod_rubro)c,

     (select d.cod_rubro,
       (sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))prom_loc,
       (sum((nvl(abs(d.tot_acu_mon_local),0)/d.can_dia_acumulado)))prom_loc_ctrl,
       (sum(case when cr.cod_moneda = v_cod_mon_local then 0 else ((nvl(d.tot_acu_mon_local,0)/pag_gen.fu_obt_cotizacion(cr.cod_moneda,'30/09/2020'))/d.can_dia_acumulado)end))prom_ext,
       (sum(case when cr.cod_moneda = v_cod_mon_local then 0 else ((nvl(abs(d.tot_acu_mon_local),0)/pag_gen.fu_obt_cotizacion(cr.cod_moneda,'30/09/2020'))/d.can_dia_acumulado)end))prom_ext_ctrl
        from cb_sal_promedios d, cb_rubros cr
        where d.mes = v_mes and d.ano = v_anho
        and d.cod_rubro  not in ('310604180100199','799998999900199','310604220100199')
        and d.cod_rubro = cr.cod_rubro
       group by d.cod_rubro)x
     where r.cod_rubro=c.cod_rubro
      and r.cod_rubro=x.cod_rubro
      and r.imputable='S'
      and (c.mon_loc <>0 or c.mon_ext<>0 or mon_loc_ctrl<>0 or mon_ext_ctrl<>0 or x.prom_loc<>0 or x.prom_ext<>0 or x.prom_loc_ctrl<>0 or x.prom_ext_ctrl<>0)
     )
     group by balbbva;


    --tipo 3

    insert into cb_bal_bbv_esp_tmp
    select '03'
    ||b.cod_mon_iso||
    lpad(trunc(abs((nvl(fug_obt_cotizacion(b.cod_moneda,p_fecha ),1)))),7,0)
    || substr(rpad((nvl(abs((nvl(fug_obt_cotizacion(b.cod_moneda,
    p_fecha),1))),0)-
    trunc(nvl(abs((nvl(fug_obt_cotizacion(b.cod_moneda,p_fecha),1))),0))),9,0),-8)
    from ba_monedas b
    where b.cod_mon_iso is not null;

    --tipo 4
    if v_mes_inf = 'P' then
      insert into cb_bal_bbv_esp_tmp
      select '04'
      ||lpad(nvl(c.cod_oficina,'0'),4,0)
      ||lpad(nvl(r.cod_rubro,'0'),15,0)
      ||decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso))
      ||decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',(lpad(trunc(abs(c.mon_loc)),15,0) || substr(rpad((nvl(abs(c.mon_loc),0)-trunc(nvl(abs(c.mon_loc),0))),3,0),-2)),
                           (lpad(trunc(abs(c.mon_ext)),15,0) || substr(rpad((nvl(abs(c.mon_ext),0)-trunc(nvl(abs(c.mon_ext),0))),3,0),-2)))
      ||decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0'))
      ||decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',(lpad(trunc(abs(nvl(x.prom_loc,0))),15,0) || substr(rpad((nvl(abs(x.prom_loc),0)-trunc(nvl(abs(x.prom_loc),0))),3,0),-2)),
                           (lpad(trunc(abs(nvl(x.prom_ext,0))),15,0) || substr(rpad((nvl(abs(x.prom_ext),0)-trunc(nvl(abs(x.prom_ext),0))),3,0),-2)))
      ||decode(nvl(x.prom_loc,0),0,'0',decode(abs(nvl(x.prom_loc,0)),nvl(x.prom_loc,0) , 1, '0'))
      balbbva

      from (select t.cod_oficina,t.cod_rubro, sum(mon_loc) mon_loc, sum(mon_ext) mon_ext
             from(
               select
               a.cod_oficina,a.cod_rubro,
               sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
               sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
                from cb_sal_oficinas_dia a
                where a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
                and a.fecha = p_fecha
                group by a.cod_oficina,a.cod_rubro

             UNION
              -- calcula la diferencia que hay que sumar al rubro cta corrientes gs
                select x.cod_oficina, '221101360200199' cod_rubro , sum(saldo_puntual*-1) mon_loc, 0 mon_ext
                from
                (
                select  c.cod_oficina,
                decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)) cod_iso,
                sum (decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',c.mon_loc,
                                     c.mon_ext) ) saldo_puntual,
                decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0')) tip_sal_pun
                                 from (select a.cod_oficina,a.cod_rubro,
                     sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
                     sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
                      from cb_sal_oficinas_dia a
                      where a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
                      and a.fecha = p_fecha
                     group by a.cod_oficina,a.cod_rubro) c,
                     cb_rubros r, ba_monedas b
                where c.cod_rubro=r.cod_rubro
                and r.cod_moneda=b.cod_moneda
                and r.imputable='S'
                and (c.mon_loc <>0 or c.mon_ext<>0 )
                group by c.cod_oficina,
                decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),
                decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0'))
                ) x
                 group by x.cod_oficina, x.cod_iso) t
                 group by t.cod_oficina,t.cod_rubro
             )c,

           (select d.cod_rubro,d.cod_oficina,
             (sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))prom_loc,
             (sum(case when cr.cod_moneda = v_cod_mon_local then 0 else ((nvl(d.tot_acu_mon_local,0)/pag_gen.fu_obt_cotizacion(cr.cod_moneda,'30/09/2020'))/d.can_dia_acumulado)end))prom_ext
              from cb_sal_promedios d, cb_rubros cr
              where d.mes = v_mes and d.ano = v_anho
              and d.cod_rubro  not in ('310604180100199','799998999900199','310604220100199')
              and d.cod_rubro = cr.cod_rubro
             group by d.cod_rubro,d.cod_oficina)x,
      cb_rubros r, ba_monedas b
        where c.cod_rubro=r.cod_rubro
        and r.cod_moneda=b.cod_moneda
        and c.cod_rubro=x.cod_rubro
        and c.cod_oficina=x.cod_oficina
        and r.imputable='S'
        and (c.mon_loc <>0 or c.mon_ext<>0 or x.prom_loc<>0 or x.prom_ext<>0);


      else
        --aqui la consulta con promedios calculados
      insert into cb_bal_bbv_esp_tmp
      select '04'
      ||lpad(nvl(c.cod_oficina,'0'),4,0)
      ||lpad(nvl(r.cod_rubro,'0'),15,0)
      ||decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso))
      ||decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',(lpad(trunc(abs(c.mon_loc)),15,0) || substr(rpad((nvl(abs(c.mon_loc),0)-trunc(nvl(abs(c.mon_loc),0))),3,0),-2)),
                           (lpad(trunc(abs(c.mon_ext)),15,0) || substr(rpad((nvl(abs(c.mon_ext),0)-trunc(nvl(abs(c.mon_ext),0))),3,0),-2)))
      ||decode(abs(c.mon_loc),c.mon_loc , 1, '0')
      ||decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',(lpad(trunc(abs(nvl(FUB_OBT_SAL_PRO_CUENTA(to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML'),0))),15,0) || substr(rpad((nvl(abs(FUB_OBT_SAL_PRO_CUENTA( to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML')),0)-trunc(nvl(abs(FUB_OBT_SAL_PRO_CUENTA(to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML')),0))),3,0),-2)),
                           (lpad(trunc(abs(nvl(FUB_OBT_SAL_PRO_CUENTA( to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ME'),0))),15,0) || substr(rpad((nvl(abs(FUB_OBT_SAL_PRO_CUENTA( to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ME')),0)-trunc(nvl(abs(FUB_OBT_SAL_PRO_CUENTA( to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML')),0))),3,0),-2)))
      ||decode(abs(FUB_OBT_SAL_PRO_CUENTA( to_date( '30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML')),FUB_OBT_SAL_PRO_CUENTA( to_date('30/09/2020','dd/mm/yyyy'),c.cod_rubro,c.cod_oficina,'ML') , 1, '0')
      balbbva

      from (select t.cod_oficina,t.cod_rubro, sum(mon_loc) mon_loc, sum(mon_ext) mon_ext
             from(
               select
               a.cod_oficina,a.cod_rubro,
               sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
               sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
                from cb_sal_oficinas_dia a
                where a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
                and a.fecha = p_fecha
                group by a.cod_oficina,a.cod_rubro

             UNION
              -- calcula la diferencia que hay que sumar al rubro cta corrientes gs
                select x.cod_oficina, '221101360200199' cod_rubro , sum(saldo_puntual*-1) mon_loc, 0 mon_ext
                from
                (
                select  c.cod_oficina,
                decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)) cod_iso,
                sum (decode(decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),'PYG',c.mon_loc,
                                     c.mon_ext) ) saldo_puntual,
                decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0')) tip_sal_pun
                                 from (select a.cod_oficina,a.cod_rubro,
                     sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
                     sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
                      from cb_sal_oficinas_dia a
                      where a.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
                      and a.fecha = p_fecha
                     group by a.cod_oficina,a.cod_rubro) c,
                     cb_rubros r, ba_monedas b
                where c.cod_rubro=r.cod_rubro
                and r.cod_moneda=b.cod_moneda
                and r.imputable='S'
                and (c.mon_loc <>0 or c.mon_ext<>0 )
                group by c.cod_oficina,
                decode(substr(r.cod_rubro,1,1),6,'PYG',7,'PYG',decode(substr(r.cod_rubro,6,3),'691','PYG','690',b.cod_mon_iso,b.cod_mon_iso)),
                decode(nvl(c.mon_loc,0),0,'0',decode(abs(nvl(c.mon_loc,0)),nvl(c.mon_loc,0) , 1, '0'))
                ) x
                 group by x.cod_oficina, x.cod_iso) t
                 group by t.cod_oficina,t.cod_rubro
             )c,

            (select d.cod_rubro,d.cod_oficina,
             (sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))prom_loc,
             (sum(case when cr.cod_moneda = v_cod_mon_local then 0 else (nvl(d.tot_acu_mon_local,0)/pag_gen.fu_obt_cotizacion(cr.cod_moneda,'30/09/2020'))/d.can_dia_acumulado end))prom_ext
              from cb_sal_promedios d, cb_rubros cr
              where d.mes = v_mes and d.ano = v_anho
              and d.cod_rubro  not in ('310604180100199','799998999900199','310604220100199')
              and d.cod_rubro = cr.cod_rubro
             group by d.cod_rubro,d.cod_oficina)x,
      cb_rubros r, ba_monedas b
        where c.cod_rubro=r.cod_rubro
        and r.cod_moneda=b.cod_moneda
        and c.cod_rubro=x.cod_rubro
        and c.cod_oficina=x.cod_oficina
        and r.imputable='S'
        and (c.mon_loc <>0 or c.mon_ext<>0 or x.prom_loc<>0 or x.prom_ext<>0);

      end if;
       commit;
    /*  -- se consulta cantidad de registros
      select count(*) into  v_cant from cb_bal_bbv_esp_tmp;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'BALBBVA';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select * from (select balbbva, rownum rnum from
        (select * from cb_bal_bbv_esp_tmp order by balbbva)) a  where a.rnum  >= ' || v_ini || ' and a.rnum  <= ' || v_fin ;

       -- dbms_output.put_line(V_SQL);
        if v_cont2 = 0 then
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'N');
        else
           prg_gen_archivo_txt(trim(V_NOM),V_SQL,'N',null,'S');
        end if;

        v_ini := v_fin + 1;
        v_fin := v_fin + p_corte;
        v_cont2 := v_cont2 + 1;
     END LOOP;*/
   Begin
      if v_error = 'S' then

         v_texto := 'Se comunica que el proceso "PRB_ESP_BALBBVA" de Generación de Informe a Espanha tiene diferencias'|| chr(10) ||chr(13)||
                    'En fecha : '||p_fecha||chr(10) ||chr(13)||
                    'A continuación se detallan las diferencias por oficina; ' ||chr(10) ||chr(13)||
                    v_texto|| chr(10) ||chr(13)||
                    'Atte. JSALA';

          if v_dir_mail_deb is null then
             -- En caso de no definir el parametro envíar a EP
             v_dir_mail_deb := fug_obt_pardinamico('CAM_MAR_DIR_EP');--'ep.py@bbva.com' ;
          end if ;

          it_mail.mail(c_dir_mail,
                       v_dir_mail_deb,
                       'SE ENCONTRARON DIFERENCIAS AL GENERAR EL REPORTE A ESPANHA',
                       v_texto);


      end if ;
   exception
      when others then
         null ;
   END ;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('CodeSection-2',v_hor_ini,v_hor_fin);

end prb_esp_balbbva;
/

