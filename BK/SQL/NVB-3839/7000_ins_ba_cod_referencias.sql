begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
--Borramos los tipos que no se utilizan
delete from cc_tip_chequeras a where a.cod_tip_chequera <> '5';

--Insertamos la nueva Parametria de tipo
insert into cc_tip_chequeras (COD_TIP_CHEQUERA, DESCRIPCION, CAN_CHEQUES, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_TASA, COD_TRANSACCION, TIPO, CAN_MINIMA, CAN_MAXIMA, COD_MONEDA, COD_TAS_CASA)
values ('1', 'VISTA-CORTO-25', '25',user,sysdate, user, sysdate, 71, 540, 'V', 1, 99999, null, null);

insert into cc_tip_chequeras (COD_TIP_CHEQUERA, DESCRIPCION, CAN_CHEQUES, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_TASA, COD_TRANSACCION, TIPO, CAN_MINIMA, CAN_MAXIMA, COD_MONEDA, COD_TAS_CASA)
values ('2', 'VISTA-FC-25', '25', user,sysdate, user, sysdate, 71, 540, 'V', 1, 99999, null, null);

insert into cc_tip_chequeras (COD_TIP_CHEQUERA, DESCRIPCION, CAN_CHEQUES, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_TASA, COD_TRANSACCION, TIPO, CAN_MINIMA, CAN_MAXIMA, COD_MONEDA, COD_TAS_CASA)
values ('3', 'DIFERIDO-CORTO-25', '25', user,sysdate, user, sysdate, 71, 540, 'D', 1, 99999, 'USD', 73);

insert into cc_tip_chequeras (COD_TIP_CHEQUERA, DESCRIPCION, CAN_CHEQUES, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_TASA, COD_TRANSACCION, TIPO, CAN_MINIMA, CAN_MAXIMA, COD_MONEDA, COD_TAS_CASA)
values ('4', 'DIFERIDO-FC-25', '25', user, sysdate,user, sysdate, 71, 540, 'D', 1, 99999, null, 73);

insert into cc_tip_chequeras (COD_TIP_CHEQUERA, DESCRIPCION, CAN_CHEQUES, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_TASA, COD_TRANSACCION, TIPO, CAN_MINIMA, CAN_MAXIMA, COD_MONEDA, COD_TAS_CASA)
values ('6', 'DIFERIDO-LARGO-25', '25', user, sysdate, user, sysdate, 71, 540, 'D', 1, 99999, 'GS', 73);

--Insertamos parametria chequera
insert into cc_par_chequeras (COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, COD_TIP_CHEQUERA, SERIE, SIG_NRO_CHEQUE, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (null, null, null, null, null, '01', 1, user, sysdate, user, sysdate);

--Insertamos referencia general para AGZ
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NOM_CHE_AGZ', 'VISTA-CORTO-25', sysdate, user, user, sysdate, '1', '1', 'VISTA-CORTO-25', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NOM_CHE_AGZ', 'DIFERIDO-CORTO-25', sysdate, user, user, sysdate, '3', '3', 'DIFERIDO-CORTO-25', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NOM_CHE_AGZ', 'VISTA-FC-25', sysdate, user, user, sysdate, '2', '2', 'VISTA-FC-25', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NOM_CHE_AGZ', 'DIFERIDO-FC-25', sysdate, user, user, sysdate, '4', '4', 'DIFERIDO-FC-25', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('NOM_CHE_AGZ', 'DIFERIDO-LARGO-25', sysdate, user, user, sysdate, '6', '6', 'DIFERIDO-LARGO-25', 'S');

commit;