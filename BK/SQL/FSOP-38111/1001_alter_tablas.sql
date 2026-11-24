alter table it.cb_cif_asientos_tmp 
add cod_area number(3);
comment on column it.cb_cif_asientos_tmp.cod_area
  is 'Codigo del Area.';
  alter table it.cb_cif_asientos_tmp 
add cod_persona varchar2(10);
comment on column it.cb_cif_asientos_tmp.cod_persona
  is 'Codigo de Persona.';

alter table it.cb_cor_asientos_det_tmp 
add cod_area number(3);
comment on column it.cb_cor_asientos_det_tmp.cod_area
  is 'Codigo del Area.';
  alter table it.cb_cor_asientos_det_tmp 
add cod_persona varchar2(10);
comment on column it.cb_cor_asientos_det_tmp.cod_persona
  is 'Codigo de Persona.';  
