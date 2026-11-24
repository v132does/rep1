BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update ge_procesos_det a 
set    a.nro_orden =376 , a.descripcion ='CORRECCION DE ASIENTOS' ,a.cod_programa='PRB_COR_ASI_AUT' , 
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=375;

update ge_procesos_det a 
set    a.nro_orden =375 , a.descripcion ='VALIDACION DE ASIENTOS' ,a.cod_programa='PRB_VAL_ASI_AUT' , 
       a.obligatorio='N' , a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=374;

update ge_procesos_det a 
set    a.nro_orden =374 , a.descripcion ='GENERACION DE ASIENTOS TEMPORAL' ,a.cod_programa='PRG_GEN_ASI_CIE_TMP',
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=373;

update ge_procesos_det a 
set    a.nro_orden =373 , a.descripcion ='TRANSF. DE MOVIMIENTOS A HISTORICOS' ,a.cod_programa='PRG_TRA_HISTORICO' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=372;

update ge_procesos_det a 
set    a.nro_orden =372 , a.descripcion ='CANCELA CUENTAS DE NOMINA' ,a.cod_programa='PAG_NOM.PR_CAN_NOMINA' , 
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=371;

update ge_procesos_det a 
set    a.nro_orden =371, a.descripcion ='GENERACION DE ASIENTOS' ,a.cod_programa='PRA_GEN_ASIENTOS' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='N'
where a.cod_proceso=11
and   a.nro_orden=370;

update ge_procesos_det a 
set    a.nro_orden = 370, a.descripcion ='GENERACION DE ASIENTOS AUTOMATICOS' ,a.cod_programa='PRA_GEN_ASI_AUTOMATICOS' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=369;

update ge_procesos_det a 
set    a.nro_orden = 369, a.descripcion ='VERF. MOVIMIENTOS A HISTORICOS' ,a.cod_programa='PRG_TRA_HIS_DUPLICADO' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=368;

update ge_procesos_det a 
set    a.nro_orden =368 , a.descripcion ='ACT. SALDDOS Y EST. BATCH' ,a.cod_programa='PRA_ACT_CUENTAS' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=367; 

update ge_procesos_det a 
set    a.nro_orden =367 , a.descripcion ='CONSOLIDADO DE TRANSACCION' ,a.cod_programa='PRA_CON_TRANSACCION' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=366;

update ge_procesos_det a 
set    a.nro_orden =366 , a.descripcion ='CERRAR OTROS MODULOS' ,a.cod_programa='PRG_CIE_MODULOS' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=365;

update ge_procesos_det a 
set    a.nro_orden =365 , a.descripcion ='ACT. CAPTACIONES A CERRADO' ,a.cod_programa='PRA_FIN_EST_MODULO' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=364;

update ge_procesos_det a 
set    a.nro_orden =364 , a.descripcion ='REV. AUT. OPE PENDIENTES' ,a.cod_programa='PRG_REV_AUTOMATICA' , 
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=363;

update ge_procesos_det a 
set    a.nro_orden =363 , a.descripcion ='REVERSION CTA. COMBINADA' ,a.cod_programa='PRC_REV_CTA_COMBINADA' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=362;

update ge_procesos_det a 
set    a.nro_orden =362 , a.descripcion ='CONTABILIZACION DE CTAS. COMBINADAS' ,a.cod_programa='PRC_PRO_TRA_CTA_COM' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=361;

update ge_procesos_det a 
set    a.nro_orden =361 , a.descripcion ='CALCULA DEV. COMISIONES DIFERIDAS' ,a.cod_programa='PRG_CAL_DEV_COMISIONES' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=360;

update ge_procesos_det a 
set    a.nro_orden =360 , a.descripcion ='GENERA COMISIONES DIFERIDAS' ,a.cod_programa='PRG_GEN_DEV_COMISIONES' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=359;

