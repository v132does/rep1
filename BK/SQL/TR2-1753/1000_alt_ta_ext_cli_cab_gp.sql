alter table it.TA_EXT_CLI_CAB_GP
add cod_tip_producto NUMBER(5);
alter table it.TA_EXT_CLI_CAB_GP
add procesado VARCHAR2(1) default 'N';
alter table it.TA_EXT_CLI_CAB_GP
add fec_proceso DATE default TRUNC(SYSDATE);
comment on column IT.TA_EXT_CLI_CAB_GP.cod_tip_producto
  is 'Codigo de Producto GP - id_producto';
comment on column IT.TA_EXT_CLI_CAB_GP.procesado
  is 'Marca de proceso del registro. Valores posibles S/N';
comment on column IT.TA_EXT_CLI_CAB_GP.fec_proceso
  is 'Fecha de proceso del registro.';
