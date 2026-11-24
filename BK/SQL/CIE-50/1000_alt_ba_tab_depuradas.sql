alter table IT.BA_TAB_DEPURADAS
add (LIMITE NUMBER(7));

comment on column BA_TAB_DEPURADAS.LIMITE
  is 'Nro de registros a procesar con el for_all en pre_eje_depuracion';
