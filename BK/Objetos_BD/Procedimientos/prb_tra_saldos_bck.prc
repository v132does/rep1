create or replace procedure it.prb_tra_saldos_bck is
   v_sql   varchar2(4000);
   v_error varchar2(4000);
begin
   -- copia del proceso 340-CIERRE DE EJERCICIO
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   /*
   || transfiere las tablas de saldos
   */

   v_sql := 'truncate table it.cb_sal_consolidados_bck';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cb_sal_consolidados_bck: '||v_error);
   end if;
   v_sql := 'truncate table it.cb_sal_oficinas_bck';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cb_sal_oficinas_bck: '||v_error);
   end if;
   ---
   begin
      insert into cb_sal_consolidados_bck(
             cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local, cre_mon_local,
             sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro,
             sal_ini_mes_mon_rubro, protegido, sal_equ_loc_ant, deb_equ_local,
             cre_equ_local, sal_ini_mes_equ_local)
      select cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local, cre_mon_local,
             sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro,
             sal_ini_mes_mon_rubro, nvl(protegido,'N'), sal_equ_loc_ant, deb_equ_local,
             cre_equ_local, sal_ini_mes_equ_local
        from ape_cb_sal_consolidados
       where 1=2;
   exception
      when others then
         raise_application_error(-20000,'Al insertar cb_sal_consolidados: '||sqlerrm);
   end;
  begin
      insert into cb_sal_oficinas_bck(
             cod_oficina, cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local, cre_mon_local,
             sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro,
             sal_ini_mes_mon_rubro, sal_ini_mes_mon_fuerte, protegido,
             sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local)
      select cod_oficina, cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local, cre_mon_local,
             sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro,
             sal_ini_mes_mon_rubro, sal_ini_mes_mon_fuerte, nvl(protegido,'N'),
             sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
        from ape_cb_sal_oficinas
       where 1=2;
   exception
      when others then
         raise_application_error(-20000,'Al insertar cie_cb_sal_consolidados: '||sqlerrm);
   end;

end;
/

