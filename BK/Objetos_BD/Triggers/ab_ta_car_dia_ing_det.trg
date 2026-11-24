CREATE OR REPLACE TRIGGER IT.ab_ta_car_dia_ing_det
 BEFORE DELETE OR INSERT OR UPDATE
     ON "IT"."TA_CAR_DIA_ING_DET"
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
/

