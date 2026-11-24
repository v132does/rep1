
begin
  
    begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
  
    
    PAO_MOR.PR_ENV_MOROSIDAD;

    commit;

  
end;
