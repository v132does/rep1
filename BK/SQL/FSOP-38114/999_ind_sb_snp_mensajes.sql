begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/

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