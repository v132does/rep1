begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

INSERT INTO GE_PAR_CAUSALES(COD_CAUSA,PARAMETRO,VAL_PARAMETRO)
select b.cod_causa,'AFE_CTA_AHORRO_BAJO_RIESGO','S'
from ge_par_causales a,ge_causales b
where parametro='AFE_CTA_AHORRO'
and val_parametro='S'
and b.tipo='I'
and a.cod_causa=b.cod_causa
AND EXISTS (Select NULL
              from ba_cod_referencias t
             where t.dominio = 'COD_INH_LISTAS'
               AND t.val_minimo=B.Cod_Causa);
