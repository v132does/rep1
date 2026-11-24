BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE (
    name      => 'IT.GENERACION_ARC_COBROS',
    attribute => 'job_action',
    value     => 'begin
            --Ejecución de las 21 hs, se ejecuta de forma independiente
            if pag_cal.fu_obt_fec_actual(1) = trunc(sysdate) and to_number(to_char(sysdate, ''HH24'')) = 21 then
              begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
              it.prg_gen_arc_cobros(pag_cal.fu_obt_fec_actual(1),''N''); 
            elsif pag_cal.fu_obt_fec_actual(1) != trunc(sysdate) and pae_cnf.fu_obt_est_modulo(1) = 4 then
              begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
              it.prg_ctr_pro_previos(12);
              it.prg_gen_arc_cobros(pag_cal.fu_obt_fec_actual(1),''N'');
            elsif pag_cal.fu_obt_fec_actual(1) = pag_cal.FU_OBT_FEC_HABIL(trunc(sysdate), 1,FUG_OBT_OFI_MATRIZ) and pae_cnf.fu_obt_est_modulo(1) != 4 then
              begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
              it.prg_gen_arc_cobros;
            end if;
          end;'
  );
END;
/
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE (
    name      => 'IT.GENERACION_ARC_COBROS',
    attribute => 'repeat_interval',
    value     => 'Freq=Daily;Interval=1;ByDay=Mon, Tue, Wed, Thu, Fri, Sat;ByHour=21,02,03,04,05,06,07,08,09,10,11,12;ByMinute=00'
  );
END;
/
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE (
    name      => 'IT.GENERACION_ARC_COBROS',
    attribute => 'comments',
    value     => 'Generación de archivos de cobro. Control diario por módulos (02 a 12 hs) y ejecución forzada nocturna (21 hs).'
  );
END;
