-- Create the synonym 
create or replace public synonym GV_SAL_ACTIVO
  for IT.GV_SAL_ACTIVO;
  
-- Create the synonym 
create or replace public synonym GV_SAL_PASIVO
  for IT.GV_SAL_PASIVO;
  
-- Create the synonym 
create or replace public synonym GV_CAR_ACTIVA
  for IT.GV_CAR_ACTIVA;
  
-- Create the synonym 
create or replace public synonym GV_CAR_PASIVA
  for IT.GV_CAR_PASIVA;
  
  
grant select on it.gv_sal_pasivo to it_temporal;

grant select on it.gv_sal_activo to it_temporal;

grant select on it.gv_car_activa to it_temporal;

grant select on it.gv_car_pasiva to it_temporal;