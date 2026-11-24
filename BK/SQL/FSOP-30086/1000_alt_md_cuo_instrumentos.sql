 ALTER TABLE IT.MD_CUO_INSTRUMENTOS
      DROP CONSTRAINT CK_MDCUO_ESTADO;
    
    alter table IT.MD_CUO_INSTRUMENTOS
     add constraint CK_MDCUO_ESTADO
      check (ESTADO IN ('R','C','N','V','S','E','X','T','I'));
