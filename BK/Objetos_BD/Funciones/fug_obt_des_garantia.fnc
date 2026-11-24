CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_GARANTIA
 (P_NRO_SOLICITUD IN TA_SOLICITUDES.NRO_SOLICITUD%TYPE
 )
 RETURN VARCHAR2
 IS

V_NRO_GARANTIA TA_SOL_GARANTIAS.NRO_GARANTIA%TYPE;
V_COD_GARANTIA TA_SOL_GARANTIAS.COD_GARANTIA%TYPE;
V_DESCRIPCION PR_GAR_TIPOS.DESCRIPCION%TYPE;
CURSOR cd_garantia is
       SELECT nro_garantia, cod_garantia FROM (
       SELECT a.nro_garantia,a.cod_garantia
         FROM ta_sol_garantias a,pr_gar_tipos b
        WHERE a.cod_garantia = b.cod_garantia
          AND a.nro_solicitud = p_nro_solicitud
          AND a.cod_garantia <> 1
       UNION   
       SELECT c.nro_garantia, c.cod_garantia
         FROM ta_sol_lineas l, ta_cta_garantias c
        WHERE l.nro_cuenta = c.nro_cuenta
          AND l.nro_solicitud = p_nro_solicitud
          AND c.cod_garantia <> 1 )
        ORDER BY decode(cod_garantia,2,9999,cod_garantia),1 ASC;
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
END FUG_OBT_DES_GARANTIA;
/

