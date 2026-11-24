begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into BA_COD_REFERENCIAS (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('CONSUMIDORES_API', 'CONSUMIDOR TRANSFERS BFF', to_date('13-05-2025 18:14:03', 'dd-mm-yyyy hh24:mi:ss'), 'JCUADROS', 'JCUADROS', to_date('13-05-2025 18:14:03', 'dd-mm-yyyy hh24:mi:ss'), 'PAYMENT_SUPPLIERS', 'PAYMPV', null, 'S');

commit;
