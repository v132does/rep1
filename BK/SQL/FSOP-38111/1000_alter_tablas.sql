alter table it.cb_asientos_det 
add cod_area number(3);
comment on column it.cb_asientos_det.cod_area
  is 'Codigo del Area.';
  
alter table it.cb_asientos_det 
add cod_persona varchar2(10);
comment on column it.cb_asientos_det.cod_persona
  is 'Codigo de Persona.';
  
alter table it.cb_asientos_det_res 
add cod_area number(3);
comment on column it.cb_asientos_det_res.cod_area
  is 'Codigo del Area.';
  
alter table it.cb_asientos_det_res 
add cod_persona varchar2(10);
comment on column it.cb_asientos_det_res.cod_persona
  is 'Codigo de Persona.';  
  
alter table it.cb_asientos_det_ini 
add cod_area number(3);
comment on column it.cb_asientos_det_ini.cod_area
  is 'Codigo del Area.';
  
alter table it.cb_asientos_det_ini 
add cod_persona varchar2(10);
comment on column it.cb_asientos_det_ini.cod_persona
  is 'Codigo de Persona.';    

alter table it.CB_ASIENTOS_DET_HIS 
add cod_area number(3);
comment on column it.CB_ASIENTOS_DET_HIS.cod_area
  is 'Codigo del Area.';
  
alter table it.CB_ASIENTOS_DET_HIS 
add cod_persona varchar2(10);
comment on column it.CB_ASIENTOS_DET_HIS.cod_persona
  is 'Codigo de Persona.'; 
  
alter table it.cb_asientos_det_his_ini 
add cod_area number(3);
comment on column it.cb_asientos_det_his_ini.cod_area
  is 'Codigo del Area.';
  
alter table it.cb_asientos_det_his_ini 
add cod_persona varchar2(10);
comment on column it.cb_asientos_det_his_ini.cod_persona
  is 'Codigo de Persona.';   
