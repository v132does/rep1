alter table it.ta_not_mov_push
add (cod_billetera NUMBER, etiquetas VARCHAR2(300));
comment on column IT.ta_not_mov_push.cod_billetera
  is 'Identificación de la billetera - Wallet id';
comment on column IT.ta_not_mov_push.etiquetas
  is 'Lista de etiquetas - Tags';
