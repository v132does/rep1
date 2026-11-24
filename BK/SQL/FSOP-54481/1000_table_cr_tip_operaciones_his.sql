alter table IT.CR_PER_TIP_OPERACIONES_HIS add cod_circuito number(15);
comment on column IT.CR_PER_TIP_OPERACIONES_HIS.cod_circuito
  is 'Código de WF generado.';

ALTER TABLE IT.CR_PER_TIP_OPERACIONES_HIS ADD estado VARCHAR2(1);
comment on column IT.CR_PER_TIP_OPERACIONES_HIS.estado
  is 'Estado verificación del monto límite.';
