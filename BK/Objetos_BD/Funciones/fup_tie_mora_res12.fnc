CREATE OR REPLACE FUNCTION IT.FUP_TIE_MORA_RES12
 (P_NRO_GARANTIA IN PR_GARANTIAS.NRO_GARANTIA%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
 CURSOR c_cta_gar(p_nro_garantia pr_cta_garantias.nro_garantia%type) IS
   SELECT nro_cuenta
     FROM pr_cta_garantias x
    WHERE x.nro_garantia = p_nro_garantia
      AND EXISTS ( SELECT 0 
                     FROM pr_cta_prestamos c 
                    WHERE c.nro_cuenta = x.nro_cuenta  
                      AND c.estado <> 'N' );
 v_dia_atraso     pr_cta_prestamos.dia_atraso%type;                                           
BEGIN
   IF p_nro_garantia IS NOT NULL THEN
      FOR g in c_cta_gar(p_nro_garantia) LOOP
	      ---
          BEGIN
            SELECT nvl(p.dia_atraso, 0)
              INTO v_dia_atraso
              FROM pr_cta_prestamos p
             WHERE p.nro_cuenta = g.nro_cuenta;
          EXCEPTION
            WHEN OTHERS THEN
              v_dia_atraso := 0;
          END;
		  ---
          IF v_dia_atraso > to_number(fug_obt_pardinamico('CAN_DIA_MOR_RES12')) THEN
             RETURN 'S';
          END IF;
      END LOOP;
   ELSIF p_nro_cuenta IS NOT NULL THEN
      ---
      BEGIN
        SELECT nvl(p.dia_atraso, 0)
          INTO v_dia_atraso
          FROM pr_cta_prestamos p
         WHERE p.nro_cuenta = p_nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          v_dia_atraso := 0;
      END;
	  ---
      IF v_dia_atraso > to_number(fug_obt_pardinamico('CAN_DIA_MOR_RES12')) THEN
         RETURN 'S';
      END IF;   
   END IF;
   
   RETURN 'N';
            
END;
/

