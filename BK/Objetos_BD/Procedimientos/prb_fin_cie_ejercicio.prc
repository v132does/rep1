create or replace procedure it.prb_fin_cie_ejercicio is
   v_sql   varchar2(4000);
   v_error varchar2(4000);
   v_fec_actual date := pag_cal.fu_obt_fec_actual(2);
   --- Cursor de detalles
   CURSOR c_asientos is
   SELECT distinct fecha, cod_oficina, nro_asiento
     FROM cb_asientos_det
    WHERE fecha = v_fec_actual
      AND (referencia = 'CIE.CT.PAT' OR referencia = 'CIE.CT.RES' OR
           referencia = 'CIE.CT.ORD' OR referencia = 'CIE.CT.CON');   
begin
   -- copia del proceso 340-CIERRE DE EJERCICIO
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   /*
   || Ejecutar los procesos e insertar en otras tablas
   */

   v_sql := 'truncate table it.cie_cb_sal_consolidados';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cie_cb_sal_consolidados: '||v_error);
   end if;
   v_sql := 'truncate table it.cie_cb_sal_oficinas';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cie_cb_sal_oficinas: '||v_error);
   end if;
   v_sql := 'truncate table it.cie_cb_rub_oficinas';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cie_cb_rub_oficinas: '||v_error);
   end if;
   ---
   begin
      insert into cie_cb_sal_consolidados(
             cod_rubro, ano, mes,
             sal_mon_loc_ant,
             deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
             sal_mon_rub_ant,
             deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro, protegido,
             sal_equ_loc_ant,
             deb_equ_local, cre_equ_local, sal_ini_mes_equ_local)
      select cod_rubro, ano, mes,
             (NVL(SAL_MON_LOC_ANT, 0) + NVL(DEB_MON_LOCAL, 0) - NVL(CRE_MON_LOCAL, 0)),
             0, 0, sal_ini_mes_mon_local,
             (nvl(sal_mon_rub_ant, 0) + nvl(deb_mon_rubro, 0) - nvl(cre_mon_rubro, 0)),
             0, 0, sal_ini_mes_mon_rubro, protegido,
             (NVL(sal_equ_loc_ant, 0) + NVL(deb_equ_local, 0) - NVL(cre_equ_local, 0)),
             0, 0, sal_ini_mes_equ_local
        from cb_sal_consolidados;
   exception
      when others then
         raise_application_error(-20000,'Al insertar cie_cb_sal_consolidados: '||sqlerrm);
   end;
   begin
      insert into cie_cb_rub_oficinas(
             cod_oficina, cod_rubro, ult_nro_extracto)
      select cod_oficina, cod_rubro, ult_nro_extracto
        from cb_rub_oficinas;
   exception
      when others then
         raise_application_error(-20000,'Al insertar cie_cb_sal_consolidados: '||sqlerrm);
   end;
   begin
      insert into cie_cb_sal_oficinas(
             cod_oficina, cod_rubro, ano, mes,
             sal_mon_loc_ant,
             deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
             sal_mon_rub_ant,
             deb_mon_rubro, cre_mon_rubro,
             sal_ini_mes_mon_rubro, sal_ini_mes_mon_fuerte, protegido,
             sal_equ_loc_ant,
             deb_equ_local, cre_equ_local, sal_ini_mes_equ_local)
      select cod_oficina, cod_rubro, ano, mes,
             (NVL(SAL_MON_LOC_ANT, 0) + NVL(DEB_MON_LOCAL, 0) - NVL(CRE_MON_LOCAL, 0)),
             0, 0, sal_ini_mes_mon_local,
             (nvl(sal_mon_rub_ant, 0) + nvl(deb_mon_rubro, 0) - nvl(cre_mon_rubro, 0)),
             0, 0,
             sal_ini_mes_mon_rubro, sal_ini_mes_mon_fuerte, protegido,
             (NVL(sal_equ_loc_ant, 0) + NVL(deb_equ_local, 0) - NVL(cre_equ_local, 0)),
             0, 0, sal_ini_mes_equ_local
        from cb_sal_oficinas;
   exception
      when others then
         raise_application_error(-20000,'Al insertar cie_cb_sal_consolidados: '||sqlerrm);
   end;
   /*
   || Borrar asientos por si sea un reproceso
   */
   for i in c_asientos loop
      DELETE
        FROM cb_asientos_det
       WHERE fecha = i.fecha
         AND cod_oficina = i.cod_oficina
         AND nro_asiento = i.nro_asiento;
      
      DELETE
        FROM cb_asientos cab
       WHERE fecha = i.fecha
         AND cod_oficina = i.cod_oficina
         AND nro_asiento = i.nro_asiento;
   end loop;
exception
   when others then
      raise_application_error(-20000,'En PRB_FIN_CIE_EJERCICIO: '||sqlerrm);
end;
/

