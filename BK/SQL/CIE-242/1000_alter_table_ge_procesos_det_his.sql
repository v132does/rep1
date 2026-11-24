ALTER TABLE IT.GE_CIE_METRICAS
  ADD (dur_bkp1 VARCHAR2(8), dur_bkp2 VARCHAR2(8), dur_paralelo VARCHAR2(8));

COMMENT ON COLUMN IT.GE_CIE_METRICAS.dur_bkp1
  IS 'Tiempo total de duracion de backup1';

COMMENT ON COLUMN IT.GE_CIE_METRICAS.dur_bkp2
  IS 'Tiempo total de duracion de backup2';
  
COMMENT ON COLUMN IT.GE_CIE_METRICAS.dur_paralelo
  IS 'Tiempo total de procesos en paralelo.';   

ALTER TABLE IT.ge_procesos_det_his
  ADD (volumen number(15));

COMMENT ON COLUMN IT.ge_procesos_det_his.volumen
  IS 'Volumen de datos procesados. ';

