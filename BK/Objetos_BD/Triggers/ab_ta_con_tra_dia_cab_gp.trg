CREATE OR REPLACE TRIGGER IT.AB_TA_CON_TRA_DIA_CAB_GP
 BEFORE DELETE OR INSERT OR UPDATE
     ON IT.TA_CON_TRA_DIA_CAB_GP
    FOR EACH ROW
DECLARE
BEGIN
  -- Verificar que se realice por programa
  IF nvl( pae_cnf.g_aplicacion, 'N' ) = 'N' THEN
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
  END IF;
  -- Controlar si el módulo se encuentra habilitado
  pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
END;
