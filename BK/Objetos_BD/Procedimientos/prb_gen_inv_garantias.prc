CREATE OR REPLACE PROCEDURE IT.PRB_GEN_INV_GARANTIAS IS
   --- Genera inventario contable de garantías.
   r_cbgar                 cb_sal_inv_garantias%ROWTYPE;
   v_fec_actual            ge_calendarios.fec_actual%TYPE;
   v_cod_mon_local         ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_mto_deu_cliente       ge_cla_operaciones.tot_deu_real%type := 0;   
   v_mto_deu_codeudoria    ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_total             ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_distribuido       ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_dif_distribucion  ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_gar_utilizado     ge_cla_operaciones.tot_deu_real%type := 0;
   v_mto_gar_contabilizado ge_cla_operaciones.tot_deu_real%type := 0;
   v_tot_deuda             ge_cla_operaciones.tot_deu_real%type := 0;
   v_nro_garantia          pr_garantias.nro_garantia%type;
   v_cod_garantia          pr_garantias.cod_garantia%type;
   v_cod_persona           ge_clientes.cod_persona%type;
   v_cod_modulo            ge_modalidades.cod_modulo%type := '6';
   v_cod_modalidad         ge_modalidades.cod_modalidad%type := '61';
   v_redondeo              NUMBER(1) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad, v_cod_mon_local);
   v_existe                NUMBER(1) := 0;
   
   -- Proceso que inserta registros en la tabla.
   PROCEDURE lp_ins_inv_garantias (r_cbgar cb_sal_inv_garantias%ROWTYPE) IS
   BEGIN      
      UPDATE cb_sal_inv_garantias
         SET  mto_dis_garantia =NVL(r_cbgar.mto_dis_garantia,0)
       WHERE fecha = r_cbgar.fecha
         AND cod_garantia = r_cbgar.cod_garantia
         AND nro_garantia = r_cbgar.nro_garantia
         AND nro_cuenta = r_cbgar.nro_cuenta
         AND tip_saldo = r_cbgar.tip_saldo;

      IF SQL%NOTFOUND THEN
         INSERT INTO cb_sal_inv_garantias(fecha, nro_garantia, nro_cuenta, cod_garantia, clasificacion, mto_deuda, mto_dis_garantia, 
                                                cod_rubro, tip_saldo, cod_transaccion)
              VALUES (r_cbgar.fecha, r_cbgar.nro_garantia, r_cbgar.nro_cuenta, r_cbgar.cod_garantia, r_cbgar.clasificacion, r_cbgar.mto_deuda,
                      r_cbgar.mto_dis_garantia, r_cbgar.cod_rubro, r_cbgar.tip_saldo, r_cbgar.cod_transaccion);
      END IF;
      
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins. cb_sal_garantias ' || r_cbgar.nro_garantia || ' - ' ||SQLERRM);
   END;
      
   -- Proceso de Distribución de Garantías Computables.
   PROCEDURE lp_gen_inv_garantias IS
   
      -- Cursores.
      -- Garantías Computables.note
      CURSOR c_gar_computable IS
       /*SELECT t.cod_persona,
                t.cod_garantia,
                t.nro_garantia,
                t.cod_oficina,
                t.fec_vencimiento,
                t.cod_moneda,
                (CASE WHEN t.cod_moneda = v_cod_mon_local THEN
                    nvl(t.monto, 0)
                 ELSE
                    ROUND(pag_gen.fu_con_mon_a_moneda(t.cod_moneda, v_cod_mon_local, nvl(t.monto, 0)),v_redondeo)
                 END) monto,
                t.descripcion,
                t.estado,
                t.cod_modulo,
                t.cod_modalidad,
                t.tra_computable,
                t.tra_no_computable
           FROM bv_gar_computables t
          WHERE t.computable = 'S'
          ORDER BY t.cod_persona, t.pri_aplicacion, t.cod_garantia, t.nro_garantia;*/
