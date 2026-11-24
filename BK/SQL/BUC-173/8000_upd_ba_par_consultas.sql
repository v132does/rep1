BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
update ba_par_consultas a 
set a.cod_campo='GRU_ECO_CO'
where a.cod_consulta='CD_SAL_GRU'
and a.cod_campo='GRU_ECO';
commit;
