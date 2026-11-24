CREATE OR REPLACE PROCEDURE IT.PRB_INF_DIA_ESP_BORRADOR
 IS
 ---Desarrollado por Simgia 2012
 ---Llama a los procedimientos que generan los informes a España actual
 ---Variante del proceso PRB_INF_DIA_ESPANA (no tiene en cuenta los controles que evitan que se genere el archivo)
 v_fecha date;
BEGIN
    ---trae la fecha actual del modulo de contabilidad
    select pag_cal.FU_OBT_FEC_ANTERIOR(2)
     into v_fecha
      from dual;
  ---llaman los proceso que generan los informes
  prb_esp_balbbva(v_fecha,'S');
  prb_esp_ra13407(v_fecha,'S');
  prb_res_bbv_esp(v_fecha,'S');
  prb_act_pas_esp(v_fecha);

END;
/

