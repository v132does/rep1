CREATE OR REPLACE PROCEDURE IT.PRB_ESP_RA13407 (p_fecha in date,p_es_borrador in varchar2 default 'N') is
--Desarrollado por Simgia - Agosto 2011
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
v_hor_ini varchar2(8);
v_hor_fin varchar2(8);

--verificar si existe registros con cod_cosolidacion null y cod_gestion null
  cursor c_datos is
      select r.cod_consolidacion, r.cod_rub_externo
      from cb_rubros r,cb_sal_oficinas_dia a
      where a.fecha=p_fecha
      and r.cod_rubro=a.cod_rubro
      and r.imputable='S'
      and r.cod_consolidacion is null
      and r.cod_rubro not in ('310604180100199','799998999900199','310604220100199')--cuentas perdidas y ganancias
      and (nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))<>0
      and (r.cod_consolidacion<>5900 or r.cod_consolidacion is null)
      group by r.cod_consolidacion, r.cod_rub_externo;

  procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRB_ESP_RA13407',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end;
begin
  v_hor_ini := to_char(sysdate,'hh24:mi:ss');
   if p_es_borrador <> 'S' then
     for x in c_datos loop
        begin
           dbms_output.put_line(c_datos%rowcount);
           v_success := false;
        end;
     end loop;
   end if;

   if v_success = false then
       RAISE_APPLICATION_ERROR(-20000,'Falta direccionar cuenta');
      return;
   end if;

  --se cera la la tabla temporal en caso de que tenga datos
  begin
    execute immediate 'truncate table cb_ra1_3407_esp_tmp';
    exception when others then null;
  end;

 --se insertan los datos en la tabla temporal
      insert into cb_ra1_3407_esp_tmp
      select
      rpad('07',15,CHR(32))
      ||lpad(nvl(r.cod_consolidacion,0),5,0)
      ||CHR(32)
      ||lpad(0,16,0)
      ||'+'
      ||lpad(trunc(abs((sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)))/1000)),16,0)
      ||decode(abs(sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1),(sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))*-1), '+' , '-') LINEA
      from cb_rubros r,cb_sal_oficinas_dia a
      where a.fecha = p_fecha
      and r.cod_rubro=a.cod_rubro
      and r.imputable='S'
      and r.cod_rubro not in ('310604180100199','799998999900199','310604220100199')
      and (r.cod_consolidacion <>59000 or r.cod_consolidacion is null)
      group by r.cod_consolidacion
      order by r.cod_consolidacion asc;

      commit;


     /* -- se consulta cantidad de registros
      select count(*) into  v_cant from cb_ra1_3407_esp_tmp;

      -- redondeo por exeso parcheado
      v_paginas := round(v_cant/p_corte) + 1;


     V_NOM := 'RA13407.TXT';
     v_cont := 1;
     v_ini := 1;
     v_fin := p_corte;


     FOR v_cont IN 1 .. v_paginas
     LOOP

        V_SQL := 'select * from (select line, rownum rnum from
        (select * from cb_ra1_3407_esp_tmp)) a  where a.rnum  >= ' || v_ini || ' and a.rnum  <= ' || v_fin ;

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
     v_hor_fin := to_char(sysdate,'hh24:mi:ss');
     lp_logeo('CodeSection',v_hor_ini,v_hor_fin);

end prb_esp_ra13407;
/

