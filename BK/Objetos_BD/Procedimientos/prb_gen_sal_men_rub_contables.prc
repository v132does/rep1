create or replace procedure it.prb_gen_sal_men_rub_contables(p_ano in number) is
--Variables--
v_mes number(2);

--Cursor de Meses--
cursor c_mes is
select distinct a.mes
  from cb_sal_oficinas_his a
 where a.ano = p_ano
union all
select distinct a.mes
  from cb_sal_oficinas a
 where a.ano = p_ano;

--Cursor de Rubros--
cursor c_rubros is
select a.cod_oficina, a.cod_rubro,
       --nvl(a.sal_mon_loc_ant,0) +
       nvl(a.cre_mon_local,0) -
       nvl(a.deb_mon_local,0) sal_mon_local
  from cb_sal_oficinas_his a
 where a.ano = p_ano
   and a.mes = v_mes
union all
select a.cod_oficina, a.cod_rubro,
       --nvl(a.sal_mon_loc_ant,0) +
       nvl(a.cre_mon_local,0) -
       nvl(a.deb_mon_local,0) sal_mon_local
  from cb_sal_oficinas a
 where a.ano = p_ano
   and a.mes = v_mes;

--Procedimiento de Actualizacion--
procedure pr_act_datos(p_mes in number, p_cod_oficina in number, p_cod_rubro in varchar2, p_sal_mon_local in number) is
begin
  update cb_sal_anuales a
     set a.sal_mon_loc_mes_01 = decode(p_mes,1,p_sal_mon_local,a.sal_mon_loc_mes_01),
         a.sal_mon_loc_mes_02 = decode(p_mes,2,p_sal_mon_local,a.sal_mon_loc_mes_02),
         a.sal_mon_loc_mes_03 = decode(p_mes,3,p_sal_mon_local,a.sal_mon_loc_mes_03),
         a.sal_mon_loc_mes_04 = decode(p_mes,4,p_sal_mon_local,a.sal_mon_loc_mes_04),
         a.sal_mon_loc_mes_05 = decode(p_mes,5,p_sal_mon_local,a.sal_mon_loc_mes_05),
         a.sal_mon_loc_mes_06 = decode(p_mes,6,p_sal_mon_local,a.sal_mon_loc_mes_06),
         a.sal_mon_loc_mes_07 = decode(p_mes,7,p_sal_mon_local,a.sal_mon_loc_mes_07),
         a.sal_mon_loc_mes_08 = decode(p_mes,8,p_sal_mon_local,a.sal_mon_loc_mes_08),
         a.sal_mon_loc_mes_09 = decode(p_mes,9,p_sal_mon_local,a.sal_mon_loc_mes_09),
         a.sal_mon_loc_mes_10 = decode(p_mes,10,p_sal_mon_local,a.sal_mon_loc_mes_10),
         a.sal_mon_loc_mes_11 = decode(p_mes,11,p_sal_mon_local,a.sal_mon_loc_mes_11),
         a.sal_mon_loc_mes_12 = decode(p_mes,12,p_sal_mon_local,a.sal_mon_loc_mes_12)
   where a.ano = p_ano
     and a.cod_oficina = p_cod_oficina
     and a.cod_rubro = p_cod_rubro;
  IF SQL%NOTFOUND THEN
     insert into cb_sal_anuales
     (ano, cod_oficina, cod_rubro,
      sal_mon_loc_mes_01, sal_mon_loc_mes_02, sal_mon_loc_mes_03,
      sal_mon_loc_mes_04, sal_mon_loc_mes_05, sal_mon_loc_mes_06,
      sal_mon_loc_mes_07, sal_mon_loc_mes_08, sal_mon_loc_mes_09,
      sal_mon_loc_mes_10, sal_mon_loc_mes_11, sal_mon_loc_mes_12)
     values
     (p_ano, p_cod_oficina, p_cod_rubro,
      decode(p_mes,1,p_sal_mon_local,0),
      decode(p_mes,2,p_sal_mon_local,0),
      decode(p_mes,3,p_sal_mon_local,0),
      decode(p_mes,4,p_sal_mon_local,0),
      decode(p_mes,5,p_sal_mon_local,0),
      decode(p_mes,6,p_sal_mon_local,0),
      decode(p_mes,7,p_sal_mon_local,0),
      decode(p_mes,8,p_sal_mon_local,0),
      decode(p_mes,9,p_sal_mon_local,0),
      decode(p_mes,10,p_sal_mon_local,0),
      decode(p_mes,11,p_sal_mon_local,0),
      decode(p_mes,12,p_sal_mon_local,0));
  END IF;
end;
begin
null;
--Elimina los registros del mismo año--
delete from cb_sal_anuales a
where a.ano = p_ano;

--Ciclo Principal de Insercion de Datos--
for mes in c_mes loop
    v_mes := mes.mes;
    for rub in c_rubros loop
        pr_act_datos(v_mes, rub.cod_oficina, rub.cod_rubro, rub.sal_mon_local);
    end loop;
end loop;
exception
 when others then
      raise_application_error(-20000, 'Error en prb_gen_sal_men_rub_contables : '||sqlerrm);
end prb_gen_sal_men_rub_contables;
/

