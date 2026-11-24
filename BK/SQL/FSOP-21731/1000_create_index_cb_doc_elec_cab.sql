create index IT.IN_CBDCAB_DEST on IT.cb_doc_elec_cab (DEST||'-'||DPUNEXP||'-'||DNUMDOC,ITIDE)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 256K
    next 1M
    minextents 1
    maxextents unlimited
  );

create index IT.IN_CBDCAB_DEST2 on IT.cb_doc_elec_cab (DEST||'-'||DPUNEXP||'-'||DNUMDOC,EST_FAC,ITIDE)
  tablespace IT_IND
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 256K
    next 1M
    minextents 1
    maxextents unlimited
  );
