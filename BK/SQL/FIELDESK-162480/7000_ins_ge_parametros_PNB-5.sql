begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/
        
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SIB_LCR_FGD', 'FONDO GARANTIA LCR', 'GE_PAR_DINAMICOS', null, 
        'Se define el monto tope de fondo de garantia para el calculo del LCR',
        user, sysdate, user, sysdate, null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('SIB_LCR_CAN_SALARIOS', 'CANT. DE SALARIOS MINIMOS LCR', 'GE_PAR_DINAMICOS', null, 
        'Cantidad de salarios minimos considerado por el informe de LCR',
        user, sysdate, user, sysdate, null, null, 'N', null);

commit;