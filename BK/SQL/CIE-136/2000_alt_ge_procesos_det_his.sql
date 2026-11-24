ALTER TABLE it.ge_procesos_det_his DROP PRIMARY KEY;

ALTER TABLE it.ge_procesos_det_his
  ADD CONSTRAINT pk_ge_procesos_det_his PRIMARY KEY (fecha, cod_proceso, nro_orden, nro_secuencia)
  USING INDEX 
  TABLESPACE IT_IND
  PCTFREE 10
  INITRANS 2
  MAXTRANS 255
  STORAGE
  (
    INITIAL 64K
    NEXT 1M
    MINEXTENTS 1
    MAXEXTENTS UNLIMITED
  );