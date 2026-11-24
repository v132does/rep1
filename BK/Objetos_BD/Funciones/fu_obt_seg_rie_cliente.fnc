CREATE OR REPLACE FUNCTION IT.FU_OBT_SEG_RIE_CLIENTE(p_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR2
IS
v_riesgo varchar2(20);
BEGIN
       select a.val_parametro into v_riesgo from ba_per_dat_adicionales a
       where a.cod_persona=P_COD_PERSONA
             and a.parametro='DTM_RIESGO';
        return v_riesgo;

EXCEPTION
       WHEN OTHERS THEN
            return null;
            RAISE_APPLICATION_ERROR(-20000,'No existe cliente con segmento de riesgo: '||p_COD_PERSONA||sqlerrm);

END;
/

