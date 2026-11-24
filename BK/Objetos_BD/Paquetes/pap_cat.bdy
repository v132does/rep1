CREATE OR REPLACE PACKAGE BODY IT.pap_cat IS

   v_min_exigido             NUMBER(18);
   v_por_cap_min_exigido     pr_parametros.por_cap_min_exigido%TYPE;
   v_por_cap_min_exi_sistema pr_parametros.por_cap_min_exi_sistema%TYPE;
   v_sal_minimo              NUMBER(18);
   -- NGRANCE - Resolucion N? 37
   v_riesgo1a pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b pr_parametros.por_riesgo_1b%TYPE;
   --
   v_riesgo2 pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3 pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4 pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5 pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6 pr_parametros.por_riesgo_6%TYPE;
   v_cod_gru_eco_entidad ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD');

   v_nro_cta_madre pr_cta_prestamos.nro_cuenta%type;
   v_mto_cap_cobrado_aux     pr_cuotas.mto_capital%TYPE;

   /*Retorna la Sub-Categoria de la Categoria 1.*/
   FUNCTION fu_obt_sub_categoria
   (
      p_cod_persona IN ge_clientes.cod_persona%TYPE,
      p_fecha       IN DATE DEFAULT NULL

   ) RETURN VARCHAR2 IS
      v_cat_crc VARCHAR2(3);
   BEGIN
      --Tomar las sub-categorías 1.1 y 1.2
      BEGIN
         BEGIN
            IF p_fecha IS NOT NULL THEN
               --Verifico las operaciones que posee el cliente a una Fecha.
               SELECT nvl(MAX(a.cat_automatica), 1)
                 INTO v_cat_crc
                 FROM ge_cla_operaciones_his a
                WHERE a.cod_persona = p_cod_persona
                  AND a.fecha = p_fecha;
            ELSE
               --Verifico las operaciones que posee el cliente en el momento.
               SELECT nvl(MAX(a.cat_automatica), 1)
                 INTO v_cat_crc
                 FROM ge_cla_operaciones a
                WHERE a.cod_persona = p_cod_persona;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_cat_crc := 1;
         END;

         IF v_cat_crc = 1.1 THEN
            v_cat_crc := '1A';
         ELSIF v_cat_crc > 1.1 THEN
            v_cat_crc := '1B';
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            v_cat_crc := 1;
      END;

      RETURN v_cat_crc;

   EXCEPTION
      WHEN OTHERS THEN
         v_cat_crc := 1;
         RETURN v_cat_crc;
   END;

   /* Verificar si un cliente es de solo consumo. */
    FUNCTION fu_cli_solo_consumo(p_cod_clie IN ge_clientes.cod_persona%TYPE)
      RETURN VARCHAR2 IS
          v_resultado VARCHAR2(1) := 'S';
          v_count NUMBER := 0;
      BEGIN
          -- Verificar si el cliente tiene operaciones con cod_sec_credito no permitidos
          SELECT COUNT(1)
            INTO v_count
            FROM ge_cla_operaciones a
           WHERE a.cod_persona = p_cod_clie
             AND a.cod_sec_credito NOT IN (701, 702, 703, 704, 705);

          IF v_count > 0 THEN
              RETURN 'N';
          END IF;

          -- Verificar si el cliente tiene operaciones
          SELECT COUNT(1)
            INTO v_count
            FROM ge_cla_operaciones a
           WHERE a.cod_persona = p_cod_clie
             AND EXISTS (SELECT 1
                           FROM ge_par_dinamicos p
                          WHERE p.cod_modulo = a.cod_modulo
                            AND p.cod_modalidad = a.cod_modalidad
                            AND p.val_parametro = 'S'
                            AND p.parametro = 'PRE_CAT_MAD_MESA');

          IF v_count > 0 THEN
              RETURN 'N';
          END IF;
          RETURN v_resultado; -- Si no encuentra en ninguna de las condiciones, devuelve 'S'
      END;
   /* Obtener deuda total bruto del cliente */
    --Agregado por Adolfo 19/03/2021
   FUNCTION fu_cli_obt_deu_real_total (p_cod_clie IN ge_clientes.cod_persona%TYPE) RETURN NUMBER IS
      v_res_deuda  NUMBER(18,2) := 0;
    BEGIN
      begin
        select SUM(nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0))
          INTO v_res_deuda
          FROM ge_cla_operaciones s
         WHERE s.cod_persona = p_cod_clie
         GROUP BY cod_persona
        HAVING SUM(nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) > 0;

      exception
        when no_data_found then
           RETURN v_res_deuda;
      end;

    --v_res_deuda := NVL(v_res_deuda, 0);
    RETURN v_res_deuda;
   END;
   --Obtiene la deuda de Medidas Excepcionales.
   FUNCTION fu_cli_obt_deu_mtrrr (p_nro_cuenta IN ge_cla_operaciones.nro_cuenta%TYPE) RETURN NUMBER IS
      v_res_deuda  NUMBER(18,2) := 0;
   BEGIN
     BEGIN
      SELECT SUM(nvl(tot_deu_real, 0))
        INTO v_res_deuda
        FROM ge_cla_operaciones s
       WHERE s.nro_cuenta in
             (select mm.val_parametro
                from ge_cta_dat_adicionales mm
               where mm.parametro in ('PRE_RRR_CTA_MBT',
                                      'PRE_RRR_CTA_MBT1',
                                      'PRE_RRR_CTA_MBT2')
                 and mm.nro_cuenta = p_nro_cuenta);
     exception
        when no_data_found then
           v_res_deuda := null;
      end;

    v_res_deuda := NVL(v_res_deuda, 0);
    RETURN v_res_deuda;
   END;

   --Obtiene la contingencia de Medidas Excepcionales.
   FUNCTION fu_cli_obt_con_mtrrr (p_nro_cuenta IN ge_cla_operaciones.nro_cuenta%TYPE) RETURN NUMBER IS
      v_res_deuda  NUMBER(18,2) := 0;
   BEGIN
    SELECT SUM(nvl(tot_deu_contingente, 0))
      INTO   v_res_deuda
        FROM ge_cla_operaciones s
        WHERE s.nro_cuenta in (select mm.val_parametro
                                 from ge_cta_dat_adicionales mm
                                where mm.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and mm.nro_cuenta = p_nro_cuenta);

    v_res_deuda := NVL(v_res_deuda, 0);
    RETURN v_res_deuda;
   END;

   --Obtiene la deuda de Medidas Excepcionales.
   FUNCTION fu_cli_obt_cat_mtrrr (p_nro_cuenta IN ge_cla_operaciones.nro_cuenta%TYPE) RETURN NUMBER IS
      v_cat_automatica  ge_cla_operaciones.cat_automatica%type := 0;
   BEGIN
    SELECT NVL(MAX(s.cat_automatica),1)
      INTO   v_cat_automatica
        FROM ge_cla_operaciones s
        WHERE s.nro_cuenta in (select mm.val_parametro
                                 from ge_cta_dat_adicionales mm
                                where mm.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and mm.nro_cuenta = p_nro_cuenta);

    RETURN v_cat_automatica;
   END;
   /* Verificar si un cliente es de solo vivienda. */
     FUNCTION fu_cli_solo_vivienda(p_cod_clie IN ge_clientes.cod_persona%TYPE)
     RETURN VARCHAR2 IS
     v_resultado VARCHAR2(1) := 'S';
     --v_cantidad  NUMBER(8);
   BEGIN
     BEGIN
       SELECT DISTINCT 'N'
         INTO v_resultado
         FROM ta_cta_tarjetas a, ge_cta_clientes b
        WHERE a.nro_cuenta = b.nro_cuenta
          AND b.cod_persona = p_cod_clie
          AND a.estado <> 'C';
     EXCEPTION
       WHEN NO_DATA_FOUND THEN--si no encuentra, busca en prestamos
         BEGIN
           SELECT DISTINCT 'N'
             INTO v_resultado
             FROM pr_cta_prestamos a, ge_cta_clientes b
            WHERE a.nro_cuenta = b.nro_cuenta
              AND b.cod_persona = p_cod_clie
              AND a.cod_sec_credito not in (702, 703)
              AND a.estado not in ('N', 'I');
         EXCEPTION
           WHEN NO_DATA_FOUND THEN--si no encuentra, busca en operaciones vencidas
             BEGIN
               SELECT DISTINCT 'N'
                 INTO v_resultado
                 FROM ov_cta_vencidas a, ge_cta_clientes b
                WHERE a.nro_cuenta = b.nro_cuenta
                  AND b.cod_persona = p_cod_clie
                  AND a.estado not in ('N', 'I');
		 EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  BEGIN
                       SELECT DISTINCT 'N'
						INTO v_resultado
						FROM CC_CTA_CORRIENTES a, ge_cta_clientes b   --> FIELDESK-158518 Modalidad 41 Sobregiros
						WHERE a.nro_cuenta = b.nro_cuenta
						  AND b.cod_persona = p_cod_clie
						  AND a.estado not in ('A','X', 'C');
				  EXCEPTION
					 WHEN NO_DATA_FOUND THEN
						 return v_resultado;--si no encuentra en ninguno, es solo vivienda
				  END;
             END;
         END;
     END;
     RETURN v_resultado;
   END;
   /* Convertir un monto a guaranies. */
   FUNCTION fu_con_a_guaranies
   (
      p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
      p_monto      IN pr_cta_prestamos.mto_capital%TYPE
   ) RETURN NUMBER IS
      v_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_deuda_gs   NUMBER(18);
   BEGIN
      IF p_cod_moneda = v_mon_fuerte THEN
         -- la moneda es Dolares -----------------------------------
         v_deuda_gs := nvl(p_monto, 0) * v_cot_mon_fuerte;
      ELSIF p_cod_moneda <> v_mon_local THEN
         -- moneda diferente a dolares y local ------------------------
         v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, v_fec_proceso);
         v_deuda_gs   := nvl(p_monto, 0) * v_cotizacion;
      ELSE
         -- es moneda local - guaranies -------------------------------
         v_deuda_gs := p_monto;
      END IF;
      RETURN v_deuda_gs;
   END;
   /* Obtener la categoria que le corresponde x mora. */
   FUNCTION fu_obt_categ_x_mora(p_can_dias IN NUMBER) RETURN NUMBER IS
      v_cat_mora ge_cla_operaciones.cat_automatica%TYPE := 1;
   BEGIN
      IF v_tipo_clie IN ('G', 'R', 'M') THEN
         -- comerciales mayores
         --- tipo de cliente comercial ----
         -- NGRANCE - Resolucion N?37
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2; --- riesgo normal    ---
            --
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2; --- riesgo potencial ---
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 3; --- riesgo real      ---
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 4; --- alto riesgo      ---
         ELSIF p_can_dias <= 270 THEN
            v_cat_mora := 5; --- alto riesgo      ---
         ELSE
            v_cat_mora := 6; --- irrecuperable    ---
         END IF;
      ELSIF v_tipo_clie IN ('N', 'C', 'P') THEN
         --- tipo de cliente personal, y comercial menor
         -- NGRANCE - Resolucion N?37
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2; --- riesgo normal    ---
            --
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2; --- riesgo potencial ---
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 3; --- riesgo real      ---
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 4; --- alto riesgo      ---
         ELSIF p_can_dias <= 270 THEN
            v_cat_mora := 5; --- alto riesgo      ---
         ELSE
            v_cat_mora := 6; --- irrecuperable    ---
         END IF;
      ELSIF v_tipo_clie IN ('V') THEN
         --- tipo de cliente personal, y comercial menor
         -- NGRANCE - Resolucion N?37
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1; --- riesgo normal    ---
            --
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 2; --- riesgo potencial ---
         ELSIF p_can_dias <= 210 THEN
            v_cat_mora := 3; --- riesgo real      ---
         ELSIF p_can_dias <= 270 THEN
            v_cat_mora := 4; --- alto riesgo      ---
         ELSIF p_can_dias <= 330 THEN
            v_cat_mora := 5; --- alto riesgo      ---
         ELSE
            v_cat_mora := 6; --- irrecuperable    ---
         END IF;
      ELSIF v_tipo_clie = 'T' THEN
         -- microcredito
         -- NGRANCE - Resolucion N?37
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1;
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1;
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2;
            --
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2;
         ELSIF p_can_dias <= 120 THEN
            v_cat_mora := 3;
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 4;
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 5;
         ELSE
            v_cat_mora := 6;
         END IF;
      END IF;
      RETURN v_cat_mora;
   END;

   -- Requerimiento: CNFAIRUNO-3.
   -- Fecha: 22/09/2014.
   /* Obtiene el código de actividad primaria del cliente. */
   FUNCTION fu_obt_cod_actividad(p_cod_persona IN ge_clientes.cod_persona%TYPE)
      RETURN NUMBER IS
      v_cod_actividad ba_personas.cod_actividad%type;
   BEGIN
      SELECT (CASE WHEN NVL(ba.cod_actividad,701) = 702 THEN 701 ELSE NVL(ba.cod_actividad,701) END)
        INTO v_cod_actividad
        FROM ba_personas ba
       WHERE ba.cod_persona = p_cod_persona;

      RETURN v_cod_actividad;
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_actividad := 701;
         RETURN v_cod_actividad;
   END;

   -- Requerimiento: CNFAIRUNO-3.
   -- Fecha: 22/09/2014.
   /*Retorna el destino de la operación.*/
   FUNCTION fu_obt_tip_destino
   (
      p_cod_persona   IN ge_cla_operaciones.cod_persona%TYPE,
      p_cod_modulo    IN ge_cla_operaciones.cod_modulo%TYPE,
      p_cod_modalidad IN ge_cla_operaciones.cod_modalidad%TYPE,
      p_cod_actividad IN ge_cla_operaciones.cod_sec_credito%TYPE,
      p_tot_deuda     IN ge_cla_operaciones.tot_deu_real%TYPE

   ) RETURN VARCHAR2 IS
   -- Variable para retorno.
   v_tip_destino pr_cta_prestamos.tip_destino%type;
   -- Variables axiliares.
   v_sal_minimo pr_parametros.sal_min_vigente%type;
   v_min_exigido pr_parametros.cap_min_exigido%type;
   v_es_fisica varchar2(01);
   BEGIN
      SELECT nvl(sal_min_vigente,0), nvl(round(cap_min_exigido*(por_cap_min_exigido/100),0),0)
        INTO v_sal_minimo, v_min_exigido
        FROM pr_parametros;
        v_es_fisica := pag_gen.FU_ES_PER_FISICA(p_cod_persona);
        IF v_es_fisica = 'O' THEN
           v_es_fisica := 'S';
        END IF;
        -- Valor por defecto.
        v_tip_destino := 4; -- Consumo
        -- Calcular tipo destino en base al monto solicitado.
        IF p_tot_deuda > v_min_exigido THEN --4% del Min.Exig.
           v_tip_destino := 1; -- Grandes Deudores
           IF p_cod_actividad = '701' THEN
              v_tip_destino := 4;
           END IF;
        ELSIF p_tot_deuda > (v_sal_minimo * 25) AND p_cod_actividad <> '701' THEN
           v_tip_destino := 2; -- Pequeños Deudores
        ELSIF  p_cod_actividad = '701' THEN
           v_tip_destino := 4; -- Consumo
           IF v_es_fisica <> 'S' THEN
              v_tip_destino := 2; -- Pequeños Deudores
           END IF;
        ELSE
           v_tip_destino := 5; -- Microcrédito.
           IF v_es_fisica <> 'S' THEN
              v_tip_destino := 2; -- Pequeños Deudores
           END IF;
        END IF;
        -- Vivienda.
        IF p_cod_modulo = 6 THEN
           IF (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS',6,p_cod_modalidad), 'N') = 'S'
              OR nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES',6,p_cod_modalidad), 'N') = 'S') THEN
                 v_tip_destino := 3;
           END IF;
        END IF;
        RETURN v_tip_destino;
   EXCEPTION
      WHEN OTHERS THEN
         v_tip_destino := 4;
         RETURN v_tip_destino;
   END;

   /* Obtiene el valor total de la garantia de un cliente. */
   FUNCTION fu_obt_tot_gar_clie
   (
      p_cod_clie  IN ge_clientes.cod_persona%TYPE,
      p_tot_deuda IN pr_cta_prestamos.mto_capital%TYPE
   ) RETURN NUMBER IS
      v_val_gara   NUMBER(18, 2) := 0;
      v_tot_gara   NUMBER(18, 2) := 0;
      v_val_tasac  NUMBER(18, 2) := 0;
      v_gar_compu  NUMBER(18, 2) := 0;
      v_cat_riesgo ge_clientes.cat_riesgo%TYPE;
      --WW_VLVTARA NUMBER(18,2) := 0;
      CURSOR garantias IS
         SELECT a.cod_moneda      ga_cdmoned,
                a.val_tasacion    ga_vltasac,
                a.valor           ga_vlgaran,
                b.por_bco_central tg_porcbcp,
                a.cod_garantia    ga_cdgaran
           FROM pr_gar_tipos b, pr_garantias a
          WHERE cod_persona = p_cod_clie
            AND a.cod_garantia = b.cod_garantia
            AND b.computable = 'S';
   BEGIN
      BEGIN
         SELECT cat_riesgo INTO v_cat_riesgo FROM ge_clientes WHERE cod_persona = p_cod_clie;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Cliente ' || p_cod_clie || ' no registrado');
      END;
      FOR reg IN garantias LOOP
         v_val_tasac := fu_con_a_guaranies(reg.ga_cdmoned, reg.ga_vltasac);
         v_val_gara  := fu_con_a_guaranies(reg.ga_cdmoned, reg.ga_vlgaran);
         --- acumulo las garantias computables del cliente ---------
         v_gar_compu := nvl(v_val_tasac, 0) * nvl(reg.tg_porcbcp, 0) / 100;
         IF v_gar_compu > v_val_gara THEN
            v_gar_compu := v_val_gara;
         END IF;
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      END LOOP;
      IF v_tot_gara > p_tot_deuda THEN
         v_tot_gara := p_tot_deuda;
      END IF;
      RETURN v_tot_gara;
   END;

   procedure pr_ins_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
   is pragma autonomous_transaction;
   begin
     insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
     values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PAP_CAT.PR_PRO_CAT_RES37',p_cod_proceso, p_hor_ini, p_hor_fin);
     commit;
   exception
     when others then null;
   end;

procedure pr_ins_dat_tarjetas is
begin
  begin
      insert into it.GE_CLA_OPERACIONES b
        (b.cod_persona,
         b.nro_cuenta,
         b.cod_modulo,
         b.cod_modalidad,
         b.cod_estado,
         b.tot_deu_real,
         b.tot_deu_contingente,
         b.dev_no_cobrado,
         b.cat_automatica,
         b.dia_atraso,
         b.cod_moneda,
         b.tot_gar_computables,
         b.cod_oficina,
         b.tipo,
         b.tot_prevision,
         b.mto_original,
         b.tip_destino,
         b.cod_sec_credito,
         b.cat_renovaciones,
         b.cat_ren_anterior,
         b.lib_prevision,
         b.tot_pri_prevision,
         b.cod_rub_economico,
         b.tot_cap_pri_prevision,
         b.tot_cap_seg_prevision,
         b.tot_int_pri_prevision,
         b.tot_int_seg_prevision,
         b.mto_pre_total,
         b.cat_pre_diferida,
         b.cat_prevision,
         b.tot_seg_prevision,
         b.tot_gar_aplicada,
         b.tot_rie_no_cubierto)
      select a.cod_persona,
             a.nro_cuenta,
             a.cod_modulo,
             a.cod_modalidad,
             a.cod_estado,
             a.tot_deu_real,
             a.tot_deu_contingente,
             a.dev_no_cobrado,
             a.cat_automatica,
             a.dia_atraso,
             a.cod_moneda,
             a.tot_gar_computables,
             a.cod_oficina,
             a.tipo,
             a.tot_prevision,
             a.mto_original,
             a.tip_destino,
             a.cod_sec_credito,
             a.cat_renovaciones,
             a.cat_ren_anterior,
             a.lib_prevision,
             a.tot_pri_prevision,
             a.cod_rub_economico,
             a.tot_cap_pri_prevision,
             a.tot_cap_seg_prevision,
             a.tot_int_pri_prevision,
             a.tot_int_seg_prevision,
             a.mto_pre_total,
             a.cat_pre_diferida,
             a.cat_prevision,
             a.tot_seg_prevision,
             a.tot_gar_aplicada,
             a.tot_rie_no_cubierto
        from it.ge_cla_operaciones_tmp a
       where fecha = pag_cal.fu_obt_fec_actual(6)
        and exists (select 1
                      from ba_personas b
                     where b.cod_persona = a.cod_persona);
  end;
exception
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error en proc. de volcado de datos de tarj. ' || SQLERRM);
end pr_ins_dat_tarjetas;

   /* Proceso principal de categorizacion segun la resolucion 37. */
   PROCEDURE pr_pro_cat_res37(p_tipo_proceso IN VARCHAR2 DEFAULT 'T') IS
      v_error VARCHAR2(2000);
      v_cant_tarjetas number;
      v_hor_ini varchar2(8);
      v_hor_fin varchar2(8);
      procedure pr_val_fideicomiso is
        cursor c_dat is
         select a.cod_persona, a.nro_cuenta
           from ge_cla_operaciones a, pr_cta_prestamos b
          where b.nro_cuenta = a.nro_cuenta
            --and b.cod_modalidad = 690 --FIELDESK-19388
            and exists (select 1 from ba_cod_referencias where dominio = 'COD_MAD_FIDEICOMISO' and val_minimo = a.cod_modalidad) --FIELDESK-19388
            and exists (select 1
                          from ge_cta_dat_adicionales c
                         where c.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                           and ((c.nro_cuenta = b.nro_cuenta)
                            or (c.val_parametro = b.nro_cuenta)));
      begin
        for k in c_dat loop
          begin
            delete ge_cta_dat_adicionales a
             where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
               and ((a.nro_cuenta = k.nro_cuenta) or a.val_parametro = k.nro_cuenta);
          end;
        end loop;
      end;
      -- INICIO DEL PROCESO PRINCIPAL---------------------------------------
   BEGIN
      v_fec_proceso := pag_cal.fu_obt_fec_actual(6);

      --CIE-73: recupero la cantidad de registros en la tabla temporal de tarjetas
      begin
        select count(0)
          into v_cant_tarjetas
          from ge_cla_operaciones_tmp
         where fecha = v_fec_proceso;
      exception
        when others then
          v_cant_tarjetas := 0;
      end;

      -- NGRANCE - Resolucion N?37
      SELECT por_riesgo_1a,
             por_riesgo_1b,
             por_riesgo_2,
             por_riesgo_3,
             por_riesgo_4,
             por_riesgo_5,
             por_riesgo_6,
             sal_min_vigente,
             cap_min_exigido,
             por_cap_min_exigido,
             por_cap_min_exi_sistema
        INTO v_riesgo1a,
             v_riesgo1b,
             v_riesgo2,
             v_riesgo3,
             v_riesgo4,
             v_riesgo5,
             v_riesgo6,
             v_sal_minimo,
             v_min_exigido,
             v_por_cap_min_exigido,
             v_por_cap_min_exi_sistema
        FROM pr_parametros;
      -- 1. Busco la moneda local y la de pase del sistema -------------
      SELECT cod_mon_local, cod_mon_fuerte INTO v_mon_local, v_mon_fuerte FROM ge_par_generales;
      -- 2. Busco la cotizacion de la moneda fuerte----------------------
      v_cot_mon_fuerte := pag_gen.fu_obt_cotizacion(v_mon_fuerte);
      IF p_tipo_proceso = 'T' THEN
         ----  solo si el proceso es general ----
         -- 3.1. Elimino los registros del FPOPECL ---------------------
         v_lugar := 'Eliminando registros anteriores';
         IF fug_obt_tip_implementacion = 2 THEN
            v_error := NULL;
            sql_util.ejecute_dml('truncate table ge_cla_operaciones', v_error);
            IF v_error IS NOT NULL THEN
               raise_application_error(-20000, 'Drop Fk ' || v_error);
            END IF;
            --- DELETE FROM ge_cla_operaciones;
            v_error := NULL;
            --- Desactivar FK de ge_cla_operaciones con GE_CLIENTES (xq tdvia no existe)
            sql_util.ejecute_dml('Alter table ge_cla_operaciones disable constraint FK_GCOPE_COD_PERSONA',
                                 v_error);
            IF v_error IS NOT NULL THEN
               raise_application_error(-20000, 'Drop Fk ' || v_error);
            END IF;
         ELSE
            -- otras implementaciones
            execute immediate('TRUNCATE TABLE ge_cla_operaciones');

         END IF;
         delete PR_CTA_MT_CAT_MEJORA m where m.fec_mejora = v_fec_proceso;

         BEGIN
          dbms_mview.refresh('GV_GAR_CATEGORIZACION');
         END;


         -- 3.2 Proceso cada uno de los tipos de operaciones por cliente
         v_lugar := 'Preparando datos de prestamos..';
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_dat_prestamo;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_DAT_PRESTAMO',v_hor_ini,v_hor_fin);

         v_lugar := 'Preparando datos de Sobregiros..';--FIELDESK-80435
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_dat_sobregiro;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_DAT_SOBREGIRO',v_hor_ini,v_hor_fin);

         v_lugar := 'Preparando datos de Tarjetas..';
         if v_cant_tarjetas > 0 then
           --Si existen registros en la tabla temporal, volcar directamente a ge_cla_operaciones
           v_hor_ini := to_char(sysdate,'hh24:mi:ss');
           pr_ins_dat_tarjetas;
           v_hor_fin := to_char(sysdate,'hh24:mi:ss');
           pr_ins_logeo('PR_INS_DAT_TARJETAS',v_hor_ini,v_hor_fin);

           v_hor_ini := to_char(sysdate,'hh24:mi:ss');
           pap_cat.pr_pro_dat_tarjetas;--Para insertar los registros que no existen en el temporal
           v_hor_fin := to_char(sysdate,'hh24:mi:ss');
           pr_ins_logeo('PR_PRO_DAT_TARJETAS',v_hor_ini,v_hor_fin);
         else
           --Caso contrario, procesarlos con el procedimiento del paquete
           v_hor_ini := to_char(sysdate,'hh24:mi:ss');
           pap_cat.pr_pro_dat_tarjetas;
           v_hor_fin := to_char(sysdate,'hh24:mi:ss');
           pr_ins_logeo('PR_PRO_DAT_TARJETAS',v_hor_ini,v_hor_fin);
         end if;
         v_lugar := 'Preparando datos de Cuentas Vencidas..';
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_dat_ope_ven;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_DAT_OPE_VEN',v_hor_ini,v_hor_fin);

         v_lugar := 'Preparando datos de Com. Exterior..';
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_dat_importac;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_DAT_IMPORTAC',v_hor_ini,v_hor_fin);

         v_lugar := 'Preparando datos de Bonos Privados';
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_dat_bonos;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_DAT_BONOS',v_hor_ini,v_hor_fin);

         COMMIT;
      END IF;
      IF p_tipo_proceso IN ('T', 'C') THEN
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_val_fideicomiso;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_VAL_FIDEICOMISO',v_hor_ini,v_hor_fin);
         --- proc. general o por cliente --
         -- 4. Proceso de clientes ---------------------------------------
         v_lugar := 'Preparando datos de Clientes..';
         BEGIN
          dbms_mview.refresh('SV_CON_CODEUDORES');
         END;
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_cat_clientes;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_CAT_CLIENTES',v_hor_ini,v_hor_fin);
         IF fug_obt_tip_implementacion = 2 THEN
            --- Activar FK de ge_cla_operaciones con GE_CLIENTES (xq ya existe)
            sql_util.ejecute_dml('Alter table ge_cla_operaciones enable constraint FK_GCOPE_COD_PERSONA',
                                 v_error);
            IF v_error IS NOT NULL THEN
               raise_application_error(-20000, 'Crea Fk ' || v_error);
            END IF;
         END IF;
         COMMIT;
      END IF;
      IF p_tipo_proceso IN ('T', 'G', 'C') THEN
         -- para todos los procesos ----
         -- 5. Proceso de grupos economicos ------------------------------
         v_lugar := 'Preparando datos de Grupos Economicos..';
         v_hor_ini := to_char(sysdate,'hh24:mi:ss');
         pr_pro_cat_gru_econ;
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         pr_ins_logeo('PR_PRO_CAT_GRU_ECON',v_hor_ini,v_hor_fin);
         COMMIT;
      END IF;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Resolucion 37-' || v_lugar || '-' || SQLERRM);
   END;
   /* Procesar categorizacion de clientes. */
   PROCEDURE pr_pro_cat_clientes IS

      --- leo las operaciones grabadas en la tabla de OPERACIONES -------
      CURSOR totales IS
        select  cod_persona,
                ww_ttdeuda,
                ww_ttdeuco,
                ww_capital,
                ww_mtorigen,
                ww_ttprevi,
                ww_garan
          from vm_total_operaciones;--Vista que reemplaza al query del total de operaciones
      --- Declaro las variables del procedimiento --------------------
      v_cliente             VARCHAR2(10);
      v_gru_eco             NUMBER(03);
      v_cat_auto            ge_cla_operaciones.cat_automatica%TYPE;
      v_tot_pond            NUMBER(21, 4);
      v_cat_pond            NUMBER(5, 3);
      v_cat_ren_pon         NUMBER(5, 3);
      v_cat_manu            pr_cta_prestamos.cat_renovaciones%type;
      v_cat_ant             pr_cta_prestamos.cat_renovaciones%type;
      v_existe              VARCHAR2(01);
      v_tot_deu_sistema     ge_cla_operaciones.tot_deu_real%TYPE;
      v_tot_deu_con_sistema ge_cla_operaciones.tot_deu_real%TYPE;
      v_tot_deu_real        ge_cla_operaciones.tot_deu_real%TYPE;
      v_mto_riesgo          ge_cla_operaciones.tot_deu_real%type;
      v_cat_sistema         pr_cta_prestamos.cat_renovaciones%type;
      v_cat_peor            pr_cta_prestamos.cat_renovaciones%type;
      v_cat_final           pr_cta_prestamos.cat_renovaciones%type;
      v_cat_renova          pr_cta_prestamos.cat_renovaciones%type;
      v_error               VARCHAR2(2000);
      v_operaciones         number;
      v_tip_implementacion  number := fug_obt_tip_implementacion;
      v_niv_paralelismo     number := nvl(to_number(fug_obt_pardinamico('GE_VAL_NIV_PARALELISMO')),6);
      v_act_paralelismo     varchar2(1) := nvl(fug_obt_pardinamico('GE_ACT_PARALEL_RES37'),'N');
      v_cli_solo_consumo    varchar2(1);
      v_cli_rel_enti        boolean;
      v_gru_mas_clie        boolean;
      v_cat_mtrrr           number;
      v_tot_deu_real_o number(18,2);
      v_tot_deu_contingente_o number(18,2);
      v_tot_gar_computables_o number(18,2);
      v_tot_prevision_o  number(18,2);
      v_tipo_o  varchar2(1);
      v_cat_subjetiva_o number(1);
      v_cat_automatica_o number(3,2);
      v_cat_renovaciones_o number(1);
      v_cat_riesgo_o varchar2(1);
      TYPE cursor_type IS TABLE OF totales%ROWTYPE;
      tot cursor_type;

      --Declaro variable
      TYPE type_ge_clientes IS TABLE OF ge_clientes%ROWTYPE;
      TYPE t_ge_cla_ope_cat_aut IS TABLE OF ge_cla_operaciones.cat_automatica%TYPE;
      TYPE t_ge_cla_reg IS TABLE OF ROWID;  -- Para ROWID de GE_CLA_OPERACIONES
      TYPE t_ge_cla_ope_cod_per IS TABLE OF ge_clientes.cod_persona%TYPE;
      TYPE t_ge_cla_ope_fec_ult IS TABLE OF ge_clientes.fec_ult_clasif%TYPE;
      --Inicializo varaible
      reg_type_ge_clientes  type_ge_clientes not null:= type_ge_clientes();
      r_ge_cla_ope_cat_aut  t_ge_cla_ope_cat_aut not null:= t_ge_cla_ope_cat_aut();
      r_ge_cla_reg          t_ge_cla_reg not null:= t_ge_cla_reg();
      r_ge_cla_ope_cod_per  t_ge_cla_ope_cod_per not null:= t_ge_cla_ope_cod_per();
      r_ge_cla_ope_fec_ult  t_ge_cla_ope_fec_ult not null:= t_ge_cla_ope_fec_ult();
      ---
      TYPE t_rowid_table IS TABLE OF ROWID INDEX BY PLS_INTEGER;
      v_rowids t_rowid_table;

      -- declaro el cursor de detalles de operaciones por cliente -------
      CURSOR detalles IS
         select t.nro_cuenta,
                t.cod_modulo,
                t.cod_modalidad,
                t.cat_automatica,
                t.cat_renovaciones,
                t.cat_pre_diferida,
                t.dia_atraso,
                t.oc_ttdeuda,
                t.oc_ttdeuco,
                t.tipo,
                t.mto_original,
                t.sal_capital,
                t.codeudor,
                t.fila,
                t.nro_cta_mtrrr,
                t.cod_persona
           from IT.vm_detalle_operaciones t--nueva vista que reemplaza al cursor de detalle
          where t.cod_persona = v_cliente;
      -------------------------------------------------------------------
      --Cursor que recupera clientes que son solo codeudores
      cursor c_cli_codeudores is
        SELECT   x.rowid
          FROM   ge_clientes x
          WHERE  LENGTH(x.cod_persona) > 0
          AND    (x.cat_riesgo <> 1 OR x.cat_automatica <> 1 OR x.cat_renovaciones <> 1)
          AND    NOT EXISTS (
             SELECT 1
             FROM   ge_cta_clientes b
             JOIN   ge_cuentas c ON b.nro_cuenta = c.nro_cuenta
             JOIN   ge_est_cuentas d
                    ON c.cod_modulo = d.cod_modulo
                    AND c.cod_modalidad = d.cod_modalidad
                    AND c.estado = d.estado
             WHERE  b.cod_persona = x.cod_persona
             AND    b.relacion = 'P'
             AND    b.cod_modulo IN (5, 6)
             AND    d.activo = 'S')
             AND   ( EXISTS ( SELECT 1
              FROM   ge_cta_clientes b
              JOIN   ge_cuentas c ON b.nro_cuenta = c.nro_cuenta
              JOIN   ge_est_cuentas d
                     ON c.cod_modulo = d.cod_modulo
                     AND c.cod_modalidad = d.cod_modalidad
                     AND c.estado = d.estado
              WHERE  b.cod_persona = x.cod_persona
              AND    b.relacion <> 'P'
              AND    b.cod_modulo IN (5, 6)
              AND    d.activo = 'S')
              OR EXISTS (SELECT 1
              FROM   sv_con_codeudores v
              JOIN   ge_cla_operaciones g ON v.nro_cuenta = g.nro_cuenta
              WHERE  v.cod_persona = x.cod_persona
              AND    v.relacion = 'L')
              OR EXISTS (SELECT 1
              FROM   ba_vinculos v
              JOIN   ba_personas b ON v.cod_per_vinculo = b.cod_persona
              WHERE  v.cod_persona = x.cod_persona
              AND    v.tipo = 'E'
              AND    EXISTS (SELECT 1
                      FROM   ge_cta_clientes b
                      JOIN   ge_cuentas c ON b.nro_cuenta = c.nro_cuenta
                      JOIN   ge_est_cuentas d
                             ON c.cod_modulo = d.cod_modulo
                             AND c.cod_modalidad = d.cod_modalidad
                             AND c.estado = d.estado
                      WHERE  b.cod_persona = v.cod_per_vinculo
                      AND    b.relacion = 'P'
                      AND    b.cod_modulo IN (5, 6)
                      AND    d.activo = 'S')));
                      
PROCEDURE lp_ins_cli_cat_res37(p_clientes IN type_ge_clientes) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   FORALL i IN INDICES OF p_clientes
      INSERT INTO ge_cli_cat_res37 (
         tot_deu_real,
         tot_deu_contingente,
         tot_gar_computables,
         tot_prevision,
         tipo,
         cat_subjetiva,
         cat_automatica,
         cat_renovaciones,
         cat_riesgo,
         cod_persona
      )
      VALUES (
         p_clientes(i).tot_deu_real,
         p_clientes(i).tot_deu_contingente,
         p_clientes(i).tot_gar_computables,
         p_clientes(i).tot_prevision,
         p_clientes(i).tipo,
         p_clientes(i).cat_subjetiva,
         p_clientes(i).cat_automatica,
         p_clientes(i).cat_renovaciones,
         p_clientes(i).cat_riesgo,
         p_clientes(i).cod_persona
      );

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al insertar en ge_cli_cat_res37 ' || SQLERRM);
END lp_ins_cli_cat_res37;
      ----------------------------------------------------------
   BEGIN
     --Limpiar la tabla auxiliar
     execute immediate('TRUNCATE TABLE ge_cli_cat_res37');
     BEGIN
      -- Refrescar la vista materializada 'vm_total_operaciones' sin ser atómico
       DBMS_MVIEW.REFRESH(
           list => 'IT.vm_total_operaciones', -- Nombre de la vista materializada
           method => 'C',  -- 'C' para un refresco completo
           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
       );
      END;
     pag_cie.PR_INS_LOG('-INICIO- Refresh Vista Detalle.', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
     BEGIN
       -- Refrescar la vista materializada 'vm_detalle_operaciones' sin ser atómico
       DBMS_MVIEW.REFRESH(
           list => 'IT.vm_detalle_operaciones', -- Nombre de la vista materializada
           method => 'C',  -- 'C' para un refresco completo
           atomic_refresh => FALSE -- Permite acceso durante el refresco, sin ser atómico
       );
      END;
      pag_cie.PR_INS_LOG('-INICIO- Inicio valores.', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      --- cero todos los clientes -------------------------------------
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CLIENTES DISABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CLIENTES DISABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER TA_GE_CLIENTES DISABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER TB_GE_CLIENTES DISABLE', v_error);


      --- cero todos los clientes -------------------------------------
      UPDATE ge_clientes
         SET tot_deu_real        = 0,
             tot_deu_contingente = 0,
             tot_gar_computables = 0,
             tot_prevision       = 0,
             cat_automatica      = 1,
             cat_renovaciones    = 1
       WHERE nvl(tot_deu_real, -1) != 0
          OR nvl(tot_deu_contingente, -1) != 0
          OR nvl(tot_gar_computables, -1) != 0
          OR nvl(tot_prevision, -1) != 0
          OR cat_automatica NOT IN (1,6);
       -- actualizar a 1 categorias de clientes que son solo codeudores
     OPEN c_cli_codeudores;
         FETCH c_cli_codeudores BULK COLLECT INTO v_rowids;
         CLOSE c_cli_codeudores;

         IF v_rowids.COUNT > 0 THEN
              FORALL i IN 1 .. v_rowids.COUNT
                 UPDATE ge_clientes
                    SET cat_riesgo       = 1,
                        cat_automatica   = 1,
                        cat_renovaciones = 1
                  WHERE  ROWID = v_rowids(i);
         END IF;
         
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CLIENTES ENABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CLIENTES ENABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER TA_GE_CLIENTES ENABLE', v_error);
      sql_util.ejecute_dml('ALTER TRIGGER TB_GE_CLIENTES ENABLE', v_error);
      --- proceso de actualizacion ------------------------------------
      pag_cie.PR_INS_LOG('-INICIO- Cursor totales.', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      IF totales%ISOPEN THEN
         CLOSE totales;
      END IF;
      ----------------------
      OPEN totales;
      LOOP
      FETCH totales BULK COLLECT
         INTO tot LIMIT 650000;
        FOR i IN 1.. tot.count LOOP
           v_cliente             := tot(i).cod_persona;
           v_cat_renova          := 1; /* para categoria  de las operaciones ren,ref y rest */
           v_cat_ant             := 1; /* categoria  anterior, por si no existe */
           v_lugar               := 'Procesando el Cliente Nro. ' || v_cliente;
           v_tipo_clie           := NULL;
           v_cat_manu            := NULL;
           v_existe              := 'N';
           v_tot_deu_sistema     := 0;
           v_tot_deu_con_sistema := 0;
           v_cat_sistema         := 1;
           v_cat_final           := 1;
           v_operaciones         := null;
           v_cat_ren_pon         := null;
           v_cli_solo_consumo    := fu_cli_solo_consumo(v_cliente);
           v_cli_rel_enti        := fu_ver_cli_rel_enti(v_cliente);
           BEGIN
              SELECT tipo, cat_riesgo, cod_gru_economico, cat_subjetiva, tot_deu_sistema, cat_sistema ,tot_deu_con_sistema,
                     tot_deu_real, tot_deu_contingente, tot_gar_computables,tot_prevision,tipo,cat_subjetiva,cat_automatica,
                     cat_renovaciones, cat_riesgo
                INTO v_tipo_clie, v_cat_ant, v_gru_eco, v_cat_manu, v_tot_deu_sistema, v_cat_sistema, v_tot_deu_con_sistema,
                     v_tot_deu_real_o, v_tot_deu_contingente_o, v_tot_gar_computables_o,v_tot_prevision_o,v_tipo_o,v_cat_subjetiva_o,v_cat_automatica_o,
                     v_cat_renovaciones_o, v_cat_riesgo_o
                FROM ge_clientes
               WHERE cod_persona = v_cliente;
              v_existe := 'S';
           EXCEPTION
              WHEN no_data_found THEN
                 v_existe    := 'N';
                 v_tipo_clie := 'X';
              WHEN too_many_rows THEN
                 v_existe := 'S';
           END;
           /*begin
             delete ge_cta_dat_adicionales a
              where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                and (a.nro_cuenta = tot(i).nro)
           end;*/
           --- Consideracion del tipo de cliente para tomar el monto de la deuda
           v_lugar        := 'Asigna deuda Nro. ' || v_cliente;
           --Cambio agregado por Adolfo 19/03/2021
           -- Para clasificacion del cliente usar deuda total del cliente
           -- no incluidas las Covid
           v_tot_deu_real := fu_cli_obt_deu_real_total(v_cliente);
           --v_tot_deu_real := tot(i).ww_ttdeuda;
           --v_tot_deu_sistema := v_tot_deu_sistema + v_tot_deu_real;
           v_tot_deu_sistema := v_tot_deu_sistema + v_tot_deu_real + v_tot_deu_con_sistema;
           --- se considera el del proceso a ayer.

           --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
           --                G = Mayores deudores vinculados a otros grupos economicos
           --                M = Grandes Deudores Comerciales,
           --                N = Peque?os deudores relacionados a la Entidad,
           --                C = Peque?os deudores comerciales,
           --                P = Deudores Personales, (consumo y vivienda)
           --                T = Micro creditos

           if v_gru_eco is not null then
              v_gru_mas_clie := pap_cat.fu_ver_gru_mas_clie(v_gru_eco);
           else
             v_gru_mas_clie := FALSE;
           end if;
           v_lugar := 'Verifica tip cliente: ' || v_cliente;
           if nvl(v_tot_deu_real, 0) > 0 then --para cancelaciones totales, solo cuando hay deuda tipificar fieldesk-5715
             IF ((nvl(v_tot_deu_real, 0) > (v_min_exigido * v_por_cap_min_exigido / 100))
               AND v_cli_solo_consumo='N')  OR
                ((nvl(v_tot_deu_sistema, 0) > (v_min_exigido * v_por_cap_min_exi_sistema / 100))
                AND v_cli_solo_consumo='N') OR -- Aplicable a partir del 01/01/2009
                ((v_gru_eco IS NOT NULL AND v_gru_mas_clie = true)
                AND v_cli_solo_consumo='N') THEN
                -- supera el 2% en la entidad, o el 4% en el sistema financiero  ---ANTES
                -- supera el 3% en la entidad, o el 6% en el sistema financiero  ---AHORA!!
                IF v_cli_rel_enti = true THEN
                   v_tipo_clie := 'R'; -- grandes deudores comerciales relacionados
                ELSE
                   IF v_gru_eco IS NOT NULL AND v_gru_mas_clie = true THEN
                      --si tiene grupo y hay otros clientes en el mismo then
                      v_tipo_clie := 'G'; -- Mayores deudores vinculados a otros grupos economicos
                   ELSE
                      v_tipo_clie := 'M'; -- grandes deudores comerciales no vinculados
                   END IF;
                END IF;
             ELSIF nvl(v_tot_deu_real, 0) > (v_sal_minimo * 25) AND
                   v_cli_solo_consumo = 'N' THEN
                --- que no posee creeditos de consumo
                IF v_cli_rel_enti = true THEN
                 v_tipo_clie := 'N'; -- peque?os deudores comerciales relacionados
                ELSE
                 v_tipo_clie := 'C'; -- peque?os deudores comerciales
                END IF;
             ELSIF v_cli_solo_consumo = 'S' THEN
                IF fu_cli_solo_vivienda(v_cliente) = 'S' THEN
                   v_tipo_clie := 'V'; -- vivienda
                ELSE
                   v_tipo_clie := 'P'; -- personal
                END IF;
             ELSE
               IF NVL(fue_per_dat_adicional(v_cliente,'IND_TIP_DEU_MENOR'),'N') = 'S' THEN
                IF v_cli_rel_enti = true THEN
                   v_tipo_clie := 'N'; -- peque?os deudores comerciales relacionados
                ELSE
                   v_tipo_clie := 'C'; -- peque?os deudores comerciales
                END IF;
               ELSE
                v_tipo_clie := 'T'; -- microcreditos
               END IF;
             END IF;
           end if;
           v_lugar    := 'Ponderar deuda: ' || v_cliente;
           v_tot_pond := 0;
           v_cat_peor := 1;
           v_mto_riesgo := 0;
           FOR det IN detalles LOOP
              v_cat_auto := det.cat_automatica;
              --v_cat_mtrrr := fu_cli_obt_cat_mtrrr(det.nro_cuenta);
              IF det.codeudor = 'S' THEN
                 v_mto_riesgo := v_mto_riesgo + nvl(det.oc_ttdeuda, 0);
              END IF;
              IF det.cod_modulo <> 6 THEN
                 --- prestamos no es necesario analizar porque ya se hizo para extornar la deuda
                 --- por cada operacion de credito, calculo el ponderado
                 IF det.dia_atraso > 0 THEN
                    v_cat_auto := fu_obt_categ_x_mora(det.dia_atraso);
                 ELSE
                    v_cat_auto := nvl(det.cat_automatica, 1);
                 END IF;
                 IF det.cat_renovaciones IS NOT NULL THEN
                    -- es un credito refinanciado, directamente debe tener 3, porque aun
                    -- no pago ni el 10% de su credito original
                    IF v_cat_auto < det.cat_renovaciones THEN
                       --- Si por mora tiene una categoria peor no debe mejorar
                       v_cat_auto := det.cat_renovaciones;
                    END IF;
                    v_cat_renova := round(det.cat_renovaciones);
                 END IF;
                 IF det.cat_pre_diferida IS NOT NULL THEN
                    -- es un credito refinanciado, directamente debe tener 3, porque aun
                    -- no pago ni el 10% de su credito original
                    IF v_cat_auto < det.cat_pre_diferida THEN
                       --- Si por mora tiene una categoria peor no debe mejorar
                       v_cat_auto := det.cat_pre_diferida;
                    END IF;
                    --v_cat_renova := round(det.cat_renovaciones);
                 END IF;
                 --- actualizo la ponderacion por mora ---------------------
                 r_ge_cla_ope_cat_aut.extend();
                 r_ge_cla_reg.extend();
                 r_ge_cla_ope_cat_aut(r_ge_cla_ope_cat_aut.COUNT) := v_cat_auto;
                 r_ge_cla_reg(r_ge_cla_reg.COUNT) := det.fila;
              END IF;
              IF v_tip_implementacion = 2 THEN
                 v_tot_pond := v_tot_pond + (nvl(det.oc_ttdeuda, 0) * round(v_cat_auto));
              END IF;
              IF v_tip_implementacion NOT IN (2) THEN
                 if det.nro_cta_mtrrr is not null then
                    v_cat_mtrrr := fu_cli_obt_cat_mtrrr(det.nro_cuenta);
                    if v_cat_mtrrr > v_cat_auto then
                       v_cat_auto := v_cat_mtrrr;
                    end if;
                    v_tot_pond := v_tot_pond +
                                  ((nvl(det.oc_ttdeuda, 0) + fu_cli_obt_deu_mtrrr(det.nro_cta_mtrrr) +
                                    nvl(det.oc_ttdeuco, 0) + fu_cli_obt_con_mtrrr(det.nro_cta_mtrrr)) * round(v_cat_auto));
                 else
                    v_tot_pond := v_tot_pond +
                                  ((nvl(det.oc_ttdeuda, 0) + nvl(det.oc_ttdeuco, 0)) * round(v_cat_auto));
                 end if;
              END IF;
           END LOOP;
           --- calculo categoria ponderada
           v_lugar := 'Calcular cat pond.: ' || v_cliente;
           IF v_tip_implementacion <> 2 THEN
              if v_tot_pond > 0 then
                v_cat_pond := round(trunc((v_tot_pond /
                                          (nvl(tot(i).ww_ttdeuda, 0) + nvl(tot(i).ww_ttdeuco, 0) + nvl(v_mto_riesgo, 0))), 2), 0);
                IF v_cat_pond = 0 THEN
                   v_cat_pond := 1;
                END IF;
              else
                v_cat_pond := 1;
              end if;

           ELSE
              --- 2
              IF nvl(tot(i).ww_ttdeuda, 0) <> 0 THEN
                 v_cat_pond := round(trunc(v_tot_pond / nvl(tot(i).ww_ttdeuda, 0), 2), 0);
              ELSE
                 IF v_tot_pond > 0 THEN
                    v_cat_pond := round(trunc(v_tot_pond, 2), 0);
                 ELSE
                    v_cat_pond := 1;
                 END IF;
              END IF;
           END IF;

           v_lugar := 'Calcular cat final: ' || v_cliente||'-'||tot(i).ww_ttdeuda||'-'||v_tot_pond||'-'||v_cat_manu||'-'||v_cat_pond;
           IF v_tip_implementacion = -2 THEN
              -- Para este cliente ya no se hace asi, sino como el else
              v_cat_final := nvl(v_cat_manu, round(v_cat_pond));
           ELSE
              v_cat_final := fup_obt_categoria(v_cat_pond, v_cat_manu);
           END IF;
           IF v_operaciones = 0 and v_cat_renova > 0 THEN
              -- el cliente no posee otro tipo de producto.
              -- debe ponderar la categoria que previsiona.
              v_cat_final :=  v_cat_renova ;
           END IF;
           --- Actualizo los datos del cliente ---------------------
           --- Modifico la fecha de ultima clasificacion a efectos de previsiones
           v_lugar := 'Actualiza cliente ' || v_cliente || ' tipo ' || v_tipo_clie || ' man ' ||
                      v_cat_manu || ' final ' || v_cat_final || ' ren ' || v_cat_renova;
           IF v_cat_ant <> v_cat_final THEN
               r_ge_cla_ope_fec_ult.extend;
               r_ge_cla_ope_cod_per.extend;
               r_ge_cla_ope_fec_ult(r_ge_cla_ope_fec_ult.count) := v_fec_proceso;
               r_ge_cla_ope_cod_per(r_ge_cla_ope_cod_per.count) := v_cliente;

           END IF;
           --- Actualizo el resto de los datos
           v_lugar := 'Actualiza cliente: ' || v_cliente || ' tipo ' || v_tipo_clie || ' man ' ||
                      v_cat_manu || ' final ' || v_cat_final || ' ren ' || v_cat_renova;

         if   nvl(v_tot_deu_real_o,0)        != nvl(tot(i).ww_ttdeuda, 0) or
              nvl(v_tot_deu_contingente_o,0) != nvl(tot(i).ww_ttdeuco, 0) or
              nvl(v_tot_gar_computables_o,0) != nvl(tot(i).ww_garan, 0)   or
              nvl(v_tot_prevision_o,0)       != nvl(tot(i).ww_ttprevi, 0) or
              v_tipo_o                       != v_tipo_clie               or
              v_cat_subjetiva_o              != v_cat_manu                or
              v_cat_automatica_o             !=v_cat_final                or
              round(v_cat_renovaciones_o,0)  != round(v_cat_renova, 0)    or
              round(v_cat_riesgo_o,0)        != round(v_cat_final, 0)     then
                 reg_type_ge_clientes.EXTEND;
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).tot_deu_real        := nvl(tot(i).ww_ttdeuda, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).tot_deu_contingente := nvl(tot(i).ww_ttdeuco, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).tot_gar_computables := nvl(tot(i).ww_garan, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).tot_prevision       := nvl(tot(i).ww_ttprevi, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).tipo                := v_tipo_clie;
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).cat_subjetiva       := v_cat_manu;
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).cat_automatica      := v_cat_final;
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).cat_renovaciones    := round(v_cat_renova, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).cat_riesgo          := round(v_cat_final, 0);
                 reg_type_ge_clientes(reg_type_ge_clientes.COUNT).cod_persona         := v_cliente;
          end if;

           -------------------------------------------------------------
        END LOOP;
      EXIT WHEN totales%NOTFOUND;
      END LOOP;
      CLOSE totales;

      pag_cie.PR_INS_LOG('-INICIO- Update ge_cla_operaciones', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      FORALL i in 1.. r_ge_cla_reg.COUNT
        UPDATE ge_cla_operaciones
           SET cat_automatica = r_ge_cla_ope_cat_aut(i)
         WHERE rowid = r_ge_cla_reg(i);

      pag_cie.PR_INS_LOG('-INICIO- Update r_ge_cla_ope_cod_per', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      FORALL i in 1 .. r_ge_cla_ope_cod_per.COUNT
        UPDATE ge_clientes
           SET cat_anterior     = cat_automatica,
               fec_cat_anterior = fec_ult_clasif,
               fec_ult_clasif   = r_ge_cla_ope_fec_ult(i)
         WHERE cod_persona = r_ge_cla_ope_cod_per(i);
      
      --Si el parametro de paralelismo esta activo, ejecutar la actualizacion de este modo
      IF v_act_paralelismo = 'S' THEN
        pag_cie.PR_INS_LOG('-INICIO PARALELISMO- Update reg_type_ge_clientes', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
        
        --cargar en procedimiento autonomo para evitar commit parcial en el proc. principal
        lp_ins_cli_cat_res37(reg_type_ge_clientes);

        BEGIN
           -- Eliminar la tarea y los bloques relacionados
           DBMS_PARALLEL_EXECUTE.DROP_TASK('cat_res37_task');
        EXCEPTION
           WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
              NULL;
        END;
        -- Crear la tarea
        DBMS_PARALLEL_EXECUTE.create_task('cat_res37_task');

        -- Dividir la tabla por ROWID en intervalos de 50000
        DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID('cat_res37_task', 'IT', 'GE_CLI_CAT_RES37', true, 50000);

        -- Ejecutar el DML en paralelo
        DBMS_PARALLEL_EXECUTE.run_task(task_name      => 'cat_res37_task',
                                       sql_stmt       =>
                        q'[BEGIN
                        begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
                        MERGE INTO ge_clientes e
                         USING (
                            SELECT tot_deu_real, tot_deu_contingente, tot_gar_computables,
                                   tot_prevision, tipo, cat_subjetiva, cat_automatica,
                                   cat_renovaciones, cat_riesgo, cod_persona
                            FROM ge_cli_cat_res37
                            WHERE rowid BETWEEN :start_id AND :end_id
                         ) h
                         ON (e.cod_persona = h.cod_persona)
                         WHEN MATCHED THEN
                            UPDATE SET e.tot_deu_real        = h.tot_deu_real,
                                       e.tot_deu_contingente = h.tot_deu_contingente,
                                       e.tot_gar_computables = h.tot_gar_computables,
                                       e.tot_prevision       = h.tot_prevision,
                                       e.tipo                = h.tipo,
                                       e.cat_subjetiva       = h.cat_subjetiva,
                                       e.cat_automatica      = h.cat_automatica,
                                       e.cat_renovaciones    = h.cat_renovaciones,
                                       e.cat_riesgo          = h.cat_riesgo
                        ;
                        END;]',
                                       language_flag  => DBMS_SQL.NATIVE,
                                       parallel_level => v_niv_paralelismo);--nivel paralelismo
  	    --Verificar el estatus de la ejecucion
        IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS('cat_res37_task') THEN
          raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || 'cat_res37_task');
        END IF;
        pag_cie.PR_INS_LOG('-FIN PARALELISMO- Update reg_type_ge_clientes', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      ELSE
        --Si el paralelismo no esta activo, ejecutar la actualizacion de forma tradicional
        pag_cie.PR_INS_LOG('-INICIO- Update reg_type_ge_clientes', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
        FORALL i IN INDICES OF reg_type_ge_clientes
          UPDATE ge_clientes
           SET tot_deu_real        = reg_type_ge_clientes(i).tot_deu_real,
               tot_deu_contingente = reg_type_ge_clientes(i).tot_deu_contingente,
               tot_gar_computables = reg_type_ge_clientes(i).tot_gar_computables,
               tot_prevision       = reg_type_ge_clientes(i).tot_prevision,
               tipo                = reg_type_ge_clientes(i).tipo,
               cat_subjetiva       = reg_type_ge_clientes(i).cat_subjetiva,
               cat_automatica      = reg_type_ge_clientes(i).cat_automatica,
               cat_renovaciones    = reg_type_ge_clientes(i).cat_renovaciones,
               cat_riesgo          = reg_type_ge_clientes(i).cat_riesgo
         WHERE cod_persona         = reg_type_ge_clientes(i).cod_persona;
        pag_cie.PR_INS_LOG('-FIN- Update reg_type_ge_clientes', pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      END IF;  
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. Clientes ' || SQLERRM);
   END;
   /* Procesar categorizacion de grupos economicos. */
   PROCEDURE pr_pro_cat_gru_econ IS

      CURSOR totales IS
         SELECT cod_gru_economico,
                SUM(nvl(tot_deu_real, 0)) ww_ttdeuda,
                SUM(nvl(tot_deu_contingente, 0)) ww_ttdeuco,
                SUM(nvl(tot_gar_computables, 0)) ww_ttgarco,
                SUM(nvl(capital, 0)) ww_capital,
                SUM(nvl(tot_deu_sistema, 0)) ww_tot_deu_sistema,
                SUM(nvl(tot_prevision, 0)) ww_ttprevi
           FROM ge_clientes a,
                (SELECT s.cod_persona, SUM(mto_original) capital
                   FROM ge_cla_operaciones s, ge_clientes e
                  WHERE s.cod_persona = e.cod_persona
                    AND fup_inc_ope_med_gru(e.cod_gru_economico, nro_cuenta) = 'S'
                  GROUP BY s.cod_persona) b
          WHERE cod_gru_economico IS NOT NULL
            AND a.cod_persona = b.cod_persona
            AND EXISTS
          (SELECT 0 FROM ge_gru_economicos b WHERE b.cod_gru_economico = a.cod_gru_economico)
          GROUP BY cod_gru_economico
         HAVING SUM(nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) > 0;

      --- declaro las variables a ser utilizadas en el proc. ------
      v_gru_eco               NUMBER(03);
      v_factorp               NUMBER(10, 4);
      v_tot_pond              NUMBER(5, 3);
      v_cat_pond              NUMBER(5, 3);
      v_cat_gru_eco_ponderada ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_automatica        ge_cla_operaciones.cat_automatica%TYPE;
      --- declaro los detalles de los clientes --------------------
      CURSOR detalles IS
         SELECT tot_deu_real,
                tot_deu_contingente,
                cat_automatica,
                tipo,
                tot_deu_sistema,
                cod_persona,
                ROWID fila
           FROM ge_clientes
          WHERE fup_inc_cli_med_gru(cod_gru_economico, cod_persona) = 'S'
            AND cod_gru_economico = v_gru_eco;
   BEGIN
      UPDATE ge_gru_economicos
         SET cat_automatica      = 1,
             tot_deu_real        = 0,
             tot_deu_contingente = 0,
             tot_gar_computables = 0,
             tot_prevision       = 0;
      FOR tot IN totales LOOP
         v_tipo_clie             := NULL;
         v_lugar                 := 'Procesando el Grupo Economico Nro. ' ||
                                    to_char(tot.cod_gru_economico, '999');
         v_gru_eco               := tot.cod_gru_economico;
         v_tot_pond              := 0;
         v_cat_gru_eco_ponderada := 0;
         --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
         --                M = Grandes Deudores Comerciales,
         --                N = Peque?os deudores relacionados a la Entidad,
         --                C = Peque?os deudores comerciales,
         --                P = Deudores Personales,
         --                T = Micro creditos
         -- Grandes deudores comerciales
         IF fu_ver_gru_mas_clie(v_gru_eco) THEN
             IF (nvl(tot.ww_capital, 0) > (v_min_exigido * v_por_cap_min_exigido / 100)) OR
                (nvl(tot.ww_tot_deu_sistema, 0) > (v_min_exigido * v_por_cap_min_exi_sistema / 100)) THEN
                -- supera el 2% en la entidad, o el 4% en el sistema financiero
                IF v_gru_eco = fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD') THEN
                   v_tipo_clie := 'R'; -- grandes deudores comerciales relacionados
                ELSE
                   v_tipo_clie := 'G'; -- Mayores deudores vinculados a otros grupos economicos
                END IF;
             ELSIF nvl(tot.ww_capital, 0) > (v_sal_minimo * 5) AND
                   nvl(tot.ww_capital, 0) > (v_sal_minimo * 100) THEN
                v_tipo_clie := 'N'; -- peque?os deudores comerciales relacionados
             ELSIF nvl(tot.ww_capital, 0) > (v_sal_minimo * 5) THEN
                v_tipo_clie := 'P'; -- personal
             ELSE
                v_tipo_clie := 'T'; -- microcreditos
             END IF;
         END IF;
         -- veo los clientes
         FOR det IN detalles LOOP
            --- por cada operacion de credito, calculo el ponderado ---
            v_factorp               := (nvl(det.tot_deu_real, 0) + nvl(det.tot_deu_contingente, 0)) /
                                       (nvl(tot.ww_ttdeuda, 0) + nvl(tot.ww_ttdeuco, 0));
            v_cat_pond              := v_factorp * det.cat_automatica;
            v_tot_pond              := nvl(v_tot_pond, 0) + v_cat_pond;
            v_cat_gru_eco_ponderada := nvl(v_cat_gru_eco_ponderada, 0) + v_cat_pond;
            IF v_tipo_clie IN ('R', 'G') THEN
              v_tipo_clie := v_tipo_clie;
               --#1 UPDATE ge_clientes SET tipo = v_tipo_clie WHERE ROWID = det.fila;
            ELSE
               --- verifico si el tipo de cliente esta ok o no ---------------
               IF (nvl(det.tot_deu_real, 0) > (v_min_exigido * v_por_cap_min_exigido / 100)
                   AND fu_cli_solo_consumo(det.cod_persona)='N') OR
                  (nvl(det.tot_deu_sistema, 0) > (v_min_exigido * v_por_cap_min_exi_sistema / 100)
                   AND fu_cli_solo_consumo(det.cod_persona)='N') -- Aplicable a partir del 01/01/2009
                THEN
                  IF fu_ver_cli_rel_enti(det.cod_persona) THEN
                     v_tipo_clie := 'R'; -- grandes deudores comerciales relacionados
                  ELSE
                     IF v_gru_eco IS NOT NULL AND fu_ver_gru_mas_clie(v_gru_eco) THEN
                        v_tipo_clie := 'G'; -- Mayores deudores vinculados a otros grupos economicos
                     ELSE
                        v_tipo_clie := 'M'; -- grandes deudores comerciales no vinculados
                     END IF;
                  END IF;
               ELSIF nvl(det.tot_deu_real, 0) > (v_sal_minimo * 25) AND
                     fu_cli_solo_consumo(det.cod_persona) = 'N' THEN
                  --- que no posee creeditos de consumo
                  IF fu_ver_cli_rel_enti(det.cod_persona) THEN
                     v_tipo_clie := 'N'; -- peque?os deudores comerciales relacionados
                  ELSE
                     v_tipo_clie := 'C'; -- peque?os deudores comerciales
                  END IF;
               ELSIF fu_cli_solo_consumo(det.cod_persona) = 'S' THEN
                  IF fu_cli_solo_vivienda(det.cod_persona) = 'S' THEN
                     v_tipo_clie := 'V'; -- vivienda
                  ELSE
                     v_tipo_clie := 'P'; -- personal
                  END IF;
               ELSE
                   IF NVL(fue_per_dat_adicional(det.cod_persona,'IND_TIP_DEU_MENOR'),'N') = 'S' THEN
                    IF fu_ver_cli_rel_enti(det.cod_persona) THEN
                       v_tipo_clie := 'N'; -- peque?os deudores comerciales relacionados
                    ELSE
                       v_tipo_clie := 'C'; -- peque?os deudores comerciales
                    END IF;
                   ELSE
                    v_tipo_clie := 'T'; -- microcreditos
                   END IF;
               END IF;
               -- si cambio el tipo se actualizan los tipos
               IF v_tipo_clie <> det.tipo THEN
                 v_tipo_clie := v_tipo_clie;
                  --#1 UPDATE ge_clientes SET tipo = v_tipo_clie WHERE ROWID = det.fila;
               END IF;
            END IF;
         END LOOP;
         -----------------------
         BEGIN
            SELECT MAX(ge_cla_operaciones.cat_automatica)
              INTO v_cat_automatica
              FROM ge_clientes, ge_cla_operaciones
             WHERE ge_clientes.cod_gru_economico = v_gru_eco
               AND ge_clientes.cod_persona = ge_cla_operaciones.cod_persona
               AND fup_inc_ope_med_gru(v_gru_eco, ge_cla_operaciones.nro_cuenta) = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               v_cat_automatica := NULL;
         END;
         -----------------------
         IF round(trunc(nvl(v_cat_gru_eco_ponderada, 1), 2), 0) < 2 AND
            nvl(v_cat_automatica, 1) < 2 THEN
            -- actualizo la categoria  final del cliente
            UPDATE ge_clientes a
               SET a.cat_riesgo        = round(trunc(nvl(v_tot_pond, 1), 2), 0),
                   a.cat_gru_economico = round(nvl(v_cat_automatica, 1), 1)
             WHERE cod_gru_economico = v_gru_eco;
         ELSE
            -- actualizo la categoria  final del cliente
            IF nvl(v_cat_gru_eco_ponderada, 1) > 1 AND
               to_number(round(trunc(nvl(v_cat_gru_eco_ponderada, 1), 1), 2)) <= 1.2 THEN
                  UPDATE ge_clientes a
                     SET a.cat_riesgo        = round(trunc(nvl(v_tot_pond, 1), 2), 0),
                         a.cat_gru_economico = round(trunc(nvl(v_cat_gru_eco_ponderada, 1), 1), 2)
                   WHERE cod_gru_economico = v_gru_eco;
            ELSE
               UPDATE ge_clientes a
                 SET a.cat_riesgo        = round(trunc(nvl(v_tot_pond, 1), 2), 0),
                     a.cat_gru_economico = round(trunc(nvl(v_cat_gru_eco_ponderada, 1), 2), 0)
               WHERE cod_gru_economico = v_gru_eco;
            END IF;
            IF v_cat_automatica >= 2 and --FIELDESK-40474
                 (round(trunc(nvl(v_cat_gru_eco_ponderada,1),1),2)=1 or
                  round(trunc(nvl(v_cat_gru_eco_ponderada,1),2),0)=1) then
                    UPDATE ge_clientes a
                       SET a.cat_gru_economico = 1.2
                     WHERE cod_gru_economico = v_gru_eco;
            END IF;
         END IF;
         -----------------------
         UPDATE ge_gru_economicos
            SET cat_automatica      = nvl(v_tot_pond, 1),
                tot_deu_real        = nvl(tot_deu_real, 0) + nvl(tot.ww_ttdeuda, 0),
                tot_deu_contingente = nvl(tot_deu_contingente, 0) + nvl(tot.ww_ttdeuco, 0),
                tot_gar_computables = nvl(tot_gar_computables, 0) + nvl(tot.ww_ttgarco, 0),
                tot_prevision       = nvl(tot_prevision, 0) + nvl(tot.ww_ttprevi, 0)
          WHERE cod_gru_economico = v_gru_eco;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. Grupos Economicos ' ||v_tot_pond || SQLERRM);
   END;

   /* Proceso de categorización de deudas de comercio exterior. */
   PROCEDURE pr_pro_dat_importac IS
      --- Deudas de comercio exterior ------------------------------------
      CURSOR c_comext IS
         SELECT a.cod_oficina,
                b.cod_persona,
                a.cod_modulo,
                a.cod_modalidad,
                a.nro_cuenta,
                a.cod_moneda,
                --a.saldo           monto, --DYDMR-3072-Modulo de LC Import Prepagas-SC-25603.-
                case
                  when (a.mto_prepago > a.mto_utilizado) then
                       a.saldo - (a.mto_prepago - a.mto_utilizado)
                  else a.saldo end monto,
                a.estado,
                a.fec_aprobacion  fecha_de_apertura,
                a.fec_vencimiento fecha_de_vencimiento,
                -- Fecha: 20/10/2014.
                -- Requerimiento: CNFAIRUNO-23.
                'N' contragarantia
           FROM ge_cta_clientes b, cx_cta_importaciones a
          WHERE a.nro_cuenta = b.nro_cuenta
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
            --AND a.saldo > 0 --DYDMR-3072-Modulo de LC Import Prepagas-SC-25603.-
            and (case when (a.mto_prepago > a.mto_utilizado) then
                       a.saldo - (a.mto_prepago - a.mto_utilizado)
                     else a.saldo end) > 0
            AND b.relacion = 'P'
         UNION
         SELECT a.cod_oficina,
                b.cod_persona,
                a.cod_modulo,
                a.cod_modalidad,
                a.nro_cuenta,
                a.cod_moneda,
                a.monto,
                a.estado,
                a.fec_concesion   fecha_de_apertura,
                a.fec_vencimiento fecha_de_vencimiento,
                -- Fecha: 20/10/2014.
                -- Requerimiento: CNFAIRUNO-23.
                a.contragarantia
           FROM ge_cta_clientes b, cx_fianzas a
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            -- Fecha: 20/10/2014.
            -- Requerimiento: CNFAIRUNO-23.
            --AND a.contragarantia = 'N' -- ICL 22/03/12: Mail HB
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
            AND a.monto > 0;

      rv_oper    ge_cla_operaciones%ROWTYPE;
      ww_ttdeuco NUMBER(18);
      ww_ttdeuda NUMBER(18);
   BEGIN
      FOR reg IN c_comext LOOP
         v_lugar := 'Procesando la operación Nro. ' || reg.nro_cuenta;
         ---1. cálculo la deuda en la moneda local ----------------------
         ww_ttdeuco := fu_con_a_guaranies(reg.cod_moneda, reg.monto);
         ww_ttdeuda := 0;
         ---2. inserto el registro de la operación ----------------------
         rv_oper.cod_persona         := reg.cod_persona;
         rv_oper.nro_cuenta          := reg.nro_cuenta;
         rv_oper.cod_modulo          := reg.cod_modulo;
         rv_oper.cod_modalidad       := reg.cod_modalidad;
         rv_oper.cod_estado          := reg.estado;
         rv_oper.tot_deu_real        := ww_ttdeuda;
         rv_oper.tot_deu_contingente := ww_ttdeuco;
         rv_oper.dia_atraso          := 0;
         rv_oper.cod_moneda          := reg.cod_moneda;
         rv_oper.cod_oficina         := reg.cod_oficina;
         rv_oper.tipo                := 'A';
         rv_oper.mto_original        := nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0);
         -- Requerimiento: CNFAIRUNO-3.
         -- Fecha: 22/09/2014.
         rv_oper.cod_sec_credito     := NVL(fu_obt_cod_actividad(reg.cod_persona),701);
         rv_oper.tip_destino         := fu_obt_tip_destino(reg.cod_persona, reg.cod_modulo, reg.cod_modalidad, rv_oper.cod_sec_credito, (nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0)));
         -- Fecha: 20/10/2014.
         -- Requerimiento: CNFAIRUNO-23.
         IF reg.contragarantia = 'S' THEN
            rv_oper.tot_gar_computables := ww_ttdeuco;
         ELSE
            rv_oper.tot_gar_computables := 0;
         END IF;
         pr_ins_sb_cla_operac(rv_oper);
      END LOOP;
   END;

   /* Proceso de categorizacion de deudas de bonos privados. */
    PROCEDURE pr_pro_dat_bonos IS
      --- Deudas de mesa de dinero ------------------------------------
        CURSOR c_bonos IS
           SELECT a.cod_oficina,
                  ge.cod_persona,
                  a.cod_modulo,
                  a.cod_modalidad,
                  a.nro_cuenta,
                  a.cod_moneda,
                  a.sal_capital     monto,
                  (a.sal_interes - a.val_int_devengar) dev_no_cobrado,
                  a.estado,
                  a.fec_inicio      fecha_de_apertura,
                  a.fec_vencimiento fecha_de_vencimiento,
                  a.cod_rub_economico  ---circular 236
             FROM md_cta_documentos a, ge_cta_clientes ge
            WHERE a.nro_cuenta = ge.nro_cuenta
              AND fug_obt_pardinamico('PRE_CAT_MAD_MESA',a.cod_modulo,a.cod_modalidad) = 'S'
              AND a.estado = 'C'
              AND ge.relacion = 'P';

        rv_oper    ge_cla_operaciones%ROWTYPE;
        ww_ttdeuco NUMBER(18,2);
        ww_ttdeuda NUMBER(18,2);
        v_tot_dev_no_cob NUMBER(18, 2);
     BEGIN
        FOR reg IN c_bonos LOOP
           v_lugar := 'Procesando la operacion Nro. ' || reg.nro_cuenta;
          ---1. calculo la deuda en la moneda local ----------------------
           ww_ttdeuco := 0;
           v_tot_dev_no_cob := nvl(reg.dev_no_cobrado,0);
           ww_ttdeuda := fu_con_a_guaranies(reg.cod_moneda, nvl(reg.monto,0) + nvl(v_tot_dev_no_cob,0));
           v_tot_dev_no_cob := fu_con_a_guaranies(reg.cod_moneda, nvl(v_tot_dev_no_cob,0));
           ---2. inserto el registro de la operacion ----------------------
           rv_oper.cod_persona         := reg.cod_persona;
           rv_oper.nro_cuenta          := reg.nro_cuenta;
           rv_oper.cod_modulo          := reg.cod_modulo;
           rv_oper.cod_modalidad       := reg.cod_modalidad;
           rv_oper.cod_estado          := reg.estado;
           rv_oper.tot_deu_real        := ww_ttdeuda;
           rv_oper.tot_deu_contingente := ww_ttdeuco;
           rv_oper.dev_no_cobrado      := v_tot_dev_no_cob;
           rv_oper.dia_atraso          := 0;
           rv_oper.cod_moneda          := reg.cod_moneda;
           rv_oper.cod_oficina         := reg.cod_oficina;
           rv_oper.tipo                := 'A';
           rv_oper.cod_rub_economico   := reg.cod_rub_economico;
           rv_oper.mto_original        := nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0);
           pr_ins_sb_cla_operac(rv_oper);
        END LOOP;
     END;

   /* Proceso de categorizacion de prestamos. */
      PROCEDURE pr_pro_dat_prestamo IS
      --recupera la deuda de clientes x prestamos
      CURSOR prestamos IS
         SELECT b.cod_persona,
                a.nro_cuenta,
                a.cod_modulo,
                a.fec_inicio,
                a.cod_modalidad,
                a.cod_moneda,
                a.nro_solicitud,
                nvl(a.sal_capital, 0) sal_cap_batch,
                nvl(a.dia_atraso, 0) dia_atraso,
                a.estado,
                decode(a.estado, 'I', nvl(a.sal_interes, 0) + nvl(a.sal_int_adelantado, 0),
                       a.dev_no_cobrado) dev_no_cobrado, -- agregado porque estado solo saldo de capital + interes adelantado
                a.cod_oficina,
                nvl(a.tip_renovacion, 'A') tipo,
                a.mto_capital,
                a.nro_cta_renovada,
                a.cat_renovaciones,
                nvl(a.dia_atr_3r, 0) dia_atr_3r,
                a.cat_pre_diferida,
                a.tip_destino,
                a.cod_sec_credito,
                a.fec_ult_categorizacion,
                a.cod_rub_economico ,  --circular 236,
                c.tipo tipo_cliente
           FROM ge_cta_clientes b, pr_cta_prestamos a, ge_clientes c
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            and b.cod_persona = c.cod_persona
            AND (
                 (nvl(a.sal_capital, 0) + nvl(a.sal_int_adelantado, 0) + nvl(a.sal_interes, 0) > 0 AND a.estado NOT IN ('N', 'I')) 
                 or (a.estado = 'N' and a.fec_cancelacion = v_fec_proceso)
                 or (a.estado != 'N' AND (SAL_CAP_BATCH + SAL_INT_BATCH >=0)) --> FIELDESK-156855
            )
            and not exists (select 1 from pr_vta_carteras x where x.nro_cuenta = a.nro_cuenta);
            -- agregamos para excluir vta cartera -- RS
            

      -- Cursor que recupera los MT BT.
      CURSOR c_mtbt IS
      SELECT ss.nro_cuenta, NVL(max(g.cat_automatica),1) cat_automatica
      FROM ge_cla_operaciones g, pr_cta_prestamos bb, ge_cta_dat_adicionales ss
          WHERE g.nro_cuenta = bb.nro_cuenta
            AND ss.nro_cuenta = g.nro_cuenta

            AND ss.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
            AND ((bb.estado NOT IN ('N', 'I')
            AND nvl(bb.sal_capital, 0) + nvl(bb.sal_int_adelantado, 0) + nvl(bb.sal_interes, 0) > 0) or (bb.estado = 'N' and bb.fec_cancelacion = v_fec_proceso) )
      GROUP BY ss.nro_cuenta
      ORDER BY ss.nro_cuenta;
      TYPE cursor_type IS TABLE OF prestamos%ROWTYPE;
      pr cursor_type;
      rv_oper          ge_cla_operaciones%ROWTYPE;
      v_tot_deuda      NUMBER(18, 2);
      v_dev_no_cobrado NUMBER(18, 2);
      v_tot_dev_no_cob NUMBER(18, 2);
      v_mto_original   NUMBER(18, 2);
      v_gar_operacion  NUMBER(18, 2);
      v_cliente        ge_cta_clientes.cod_persona%TYPE;
      v_cat_auto       ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_renov      ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_pre_diferida  ge_cla_operaciones.cat_automatica%TYPE;
      v_pue_categoria  VARCHAR2(01);
      v_pue_prevision  VARCHAR2(01);
      v_cat_operacion  NUMBER(5,3);
      v_dia_atraso     NUMBER(6);
      v_cat_mtbt       ge_cla_operaciones.cat_automatica%TYPE;
      v_can_mejora     number;
      v_ult_mejora     number;
      --Declaro variable
      TYPE type_ge_cla_ope IS TABLE OF ge_cla_operaciones%ROWTYPE;
      --Inicializo varaible
      reg_ge_cla_ope  type_ge_cla_ope not null:= type_ge_cla_ope();

--fieldesk-6099
      PROCEDURE pr_obt_for_pag_mt
       (
          p_nro_cuenta             IN ge_cuentas.nro_cuenta%TYPE,
          p_categoria              IN ge_cla_operaciones.cat_automatica%TYPE,
          p_mto_original           IN ge_cla_operaciones.mto_original%TYPE,
          p_sal_capital            IN ge_cla_operaciones.mto_original%TYPE,
          p_fec_ult_categorizacion IN pr_cta_prestamos.fec_ult_categorizacion%TYPE,
          p_pue_categoria          IN OUT VARCHAR2, --- Puede mejorar categoria S/N
          p_pue_prevision          IN OUT VARCHAR2,
          p_can_mejora             IN OUT number
       ) --- Puede liberar prevision S/N
        IS
          v_por_pago        NUMBER(15, 2);
          v_plazo           NUMBER(10);
          v_mto_capital     pr_cuotas.mto_capital%TYPE;
          v_mto_cap_cobrado pr_cobros.mto_capital%TYPE;
          --v_por_cat_mejora  NUMBER(2) := fug_obt_pardinamico('SIB_POR_CAT_MEJORADA');
          v_aux_can_mejora  number;
       BEGIN
          p_pue_categoria   := 'N';
          p_pue_prevision   := 'N';
          v_mto_capital     := fup_obt_mon_cob_mt(p_nro_cuenta,'R',p_fec_ult_categorizacion,v_nro_cta_madre);--Riesgo o saldo total de las operaciones

          v_mto_cap_cobrado := fup_obt_mon_cob_mt(p_nro_cuenta,'C',p_fec_ult_categorizacion,v_nro_cta_madre);--Cobro total de las operaciones segun corte correspondiente

          v_por_pago        := round((v_mto_cap_cobrado * 100) / v_mto_capital);


          --- calculo de mejora progresiva de categoria
          IF nvl(v_por_pago,0) >= 0 and nvl(v_por_pago,0) < 20 then  --si no alcanzo el 20% minimamente no mejora
             p_pue_categoria := 'N';
             p_pue_prevision := 'N';
             p_can_mejora    := 0;--NO HAY MEJORA
          ELSIF v_por_pago >= 20 AND v_por_pago < 40  THEN
             p_pue_categoria := 'S';
             p_pue_prevision := 'S';
             --p_can_mejora    := 1;
             v_aux_can_mejora := 1;--MEJORA 1
          ELSIF v_por_pago >= 40  AND v_por_pago < 60 THEN
             p_pue_categoria := 'S';
             p_pue_prevision := 'S';
             --p_can_mejora    := 2;--MEJORA 2
             v_aux_can_mejora    := 2;--MEJORA 2    := 2;--MEJORA 2
          ELSIF v_por_pago >= 60  AND v_por_pago < 80 THEN
             p_pue_categoria := 'S';
             p_pue_prevision := 'S';
             --p_can_mejora    := 3;--MEJORA 3
             v_aux_can_mejora    := 3;--MEJORA 3
          ELSIF v_por_pago >= 80 and v_por_pago < 100 then
             p_pue_categoria := 'S';
             p_pue_prevision := 'S';
             --p_can_mejora    := 4;--MEJORA 4
             v_aux_can_mejora    := 4;--MEJORA 4
          ELSE
             p_pue_categoria := 'S';
             p_pue_prevision := 'S';
             --p_can_mejora    := 5;--MEJORA 5
             v_aux_can_mejora := 5;--MEJORA 5
          END IF;


          IF p_pue_categoria = 'S' OR p_pue_prevision = 'S' THEN
            --obtencion de la tabla historica,la ultima mejora de la cuenta
            begin
              select mejora
              into v_ult_mejora
              from (select m.mejora, m.fec_mejora
                    from PR_CTA_MT_CAT_MEJORA m
                    where m.nro_cuenta = p_nro_cuenta--por cada cuenta evaluada
                    order by 2 desc) a
              where rownum = 1;
            exception
              when no_data_found then--si aun no mejoro devolver 0
                v_ult_mejora := 0;
            end;

            --si hubo mejora anterior,restar cantidad a mejorar actualmente de la ultima anterior
            if v_ult_mejora > 0 then

               --p_can_mejora := p_can_mejora - v_ult_mejora;
               p_can_mejora := v_aux_can_mejora - v_ult_mejora;

            end if;

            --solo si el resultado es mayor a 0 actualizo cuenta y guardo historico de mejora
            if nvl(p_can_mejora,0) > 0 then

            --
            --si resultado es mayor a cero actualizo fec_ult_Categorizacion e inserto en tabla historica
            --devuelvo valor real a restar de categoria actual al proceso principal.
             UPDATE pr_cta_prestamos
                SET fec_ult_categorizacion = v_fec_proceso
              WHERE nro_cuenta = p_nro_cuenta;

              insert into PR_CTA_MT_CAT_MEJORA
                (nro_cuenta, mejora, Fec_Mejora)
              values
                (p_nro_cuenta, v_aux_can_mejora, v_fec_proceso);
            else
               p_pue_categoria := 'N';
               p_pue_prevision := 'N';
               p_can_mejora := 0;--NO HAY MEJORA
            end if;
          END IF;
       END;

--

      FUNCTION fl_rec_deu_codeudor(p_cliente IN ge_clientes.cod_persona%TYPE) RETURN NUMBER IS
         v_tot_codeudor ge_cla_operaciones.tot_deu_contingente%TYPE;
      BEGIN
         SELECT nvl(SUM(nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0)), 0)
           INTO v_tot_codeudor
           FROM pr_cta_prestamos p, pr_cta_garantias a
          WHERE p.nro_cuenta = a.nro_cuenta
            AND a.cod_garantia = 2 -- codeudoria
            AND a.nro_garantia = p_cliente
            AND p.estado NOT IN ('N', 'I')
            AND fup_obt_tip_bono(p.cod_modalidad) = 'N'
            AND fup_obt_tip_letra(p.cod_modalidad) = 'N'
            AND fup_obt_tip_afd(p.cod_modalidad) = 'N';
         RETURN v_tot_codeudor;
      END;

      PROCEDURE pr_obt_mto_prevision
      (
         p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
         p_prevision     IN OUT pr_previsiones.monto%TYPE,
         p_pri_prevision IN OUT pr_previsiones.tot_pri_prevision%TYPE
      ) IS
      BEGIN
        /* SELECT monto, tot_pri_prevision
           INTO p_prevision, p_pri_prevision
           FROM (SELECT pr.monto, pr.tot_pri_prevision
                   FROM pr_previsiones pr
                  WHERE pr.nro_cuenta = p_nro_cuenta
                  ORDER BY fecha DESC)
          WHERE rownum = 1;*/
           SELECT monto, tot_pri_prevision
           INTO p_prevision, p_pri_prevision
           FROM pr_previsiones pr
           where pr.nro_cuenta = p_nro_cuenta
             and pr.fecha =
           (SELECT max(pr1.fecha)
                   FROM pr_previsiones pr1
                  WHERE pr1.nro_cuenta = p_nro_cuenta
                  );

      EXCEPTION
         WHEN no_data_found THEN
            p_prevision     := 0;
            p_pri_prevision := 0;
      END;
      --- Consideraciones: Queda definido que se categoriza al prestamo
      --- con la Clasificacion obtenida por el cliente el dia de ayer.
   BEGIN
     IF prestamos%ISOPEN THEN
       CLOSE prestamos;
     END IF;
     ----------------------
     OPEN prestamos;
     LOOP
     FETCH prestamos BULK COLLECT
        INTO pr LIMIT 90000;
      FOR i IN 1.. pr.count LOOP
         v_lugar   := 'Procesando prestamo Nro. ' || pr(i).nro_cuenta; --
         v_cliente := pr(i).cod_persona;
         v_tipo_clie := nvl(pr(i).tipo_cliente,'X');
         --- EXTORNO de interes
         --- por cada operacion de credito, su categoria  para extornar
         IF pr(i).dia_atraso > 0 or nvl(pr(i).dia_atr_3r, 0) > 0 THEN
            IF nvl(pr(i).dia_atr_3r, 0) > 0 THEN
               --debe empeorar
               v_cat_auto := fu_obt_categ_x_mora(pr(i).dia_atr_3r);
            ELSIF pr(i).dia_atraso > 0 THEN
               v_cat_auto := fu_obt_categ_x_mora(pr(i).dia_atraso);
            END IF;
         ELSE
            v_cat_auto := 1;
         END IF;
         v_pue_categoria := 'N';
         v_cat_renov     := NULL;
         v_cat_pre_diferida := null;
         v_pue_prevision := null;
         IF pr(i).cat_renovaciones IS NOT NULL THEN
            --IF nvl(pr(i).dia_atr_3r, 0) = 0 THEN --quiere decir que no arrastra la mora, que puede mejorar tbn,.
            v_cat_renov := pr(i).cat_renovaciones;
            -- Verificar si puede mejorar su categoria
            pap_cat.pr_obt_for_pag_rrr(pr(i).nro_cuenta, v_cat_renov, nvl(pr(i).mto_capital, 0),
                                       nvl(pr(i).sal_cap_batch, 0), pr(i).fec_ult_categorizacion,
                                       v_pue_categoria, v_pue_prevision);
            IF v_pue_categoria = 'S' THEN
               IF v_cat_renov >= 2 THEN
                  v_cat_renov := v_cat_renov - 1;
               ELSE
                  v_cat_renov := 1;
               END IF;
            END IF;
            --
            -- es un credito refinanciado, directamente debe tener 3, porque aun
            -- no pago ni el 10% de su credito original
            IF v_cat_auto < v_cat_renov THEN
               --- Si por mora tiene una categoria peor no debe mejorar
               v_cat_auto := v_cat_renov;
            END IF;
            --  END IF;
         END IF;
         --busqueda que determina si la cuenta es una MT (trae cuenta madre) fieldesk-6099
         begin
         select distinct (mm.nro_cuenta)
           into v_nro_cta_madre
           from ge_cta_dat_adicionales mm
          where mm.parametro in
                ('PRE_RRR_CTA_MBT', 'PRE_RRR_CTA_MBT1', 'PRE_RRR_CTA_MBT2')
            and (mm.nro_cuenta = pr(i).nro_cuenta or mm.val_parametro = pr(i).nro_cuenta);
         exception
           when no_Data_found then
             v_nro_cta_madre := null;
         end;
         -------------------------------------------------------------------------
         --para medida excepcional.
         IF pr(i).cat_pre_diferida IS NOT NULL THEN
           if v_nro_cta_madre is not null then --fieldesk-6099
            v_cat_pre_diferida := pr(i).cat_pre_diferida;
            -- Verificar si puede mejorar su categoria
           /*pr_obt_for_pag_mt(pr(i).nro_cuenta, v_cat_pre_diferida, nvl(pr(i).mto_capital, 0),
                                       nvl(pr(i).sal_cap_batch, 0), pr(i).fec_ult_categorizacion,
                                       v_pue_categoria, v_pue_prevision, v_can_mejora);*/
            IF v_pue_categoria = 'S' THEN
              if v_can_mejora > 0 then
                v_cat_pre_diferida := v_cat_pre_diferida - v_can_mejora;
              end if;
              --no dejar cero ni negativo agrega evaluacion de abajo
              if v_cat_pre_diferida <= 0 then
                 v_cat_pre_diferida := 1;
              end if;
               /*IF v_cat_pre_diferida >= 2 THEN
                  v_cat_pre_diferida := v_cat_pre_diferida - 1;
               ELSE
                  v_cat_pre_diferida := 1;
               END IF;*/
            END IF;
            --
            -- es un credito refinanciado, directamente debe tener 3, porque aun
            -- no pago ni el 10% de su credito original
            IF v_cat_auto < v_cat_pre_diferida THEN
               --- Si por mora tiene una categoria peor no debe mejorar
               v_cat_auto := v_cat_pre_diferida;
           /* ELSIF v_cat_pre_diferida < v_cat_auto THEN --obs fieldes de R1 --no debe empeorar pre_diferida
               v_cat_pre_diferida := v_cat_auto;*/
            END IF;
