CREATE OR REPLACE FUNCTION IT.FUG_VER_APR_MULTIPROD (P_COD_PERSONA   BA_PERSONAS.COD_PERSONA%TYPE,
                                                  P_COD_MODULO 	  PR_SOLICITUDES.COD_MODULO%TYPE,
                                                  P_NRO_SOLICITUD PR_SOLICITUDES.NRO_SOLICITUD%TYPE,
                                                  P_TIP_OPE_TAR   VARCHAR2 DEFAULT NULL)
                                                  RETURN VARCHAR2 IS
  
  v_existe        varchar2(1) := 'N';
  v_nvo_nro_sol pr_solicitudes.nro_solicitud%type;
  FUNCTION lf_obt_nro_sol_sco (p_nro_solicitud pr_solicitudes.nro_solicitud%type,
   														 p_cod_modulo 	 pr_solicitudes.cod_modulo%type,
                               p_tip_ope_tar   varchar2) return varchar2 IS
     v_return pr_solicitudes.nro_solicitud%type;
  BEGIN
     BEGIN
		 	  IF p_cod_modulo = 6 THEN
				   SELECT to_number(a.val_parametro)
					   INTO v_return
		  			 FROM ba_tab_dat_adicionales a 
		  		  WHERE a.parametro='SCO_MUL_NRO_SOL_ORI' 
		   			  AND a.tab_relacion = 'PR_SOLICITUDES' -- Si la solicitud padre es TDC, buscar en PR_SOLICITUDES.
		   				AND a.referencia = p_nro_solicitud;
			  ELSIF p_cod_modulo = 5 THEN
           IF p_tip_ope_tar = 'T' THEN
              SELECT to_number(a.val_parametro)
                INTO v_return
                FROM ba_tab_dat_adicionales a 
               WHERE a.parametro='SCO_MUL_NRO_SOL_ORI' 
                 AND a.tab_relacion = 'TA_SOLICITUDES'-- Si la solicitud padre es Prest., buscar en TA_SOLICITUDES o TA_SOL_LINEAS.
                 AND a.referencia = p_nro_solicitud;
           ELSIF p_tip_ope_tar = 'L' THEN
              SELECT to_number(a.val_parametro)
                INTO v_return
                FROM ba_tab_dat_adicionales a 
               WHERE a.parametro='SCO_MUL_NRO_SOL_ORI' 
                 AND a.tab_relacion = 'TA_SOL_LINEAS' -- Si la solicitud padre es Prest., buscar en TA_SOLICITUDES o TA_SOL_LINEAS.
                 AND a.referencia = p_nro_solicitud;
           END IF; 
			  END IF;
     EXCEPTION
		 	  WHEN others THEN		   
			     v_return := null;  	
		 END;	
		 return v_return;
   END;
   
BEGIN
   v_nvo_nro_sol := lf_obt_nro_sol_sco(p_nro_solicitud, p_cod_modulo, p_tip_ope_tar);
   IF p_cod_modulo = 6 THEN
      BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ta_solicitudes
             WHERE cod_persona = p_cod_persona
               AND cod_estado IN ('PAN','PVC','APR')
               AND nro_solicitud = v_nvo_nro_sol;
      EXCEPTION
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN others THEN
               v_existe := 'N';
      END;
      IF v_existe = 'N' THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ta_sol_lineas
             WHERE cod_persona = p_cod_persona
               AND cod_estado IN ('PAN','PVC','APR')
               AND nro_solicitud = v_nvo_nro_sol;
         EXCEPTION
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN others THEN
               v_existe := 'N';
         END;
      END IF;
   ELSIF p_cod_modulo = 5 THEN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM pr_solicitudes
          WHERE cod_persona = p_cod_persona
            AND estado IN ('S','L','E','C')
            AND nro_solicitud = v_nvo_nro_sol;
      EXCEPTION
         WHEN too_many_rows THEN
            v_existe := 'S';
         WHEN others THEN
            v_existe := 'N';
      END;
   END IF; 
   
   IF v_existe = 'S' THEN
      RETURN 'N';
   ELSE
      RETURN 'S';
   END IF;
END FUG_VER_APR_MULTIPROD;
/

