
begin
  
    begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
  
    
    it.pao_mor.PR_GEN_INF_ARCHIVO('24/10/2024');

    commit;

  
end;
