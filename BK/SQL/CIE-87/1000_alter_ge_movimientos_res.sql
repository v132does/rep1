begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
alter table it.ge_movimientos_res add rutina1 VARCHAR2(30);
comment on column it.GE_MOVIMIENTOS_RES.rutina1 is 'Nombre de rutina.';

alter table it.ge_movimientos_res add tipo VARCHAR2(1);
comment on column it.GE_MOVIMIENTOS_RES.tipo is 'Tipo de transaccion. Define en que forma afecta en la operacion.';

alter table it.ge_movimientos_res add afecta VARCHAR2(1);
comment on column it.GE_MOVIMIENTOS_RES.afecta is 'Detalle. (D=Debito, C=Credito, S=Cabecera).';
 
commit;
/

