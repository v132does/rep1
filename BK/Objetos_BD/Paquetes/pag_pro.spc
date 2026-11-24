CREATE OR REPLACE PACKAGE IT.PAG_PRO IS

   FUNCTION fu_obt_cta_cte_comb(p_nro_cuenta IN ah_cta_vistas.nro_cuenta%TYPE) RETURN VARCHAR2;

   FUNCTION fu_obt_cta_aho_comb(p_nro_cuenta IN ah_cta_vistas.nro_cuenta%TYPE) RETURN VARCHAR2;

   FUNCTION fu_obt_sub_mod_cuenta(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;

   FUNCTION fu_obt_tas_cuenta(p_nro_cuenta IN VARCHAR2, p_cod_tasa IN NUMBER) RETURN VARCHAR2;

   FUNCTION fu_obt_cta_codeudor(p_nro_cuenta IN VARCHAR2, p_nro_garantia IN NUMBER) RETURN VARCHAR2;

   FUNCTION fu_obt_pla_cuenta(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;

   FUNCTION fu_obt_sal_pro_cuenta(p_nro_cuenta IN VARCHAR2, p_sal_minimo IN NUMBER) RETURN VARCHAR2;

   FUNCTION fu_obt_nom_principal(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2;
   
   FUNCTION fu_obt_tip_garantia(p_nro_cuenta IN VARCHAR2, p_nro_garantia IN NUMBER) RETURN VARCHAR2;

END;
/

