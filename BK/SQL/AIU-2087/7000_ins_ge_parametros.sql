begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros(parametro, descripcion,tab_relacion,observacion)
  values ('USU_CDA_APP','Usuario de creacion de CDA - APP','GE_PAR_DINAMICOS','Corresponde al usuario que realiza la creacion de CDA desde la APP.');
commit;
