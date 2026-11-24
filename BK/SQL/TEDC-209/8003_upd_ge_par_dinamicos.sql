BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
--Seteamos la variable que habilita la retención en N
update ge_par_dinamicos t 
set t.val_parametro = 'N'
where t.parametro = 'CJ_RET_DEP_TED';

commit;