/*           else

            v_cat_pre_diferida := pr(i).cat_pre_diferida;
            -- Verificar si puede mejorar su categoria
            pap_cat.pr_obt_for_pag_rrr(pr(i).nro_cuenta, v_cat_pre_diferida, nvl(pr(i).mto_capital, 0),
                                       nvl(pr(i).sal_cap_batch, 0), pr(i).fec_ult_categorizacion,
                                       v_pue_categoria, v_pue_prevision);
            IF v_pue_categoria = 'S' THEN
               IF v_cat_pre_diferida >= 2 THEN
                  v_cat_pre_diferida := v_cat_pre_diferida - 1;
               ELSE
                  v_cat_pre_diferida := 1;
               END IF;
            END IF;
            --
            -- es un credito refinanciado, directamente debe tener 3, porque aun
            -- no pago ni el 10% de su credito original
            IF v_cat_auto < v_cat_pre_diferida THEN
               --- Si por mora tiene una categoria peor no debe mejorar
               v_cat_auto := v_cat_pre_diferida;
            ELSIF v_cat_pre_diferida < v_cat_auto THEN --obs fieldes de R1 --no debe empeorar pre_diferida
               v_cat_pre_diferida := v_cat_auto;
            END IF;
           end if;*/
          end if;
         END IF;

         -- Inicializo el dev no cobrado
         v_dev_no_cobrado := nvl(pr(i).dev_no_cobrado, 0);
         ---1. calculo la deuda en la moneda local ----------------------
         v_tot_deuda      := fu_con_a_guaranies(pr(i).cod_moneda,
                                                nvl(pr(i).sal_cap_batch, 0) + nvl(v_dev_no_cobrado, 0));
         v_tot_dev_no_cob := fu_con_a_guaranies(pr(i).cod_moneda, nvl(v_dev_no_cobrado, 0));
         --2. garantias x operacion
         v_gar_operacion := fu_obt_tot_gar_x_ope(pr(i).nro_cuenta, v_tot_deuda);
         ---4. inserto el registro de la operacion ----------------------
         -- Veo el monto original de la operacion------------------------
         v_mto_original := nvl(pr(i).mto_capital, 0);
         IF pr(i).tipo <> 'A' THEN
            -- es una operacion renovada, busco el monto original del credito
            BEGIN
               SELECT mto_capital
                 INTO v_mto_original
                 FROM pr_cta_prestamos
                WHERE nro_cuenta = pr(i).nro_cta_renovada;
            EXCEPTION
               WHEN OTHERS THEN
                  -- sino encuentra o tiene problemas en la busqueda se asigna el actual
                  v_mto_original := nvl(pr(i).mto_capital, 0);
            END;
         END IF;
         -- inserto el registro de la operacion --------------------------
         /*rv_oper.cod_persona         := pr(i).cod_persona;
         rv_oper.nro_cuenta          := pr(i).nro_cuenta;
         rv_oper.cod_modulo          := pr(i).cod_modulo;
         rv_oper.cod_modalidad       := pr(i).cod_modalidad;
         rv_oper.cod_estado          := pr(i).estado;
         rv_oper.tot_deu_real        := v_tot_deuda;
         rv_oper.tot_deu_contingente := 0;
         rv_oper.dev_no_cobrado      := v_tot_dev_no_cob;
         rv_oper.tot_gar_computables := v_gar_operacion;
         IF NVL(pr(i).dia_atr_3r, 0) > pr(i).dia_atraso THEN
            rv_oper.dia_atraso      := pr(i).dia_atr_3r;
         ELSE
            rv_oper.dia_atraso      := pr(i).dia_atraso;
         END IF;
         rv_oper.cod_moneda          := pr(i).cod_moneda;
         rv_oper.cod_oficina         := pr(i).cod_oficina;
         rv_oper.tipo                := pr(i).tipo;
         rv_oper.cat_renovaciones    := v_cat_renov;
         rv_oper.cat_ren_anterior    := pr(i).cat_renovaciones;
         rv_oper.lib_prevision       := v_pue_prevision;
         rv_oper.cat_automatica      := v_cat_auto;
         rv_oper.cat_pre_diferida    := v_cat_pre_diferida;
         rv_oper.tip_destino         := pr(i).tip_destino;
         rv_oper.cod_rub_economico   := pr(i).cod_rub_economico;
         rv_oper.cod_sec_credito     := nvl(pr(i).cod_sec_credito, 701);
         pr_obt_mto_prevision(pr(i).nro_cuenta, rv_oper.tot_prevision, rv_oper.tot_pri_prevision);
         rv_oper.tot_prevision     := pap_cat.fu_con_a_guaranies(pr(i).cod_moneda,
                                                                 rv_oper.tot_prevision);
         rv_oper.tot_pri_prevision := pap_cat.fu_con_a_guaranies(pr(i).cod_moneda,
                                                                 rv_oper.tot_pri_prevision);
         -- se pasa el monto original del credito a guaranies ------------
         rv_oper.mto_original := fu_con_a_guaranies(pr(i).cod_moneda, v_mto_original);
         pr_ins_sb_cla_operac(rv_oper);*/
         reg_ge_cla_ope.extend();
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_persona         := pr(i).cod_persona;
         reg_ge_cla_ope(reg_ge_cla_ope.count).nro_cuenta          := pr(i).nro_cuenta;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modulo          := pr(i).cod_modulo;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modalidad       := pr(i).cod_modalidad;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_estado          := pr(i).estado;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_real        := v_tot_deuda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_contingente := 0;
         reg_ge_cla_ope(reg_ge_cla_ope.count).dev_no_cobrado      := v_tot_dev_no_cob;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_gar_computables := v_gar_operacion;
         IF NVL(pr(i).dia_atr_3r, 0) > pr(i).dia_atraso THEN
            reg_ge_cla_ope(reg_ge_cla_ope.count).dia_atraso      := pr(i).dia_atr_3r;
         ELSE
            reg_ge_cla_ope(reg_ge_cla_ope.count).dia_atraso      := pr(i).dia_atraso;
         END IF;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_moneda          := pr(i).cod_moneda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_oficina         := pr(i).cod_oficina;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tipo                := pr(i).tipo;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cat_renovaciones    := v_cat_renov;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cat_ren_anterior    := pr(i).cat_renovaciones;
         reg_ge_cla_ope(reg_ge_cla_ope.count).lib_prevision       := v_pue_prevision;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cat_automatica      := v_cat_auto;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cat_pre_diferida    := v_cat_pre_diferida;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tip_destino         := pr(i).tip_destino;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_rub_economico   := pr(i).cod_rub_economico;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_sec_credito     := nvl(pr(i).cod_sec_credito, 701);
         pr_obt_mto_prevision(pr(i).nro_cuenta, reg_ge_cla_ope(reg_ge_cla_ope.count).tot_prevision, reg_ge_cla_ope(reg_ge_cla_ope.count).tot_pri_prevision);
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_prevision     := pap_cat.fu_con_a_guaranies(pr(i).cod_moneda, reg_ge_cla_ope(reg_ge_cla_ope.count).tot_prevision);
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_pri_prevision := pap_cat.fu_con_a_guaranies(pr(i).cod_moneda, reg_ge_cla_ope(reg_ge_cla_ope.count).tot_pri_prevision);
         -- se pasa el monto original del credito a guaranies ------------
         reg_ge_cla_ope(reg_ge_cla_ope.count).mto_original := fu_con_a_guaranies(pr(i).cod_moneda, v_mto_original);


         --- Actualizar categoria de renovacion para mejorar categoria final
         IF v_cat_renov IS NOT NULL AND v_cat_renov <> pr(i).cat_renovaciones THEN
            UPDATE pr_cta_prestamos
               SET cat_renovaciones = v_cat_renov
             WHERE nro_cuenta = pr(i).nro_cuenta;
         END IF;
         --- Actualizar categoria de renovacion para mejorar categoria final
         IF v_cat_pre_diferida IS NOT NULL AND v_cat_pre_diferida <> pr(i).cat_pre_diferida THEN
            UPDATE pr_cta_prestamos
               SET cat_pre_diferida = v_cat_pre_diferida,
                   dia_atr_3r = 0,
                   dia_atr_original = 0
             WHERE nro_cuenta = pr(i).nro_cuenta;
         END IF;
      END LOOP;
    EXIT WHEN prestamos%NOTFOUND;
    END LOOP;
    CLOSE prestamos;

      FORALL i IN 1 .. reg_ge_cla_ope.COUNT
          insert into ge_cla_operaciones
             (cod_persona,
              nro_cuenta,
              cod_modulo,
              cod_modalidad,
              cod_estado,
              tot_deu_real,
              tot_deu_contingente,
              dev_no_cobrado,
              tot_gar_computables,
              dia_atraso,
              cod_moneda,
              cod_oficina,
              tipo,
              cat_renovaciones,
              cat_ren_anterior,
              lib_prevision,
              cat_automatica,
              cat_pre_diferida,
              tip_destino,
              cod_rub_economico,
              cod_sec_credito,
              tot_prevision,
              tot_pri_prevision,
              mto_original)
          values
             (reg_ge_cla_ope(i).cod_persona,
              reg_ge_cla_ope(i).nro_cuenta,
              reg_ge_cla_ope(i).cod_modulo,
              reg_ge_cla_ope(i).cod_modalidad,
              reg_ge_cla_ope(i).cod_estado,
              reg_ge_cla_ope(i).tot_deu_real,
              reg_ge_cla_ope(i).tot_deu_contingente,
              reg_ge_cla_ope(i).dev_no_cobrado,
              reg_ge_cla_ope(i).tot_gar_computables,
              reg_ge_cla_ope(i).dia_atraso,
              reg_ge_cla_ope(i).cod_moneda,
              reg_ge_cla_ope(i).cod_oficina,
              reg_ge_cla_ope(i).tipo,
              reg_ge_cla_ope(i).cat_renovaciones,
              reg_ge_cla_ope(i).cat_ren_anterior,
              reg_ge_cla_ope(i).lib_prevision,
              reg_ge_cla_ope(i).cat_automatica,
              reg_ge_cla_ope(i).cat_pre_diferida,
              reg_ge_cla_ope(i).tip_destino,
              reg_ge_cla_ope(i).cod_rub_economico,
              reg_ge_cla_ope(i).cod_sec_credito,
              reg_ge_cla_ope(i).tot_prevision,
              reg_ge_cla_ope(i).tot_pri_prevision,
              reg_ge_cla_ope(i).mto_original);

      --
      for reg in c_mtbt loop
         select NVL(MAX(ge.cat_automatica),1)
           into v_cat_mtbt
           from ge_cla_operaciones ge
          where ge.nro_cuenta in
           (select mm.val_parametro
              from ge_cta_dat_adicionales mm
             where mm.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
               and mm.nro_cuenta = reg.nro_cuenta);

         -- Verifico la categoria.
         if reg.cat_automatica > v_cat_mtbt then
            update ge_cla_operaciones gc
               set gc.cat_automatica = reg.cat_automatica
             where gc.nro_cuenta in (select mm.val_parametro
              from ge_cta_dat_adicionales mm
             where mm.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
               and mm.nro_cuenta = reg.nro_cuenta);
         else
             update ge_cla_operaciones gc
               set gc.cat_automatica = v_cat_mtbt
             where gc.nro_cuenta = reg.nro_cuenta;

              update ge_cla_operaciones gc
               set gc.cat_automatica = v_cat_mtbt
             where gc.nro_cuenta in (select mm.val_parametro
              from ge_cta_dat_adicionales mm
             where mm.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
               and mm.nro_cuenta = reg.nro_cuenta);
         end if;
      end loop;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. prestamo ' || SQLERRM);
   END;

   /* Procesar categorización de cuentas corrientes sobregiradas. */
   PROCEDURE pr_pro_dat_sobregiro IS
      CURSOR ctasctes IS
      -- las que tienen sobregiro y/o linea..... solamente
         SELECT g.cod_persona,
                g.cod_modulo,
                g.cod_modalidad,
                g.cod_oficina,
                g.nro_cuenta,
                g.cod_moneda,
                g.sal_actual,
                g.estado,
                g.dias_sobregiro,
                g.linea,
                f.mnto_prevision,
                f.mnto_tot_pri_prevision
           FROM pv_cat_sobregiros g,
                (SELECT nvl(pr.monto, 0) mnto_prevision,
                        nvl(pr.tot_pri_prevision, 0) mnto_tot_pri_prevision,
                        pr.nro_cuenta
                   FROM cc_previsiones pr
                  WHERE pr.fecha = (SELECT MAX(pv.fecha)
                                      FROM cc_previsiones pv
                                     WHERE pr.nro_cuenta = pv.nro_cuenta)) f
          WHERE f.nro_cuenta(+) = g.nro_cuenta
          ORDER BY cod_moneda;

      rv_oper        ge_cla_operaciones%ROWTYPE;
      ww_ttdeuda     NUMBER(18);
      ww_ttdeuco     NUMBER(18);
      v_mon_anterior ov_cta_vencidas.cod_moneda%TYPE;
      v_redondeo     NUMBER;
      v_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      --Declaro variable
      TYPE type_ge_cla_ope IS TABLE OF ge_cla_operaciones%ROWTYPE;
      --Inicializo varaible
      reg_ge_cla_ope  type_ge_cla_ope not null:= type_ge_cla_ope();
   BEGIN
      dbms_mview.refresh('PV_CAT_SOBREGIROS');
      v_mon_anterior := v_mon_local;
      v_cotizacion   := 1;
      v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_mon_local);
      FOR cc IN ctasctes LOOP
         v_lugar := 'Procesando la Cuenta Corriente Nro. ' || cc.nro_cuenta;
         ---1. cálculo la deuda en la moneda local ----------------------
         IF v_mon_anterior <> cc.cod_moneda THEN
            IF cc.cod_moneda <> v_mon_local THEN
               v_cotizacion := pag_gen.fu_obt_cotizacion(cc.cod_moneda, v_fec_proceso);
            ELSE
               -- es moneda local - guaraníes -------------------------------
               v_cotizacion := 1;
            END IF;
         END IF;
         ww_ttdeuda := round(nvl(cc.sal_actual, 0) * v_cotizacion, v_redondeo);
         --- Verifico si tiene acuerdo permanente para la contingencia --???????
         IF abs(cc.sal_actual) >= cc.linea THEN
            ww_ttdeuco := 0;
         ELSE
            ww_ttdeuco := round((cc.linea - abs(cc.sal_actual)) * v_cotizacion, v_redondeo);
         END IF;
         ---3. inserto el registro de la operación ----------------------
