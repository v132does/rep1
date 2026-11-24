alter table it.sb_ext_mt940 add nro_ref_rev_recibida number(15);
comment on column it.sb_ext_mt940.nro_ref_rev_recibida is 'Referencia de Reversión Recibida';
alter table it.sb_ext_mt940 add nro_ref_rev_enviada number(15);
comment on column it.sb_ext_mt940.nro_ref_rev_enviada is 'Referencia de Reversión Enviada';
