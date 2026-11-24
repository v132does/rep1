alter table it.bw_pag_servicios
add ( nro_caja          NUMBER(3),
         canal          VARCHAR2(20));             
comment on column IT.bw_pag_servicios.nro_caja
  is 'Número de Terminal desde la cual se accede.';
comment on column IT.bw_pag_servicios.canal
  is 'Canal desde la cual se accede en la WEB';
  
alter table it.bw_movimientos
add (canal          VARCHAR2(20));
comment on column IT.bw_movimientos.canal
  is 'Canal desde la cual se accede en la WEB';