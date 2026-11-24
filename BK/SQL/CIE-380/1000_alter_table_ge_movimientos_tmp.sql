Alter Table it.ge_movimientos_tmp 
 Add procesado    VARCHAR2(1) default 'N';
 
comment on column IT.GE_MOVIMIENTOS_TMP.procesado
  is 'Procesado. (N=NO / S=SI).';
