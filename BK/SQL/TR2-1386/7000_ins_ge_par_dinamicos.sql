begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
end;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('TAR_ACT_TRI_AUDITORIA', 'Indicador de trigger activo', 'GE_PAR_DINAMICOS', 'Parámetro que sirve de indicador para identificar que se encuentran activos los triggers de auditoria para la tabla ta_cta_tarjetas', 'N');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('TAR_ACT_TRI_AUDITORIA', 'N', null, null, null, null, 'EMARTINEZ', to_date('07-07-2025 16:00:39', 'dd-mm-yyyy hh24:mi:ss'), 'EMARTINEZ', to_date('07-07-2025 16:00:39', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
