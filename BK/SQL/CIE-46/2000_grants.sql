grant execute on IT.prg_pro_dat_tarjetas to IT_TEMPORAL;
create or replace public synonym prg_pro_dat_tarjetas
  for IT.prg_pro_dat_tarjetas;

grant select, insert, update, delete on IT.ge_cla_operaciones_tmp to IT_TEMPORAL;
create or replace public synonym ge_cla_operaciones_tmp
  for IT.ge_cla_operaciones_tmp;
  
