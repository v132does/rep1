begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
create index it.in_s940_referencia_bcp on it.sb_ext_mt940 (referencia_bcp)
  tablespace it_ind
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
