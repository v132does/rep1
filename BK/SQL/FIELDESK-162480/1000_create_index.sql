begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

  create index IT.IN_EPERS_PER_TIPO on IT.BA_PERSONAS(COD_PERSONA, TIPO)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
  
  create index IT.IN_CBSAL_FEC_MOD_TIP_SAL on IT.CB_SAL_INVENTARIOS_HIS(FECHA, COD_MODALIDAD, TIP_SALDO)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    next 1M
    minextents 1
    maxextents unlimited
  );
