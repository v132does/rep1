begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('RECHAZO_AUTOMATICO', 'Proc. Aut de Rechazo de cheques recibido de camara', to_date('27-01-2025 11:45:34', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-01-2025 15:01:02', 'dd-mm-yyyy hh24:mi:ss'), 'O', '128', 'ORDEN DE NO PAGO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('RECHAZO_AUTOMATICO', 'Proc. Aut de Rechazo de cheques recibido de camara', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-01-2025 14:59:32', 'dd-mm-yyyy hh24:mi:ss'), 'C', '107', 'CUENTA CANCELADA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('RECHAZO_AUTOMATICO', 'Proc. Aut de Rechazo de cheques recibido de camara', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-01-2025 14:59:32', 'dd-mm-yyyy hh24:mi:ss'), 'T', '239', 'INHAB. P/ OPERAR EN CTA CTE', 'S');

insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO)
values ('COD_WF_INH_PER', 'Cuenta Cancelada', 'C', '401');

insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO)
values ('COD_WF_INH_PER', 'Fallas Formales', 'F', '402');

insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO)
values ('COD_WF_INH_PER', 'Insuficiencia de Fondos', 'I', '400');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('COD_TIP_DEVOLUCION', 'Inh. por Devol. de Cheq. por Ins. Fondos', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-01-2025 14:59:32', 'dd-mm-yyyy hh24:mi:ss'), 'I', '248', 'INSUFICIENCIA DE FONDOS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('COD_TIP_DEVOLUCION', 'Inh. por Devol. de Cheq. por Cta.Canc.', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-01-2025 14:59:32', 'dd-mm-yyyy hh24:mi:ss'), 'C', '249', 'CTA. CANCELADA', 'S');

commit;
