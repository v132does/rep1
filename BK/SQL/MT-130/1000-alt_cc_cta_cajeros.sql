-- add/modify columns 
alter table it.cc_cta_cajeros add cod_ent_portavalor number(5);
-- add comments to the table 
comment on column it.cc_cta_cajeros.cod_ent_portavalor
  is 'Codigo ente para Porta Valor.';
