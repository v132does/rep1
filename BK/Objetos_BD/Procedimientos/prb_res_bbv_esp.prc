CREATE OR REPLACE PROCEDURE IT.PRB_RES_BBV_ESP (p_fecha in date,p_es_borrador in varchar2 default 'N') is

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
v_cod_consolidacion varchar2(20):='';
v_tot_mon_loc number:=0;
v_tot_mon_ext number:=0;
v_tot_prom number:=0;
v_nro_linea number:=1;
v_mes  number;
v_anho number;
v_hor_ini varchar2(8);
v_hor_fin varchar2(8);

--verificar si existe registros con cod_cosolidacion null y cod_gestion null
  cursor c_datos is
   select distinct r.cod_rubro, r.cod_rub_externo, r.cod_gestion, r.cod_consolidacion
    from cb_rubros r,
    (select a.cod_rubro,
         sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
         sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
          from cb_sal_oficinas_dia a
          where a.fecha = p_fecha
         group by a.cod_rubro)c,
       (select d.cod_rubro,
         (sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))prom_loc,
         (sum(nvl(d.tot_acumulado,0)/d.can_dia_acumulado))prom_ext
          from cb_sal_promedios d
          where d.mes= v_mes and d.ano = v_anho
         group by d.cod_rubro)x
    where r.cod_rubro=c.cod_rubro(+)
    and r.cod_rubro=x.cod_rubro(+)
    and r.imputable='S'
    and (r.cod_consolidacion is null or r.cod_gestion is null)
    and r.cod_rubro not in ('310604180100199','799998999900199','310604220100199')--a pedido de Silvia Lezcano se excluyen
    and (c.mon_loc <>0 or c.mon_ext<>0 or x.prom_loc<>0 or x.prom_ext<>0);

  cursor cu_datos is
    select nvl(r.cod_consolidacion,0) cod_consolidacion,
      r.cod_rub_externo,
      r.cod_rubro,
      r.descripcion,
      r.cod_moneda,
      c.mon_loc,
      x.prom_loc

      from cb_rubros r,
      (select a.cod_rubro,
             (sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1)mon_loc,
             (sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))*-1)mon_ext
              from cb_sal_oficinas_dia a
              where a.fecha=p_fecha
             group by a.cod_rubro)c,
      (select d.cod_rubro,
             ((sum(nvl(d.tot_acu_mon_local,0)/d.can_dia_acumulado))*-1) prom_loc,
             ((sum(nvl(d.tot_acumulado,0)/d.can_dia_acumulado))*-1) prom_ext
              from cb_sal_promedios d
              where d.mes=v_mes and d.ano = v_anho
             group by d.cod_rubro)x
      where r.cod_rubro=c.cod_rubro
      and c.cod_rubro=x.cod_rubro
      and r.cod_rubro=x.cod_rubro
      and r.imputable='S'
      and (c.mon_loc<>0 or c.mon_ext<>0 or x.prom_loc<>0 or x.prom_ext<>0)
      and r.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
      order by r.cod_consolidacion asc;

  procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRB_RES_BBV_ESP',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end;
