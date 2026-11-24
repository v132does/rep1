CREATE OR REPLACE PROCEDURE IT.prs_obt_gru_eco_bcp
(  p_abreviatura IN ba_tip_documentos.abreviatura%TYPE,
   p_doc_numero  IN sb_gru_eco_bcp_det.doc_numero%TYPE,
   p_grupo_1     OUT sb_gru_eco_bcp_det.grupo%TYPE,
   p_grupo_2     OUT sb_gru_eco_bcp_det.grupo%TYPE,
   p_grupo_3     OUT sb_gru_eco_bcp_det.grupo%TYPE,
   p_grupo_4     OUT sb_gru_eco_bcp_det.grupo%TYPE,
   p_grupo_5     OUT sb_gru_eco_bcp_det.grupo%TYPE,
   p_grupos      OUT VARCHAR2
) IS
   TYPE ref_cursor IS RECORD(grupo sb_gru_eco_bcp_det.grupo%TYPE);
   TYPE t_cursor_tab IS TABLE OF ref_cursor INDEX BY BINARY_INTEGER;
   v_ref_cursor t_cursor_tab;
   CURSOR c_grupos IS
      SELECT b.grupo
        FROM sv_gru_eco_bcp b
       WHERE b.tip_documento = p_abreviatura
         AND b.doc_numero = p_doc_numero
         AND b.fec_baja IS NULL
         AND b.per_fec_baja IS NULL
       ORDER BY b.per_fec_alta;
   v_nro_grupo NUMBER := 0;
   v_grupos    VARCHAR2(4000) := '';
BEGIN
   FOR i IN c_grupos LOOP
      v_nro_grupo := v_nro_grupo + 1;
      v_grupos := v_grupos || ',' || i.grupo;
      v_ref_cursor(v_nro_grupo).grupo := i.grupo;
   END LOOP;
   p_grupo_1 := NULL;
   p_grupo_2 := NULL;
   p_grupo_3 := NULL;
   p_grupo_4 := NULL;
   p_grupo_5 := NULL;
   FOR i IN 1 .. v_nro_grupo LOOP
      IF i = 1 THEN
         p_grupo_1 := v_ref_cursor(1).grupo;
      ELSIF i = 2 THEN
         p_grupo_2 := v_ref_cursor(2).grupo;
      ELSIF i = 3 THEN
         p_grupo_3 := v_ref_cursor(3).grupo;
      ELSIF i = 4 THEN
         p_grupo_4 := v_ref_cursor(4).grupo;
      ELSIF i = 5 THEN
         p_grupo_5 := v_ref_cursor(5).grupo;
      END IF;
   END LOOP;
   p_grupos := substr(v_grupos, 2);
END;
/

