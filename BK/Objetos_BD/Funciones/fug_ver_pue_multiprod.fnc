CREATE OR REPLACE FUNCTION IT.FUG_VER_PUE_MULTIPROD (P_COD_PERSONA   BA_PERSONAS.COD_PERSONA%TYPE,
                                                  P_COD_MODULO    BA_MODULOS.COD_MODULO%TYPE,
                                                  P_COD_MODALIDAD GE_MODALIDADES.COD_MODALIDAD%TYPE DEFAULT NULL,
                                                  P_COD_SUB_MODAL GE_SUB_MODALIDADES.COD_SUB_MODALIDAD%TYPE DEFAULT NULL,
                                                  P_NRO_SOLICITUD PR_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL,
                                                  P_NVO_NRO_SOL   OUT PR_SOLICITUDES.NRO_SOLICITUD%TYPE)
                                                  RETURN VARCHAR2 IS
  v_mto_max_linea number(18,2):= fug_obt_pardinamico('SCO_MUL_MTO_MAX_TAR', 5);
  v_sum_mto_tar   ta_cta_tarjetas.lin_credito%type;
  v_existe        varchar2(1) := 'N';
  FUNCTION LF_VAL_SUM_LIN_CRE RETURN number IS
     v_return number;
  BEGIN
     SELECT nvl(trunc(sum(b.lin_credito),-6)+1000000, 0) -- Redondear al millón, hacia arriba.
       INTO v_return
       FROM ge_cta_clientes a, ta_cta_tarjetas b, ge_est_cuentas c
      WHERE a.nro_cuenta=b.nro_cuenta 
        AND a.relacion='P' 
        AND a.cod_persona = p_cod_persona
        AND b.cod_modulo=c.cod_modulo AND b.cod_modalidad=c.cod_modalidad AND b.estado=c.estado 
        AND c.activo='S';
     RETURN v_return;
  EXCEPTION
     WHEN others THEN
        return 0;
  END;
  --
  FUNCTION lf_obt_nro_sol_sco (p_nro_solicitud pr_solicitudes.nro_solicitud%type,
   														 p_cod_modulo 	 pr_solicitudes.cod_modulo%type) return varchar2 IS
     v_nro_sol pr_solicitudes.nro_solicitud%type;
  BEGIN
     BEGIN
		 	  IF p_cod_modulo = 6 THEN
				   SELECT max(to_number(a.referencia))
					   INTO v_nro_sol
		  			 FROM ba_tab_dat_adicionales a 
		  		  WHERE a.parametro='SCO_MUL_NRO_SOL_ORI' 
		   			  AND a.tab_relacion = 'PR_SOLICITUDES' -- Si la solicitud padre es TDC, buscar en PR_SOLICITUDES.
		   				AND a.val_parametro = p_nro_solicitud;
			  ELSIF p_cod_modulo = 5 THEN
				   SELECT max(to_number(a.referencia))
					   INTO v_nro_sol
		  			 FROM ba_tab_dat_adicionales a 
		  		  WHERE a.parametro='SCO_MUL_NRO_SOL_ORI' 
		   			  AND a.tab_relacion in ('TA_SOLICITUDES', 'TA_SOL_LINEAS') -- Si la solicitud padre es Prest., buscar en TA_SOLICITUDES o TA_SOL_LINEAS.
		   				AND a.val_parametro = p_nro_solicitud;
			  END IF;
     EXCEPTION
		 	  WHEN others THEN		   
			     v_nro_sol := null;  	
		 END;	
		 return v_nro_sol;
   END;
   
BEGIN
   -- Ver si tiene preaporbados
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_pro_pre_aprobados
       WHERE cod_persona = p_cod_persona
         AND cod_modulo = p_cod_modulo
         AND nvl(cod_modalidad, '9999') = nvl(nvl(p_cod_modalidad, cod_modalidad), '9999')
         AND nvl(cod_sub_modalidad, '9999') = nvl(nvl(p_cod_sub_modal, cod_sub_modalidad), '9999')
         AND estado = 'V';
   EXCEPTION
      WHEN too_many_rows THEN
         v_existe := 'S';
      WHEN others THEN
         v_existe := 'N';
   END;
   -- Excluir empleados
   IF v_existe = 'N' THEN
      IF fug_es_empleado(p_cod_persona) = 'S' THEN
         v_existe := 'S'; 
      END IF;
   END IF;
   -- Si no tiene preaprobado y no es funcionario, ver si tiene solicitudes pendientes
   IF v_existe = 'N' THEN
      p_nvo_nro_sol := lf_obt_nro_sol_sco(p_nro_solicitud, p_cod_modulo);
      IF p_cod_modulo = 5 THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ta_solicitudes
             WHERE cod_persona = p_cod_persona
               AND cod_estado IN ('PAN','PVC','APR')
               AND (nro_solicitud <> p_nvo_nro_sol or p_nvo_nro_sol is null);
         EXCEPTION
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN others THEN
               v_existe := 'N';
         END;
         /*Si el producto B ya está aprobado, ya no le debe volver a ofrecer*/
         IF v_existe = 'N' THEN
            BEGIN
               SELECT 'S'
                 INTO v_existe
                 FROM ta_solicitudes
                WHERE cod_persona = p_cod_persona
                  AND cod_estado = 'TIA'
                  AND nro_solicitud = p_nvo_nro_sol;
            EXCEPTION
               WHEN too_many_rows THEN
                  v_existe := 'S';
               WHEN others THEN
                  v_existe := 'N';
            END;
         END IF;
         /*Si no tiene preaprobado y no tiene solicitudes pendientes,
         ver si la sumatoria de sus TDC no supera el limite de 150MM*/
         IF v_existe = 'N' THEN
            v_sum_mto_tar := lf_val_sum_lin_cre;
            IF v_sum_mto_tar >= v_mto_max_linea THEN
               v_existe := 'S';
            END IF;
         END IF;
      ELSIF p_cod_modulo = 6 THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM pr_solicitudes
             WHERE cod_persona = p_cod_persona
               AND estado IN ('S','L','E','C')
               AND (nro_solicitud <> p_nvo_nro_sol or p_nvo_nro_sol is null);
         EXCEPTION
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN others THEN
               v_existe := 'N';
         END;
         /*Si el producto B ya está aprobado, ya no le debe volver a ofrecer*/
         IF v_existe = 'N' THEN
            BEGIN
               SELECT 'S'
                 INTO v_existe
                 FROM pr_solicitudes
                WHERE cod_persona = p_cod_persona
                  AND estado = 'A'
                  AND nro_solicitud = p_nvo_nro_sol;
            EXCEPTION
               WHEN too_many_rows THEN
                  v_existe := 'S';
               WHEN others THEN
                  v_existe := 'N';
            END;
         END IF;
      END IF; 
   END IF;
   
   -- Si tiene preaprob o una solicitud pendiente, devolver N
   IF v_existe = 'S' THEN
      RETURN 'N';
   ELSE
      RETURN 'S';
   END IF;
END;
/

