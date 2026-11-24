CREATE OR REPLACE PROCEDURE IT.prs_snp_gen_enc_legal(p_fecha IN ge_snp_mensajes.fec_valor%TYPE DEFAULT NULL)
-- https://itti-digital.atlassian.net/browse/HA-3881
-- Procedimiento de generación y envio de encaje legal (MT998)
 IS
   v_cod_msj_swift       ge_snp_mensajes.cod_msj_swift%TYPE := '998';
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%TYPE := 'MT' || v_cod_msj_swift;
   v_cod_per_bcp         ba_personas.cod_persona%TYPE;
   r_ge_snp_par_mensajes ge_snp_par_mensajes%ROWTYPE;
   v_sql                 VARCHAR2(4000);
   v_cur                 SYS_REFCURSOR;
   v_monto               NUMBER;
   v_mensaje             VARCHAR2(4000);
   v_fecha               DATE;
   v_nro_detalle         NUMBER := 1;
   v_cod_mon_iso         ba_monedas.cod_mon_iso%TYPE;
   v_cod_cta_bono        VARCHAR2(20);
   v_monto_extracted     NUMBER;
   v_depositvalue_tag    VARCHAR2(1000);
   v_ref_historica       sb_snp_mensajes.nro_referencia%TYPE;
   -- Cursor con los Plazos parametrizados a informar
   CURSOR c_plazos IS
      SELECT val_minimo dia_fin, val_maximo plazo, cod_moneda, moneda, producto
        FROM (SELECT a.val_minimo,
                     a.val_maximo,
                     6900 cod_moneda,
                     1 orden,
                     'GS' moneda,
                     'ENCAJE' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ML'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     6900 cod_moneda,
                     2 orden,
                     'GS' moneda,
                     'SALDOS_COVID' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_SAL_COV_ML'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     1 cod_moneda,
                     3 orden,
                     'USD' moneda,
                     'ENCAJE' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     1 cod_moneda,
                     4 orden,
                     'USD' moneda,
                     'SALDOS_COVID' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_SAL_COV_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     59 cod_moneda,
                     5 orden,
                     'EUR' moneda,
                     'ENCAJE' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     6900 cod_moneda,
                     6 orden,
                     'GS' moneda,
                     'BONO' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_BON_ML'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     1 cod_moneda,
                     7 orden,
                     'USD' moneda,
                     'BONO' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_BON_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     59 cod_moneda,
                     8 orden,
                     'EUR' moneda,
                     'BONO' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_BON_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     59 cod_moneda,
                     9 orden,
                     'EURUSD' moneda,
                     'ENCAJE' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_ENC_LEG_ME'
              UNION
              SELECT a.val_minimo,
                     a.val_maximo,
                     59 cod_moneda,
                     10 orden,
                     'EURUSD' moneda,
                     'BONO' producto
                FROM ba_cod_referencias a
               WHERE a.dominio = 'SNP_PLZ_BON_ME')
       ORDER BY orden, to_number(val_minimo);

