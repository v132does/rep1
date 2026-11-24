begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

Insert into GE_PARAMETROS (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE,VAL_DEFECTO)
values ('CAN_ERR_MAX_SEG_VIDA','LIMITE ERRORES PRP_GEN_CAR_SEG_VIDA','GE_PAR_DINAMICOS','Límite de cantidad de errores máximos permitidos en PRP_GEN_CAR_SEG_VIDA','S',null);

Insert into GE_PAR_DINAMICOS (PARAMETRO,VAL_PARAMETRO)
values ('CAN_ERR_MAX_SEG_VIDA','5');

COMMIT;
