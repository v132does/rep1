CREATE OR REPLACE FUNCTION IT.fus_obt_tas_solicitud
(
   p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
   p_tip_tasa      IN VARCHAR2
) RETURN NUMBER IS

--Retorna el valor de la tasa efectiva o Nominal de la solicitud(E-Efectiva,N-Nominal)

   v_val_tasa     ge_tas_fechas.val_tasa%TYPE;
   v_tas_efectiva ge_tas_fechas.val_tasa%TYPE;
   v_tas_nominal  ge_tas_fechas.val_tasa%TYPE;

BEGIN

   pas_bcp.pr_obt_tas_prestamo(p_nro_solicitud,null, v_tas_efectiva, v_tas_nominal);

   IF p_tip_tasa = 'E' THEN
      --Tasa Efectiva
      v_val_tasa := v_tas_efectiva;
   ELSIF p_tip_tasa = 'N' THEN
      --Tasa Nominal
      v_val_tasa := v_tas_nominal;
   END IF;

   RETURN v_val_tasa;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;
END;
/

