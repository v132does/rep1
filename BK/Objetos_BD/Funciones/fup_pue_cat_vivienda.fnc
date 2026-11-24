CREATE OR REPLACE FUNCTION IT.FUP_PUE_CAT_VIVIENDA
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
  P_DIA_ATRASO IN PR_CTA_PRESTAMOS.DIA_ATRASO%TYPE,
  P_FEC_ULT_CATEGORIZACION IN PR_CTA_PRESTAMOS.FEC_ULT_CATEGORIZACION%TYPE,
  P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 )
 RETURN VARCHAR2
 IS
 v_can_meses      number(3) := to_number(fug_obt_pardinamico('SIB_CAN_MES_HIP_ATRASO'));
 v_fec_actual     date := pag_cal.fu_obt_fec_actual(6);
 v_pue_categoria  varchar2(1) := 'N';
 v_fec_cobro      date;
BEGIN
   IF p_dia_atraso = 0 THEN 
      BEGIN
        SELECT MAX(c.fecha)
          INTO v_fec_cobro
          FROM pr_cobros c
         WHERE c.nro_cuenta = p_nro_cuenta
           AND (c.fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL)           
           AND c.dia_mora > 0;
      EXCEPTION 
        WHEN OTHERS THEN
          v_fec_cobro := null;
      END;
	  ---
      IF v_fec_cobro IS NULL THEN
         v_fec_cobro := nvl(p_fec_ult_categorizacion, p_fec_inicio);
      END IF;
      IF v_fec_actual >= add_months(v_fec_cobro, v_can_meses) THEN
         v_pue_categoria := 'S';
      END IF;     
   END IF;   
   RETURN v_pue_categoria;           
END;
/

