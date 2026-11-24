CREATE OR REPLACE PACKAGE BODY IT."PAG_PRO" IS

   /* Obtiene la Cta. Cte. si es una Cuenta Combinada. */
   FUNCTION fu_obt_cta_cte_comb(p_nro_cuenta IN ah_cta_vistas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      v_nro_cta_cte cc_cta_combinadas.nro_cta_cte%TYPE;
   BEGIN
      SELECT nro_cta_cte
        INTO v_nro_cta_cte
        FROM cc_cta_combinadas
       WHERE nro_cta_ahorro = p_nro_cuenta;
      RETURN v_nro_cta_cte;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;

   /* Obtiene la Cta. Ahorro si es una Cuenta Combinada. */
   FUNCTION fu_obt_cta_aho_comb(p_nro_cuenta IN ah_cta_vistas.nro_cuenta%TYPE) RETURN VARCHAR2 IS
      v_nro_cta_aho cc_cta_combinadas.nro_cta_ahorro%TYPE;
   BEGIN
      SELECT nro_cta_ahorro
        INTO v_nro_cta_aho
        FROM cc_cta_combinadas
       WHERE nro_cta_cte = p_nro_cuenta;
      RETURN v_nro_cta_aho;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;

   /* Obtiene Descripción de Sub-Modalidad de una cuenta. */
   FUNCTION fu_obt_sub_mod_cuenta(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_descripcion       ge_sub_modalidades.descripcion%TYPE := NULL;
      v_cod_modulo        ge_sub_modalidades.cod_modulo%TYPE;
      v_cod_modalidad     ge_sub_modalidades.cod_modalidad%TYPE;
      v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%TYPE;
   BEGIN
      SELECT cod_modulo, cod_modalidad, cod_sub_modalidad
        INTO v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad
        FROM ge_cuentas
       WHERE nro_cuenta = p_nro_cuenta;
      v_descripcion := fug_obt_des_submodalidad(v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad);
      RETURN v_descripcion;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;

   /* Obtiene Tasas Personalizadas de una cuenta. */
   FUNCTION fu_obt_tas_cuenta(p_nro_cuenta IN VARCHAR2, p_cod_tasa IN NUMBER) RETURN VARCHAR2 IS
      v_dato       VARCHAR2(300);
      v_cod_moneda ge_cuentas.cod_moneda%TYPE;
   BEGIN
      BEGIN
         SELECT g.cod_moneda INTO v_cod_moneda FROM ge_cuentas g WHERE g.nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'en fu_obt_tas_cuenta - ' || SQLERRM);
      END;
      SELECT b.descripcion || '. Tasa: ' || nvl(a.val_tasa, 0) ||
             decode(b.tip_valor, 'P', '%', v_cod_moneda)
        INTO v_dato
        FROM ge_tas_fechas a, ge_tasas b
       WHERE a.cod_tasa = b.cod_tasa
         AND a.nro_cuenta = p_nro_cuenta
         AND a.cod_tasa = p_cod_tasa
         AND a.fec_vigencia >= pag_cal.fu_obt_fec_actual(1);
      RETURN v_dato;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RETURN SQLERRM;
         END IF;
   END;

   /* Obtiene Codeudor de una cuenta. */
   FUNCTION fu_obt_cta_codeudor(p_nro_cuenta IN VARCHAR2, p_nro_garantia IN NUMBER) RETURN VARCHAR2 IS
      v_dato VARCHAR2(300);
   BEGIN
      SELECT b.nom_completo
        INTO v_dato
        FROM pr_cta_garantias a, ba_personas b
       WHERE a.nro_garantia = b.cod_persona
         AND a.nro_cuenta = p_nro_cuenta
         AND a.nro_garantia = p_nro_garantia
         AND a.cod_garantia = 2;
      RETURN v_dato;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;

   /* Obtiene Plazo en días de una cuenta. */
   FUNCTION fu_obt_pla_cuenta(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_dato VARCHAR2(300);
   BEGIN
      SELECT a.fec_vencimiento - a.fec_inicio
        INTO v_dato
        FROM pr_cta_prestamos a
       WHERE a.nro_cuenta = p_nro_cuenta;
      RETURN v_dato;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;

   /* Obtiene Saldo Promedio de una cuenta. */
   FUNCTION fu_obt_sal_pro_cuenta(p_nro_cuenta IN VARCHAR2, p_sal_minimo IN NUMBER) RETURN VARCHAR2 IS
      v_sal_promedio      ge_cuentas.sal_promedio%TYPE;
      v_cod_persona       ge_cta_clientes.cod_persona%TYPE;
      v_cod_moneda        ge_cuentas.cod_moneda%TYPE;
      v_cod_modulo        ge_cuentas.cod_modulo%TYPE;
      v_cod_modalidad     ge_cuentas.cod_modalidad%TYPE;
      v_cod_oficina       ge_cuentas.cod_oficina%TYPE;
      v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%TYPE;
   BEGIN
      v_sal_promedio := p_sal_minimo;
      IF p_sal_minimo IS NULL THEN
         BEGIN
            SELECT g.cod_persona,
                   f.cod_moneda,
                   f.cod_modulo,
                   f.cod_modalidad,
                   f.cod_oficina,
                   f.cod_sub_modalidad
              INTO v_cod_persona,
                   v_cod_moneda,
                   v_cod_modulo,
                   v_cod_modalidad,
                   v_cod_oficina,
                   v_cod_sub_modalidad
              FROM ge_cta_clientes g, ge_cuentas f
             WHERE g.nro_cuenta = f.nro_cuenta
               AND g.relacion = 'P'
               AND g.nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'en fu_obt_sal_pro_cuenta - ' || SQLERRM);
         END;
         v_sal_promedio := fug_obt_sal_min_pactado(v_cod_moneda,
                                                   v_cod_persona,
                                                   v_cod_modulo,
                                                   v_cod_modalidad,
                                                   v_cod_oficina,
                                                   v_cod_sub_modalidad);
      END IF;
      RETURN v_sal_promedio;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            RETURN SQLERRM;
         END IF;
   END;

   /* Obtiene el Nombre del principal de una cuenta. */
   FUNCTION fu_obt_nom_principal(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS      
   BEGIN
      RETURN fue_obt_nom_persona(fug_obt_cli_principal(p_nro_cuenta));      
   EXCEPTION
      WHEN OTHERS THEN
         RETURN SQLERRM;
   END;
   
   FUNCTION fu_obt_tip_garantia(p_nro_cuenta IN VARCHAR2, p_nro_garantia IN NUMBER) RETURN VARCHAR2 IS
      v_dato VARCHAR2(300);
   BEGIN
      SELECT t.descripcion
        INTO v_dato
        FROM pr_cta_garantias a, pr_gar_tipos t
       WHERE nvl(a.nro_garantia, 0) = nvl(p_nro_garantia, 0)
         AND a.nro_cuenta = p_nro_cuenta
         AND a.cod_garantia = t.cod_garantia
         AND rownum = 1;
      RETURN v_dato;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;
   END;

END;
/

