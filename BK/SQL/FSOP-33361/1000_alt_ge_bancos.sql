alter table IT.GE_BANCOS
        add (COD_PAIS   NUMBER(3),
             COD_CIUDAD NUMBER(3));

comment on column GE_BANCOS.COD_PAIS
  is 'Codigo de Pais que corresponde al Banco.';
  
comment on column GE_BANCOS.COD_CIUDAD
  is 'Codigo de Ciudad que corresponde al Banco.';
  
alter table IT.GE_BANCOS
  add constraint FK_GPAI_COD_PAIS foreign key (COD_PAIS)
  references IT.BA_PAISES (COD_PAIS);

alter table IT.GE_BANCOS
  add constraint FK_GCIU_COD_CIUDAD foreign key (COD_CIUDAD, COD_PAIS)
  references IT.BA_CIUDADES (COD_CIUDAD, COD_PAIS);
