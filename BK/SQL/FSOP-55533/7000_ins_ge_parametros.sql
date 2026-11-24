Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('HABILITAR_XML', 'HABILITA EXPORTAR A XML', 'BA_COD_REFERENCIAS', 'Habilita la funcionalidad de exportar a formato XML los Informes. (VAL_MINIMO = Reporte / VAL_MAXIMO = Cod_Usuario).', null, 'N', null);

commit;
