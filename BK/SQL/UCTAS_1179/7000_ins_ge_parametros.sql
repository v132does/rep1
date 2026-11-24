begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_parametros (parametro, descripcion, tab_relacion, observacion)
values ('USU_MIG_MODALIDAD', 'Usuario migra masiva de modalidad', 'GE_PAR_DINAMICOS', 'Usuario utilizado para bloquear el control de cambio de sub-modalidad de cuenta en el trigger de cuentas durante la migración masiva de cuentas de ahorro básicas a cuentas de ahorro de bajo riesgo');

insert into ge_parametros (parametro, descripcion, tab_relacion, observacion)
VALUES ('LOT_MIG_MODALIDAD', 'Lote de migra masiva de modalidades', 'GE_CTA_DEF_ADICIONALES', 'Indica el lote en el que se incluyó a la cuenta durante la migración masiva de cuentas de ahorro básicas a cuentas de ahorro de bajo riesgo');

commit;
