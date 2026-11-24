BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GEN_EDAD_MIN_INF', 'EDAD MINIMA PARA OFERTAS EN INFORMA', 'GE_PAR_DINAMICOS', null, 'IT', to_date('18-03-2024 16:19:32', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('18-03-2024 16:19:32', 'dd-mm-yyyy hh24:mi:ss'), 'Parametro creado para identificar la edad minima del cliente INFORMAL para ingresar al analisis de su posible oferta de pre-aprobado', null, null, 'N', null);

commit;
