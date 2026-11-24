create or replace procedure it.prb_gen_sal_promedios is

 --Definicion del Tipo de Dato Vector--
 type vector is table of date index by binary_integer;

 --Definicion de Variables--
 v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(2);
 v_fec_inicial date := to_date('01'||to_char(v_fecha,'/mm/yyyy'),'dd/mm/yyyy');
 v_fec_final date := last_day(v_fecha);
 v_indice number(2);
 v_vec_fecha vector;
 v_fec_auxiliar date;
 v_fec_insertar date;
 v_mes number(2) := to_number(to_char(v_fecha,'mm'));
 v_ano number(4) := to_number(to_char(v_fecha,'yyyy'));
 v_cod_mon_fuerte ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_FUERTE;
 v_val_cot_mon_fuerte ge_cotizaciones.val_conversion%type;
 v_ult_dia_mes_habil date;

 --Definicion de Cursor--
 cursor c_fechas is
   select distinct a.fecha
     from cb_sal_oficinas_dia a
    where a.fecha between v_fec_inicial and v_fecha
   union all
   select v_fecha from dual;
begin
 --Obtener Ultimo Día del Mes Habil--
  pag_cal.PR_OBT_DAT_CALENDAR(2);
  v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;

  if v_fecha < v_ult_dia_mes_habil then
     v_fec_final := v_fecha;
  end if;

 --01) Insertar Resgistros de Detalle--
 --Eliminar registros anteriores--
 delete from cb_sal_promedios_det x
  where x.fecha between v_fec_inicial and v_fec_final;

 --Obtener fecha auxiliar--
 SELECT max(y.fecha)
   into v_fec_auxiliar
   FROM cb_sal_oficinas_dia y, cb_rubros x
  WHERE y.fecha < v_fec_inicial
    and x.cod_rubro = y.cod_rubro
    and x.imputable = 'S';

 --Inicializar el vector--
 for v_indice in 1..to_number(to_char(v_fec_final,'dd')) loop
     v_vec_fecha(v_indice) := null;
 end loop;

 --Cargar las fechas que existen--
 for fec in c_fechas loop
     v_vec_fecha(to_number(to_char(fec.fecha,'DD'))) := fec.fecha;
 end loop;

 --Completar Fechas--
 for v_indice in 1..to_number(to_char(v_fec_final,'dd')) loop
     if v_vec_fecha(v_indice) is null then
        v_vec_fecha(v_indice) := v_fec_auxiliar;
     else
        v_fec_auxiliar := to_date(trim(to_char(v_indice,'00'))||to_char(v_fec_final,'/mm/yyyy'),'dd/mm/yyyy');
     end if;
 end loop;

 for v_indice in 1..to_number(to_char(v_fec_final,'dd')) loop
     dbms_output.put_line('fecha ('||to_char(v_indice)||'): '||to_char(v_vec_fecha(v_indice),'dd/mm/yyyy'));
 end loop;

 --Insertar todos los registros--
 for v_indice in 1..to_number(to_char(v_fec_final,'dd')) loop
     v_fec_insertar := v_vec_fecha(v_indice);
     v_fec_auxiliar := to_date(trim(to_char(v_indice,'00'))||to_char(v_fec_final,'/mm/yyyy'),'dd/mm/yyyy');
     v_val_cot_mon_fuerte := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte, v_fec_insertar);
     if v_fec_insertar = v_fecha then
        INSERT INTO cb_sal_promedios_det
        (cod_oficina,cod_rubro,fecha,
         sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
         sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
         sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
         cre_equ_local, sal_ini_mes_equ_local, val_cot_mon_fuerte,
         sal_mon_loc_actual, sal_mon_fue_actual)
        select cod_oficina,a.cod_rubro,v_fec_auxiliar,
               sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
               sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
               sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
               cre_equ_local, sal_ini_mes_equ_local, v_val_cot_mon_fuerte,
               nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0),
               round((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))/v_val_cot_mon_fuerte,2)
          from cb_sal_oficinas a, cb_rubros x
         where ano = v_ano
           and mes = v_mes
           and x.cod_rubro = a.cod_rubro
           and x.imputable = 'S';
     else
        INSERT INTO cb_sal_promedios_det
        (cod_oficina,cod_rubro,fecha,
         sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
         sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
         sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
         cre_equ_local, sal_ini_mes_equ_local, val_cot_mon_fuerte,
         sal_mon_loc_actual, sal_mon_fue_actual)
        select cod_oficina,a.cod_rubro,v_fec_auxiliar,
               sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
               sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
               sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
               cre_equ_local, sal_ini_mes_equ_local, v_val_cot_mon_fuerte,
               nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0),
               round((nvl(sal_mon_loc_ant,0)+nvl(deb_mon_local,0)-nvl(cre_mon_local,0))/v_val_cot_mon_fuerte,2)
          from cb_sal_oficinas_dia a, cb_rubros x
         where a.fecha = v_fec_insertar
           and x.cod_rubro = a.cod_rubro
           and x.imputable = 'S';
     end if;
 end loop;

exception
  when others then
       raise_application_error(-20000,' ERROR en : prb_gen_det_sal_promedios'||sqlerrm);
end prb_gen_sal_promedios;
/

