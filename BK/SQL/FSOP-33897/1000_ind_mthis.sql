begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
create index IT.IN_AMHIS_FECHA on IT.AH_MOVIMIENTOS_HIS(FECHA,COD_MOD_PADRE)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );

create index IT.IN_PMHIS_COD_MOD_PADRE on IT.PR_MOVIMIENTOS_HIS (FECHA, COD_MOD_PADRE)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );
  
 create index IT.IN_TMHIS_COD_OFI_ORIGEN on IT.TA_MOVIMIENTOS_HIS (FECHA, COD_OFI_ORIGEN)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );
  
  create index IT.IN_LMHIS_FECHA on IT.LC_MOVIMIENTOS_HIS (FECHA)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );
 
 create index IT.IN_GEMOV_COD_MOD_PADRE on IT.GE_MOVIMIENTOS (FECHA, COD_MOD_PADRE)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  ); 
  
create index IT.IN_GMNOC_COD_MOD_PADRE on IT.GE_MOVIMIENTOS_NOC (FECHA, COD_MOD_PADRE)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  ); 
  
  create index IT.IN_OMHIS_COD_OFI_ORIGEN on IT.OV_MOVIMIENTOS_HIS (FECHA, COD_OFI_ORIGEN)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );
 create index IT.IN_AMHIS_COD_MAD_PADRE on IT.AF_MOVIMIENTOS_HIS (FECHA, COD_MAD_PADRE)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );
  
  create index IT.IN_SBMEN_VALOR on IT.SB_SNP_MENSAJES(REGEXP_SUBSTR (VALOR,'F[^//]*'),CAMPO,COD_MENSAJE,NRO_LINEA)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );

  create index IT.IN_SBMEN_NRO_REFERENCIA on IT.SB_SNP_MENSAJES(NRO_REFERENCIA,CAMPO)
  tablespace IT_IND
  pctfree 10
  initrans 40
  maxtrans 255
  storage
  (
    initial 704K
    next 1M
    minextents 1
    maxextents unlimited
  );

 commit;