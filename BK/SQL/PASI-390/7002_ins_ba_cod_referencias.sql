Begin pre_ini_aplicacion; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('MES_PRO_MODALIDAD', 'PMOS. REC. AFD CHE ROGA', to_date('27-03-2025 09:49:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('27-03-2025 09:49:57', 'dd-mm-yyyy hh24:mi:ss'), '150', '50000000', 'MMCTAPRE', 'S');

commit;
