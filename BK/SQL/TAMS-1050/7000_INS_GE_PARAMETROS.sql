Begin
pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
end;


-- 1) Registrar  parámetro en GE_PARAMETROS

UPDATE IT.GE_PAR_DINAMICOS
SET val_parametro = 'SRVBANCARD,CARDFIPR'
WHERE parametro = 'USU_PRO_ARC_TAR_EMPRESAS';

