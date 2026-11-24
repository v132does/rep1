begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

INSERT INTO ge_parametros (
    parametro,
    descripcion,
    tab_relacion,
    referencia,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion,
    observacion,
    pro_verificacion,
    permiso,
    modificable,
    val_defecto
) VALUES ( 'VAL_PAG_ACT_CAT',
           'PAGINADO ACT CAT CLIENTES',
           'GE_PAR_DINAMICOS',
           NULL,
           'IT',
           sysdate,
           'IT',
           sysdate,
           'Tamaño del paginado para la actualizacion de tablas maestras con informacion de categorizacion de clientes',
           NULL,
           NULL,
           'S',
           NULL );

INSERT INTO ge_par_dinamicos (
    parametro,
    val_parametro,
    cod_modulo,
    cod_modalidad,
    cod_oficina,
    cod_moneda,
    usu_insercion,
    fec_insercion,
    usu_modificacion,
    fec_modificacion,
    cod_sub_modalidad
) VALUES ( 'VAL_PAG_ACT_CAT',
           '100000',
           NULL,
           NULL,
           NULL,
           NULL,
           'DDBAINOTTI',
           sysdate,
           'DDBAINOTTI',
           sysdate,
           NULL );
		   
		   
COMMIT;