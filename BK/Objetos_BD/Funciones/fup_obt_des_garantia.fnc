CREATE OR REPLACE FUNCTION IT.FUP_OBT_DES_GARANTIA
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
 RETURN VARCHAR2
 IS

V_NRO_GARANTIA PR_SOL_GARANTIAS.NRO_GARANTIA%TYPE;
V_COD_GARANTIA PR_SOL_GARANTIAS.COD_GARANTIA%TYPE;
V_DESCRIPCION PR_GAR_TIPOS.DESCRIPCION%TYPE;
CURSOR cd_garantia is
       SELECT a.nro_garantia,a.cod_garantia
         FROM pr_sol_garantias a,pr_gar_tipos b
        WHERE a.cod_garantia = b.cod_garantia
          --AND b.computable = 'S'
          AND a.nro_solicitud = p_nro_solicitud
          AND a.cod_garantia <> 1
        ORDER BY decode(a.cod_garantia,2,9999,a.cod_garantia),1 ASC;
BEGIN
     OPEN cd_garantia;
          FETCH cd_garantia INTO v_nro_garantia,v_cod_garantia;
     CLOSE cd_garantia;

     IF v_cod_garantia IS NOT NULL THEN
        SELECT descripcion
          INTO V_DESCRIPCION
          FROM pr_gar_tipos b
         WHERE b.cod_garantia = v_cod_garantia;
     ELSE
        V_DESCRIPCION := 'A sola firma';
     END IF;
     RETURN V_DESCRIPCION;
END;
/

