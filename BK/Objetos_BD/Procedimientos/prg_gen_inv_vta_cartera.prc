CREATE OR REPLACE PROCEDURE IT.PRG_GEN_INV_VTA_CARTERA (P_PREVISION IN NUMBER,
                                                     P_NOMINA IN VARCHAR2,
                                                     P_DIA_DESDE IN NUMBER,
                                                     P_DIA_HASTA IN NUMBER,
                                                     P_GARANTIA IN VARCHAR2,
                                                     P_TIPOS IN VARCHAR2,
                                                     P_DEU_DESDE IN NUMBER,
                                                     P_DEU_HASTA IN NUMBER,
                                                     P_GRU_ECONOMICO IN VARCHAR2,
                                                     P_MODULO IN VARCHAR2,
                                                     P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
                                                     P_REF_LOTE IN NUMBER DEFAULT NULL,
                                                     P_CAN_GEN OUT NUMBER,
                                                     P_COD_PERSONA IN VARCHAR2 DEFAULT NULL,
                                                     P_TIP_LLAMADO IN VARCHAR2 DEFAULT NULL) IS

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
   v_ref_lote             ge_sal_inv_vta_cartera_tmp.ref_lote%type;
   v_fec_cambio           date := pag_cal.fu_obt_fec_anterior(1);
   v_tipo_operacion       varchar2(60) := NULL;
   v_control              number;

   -- Cursores.
   CURSOR c_cta_clientes IS
      SELECT ge.cod_persona
        FROM ge_cla_operaciones ge, ge_clientes gc, ba_personas ba, ge_modalidades bm, ge_cuentas g
       WHERE --------JOINS-------------------
             ge.cod_persona   = ba.cod_persona
         AND ge.cod_persona   = gc.cod_persona
         AND ge.cod_modulo    = bm.cod_modulo
         AND ge.cod_modalidad = bm.cod_modalidad
         AND ge.nro_cuenta    = g.nro_cuenta --solo para confirmar que las cuenta exista en el sistema
         ----CONTROL QUE YA NO EXISTA EN CARTERA---
         AND NOT EXISTS(SELECT 1 FROM ge_sal_inv_vta_cartera_tmp gs WHERE gs.nro_cuenta = ge.nro_cuenta)
         ------------FILTROS DE CARTERA------------
         and (P_COD_MONEDA is null or ge.cod_moneda = P_COD_MONEDA)
         and (P_COD_PERSONA is null or ba.cod_persona = P_COD_PERSONA)
         and ((INSTR(P_MODULO, '#4') <> 0 AND ge.cod_modulo = 4 AND g.estado not in('C', 'P', 'A', 'X'))
             or (INSTR(P_MODULO, '#5') <> 0 AND ge.cod_modulo = 5 AND g.estado not in('C', 'P'))
             or (INSTR(P_MODULO, '#6') <> 0 AND ge.cod_modulo = 6 AND g.estado not in('N', 'I'))
             or (INSTR(P_MODULO, '#15') <> 0 AND ge.cod_modulo = 15 AND g.estado not in('C', 'I')))
         and ((P_GARANTIA = 'N' and ge.cod_persona not in (select cod_persona from pr_garantias pr, pr_gar_tipos pg
               where pr.cod_persona = ge.cod_persona and pr.estado in ('C','V','I') and pr.cod_garantia = pg.cod_garantia
               and pg.computable = 'S')) or (P_GARANTIA = 'S'))
         and ((P_GRU_ECONOMICO = 'S') or (P_GRU_ECONOMICO = 'N' and gc.cod_gru_economico is null))
         and ((nvl(P_TIPOS, 'N') = 'N')
             or (nvl(P_TIPOS, 'N') <> 'N' and ge.cod_persona not in (select t.cod_persona from GE_PER_INHIBIDAS t, GE_CAUSALES r
               where t.cod_causa = r.cod_causa and t.estado = 'I' and t.cod_persona = ge.cod_persona and r.tipo = 'I' and INSTR(P_TIPOS,r.cod_causa) > 0))) --aplica los inhibidos
         and ((P_NOMINA = 'N' and (SELECT nvl(max(vg.fec_proceso),to_date('02/01/2000','dd/mm/yyyy')) FROM GV_PAGO_SUELDO vg
               WHERE vg.cliente = ge.cod_persona) < (pag_cal.FU_OBT_FEC_ACTUAL(1)-120)) --Es nomina porque la ultima acreditacion NO esta dentro de los ultimos 4 meses.
             or (P_NOMINA = 'S' and (SELECT nvl(max(vg.fec_proceso),to_date('02/01/2000','dd/mm/yyyy')) FROM GV_PAGO_SUELDO vg
               WHERE vg.cliente = ge.cod_persona) >= (pag_cal.FU_OBT_FEC_ACTUAL(1)-120))) --Es nomina porque la ultima acreditacion esta dentro de los ultimos 4 meses.
         and  P_TIP_LLAMADO = 'F'  -- Proceso por formulario
      GROUP BY ge.cod_persona
        HAVING sum(ge.tot_deu_real) >= nvl(P_DEU_DESDE, 1)
           AND sum(ge.tot_deu_real) <= nvl(P_DEU_HASTA, 999999999)
           AND max(ge.dia_atraso)   >= nvl(P_DIA_DESDE, 1)
           AND max(ge.dia_atraso)   <= nvl(P_DIA_HASTA, 99999)
           AND ((sum(nvl(ge.tot_prevision,0))/sum(ge.tot_deu_real))*100) >= P_PREVISION
         UNION ALL
      SELECT ge.cod_persona
        FROM ge_cla_operaciones ge, ge_clientes gc, ba_personas ba, ge_modalidades bm, ge_cuentas g,
             ge_inv_vta_cartera_tmp v
       WHERE ge.cod_persona   = ba.cod_persona
         AND ge.cod_persona   = gc.cod_persona
         AND ge.cod_modulo    = bm.cod_modulo
         AND ge.cod_modalidad = bm.cod_modalidad
         AND ge.nro_cuenta    = g.nro_cuenta --solo para confirmar que las cuenta exista en el sistema
         AND ge.cod_modulo    = v.cod_modulo
         AND ge.cod_modalidad = v.cod_modalidad
         AND ge.nro_cuenta    = v.nro_cuenta
         AND P_TIP_LLAMADO = 'P'  -- Proceso de importación
         ----CONTROL QUE YA NO EXISTA EN CARTERA---
         AND NOT EXISTS(SELECT 1 FROM ge_sal_inv_vta_cartera_tmp gs WHERE gs.nro_cuenta = ge.nro_cuenta)
         and ((INSTR(P_MODULO, '#4') <> 0 AND ge.cod_modulo = 4 AND g.estado not in('C', 'P', 'A', 'X'))
             or (INSTR(P_MODULO, '#5') <> 0 AND ge.cod_modulo = 5 AND g.estado not in('C', 'P'))
             or (INSTR(P_MODULO, '#6') <> 0 AND ge.cod_modulo = 6 AND g.estado not in('N', 'I'))
             or (INSTR(P_MODULO, '#15') <> 0 AND ge.cod_modulo = 15 AND g.estado not in('C', 'I')))         ;

   CURSOR c_dat_cta_clientes(p_cod_persona IN ge_clientes.cod_persona%TYPE) IS
      SELECT ge.cod_persona, ba.nom_completo nom_persona, ba.nro_documento, ge.cod_oficina, ge.nro_cuenta, bm.descripcion tipo_operacion,
             gc.cod_usu_oficial||' - '||fue_obt_nom_usuario(gc.cod_usu_oficial) gestor, ge.tot_deu_real, ge.tot_deu_contingente,
             ge.tot_prevision, ge.dia_atraso, gc.cat_riesgo, gc.fec_ult_cla_sistema, gc.cat_sistema, gc.tot_deu_sistema,
             gc.tot_deu_con_sistema, gc.tot_deu_cod_sistema, ge.cod_modulo, ge.cod_modalidad, g.cod_moneda
        FROM ge_cla_operaciones ge, ge_clientes gc, ba_personas ba, ge_modalidades bm, ge_cuentas g
       WHERE ge.cod_persona   = ba.cod_persona
         AND ge.cod_persona   = gc.cod_persona
         AND ge.cod_modulo    = bm.cod_modulo
         AND ge.cod_modalidad = bm.cod_modalidad
         AND ge.nro_cuenta    = g.nro_cuenta --(solo para confirmar que las cuenta exista en el sistema)
         AND ge.cod_persona   = p_cod_persona --conexion con el primer cursor
         AND ((INSTR(P_MODULO, '#4') <> 0 AND ge.cod_modulo = 4)
             or (INSTR(P_MODULO, '#5') <> 0 AND ge.cod_modulo = 5)
             or (INSTR(P_MODULO, '#6') <> 0 AND ge.cod_modulo = 6)
             or (INSTR(P_MODULO, '#15') <> 0 AND ge.cod_modulo = 15))
         AND NOT EXISTS(SELECT 1 FROM ge_sal_inv_vta_cartera_tmp gs WHERE gs.nro_cuenta = ge.nro_cuenta)
         and  P_TIP_LLAMADO = 'F'
         UNION ALL
      SELECT ge.cod_persona, ba.nom_completo nom_persona, ba.nro_documento, ge.cod_oficina, ge.nro_cuenta, bm.descripcion tipo_operacion,
             gc.cod_usu_oficial||' - '||fue_obt_nom_usuario(gc.cod_usu_oficial) gestor, ge.tot_deu_real, ge.tot_deu_contingente,
             ge.tot_prevision, ge.dia_atraso, gc.cat_riesgo, gc.fec_ult_cla_sistema, gc.cat_sistema, gc.tot_deu_sistema,
             gc.tot_deu_con_sistema, gc.tot_deu_cod_sistema, ge.cod_modulo, ge.cod_modalidad, g.cod_moneda
        FROM ge_cla_operaciones ge, ge_clientes gc, ba_personas ba, ge_modalidades bm, ge_cuentas g,
             ge_inv_vta_cartera_tmp v
       WHERE ge.cod_persona   = ba.cod_persona
         AND ge.cod_persona   = gc.cod_persona
         AND ge.cod_modulo    = bm.cod_modulo
         AND ge.cod_modalidad = bm.cod_modalidad
         AND ge.nro_cuenta    = g.nro_cuenta --solo para confirmar que las cuenta exista en el sistema
         AND ge.cod_modulo    = v.cod_modulo
         AND ge.cod_modalidad = v.cod_modalidad
         AND ge.nro_cuenta    = v.nro_cuenta
         AND NOT EXISTS(SELECT 1 FROM ge_sal_inv_vta_cartera_tmp gs WHERE gs.nro_cuenta = ge.nro_cuenta)
         AND P_TIP_LLAMADO = 'P'
         AND ((INSTR(P_MODULO, '#4') <> 0 AND ge.cod_modulo = 4)
             or (INSTR(P_MODULO, '#5') <> 0 AND ge.cod_modulo = 5)
             or (INSTR(P_MODULO, '#6') <> 0 AND ge.cod_modulo = 6)
             or (INSTR(P_MODULO, '#15') <> 0 AND ge.cod_modulo = 15));

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
         AND a.cod_persona = p_cod_persona
         and a.estado = 'I';
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

   -- Convertir un monto a guaraníes.
   FUNCTION fu_con_a_guaranies ( p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                                 p_monto      IN pr_cta_prestamos.mto_capital%TYPE ) RETURN NUMBER IS
      v_cotizacion  ge_cotizaciones.val_conversion%TYPE;
      v_deuda_gs    NUMBER(18);
      v_mon_fuerte  ge_par_generales.cod_mon_fuerte%TYPE;
      v_mon_local   ge_par_generales.cod_mon_local%TYPE;
   BEGIN
      SELECT cod_mon_local, cod_mon_fuerte INTO v_mon_local, v_mon_fuerte FROM ge_par_generales;
      IF p_cod_moneda = v_mon_fuerte THEN
         -- la moneda es Dolares -----------------------------------
         v_deuda_gs := nvl(p_monto, 0) * pag_gen.fu_obt_cotizacion(v_mon_fuerte, v_fec_cambio);
      ELSIF p_cod_moneda <> v_mon_local THEN
         -- moneda diferente a dolares y local ---------------------
         v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, v_fec_cambio);
         v_deuda_gs   := nvl(p_monto, 0) * v_cotizacion;
      ELSE
         -- es moneda local - guaraníes ----------------------------
         v_deuda_gs := p_monto;
      END IF;
      RETURN v_deuda_gs;
   END;

