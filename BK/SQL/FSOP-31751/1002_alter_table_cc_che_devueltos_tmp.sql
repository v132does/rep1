ALTER TABLE it.cc_che_devueltos_tmp ADD multa number(18,2);
comment on column IT.CC_CHE_DEVUELTOS_TMP.multa is 'Monto de Multa.';

ALTER TABLE it.cc_che_devueltos_tmp ADD cod_sub_motivo  varchar2(10) ;
comment on column IT.cc_che_devueltos_tmp.cod_sub_motivo is 'Sub-motivo';

ALTER TABLE it.cc_che_devueltos_tmp ADD tip_importe  NUMBER(1) ;
comment on column IT.CC_CHE_DEVUELTOS_TMP.tip_importe
is 'Tipo de Importe (0 = Bajo Valor ; 1 = Alto Valor).';
  
ALTER TABLE it.cc_che_devueltos_tmp ADD cod_cau_secundaria  VARCHAR2(40) ;
comment on column IT.CC_CHE_DEVUELTOS_TMP.cod_cau_secundaria
is 'Códigos de causas secundarias. ';
  
ALTER TABLE it.cc_che_devueltos_tmp ADD dev_com_directa   VARCHAR2(1) default 'N';
comment on column IT.CC_CHE_DEVUELTOS_TMP.dev_com_directa
  is 'Devolución por compensacion directa.';

ALTER TABLE it.cc_che_devueltos_tmp ADD regularizado  VARCHAR2(1) default 'N';
comment on column IT.CC_CHE_DEVUELTOS_TMP.regularizado
  is 'Indica si fue regularizado el cheque(S/N).';

ALTER TABLE it.cc_che_devueltos_tmp ADD nro_caja  NUMBER(3);
comment on column IT.CC_CHE_DEVUELTOS_TMP.nro_caja
  is 'Número de caja.';

ALTER TABLE it.cc_che_devueltos_tmp ADD sal_multa   NUMBER(18,2);
comment on column IT.CC_CHE_DEVUELTOS_TMP.sal_multa
  is 'Saldo de la Multa.';

ALTER TABLE it.cc_che_devueltos_tmp ADD tipo  VARCHAR2(1);
comment on column IT.CC_CHE_DEVUELTOS_TMP.tipo
  is 'Tipo de Causa de Devolución.';

ALTER TABLE it.cc_che_devueltos_tmp ADD cod_cau_principal  VARCHAR2(38);
comment on column IT.CC_CHE_DEVUELTOS_TMP.cod_cau_principal
  is 'Codigo de Causa de Devolución.';

ALTER TABLE it.cc_che_devueltos_tmp ADD cod_ofi_camara  NUMBER(3);
comment on column IT.CC_CHE_DEVUELTOS_TMP.cod_ofi_camara 
  is 'Oficina de cámara.';

ALTER TABLE it.cc_che_devueltos_tmp ADD fecha  VARCHAR2(10) ;
comment on column IT.CC_CHE_DEVUELTOS_TMP.fecha
 is 'Fecha de Devolución.';
  
ALTER TABLE it.cc_che_devueltos_tmp ADD  hora VARCHAR2(8) default to_char(sysdate,'HH24:MI:SS');
comment on column IT.CC_CHE_DEVUELTOS_TMP.hora
 is 'Hora de Devolución.';
