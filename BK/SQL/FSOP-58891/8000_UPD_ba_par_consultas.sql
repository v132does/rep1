EXEC Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

UPDATE ba_par_consultas SET OBLIGATORIO = 'N' WHERE cod_campo = 'PAG_PRO3' AND cod_consulta = 'RET_PROVEE';

COMMIT;