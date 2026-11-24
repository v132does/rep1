begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_CAUSA', 'Sub Motivo Rechazo', 'U', null, 'Anulacion de Tarjetas', 'S');

commit;
