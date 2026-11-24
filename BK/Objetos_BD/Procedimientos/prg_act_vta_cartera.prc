CREATE OR REPLACE PROCEDURE IT.PRG_ACT_VTA_CARTERA (P_REF_LOTE IN NUMBER) IS
   -- Actualiza los campos de la cartera de clientes
   -- Variables. 
   v_nro_tarjeta          ta_tarjetas.nro_tarjeta%type;
   v_cod_afinidad         ta_cta_tarjetas.afinidad%type;
   v_des_afinidad         ba_cod_referencias.significado%type;
   v_can_cuotas           pr_cta_prestamos.can_cuotas%type;  
   v_can_cuo_vencidas     pr_cta_prestamos.can_cuotas%type;
   v_dir_principal        ba_direcciones.direccion%type;
   v_dir_laboral          ba_direcciones.direccion%type;
   v_tot_riesgo           ge_cla_operaciones.tot_deu_real%type := 0;
   v_liq_imp_sobregiro    ge_cla_operaciones.tot_deu_real%type := 0;
   v_liq_int_sobregiro    ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_deuda            ge_cla_operaciones.tot_deu_real%type := 0;
   v_tip_garantias        ge_sal_inv_vta_cartera_tmp.gar_cliente%type;
   v_tip_gar_vencidas     ge_sal_inv_vta_cartera_tmp.gar_cliente%type;
   v_tip_gar_codeudor     ge_sal_inv_vta_cartera_tmp.gar_codeudor%type;
   v_tip_gar_ven_codeudor ge_sal_inv_vta_cartera_tmp.gar_codeudor%type;
   v_cod_per_codeudor     ge_sal_inv_vta_cartera_tmp.cod_per_codeudor%type;
   v_tip_bloqueo          ge_sal_inv_vta_cartera_tmp.tip_bloqueo%type;
   v_tip_inhibicion       ge_sal_inv_vta_cartera_tmp.tip_inhibicion%type;
   v_fec_pag_ult_nomina   date := to_date('01/01/1900','dd/mm/yyyy');
   v_cli_nomina           varchar2(1) := 'N';
   v_nro_tel_particular   varchar2(30) := NULL;
   v_nro_tel_laboral      varchar2(30) := NULL;
   v_fec_cambio           date := pag_cal.fu_obt_fec_anterior(1);

   -- Cursores.
   CURSOR c_cta_clientes IS
      SELECT ge.cod_persona, ba.nom_completo nom_persona, ba.nro_documento, ge.cod_oficina, ge.nro_cuenta,
             (CASE WHEN bm.cod_modulo = 6 THEN
                 NVL((SELECT pe.descripcion
                    FROM pr_cta_prestamos pr, pr_rub_economicos pe
                   WHERE pr.nro_cuenta = ge.nro_cuenta
                     AND pr.cod_rub_economico = pe.cod_rub_economico),bm.descripcion)
              ELSE
                 bm.descripcion
              END) tipo_operacion,
             gc.cod_usu_oficial||' - '||fue_obt_nom_usuario(gc.cod_usu_oficial) gestor, ge.tot_deu_real, ge.tot_deu_contingente,
             ge.tot_prevision, ge.dia_atraso, gc.cat_riesgo, gc.fec_ult_cla_sistema, gc.cat_sistema, gc.tot_deu_sistema,
             gc.tot_deu_con_sistema, gc.tot_deu_cod_sistema, ge.cod_modulo, ge.cod_modalidad
        FROM ge_cla_operaciones ge, ge_clientes gc, ba_personas ba, ge_modalidades bm, ge_sal_inv_vta_cartera_tmp a
       WHERE ge.cod_persona = ba.cod_persona --join
         AND ge.cod_persona = gc.cod_persona --join
         AND ge.cod_modulo = bm.cod_modulo --join
         AND ge.cod_modalidad = bm.cod_modalidad --join
         AND ge.nro_cuenta = a.nro_cuenta --join
         AND a.ref_lote = P_REF_LOTE; --toma el lote de la cartera

   CURSOR c_codeudores(p_nro_cuenta in ge_cla_operaciones.nro_cuenta%TYPE) IS
      SELECT gc.cod_persona
        FROM ge_cta_clientes gc
       WHERE gc.nro_cuenta = p_nro_cuenta
         AND gc.relacion = 'C';

   -- Funcion
   FUNCTION fu_obt_mto_riesgo(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN NUMBER
   AS
   -- Variable.
   v_monto    ge_cla_operaciones.tot_deu_real%type := 0;
   v_modulos  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('INV_VTA_CAR_TOT_RIESGO');
   BEGIN
      SELECT sum(nvl(ge.tot_deu_real,0))
        INTO v_monto
        FROM ge_cla_operaciones ge
       WHERE ge.cod_persona = p_cod_persona
         AND instr(v_modulos,ge.cod_modulo) > 0
         AND ge.tot_deu_real <> 0;

      RETURN nvl(v_monto,0);

   EXCEPTION
      WHEN OTHERS THEN
         v_monto := 0;
         RETURN nvl(v_monto,0);
   END;

   -- Obtiene las garantias que posee la persona.
   FUNCTION fu_obt_garantias(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN VARCHAR2
   AS
   -- Variable.
   v_tip_garantia ge_sal_inv_vta_cartera_tmp.Gar_Cliente%type := NULL;

   -- Cursor.
   CURSOR c_garantias IS
       SELECT distinct trim(pg.descripcion) garantia
         FROM pr_garantias pr, pr_gar_tipos pg
        WHERE pr.cod_persona = p_cod_persona
          AND pr.estado IN ('C','V','T')
          AND pr.cod_garantia = pg.cod_garantia
          AND pg.computable = 'S';
   BEGIN
      FOR reg IN c_garantias LOOP
         IF v_tip_garantia IS NULL THEN
            v_tip_garantia := TRIM(reg.garantia);
         ELSE
            v_tip_garantia := substr((TRIM(v_tip_garantia)||';'||TRIM(reg.garantia)),240);
         END IF;
      END LOOP;

      RETURN v_tip_garantia;

   EXCEPTION
      WHEN OTHERS THEN
         v_tip_garantia := NULL;
         RETURN v_tip_garantia;
   END;

   -- Obtiene las garantias vencidas que posee la persona.
   FUNCTION fu_obt_gar_vencidas(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN VARCHAR2
   AS
   -- Variable.
   v_tip_garantia ge_sal_inv_vta_cartera_tmp.Gar_Cliente%type := NULL;

   -- Cursor.
   CURSOR c_garantias IS
       SELECT distinct trim(pg.descripcion) garantia
         FROM pr_garantias pr, pr_gar_tipos pg
        WHERE pr.cod_persona = p_cod_persona
          AND pr.estado = 'V'
          AND pr.cod_garantia = pg.cod_garantia
          AND pg.computable = 'S';
   BEGIN
      FOR reg IN c_garantias LOOP
         IF v_tip_garantia IS NULL THEN
            v_tip_garantia := TRIM(reg.garantia);
         ELSE
            v_tip_garantia := substr((TRIM(v_tip_garantia)||';'||TRIM(reg.garantia)),240);
         END IF;
      END LOOP;

      RETURN v_tip_garantia;

   EXCEPTION
      WHEN OTHERS THEN
         v_tip_garantia := NULL;
         RETURN v_tip_garantia;
   END;

   -- Obtiene el tipo de bloqueo que posee la cuenta.
   FUNCTION fu_obt_tip_bloqueo(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE)
   RETURN VARCHAR2
   AS
   -- Variable.
   v_tip_bloqueo ge_sal_inv_vta_cartera_tmp.tip_bloqueo%type := NULL;

   -- Cursor.
   CURSOR c_tip_bloqueo IS
      SELECT b.descripcion
        FROM ge_bloqueos a, ge_causales b
       WHERE a.cod_causa = b.cod_causa
         AND a.nro_cuenta = p_nro_cuenta;

   BEGIN
      FOR reg IN c_tip_bloqueo LOOP
         IF v_tip_bloqueo IS NULL THEN
            v_tip_bloqueo := TRIM(reg.descripcion);
         ELSE
            v_tip_bloqueo := substr((TRIM(v_tip_bloqueo)||';'||TRIM(reg.descripcion)),240);
         END IF;
      END LOOP;

      RETURN v_tip_bloqueo;

   EXCEPTION
      WHEN OTHERS THEN
         v_tip_bloqueo := NULL;
         RETURN v_tip_bloqueo;
   END;

   -- Obtiene el tipo de Inhibición que posee la persona.
   FUNCTION fu_obt_tip_inhibicion(p_cod_persona IN ge_clientes.cod_persona%TYPE)
   RETURN VARCHAR2
   AS
   -- Variable.
   v_tip_inhibicion ge_sal_inv_vta_cartera_tmp.tip_inhibicion%type := NULL;

   -- Cursor.
   CURSOR c_tip_inhibicion IS
      SELECT  b.descripcion
        FROM ge_per_inhibidas a, ge_causales b
       WHERE a.cod_causa = b.cod_causa
         AND a.cod_persona = p_cod_persona;

   BEGIN
      FOR reg IN c_tip_inhibicion LOOP
         IF v_tip_inhibicion IS NULL THEN
            v_tip_inhibicion := TRIM(reg.descripcion);
         ELSE
            v_tip_inhibicion := substr((TRIM(v_tip_inhibicion)||';'||TRIM(reg.descripcion)),240);
         END IF;
      END LOOP;

      RETURN v_tip_inhibicion;

   EXCEPTION
      WHEN OTHERS THEN
         v_tip_inhibicion := NULL;
         RETURN v_tip_inhibicion;
   END;

BEGIN
   -- Genera el inventario de acuerdo a los Parametros.
   FOR reg IN c_cta_clientes LOOP

      -- Seteo de variables.
      v_cli_nomina            := 'N';
      v_fec_pag_ult_nomina    := NULL;
      v_cod_afinidad          := NULL;
      v_nro_tarjeta           := NULL;
      v_des_afinidad          := NULL;
      v_can_cuotas            := NULL;
      v_can_cuo_vencidas      := NULL;
      v_nro_tel_particular    := NULL;
      v_nro_tel_laboral       := NULL;
      v_dir_principal         := NULL;
      v_dir_laboral           := NULL;
      v_tot_riesgo            := 0;

      -- Obtendo los datos de la tarjeta.
      IF reg.cod_modulo = 5 THEN
         BEGIN
            SELECT ta.afinidad, tt.nro_tarjeta
              INTO v_cod_afinidad, v_nro_tarjeta
              FROM ta_cta_tarjetas ta, ta_tarjetas tt
             WHERE ta.nro_cuenta = reg.nro_cuenta
               AND ta.nro_cuenta = tt.nro_cuenta
               --AND tt.vigente = 'S'
               AND rownum = 1;

            -- Obtengo el nombre de la afinidad.
            v_des_afinidad :=  fue_obt_sig_refcodes('AFINIDAD',v_cod_afinidad);

         EXCEPTION
            WHEN OTHERS THEN
               v_nro_tarjeta     := NULL;
               v_des_afinidad    := NULL;
         END;
      END IF;

      -- Agrego el monto a liquidar de las cuentas de sobregiro.
      IF reg.cod_modulo = 4 THEN
         BEGIN
            pac_sob.pr_pro_liq_sob(reg.nro_cuenta,'N',v_liq_imp_sobregiro,v_liq_int_sobregiro);
         EXCEPTION
            WHEN OTHERS THEN
               v_liq_imp_sobregiro := 0;
               v_liq_int_sobregiro := 0;
         END;

         -- Actualizo el importe de la deuda.
         v_mto_deuda := nvl(reg.tot_deu_real,0) + nvl(v_liq_imp_sobregiro,0) + nvl(v_liq_int_sobregiro,0);

      ELSE
         v_mto_deuda := nvl(reg.tot_deu_real,0);
      END IF;

      -- Obtengo el detalle de las cuentas de prestamos.
      IF reg.cod_modulo = 6 THEN
         BEGIN
            SELECT nvl(pr.can_cuotas,0), nvl(pr.can_cuotas,0) - nvl(pr.can_cuo_pagadas,0)
              INTO v_can_cuotas, v_can_cuo_vencidas
              FROM pr_cta_prestamos pr
             WHERE pr.nro_cuenta = reg.nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               v_can_cuotas := 0;
               v_can_cuo_vencidas := 0;
         END;
      END IF;

      -- Obtengo los datos de referencia del cliente.
      BEGIN
         SELECT bt.area||'-'||bt.telefono
           INTO v_nro_tel_particular
           FROM ba_telefonos bt
          WHERE bt.cod_persona = reg.cod_persona
            AND bt.principal = 'S';
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_tel_particular := NULL;
      END;
      --
      BEGIN
         SELECT bt.area||'-'||bt.telefono
           INTO v_nro_tel_laboral
           FROM ba_telefonos bt
          WHERE bt.cod_persona = reg.cod_persona
            AND bt.tipo = 'L'
            AND rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_nro_tel_laboral := NULL;
      END;
      --
      BEGIN
         SELECT trim(bd.direccion)
           INTO v_dir_principal
           FROM ba_direcciones bd
          WHERE bd.cod_persona = reg.cod_persona
            AND bd.principal = 'S';
      EXCEPTION
         WHEN OTHERS THEN
            v_dir_principal := NULL;
      END;
      --
      BEGIN
         SELECT trim(bd.direccion)
           INTO v_dir_laboral
           FROM ba_direcciones bd
          WHERE bd.cod_persona = reg.cod_persona
            AND bd.tipo = 'L'
            AND rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_dir_laboral := NULL;
      END;

      -- Obtengo el tipo de bloqueo de la cuenta.
      v_tip_bloqueo := fu_obt_tip_bloqueo(reg.nro_cuenta);

      -- Obtengo el riesgo total del cliente.
      v_tot_riesgo := fu_obt_mto_riesgo(reg.cod_persona);
      --dbms_output.put_line(reg.nro_cuenta);

           -- Se ajustan los datos
           UPDATE GE_SAL_INV_VTA_CARTERA_TMP
              SET mto_deuda            = v_mto_deuda,
                  mto_previsiones      = reg.tot_prevision,
                  dia_atrasos          = reg.dia_atraso,
                  cat_cliente          = reg.cat_riesgo,
                  tot_riesgo           = v_tot_riesgo,
                  fec_ult_cat_sistema  = reg.fec_ult_cla_sistema,
                  cat_sistema          = reg.cat_sistema,
                  tot_deu_sistema      = reg.tot_deu_sistema,
                  tot_deu_con_sistema  = reg.tot_deu_con_sistema,
                  tot_deu_cod_sistema  = reg.tot_deu_cod_sistema,
                  tot_cuotas           = v_can_cuotas,
                  tot_cuo_vencidas     = v_can_cuo_vencidas,
                  fecha                = v_fec_cambio
            where cod_persona   = reg.cod_persona
              and nro_cuenta    = reg.nro_cuenta
              and ref_lote      = P_REF_LOTE;

   END LOOP;

   -- Obtengo las garantias del cliente.
   FOR reg IN (SELECT distinct gs.cod_persona cod_persona
                 FROM ge_sal_inv_vta_cartera_tmp gs where gs.ref_lote = P_REF_LOTE) LOOP

      v_tip_garantias    := fu_obt_garantias(reg.cod_persona);
      v_tip_gar_vencidas := fu_obt_gar_vencidas(reg.cod_persona);
      v_tip_inhibicion   := fu_obt_tip_inhibicion(reg.cod_persona);
      --
      UPDATE ge_sal_inv_vta_cartera_tmp gs
         SET gs.gar_cliente = v_tip_garantias,
             gs.gar_ven_cliente = v_tip_gar_vencidas,
             gs.tip_inhibicion = v_tip_inhibicion
       WHERE gs.cod_persona = reg.cod_persona
         and gs.ref_lote    = P_REF_LOTE;
   END LOOP; 

   -- Obtengo los codeudores del cliente.
   FOR reg IN (SELECT distinct gs.nro_cuenta nro_cuenta
                 FROM ge_sal_inv_vta_cartera_tmp gs where gs.ref_lote = P_REF_LOTE) LOOP

       v_cod_per_codeudor := NULL;
       v_tip_gar_codeudor := NULL;
       v_tip_gar_ven_codeudor := NULL;

       -- Obtengo los codeudores de las cuentas.
       FOR reg_codeudores IN c_codeudores(reg.nro_cuenta) LOOP
           IF v_cod_per_codeudor IS NULL THEN
              v_cod_per_codeudor := reg_codeudores.cod_persona;
           ELSE
              v_cod_per_codeudor := TRIM(v_cod_per_codeudor)||';'||reg_codeudores.cod_persona;
           END IF;
           --
           IF v_tip_gar_codeudor IS NULL THEN
              v_tip_gar_codeudor :=  fu_obt_garantias(reg_codeudores.cod_persona);
           ELSE
              v_tip_gar_codeudor := TRIM(v_tip_gar_codeudor)||';'||fu_obt_garantias(reg_codeudores.cod_persona);
           END IF;
           --
           IF v_tip_gar_ven_codeudor IS NULL THEN
              v_tip_gar_ven_codeudor :=  fu_obt_gar_vencidas(reg_codeudores.cod_persona);
           ELSE
              v_tip_gar_ven_codeudor := TRIM(v_tip_gar_ven_codeudor)||';'||fu_obt_gar_vencidas(reg_codeudores.cod_persona);
           END IF;

       END LOOP;

       -- Actualizo los valores
       IF v_cod_per_codeudor IS NOT NULL THEN
          UPDATE ge_sal_inv_vta_cartera_tmp gs
             SET gs.cod_per_codeudor = v_cod_per_codeudor,
                 gs.gar_codeudor = v_tip_gar_codeudor,
                 gs.gar_ven_codeudor = v_tip_gar_ven_codeudor
           WHERE gs.nro_cuenta = reg.nro_cuenta
             and gs.ref_lote   = P_REF_LOTE;
       END IF;
   END LOOP;

END;
/

