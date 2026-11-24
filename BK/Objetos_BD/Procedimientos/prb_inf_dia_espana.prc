CREATE OR REPLACE PROCEDURE IT.PRB_INF_DIA_ESPANA
 IS
 ---Desarrollado por Simgia 2011
 ---Llama a los procedimientos que generan los informes a España actual
 v_fecha date;
BEGIN
    ---trae la fecha actual del modulo de contabilidad
    select pag_cal.FU_OBT_FEC_ANTERIOR(2) 
     into v_fecha
      from dual;
  ---llaman los proceso que generan los informes
  prb_esp_balbbva(v_fecha);
  prb_esp_ra13407(v_fecha); 
  prb_res_bbv_esp(v_fecha);  
  prb_act_pas_esp(v_fecha);
   
END;
/

