begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('SNP_SPI_USUARIOS', 'USER PARA TRANSF. SPI ENV.', 'HBANKF', 'SPI', null, 'S');

commit;