/*         rv_oper.cod_persona         := cc.cod_persona;
         rv_oper.nro_cuenta          := cc.nro_cuenta;
         rv_oper.cod_modulo          := cc.cod_modulo;
         rv_oper.cod_modalidad       := cc.cod_modalidad;
         rv_oper.cod_estado          := cc.estado;
         rv_oper.tot_deu_real        := abs(ww_ttdeuda); --valor absoluto xq el sobregiro puede estar en negativo y para ponderar no funciona  --ww_ttdeuda;
         rv_oper.tot_deu_contingente := nvl(ww_ttdeuco, 0);
         rv_oper.dia_atraso          := nvl(cc.dias_sobregiro, 1);
         rv_oper.cod_moneda          := cc.cod_moneda;
         rv_oper.cod_oficina         := cc.cod_oficina;
         rv_oper.tipo                := 'A';
         rv_oper.mto_original        := abs(ww_ttdeuda);
         rv_oper.tot_prevision       := pap_cat.fu_con_a_guaranies(cc.cod_moneda, cc.mnto_prevision);
         rv_oper.tot_pri_prevision   := pap_cat.fu_con_a_guaranies(cc.cod_moneda,
                                                                   cc.mnto_tot_pri_prevision);
         -- Requerimiento: CNFAIRUNO-3.
         -- Fecha: 22/09/2014.
         -- Las Cuentas en Sobregiro que corresponden a Nomina siempre se debe considerar como Consumo.
         IF cc.linea > 0 THEN
            rv_oper.cod_sec_credito     := 701; --Consumo.
            rv_oper.tip_destino         := 4;
         ELSE
            rv_oper.cod_sec_credito     := NVL(fu_obt_cod_actividad(cc.cod_persona),701);
            rv_oper.tip_destino         := fu_obt_tip_destino(cc.cod_persona, cc.cod_modulo, cc.cod_modalidad, rv_oper.cod_sec_credito, abs(ww_ttdeuda));
         END IF;
         pr_ins_sb_cla_operac(rv_oper);*/
         reg_ge_cla_ope.extend();
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_persona         := cc.cod_persona;
         reg_ge_cla_ope(reg_ge_cla_ope.count).nro_cuenta          := cc.nro_cuenta;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modulo          := cc.cod_modulo;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modalidad       := cc.cod_modalidad;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_estado          := cc.estado;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_real        := abs(ww_ttdeuda); --valor absoluto xq el sobregiro puede estar en negativo y para ponderar no funciona  --ww_ttdeuda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_contingente := nvl(ww_ttdeuco, 0);
         reg_ge_cla_ope(reg_ge_cla_ope.count).dia_atraso          := nvl(cc.dias_sobregiro, 1);
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_moneda          := cc.cod_moneda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_oficina         := cc.cod_oficina;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tipo                := 'A';
         reg_ge_cla_ope(reg_ge_cla_ope.count).mto_original        := abs(ww_ttdeuda);
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_prevision       := pap_cat.fu_con_a_guaranies(cc.cod_moneda, cc.mnto_prevision);
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_pri_prevision   := pap_cat.fu_con_a_guaranies(cc.cod_moneda,
                                                                   cc.mnto_tot_pri_prevision);
         IF cc.linea > 0 THEN
            reg_ge_cla_ope(reg_ge_cla_ope.count).cod_sec_credito     := 701; --Consumo.
            reg_ge_cla_ope(reg_ge_cla_ope.count).tip_destino         := 4;
         ELSE
            reg_ge_cla_ope(reg_ge_cla_ope.count).cod_sec_credito     := NVL(fu_obt_cod_actividad(cc.cod_persona),701);
            reg_ge_cla_ope(reg_ge_cla_ope.count).tip_destino         := fu_obt_tip_destino(cc.cod_persona, cc.cod_modulo, cc.cod_modalidad, reg_ge_cla_ope(reg_ge_cla_ope.count).cod_sec_credito, abs(ww_ttdeuda));
         END IF;
         v_mon_anterior := cc.cod_moneda;
      END LOOP;
      FORALL i in 1 .. reg_ge_cla_ope.count
        INSERT INTO ge_cla_operaciones
         (cod_persona,
          nro_cuenta,
          cod_modulo,
          cod_modalidad,
          cod_estado,
          tot_deu_real,
          tot_deu_contingente,
          dia_atraso,
          cod_moneda,
          cod_oficina,
          tipo,
          mto_original,
          tot_prevision,
          tot_pri_prevision,
          cod_sec_credito,
          tip_destino)
        values
         (reg_ge_cla_ope(i).cod_persona,
          reg_ge_cla_ope(i).nro_cuenta,
          reg_ge_cla_ope(i).cod_modulo,
          reg_ge_cla_ope(i).cod_modalidad,
          reg_ge_cla_ope(i).cod_estado,
          reg_ge_cla_ope(i).tot_deu_real,
          reg_ge_cla_ope(i).tot_deu_contingente,
          reg_ge_cla_ope(i).dia_atraso,
          reg_ge_cla_ope(i).cod_moneda,
          reg_ge_cla_ope(i).cod_oficina,
          reg_ge_cla_ope(i).tipo,
          reg_ge_cla_ope(i).mto_original,
          reg_ge_cla_ope(i).tot_prevision,
          reg_ge_cla_ope(i).tot_pri_prevision,
          reg_ge_cla_ope(i).cod_sec_credito,
          reg_ge_cla_ope(i).tip_destino);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. Sobregiro ' || SQLERRM);
   END;

   /* Procesar categorizacion de tarjetas de credito. */
   PROCEDURE pr_pro_dat_tarjetas IS
      --- Deudas de tarjetas ----------------------------------------------
      CURSOR tarjetas IS
         SELECT b.cod_persona,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                a.cod_moneda,
                nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) + nvl(a.sal_financiado, 0) +
                nvl(a.sal_cuo_pendientes, 0) saldo,
                nvl(a.lin_credito, 0) + nvl(a.lin_cuotas, 0) linea_de_credito,
                nvl(a.dia_mora, 0) dia_mora,
                a.estado,
                a.cod_rub_economico  --circular 236
           FROM ge_cta_clientes b, ta_cta_tarjetas a
          WHERE b.nro_cuenta = a.nro_cuenta
            --and b.cod_persona in ('8637936','8681919')
            AND b.relacion = 'P' --y principales de cuenta;
            AND ((a.estado <> 'C'
            AND EXISTS (SELECT t.nro_cuenta
                   FROM ta_tarjetas t
                  WHERE t.nro_cuenta = a.nro_cuenta
                    AND t.vigente = 'S')) or (a.estado = 'C' and a.fec_cancelacion = v_fec_proceso))--ajustado para tener en cuenta calif 1 por cancelacion fieldesk-5175
            AND NOT EXISTS (select o.nro_cuenta
                              from ge_cla_operaciones_tmp o
                             where o.nro_cuenta = a.nro_cuenta);--CIE-73 agregado para procesar los registros que no existen en el temporal
      rv_oper    ge_cla_operaciones%ROWTYPE;
      ww_ttdeuda NUMBER(18);
      ww_ttdeuco NUMBER(18);
      v_gar_operacion  NUMBER(18,2);
      --Declaro variable
      TYPE type_ge_cla_ope IS TABLE OF ge_cla_operaciones%ROWTYPE;
      --Inicializo varaible
      reg_ge_cla_ope  type_ge_cla_ope not null:= type_ge_cla_ope();
      FUNCTION fl_obt_mto_prevision(p_nro_cuenta IN ta_cta_tarjetas.nro_cuenta%TYPE) RETURN NUMBER IS
         v_prevision ta_previsiones.monto%TYPE;
      BEGIN
         SELECT pr.monto
           INTO v_prevision
           FROM ta_previsiones pr
          WHERE pr.fecha =
                (SELECT MAX(pv.fecha) FROM ta_previsiones pv WHERE pr.nro_cuenta = pv.nro_cuenta)
            AND pr.nro_cuenta = p_nro_cuenta;
         RETURN v_prevision;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN 0;
      END;

   BEGIN
       FOR ta IN tarjetas LOOP
         v_lugar := 'Procesando la Tarjeta Nro. ' || ta.nro_cuenta;
         ---1. calculo la deuda en la moneda local ----------------------
         ww_ttdeuda := fu_con_a_guaranies(ta.cod_moneda, ta.saldo);
         IF ta.estado != 'B' THEN --FIELDESK-76691
           IF nvl(ta.saldo, 0) >= nvl(ta.linea_de_credito, 0) THEN
              ww_ttdeuco := 0;
           ELSE
              IF nvl(ww_ttdeuda, 0) < 0 THEN
               -- si tiene un credito (saldo neg.) se considera solo la linea
                 ww_ttdeuco := nvl(ta.linea_de_credito, 0);
                 ww_ttdeuda := 0;
              ELSE
                 ww_ttdeuco := (nvl(ta.linea_de_credito, 0) - nvl(ta.saldo, 0));
              END IF;
            END IF;
         ELSE
           ww_ttdeuco := 0;
           IF nvl(ww_ttdeuda, 0) < 0 THEN
             ww_ttdeuda := 0;
           end if;
         END IF;
         -- garantias x operacion
         v_gar_operacion := fu_obt_tot_gar_x_ope(ta.nro_cuenta, null);
         ww_ttdeuco := fu_con_a_guaranies(ta.cod_moneda, ww_ttdeuco);

         ---2. inserto el registro de la operacion ----------------------
         /*rv_oper.cod_persona         := ta.cod_persona;
         rv_oper.nro_cuenta          := ta.nro_cuenta;
         rv_oper.cod_modulo          := ta.cod_modulo;
         rv_oper.cod_modalidad       := ta.cod_modalidad;
         rv_oper.cod_estado          := ta.estado;
         rv_oper.tot_deu_real        := ww_ttdeuda;
         rv_oper.tot_deu_contingente := ww_ttdeuco;
         rv_oper.dia_atraso          := ta.dia_mora;
         rv_oper.cod_moneda          := ta.cod_moneda;
         rv_oper.cod_oficina         := ta.cod_oficina;
         rv_oper.tipo                := 'A';
         rv_oper.cod_sec_credito     := 701;
         rv_oper.mto_original        := nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0);
         rv_oper.tip_destino         := 4; --- Consumo
         rv_oper.cod_rub_economico   := ta.cod_rub_economico; ---circular 236
         rv_oper.tot_gar_computables := v_gar_operacion;
         rv_oper.tot_prevision       := pap_cat.fu_con_a_guaranies(ta.cod_moneda,
                                                                   fl_obt_mto_prevision(ta.nro_cuenta));
         pr_ins_sb_cla_operac(rv_oper);*/
         reg_ge_cla_ope.extend();
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_persona         := ta.cod_persona;
         reg_ge_cla_ope(reg_ge_cla_ope.count).nro_cuenta          := ta.nro_cuenta;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modulo          := ta.cod_modulo;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_modalidad       := ta.cod_modalidad;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_estado          := ta.estado;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_real        := ww_ttdeuda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_deu_contingente := ww_ttdeuco;
         reg_ge_cla_ope(reg_ge_cla_ope.count).dia_atraso          := ta.dia_mora;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_moneda          := ta.cod_moneda;
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_oficina         := ta.cod_oficina;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tipo                := 'A';
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_sec_credito     := 701;
         reg_ge_cla_ope(reg_ge_cla_ope.count).mto_original        := nvl(ww_ttdeuda, 0) + nvl(ww_ttdeuco, 0);
         reg_ge_cla_ope(reg_ge_cla_ope.count).tip_destino         := 4; --- Consumo
         reg_ge_cla_ope(reg_ge_cla_ope.count).cod_rub_economico   := ta.cod_rub_economico; ---circular 236
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_gar_computables := v_gar_operacion;
         reg_ge_cla_ope(reg_ge_cla_ope.count).tot_prevision       := pap_cat.fu_con_a_guaranies(ta.cod_moneda,
                                                                   fl_obt_mto_prevision(ta.nro_cuenta));
      END LOOP;
      FORALL i IN 1 .. reg_ge_cla_ope.COUNT
          insert into ge_cla_operaciones
          (cod_persona,
           nro_cuenta,
           cod_modulo,
           cod_modalidad,
           cod_estado,
           tot_deu_real,
           tot_deu_contingente,
           dia_atraso,
           cod_moneda,
           cod_oficina,
           tipo,
           cod_sec_credito,
           mto_original,
           tip_destino,
           cod_rub_economico,
           tot_gar_computables,
           tot_prevision)
          values
          (reg_ge_cla_ope(i).cod_persona,
           reg_ge_cla_ope(i).nro_cuenta,
           reg_ge_cla_ope(i).cod_modulo,
           reg_ge_cla_ope(i).cod_modalidad,
           reg_ge_cla_ope(i).cod_estado,
           reg_ge_cla_ope(i).tot_deu_real,
           reg_ge_cla_ope(i).tot_deu_contingente,
           reg_ge_cla_ope(i).dia_atraso,
           reg_ge_cla_ope(i).cod_moneda,
           reg_ge_cla_ope(i).cod_oficina,
           reg_ge_cla_ope(i).tipo,
           reg_ge_cla_ope(i).cod_sec_credito,
           reg_ge_cla_ope(i).mto_original,
           reg_ge_cla_ope(i).tip_destino,
           reg_ge_cla_ope(i).cod_rub_economico,
           reg_ge_cla_ope(i).tot_gar_computables,
           reg_ge_cla_ope(i).tot_prevision);

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. Tarjeta ' || SQLERRM);

   END;
   /* Proceso de categorizacion de Operaciones Vencidas. */
   PROCEDURE pr_pro_dat_ope_ven IS
      --recupera la deuda de clientes x prestamos
      CURSOR prestamos IS
         SELECT b.cod_persona,
                a.nro_cuenta,
                a.cod_modulo,
                a.cod_modalidad,
                a.cod_moneda,
                nvl(a.sal_tot_batch, 0) sal_cap_batch,
                nvl(a.dia_atraso, 0) dia_atraso,
                a.estado,
                a.cod_oficina,
                a.mto_origen mto_capital,
                a.cod_rub_economico   -- circular 236
           FROM ge_cta_clientes b, ov_cta_vencidas a
          WHERE a.nro_cuenta = b.nro_cuenta
             AND (
                (nvl(a.sal_total, 0) > 0 AND a.estado NOT IN ('C', 'I'))
                 OR 
                 (nvl(a.SAL_TOT_BATCH, 0) > 0 AND a.estado  IN ('C')))  --FIELDESK-156855
            AND b.relacion = 'P'; --y principales de cuenta

      rv_oper         ge_cla_operaciones%ROWTYPE;
      v_tot_deuda     NUMBER(18, 2);
      v_mto_original  NUMBER(18, 2);
      v_gar_operacion NUMBER(18, 2);
      v_cliente       ge_cta_clientes.cod_persona%TYPE;
      v_cat_auto      ge_cla_operaciones.cat_automatica%TYPE;

      --- Consideraciones: Queda definido que se categoriza a la cuenta
      --- con la Clasificacion obtenida por el cliente el dia de ayer.
   BEGIN
      FOR pr IN prestamos LOOP
         v_lugar   := 'Procesando prestamo Nro. ' || pr.nro_cuenta; --
         v_cliente := pr.cod_persona;
         --- Recuperar categoria del cliente
         BEGIN
            SELECT tipo INTO v_tipo_clie FROM ge_clientes WHERE cod_persona = v_cliente;
         EXCEPTION
            WHEN no_data_found THEN
               v_tipo_clie := 'X';
         END;
         -- se calcula la categoria de acuerdo a la mora-------------
         IF pr.dia_atraso > 0 THEN
            v_cat_auto := fu_obt_categ_x_mora(pr.dia_atraso);
         ELSE
            v_cat_auto := 1;
         END IF;
         ---1. calculo la deuda en la moneda local ----------------------
         v_tot_deuda := fu_con_a_guaranies(pr.cod_moneda, nvl(pr.sal_cap_batch, 0));
         --2. garantias x operacion
         v_gar_operacion := fu_obt_tot_gar_x_ope(pr.nro_cuenta, v_tot_deuda);
         ---4. inserto el registro de la operacion ----------------------
         -- Veo el monto original de la operacion------------------------
         v_mto_original := nvl(pr.mto_capital, 0);
         -- inserto el registro de la operacion --------------------------
         rv_oper.cod_persona         := pr.cod_persona;
         rv_oper.nro_cuenta          := pr.nro_cuenta;
         rv_oper.cod_modulo          := pr.cod_modulo;
         rv_oper.cod_modalidad       := pr.cod_modalidad;
         rv_oper.cod_estado          := pr.estado;
         rv_oper.tot_deu_real        := v_tot_deuda;
         rv_oper.tot_deu_contingente := 0;
         rv_oper.dev_no_cobrado      := 0;
         rv_oper.tot_gar_computables := v_gar_operacion;
         rv_oper.dia_atraso          := pr.dia_atraso;
         rv_oper.cod_moneda          := pr.cod_moneda;
         rv_oper.cod_oficina         := pr.cod_oficina;
         rv_oper.tipo                := 'A';
         rv_oper.cat_renovaciones    := NULL;
         rv_oper.cat_automatica      := v_cat_auto;
         rv_oper.tip_destino         := 4; -- Consumo
         rv_oper.cod_rub_economico   := pr.cod_rub_economico;
         rv_oper.cod_sec_credito     := NULL;
         -- se pasa el monto original del credito a guaranies ------------
         rv_oper.mto_original := fu_con_a_guaranies(pr.cod_moneda, v_mto_original);
         pr_ins_sb_cla_operac(rv_oper);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Proc. prestamo ' || SQLERRM);
   END;
   /* Insertar datos en la tabla ge_cla_operaciones. */
   PROCEDURE pr_ins_sb_cla_operac(rp_oper IN ge_cla_operaciones%ROWTYPE) IS
   BEGIN
      INSERT INTO ge_cla_operaciones
         (cod_persona, nro_cuenta, cod_modulo, cod_modalidad, cod_estado, tot_deu_real,
          tot_deu_contingente, dev_no_cobrado, cat_automatica, dia_atraso, cod_moneda,
          tot_gar_computables, cod_oficina, tipo, tot_prevision, mto_original, tip_destino,
          cod_sec_credito, cat_renovaciones, cat_ren_anterior, lib_prevision, tot_pri_prevision, cod_rub_economico, cat_pre_diferida)
      VALUES
         (rp_oper.cod_persona, rp_oper.nro_cuenta, rp_oper.cod_modulo, rp_oper.cod_modalidad,
          rp_oper.cod_estado, rp_oper.tot_deu_real, rp_oper.tot_deu_contingente,
          rp_oper.dev_no_cobrado, rp_oper.cat_automatica, rp_oper.dia_atraso, rp_oper.cod_moneda,
          rp_oper.tot_gar_computables, rp_oper.cod_oficina, rp_oper.tipo, rp_oper.tot_prevision,
          rp_oper.mto_original, rp_oper.tip_destino, rp_oper.cod_sec_credito,
          rp_oper.cat_renovaciones, rp_oper.cat_ren_anterior, rp_oper.lib_prevision,
          rp_oper.tot_pri_prevision, rp_oper.cod_rub_economico, rp_oper.cat_pre_diferida);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 SQLERRM || ' al Ins. ge_cla_operaciones Clie -' ||
                                  rp_oper.cod_persona || ' Cta. ' || rp_oper.nro_cuenta);
   END;
   /* Obtiene el valor total de las garantias x la operacion de prestamo. */
   FUNCTION fu_obt_tot_gar_x_ope
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_tot_deuda  IN NUMBER DEFAULT NULL --- para q siga funcionando con la Res. Actual
   ) RETURN NUMBER IS
      v_val_gara NUMBER(18, 2) := 0;
      v_tot_gara NUMBER(18, 2) := 0;
      CURSOR garantias IS
         SELECT a.cod_mon_ope ga_cdmoned, a.mto_apl_computable monto, cl.cat_riesgo, a.cod_garantia
           FROM it.gv_gar_categorizacion a,
                ge_clientes      cl,
                ge_cta_clientes  cc
          WHERE cl.cod_persona = cc.cod_persona
            AND cc.nro_cuenta = p_nro_cuenta
            AND cc.nro_cuenta=a.nro_cuenta
            AND cc.relacion = 'P';
   BEGIN

      FOR reg IN garantias LOOP
         v_val_gara := fu_con_a_guaranies(reg.ga_cdmoned, reg.monto);
         --- acumulo las garantias computables del prestamo ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_val_gara, 0);
      END LOOP;
      RETURN v_tot_gara;
   END;
   /* Verifica si el cliente esta relacionado con la entidad. */
   FUNCTION fu_ver_cli_rel_enti(p_cod_persona IN VARCHAR2) RETURN BOOLEAN IS
      v_count NUMBER := 0;
      --v_existe VARCHAR2(1);
   BEGIN
      SELECT COUNT(1)
      INTO v_count
      FROM ge_clientes g
     WHERE g.cod_persona = p_cod_persona
       AND NVL(g.cod_gru_economico, -1) = v_cod_gru_eco_entidad;
       RETURN v_count > 0;
   END;
   FUNCTION fu_obt_mto_capital
      (
         p_nro_cuenta             pr_cuotas.nro_cuenta%TYPE,
         p_fecha                  DATE,
         p_dias_atraso            pr_cta_prestamos.dia_atraso%TYPE,
         p_tip_saldo              VARCHAR2,
         p_tip_monto              VARCHAR2,
         p_fec_ult_categorizacion DATE,
         p_cod_modulo             ge_cuentas.cod_modulo%TYPE,
         p_valor                  varchar2 default 'C'
      ) RETURN NUMBER IS
         v_mto_cap_cobrado         pr_cuotas.mto_capital%TYPE;
         v_sal_cobrado             pr_cuotas.sal_capital%type;
         v_error                   number;
         v_mensaje                 varchar2(4000);
         v_sal_capital             pr_cuotas.sal_capital%TYPE;
         v_monto                   pr_cuotas.mto_capital%TYPE;
         v_cod_modulo              ge_cuentas.cod_modulo%TYPE;
         v_nro_cuo_desde           pr_cuotas.nro_cuota%TYPE;
         v_nro_cuo_hasta           pr_cuotas.nro_cuota%TYPE;
         v_cod_ofi_origen          pr_cta_prestamos.cod_oficina%type;
         v_sal_interes             pr_cuotas.sal_interes%type;
         v_sal_int_ade             pr_cuotas.sal_int_documentado%type;
         v_mora                    pr_cuotas.mto_capital%type;
         v_mora_interes            pr_cuotas.mto_capital%type;
         v_mora_int_ade            pr_cuotas.mto_capital%type;
         v_punitorio               pr_cuotas.mto_capital%type;
         v_impuesto                pr_cuotas.mto_capital%type;
         v_cargo                   pr_cuotas.mto_capital%type;
         v_cargo_iva               pr_cuotas.mto_capital%type;
         v_int_descontado          pr_cuotas.mto_interes%type;
         v_dia_mora                pr_cta_prestamos.dia_atraso%type;
         v_cod_tra_padre           ge_transacciones.cod_transaccion%type := 360;
         v_cancelacion             varchar2(1);
         v_renueva                 varchar2(1);
         v_cancel_rrr              varchar2(1);
         v_tot_deuda               ge_cla_operaciones.tot_deu_real%type;
         --v_fec_cobro               date := pae_cnf.fu_obt_fec_actual(6);
         /*
          p_tip_monto: 'M'(Cuando se debe recuperar el monto capital ó Interés total) - 'C'(Cuando se debe recuperar el capital ó Interés cobrado).
          p_tip_saldo: 'O'(Cuando se busca el saldo capital ó Interés original) - 'V'(Cuando se debe recuperar el saldo capital ó Interés vencido).
          p_valor    : 'H'( recuperar la deuda capital e intereses) - 'C'(Cuando se debe recuperar el monto capital) - 'I'(Cuando se debe recuperar el monto interés)
         */
      BEGIN
         v_cod_modulo:= p_cod_modulo;
         IF nvl(p_valor, 'C') = 'C' THEN
            IF v_cod_modulo = 6 THEN
               IF v_mto_cap_cobrado_aux IS NULL THEN
                 BEGIN
                    SELECT SUM(mto_capital)
                      INTO v_mto_cap_cobrado
                      FROM pr_cobros
                     WHERE nro_cuenta = p_nro_cuenta
                       AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
                 EXCEPTION
                    WHEN OTHERS THEN
                        v_mto_cap_cobrado := 0;
                 END;
                 v_mto_cap_cobrado_aux := v_mto_cap_cobrado;
               END IF;
               IF p_tip_monto = 'M' THEN
                  BEGIN
                     SELECT SUM(sal_capital)
                       INTO v_sal_capital
                       FROM pr_cuotas
                      WHERE nro_cuenta = p_nro_cuenta
                        AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                            (p_tip_saldo = 'O'));
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_sal_capital := 0;
                  END;
               END IF;
            ELSIF v_cod_modulo = 15 THEN
               BEGIN
                  SELECT SUM(mto_total)
                    INTO v_mto_cap_cobrado
                    FROM ov_cobros
                   WHERE nro_cuenta = p_nro_cuenta
                     AND fecha > p_fec_ult_categorizacion;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_mto_cap_cobrado := 0;
               END;
               IF p_tip_monto = 'M' THEN
                  BEGIN
                     SELECT sal_total
                       INTO v_sal_capital
                       FROM ov_cta_vencidas
                      WHERE nro_cuenta = p_nro_cuenta;
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_sal_capital := 0;
                  END;
               END IF;
            END IF;
            IF v_mto_cap_cobrado_aux IS NULL THEN
              v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_sal_capital, 0);
            ELSE
              v_monto := nvl(v_mto_cap_cobrado_aux, 0) + nvl(v_sal_capital, 0);
            END IF;
         ELSIF nvl(p_valor,'C') = 'H' THEN --Res 12 Préstamos Hip.
            IF v_cod_modulo = 6 THEN
               BEGIN
                  SELECT SUM(
                          nvl(a.mto_capital, 0) +
                          nvl(a.mto_interes, 0) +
                          nvl(a.mto_int_documentado, 0) +
                          nvl(a.mto_int_moratorio, 0) +
                          nvl(a.mto_int_mor_interes, 0) +
                          nvl(a.mto_int_mor_adelantado, 0) +
                          nvl(a.mto_int_punitorio,0) +
                          nvl(a.mto_cargo,0) +
                          nvl(a.mto_impuesto,0))
                    INTO v_mto_cap_cobrado
                    FROM pr_cobros a
                   WHERE nro_cuenta = p_nro_cuenta
                     AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_mto_cap_cobrado := 0;
               END;
               IF p_tip_monto = 'M' THEN
                  BEGIN
                     SELECT MIN(nro_cuota), MAX(nro_cuota)
                       INTO v_nro_cuo_desde, v_nro_cuo_hasta
                       FROM pr_cuotas
                      WHERE nro_cuenta = p_nro_cuenta
                        AND nro_cuota > 0
                        AND estado <> 'N'
                        AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                            (p_tip_saldo = 'O'));
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_nro_cuo_desde := null;
                        v_nro_cuo_hasta := null;
                  END;
                  --inicializar variables de cobro
                  pap_pre.pr_ini_var_cobro;
                  pap_pre.pr_ini_autorizacion;
                  pap_pre.pr_obt_deu_prestamo(p_nro_cuenta, v_fec_proceso, v_nro_cuo_desde, v_nro_cuo_hasta, v_cod_ofi_origen, v_sal_cobrado, v_error,
                                              v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes,
                                              v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado,
                                              v_dia_mora, v_cod_tra_padre, v_cancelacion,v_renueva,v_cancel_rrr);
                  commit;
                  v_tot_deuda := nvl(v_sal_capital,0)  +
                                 nvl(v_sal_interes,0)  +
                                 nvl(v_mora,0)         +
                                 nvl(v_mora_interes,0) +
                                 nvl(v_mora_int_ade,0) +
                                 nvl(v_punitorio,0)    +
                                 nvl(v_impuesto,0)     +
                                 nvl(v_cargo,0)      /*+
                                 nvl(v_cargo_iva,0)*/  ;
               END IF;
            END IF;
            v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_tot_deuda, 0);
         Elsif nvl(p_valor,'C') = 'I' Then
             BEGIN
                SELECT SUM(mto_interes)
                  INTO v_mto_cap_cobrado
                  FROM pr_cobros
                 WHERE nro_cuenta = p_nro_cuenta
                   AND (fecha > p_fec_ult_categorizacion OR p_fec_ult_categorizacion IS NULL);
             EXCEPTION
                WHEN OTHERS THEN
                   v_mto_cap_cobrado := 0;
             END;
             IF p_tip_monto = 'M' THEN
                BEGIN
                   SELECT SUM(sal_interes)
                     INTO v_sal_capital
                     FROM pr_cuotas
                    WHERE nro_cuenta = p_nro_cuenta
                      AND ((p_tip_saldo = 'V' AND (p_fecha - fec_vencimiento) > p_dias_atraso) OR
                          (p_tip_saldo = 'O'));
                EXCEPTION
                   WHEN OTHERS THEN
                      v_sal_capital := 0;
                END;
             END IF;
             v_monto := nvl(v_mto_cap_cobrado, 0) + nvl(v_sal_capital, 0);
         End If;
         RETURN v_monto;

      END;
   /* Solo para RRR, se verifica la forma de pago de la nueva operacion */
   PROCEDURE pr_obt_for_pag_rrr
   (
      p_nro_cuenta             IN ge_cuentas.nro_cuenta%TYPE,
      p_categoria              IN ge_cla_operaciones.cat_automatica%TYPE,
      p_mto_original           IN ge_cla_operaciones.mto_original%TYPE,
      p_sal_capital            IN ge_cla_operaciones.mto_original%TYPE,
      p_fec_ult_categorizacion IN pr_cta_prestamos.fec_ult_categorizacion%TYPE,
      p_pue_categoria          IN OUT VARCHAR2, --- Puede mejorar categoria S/N
      p_pue_prevision          IN OUT VARCHAR2
   ) --- Puede liberar prevision S/N
    IS
      v_por_pago        NUMBER(15, 2);
      v_plazo           NUMBER(10);
      v_mto_capital     pr_cuotas.mto_capital%TYPE;
      v_mto_cap_cobrado pr_cobros.mto_capital%TYPE;
      v_cod_modulo      ge_cuentas.cod_modulo%TYPE;
      --v_por_cat_mejora  NUMBER(2) := fug_obt_pardinamico('SIB_POR_CAT_MEJORADA');
   BEGIN
      --- Hallar el plazo de la cuenta
      BEGIN
         SELECT fec_vencimiento - fec_apertura, cod_modulo
           INTO v_plazo, v_cod_modulo
           FROM ge_cuentas
          WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Cuenta ' || p_nro_cuenta || ' no regitrada');
      END;
      
      p_pue_categoria   := 'N';
      p_pue_prevision   := 'N';
      v_mto_cap_cobrado_aux := null;
      v_mto_capital     := fu_obt_mto_capital(p_nro_cuenta, NULL, NULL, 'O', 'M', p_fec_ult_categorizacion, v_cod_modulo);
      v_mto_cap_cobrado := fu_obt_mto_capital(p_nro_cuenta, NULL, NULL, NULL, 'C', p_fec_ult_categorizacion,v_cod_modulo);
      if v_mto_capital = 0 then
        v_mto_capital := 1;
      end if;
      v_por_pago        := round((v_mto_cap_cobrado * 100) / v_mto_capital);

      IF p_categoria IN (1, 2, 3) THEN
         --- Categorias menores mejoran si pagan el 10%
         IF v_por_pago >= 10 THEN
            p_pue_categoria := 'S';
            p_pue_prevision := 'S';
         END IF;
      ELSE
         --- Categorias superiores
         IF v_plazo < 1095 THEN
            --- Plazo menor a 3 a?os
            IF v_por_pago >= 10 AND v_por_pago < 25 THEN
               p_pue_categoria := 'S';
               p_pue_prevision := 'N';
            ELSIF v_por_pago >= 25 THEN
               p_pue_categoria := 'S';
               p_pue_prevision := 'S';
            END IF;
         ELSE
            --- Plazo superior a 3 a?os
            IF v_por_pago >= 10 AND v_por_pago < 15 THEN
               p_pue_categoria := 'S';
               p_pue_prevision := 'N';
            ELSIF v_por_pago >= 15 THEN
               p_pue_categoria := 'S';
               p_pue_prevision := 'S';
            END IF;
         END IF;
      END IF;
      IF p_pue_categoria = 'S' OR p_pue_prevision = 'S' THEN
         UPDATE pr_cta_prestamos
            SET fec_ult_categorizacion = v_fec_proceso
          WHERE nro_cuenta = p_nro_cuenta;
      END IF;
   END;




   /* Verifica si el grupo economico tiene mas de un cliente. */
   FUNCTION fu_ver_gru_mas_clie(p_cod_gru_economico IN ge_gru_economicos.cod_gru_economico%TYPE)
      RETURN BOOLEAN IS
      v_cant NUMBER(20) := 0;
   BEGIN
       SELECT COUNT(*)
         INTO v_cant
         FROM ge_clientes c
        WHERE c.cod_gru_economico = p_cod_gru_economico
             --- Persona que poseea deuda todavia
          AND EXISTS (SELECT 1
                 FROM ge_cta_clientes cc, ge_cuentas cu
                WHERE cu.nro_cuenta = cc.nro_cuenta
                  AND cu.estado <> 'N'
                  AND cu.cod_modulo IN (6, 10)
                  AND c.cod_persona = cc.cod_persona
                  AND cc.relacion = 'P'
               UNION
               SELECT 1
                 FROM ge_cta_clientes cc, ge_cuentas cu
                WHERE cu.nro_cuenta = cc.nro_cuenta
                  AND cu.estado <> 'C'
                  AND cu.cod_modulo = 5
                  AND c.cod_persona = cc.cod_persona
                  AND cc.relacion = 'P'
                  AND EXISTS (SELECT t.nro_cuenta
                         FROM ta_tarjetas t
                        WHERE t.nro_cuenta = cc.nro_cuenta
                          AND t.vigente = 'S'));

      IF v_cant > 1 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END;

   FUNCTION fu_obt_cat_cliente
   (
      p_cod_persona IN ge_clientes.cod_persona%TYPE,
      p_fecha       IN DATE DEFAULT NULL
   ) RETURN NUMBER IS
      v_cat_riesgo ge_clientes.cat_automatica%TYPE;
   BEGIN
      SELECT nvl(cat_riesgo, cat_automatica)
        INTO v_cat_riesgo
        FROM ge_clientes_his
       WHERE cod_persona = p_cod_persona
         AND fecha = p_fecha;

      RETURN v_cat_riesgo;
   EXCEPTION
      WHEN no_data_found THEN
         BEGIN
            SELECT nvl(cat_riesgo, cat_automatica)
              INTO v_cat_riesgo
              FROM ge_clientes
             WHERE cod_persona = p_cod_persona;

            RETURN v_cat_riesgo;
         EXCEPTION
            WHEN OTHERS THEN
               RETURN 1;
         END;
      WHEN OTHERS THEN
         RETURN 1;
   END;

