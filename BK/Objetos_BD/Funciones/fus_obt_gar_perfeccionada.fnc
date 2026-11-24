CREATE OR REPLACE FUNCTION IT.fus_obt_gar_perfeccionada
(
   p_nro_garantia IN pr_garantias.nro_garantia%TYPE,
   p_cod_garantia IN pr_garantias.cod_garantia%TYPE,
   p_estado       IN pr_garantias.estado%TYPE
) RETURN VARCHAR2 IS

   v_fec_actual        ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
   v_gar_perfeccionada pr_garantias.perfeccionada%TYPE := 'N';
   v_nom_tab_anexa     pr_gar_tipos.nom_tab_anexa%TYPE;
BEGIN

   --obtener el tipo de garantía
   BEGIN
      SELECT c.nom_tab_anexa
        INTO v_nom_tab_anexa
        FROM pr_gar_tipos c
       WHERE c.cod_garantia = p_cod_garantia;
   END;

   IF v_nom_tab_anexa = 'PR_GAR_HIPOTECARIAS' THEN
      SELECT nvl(decode(MAX(c.fec_inscripcion), NULL, 'N', 'S'), 'N')
        INTO v_gar_perfeccionada
        FROM pr_gar_hipotecarias c
       WHERE c.nro_garantia = p_nro_garantia
         AND c.fec_inscripcion <= v_fec_actual
         AND ((c.fec_fir_escritura IS NULL) OR
             (c.fec_fir_escritura IS NOT NULL AND c.fec_inscripcion IS NOT NULL))
         AND p_estado IN ('C', 'I', 'V');
      RETURN v_gar_perfeccionada;
   ELSIF v_nom_tab_anexa = 'PR_GAR_VEHICULOS' THEN
      SELECT nvl(decode(MAX(c.fec_inscripcion), NULL, 'N', 'S'), 'N')
        INTO v_gar_perfeccionada
        FROM pr_gar_vehiculos c
       WHERE c.nro_garantia = p_nro_garantia
         AND c.fec_inscripcion <= v_fec_actual
         AND ((c.fec_fir_escritura IS NULL) OR
             (c.fec_fir_escritura IS NOT NULL AND c.fec_inscripcion IS NOT NULL))
         AND p_estado IN ('C', 'I', 'V');
      RETURN v_gar_perfeccionada;
   ELSIF v_nom_tab_anexa = 'PR_GAR_WARRANTS' THEN
      SELECT decode(MAX(c.fec_inscripcion), NULL, 'N', 'S')
        INTO v_gar_perfeccionada
        FROM pr_gar_hipotecarias c
       WHERE c.nro_garantia = p_nro_garantia
         AND c.fec_inscripcion <= v_fec_actual;
      v_gar_perfeccionada := nvl(v_gar_perfeccionada, 'N');
   ELSE
      v_gar_perfeccionada := 'S';
   END IF;

   --si el estado de la garantía es diferente a C (confirmado)
   --retornar N
   IF p_estado <> 'C' THEN
      RETURN 'N';
   END IF;

   RETURN v_gar_perfeccionada;

EXCEPTION
   WHEN OTHERS THEN
      RETURN v_gar_perfeccionada;
END;
/

