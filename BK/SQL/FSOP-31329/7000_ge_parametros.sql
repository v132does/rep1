begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into  ge_parametros(PARAMETRO,
                     DESCRIPCION,
                     TAB_RELACION,
                     REFERENCIA,
                     OBSERVACION,
                     PRO_VERIFICACION,
                     PERMISO,
                     MODIFICABLE,
                     VAL_DEFECTO) values('SNP_HAB_AWS',
                                         'HABILITAR ENVIO AWS-XADAPTER',
                                         'GE_PAR_DINAMICOS',
                                         null,
                                         'Control de envío por AWS al XADAPTER',
                                         null,
                                         null,
                                         'N',
                                         null);
commit;
