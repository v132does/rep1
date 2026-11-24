begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'BWE_PAG_PROVEEDOR', null, 'INDICA HOMEBANKING HAB (PROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COB_CHQ_CARGO', null, 'INDICA SI SE COBRA LA EMISION-CHEQU', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COB_COM_CARGO', 'N', 'INDICA SI SE COBRA LA EMISION', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_RUB_PPROV', null, 'RUBRO CONTABLE PARA PAGO PROV.', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_CHQ_GERENCIA', null, 'TRX. DE CHEQUE GERENCI', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_COB_SERVICIO', null, 'TRANSACCION COBRO DE SERVICIOS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_COM_INDIVIDUAL', null, 'TRANSACCION COM. INDIVIDUAL (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_COM_MENSUAL', null, 'TRANSACCION COM. MENSUAL (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_COM_SERVICIO', null, 'TRANSACCION COM. SERVICIO (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_PAD_PPROV', '346', 'TRANSACCION PADRE PAGO PROV(PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'COD_TRA_PAD_PRV_CREDITO', null, 'TRANSACCION PADRE CRED. CTA(PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'CTA_DEB_CARGO', null, 'CUENTA DEBITO COBRO SERVICIO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'CTA_DEB_PPROV', null, 'CUENTA DEBITO PAGO PROV. (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'CTA_DEB_PPROV_1', null, 'CUENTA DEBITO 1 PAGO PROV. (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'CTA_DEB_PPROV_2', null, 'CUENTA DEBITO 2 PAGO PROV. (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'CTA_DEB_PPROV_3', null, 'CUENTA DEBITO 3 PAGO PROV. (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'DIR_ARC_PRV', null, 'DIRECTORIO FISICO PARA ARCHIVOS', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'DIR_MAIL_NOT_PP', null, 'DIR. MAIL NOTIFIC PAGOS PROVEEDORES', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'DIR_MAIL_PP', null, 'DIR. MAIL PAGOS PROVEEDORES', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'EXT_ARC_SAL_PRV', null, 'EXTENCIÓN DE ARCHIVO DE SER ENVIADO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'FEC_INICIO_PRV', null, 'FECHA INICIO CONTRATO (PROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'FEC_VENCIMIENTO_PRV', null, 'FECHA VENCIM.CONTRATO(PROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'FEC_VTO_CONTRATO', null, 'FECHA VENCIMIENTO CONTRATO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'HAB_HOMEBANKING_PRV', 'S', 'INDICA HOMEBANKING HAB (PROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'HAB_PRV_HUB_GLOBAL', null, 'HABILITAR OPERACIONES HUB GLOBAL', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'MOD_ENV_NRO_PAGO', null, 'MODO ENVIO NRO PAGO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'MOD_REG_PAG_PRV', 'P', 'MODALIDAD REGISTRACION DE PAGO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'ORD_PAG_PROVEEDOR', null, 'PERMITE PAGO A PROVEEDOR', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'PAG_FAC_ATRASADA', 'S', 'SI PAGA FACTURA ATRASADA (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'PRV_NRO_TIM_RETENCION', null, 'NÚMERO DE TIMBRADO RETENCIÓN', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'PRV_VTO_TIM_RETENCION', null, 'FECHA VTO. DE TIMBRADO RETENCIÓN', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'REF_TXT_PPROV', 'PAG_PROVEEDORES_HB1', 'REFERENCIA PARA TXT (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'REF_TXT_PPROV_USD', 'PAG_PROVEEDORES_HB1', 'REFERENCIA PARA TXT USD (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SER_ACTIVO_PRV', 'S', 'INDICA SERVICIO ACTIVO (PROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SNP_HAB_PROVEEDORES', 'S', 'HABILITAR OPER. PAGO PROV.', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SNP_TIP_AV_PROVEEDORES', '016,003', 'TIPO OPER. ALTO VALOR PROV. SNP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SNP_TIP_BV_PROVEEDORES', '016,003', 'TIPO OPER. BAJO VALOR PROV. SNP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SNP_TIP_CAR_PROVEEDORES', 'OUR', 'TIPO CARGO PROVEEDORES SNP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'SNP_TIP_PRIORIDAD', null, 'TIPO PRIORIDAD PROV. SNP', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'TIP_COB_PPROV', 'F', 'TIPO COBRO PAGO PROVEEDOR (PPROV)', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_PROVEEDORES', 'Parametros de ente para pago de Proveedores', 'TIP_ENV_SAL_PRV', null, 'TIPO DE ENVIO DE ARCHIVO DE SALIDA', 'S');


insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'ASI_TIP_TDD_MANUAL', 'N', 'Asignación de TDD INFONET/VISA de forma manual en la alta masiva de cliente nómina', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'BWE_PAG_SUELDO', 'S', 'Indica si el servicio esta activo o no para HOMEBANKING (S/N)', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'BW_PAG_SER_CRI', null, 'S indica que los empleados del ente no podran realizar pagos a servicios considerados criticos.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_CON_EXT_ATM', null, 'Cantidad máxima de transacciones sin costo por consultas en atms extranjeros. Utilizado en el programa de Cobro de Cargos por uso de ATM.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_CON_OTR_ATM', null, 'Cantidad máxima de transacciones sin costo por consultas en otros atms. Utilizado en el programa de Cobro de Cargo por Utilización de ATM.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_CON_PRO_ATM', null, 'Cantidad máxima de transacciones sin costo por consultas en atm''s propios de la entidad. Utilizado en el programa de Cobro de Cargos por Uso de ATM.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_EXT_OTR_ATM', null, 'Cantidad máxima de transacciones sin costo por extracciones en otros atms. Utilizado en el programa de Cobro de Comisiones por Uso de ATM.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_EXT_PRO_ATM', null, 'Utilizado en el programa de Cobro de Comisiones por Uso de ATM.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_PAG_SAL_ATM', '999', 'Cantidad maxima de transacciones sin costo por extracciones y consultas por cuentas pago de salario en ATM', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MAX_TRANSACCION', null, 'Cantidad máxima de transacciones sin costo', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'CAN_MES_PRO_INGRESO', null, 'Define la cantidad de meses para cálculo de promedio de ingreso en caso de que la persona no tenga información laboral.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TAS_LIN_SOBREGIROS', null, 'Permite definir el código de Tasa para crear las Líneas de Sobregiro de las cuentas Asociadas al Ente.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_COMISION', '8071', null, 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_COM_EXCESO', '137', 'Transacción de comisión por exceso', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_IVA', null, 'Se utiliza en el proceso de pago de sueldos.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PAD_AGUINALDO', '1304', 'Transacción Padre de Débito por Aguinaldo', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PAD_COMISION', '1305', 'Transacción Padre de Débito por Comisión', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PAD_CREDITO', '1306', 'Transacción Padre de Débito por Crédito', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PAD_GRATIFICACION', null, 'Transacción Padre de Débito por Gratificacion', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PAD_SUELDO', '304', 'Transacción Padre de Débito por Pago de sueldos', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'COD_TRA_PRECIO_FIJO', 'N', 'Valores posible (S o N). Indica si el precio de la comisión a cobrar al ente es fijo o no.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'DEB_EXCESO_EMPRESA', null, 'Indica si se debita o no a la empresa el exceso de transacciones (S/N)', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'DIR_ARC_RESPUESTA', 'C:\IT', 'Ubicación utilizada para depositar los archivos de respuesta y resultado del proceso de pago de sueldos. El archivo contiene los registros que tuvieron errores.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'DIR_MAIL_SUE', null, 'Dirección de Mail de procesos de pagos de nómina', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'EMI_CHEQUERAS', null, 'Permite emisión de chequeras para Clientes Nóminas. Valores posibles (S/N).', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'FEC_INICIO', null, 'Fecha de inicio del contrato de servicio con la empresa', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'FEC_VENCIMIENTO', null, 'Fecha de vencimiento del contrato con la empresa', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'HAB_HOMEBANKING', 'S', 'Indica si el servicio esta activo o no para HOMEBANKING (S/N)', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_ASI_TIP_TDD_MANUAL', null, 'Información: Asignación de tipo de tarjeta de débito de forma manual por el usuario', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_COD_TAS_LIN_SOBREGIROS', null, 'Permite definir el codigo de Tasa para crear las Lineas de Sobregiro de las cuentas Asociadas al Ente.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_COM_DEU_TAR_CRE', null, 'Campo de Información de Tasas Especiales para Compra de Deuda de Tarjeta de Crédito', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_COS_ANU_TAR_CRE', null, 'Campo de Información de Costo Anual de Tarjeta de Crédito para Salarios', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_COS_CHE_HOJ_CHEQUE', null, 'Costo de chequera u hoja de cheque', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_POR_LIM_SUELDO', '0', 'Porcentaje de Anticipo de sueldo.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_TAS_ESPECIALES', null, 'Tasas especiales', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_TAS_PRE_AUTO', null, 'Campo de Información de Tasas Especiales de Prestamo Auto', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'INF_TAS_PRE_PRESONAL', null, 'Campo de Información de Tasas Especiales de Prestamo Personal', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'MES_PRO_SUELDO', null, 'Cantidad de meses utilizado para calcular el Promedio del Sueldo.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'MTO_MAX_COMISION', null, 'Se define en la moneda de la cuenta de debito, el monto maximo de la comision a ser cobrada a la empresa pagadora.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'NRO_CTA_CONTABLE', null, 'Indica la cuenta contable a la cual se debe debitar en lugar de debitar de una cuenta de ahorros', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'NRO_CTA_DEBITO', null, null, 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'PAG_ENT_EST', null, 'Se utiliza para indicar si un ente esta activo o inactivo', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'PAG_NOM_ES_WEB', 'S', 'Se utiliza para habilitar o no el campo de importacion en el GMANTICI y distinguir si es web o no', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'PAG_TRA_AGUINALDO', 'S', 'Valores posible (S/N). Indica si se realizara el traspaso del credito por aguinaldo de la cta. cte. a la caja de ahorro.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'POR_LIM_AGUINALDO', null, 'Porce. Anticipo Aguinaldo.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'POR_LIM_SUELDO', '0', 'Porcentaje de Anticipo de sueldo.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'POR_PRO_SUELDO', null, 'Valor del Porcentaje utilizado para calcular el Promedio del Sueldo. Formato 999.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'PRO_CON_ERRORES', 'C', 'Permite procesar pagos habiendo cuentas con errores; valor ''N''/ Continuar proceso de Pago, ''C''/Cancelar proceso de Pago.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'REFERENCIA_TXT_SUELDO', 'PAG_SUELDOS_HB1', 'Define el nombre del archivo txt a ser leido', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'REF_CTA_DEBITO', null, 'Este campo contiene los nros. de cuenta de debito de la empresa pagadora separado por punto y coma, sirve para realizar la verificacion de la cuenta que se recibe en el archivo txt, la cuenta debe estar en esta referencia.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'SAL_MIN_EMI_CHEQUERAS', null, 'Salario mínimo para la emisión de chequeras a clientes nóminas.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'SER_ACTIVO', 'S', 'Indica si el servicio esta activo o no (S/N)', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'SOB_PER_CALCULO', null, 'Permite definir el periodo de cálculo (en meses) para la generación de las líneas de sobregiro.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'SOB_PER_RECALCULO', null, 'Permite definir el periodo de re-cálculo (en meses) del monto de la línea de sobregiro, en base al promedio de los de acreditación de salarios durante este periodo.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'TIP_PRO_SUELDO', 'O', 'Indicará si el pago de nóminas es B/Batch, O/On-Line o R/A Requerimiento.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'TRA_PAD_DEBITO', null, null, 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'UTI_DIR_ENTE_EXTRACTO', null, 'Utilizada en Generación de Extracto para indicar en caso de no utilizar la dirección del ente en el extracto de cuentas del empleado.', 'S');

insert into Ba_Cod_Referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('PAR_ENT_PAG_SALARIOS', 'Parametros de ente para pago de salarios', 'VAL_NRO_DOCUMENTO', 'S', 'Valida si será tomando o no el número de documento para el proceso de validación del mismo.', 'S');


commit;