begin
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
  v_mes := to_number(to_char(p_fecha, 'mm'));
  v_anho := to_number(to_char(p_fecha, 'yyyy'));
      if p_es_borrador <> 'S' then
        for x in c_datos loop
            begin
               dbms_output.put_line(c_datos%rowcount);
               v_success := false;
            end;
         end loop;

         if v_success = false then
             RAISE_APPLICATION_ERROR(-20000,'Faltan direccionar cod_consolidacion y/o cod_gestion');
            return;
         end if;
     end if;
  --se cera la tabla temporal en caso de que tenga datos
  begin
    execute immediate 'truncate table cb_res_bbv_esp_tmp';
    exception when others then null;
  end;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  lp_logeo('loop-1',v_hor_ini,v_hor_fin);

  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
   for reg in cu_datos loop
    if v_cod_consolidacion is null then
       v_cod_consolidacion:=reg.cod_consolidacion;
    end if;
    if v_cod_consolidacion = reg.cod_consolidacion then
          insert into cb_res_bbv_esp_tmp resbbva values(
          lpad(nvl(reg.cod_consolidacion,'0'),5,0)||chr(32)
          ||lpad(nvl(reg.cod_rub_externo,'0'),12,0) ||chr(32)
          ||lpad(nvl(reg.cod_rubro,'0'),15,0) ||chr(32)
          ||rpad(reg.cod_moneda,5,CHR(32))
          ||rpad(reg.descripcion,41,CHR(32))
          --cuando va en columna de moneda local
          ||case when reg.cod_moneda='GS' then---cuando la moneda es en GS
                  lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
            --cuentas de resultados
                 when substr(reg.cod_rubro,1,1)=6 or  substr(reg.cod_rubro,1,1)=7 then
                  lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
            --cuentas de posicion de cambio
                 when reg.cod_rubro= '510406910200105' or reg.cod_rubro='520406900400205' or reg.cod_rubro='510406910200103' or reg.cod_rubro='510406910200117' then
                  lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
                 else lpad('+0',16,CHR(32))
            end
          ---cuando va en columna de moneda extranjera
          ||case when reg.cod_moneda<>'GS' and (substr(reg.cod_rubro,1,1)<>6 AND  substr(reg.cod_rubro,1,1)<>7)
                      and (reg.cod_rubro<> '510406910200105' AND reg.cod_rubro<>'520406900400205' AND reg.cod_rubro<>'510406910200103' AND reg.cod_rubro<>'510406910200117')
            then
               lpad(case when reg.mon_loc > 0 then '+' end ||decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),17,CHR(32))
            else lpad('+0',17,CHR(32))
          end
          --
          ||lpad(case when reg.mon_loc > 0 then '+' end ||decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),17,CHR(32))
          --promedio
          ||lpad(case when reg.prom_loc > 0 then '+' end ||decode(reg.prom_loc,0,'+0',trunc((reg.prom_loc))),17,CHR(32)),
          v_nro_linea);

          v_nro_linea:=v_nro_linea+1;
          --sumariza los monto
          if reg.cod_moneda='GS' or substr(reg.cod_rubro,1,1)=6 or  substr(reg.cod_rubro,1,1)=7
              or reg.cod_rubro= '510406910200105' or reg.cod_rubro='520406900400205' or reg.cod_rubro='510406910200103' or reg.cod_rubro='510406910200117'
          then
           v_tot_mon_loc:=nvl(v_tot_mon_loc,0)+nvl(reg.mon_loc,0);
          end if;

          if reg.cod_moneda<>'GS' and (substr(reg.cod_rubro,1,1)<>'6' AND  substr(reg.cod_rubro,1,1)<>'7')  and (reg.cod_rubro<> '510406910200105' AND reg.cod_rubro<>'520406900400205' AND reg.cod_rubro<>'510406910200103' AND reg.cod_rubro<>'510406910200117')
           then
           v_tot_mon_ext:=nvl(v_tot_mon_ext,0)+nvl(reg.mon_loc,0);
          end if;

    else
        insert into cb_res_bbv_esp_tmp resbbva values(
        lpad(nvl(v_cod_consolidacion,'0'),5,0)||chr(32)
        ||lpad(chr(32),33,chr(32)) ||chr(32)
        ||rpad('TOTAL RUBRO',41,CHR(32))
        ||lpad(case when v_tot_mon_loc > 0 then '+' end || decode(v_tot_mon_loc,0,'+0',trunc((v_tot_mon_loc))),16,CHR(32))
        ||lpad(case when v_tot_mon_ext > 0 then '+' end ||decode(v_tot_mon_ext,0,'+0',trunc((v_tot_mon_ext))),17,CHR(32))
        ||lpad(case when (nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0)) > 0 then '+' end ||decode((nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0)),0,'+0',trunc(((nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0))))),17,CHR(32))
        ,v_nro_linea);
       ---cera los montos totales
        v_cod_consolidacion:=reg.cod_consolidacion;
        v_tot_mon_loc:=0;
        v_tot_mon_ext:=0;
        v_tot_prom:=0;
        v_nro_linea:=v_nro_linea+1;

        insert into cb_res_bbv_esp_tmp resbbva values(
          lpad(nvl(reg.cod_consolidacion,'0'),5,0)||chr(32)
          ||lpad(nvl(reg.cod_rub_externo,'0'),12,0) ||chr(32)
          ||lpad(nvl(reg.cod_rubro,'0'),15,0) ||chr(32)
          ||rpad(reg.cod_moneda,5,CHR(32))
          ||rpad(reg.descripcion,41,CHR(32))

         --cuando va en columna de moneda local
          ||case when reg.cod_moneda='GS' then---cuando la moneda es en GS
               lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
            --cuentas de resultados
            when substr(reg.cod_rubro,1,1)=6 or  substr(reg.cod_rubro,1,1)=7 then
              lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
            --cuentas de posicion de cambio
            when reg.cod_rubro= '510406910200105' or reg.cod_rubro='520406900400205' or reg.cod_rubro='510406910200103' or reg.cod_rubro='510406910200117' then
               lpad(case when reg.mon_loc > 0 then '+' end || decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),16,CHR(32))
            else lpad('+0',16,CHR(32))
          end
          ---cuando va en columna de moneda extranjera
          ||case when reg.cod_moneda<>'GS' and (substr(reg.cod_rubro,1,1)<>'6' AND  substr(reg.cod_rubro,1,1)<>'7')  and (reg.cod_rubro<> '510406910200105' AND reg.cod_rubro<>'520406900400205' AND reg.cod_rubro<>'510406910200103' AND reg.cod_rubro<>'510406910200117')
           then
                 lpad(case when reg.mon_loc > 0 then '+' end ||decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),17,CHR(32))
            else
                 lpad('+0',17,CHR(32))
            end
          ||lpad(case when reg.mon_loc > 0 then '+' end ||decode(reg.mon_loc,0,'+0',trunc((reg.mon_loc))),17,CHR(32))
          ||lpad(case when reg.prom_loc > 0 then '+' end ||decode(reg.prom_loc,0,'+0',trunc((reg.prom_loc))),17,CHR(32)),
          v_nro_linea);

          v_nro_linea:=v_nro_linea+1;
          --sumariza los monto
           if reg.cod_moneda='GS' or substr(reg.cod_rubro,1,1)=6 or  substr(reg.cod_rubro,1,1)=7
            or reg.cod_rubro= '510406910200105' or reg.cod_rubro='520406900400205' or reg.cod_rubro='510406910200103' or reg.cod_rubro='510406910200117'
          then
           v_tot_mon_loc:=nvl(v_tot_mon_loc,0)+nvl(reg.mon_loc,0);
          end if;

          if reg.cod_moneda<>'GS' and (substr(reg.cod_rubro,1,1)<>'6' AND  substr(reg.cod_rubro,1,1)<>'7')  and (reg.cod_rubro<> '510406910200105' AND reg.cod_rubro<>'520406900400205' AND reg.cod_rubro<>'510406910200103' AND reg.cod_rubro<>'510406910200117')
           then
           v_tot_mon_ext:=nvl(v_tot_mon_ext,0)+nvl(reg.mon_loc,0);
          end if;
   end if;
   end loop;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('loop-2',v_hor_ini,v_hor_fin);

   v_hor_ini := to_char(sysdate,'hh24:mi:ss');
   insert into cb_res_bbv_esp_tmp resbbva values(
        lpad(nvl(v_cod_consolidacion,'0'),5,0)||chr(32)
        ||lpad(chr(32),33,chr(32)) ||chr(32)
        ||rpad('TOTAL RUBRO',41,CHR(32))
        ||lpad(case when v_tot_mon_loc > 0 then '+' end || decode(v_tot_mon_loc,0,'+0',trunc((v_tot_mon_loc))),16,CHR(32))
        ||lpad(case when v_tot_mon_ext > 0 then '+' end ||decode(v_tot_mon_ext,0,'+0',trunc((v_tot_mon_ext))),17,CHR(32))
        ||lpad(case when (nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0)) > 0 then '+' end ||decode((nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0)),0,'+0',trunc(((nvl(v_tot_mon_loc,0)+nvl(v_tot_mon_ext,0))))),17,CHR(32))
        ,v_nro_linea );

    commit;
    v_hor_fin := to_char(sysdate,'hh24:mi:ss');
    lp_logeo('insert_final',v_hor_ini,v_hor_fin);

  /* -- se consulta cantidad de registros
    select count(*) into  v_cant from cb_res_bbv_esp_tmp;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'RESBBVA.PRN';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select resbbva from (select resbbva, rownum rnum from
        (select resbbva from cb_res_bbv_esp_tmp order by nro_linea asc)) a  where a.rnum  >= ' || v_ini || ' and a.rnum  <= ' || v_fin ;

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

end prb_res_bbv_esp;
/

