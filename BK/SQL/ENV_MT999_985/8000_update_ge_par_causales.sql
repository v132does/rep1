begin
  
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;

update ge_par_causales p
set p.val_parametro = val_parametro||',995'
where p.cod_causa = 237
and p.parametro= 'AFE_CIRCUITO';

commit;
end;
