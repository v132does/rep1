-- 
create or replace public synonym ge_cta_blo_creditos
  for it.ge_cta_blo_creditos;
  
--  
grant all on it.ge_cta_blo_creditos to it_temporal; 

-- 
create or replace public synonym ge_cta_blo_creditos_det
  for it.ge_cta_blo_creditos_det;
  
--  
grant all on it.ge_cta_blo_creditos_det to it_temporal; 

--  
create or replace public synonym s_cod_blo_credito
  for it.s_cod_blo_credito;

-- 
grant select on it.s_cod_blo_credito to it_temporal;

--
create or replace public synonym prg_blo_des_credito
  for it.prg_blo_des_credito;

-- 
grant execute on it.prg_blo_des_credito to it_temporal;