-- Garantías Computables.
         SELECT v.fecha,
                v.cod_persona,
                v.cod_garantia,
                v.nro_garantia,
                v.cod_rubro,
                v.cod_moneda,
                v.MONTO,
                v.descripcion,
                v.cod_modulo,
                v.cod_modalidad,
                v.tra_computable,
                v.tra_no_computable,
                v.computable,
                v.pri_aplicacion,
                v.nro_cuenta,
                ROUND(v.tot_deu_calculada, fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v.cod_modulo, v.cod_modalidad, v_cod_mon_local)) tot_deu_real
           FROM (
                 SELECT pag_cal.fu_obt_fec_actual(1) fecha,
                        g.cod_persona cod_persona,
                        g.cod_garantia cod_garantia,
                        g.nro_garantia nro_garantia,
                        NVL(fub_obt_rub_transaccion(tg.cod_modulo, tg.cod_modalidad, tg.cod_transaccion1, g.cod_moneda, g.cod_persona, NULL, 'D'), 0) cod_rubro,
                        g.cod_moneda cod_moneda,
                        NVL(g.mto_apl_com_ml, 0) MONTO,
                        tg.descripcion descripcion,
                        tg.cod_modulo,
                        tg.cod_modalidad,
                        tg.cod_transaccion1 tra_computable,
                        tg.cod_transaccion2 tra_no_computable,
                        tg.computable,
                        tg.pri_aplicacion,
                        g.nro_cuenta,
                        SUM(CASE WHEN ge.cod_modulo = 6 THEN (NVL(ge.tot_deu_real, 0) - NVL(ge.dev_no_cobrado, 0)) 
                                 WHEN ge.cod_modulo NOT IN (4, 6) THEN NVL(ge.tot_deu_real, 0) + NVL(ge.tot_deu_contingente, 0)
                                 WHEN ge.cod_modulo = 4 THEN NVL(ge.tot_deu_contingente, 0)
                            ELSE 0 END) tot_deu_calculada
                   FROM pr_cta_garantias_det g,
                        ge_clientes c,
                        pr_gar_tipos tg,
                        ge_cla_operaciones ge
                  WHERE g.fecha        = pag_cal.fu_obt_fec_actual(1)
                    AND g.cod_persona  = c.cod_persona
                    AND g.cod_garantia = tg.cod_garantia
                    AND g.cod_persona  = ge.cod_persona
                    AND g.nro_cuenta   = ge.nro_cuenta
                    AND NOT EXISTS (
                        SELECT 1 
                          FROM ge_cuentas gc
                         WHERE gc.nro_cuenta = g.nro_cuenta
                           AND gc.cod_modalidad IN (970, 971)
                    )
                  GROUP BY g.cod_persona, g.cod_garantia, g.nro_garantia, g.cod_moneda, g.mto_apl_com_ml,
                           tg.descripcion, tg.cod_modulo, tg.cod_modalidad, tg.cod_transaccion1, tg.cod_transaccion2,
                           tg.computable, tg.pri_aplicacion, g.nro_cuenta
                ) v
          ORDER BY v.cod_persona, v.pri_aplicacion, v.cod_garantia, v.nro_garantia;
      -- Garantías no Computables.
      CURSOR c_gar_nocomputable IS
         SELECT t.pri_aplicacion,
                t.cod_persona,
                t.cod_garantia,
                t.nro_garantia,
                nvl(t.cod_oficina,7) cod_oficina,
                t.fec_vencimiento,
                t.cod_moneda,
                (CASE WHEN t.cod_moneda = v_cod_mon_local THEN
                    nvl(t.monto, 0)
                 ELSE
                    ROUND(pag_gen.fu_con_mon_a_moneda(t.cod_moneda, v_cod_mon_local, nvl(t.monto, 0)),
                    fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', t.cod_modulo, t.cod_modalidad, v_cod_mon_local))
                 END) monto,
                t.descripcion,
                t.estado,
                t.cod_modulo,
                t.cod_modalidad,
                t.tra_computable,
                t.tra_no_computable
           FROM bv_gar_computables t
          WHERE (t.computable = 'N' OR t.cod_modalidad IN (970, 971))
         UNION --- Incidencia: para contabilizar como exceso las garantias que no incluimos en computables
         SELECT t.pri_aplicacion,
                t.cod_persona,
                t.cod_garantia,
                t.nro_garantia,
                nvl(t.cod_oficina,7) cod_oficina,
                t.fec_vencimiento,
                t.cod_moneda,
                (CASE WHEN t.cod_moneda = v_cod_mon_local THEN
                    nvl(t.monto, 0)
                 ELSE
                    ROUND(pag_gen.fu_con_mon_a_moneda(t.cod_moneda, v_cod_mon_local, nvl(t.monto, 0)),
                    fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', t.cod_modulo, t.cod_modalidad, v_cod_mon_local)
                    )
                 END) monto,
                t.descripcion,
                t.estado,
                t.cod_modulo,
                t.cod_modalidad,
                t.tra_computable,
                t.tra_no_computable
           FROM bv_gar_computables t
          WHERE t.computable = 'S'
            and not exists (select 1 from pr_cta_garantias_det p 
                             where p.nro_garantia = t.nro_garantia
                               and p.fecha = v_fec_actual)
          ORDER BY pri_aplicacion, cod_garantia, nro_garantia;
      
      CURSOR c_cuentas(p_cod_garantia pr_garantias.cod_garantia%type, 
                       p_nro_garantia pr_garantias.nro_garantia%type) IS
         SELECT cs.fecha, cs.nro_garantia, cs.nro_cuenta, cs.cod_garantia, cs.clasificacion, cs.tip_saldo, cs.mto_deuda, cs.cod_rubro,
                NVL((ROUND(NVL(cs.mto_deuda,0) - 
                    (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                       FROM cb_sal_inv_garantias cc
                      WHERE cc.fecha = v_fec_actual
                        AND cc.nro_cuenta = cs.nro_cuenta
                        AND cc.tip_saldo = cs.tip_saldo),v_redondeo)),0) monto
           FROM cb_sal_inv_garantias cs, ge_cuentas gc
          WHERE cs.fecha = v_fec_actual
            AND cs.nro_garantia = p_nro_garantia
            AND cs.cod_garantia = p_cod_garantia
            AND cs.nro_cuenta = gc.nro_cuenta
            AND NVL(cs.mto_deuda,0) > 
                (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                   FROM cb_sal_inv_garantias cc
                  WHERE cc.fecha = v_fec_actual
                    AND cc.nro_cuenta = cs.nro_cuenta
                    AND cc.tip_saldo = cs.tip_saldo)
          GROUP BY cs.fecha, cs.nro_garantia, cs.nro_cuenta, cs.cod_garantia, cs.clasificacion, cs.tip_saldo, cs.mto_deuda, cs.cod_rubro; 
      
      CURSOR c_aju_cuentas(p_cod_persona ge_clientes.cod_persona%type) IS
         SELECT cs.fecha, cs.nro_cuenta, cs.mto_deuda, 
                NVL((ROUND(NVL(cs.mto_deuda,0) - 
                    (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                       FROM cb_sal_inv_garantias cc
                      WHERE cc.fecha = v_fec_actual
                        AND cc.nro_cuenta = cs.nro_cuenta
                        AND cc.tip_saldo = 'C'),v_redondeo)),0) monto
           FROM cb_sal_inv_garantias cs, ge_cuentas gc, ge_cta_clientes cc
          WHERE cs.fecha = v_fec_actual
            AND cs.nro_cuenta = gc.nro_cuenta
            AND cs.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND cc.cod_persona = p_cod_persona
            AND cs.tip_saldo = 'C'
            AND NVL(cs.mto_deuda,0) > 
                (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                   FROM cb_sal_inv_garantias cc
                  WHERE cc.fecha = v_fec_actual
                    AND cc.nro_cuenta = cs.nro_cuenta
                    AND cc.tip_saldo = 'C')
          GROUP BY cs.fecha, cs.nro_cuenta, cs.mto_deuda; 
            
      -- Cuentas de Clientes para Tipo de Saldo Capital.
      CURSOR c_cta_clientes(p_cod_persona ge_cla_operaciones.cod_persona%type) IS
         SELECT ge.cod_persona, ge.nro_cuenta, ge.cod_moneda, 
                ROUND((CASE WHEN ge.cod_modulo = 6 THEN (nvl(ge.tot_deu_real, 0) - NVL(ge.dev_no_cobrado,0)) 
                      WHEN ge.cod_modulo NOT IN (4,6) THEN nvl(ge.tot_deu_real, 0) + nvl(ge.tot_deu_contingente, 0)
                      WHEN ge.cod_modulo = 4 THEN nvl(ge.tot_deu_contingente, 0)
                  ELSE 0 END),v_redondeo) tot_deu_real
           FROM ge_cla_operaciones ge
          WHERE ge.cod_persona = p_cod_persona;
            --AND NOT EXISTS (SELECT 1 FROM cb_sal_inv_garantias cs WHERE cs.fecha = v_fec_actual AND cs.nro_cuenta = ge.nro_cuenta AND cs.tip_saldo = 'C');           
            
      -- Cuentas de Clientes para Tipo de Saldo Interes.
      CURSOR c_cta_dev_cliente(p_cod_persona ge_cla_operaciones.cod_persona%type) IS
         SELECT ge.cod_persona, ge.nro_cuenta, ge.cod_moneda, NVL(ge.dev_no_cobrado, 0) dev_no_cobrado
           FROM ge_cla_operaciones ge
          WHERE ge.cod_persona = p_cod_persona
            AND NVL(ge.dev_no_cobrado, 0) > 0;
            --AND NOT EXISTS (SELECT 1 FROM cb_sal_inv_garantias cs WHERE cs.fecha = v_fec_actual AND cs.nro_cuenta = ge.nro_cuenta AND cs.tip_saldo = 'I');
            
      -- Cuentas vinculadas al Cliente - Codeudoría para Tipo de Saldo Capital.
      CURSOR c_cta_codeudoria(p_cod_persona ge_cla_operaciones.cod_persona%type) IS
         SELECT DISTINCT ge.cod_persona, ge.nro_cuenta, ge.cod_moneda, 
                         NVL(ROUND((CASE WHEN ge.cod_modulo = 6 THEN (nvl(ge.tot_deu_real, 0) - NVL(ge.dev_no_cobrado,0)) 
                               WHEN ge.cod_modulo NOT IN (4,6) THEN nvl(ge.tot_deu_real, 0) + nvl(ge.tot_deu_contingente, 0)
                               WHEN ge.cod_modulo = 4 THEN nvl(ge.tot_deu_contingente, 0)
                          ELSE 0 END),0),0) tot_deu_real
           FROM ge_cla_operaciones ge, ge_cta_clientes t
          WHERE t.nro_cuenta = ge.nro_cuenta
            AND t.cod_persona = p_cod_persona
            AND t.relacion IN ('C', 'G')
            AND NVL(ROUND((CASE WHEN ge.cod_modulo = 6 THEN (nvl(ge.tot_deu_real, 0) - NVL(ge.dev_no_cobrado,0)) 
                               WHEN ge.cod_modulo NOT IN (4,6) THEN nvl(ge.tot_deu_real, 0) + nvl(ge.tot_deu_contingente, 0)
                               WHEN ge.cod_modulo = 4 THEN nvl(ge.tot_deu_contingente, 0)
                          ELSE 0 END),0),0) > 
                (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                   FROM cb_sal_inv_garantias cc
                  WHERE cc.fecha = v_fec_actual
                    AND cc.nro_cuenta = t.nro_cuenta
                    AND cc.tip_saldo = 'C');
            
      -- Cuentas vinculadas al Cliente - Codeudoría para Tipo de Saldo Interes.
      CURSOR c_cta_dev_codeudoria(p_cod_persona ge_cla_operaciones.cod_persona%type) IS
         SELECT DISTINCT ge.cod_persona, ge.nro_cuenta, ge.cod_moneda, NVL(ge.dev_no_cobrado, 0) dev_no_cobrado
           FROM ge_cla_operaciones ge, ge_cta_clientes t
          WHERE t.nro_cuenta = ge.nro_cuenta
            AND t.cod_persona = p_cod_persona
            AND t.relacion IN ('C', 'G')
            AND NVL(ge.dev_no_cobrado, 0) > 
                (SELECT NVL(SUM(NVL(cc.mto_dis_garantia,0)),0)
                   FROM cb_sal_inv_garantias cc
                  WHERE cc.fecha = v_fec_actual
                    AND cc.nro_cuenta = t.nro_cuenta
                    AND cc.tip_saldo = 'I');
          
      -- Listado de cuentas para ajustes de redondeo.
      CURSOR c_cta_mon_extranjera IS
         SELECT a.cod_garantia, a.nro_garantia, a.cod_rubro, a.clasificacion, NVL(SUM(a.mto_dis_garantia),0) mto_dis_garantia,
                p.cod_transaccion1 tra_computable, p.cod_transaccion2 tra_no_computable 
           FROM cb_sal_inv_garantias a, pr_garantias b, pr_gar_tipos p
          WHERE a.fecha = v_fec_actual
            AND a.cod_garantia = b.cod_garantia
            AND a.nro_garantia = b.nro_garantia
            AND b.cod_moneda <> v_cod_mon_local
            AND b.cod_garantia = p.cod_garantia
          GROUP BY a.cod_garantia, a.nro_garantia, a.cod_rubro, a.clasificacion,
                   p.cod_transaccion1, p.cod_transaccion2;
       
      -- Obtiene la lista de cuentas para realizar el ajustes de redondeo.
      CURSOR c_cta_inventario(p_cod_garantia pr_garantias.cod_garantia%type, 
                              p_nro_garantia pr_garantias.nro_garantia%type,
                              p_cod_rubro    cb_rubros.cod_rubro%type) IS
         SELECT v.nro_cuenta, v.tip_saldo
           FROM (
         SELECT a.nro_cuenta, a.tip_saldo
           FROM cb_sal_inv_garantias a 
          WHERE a.fecha = v_fec_actual
            AND a.cod_garantia = p_cod_garantia
            AND a.nro_garantia = p_nro_garantia
            AND a.cod_rubro = p_cod_rubro
            AND NVL(a.mto_dis_garantia,0) > NVL(a.mto_deuda,0)
            AND NVL(a.mto_deuda,0) = 0) v
          WHERE ROWNUM = 1;

      --- Obtiene la parte no utilizada de la garantía computable
      cursor c_gar_utilizado is
         SELECT pg.nro_garantia, pg.cod_garantia, pg.cod_moneda, pg.cod_persona,
                pt.cod_modulo, pt.cod_modalidad,
                pt.cod_transaccion1 tra_computable, pt.cod_transaccion2 tra_no_computable,
                (CASE WHEN pg.cod_moneda = v_cod_mon_local THEN
                      nvl(pg.valor, 0)
                 ELSE
                      ROUND(pag_gen.fu_con_mon_a_moneda(pg.cod_moneda, v_cod_mon_local, nvl(pg.valor, 0)),v_redondeo)
                 END) monto,
                nvl(cb.mto_gar_utilizado, 0) mto_distribuido,
               ((CASE WHEN pg.cod_moneda = v_cod_mon_local THEN
                      nvl(pg.valor, 0)
                 ELSE
                      ROUND(pag_gen.fu_con_mon_a_moneda(pg.cod_moneda, v_cod_mon_local, nvl(pg.valor, 0)),v_redondeo)
                  END) - nvl(cb.mto_gar_utilizado, 0)) mto_disponible
           FROM pr_garantias pg, pr_gar_tipos pt,
               (SELECT cs.nro_garantia, 
                       cs.cod_garantia,
                       NVL(SUM(nvl(cs.mto_dis_garantia, 0)),0) mto_gar_utilizado
                  FROM cb_sal_inv_garantias cs
                 WHERE cs.fecha = pag_cal.fu_obt_fec_actual(1)
                 GROUP by cs.nro_garantia, cs.cod_garantia) cb
          WHERE cb.nro_garantia = pg.nro_garantia
            AND cb.cod_garantia = pg.cod_garantia
            AND pt.cod_garantia = pg.cod_garantia
            AND ((CASE WHEN pg.cod_moneda = v_cod_mon_local THEN
                       nvl(pg.valor, 0)
                  ELSE
                       ROUND(pag_gen.fu_con_mon_a_moneda(pg.cod_moneda, v_cod_mon_local, nvl(pg.valor, 0)),v_redondeo)
                  END) - nvl(cb.mto_gar_utilizado, 0)) > 0
            AND EXISTS (select 1 from pr_cta_garantias_det de
                         WHERE de.fecha = pag_cal.fu_obt_fec_actual(1)
                           and pg.nro_garantia = de.nro_garantia
                           and pg.cod_garantia = de.cod_garantia);      
      -- Funciones.
      FUNCTION lf_obt_mto_distribuido(p_cod_garantia pr_garantias.cod_garantia%type, 
                                      p_nro_garantia pr_garantias.nro_garantia%type)
      RETURN NUMBER
      AS
      v_mto_dis_garantia cb_sal_inv_garantias.mto_dis_garantia%type :=0;
      BEGIN
         SELECT NVL(SUM(nvl(cs.mto_dis_garantia, 0)),0)
           INTO v_mto_dis_garantia
           FROM cb_sal_inv_garantias cs, ge_cuentas gc
          WHERE cs.fecha = v_fec_actual
            AND cs.nro_garantia = p_nro_garantia
            AND cs.cod_garantia = p_cod_garantia
            AND cs.nro_cuenta = gc.nro_cuenta;
            
         RETURN v_mto_dis_garantia;
           
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END; 
      
      -- Obtiene la deuda del cliente.
      FUNCTION lf_obt_deu_cliente(p_cod_persona ge_cla_operaciones.cod_persona%type)
      RETURN NUMBER
      AS
      v_mto_deuda           ge_cla_operaciones.tot_deu_real%type :=0;
      v_tot_deu_real        ge_cla_operaciones.tot_deu_real%type :=0;
      v_tot_deu_contingente ge_cla_operaciones.tot_deu_real%type :=0;
      BEGIN
         BEGIN
            SELECT nvl(SUM(nvl(tot_deu_real, 0) + nvl(t.tot_deu_contingente, 0)), 0) deuda -- la deuda ya es en moneda local siempre
              INTO v_tot_deu_real
              FROM ge_cla_operaciones t
             WHERE t.cod_persona = p_cod_persona
               AND t.cod_modulo <> 4
             GROUP BY t.cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               v_tot_deu_real := 0;
         END;
         --
         BEGIN
	          SELECT nvl(SUM(nvl(t.tot_deu_contingente,0)), 0) -- la deuda ya es en moneda local siempre
              INTO v_tot_deu_contingente
              FROM ge_cla_operaciones t
             WHERE t.cod_persona = p_cod_persona
               AND t.cod_modulo = 4
             GROUP BY t.cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               v_tot_deu_contingente := 0;
         END;
         
         v_mto_deuda := NVL(v_tot_deu_real,0) + NVL(v_tot_deu_contingente,0);
            
         RETURN v_mto_deuda;
           
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END; 
      -- Obtiene la deuda del codeudor.
      FUNCTION lf_obt_deu_codeudor(p_cod_persona ge_cla_operaciones.cod_persona%type)
      RETURN NUMBER
      AS
      v_mto_deuda           ge_cla_operaciones.tot_deu_real%type :=0;
      v_tot_deu_real        ge_cla_operaciones.tot_deu_real%type :=0;
      v_tot_deu_contingente ge_cla_operaciones.tot_deu_real%type :=0;
      BEGIN
         BEGIN
            SELECT nvl(SUM(nvl(o.tot_deu_real, 0)), 0) mto_riesgo -- la deuda ya es en moneda local siempre
              INTO v_tot_deu_real
              FROM ge_cla_operaciones o, ge_cta_clientes t
             WHERE t.nro_cuenta = o.nro_cuenta
               AND t.cod_persona = p_cod_persona
               AND t.cod_modulo <> 4
               AND t.relacion IN ('C', 'G');
         EXCEPTION
            WHEN no_data_found THEN
               v_tot_deu_real := 0;
         END;
         --
         BEGIN
            SELECT nvl(SUM(nvl(o.tot_deu_contingente,0)), 0) -- la deuda ya es en moneda local siempre
              INTO v_tot_deu_contingente
              FROM ge_cla_operaciones o, ge_cta_clientes t
             WHERE t.nro_cuenta = o.nro_cuenta
               AND t.cod_persona = p_cod_persona
               AND t.cod_modulo = 4
               AND t.relacion IN ('C', 'G');
         EXCEPTION
            WHEN no_data_found THEN
               v_tot_deu_contingente := 0;
         END;
         
         v_mto_deuda := NVL(v_tot_deu_real,0) + NVL(v_tot_deu_contingente,0);
            
         RETURN v_mto_deuda;
           
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END; 
      
      -- Obtiene el monto contabilizado COMPUTABLE de la garantia.
      FUNCTION lf_obt_mto_asiento(p_cod_garantia pr_garantias.cod_garantia%type, 
                                  p_nro_garantia pr_garantias.nro_garantia%type,
                                  p_cod_rubro    cb_rubros.cod_rubro%type)
      RETURN NUMBER
      AS
      v_mto_dis_garantia cb_sal_inv_garantias.mto_dis_garantia%type :=0;
      BEGIN
         SELECT NVL(SUM(NVL(a.mto_equ_local,0)),0) monto
           INTO v_mto_dis_garantia
           FROM ge_movimientos a, pr_garantias b, pr_gar_tipos c
          WHERE a.cod_tra_padre = 200 
            AND a.referencia = b.cod_garantia
            AND a.nro_documento = b.nro_garantia
            AND b.cod_garantia = p_cod_garantia
            AND b.nro_garantia = p_nro_garantia
            AND b.cod_garantia = c.cod_garantia
            AND fub_obt_rub_transaccion(a.cod_modulo, a.cod_modalidad,  a.cod_transaccion, a.cod_moneda, a.cod_persona, null, 'D') = p_cod_rubro;
                     
         RETURN v_mto_dis_garantia;
           
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END;
      
      FUNCTION lf_obt_mto_aplicado(p_nro_cuenta cb_sal_inv_garantias.nro_cuenta%type,
                                   p_tipo       cb_sal_inv_garantias.tip_saldo%type)
      RETURN NUMBER
      AS
      v_mto_dis_garantia cb_sal_inv_garantias.mto_dis_garantia%type :=0;
      BEGIN
         SELECT NVL(SUM(nvl(cs.mto_dis_garantia, 0)),0)
           INTO v_mto_dis_garantia
           FROM cb_sal_inv_garantias cs
          WHERE cs.fecha = v_fec_actual
            AND cs.nro_cuenta = p_nro_cuenta
            AND cs.tip_saldo = p_tipo;
            
         RETURN v_mto_dis_garantia;
           
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END; 
        
   BEGIN
      FOR gar IN c_gar_computable LOOP
         -- Asigno valores.
         v_mto_deu_cliente       := 0;
         v_mto_deu_codeudoria    := 0;
         v_mto_total             := 0;
         v_mto_distribuido       := 0;
         v_mto_dif_distribucion  := 0;
         v_mto_gar_utilizado     := 0;
         v_nro_garantia          := gar.nro_garantia;
         v_cod_garantia          := gar.cod_garantia;
         v_cod_persona           := gar.cod_persona;
         /*
         -- Obtengo hasta que monto puedo distribuir la garantía.
         v_mto_deu_cliente    := NVL(lf_obt_deu_cliente(gar.cod_persona),0);
         v_mto_deu_codeudoria := NVL(lf_obt_deu_codeudor(gar.cod_persona),0);
         --
         IF NVL(gar.monto,0) > NVL(v_mto_deu_cliente,0) THEN
            IF (NVL(gar.monto,0) - NVL(v_mto_deu_cliente,0)) > NVL(v_mto_deu_codeudoria,0) THEN
               v_mto_total := ROUND(NVL(v_mto_deu_cliente,0) + NVL(v_mto_deu_codeudoria,0),v_redondeo);
            ELSE               
               v_mto_total := ROUND(NVL(gar.monto,0),v_redondeo);
            END IF;
         ELSE
            v_mto_total := ROUND(NVL(gar.monto,0),v_redondeo);
         END IF;         
         
         -- Verifico si se puede distribuir la garantía.      
         v_mto_distribuido      := ROUND(NVL(lf_obt_mto_distribuido(gar.cod_garantia, gar.nro_garantia),0),v_redondeo);
         v_mto_dif_distribucion := 0;
         IF NVL(v_mto_total,0) > NVL(v_mto_distribuido,0) THEN
            v_mto_dif_distribucion := ROUND(NVL(v_mto_total,0) - NVL(v_mto_distribuido,0),v_redondeo);            
         END IF;  
         -- Verifico si el monto de distribución sea igual a cero.
         IF NVL(v_mto_dif_distribucion,0) > 0 THEN
            FOR reg IN c_cta_clientes(gar.cod_persona) LOOP
               v_tot_deuda := NVL(reg.tot_deu_real,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'C');
               IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN
               */
                  r_cbgar.fecha              := v_fec_actual;
                  r_cbgar.cod_garantia       := gar.cod_garantia;
                  r_cbgar.nro_garantia       := gar.nro_garantia;
                  r_cbgar.nro_cuenta         := gar.nro_cuenta;
                  r_cbgar.tip_saldo          := 'C';
                  r_cbgar.clasificacion      := 'COMPUTABLE';
                  r_cbgar.mto_deuda          := NVL(gar.tot_deu_real,0);
                  r_cbgar.mto_dis_garantia   := NVL(gar.monto,0);--NVL(v_tot_deuda,0);
                  r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');
                  r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                  lp_ins_inv_garantias(r_cbgar);
                  /*--
                  v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                  IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               ELSE
                  r_cbgar.fecha              := v_fec_actual;
                  r_cbgar.cod_garantia       := gar.cod_garantia;
                  r_cbgar.nro_garantia       := gar.nro_garantia;
                  r_cbgar.nro_cuenta         := reg.nro_cuenta;
                  r_cbgar.tip_saldo          := 'C';
                  r_cbgar.clasificacion      := 'COMPUTABLE';
                  r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                  r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                  r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                  r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                  lp_ins_inv_garantias(r_cbgar);
                  --
                  v_mto_dif_distribucion := 0;
                  exit;
               END IF;
            END LOOP;
            -- Distribuye el importe del interes devengado no cobrado de las cuentas del cliente.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_dev_cliente(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.dev_no_cobrado,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'I');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;            
            -- Distribuye a las cuentas del cliente - codeudoría.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_codeudoria(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.tot_deu_real,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'C');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'C';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'C';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;
            -- Distribuye el importe del interes devengado no cobrado de las cuentas vinculadas al cliente - codeudoría.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_dev_codeudoria(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.dev_no_cobrado,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'I');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;
            -- Actualiza el monto de distribución de las cuentas existentes por número de garantía.-
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cuentas(gar.cod_garantia,gar.nro_garantia) LOOP
                  IF NVL(v_mto_dif_distribucion,0) > 0 THEN
                     IF NVL(reg.monto,0) <= NVL(v_mto_dif_distribucion,0) THEN
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := reg.cod_garantia;
                        r_cbgar.nro_garantia       := reg.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := reg.tip_saldo;
                        r_cbgar.clasificacion      := reg.clasificacion;
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(reg.monto,0);
                        r_cbgar.cod_rubro          := reg.cod_rubro;
                        --- DYDMR-592
                        BEGIN
                           SELECT nvl(cod_transaccion1, cod_transaccion2)
                             INTO r_cbgar.cod_transaccion
                             FROM pr_gar_tipos
                            WHERE cod_garantia = r_cbgar.cod_garantia;
                        EXCEPTION
                           WHEN OTHERS THEN
                              r_cbgar.cod_transaccion := nvl(gar.tra_computable,gar.tra_no_computable);
                        END;
                        ---
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  NVL(v_mto_dif_distribucion,0) - NVL(reg.monto,0);
                     ELSE
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := reg.cod_garantia;
                        r_cbgar.nro_garantia       := reg.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := reg.tip_saldo;
                        r_cbgar.clasificacion      := reg.clasificacion;
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                        r_cbgar.cod_rubro          := reg.cod_rubro;      
                        r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  0;
                        exit;
                     END IF;
                  END IF;
               END LOOP;
            END IF; 
            -- Actualiza el monto de distribución de las cuentas existentes por código de persona.-
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_aju_cuentas(gar.cod_persona) LOOP
                  IF NVL(v_mto_dif_distribucion,0) > 0 THEN
                     IF NVL(reg.monto,0) <= NVL(v_mto_dif_distribucion,0) THEN
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := gar.cod_garantia;
                        r_cbgar.nro_garantia       := gar.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := 'C';
                        r_cbgar.clasificacion      := 'COMPUTABLE';
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(reg.monto,0);
                        r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                        r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  NVL(v_mto_dif_distribucion,0) - NVL(reg.monto,0);
                     ELSE
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := gar.cod_garantia;
                        r_cbgar.nro_garantia       := gar.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := 'C';
                        r_cbgar.clasificacion      := 'COMPUTABLE';
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);     
                        r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_computable,gar.tra_no_computable), gar.cod_moneda, gar.cod_persona, null, 'D');
                        r_cbgar.cod_transaccion    := nvl(gar.tra_computable,gar.tra_no_computable); --DYDMR-592
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  0;
                        exit;
                     END IF;
                  END IF;
               END LOOP;
            END IF;   
         END IF;*/
      END LOOP;
      ---
      FOR gar IN c_gar_utilizado LOOP
         -- Inserto el registro que corresponde a la parte no computable de la garantía.
         --v_mto_gar_utilizado := ROUND(NVL(lf_obt_mto_distribuido(gar.cod_garantia,gar.nro_garantia),0),v_redondeo);
         --IF (NVL(gar.monto,0) - NVL(v_mto_gar_utilizado,0)) > 0 THEN
            r_cbgar.fecha              := v_fec_actual;
            r_cbgar.cod_garantia       := gar.cod_garantia;
            r_cbgar.nro_garantia       := gar.nro_garantia;
            r_cbgar.nro_cuenta         := '999999999';
            r_cbgar.tip_saldo          := 'C';
            r_cbgar.clasificacion      := 'NO COMPUTABLE';
            r_cbgar.mto_deuda          := 0;
            r_cbgar.mto_dis_garantia   := ROUND(NVL(gar.mto_disponible,0),v_redondeo);--ROUND((NVL(gar.monto,0) - NVL(v_mto_gar_utilizado,0)),v_redondeo);
            r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
            r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
            lp_ins_inv_garantias(r_cbgar);
         --END IF;
      END LOOP;
                  
      -- Garantías no computables.
      FOR gar IN c_gar_nocomputable LOOP
         -- Asigno valores.
         v_mto_deu_cliente       := 0;
         v_mto_deu_codeudoria    := 0;
         v_mto_total             := 0;
         v_mto_distribuido       := 0;
         v_mto_dif_distribucion  := 0;
         v_mto_dif_distribucion  := 0;
         v_mto_gar_utilizado     := 0;
         v_nro_garantia          := gar.nro_garantia;
         v_cod_garantia          := gar.cod_garantia;
         v_cod_persona           := gar.cod_persona;
         -- Obtengo hasta que monto puedo distribuir la garantía.
         v_mto_deu_cliente    := NVL(lf_obt_deu_cliente(gar.cod_persona),0);
         v_mto_deu_codeudoria := NVL(lf_obt_deu_codeudor(gar.cod_persona),0);
         --
         IF NVL(gar.monto,0) > NVL(v_mto_deu_cliente,0) THEN
            IF (NVL(gar.monto,0) - NVL(v_mto_deu_cliente,0)) > NVL(v_mto_deu_codeudoria,0) THEN
               v_mto_total := ROUND(NVL(v_mto_deu_cliente,0) + NVL(v_mto_deu_codeudoria,0),v_redondeo);
            ELSE               
               v_mto_total := ROUND(NVL(gar.monto,0),v_redondeo);
            END IF;
         ELSE
            v_mto_total := ROUND(NVL(gar.monto,0),v_redondeo);
         END IF;         
         
         -- Verifico si se puede distribuir la garantía.      
         v_mto_distribuido      := ROUND(NVL(lf_obt_mto_distribuido(gar.cod_garantia, gar.nro_garantia),0),0);
         v_mto_dif_distribucion := 0;
         IF NVL(v_mto_total,0) > NVL(v_mto_distribuido,0) THEN
            v_mto_dif_distribucion := ROUND(NVL(v_mto_total,0) - NVL(v_mto_distribuido,0),v_redondeo);            
         END IF;  
         -- Verifico si el monto de distribución sea igual a cero.
         IF NVL(v_mto_dif_distribucion,0) > 0 THEN
            FOR reg IN c_cta_clientes(gar.cod_persona) LOOP
               -- Obtengo el monto de la deuda actual.;
               v_tot_deuda := NVL(reg.tot_deu_real,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'C');
               IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN   
                  r_cbgar.fecha              := v_fec_actual;
                  r_cbgar.cod_garantia       := gar.cod_garantia;
                  r_cbgar.nro_garantia       := gar.nro_garantia;
                  r_cbgar.nro_cuenta         := reg.nro_cuenta;
                  r_cbgar.tip_saldo          := 'C';
                  r_cbgar.clasificacion      := 'NO COMPUTABLE';
                  r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                  r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                  r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                  r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                  lp_ins_inv_garantias(r_cbgar);
                  --
                  v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                  IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               ELSE
                  r_cbgar.fecha              := v_fec_actual;
                  r_cbgar.cod_garantia       := gar.cod_garantia;
                  r_cbgar.nro_garantia       := gar.nro_garantia;
                  r_cbgar.nro_cuenta         := reg.nro_cuenta;
                  r_cbgar.tip_saldo          := 'C';
                  r_cbgar.clasificacion      := 'NO COMPUTABLE';
                  r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                  r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                  r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                  r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                  lp_ins_inv_garantias(r_cbgar);
                  --
                  v_mto_dif_distribucion := 0;
                  exit;
               END IF;
            END LOOP;
            -- Distribuye el importe del interes devengado no cobrado de las cuentas del cliente.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_dev_cliente(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.dev_no_cobrado,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'I');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;
            -- Distribuye a las cuentas del cliente - codeudoría.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_codeudoria(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.tot_deu_real,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'C');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'C';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_tot_deuda,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'C';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.tot_deu_real,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;
            -- Distribuye el importe del interes devengado no cobrado de las cuentas vinculadas al cliente - codeudoría.
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_cta_dev_codeudoria(gar.cod_persona) LOOP
                  v_tot_deuda := NVL(reg.dev_no_cobrado,0) - lf_obt_mto_aplicado(reg.nro_cuenta,'I');
                  IF  NVL(v_mto_dif_distribucion,0) > NVL(v_tot_deuda,0) THEN                              
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(v_tot_deuda,0);
                     r_cbgar.mto_dis_garantia   := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := NVL(v_mto_dif_distribucion,0) - NVL(v_tot_deuda,0);
                     IF NVL(v_mto_dif_distribucion,0) <= 0 THEN
                        v_mto_dif_distribucion := 0;
                        exit;
                     END IF;
                  ELSE
                     r_cbgar.fecha              := v_fec_actual;
                     r_cbgar.cod_garantia       := gar.cod_garantia;
                     r_cbgar.nro_garantia       := gar.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := 'I';
                     r_cbgar.clasificacion      := 'NO COMPUTABLE';
                     r_cbgar.mto_deuda          := NVL(reg.dev_no_cobrado,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion := 0;
                     exit;
                  END IF;
               END LOOP;
            END IF;   
         END IF;
         -- Actualiza el monto de distribución de las cuentas existentes por número de garantía.-
         IF NVL(v_mto_dif_distribucion,0) > 0 THEN
            FOR reg IN c_cuentas(gar.cod_garantia,gar.nro_garantia) LOOP
               IF NVL(v_mto_dif_distribucion,0) > 0 THEN
                  IF NVL(reg.monto,0) <= NVL(v_mto_dif_distribucion,0) THEN
                     r_cbgar.fecha              := reg.fecha;
                     r_cbgar.cod_garantia       := reg.cod_garantia;
                     r_cbgar.nro_garantia       := reg.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := reg.tip_saldo;
                     r_cbgar.clasificacion      := reg.clasificacion;
                     r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                     r_cbgar.mto_dis_garantia   := NVL(reg.monto,0);
                     r_cbgar.cod_rubro          := reg.cod_rubro;      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                     --
                     v_mto_dif_distribucion :=  NVL(v_mto_dif_distribucion,0) - NVL(reg.monto,0);
                  ELSE
                     r_cbgar.fecha              := reg.fecha;
                     r_cbgar.cod_garantia       := reg.cod_garantia;
                     r_cbgar.nro_garantia       := reg.nro_garantia;
                     r_cbgar.nro_cuenta         := reg.nro_cuenta;
                     r_cbgar.tip_saldo          := reg.tip_saldo;
                     r_cbgar.clasificacion      := reg.clasificacion;
                     r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                     r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                     r_cbgar.cod_rubro          := reg.cod_rubro;      
                     r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                     lp_ins_inv_garantias(r_cbgar);
                      --
                     v_mto_dif_distribucion :=  0;
                     exit;
                  END IF;
               END IF;
            END LOOP;
            -- Actualiza el monto de distribución de las cuentas existentes por código de persona.-
            IF NVL(v_mto_dif_distribucion,0) > 0 THEN
               FOR reg IN c_aju_cuentas(gar.cod_persona) LOOP
                  IF NVL(v_mto_dif_distribucion,0) > 0 THEN
                     IF NVL(reg.monto,0) <= NVL(v_mto_dif_distribucion,0) THEN
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := gar.cod_garantia;
                        r_cbgar.nro_garantia       := gar.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := 'C';
                        r_cbgar.clasificacion      := 'NO COMPUTABLE';
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(reg.monto,0);
                        r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                        r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  NVL(v_mto_dif_distribucion,0) - NVL(reg.monto,0);
                     ELSE
                        r_cbgar.fecha              := reg.fecha;
                        r_cbgar.cod_garantia       := gar.cod_garantia;
                        r_cbgar.nro_garantia       := gar.nro_garantia;
                        r_cbgar.nro_cuenta         := reg.nro_cuenta;
                        r_cbgar.tip_saldo          := 'C';
                        r_cbgar.clasificacion      := 'NO COMPUTABLE';
                        r_cbgar.mto_deuda          := NVL(reg.mto_deuda,0);
                        r_cbgar.mto_dis_garantia   := NVL(v_mto_dif_distribucion,0);
                        r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
                        r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
                        lp_ins_inv_garantias(r_cbgar);
                        --
                        v_mto_dif_distribucion :=  0;
                        exit;
                     END IF;
                  END IF;
               END LOOP;
            END IF;
         END IF;   
         -- Inserto el registro que corresponde a la parte no computable de la garantía.
         v_mto_gar_utilizado := NVL(lf_obt_mto_distribuido(gar.cod_garantia,gar.nro_garantia),0);
         IF (NVL(gar.monto,0) - NVL(v_mto_gar_utilizado,0)) > 0 THEN
            r_cbgar.fecha              := v_fec_actual;
            r_cbgar.cod_garantia       := gar.cod_garantia;
            r_cbgar.nro_garantia       := gar.nro_garantia;
            r_cbgar.nro_cuenta         := '999999999';
            r_cbgar.tip_saldo          := 'C';
            r_cbgar.clasificacion      := 'NO COMPUTABLE';
            r_cbgar.mto_deuda          := 0;
            r_cbgar.mto_dis_garantia   := ROUND((NVL(gar.monto,0) - NVL(v_mto_gar_utilizado,0)),v_redondeo);
            r_cbgar.cod_rubro          := fub_obt_rub_transaccion(gar.cod_modulo, gar.cod_modalidad,  nvl(gar.tra_no_computable,gar.tra_computable), gar.cod_moneda, gar.cod_persona, null, 'D');      
            r_cbgar.cod_transaccion    := nvl(gar.tra_no_computable,gar.tra_computable); --DYDMR-592
            lp_ins_inv_garantias(r_cbgar);
         END IF;
      END LOOP;
      
      -- Verifica la diferencia de redondeo entre el inventario y los asientos generados de los rubros computables y no computables.
      v_mto_gar_contabilizado := 0;
      FOR reg IN c_cta_mon_extranjera LOOP
         v_mto_gar_contabilizado := NVL(lf_obt_mto_asiento(reg.cod_garantia, reg.nro_garantia, reg.cod_rubro),0);
         v_existe := 0;
         IF NVL(reg.mto_dis_garantia,0) <> NVL(v_mto_gar_contabilizado,0) AND ((NVL(reg.mto_dis_garantia,0) - NVL(v_mto_gar_contabilizado,0)) BETWEEN -100 AND 100) THEN            
            FOR reg_1 IN c_cta_inventario(reg.cod_garantia, reg.nro_garantia, reg.cod_rubro) LOOP
               UPDATE cb_sal_inv_garantias a
                  SET a.mto_dis_garantia = ROUND(NVL(a.mto_dis_garantia,0) - (NVL(reg.mto_dis_garantia,0) - NVL(v_mto_gar_contabilizado,0)),0)
                WHERE a.fecha = v_fec_actual
                  AND a.cod_garantia = reg.cod_garantia 
                  AND a.nro_garantia = reg.nro_garantia
                  AND a.nro_cuenta = reg_1.nro_cuenta
                  AND a.tip_saldo = reg_1.tip_saldo;
               --
               v_existe := 1;
            END LOOP;
         END IF;
         IF v_existe = 0 AND ((NVL(reg.mto_dis_garantia,0) - NVL(v_mto_gar_contabilizado,0)) BETWEEN -100 AND 100) THEN
            IF (NVL(reg.mto_dis_garantia,0) - NVL(v_mto_gar_contabilizado,0)) <> 0 THEN
               r_cbgar.fecha              := v_fec_actual;
               r_cbgar.cod_garantia       := reg.cod_garantia;
               r_cbgar.nro_garantia       := reg.nro_garantia;
               r_cbgar.nro_cuenta         := '99999999';
               r_cbgar.tip_saldo          := 'C';
               r_cbgar.clasificacion      := reg.clasificacion;
               r_cbgar.mto_deuda          := 0;
               r_cbgar.mto_dis_garantia   := (ROUND((NVL(reg.mto_dis_garantia,0) - NVL(v_mto_gar_contabilizado,0)),v_redondeo) * (-1));
               r_cbgar.cod_rubro          := reg.cod_rubro;      
               r_cbgar.cod_transaccion    := nvl(reg.tra_no_computable,reg.tra_computable); --DYDMR-592
               lp_ins_inv_garantias(r_cbgar);   
            END IF;
         END IF;
      END LOOP;
   END;
BEGIN   
   v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
   -- Elimino los datos de la fecha de proceso.
   delete cb_sal_inv_garantias a where a.fecha = v_fec_actual;     
   -- Genero los datos.
   lp_gen_inv_garantias;
EXCEPTION
   WHEN OTHERS THEN  
      raise_application_error(-20000, 'Nro. Garantia ' || v_nro_garantia || 'Cod. Persona ' || v_cod_persona || ' - ' ||SQLERRM);
END;

 

 
/
