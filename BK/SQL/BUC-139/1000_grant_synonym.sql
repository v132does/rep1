-- Create the synonym
create or replace public synonym gv_fir_cuentas
  for IT.gv_fir_cuentas;
create or replace public synonym gv_fir_firmas
  for IT.gv_fir_firmas;
create or replace public synonym gv_fir_firmantes
  for IT.gv_fir_firmantes;
create or replace public synonym gv_fir_cta_detalle
  for IT.gv_fir_cta_detalle;  

GRANT SELECT ON IT.gv_fir_cuentas TO IT_TEMPORAL;  
GRANT SELECT ON IT.gv_fir_firmas TO IT_TEMPORAL;  
GRANT SELECT ON IT.gv_fir_firmantes TO IT_TEMPORAL;  
GRANT SELECT ON IT.gv_fir_cta_detalle TO IT_TEMPORAL; 
