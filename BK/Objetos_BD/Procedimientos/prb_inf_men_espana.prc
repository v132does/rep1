CREATE OR REPLACE PROCEDURE IT.PRB_INF_MEN_ESPANA
 IS
 ---Desarrollado por Simgia 2011
 ---Llama a los procedimientos que generan los informes a España a fin de mes
 v_fecha date;
BEGIN
    ---trae la fecha de fin de mes anterior
    select pag_cal.FU_OBT_FEC_ANT_HAB (x.pri_dia_mes,31,1) 
     into v_fecha
     from 
       (select f.pri_dia_mes 
         from ge_calendarios f 
         where f.cod_modulo=2)x;
  ---llaman los proceso que generan los informes
  prb_esp_balbbva(v_fecha);
  prb_esp_ra13407(v_fecha); 
  prb_res_bbv_esp(v_fecha);  
  prb_act_pas_esp(v_fecha);
   
END;
/

