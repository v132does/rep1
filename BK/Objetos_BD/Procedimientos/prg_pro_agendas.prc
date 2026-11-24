CREATE OR REPLACE PROCEDURE IT.PRG_PRO_AGENDAS is
--cursor de campañas automaticas no vencidas
   cursor campanias is
   select a.cod_campana,a.frecuencia
     from cr_campanas a
    where a.estado = 2
      and a.automatico = 'S'
      and pag_cal.FU_OBT_FEC_ACTUAL(12) between a.fec_inicio and nvl(a.fec_vencimiento,to_date('01/01/2999','dd/mm/yyyy'))
      and a.tip_responsable is not null;

--v_fec_actual date              := to_date('05/01/2008','dd/mm/yyyy') ;
v_fec_actual date              := pag_cal.FU_OBT_FEC_ACTUAL(12) ; --Fecha actual
v_dia_actual varchar2(1)       := to_char(v_fec_actual,'d'); --Dia Actual
v_fec_hab_anterior date        := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,12); -- Fecha Habil Anterior
v_dia_hab_anterior varchar2(1) := to_char(v_fec_hab_anterior,'d'); --Dia Habil Anterior
v_pri_fec_mes date             := pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(12); --Primer fecha habil del mes
v_lunes varchar2(1)            := to_char(to_date('21/01/2008','dd/mm/yyyy'),'d') ; --Obtengo el nro. que corresponde a Lunes
v_viernes varchar2(1)          := to_char(to_date('21/01/2008','dd/mm/yyyy')-3,'d') ; --Obtengo el nro. que corresponde a Viernes
BEGIN
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
     --dbms_output.put_line('1er Fec habil '||v_pri_fec_mes);
     --dbms_output.put_line('Fec Actual '||v_fec_actual||' Dia '||v_dia_actual);
     --dbms_output.put_line('Fec Hab Ante '||v_fec_hab_anterior||' Dia Anterior '||v_dia_hab_anterior);
   for r1 in campanias loop
      if ( (r1.frecuencia = 'D') or --diario
           ((v_dia_hab_anterior = v_viernes or v_dia_actual = v_lunes) and r1.frecuencia = 'S') or --Semanal
           (v_fec_actual = v_pri_fec_mes and r1.frecuencia = 'M') ) then   --Mensual
       --dbms_output.put_line('Campaña '||r1.cod_campana||' Frecuencia '||r1.frecuencia);
         par_cam.PR_GEN_CAM_PERSONAS(r1.cod_campana); --Actualiza las personas del segmento
         par_cam.PR_GEN_AGENDA(r1.cod_campana);       --genera agenda a la personas actualizadas
      end if;
   end loop;
   par_cam.PR_CAM_VENCIDA; --Cambia a vencida las campañas que tengan fecha de vencimiento = v_fec_actual
   par_cam.PR_PRO_ACT_EFECTIVAS; --Efectividad
END;
/