/*Retorna la categoria del cliente a Informar a la CRC.*/
   FUNCTION fu_obt_cat_crc
   (
      p_cod_persona      IN ge_clientes.cod_persona%TYPE,
      p_fecha            IN DATE DEFAULT NULL,
      p_con_subcategoria IN VARCHAR2 DEFAULT NULL

   ) RETURN VARCHAR2 IS
      v_cat_crc        VARCHAR2(3);
      v_cat_automatica ge_clientes_his.cat_automatica%TYPE;
      v_cat_subjetiva  ge_clientes_his.cat_subjetiva%TYPE;
      v_exists         NUMBER(1) := 0;
   BEGIN
      IF p_fecha IS NOT NULL THEN
         BEGIN
            --Verifica si se Informó en Fecha a la CRC.
            SELECT COUNT(*)
              INTO v_exists
              FROM ge_cla_operaciones_his
             WHERE fecha = p_fecha
               AND cod_persona = p_cod_persona
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_exists := 0;
         END;

         BEGIN
            --Verifica la Cat. del Cliente a una Fecha.
            SELECT nvl(cat_automatica, 0), nvl(cat_subjetiva, 0)
              INTO v_cat_automatica, v_cat_subjetiva
              FROM ge_clientes_his
             WHERE cod_persona = p_cod_persona
               AND fecha = p_fecha;
         EXCEPTION
            WHEN OTHERS THEN
              /*ALV - FEB/2017 (DYDMR-6042)*/
              BEGIN
                --Verifica la Cat. Actual del Cliente.
                SELECT nvl(cat_automatica, 0), nvl(cat_subjetiva, 0)
                  INTO v_cat_automatica, v_cat_subjetiva
                  FROM ge_clientes
                 WHERE cod_persona = p_cod_persona;
              EXCEPTION
                WHEN OTHERS THEN
                  v_cat_automatica := 1;
                  v_cat_subjetiva  := 1;
              END;
         END;
      ELSE
         BEGIN
            --Verifica si se Informará Actualmente a la CRC.
            SELECT COUNT(*)
              INTO v_exists
              FROM ge_cla_operaciones
             WHERE cod_persona = p_cod_persona
               AND rownum = 1;
         EXCEPTION
            WHEN OTHERS THEN
               v_exists := 0;
         END;

         BEGIN
            --Verifica la Cat. Actual del Cliente.
            SELECT nvl(cat_automatica, 0), nvl(cat_subjetiva, 0)
              INTO v_cat_automatica, v_cat_subjetiva
              FROM ge_clientes
             WHERE cod_persona = p_cod_persona;
         EXCEPTION
            WHEN OTHERS THEN
               v_cat_automatica := 1;
               v_cat_subjetiva  := 1;
         END;
      END IF;

      IF v_exists = 1 THEN
         v_cat_crc := fup_obt_categoria(nvl(v_cat_automatica, 0), nvl(v_cat_subjetiva, 0));
         --Tomar las sub-categorías 1.1 o 1.2
         IF v_cat_crc = 1 AND nvl(p_con_subcategoria, 'S') = 'S' THEN
            v_cat_crc := fu_obt_sub_categoria(p_cod_persona, p_fecha);
         END IF;
      ELSE
         --Si nunca fue informado
         v_cat_crc := nvl(v_cat_automatica, 0);
      END IF;

      RETURN v_cat_crc;

   EXCEPTION
      WHEN OTHERS THEN
         v_cat_crc := 1;
         RETURN v_cat_crc;
   END;


END pap_cat;
/
