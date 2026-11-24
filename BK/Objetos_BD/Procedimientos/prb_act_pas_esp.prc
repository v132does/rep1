CREATE OR REPLACE PROCEDURE IT.PRB_ACT_PAS_ESP (p_fecha IN DATE)
IS
 v_fec_desde date;
 v_fec_hasta date;
 v_hor_ini varchar2(8);
 v_hor_fin varchar2(8);
 procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRB_ACT_PAS_ESP',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end;
BEGIN
  v_fec_desde := trunc(p_fecha, 'month');
  v_fec_hasta := p_fecha;
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
   BEGIN
      -- Se cera la tabla temporal en caso de que exista datos.
      EXECUTE IMMEDIATE 'truncate table cb_act_pas_esp_tmp';
      EXCEPTION WHEN OTHERS THEN NULL;
   END;

   -- Tipo 1.
   EXECUTE IMMEDIATE('insert into cb_act_pas_esp_tmp select ''MES;T;DIV;DIA;IMPORTE_DIV;IMPORTE_GS.;'' line from dual');

   insert into cb_act_pas_esp_tmp
   select to_char(a.fecha,'mm')||';1;'
     ||decode(r.cod_moneda,'GS','00','USD','05','EUR','17','JPY','14','CAD','28','GBP','10', 'CHF','07','ARS','15','BRL','03')||';'||to_char(a.fecha,'dd')||';'
     ||case when r.cod_moneda = 'GS' then
     lpad(trunc((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))-trunc(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))),3,0),-2)
     else
     lpad(trunc((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))-trunc(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))),3,0),-2)
     end
     ||';'
     ||lpad((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1),19,CHR(32))
     line
     from cb_rubros r, cb_sal_oficinas_dia a
     where a.cod_rubro=r.cod_rubro
       and a.fecha >= v_fec_desde and a.fecha <= v_fec_hasta
       and r.imputable='S'
       and substr(r.cod_rubro,1,5)<20000--activo
       and substr(r.cod_rubro,6,3) not in (145,353,369) --Derivados Activo
     group by r.cod_moneda, a.fecha
     having (sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1) <> 0

   --grupo 2
     union
     select to_char(a.fecha,'mm')||';2;'
     ||decode(r.cod_moneda,'GS','00','USD','05','EUR','17','JPY','14','CAD','28','GBP','10', 'CHF','07','ARS','15','BRL','03')||';'||to_char(a.fecha,'dd')||';'
     ||case when r.cod_moneda = 'GS' then
     lpad(trunc((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))-trunc(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))),3,0),-2)
     else
     lpad(trunc((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))-trunc(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))),3,0),-2)
     end
     ||';'
     ||lpad((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1),19,CHR(32))
     line
     from cb_rubros r, cb_sal_oficinas_dia a
     where a.cod_rubro=r.cod_rubro
       and a.fecha >= v_fec_desde and a.fecha <= v_fec_hasta
       and r.imputable='S'
       and substr(r.cod_rubro,1,5)> 20000
       and substr(r.cod_rubro,1,5)< 40000 --pasivo
       and substr(r.cod_rubro,6,3) not in (118,180,198) --Derivados Pasivo
     group by r.cod_moneda, a.fecha
     having (sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1) <> 0

   --grupo 7
     union
     select to_char(a.fecha,'mm')||';7;'
     ||decode(r.cod_moneda,'GS','00','USD','05','EUR','17','JPY','14','CAD','28','GBP','10', 'CHF','07','ARS','15','BRL','03')||';'||to_char(a.fecha,'dd')||';'
     ||case when r.cod_moneda = 'GS' then
     lpad(trunc((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))-trunc(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))),3,0),-2)
     else
     lpad(trunc((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))-trunc(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))),3,0),-2)
     end
     ||';'
     ||lpad((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1),19,CHR(32))
     line
     from cb_rubros r, cb_sal_oficinas_dia a
     where a.cod_rubro=r.cod_rubro
       and a.fecha >= v_fec_desde and a.fecha <= v_fec_hasta
       and r.imputable='S'
       and substr(r.cod_rubro,6,3) in (145,353,369) --Derivados Activo
     group by r.cod_moneda, a.fecha
     having (sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1) <> 0

   --grupo 8
     union
     select to_char(a.fecha,'mm')||';8;'
     ||decode(r.cod_moneda,'GS','00','USD','05','EUR','17','JPY','14','CAD','28','GBP','10', 'CHF','07','ARS','15','BRL','03')||';'||to_char(a.fecha,'dd')||';'
     ||case when r.cod_moneda = 'GS' then
     lpad(trunc((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))-trunc(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))))),3,0),-2)
     else
     lpad(trunc((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)),17,CHR(32))||','||substr(rpad(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))-trunc(abs((sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))))),3,0),-2)
     end
     ||';'
     ||lpad((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1),19,CHR(32))
     line
     from cb_rubros r, cb_sal_oficinas_dia a
     where a.cod_rubro=r.cod_rubro
       and a.fecha >= v_fec_desde and a.fecha <= v_fec_hasta
       and r.imputable='S'
       and substr(r.cod_rubro,6,3) in (118,180,198) --Derivados Pasivo
     group by r.cod_moneda, a.fecha
     having (sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1) <> 0;

-----------------------------------------------------------------------------------------------

 commit;
 v_hor_fin := to_char(sysdate,'hh24:mi:ss');
 lp_logeo('CodeSection',v_hor_ini,v_hor_fin);

end prb_act_pas_esp;
/

