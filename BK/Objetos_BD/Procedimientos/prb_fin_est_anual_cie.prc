CREATE OR REPLACE PROCEDURE IT.PRB_FIN_EST_ANUAL_CIE
 IS
   v_sql   varchar2(4000);
   v_error varchar2(4000);
   v_fec_act date := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_fec_sig date := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_act,fun_obt_ofi_matriz);
BEGIN
   ---
   --- Limpia basuras por redondeo, si es que quedaron
   ---
   --- cie_cb_sal_consolidados
   ---
   update cie_cb_sal_consolidados s
      set s.sal_equ_loc_ant = s.sal_equ_loc_ant - abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))
    where (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) > 0;
   update cie_cb_sal_consolidados s
      set s.sal_equ_loc_ant = s.sal_equ_loc_ant + abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))
    where (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) < 0;

   update cie_cb_sal_consolidados s
      set s.sal_mon_rub_ant = s.sal_mon_rub_ant - abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0))
    where (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) > 0;
   update cie_cb_sal_consolidados s
      set s.sal_mon_rub_ant = s.sal_mon_rub_ant + abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0))
    where (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) < 0;

   v_sql := 'truncate table it.cie_cb_sal_consolidados_dia';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cie_cb_sal_consolidados_dia: '||v_error);
   end if;
   
   begin
      INSERT INTO cie_cb_sal_consolidados_dia
         (cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
          sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro, protegido,
          sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local)
      SELECT cod_rubro, pag_cal.FU_OBT_FEC_ACTUAL(2), sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
             sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro, protegido,
             sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
        FROM cie_cb_sal_consolidados;
   exception
      when others then
         raise_application_error(-20000,'Al Ins.CIE_CB_SAL_CONSOLIDADOS_DIA: '||sqlerrm);
   end;
   ---
   --- cie_cb_sal_oficinas
   ---
   update cie_cb_sal_oficinas s
      set s.sal_equ_loc_ant = s.sal_equ_loc_ant - abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))
    where (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) > 0;
   update cie_cb_sal_oficinas s
      set s.sal_equ_loc_ant = s.sal_equ_loc_ant + abs(nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0))
    where (nvl(s.sal_equ_loc_ant,0)+nvl(s.deb_equ_local,0)-nvl(s.cre_equ_local,0)) < 0;

   update cie_cb_sal_oficinas s
      set s.sal_mon_rub_ant = s.sal_mon_rub_ant - abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0))
    where (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) > 0;
   update cie_cb_sal_oficinas s
      set s.sal_mon_rub_ant = s.sal_mon_rub_ant + abs(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0))
    where (nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) < 0;

   v_sql := 'truncate table it.cie_cb_sal_oficinas_dia';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar cie_cb_sal_oficinas_dia: '||v_error);
   end if;
   
   begin
      INSERT INTO cie_cb_sal_oficinas_dia
         (cod_oficina, cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local, cre_mon_local,
          sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
          sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local)
      SELECT cod_oficina, cod_rubro, pag_cal.FU_OBT_FEC_ACTUAL(2), sal_mon_loc_ant, deb_mon_local, cre_mon_local,
             sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
             sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
        FROM cie_cb_sal_oficinas;
   exception
      when others then
         raise_application_error(-20000,'Al Ins.CIE_CB_SAL_OFICINAS_DIA: '||sqlerrm);
   end;
   ---
   --- Actualiza fecha de calendario al dia siguiente
   ---
   UPDATE ba_modulos
      set estado = 4
    where cod_modulo = 2;
   if sql%notfound then
      raise_application_error(-20000,'Act. Modulo Contable a cerrado');
   end if;

   v_sql := 'alter trigger TB_GE_CALENDARIOS disable';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al Desabilitar trigger de GE_CALENDARIOS: '||v_error);
   end if;

   pag_cal.PR_OBT_DAT_CALENDAR(2);
   update ge_calendarios
      set fec_proxima = v_fec_sig, --fec_actual + 1,
          ult_dia_mes_habil = pag_cal.G_ULT_DIA_MES,
          ult_dia_hab_trimestre = pag_cal.G_ULT_DIA_MES
    where cod_modulo in (2);

   v_sql := 'alter trigger TB_GE_CALENDARIOS enable';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al Habilitar trigger de GE_CALENDARIOS: '||v_error);
   end if;
END;
/

