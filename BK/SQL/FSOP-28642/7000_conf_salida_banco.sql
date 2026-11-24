begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

/*Volver a los valores originales la definición de transacciones de caja*/
---Configuración 352
--restituir las etiquetas--
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 1(0HS)'
 where cod_transaccion = 352
   and nro_orden = 6;

--retención 24 hs restituir valores
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 2(24HS)',
       ayuda    = 'Ingrese el importe en cheq. C/O/Bcos. con Retencion: 24 Hs.'
 where cod_transaccion = 352
   and nro_orden = 8;

--retención 48 hs restituir valores
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 3(48HS)'
 where cod_transaccion = 352
   and nro_orden = 10;

--Configuración 361
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 1(0HS)',
   val_minimo = null,
   val_maximo = null,
   val_defecto = null
 where cod_transaccion = 361
   and nro_orden = 19;
  
--retención 24 hs restituir valores
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 2(24HS)',
       ayuda    = 'Ingrese el importe en cheq. C/O/Bcos. con Retencion: 24 Hs.'
 where cod_transaccion = 361
   and nro_orden = 20;
   
--retención 48 hs restituir valores
update ge_tra_campos
   set etiqueta = 'Imp. Cheques - Ret. 3(48HS)',
   val_minimo = null,
   val_maximo = null,
   val_defecto = null
 where cod_transaccion = 361
   and nro_orden = 23;

--Configuración 250
update ge_tra_campos
   set val_defecto = null
 where cod_transaccion = 250
   and cod_campo = 'TIP_RETEN';

--Configuración 133
update ge_tra_campos
   set val_defecto = null
 where cod_transaccion = 133
   and cod_campo = 'OFI_CAMARA';
  
/*Configuración de retenciones*/
update ge_retenciones
   set descripcion = 'DEPOSITOS CHEQUES 0HS'
 where cod_retencion = 1;

update ge_retenciones
   set descripcion = 'DEPOSITOS CHEQUES 24HS'
 where cod_retencion = 2;

update ge_retenciones
   set descripcion = 'DEPOSITOS CHEQUES 48HS'
 where cod_retencion = 3;

/*update ge_ret_monedas
   set can_dias = 1
 where cod_retencion = 1
   and cod_moneda = 'GS';

update ge_ret_monedas
   set can_dias = 2
 where cod_retencion = 2
   and cod_moneda = 'GS';

update ge_ret_monedas
   set can_dias = 3
 where cod_retencion = 3
   and cod_moneda = 'GS';*/

--falta definir tiempo de retención de autoservicios

/**Parámetros de cámara**/
update ge_par_dinamicos
   set val_parametro = 1000000000
 where parametro = 'MTO_CHE_RET_CERO'
   and cod_moneda = 'GS';
 
update ba_cod_referencias
   set val_maximo = '12:59'
 where dominio = 'HOR_COR_CAMARA'
   and val_minimo = '1';
   
update ba_cod_referencias
   set val_maximo = '17:30'
 where dominio = 'HOR_COR_CAMARA'
   and val_minimo = 'T';   

/**Parámetros Conexión Prodep desde caja**/
update ge_par_dinamicos
   set val_parametro = 1
 where parametro = 'CAJ_PRO_CONECTOR';

--dominios CAJ_PAR_PRODEP  parametrizar con valores de conexión

--valor del parámetro para enviar el número de cta a Prodep
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('ENV_NRO_CTA_PRODEP', 'S', null, null, null, null, 'PRODEP', to_date('09-08-2023 15:16:25', 'dd-mm-yyyy hh24:mi:ss'), 'PRODEP', to_date('09-08-2023 15:16:25', 'dd-mm-yyyy hh24:mi:ss'), null);

--grupo de transacciones para conexión prodep
insert into ge_gru_transacciones (COD_GRU_TRANSACCION, DESCRIPCION, CONDICION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 'TRANSACCIONES DE CAJA PRODEP', 'I', 'IT', to_date('03-08-2023 11:18:08', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:18:08', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 133, 9, 91, 'IT', to_date('03-08-2023 11:23:18', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:23:18', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 215, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 245, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 246, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 247, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 250, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 352, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 361, 9, 91, 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:35', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (900, 398, 9, 91, 'IT', to_date('03-08-2023 11:29:36', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-08-2023 11:29:36', 'dd-mm-yyyy hh24:mi:ss'));
insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (900, 217, 9, 91);
/*Parámetro desde el PRG_VAL_CAJ_PRO_CONECTOR
--dominio CAJ_PRO_CONECTOR

/**Grupos de transacciones para no detallar en Prodep**/
--para el trigger TB_CJ_MOVIMIENTOS hay que borrar el detalle del grupo 804
delete ge_gru_transacciones_det where cod_gru_transaccion = 804;
------------------no detallar.

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 245, 9, 91);


insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 250, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 352, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 361, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 362, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 246, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 241, 9, 91);

insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 242, 9, 91);
insert into ge_gru_transacciones_det (COD_GRU_TRANSACCION, COD_TRANSACCION, COD_MODULO, COD_MODALIDAD)
values (804, 217, 9, 91);
 
commit;




