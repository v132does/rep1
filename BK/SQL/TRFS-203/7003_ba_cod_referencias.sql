begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('SNP_SPI_USU_APN', 'USER PARA TRANSFERIAS APN.', 'APNWEPA', 'SPI', null, 'S');

commit;