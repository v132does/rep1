begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_REC_SNP', 'Tipo de Rechazo para operaciones de reverso de MT Recibidos - SNP', to_date('11-03-2025 10:11:20', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', 'BROLON', to_date('11-03-2025 10:11:20', 'dd-mm-yyyy hh24:mi:ss'), '016', null, 'Horario no disponible', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_REC_SNP', 'Tipo de Rechazo para operaciones de reverso de MT Recibidos - SNP', to_date('11-03-2025 10:11:20', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', 'BROLON', to_date('11-03-2025 10:11:20', 'dd-mm-yyyy hh24:mi:ss'), '017', null, 'Fecha futura no permitida', 'S');

commit;
