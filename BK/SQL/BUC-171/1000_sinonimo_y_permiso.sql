create or replace public synonym gv_ext_legales
  for it.gv_ext_legales;
  
grant select on it.gv_ext_legales to it_temporal;  
