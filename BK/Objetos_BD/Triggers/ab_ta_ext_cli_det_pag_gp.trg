CREATE OR REPLACE TRIGGER IT.ab_ta_ext_cli_det_pag_gp
 BEFORE DELETE OR INSERT OR UPDATE
 ON IT.TA_EXT_CLI_DET_PAG_GP
 FOR EACH ROW

DECLARE
BEGIN
  -- Verificar que se realice por programa
  IF nvl(pae_cnf.g_aplicacion,'N') = 'N' THEN
    raise_application_error(-20000,
    'Solo pueden realizarse modificaciones a través del Sistema');
  END IF;
END;
/