update ge_procesos_det a 
set    a.nro_orden =359 , a.descripcion ='CONT. CONTINGENCIA Y SALDO ACREEDOR' ,a.cod_programa='PRT_GEN_ASI_ACRE_FIN' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=358;

update ge_procesos_det a 
set    a.nro_orden =358 , a.descripcion ='GENERACION AUTOMATICA DE RECIBOS' ,a.cod_programa='PRB_GEN_RECIBOS' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=357;

update ge_procesos_det a 
set    a.nro_orden =357 , a.descripcion ='GENERACION LIBRO IVA COMPRAS' ,a.cod_programa='PRK_GEN_LIB_COMPRAS' , 
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=356;

update ge_procesos_det a 
set    a.nro_orden =356 , a.descripcion ='GENERACION LIBRO IVA VENTAS' ,a.cod_programa='PAB_IVA.PR_PRO_CIERRE' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=355;

update ge_procesos_det a 
set    a.nro_orden =355 , a.descripcion ='DESVINCULAR CLIENTES DE SU PAQUETE' ,a.cod_programa='PRT_CAN_AUT_PAQUETES' ,
       a.obligatorio='S', a.frecuencia='M' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=354;

update ge_procesos_det a 
set    a.nro_orden =354 , a.descripcion ='CIERRE DE CAMBIOS' ,a.cod_programa='PRL_CIE_CAMBIOS' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=353;

update ge_procesos_det a 
set    a.nro_orden =353 , a.descripcion ='VALUACIONES DE CTA. CTES' ,a.cod_programa='PRC_GEN_VALUACIONES' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=352;

update ge_procesos_det a 
set    a.nro_orden =352 , a.descripcion ='VALUACIONES DE OPE. VENCIDAS' ,a.cod_programa='PRV_GEN_VALUACIONES' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=351;


update ge_procesos_det a 
set    a.nro_orden =351 , a.descripcion ='VALUACIONES DE PRESTAMOS' ,a.cod_programa='PRP_GEN_VALUACIONES' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=350;

update ge_procesos_det a 
set    a.nro_orden = 350, a.descripcion ='TRASLADO DE SALDOS ACREEDOR TARJE' ,a.cod_programa='PRT_TRA_SAL_ACREEDOR' ,
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=349;

update ge_procesos_det a 
set    a.nro_orden =349 , a.descripcion ='REV. AUTOMATICA SIPAP' ,a.cod_programa='PAS_SNP.PR_GEN_REV_SNP' ,
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=348;

update ge_procesos_det a 
set    a.nro_orden =348 , a.descripcion ='INACTIVACION CTA. SIN MOV.' ,a.cod_programa='PRA_INA_AHO_VISTA' ,
       a.obligatorio='N', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=347;

update ge_procesos_det a 
set    a.nro_orden =347 , a.descripcion ='INSERTA CTAS. CON ATRASO' ,a.cod_programa='PRG_INS_CLI_CTA_ATRASOS' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=346;

update ge_procesos_det a 
set    a.nro_orden =346 , a.descripcion ='VENCIMIENTO LIMITES GLOBALES' ,a.cod_programa='PRP_ACT_VEN_LIM_GLOBAL' ,
       a.obligatorio='S', a.frecuencia='D' , a.activo='S'
where a.cod_proceso=11
and   a.nro_orden=345;

BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('PRP_GEN_PRE_FUSION', 'DIFERIMIENTO DE PREVISIONES', 8, 6, 'EN LA BASE DE DATOS', 'EN LA BASE DE DATOS', 'Calcula el diferimiento de cuentas diariamente', null, 'null', 'IT', to_date('26-01-2012 18:53:24', 'dd-mm-yyyy hh24:mi:ss'), 'PARRUA', to_date('11-06-2023 13:46:32', 'dd-mm-yyyy hh24:mi:ss'), 'N', null, null, '.', null);


insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, ACTIVO)
values (11, 345, 'DIFERIMIENTO DE PREVISIONES', 'PRP_GEN_PRE_FUSION', 'S', 'D','S');

commit; 

