create synonym  ge_cta_ips_emp_tmp for it.ge_cta_ips_emp_tmp;
grant insert, delete,update,select on it.ge_cta_ips_emp_tmp to it_temporal;


create synonym  prg_gen_cta_ips for it.prg_gen_cta_ips;
grant execute on it.prg_gen_cta_ips to it_temporal;
