ALTER TABLE it.cc_che_devueltos ADD tip_importe  NUMBER(1) ;
comment on column IT.cc_che_devueltos.tip_importe
is 'Tipo de Importe (0 = Bajo Valor ; 1 = Alto Valor).';
  
ALTER TABLE it.cc_che_devueltos ADD cod_sub_motivo  varchar2(10) ;
comment on column IT.cc_che_devueltos.cod_sub_motivo is 'Sub-motivo';

