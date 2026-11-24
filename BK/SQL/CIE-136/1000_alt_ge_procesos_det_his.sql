ALTER TABLE it.ge_procesos_det_his
add (nro_secuencia NUMBER(3));

COMMENT ON COLUMN it.ge_procesos_det_his.nro_secuencia
  is 'Nro de secuencia indica la cantidad de ejecuciones realizadas';

ALTER TABLE it.ge_procesos_det_his
add (origen varchar2(10));

COMMENT ON COLUMN it.ge_procesos_det_his.nro_secuencia
  is 'Origen de insercion User(Usuario) o GPPROFIN(Pantalla de cierre operativo)';

ALTER TABLE it.ge_procesos_det_his
add (estado VARCHAR2(1));

COMMENT ON COLUMN it.ge_procesos_det_his.nro_secuencia
  is 'Estado al momento de la insercion (E)rror o F(inalizado)';