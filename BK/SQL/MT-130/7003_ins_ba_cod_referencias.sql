begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_cod_referencias
  (dominio,
   significado,
   fec_insercion,
   usu_insercion,
   usu_modificacion,
   fec_modificacion,
   val_minimo,
   val_maximo,
   abreviatura,
   activo)
values
  ('TIP_ENTE',
   'Porta Valores TEDs',
   sysdate,
   user,
   user,
   sysdate,
   'CD',
   null,
   'Portavalores Carga-Descarga TEDs',
   'S');
commit;
