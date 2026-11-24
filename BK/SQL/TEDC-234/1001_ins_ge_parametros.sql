--Parámetros
--Configuracion para operacion de Deposito en efectivo TEDs para validacion de umbral
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_OPE_TED_UMB', 'CODIGO OPERACIÓN TED EX EN DEP', 'GE_PAR_DINAMICOS', NULL, 'Se configura el Codigo de Operacion a ser excluido en validacion umbral', null, null, 'IT', to_date('04-05-2023 13:36:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('25-05-2023 16:20:20', 'dd-mm-yyyy hh24:mi:ss'));
