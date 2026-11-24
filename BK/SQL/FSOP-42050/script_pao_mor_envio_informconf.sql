
begin
  
    begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
  

    PAO_MOR.PR_PRO_INF_CONFIRMAR('30/10/2024');

    commit;
  
end;