BEGIN

   --Cargo el nuevo numero de ref_lote
   IF P_REF_LOTE IS NULL THEN
     select s_lote_vta_cartera.nextval into v_ref_lote from dual;
   ELSIF P_REF_LOTE IS NOT NULL THEN
     v_ref_lote := P_REF_LOTE;
     --se carga en tabla las cuentas que estaban inicialmente en el lote a regenerar (esta tabla al final de este proceso se volvera a limpiar)
     --esto para luego comparar con lo generado al día, y no incluir nuevos pero si excluir lo que ya no cumplan
     insert into pr_vta_cartera
       select cod_persona, nro_cuenta, 'N' from ge_sal_inv_vta_cartera_tmp r where r.ref_lote = P_REF_LOTE;
     --eliminamos el lote a regenerar de la tabla TMP
     delete from ge_sal_inv_vta_cartera_tmp r where r.ref_lote = P_REF_LOTE;
     delete from ge_fil_vta_cartera r where r.ref_lote = P_REF_LOTE;
   END IF;

   -- En el primer Loop prepara los clientes que cumplen los filtros, luego carga las cuentas en un segundo Loop
   FOR reg IN c_cta_clientes LOOP
     --si es regeneracion controla que haya estado en la cartera anteriormente
     select nvl(count(*), 0) into v_control from pr_vta_cartera where cod_persona = reg.cod_persona;
     if P_REF_LOTE IS NULL or (P_REF_LOTE IS NOT NULL and v_control > 0) then
        -- Seteo de variables.
        v_nro_tel_particular    := NULL;
        v_nro_tel_laboral       := NULL;
        v_dir_principal         := NULL;
        v_dir_laboral           := NULL;
        v_tot_riesgo            := 0;

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

        -- Obtengo el riesgo total del cliente.
        v_tot_riesgo := fu_obt_mto_riesgo(reg.cod_persona);

        -- Inserto todas las cuentas del cliente.
        FOR reg1 IN c_dat_cta_clientes(reg.cod_persona) LOOP
            -- Seteo de variables.
            v_cli_nomina            := 'N';
            v_fec_pag_ult_nomina    := to_date('01/01/1900','dd/mm/yyyy');
            v_cod_afinidad          := NULL;
            v_nro_tarjeta           := NULL;
            v_des_afinidad          := NULL;
            v_can_cuotas            := NULL;
            v_can_cuo_vencidas      := NULL;

            if reg1.cod_modulo = 6 THEN
               BEGIN
                  SELECT pe.descripcion
                    INTO v_tipo_operacion
                    FROM pr_cta_prestamos pr, pr_rub_economicos pe
                   WHERE pr.nro_cuenta = reg1.nro_cuenta
                     AND pr.cod_rub_economico = pe.cod_rub_economico;
               EXCEPTION
                 WHEN OTHERS THEN
                   v_tipo_operacion := reg1.tipo_operacion;
               END;
            else
               v_tipo_operacion := reg1.tipo_operacion;
            end if;

            -- Verifica si es Cliente Nomina.
            BEGIN
               SELECT 'S', nvl(vg.fec_proceso,to_date('01/01/1900','dd/mm/yyyy'))
                 INTO v_cli_nomina, v_fec_pag_ult_nomina
                 FROM GV_PAGO_SUELDO vg
                WHERE vg.cliente = reg1.cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cli_nomina := 'N';
                  v_fec_pag_ult_nomina := to_date('01/01/1900','dd/mm/yyyy');
            END;

            -- Obtendo los datos de la tarjeta.
            IF reg1.cod_modulo = 5 THEN
               BEGIN
                  SELECT ta.afinidad, tt.nro_tarjeta
                    INTO v_cod_afinidad, v_nro_tarjeta
                    FROM ta_cta_tarjetas ta, ta_tarjetas tt
                   WHERE ta.nro_cuenta = reg1.nro_cuenta
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
            IF reg1.cod_modulo = 4 THEN
               BEGIN
                  pac_sob.pr_pro_liq_sob(reg1.nro_cuenta,'N',v_liq_imp_sobregiro,v_liq_int_sobregiro);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_liq_imp_sobregiro := 0;
                     v_liq_int_sobregiro := 0;
               END;
               v_liq_imp_sobregiro := fu_con_a_guaranies(reg1.cod_moneda, v_liq_imp_sobregiro);
               v_liq_int_sobregiro := fu_con_a_guaranies(reg1.cod_moneda, v_liq_int_sobregiro);
               -- Actualizo el importe de la deuda.
               v_mto_deuda := nvl(reg1.tot_deu_real,0) + nvl(v_liq_imp_sobregiro,0) + nvl(v_liq_int_sobregiro,0);

            ELSE
               v_mto_deuda := nvl(reg1.tot_deu_real,0);
            END IF;

            -- Obtengo el detalle de las cuentas de prestamos.
            IF reg1.cod_modulo = 6 THEN
               BEGIN
                  SELECT nvl(pr.can_cuotas,0), nvl(pr.can_cuotas,0) - nvl(pr.can_cuo_pagadas,0)
                    INTO v_can_cuotas, v_can_cuo_vencidas
                    FROM pr_cta_prestamos pr
                   WHERE pr.nro_cuenta = reg1.nro_cuenta;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_can_cuotas := 0;
                     v_can_cuo_vencidas := 0;
               END;
            END IF;

            -- Obtengo el tipo de bloqueo de la cuenta.
            v_tip_bloqueo := fu_obt_tip_bloqueo(reg1.nro_cuenta);

            -- Inserto el registro.
            begin
              INSERT INTO ge_sal_inv_vta_cartera_tmp(fecha, cod_persona, nom_completo, nro_documento, cli_nomina, fec_ult_acreditacion,
                                                     cod_oficina, nro_cuenta, tip_producto, nro_tarjeta, afinidad, cod_per_codeudor,
                                                     gestor, mto_deuda, mto_previsiones, dia_atrasos, cat_cliente,
                                                     tot_riesgo, fec_ult_cat_sistema, cat_sistema, tot_deu_sistema,
                                                     tot_deu_con_sistema, tot_deu_cod_sistema, tot_cuotas, tot_cuo_vencidas,
                                                     tel_particular, dir_particular, tel_laboral, dir_laboral,gar_cliente,gar_ven_cliente,
                                                     gar_codeudor,tip_bloqueo,tip_inhibicion,cod_modulo,cod_modalidad, ref_lote)
                   VALUES(v_fec_cambio, reg1.cod_persona, reg1.nom_persona, reg1.nro_documento, v_cli_nomina, v_fec_pag_ult_nomina,
                          reg1.cod_oficina, reg1.nro_cuenta, v_tipo_operacion, v_nro_tarjeta, v_des_afinidad, null,
                          reg1.gestor, v_mto_deuda, reg1.tot_prevision, reg1.dia_atraso, reg1.cat_riesgo,
                          v_tot_riesgo, reg1.fec_ult_cla_sistema, reg1.cat_sistema, reg1.tot_deu_sistema,
                          reg1.tot_deu_con_sistema, reg1.tot_deu_cod_sistema, v_can_cuotas, v_can_cuo_vencidas,
                          v_nro_tel_particular, v_dir_principal, v_nro_tel_laboral, v_dir_laboral,null,null,null,
                          v_tip_bloqueo,null,reg1.cod_modulo,reg1.cod_modalidad, v_ref_lote);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Insercion de cuentas: '||reg1.nro_cuenta||' '||sqlerrm);
            END;
        END LOOP;
     end if;
   END LOOP;

   -- Obtengo las garantias del cliente.
   FOR reg IN (SELECT distinct gs.cod_persona cod_persona
                 FROM ge_sal_inv_vta_cartera_tmp gs where gs.ref_lote = v_REF_LOTE) LOOP

      v_tip_garantias    := fu_obt_garantias(reg.cod_persona);
      v_tip_gar_vencidas := fu_obt_gar_vencidas(reg.cod_persona);
      v_tip_inhibicion   := fu_obt_tip_inhibicion(reg.cod_persona);
      --
      UPDATE ge_sal_inv_vta_cartera_tmp gs
         SET gs.gar_cliente = v_tip_garantias,
             gs.gar_ven_cliente = v_tip_gar_vencidas,
             gs.tip_inhibicion = v_tip_inhibicion
       WHERE gs.cod_persona = reg.cod_persona
         AND gs.ref_lote    = v_REF_LOTE;

   END LOOP;

   -- Obtengo los codeudores del cliente.
   FOR reg IN (SELECT distinct gs.nro_cuenta nro_cuenta
                 FROM ge_sal_inv_vta_cartera_tmp gs WHERE gs.ref_lote = v_REF_LOTE) LOOP

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
             AND gs.ref_lote   = v_REF_LOTE;
       END IF;
   END LOOP;

   SELECT COUNT(1) INTO P_CAN_GEN FROM GE_SAL_INV_VTA_CARTERA_TMP WHERE REF_LOTE = v_REF_LOTE;

   --Se guardan los filtros en su tabla
   IF P_CAN_GEN > 0 THEN
     begin
         INSERT INTO GE_FIL_VTA_CARTERA
        VALUES(v_REF_LOTE,
               P_PREVISION,
               P_NOMINA,
               P_DIA_DESDE,
               P_DIA_HASTA,
               P_GARANTIA,
               P_TIPOS,
               P_DEU_DESDE,
               P_DEU_HASTA,
               P_GRU_ECONOMICO,
               P_MODULO,
               P_COD_MONEDA );
     exception
         when others then
            raise_application_error(-20000, 'Insercion de filtros. '||sqlerrm);
     end;
   END IF;

   --se limpia la tabla con las cuentas para regeneracion
   DELETE PR_VTA_CARTERA PV WHERE UPPER(PV.TIPO_DEUDA) = 'N';
END;
/