BEGIN
   -- Siempre se envia lo último procesado
   --SELECT MAX(fecha) INTO v_fecha FROM sb_enc_circular254;
   IF pag_cal.fu_obt_fec_habil(p_fecha,1, 61) = p_fecha THEN
      v_fecha := p_fecha;
   ELSE
      v_fecha := IT.FUG_OBT_FEC_HABIL_ANT(p_fecha);
   END IF;

   -- Se hallan los parámetros del MT998.
   BEGIN
      SELECT *
        INTO r_ge_snp_par_mensajes
        FROM ge_snp_par_mensajes
       WHERE cod_msj_swift = v_cod_msj_swift;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001,
                                 'Error al obtener los Parámetros del ' || v_cod_mensaje || ': ' ||
                                  SQLERRM);
   END;

   -- Se hallan el código de persona de BCP para el envío.
   BEGIN
      SELECT cod_persona
        INTO v_cod_per_bcp
        FROM gv_snp_participantes
       WHERE cod_swift = fug_obt_pardinamico('SNP_BIC_BCP');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001,
                                 'Error al obtener el Código de Persona del BCP: ' || SQLERRM);
   END;
   -- Se valida el Horario de BCP.
   IF pas_snp.fu_obt_est_horario(r_ge_snp_par_mensajes.cod_msj_swift,
                                 r_ge_snp_par_mensajes.cod_tip_operacion,
                                 r_ge_snp_par_mensajes.cod_sub_tip_operacion) <> 'A' THEN
      raise_application_error(-20001, pas_snp.fu_obt_msj_error);
   END IF;

   -- Se setea el Formato numerico
   pre_cam_for_numerico(',.');
   -- Se genera la Cabecera del MT998
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'CAB',
                                      '{1:F01' || rpad(pas_snp.g_usu_xadapter, 12, 'X') || '}' ||
                                       '{2:I998' || rpad(pas_snp.fu_obt_bic_sistema, 12, 'X') || 'N}' ||
                                       '{3:{113' || ':' || lpad('30', 4, '0') || '}}{4:');
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '20', pas_snp.fu_obt_sig_nro_referencia);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '12',
                                      r_ge_snp_par_mensajes.cod_sub_tip_operacion);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '77E', NULL);
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '59',
                                      pas_snp.fu_obt_cod_swi_participante(v_cod_per_bcp));
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '54A',
                                      pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad));
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '70', '/MR/YES');

   ---Recupera la cta.contable bonos
   BEGIN
      SELECT DISTINCT substr(c.cod_rubro, 6, 3)
        INTO v_cod_cta_bono
        FROM cb_sal_inventarios_det d,
             cb_sal_inventarios     c,
             ba_monedas             m,
             ge_clientes            g,
             ge_cta_clientes        ge
       WHERE d.nro_referencia = c.nro_referencia
         AND c.cod_moneda = m.cod_moneda
         AND c.cod_modulo = 10
         AND c.tip_saldo = 'C'
         AND ge.nro_cuenta = d.nro_cuenta
         AND g.cod_persona = ge.cod_persona
         AND instr(',' || fug_obt_pardinamico('MDD_MAD_ENCAJE') || ',', ',' || c.cod_modalidad || ',') = 0
         AND ge.relacion = 'P'
         AND nvl(c.sal_total, 0) != 0
         AND c.cod_rubro IS NOT NULL
         AND instr(fug_obt_pardinamico('MDD_MAD_BONOS_ENCAJE'), c.cod_modalidad) > 0;
   EXCEPTION
      WHEN no_data_found THEN
         v_cod_cta_bono := 0;
      WHEN too_many_rows THEN
         DECLARE

            CURSOR c_cta_bono IS
               SELECT DISTINCT substr(c.cod_rubro, 6, 3) cuenta
                 FROM cb_sal_inventarios_det d,
                      cb_sal_inventarios     c,
                      ba_monedas             m,
                      ge_clientes            g,
                      ge_cta_clientes        ge
                WHERE d.nro_referencia = c.nro_referencia
                  AND c.cod_moneda = m.cod_moneda
                  AND c.cod_modulo = 10
                  AND c.tip_saldo = 'C'
                  AND ge.nro_cuenta = d.nro_cuenta
                  AND g.cod_persona = ge.cod_persona
                  AND instr(',' || fug_obt_pardinamico('MDD_MAD_ENCAJE') || ',', ',' || c.cod_modalidad || ',') = 0
                  AND ge.relacion = 'P'
                  AND nvl(c.sal_total, 0) != 0
                  AND c.cod_rubro IS NOT NULL
                  AND instr(fug_obt_pardinamico('MDD_MAD_BONOS_ENCAJE'), c.cod_modalidad) > 0;
         BEGIN

            FOR r_cta_bono IN c_cta_bono LOOP
               v_cod_cta_bono := v_cod_cta_bono || r_cta_bono.cuenta || ',';
            END LOOP;
            v_cod_cta_bono := substr(v_cod_cta_bono, 1, length(v_cod_cta_bono) - 1);
         END;
   END;

   -- Proceso por plazos.
   FOR plz IN c_plazos LOOP
      IF plz.producto = 'ENCAJE' THEN
         v_sql := 'select sum(case
                                 when a.cod_moneda <> 59 then NVL(a.importe,0)
                                 when a.cod_moneda = 59 and length(''' || plz.moneda || ''') <= 3 then 0
                                 else round(pag_gen.FU_CON_MON_A_MONEDA(''' || substr(plz.moneda,1,3) || ''', ''' || substr(plz.moneda,4,3) || ''', NVL(a.importe,0)),2)
                              end) monto
                     from sb_enc_circular254 a
                    where a.plazo in (' || plz.plazo || ')
                      and a.cod_moneda = ''' || plz.cod_moneda || '''
                      and a.fecha = ''' || v_fecha || '''
                      and a.cod_cuenta not in(' || v_cod_cta_bono || ')
                    group by a.cod_moneda';
      ELSIF plz.producto = 'SALDOS_COVID' THEN
         v_sql := 'select nvl(sum(max(c.sal_actual) - nvl((select  (nvl(max(p.tot_cap_pri_prevision), 0) + nvl(max(p.tot_cap_seg_prevision), 0)) monto
                                       from pr_previsiones p
                                      where a.nro_cuenta = p.nro_cuenta
                                        and p.fecha = (select max(b.fecha)
                                                        from pr_previsiones b
                                                       where b.nro_cuenta = a.nro_cuenta
                                                         and b.fecha <= ''' || v_fecha || ''')),0)),0)
                    from pr_cta_prestamos a,
                         ge_cta_dat_adicionales d,
                         cb_sal_inventarios_det_his c,
                         cb_sal_inventarios_his e
                   where d.nro_cuenta = a.nro_cuenta
                     and d.parametro = ''CTA_INF_ENC_LEGAL_CIR_7/2020''
                     and d.val_parametro = ''S''
                     and c.fecha = ''' || v_fecha || '''
                     and c.nro_cuenta = a.nro_cuenta
                     and c.fecha = e.fecha
                     and c.nro_referencia = e.nro_referencia
                     and e.tip_saldo = ''C''
                     and (a.fec_vencimiento - a.fec_inicio) >= ''' || plz.plazo || '''
                     and a.cod_moneda = ''' || plz.moneda || '''
                  group by a.cod_moneda, a.nro_cuenta';
      ELSIF plz.producto = 'BONO' THEN
         v_sql := 'select sum(case
                                 when a.cod_moneda <> 59 then NVL(a.importe,0)
                                 when a.cod_moneda = 59 and length(''' || plz.moneda || ''') <= 3 then NVL(a.importe,0)
                                 else round(pag_gen.FU_CON_MON_A_MONEDA(''' || substr(plz.moneda,1,3) || ''', ''' || substr(plz.moneda,4,3) || ''', NVL(a.importe,0)),0)
                              end) monto
                     from sb_enc_circular254 a
                    where a.plazo in (' || plz.plazo || ')
                      and a.cod_moneda = ''' || plz.cod_moneda || '''
                      and a.fecha = ''' || v_fecha || '''
                      and a.cod_cuenta in (' || v_cod_cta_bono || ')
                    group by a.cod_moneda';
      END IF;
      OPEN v_cur FOR v_sql;
      v_monto := NULL;

      --Se halla la moneda ISO.
      BEGIN
         SELECT m.cod_mon_iso
           INTO v_cod_mon_iso
           FROM ba_monedas m
          WHERE m.cod_mon_bco_central = plz.cod_moneda;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001,
                                    'Error al Obtener Moneda ' || plz.cod_moneda || ': ' || SQLERRM);
      END;

      -- Se halla el Monto total del Select dinámico
      LOOP
         FETCH v_cur
            INTO v_monto;
         EXIT WHEN v_cur%NOTFOUND;
      END LOOP;
      
      -- Solo para SHORTEURUSD se usa DEPOSITVALUE histórico.
      v_monto_extracted := v_monto;
      IF plz.producto = 'ENCAJE'
         AND plz.dia_fin = '1'
         AND plz.moneda = 'EURUSD' THEN
         SELECT MIN(x.nro_referencia)
           INTO v_ref_historica
           FROM it.sb_snp_mensajes x
          WHERE x.cod_mensaje = v_cod_mensaje
            AND x.campo = '79'
            AND x.valor = '/DEPOSITDATE/' || to_char(nvl(p_fecha, v_fecha), 'RRMMDD')
            AND EXISTS (SELECT 1
                   FROM it.sb_snp_mensajes xt
                  WHERE xt.nro_referencia = x.nro_referencia
                    AND xt.campo = '79'
                    AND xt.nro_detalle = x.nro_detalle
                    AND xt.valor = '/DEPOSITTYPE/SHORTEURUSD');

         IF v_ref_historica IS NOT NULL THEN
            BEGIN
               SELECT REPLACE(m.valor, '/DEPOSITVALUE/', '')
                 INTO v_depositvalue_tag
                 FROM IT.SB_SNP_MENSAJES m
                WHERE m.campo = '79'
                  AND m.nro_referencia = v_ref_historica
                  AND m.valor LIKE '/DEPOSITVALUE/%'
                  AND EXISTS (SELECT 1
                         FROM IT.SB_SNP_MENSAJES t
                        WHERE t.nro_referencia = m.nro_referencia
                          AND t.campo = '79'
                          AND t.nro_detalle = m.nro_detalle
                          AND t.valor = '/DEPOSITTYPE/SHORTEURUSD')
                  AND ROWNUM = 1;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_depositvalue_tag := NULL;
            END;

            IF v_depositvalue_tag IS NOT NULL THEN
               v_monto_extracted := TO_NUMBER(REPLACE(RTRIM(v_depositvalue_tag, ','),
                                                      ',',
                                                      '.'),
                                              '9999999999999990D999999999999',
                                              'NLS_NUMERIC_CHARACTERS=''.,''');
            END IF;
         END IF;
      END IF;

      --Solo el primer detalle no debe contener el Tag :79: (Excepcion Batch del MT998)
      IF v_nro_detalle = 1 THEN
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/PARTICIPANT/' ||
                                             pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '54A', 1, 0),
                                            v_nro_detalle);
      ELSE
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            ':79:/PARTICIPANT/' ||
                                             pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '54A', 1),
                                            v_nro_detalle);
      END IF;

      IF plz.producto in ('ENCAJE', 'SALDOS_COVID') THEN
         -- Tipo de Plazo informado
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/DEPOSITTYPE/' || CASE
                                                WHEN plz.dia_fin = '1' AND plz.producto <> 'SALDOS_COVID' THEN
                                                 'SHORT' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end)
                                                WHEN plz.dia_fin = '360' AND plz.producto <> 'SALDOS_COVID' THEN
                                                 'LONG' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end) || '01'
                                                WHEN plz.dia_fin = '540' AND plz.producto <> 'SALDOS_COVID' THEN
                                                 'LONG' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end) || '02'
                                                WHEN plz.dia_fin = '3650' AND plz.producto <> 'SALDOS_COVID' AND plz.moneda = pas_snp.g_cod_mon_local THEN
                                                 'LONG' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end) || '03'
                                                WHEN plz.dia_fin = '3650' AND plz.producto = 'SALDOS_COVID' AND plz.moneda = pas_snp.g_cod_mon_local THEN
                                                 'SALCAPCOVPYG'
                                                WHEN plz.dia_fin = '1080' AND plz.producto <> 'SALDOS_COVID' AND plz.moneda != pas_snp.g_cod_mon_local THEN
                                                 'LONG' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end) || '03'
                                                WHEN plz.dia_fin = '3650' AND plz.producto <> 'SALDOS_COVID' AND plz.moneda != pas_snp.g_cod_mon_local THEN
                                                 'LONG' || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end) || '04'
                                                WHEN plz.dia_fin = '3650' AND plz.producto = 'SALDOS_COVID' AND plz.moneda != pas_snp.g_cod_mon_local THEN
                                                 'SALCAPCOVUSD'
                                                ELSE
                                                 NULL
                                             END, v_nro_detalle);
         -- Fecha
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/DEPOSITDATE/' ||
                                             to_char(nvl(p_fecha, v_fecha), 'RRMMDD'), v_nro_detalle);
         -- Plazo Desde
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/TERMFROM/' || CASE
                                WHEN plz.dia_fin = '1' AND
                                     plz.producto <> 'SALDOS_COVID' THEN
                                     '1'
                                  WHEN plz.dia_fin = '360' AND
                                       plz.producto <> 'SALDOS_COVID' THEN
                                     '2'
                                  WHEN plz.dia_fin = '540' AND
                                       plz.producto <> 'SALDOS_COVID' THEN
                                     '361'
                                  WHEN plz.dia_fin = '1080' AND
                                       plz.producto <> 'SALDOS_COVID' THEN
                                     '541'
                                  WHEN plz.dia_fin = '3650' AND
                                       plz.moneda = pas_snp.g_cod_mon_local AND
                                       plz.producto <> 'SALDOS_COVID' THEN
                                     '541'
                                  WHEN plz.dia_fin = '3650' AND
                                       plz.moneda != pas_snp.g_cod_mon_local AND
                                       plz.producto <> 'SALDOS_COVID' THEN
                                     '1081'
                                  WHEN plz.dia_fin = '3650' AND
                                       plz.producto = 'SALDOS_COVID' THEN
                                     '1'
                                  ELSE
                                      NULL
                                END,
                                            v_nro_detalle);
      ELSIF plz.producto = 'BONO' THEN
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/DEPOSITTYPE/' || plz.producto || (case when length(plz.moneda) > 3 then plz.moneda else v_cod_mon_iso end),
                                            v_nro_detalle);
         -- Fecha
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/DEPOSITDATE/' ||
                                             to_char(nvl(p_fecha, v_fecha), 'RRMMDD'), v_nro_detalle);
         -- Plazo Desde
         pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                            '/TERMFROM/' || CASE WHEN plz.dia_fin = '3650' THEN
                                             '541' ELSE NULL END, v_nro_detalle);
      END IF;

      -- Plazo Hasta
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/TERM/' || plz.dia_fin,
                                         v_nro_detalle);
      -- Moneda
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79', '/CURRENCY/' || (case when length(plz.moneda) > 3 then substr(plz.moneda,4,3) else v_cod_mon_iso end),
                                         v_nro_detalle);
      -- Monto (solo SHORTEURUSD usa el valor histórico)
      pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, '79',
                                         '/DEPOSITVALUE/' ||
                                          TRIM(to_char(nvl(v_monto_extracted, 0),
                                                       '9999999999999990D' ||
                                                        rpad('9',
                                                             nvl(fug_obt_pardinamico(p_parametro => 'VAL_RED_MON_EXTRANJERA',
                                                                                      p_cod_moneda => plz.moneda),
                                                                  2), '9'))), v_nro_detalle);

      v_nro_detalle := v_nro_detalle + 1;

      -- Se actualiza el Nro. de Referencia de la Transferencia Generada
      BEGIN
         v_sql := 'update sb_enc_circular254 a
                      set a.nro_referencia = ' ||
                  pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20') ||
                  ' where a.fecha = to_date(''' || to_char(v_fecha, 'dd/mm/yyyy') ||
                  ''', ''dd/mm/yyyy'')' || ' and a.plazo in (' || plz.plazo || ')';

         EXECUTE IMMEDIATE v_sql;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001,
                                    'Error al Actualizar el Nro. de Referencia: ' || SQLERRM);
      END;
   END LOOP;

   -- Se agrega el Pie del MT998
   pao_pmt.pr_ins_sb_snp_mensajes_tmp(v_cod_mensaje, 'PIE', '-}');
   pao_pmt.pr_pro_mt_enviado(v_cod_mensaje, v_mensaje);
   if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
   -- TRFS-533-Inserta mensaje para que el OWL/ETL procesee
       begin
         insert into ge_men_env_sipap
           (nro_referencia, estado, msj_swift)
         values
           (pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20'),
            'PENDING',
            REPLACE(REPLACE(v_mensaje, chr(10), pas_snp.fu_obt_sal_socket),
                    chr(13),
                    ''));
       exception
         when others then
           -- Hubo problema en la insercion
           pas_snp.g_cod_error := 49;
           pas_snp.g_msj_error := SQLERRM;
           raise_application_error(-20001,
                                   'Error al insertar en GE_MEN_ENV_SIPAP: ' ||
                                   SQLERRM);
       end;
    else
            pas_snp.pr_gen_arc_swi_lote(v_mensaje); --envio mt
    end if;

   -- Se inserta en GE_SNP_MENSAJES
   BEGIN
      INSERT INTO ge_snp_mensajes
         (nro_referencia, nro_ref_externa, cod_msj_swift, fec_valor, msj_swift, cod_moneda, monto,
          error, msj_swi_original, situacion)
      VALUES
         (pao_pmt.fu_obt_val_mt_proceso(v_cod_mensaje, '20'), NULL, v_cod_msj_swift,
          nvl(p_fecha, v_fecha), v_mensaje, NULL, NULL, NULL, v_mensaje, 'V');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error al insertar en GE_SNP_MENSAJES: ' || SQLERRM);
   END;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20001, 'Error al Procesar Encaje legal: ' || SQLERRM);

END prs_snp_gen_enc_legal;
/
