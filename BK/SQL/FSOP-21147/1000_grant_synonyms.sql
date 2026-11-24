create or replace public synonym TM_PER_JUDICIALES
  for IT.TM_PER_JUDICIALES;
  
grant all on TM_PER_JUDICIALES to it_temporal;


create or replace public synonym prg_inh_per_judiciales
  for IT.prg_inh_per_judiciales;
  
grant execute on prg_inh_per_judiciales to it_temporal;

create or replace public synonym prg_inh_per_pep 
  for IT.prg_inh_per_pep ;
  
grant execute on prg_inh_per_pep  to it_temporal;

create or replace public synonym TM_CLIENTE_PEP
  for IT.TM_CLIENTE_PEP;
  
grant all on TM_CLIENTE_PEP to it_temporal;


create or replace public synonym TM_ONU_FISICAS
  for IT.TM_ONU_FISICAS;
  
grant all on TM_ONU_FISICAS to it_temporal;
