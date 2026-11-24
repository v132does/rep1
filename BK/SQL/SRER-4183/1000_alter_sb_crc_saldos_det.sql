BEGIN 
PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; 
DBMS_SESSION.SET_IDENTIFIER('SRER-4183');

END;
/

ALTER TABLE it.sb_crc_saldos_det ADD (
    ind_movimiento      VARCHAR2(1),
    est_tarjeta         NUMBER(1),
    mto_deu_anterior    NUMBER(18,2),
    mto_pag_mes         NUMBER(18,2),
    mto_com_mes         NUMBER(18,2),
    mto_deu_facturar    NUMBER(18,2),
    mto_cargo           NUMBER(18,2),
    mto_lin_credito     NUMBER(18,2)
);


