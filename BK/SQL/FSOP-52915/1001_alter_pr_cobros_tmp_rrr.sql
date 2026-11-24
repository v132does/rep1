-- Add/modify columns 
alter table IT.PR_COBROS_TMP_RRR add cod_clave number(8);
alter table IT.PR_COBROS_TMP_RRR add nro_secuencia number(3);
-- Add comments to the columns 
comment on column IT.PR_COBROS_TMP_RRR.cod_clave
  is 'Código de clave para relacionar con la cabecera.';
comment on column IT.PR_COBROS_TMP_RRR.nro_secuencia
  is 'Número de registro.';
