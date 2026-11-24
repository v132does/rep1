create or replace PROCEDURE    IT.PRP_GEN_CTA_GARANTIA IS
   v_mto_aplicado        pr_garantias.mto_aplicado%TYPE;
   v_mto_gar_aplicado    pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_mto_apl_utilizado   pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_mto_apl_aplicado    pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_mto_disponible      pr_garantias.valor%TYPE;
   v_mto_uti_disponible  pr_garantias.valor%TYPE;       --nuevo
   v_mto_apl_disponible  pr_garantias.valor%TYPE;       --nuevo
   v_tot_saldo           pr_garantias.mto_aplicado%TYPE;
   v_tot_utilizado       pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_tot_aplicado        pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_mto_apl_computable  pr_garantias.mto_aplicado%TYPE;
   v_mto_computable      pr_garantias.mto_aplicado%TYPE;
   v_valor               pr_garantias.valor%TYPE;
   v_val_aplicado        pr_garantias.mto_aplicado%TYPE;
   v_val_apl_utilizado   pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_val_apl_aplicado    pr_garantias.mto_aplicado%TYPE;-- nuevo
   v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE;
   v_mto_linea           ta_cta_tarjetas.lin_credito%TYPE;
   v_est_tarjeta         ta_cta_tarjetas.estado%TYPE;
   v_mon_local           ba_monedas.cod_moneda%TYPE DEFAULT pag_gen.fu_obt_mon_local;
   v_red_credito         NUMBER(2);
   v_sal_cliente         pr_garantias.mto_aplicado%TYPE; --ajuste
   v_control             NUMBER(3);
   v_mon_anterior        ba_monedas.cod_moneda%TYPE := null;
   v_gar                 varchar2(200);
   v_contador            number;
   v_monto               number;
   v_acu_monto           number;
   v_fec_actual          ge_calendarios.fec_actual%type := pae_cnf.FU_OBT_FEC_ACTUAL(1);
   v_con_fecha           varchar2(1) := 'N' ;
   v_con_fecha1          varchar2(1) := 'N' ;
   v_cat_automatica      ge_clientes.cat_automatica%type;
   v_can_dia_ult_clasif  NUMBER;   
   v_cod_gar_fogapy      ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_GAR_FOGAPY');
   -- Variables utilizadas CIE-290
   v_sql VARCHAR2(1000);
   TYPE typ_tabla_list IS TABLE OF VARCHAR2(30);
   v_tablas typ_tabla_list := typ_tabla_list();
   v_err                 varchar2(1000);
   v_err_aux             varchar2(1000);
   v_error_trg           varchar2(1000);
   v_por_mto_riesgo      number := 0;
   --Cursores.
   -- Cursor General de Cuentas.
   CURSOR c_cuentas IS
      SELECT p.cod_persona,
       p.dia_atraso,
       p.orden,
       p.saldo,
       p.cod_modulo,
       p.cod_modalidad,
       p.nro_cuenta,
       p.cod_moneda,
       p.mto_linea,
       p.estado,
       p.mto_aplicado,
       (
         CASE 
             WHEN p.cod_modulo = 5 AND p.estado != 'B' THEN
                 GREATEST(p.saldo, p.mto_linea)
             ELSE p.saldo
         END
         - p.mto_aplicado
       ) AS tot_saldo
  FROM pv_cta_garantias p
 ORDER BY p.orden, p.saldo DESC, p.cod_persona;
 ----- type de cursor c_cuentas  
  TYPE cta_garantia_rec IS RECORD (
    cod_persona     pv_cta_garantias.cod_persona%TYPE,
    dia_atraso      pv_cta_garantias.dia_atraso%TYPE,
    orden           pv_cta_garantias.orden%TYPE,
    saldo           pv_cta_garantias.saldo%TYPE,
    cod_modulo      pv_cta_garantias.cod_modulo%TYPE,
    cod_modalidad   pv_cta_garantias.cod_modalidad%TYPE,
    nro_cuenta      pv_cta_garantias.nro_cuenta%TYPE,
    cod_moneda      pv_cta_garantias.cod_moneda%TYPE,
    mto_linea       pv_cta_garantias.mto_linea%TYPE,
    estado          pv_cta_garantias.estado%TYPE,
    mto_aplicado    pv_cta_garantias.mto_aplicado%TYPE,
    tot_saldo       NUMBER);
    TYPE cta_garantias_type IS TABLE OF cta_garantia_rec INDEX BY PLS_INTEGER;
    c_ctas cta_garantias_type;
 --- coleccion para cta_garantias           
    v_cc_ctas typ_cta_garantia_tab := typ_cta_garantia_tab();
    v_ta_ctas typ_cta_garantia_tab := typ_cta_garantia_tab();
    v_pr_ctas typ_cta_garantia_tab := typ_cta_garantia_tab();
    v_ov_ctas typ_cta_garantia_tab := typ_cta_garantia_tab();
    v_cx_ctas typ_cta_garantia_tab := typ_cta_garantia_tab();

/* Cursor sólo para Préstamos Hipotecarios o Construcción*/
     CURSOR c_pre_hipotecarios IS
          SELECT cc.cod_persona,
                1,
                 --> Jira CROMG-50: A Pedido de Maria Esther Chavez y Domingo Daniel Ramirez se excluye  los intereses devegandos no cobrados
                nvl(p.sal_capital, 0) /*+ nvl(p.dev_no_cobrado, 0)*/ mto_riesgo,
                cc.cod_modulo,
                cc.cod_modalidad,
                cc.nro_cuenta,
                p.cod_moneda,
                0,
                p.estado,
                p.rowid fila
           FROM pr_cta_prestamos p
           JOIN ge_est_cuentas e on p.estado = e.estado
           JOIN ge_cta_clientes cc on p.nro_cuenta = cc.nro_cuenta
          WHERE p.cod_modulo = e.cod_modulo
            AND p.cod_modalidad = e.cod_modalidad
            AND e.activo = 'S'
            AND p.estado <> 'I'
            AND cc.relacion = 'P'
            AND exists (select 1
                          from ge_par_dinamicos g
                         where g.parametro in ('PRE_MAD_CONSTRUCCIONES','MAD_HIPOTECARIOS')
                           and g.cod_modulo = e.cod_modulo
                           and g.cod_modalidad = e.cod_modalidad
                           and g.val_parametro = 'S')
          ORDER BY 1 DESC, 3;

  /* Cursor sólo para Garantías Hipotecarias*/
   CURSOR c_gar_hipotecario(p_cliente pr_garantias.cod_persona%TYPE) IS
      SELECT g.nro_garantia,
             g.valor,
             g.mto_apl_valor,
             g.mto_aplicado,
             d.por_bco_central cobertura,
             g.cod_moneda,
             d.cod_garantia,
             d.pri_aplicacion,
             g.cod_persona,
             d.computable
        FROM pr_garantias g, pr_gar_tipos d
       WHERE nvl(g.estado, 'C') = 'C'
         AND g.tipo = 'A'
         AND nvl(g.ind_uti_tercero, 'N') = 'N'
         AND g.cod_garantia = d.cod_garantia
         AND g.cod_persona = p_cliente
         AND g.cod_garantia in (3, 13)
       ORDER BY g.valor DESC;

    /* Cursor para Clientes de Préstamos Hipotecarios o Construcción*/
   CURSOR c_cli_hipotecarios(p_nro_cta_garantia pr_cta_garantias.nro_cuenta%type) IS
      SELECT 1 orden,
             a.cod_persona,
             a.nro_cuenta,
             a.nro_garantia,
             a.cod_garantia,
             a.mto_riesgo,
             b.cod_moneda moneda,
             b.cod_modulo,
             a.rowid fila
        FROM pr_cta_garantias a, ge_cuentas b
       WHERE a.nro_cuenta = b.nro_cuenta
         AND a.mto_riesgo > 0
         AND a.cod_garantia != 2
      AND a.nro_cuenta = p_nro_cta_garantia
      AND exists (select 1
                          from ge_par_dinamicos g
                         where g.parametro in ('PRE_MAD_CONSTRUCCIONES','MAD_HIPOTECARIOS')
                           and g.cod_modulo = b.cod_modulo
                           and g.cod_modalidad = b.cod_modalidad
                           and g.val_parametro = 'S')
      ORDER BY  2;

   -- Cursor de clientes que poseen monto de riesgo mayor a cero para realizar la distribucion de las garantias abiertas y que pueden ser utilizadas por terceros.
    CURSOR c_clientes IS
       SELECT a.orden,
              a.cod_persona,
              a.mto_riesgo,
              a.nro_cuenta,
              a.moneda,
              a.cod_modulo,
              a.fila,
              CASE
                  WHEN a.moneda != v_mon_local THEN pag_gen.fu_con_mon_a_moneda(a.moneda, v_mon_local, a.mto_riesgo)
                  ELSE a.mto_riesgo
              END AS mto_orden
         FROM pv_mto_apl_gar_clientes a
       WHERE EXISTS (
           SELECT 1
             FROM pr_garantias g
            WHERE g.cod_persona = a.cod_persona
              AND (g.estado = 'C' OR g.estado IS NULL)
              AND g.tipo = 'A'
              AND (g.ind_uti_tercero = 'N' OR g.ind_uti_tercero IS NULL)
              AND (g.cod_garantia NOT IN (3, 13)
                   OR (g.cod_garantia IN (3, 13) AND g.valor - NVL(g.mto_aplicado, 0) > 0)))
              ORDER BY 1, 8 DESC, 2;
               TYPE t_clientes_tab IS TABLE OF c_clientes%ROWTYPE;
               reg t_clientes_tab;    
   --Cursor de Garantias abiertas.
  CURSOR c_garantias(p_cliente pr_garantias.cod_persona%TYPE) IS
     SELECT g.nro_garantia,
            g.valor,
            g.mto_apl_valor,
            g.mto_aplicado,
            d.por_bco_central AS cobertura,
            g.cod_moneda,
            d.cod_garantia,
            d.pri_aplicacion,
            g.cod_persona,
            d.computable
        FROM pr_garantias g
        JOIN pr_gar_tipos d
            ON g.cod_garantia = d.cod_garantia
        WHERE (g.estado = 'C' OR g.estado IS NULL)
            AND g.tipo = 'A'
            AND g.cod_persona = p_cliente
            AND (g.ind_uti_tercero = 'N' OR g.ind_uti_tercero IS NULL)
            AND ((g.cod_garantia NOT IN (3, 13)) OR
            (g.cod_garantia IN (3, 13) AND g.valor - NVL(g.mto_aplicado,0) > 0))
        ORDER BY 8, 2 DESC;
   --Cursor de Garantías cerradas.
   CURSOR c_gar_cerradas IS
      SELECT g.nro_garantia,
             g.valor,
             g.mto_apl_valor,
             g.mto_aplicado,
             d.por_bco_central cobertura,
             g.cod_moneda,
             d.cod_garantia,
             d.computable
        FROM pr_garantias g, pr_gar_tipos d
       WHERE nvl(g.estado, 'C') IN ('C', 'V')
         AND g.tipo = 'C'
         AND g.cod_garantia = d.cod_garantia
         AND g.cod_garantia > 2
       ORDER BY d.pri_aplicacion, g.valor DESC;
--CIE-91 - 1er cursor unificado
-- Cursor que obtiene las deudas del titular de las garantia y de los terceros 
-- y distribuye la misma de acuerdo a la clasificacion de los clientes.
-- Cursor garantias cerradas
    CURSOR c_deu_garantias IS
        SELECT t.orden,
               t.cat_riesgo,
               t.mto_riesgo,
               t.nro_cuenta,
               t.nro_garantia,
               t.cod_moneda,
               t.cod_modulo,
               t.cod_garantia,
               t.fila,
               t.cod_persona,
               g.valor,
               g.mto_apl_valor,
               g.mto_aplicado,
               d.por_bco_central cobertura,
               g.cod_moneda,
               d.cod_garantia,
               d.computable,
			   g.estado
          FROM pv_deu_gar_terceros_jj t, pr_garantias g, pr_gar_tipos d
          WHERE NVL(g.estado, 'C') IN ('C', 'V')
            AND g.tipo = 'C'
            AND g.cod_garantia = d.cod_garantia
            AND g.cod_garantia > 2
            AND t.nro_garantia = g.nro_garantia;
 -- Tipo de registro
    TYPE t_deu_terceros_rec IS RECORD (
        orden           pv_deu_gar_terceros_jj.orden%TYPE,
        cat_riesgo      pv_deu_gar_terceros_jj.cat_riesgo%TYPE,
        mto_riesgo      pv_deu_gar_terceros_jj.mto_riesgo%TYPE,
        nro_cuenta      pv_deu_gar_terceros_jj.nro_cuenta%TYPE,
        nro_garantia    pv_deu_gar_terceros_jj.nro_garantia%TYPE,
        cod_moneda      pv_deu_gar_terceros_jj.cod_moneda%TYPE,
        cod_modulo      pv_deu_gar_terceros_jj.cod_modulo%TYPE,
        cod_garantia    pv_deu_gar_terceros_jj.cod_garantia%TYPE,
        fila            pv_deu_gar_terceros_jj.fila%TYPE,
        cod_persona     pv_deu_gar_terceros_jj.cod_persona%TYPE,
        g_valor         pr_garantias.valor%TYPE,
        g_mto_apl_valor pr_garantias.mto_apl_valor%TYPE,
        g_mto_aplicado  pr_garantias.mto_aplicado%TYPE,
        cobertura       pr_gar_tipos.por_bco_central%TYPE,
        cod_moneda_vencida   pr_garantias.cod_moneda%TYPE,
        g_cod_garantia  pr_gar_tipos.cod_garantia%TYPE,
        computable      pr_gar_tipos.computable%TYPE,
		g_estado      pr_garantias.estado%TYPE);

    TYPE t_deu_terceros_tab IS TABLE OF t_deu_terceros_rec;
    v_deu_terceros_tab t_deu_terceros_tab;

   --Cursor de Garantias abiertas y que pueden ser utilizadas por terceros.
   CURSOR c_gar_terceros IS
      SELECT g.nro_garantia,
             nvl(g.valor, 0) valor,
             nvl(g.mto_apl_valor, 0) mto_apl_valor,
             g.mto_aplicado,
             d.por_bco_central cobertura,
             g.cod_moneda,
             d.cod_garantia,
             g.cod_persona
        FROM pr_garantias g, pr_gar_tipos d
       WHERE nvl(g.estado, 'C') = 'C'
         AND g.tipo = 'A'
         AND nvl(g.ind_uti_tercero, 'N') = 'S'
         AND g.cod_garantia = d.cod_garantia
       ORDER BY d.pri_aplicacion, g.valor DESC;
       
--CIE-91 2do cursor unificado
     CURSOR c_gara_terceros IS
        SELECT t.orden,
               t.cat_riesgo,
               t.mto_riesgo,
               t.nro_cuenta,
               t.nro_garantia,
               t.cod_moneda,
               t.cod_modulo,
               t.cod_garantia,
               t.fila,
               t.cod_persona,
               nvl(g.valor, 0) valor,
               nvl(g.mto_apl_valor, 0) mto_apl_valor,
               g.mto_aplicado,
               d.por_bco_central cobertura,
               g.cod_moneda,
               d.cod_garantia,
               g.cod_persona
          FROM pv_deu_gar_terceros_jj t, pr_garantias g, pr_gar_tipos d
           WHERE nvl(g.estado, 'C') = 'C'
             AND g.tipo = 'A'
             AND nvl(g.ind_uti_tercero, 'N') = 'S'
             AND g.cod_garantia = d.cod_garantia
             and g.nro_garantia = t.nro_garantia;
    -- Definición de tipo de registro
    TYPE t_gara_terceros IS RECORD (
        orden            pv_deu_gar_terceros_jj.orden%TYPE,
        cat_riesgo       pv_deu_gar_terceros_jj.cat_riesgo%TYPE,
        mto_riesgo       pv_deu_gar_terceros_jj.mto_riesgo%TYPE,
        nro_cuenta       pv_deu_gar_terceros_jj.nro_cuenta%TYPE,
        nro_garantia     pv_deu_gar_terceros_jj.nro_garantia%TYPE,
        cod_moneda       pv_deu_gar_terceros_jj.cod_moneda%TYPE,
        cod_modulo       pv_deu_gar_terceros_jj.cod_modulo%TYPE,
        cod_garantia     pv_deu_gar_terceros_jj.cod_garantia%TYPE,
        fila             pv_deu_gar_terceros_jj.fila%TYPE,
        cod_persona      pv_deu_gar_terceros_jj.cod_persona%TYPE,
        valor            pr_garantias.valor%TYPE,
        mto_apl_valor    pr_garantias.mto_apl_valor%TYPE,
        mto_aplicado     pr_garantias.mto_aplicado%TYPE,
        cobertura        pr_gar_tipos.por_bco_central%TYPE,
        cod_moneda_b     pr_garantias.cod_moneda%TYPE,
        cod_garantia_b   pr_garantias.cod_garantia%TYPE,
        cod_persona_b    pr_garantias.cod_persona%TYPE
    );

    TYPE t_gara_terceros_tab IS TABLE OF t_gara_terceros;
    v_gara_terceros t_gara_terceros_tab;



   --Cursor de Operaciones de Terceros que utilizan Garantias Abiertas.
   CURSOR c_ope_terceros IS
   -- Prestamos.
      SELECT DISTINCT a.nro_cuenta, 2 orden
        FROM pr_cta_garantias a
       WHERE a.nro_garantia IN (SELECT g.nro_garantia
                                  FROM pr_garantias g, pr_gar_tipos d
                                 WHERE nvl(g.estado, 'C') IN ('C', 'V')
                                   AND g.tipo = 'A'
                                   AND nvl(g.ind_uti_tercero, 'N') = 'S'
                                   AND g.cod_garantia = d.cod_garantia)

      UNION ALL
      -- Cuenta Corriente.
      SELECT DISTINCT a.nro_cuenta, 4
        FROM cc_cta_garantias a
       WHERE a.nro_garantia IN (SELECT g.nro_garantia
                                  FROM pr_garantias g, pr_gar_tipos d
                                 WHERE nvl(g.estado, 'C') IN ('C', 'V')
                                   AND g.tipo = 'A'
                                   AND nvl(g.ind_uti_tercero, 'N') = 'S'
                                   AND g.cod_garantia = d.cod_garantia)

      UNION ALL
      -- Tarjetas.
      SELECT DISTINCT a.nro_cuenta, 5
        FROM ta_cta_garantias a
       WHERE a.nro_garantia IN (SELECT g.nro_garantia
                                  FROM pr_garantias g, pr_gar_tipos d
                                 WHERE nvl(g.estado, 'C') IN ('C', 'V')
                                   AND g.tipo = 'A'
                                   AND nvl(g.ind_uti_tercero, 'N') = 'S'
                                   AND g.cod_garantia = d.cod_garantia)

      UNION ALL
      -- Operaciones Vencidas.
      SELECT DISTINCT a.nro_cuenta, 1
        FROM ov_cta_garantias a
       WHERE a.nro_garantia IN (SELECT g.nro_garantia
                                  FROM pr_garantias g, pr_gar_tipos d
                                 WHERE nvl(g.estado, 'C') IN ('C', 'V')
                                   AND g.tipo = 'A'
                                   AND nvl(g.ind_uti_tercero, 'N') = 'S'
                                   AND g.cod_garantia = d.cod_garantia)

      UNION ALL
      -- Comercio Exterior.
      SELECT DISTINCT a.nro_cuenta, 3
        FROM cx_cta_garantias a
       WHERE a.nro_garantia IN (SELECT g.nro_garantia
                                  FROM pr_garantias g, pr_gar_tipos d
                                 WHERE nvl(g.estado, 'C') IN ('C', 'V')
                                   AND g.tipo = 'A'
                                   AND nvl(g.ind_uti_tercero, 'N') = 'S'
                                   AND g.cod_garantia = d.cod_garantia)
    ORDER BY 2;

    TYPE t_ope_terceros_record IS RECORD (
       nro_cuenta    cc_cta_garantias.nro_cuenta%TYPE,
       orden         NUMBER
    );

    TYPE t_ope_terceros_table IS TABLE OF t_ope_terceros_record;
    v_ope_terceros  t_ope_terceros_table;

   --Cursor que obtiene las deudas del titular de las garantia y de los terceros y distribuye la misma de acuerdo a la clasificacion de los clientes.
   CURSOR c_deu_terceros(p_cod_garantia pr_garantias.nro_garantia%TYPE) IS
      SELECT t.orden,
             t.cat_riesgo,
             t.mto_riesgo,
             t.nro_cuenta,
             t.nro_garantia,
             t.cod_moneda,
             t.cod_modulo,
             t.cod_garantia,
             t.fila,
             t.cod_persona
        FROM pv_deu_gar_terceros_jj t
       WHERE t.nro_garantia = p_cod_garantia
       ORDER BY 2 DESC, 1, 3 DESC;

 -- Cursor de operaciones que deben ser ajustadas con garantías no computables(SOLA FIRMA) cuando el monto de riesgo es mayor al monto aplicado.
   CURSOR c_aju_tot_garantia IS
   -- Prestamos.
      SELECT v.cod_moneda, v.cod_modulo, v.nro_cuenta, v.mto_aplicado, v.mto_riesgo
        FROM (SELECT b.cod_moneda,
                     b.cod_modulo,
                     a.nro_cuenta,
                     SUM(a.mto_aplicado) mto_aplicado,
                     MAX(a.mto_riesgo) mto_riesgo
                FROM pr_cta_garantias a, pr_cta_prestamos b
               WHERE a.nro_cuenta = b.nro_cuenta
               GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
       WHERE v.mto_aplicado != v.mto_riesgo

       UNION ALL
      -- Cuentas Corrientes.
      SELECT v.cod_moneda, v.cod_modulo, v.nro_cuenta, v.mto_aplicado, v.mto_riesgo
        FROM (SELECT b.cod_moneda,
                     b.cod_modulo,
                     a.nro_cuenta,
                     SUM(a.mto_aplicado) mto_aplicado,
                     MAX(a.mto_riesgo) mto_riesgo
                FROM cc_cta_garantias a, cc_cta_corrientes b
               WHERE a.nro_cuenta = b.nro_cuenta
               GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
       WHERE v.mto_aplicado != v.mto_riesgo

       UNION ALL
      -- Tarjetas.
       SELECT v.cod_moneda, v.cod_modulo, v.nro_cuenta, v.mto_aplicado, v.mto_riesgo
         FROM (SELECT b.cod_moneda,
                     b.cod_modulo,
                     a.nro_cuenta,
                     SUM(a.mto_aplicado) mto_aplicado,
                     MAX(a.mto_riesgo) mto_riesgo
                FROM ta_cta_garantias a, ta_cta_tarjetas b
               WHERE a.nro_cuenta = b.nro_cuenta
               GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
        WHERE v.mto_aplicado != v.mto_riesgo

        UNION ALL
      -- Operaciones Vencidas.
       SELECT v.cod_moneda, v.cod_modulo, v.nro_cuenta, v.mto_aplicado, v.mto_riesgo
         FROM (SELECT b.cod_moneda,
                      b.cod_modulo,
                      a.nro_cuenta,
                      SUM(a.mto_aplicado) mto_aplicado,
                        MAX(a.mto_riesgo) mto_riesgo
                 FROM ov_cta_garantias a, ov_cta_vencidas b
                WHERE a.nro_cuenta = b.nro_cuenta
                GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
        WHERE v.mto_aplicado != v.mto_riesgo

       UNION ALL
      -- Comercio Exterior.
       SELECT v.cod_moneda, v.cod_modulo, v.nro_cuenta, v.mto_aplicado, v.mto_riesgo
         FROM (SELECT b.cod_moneda,
                     b.cod_modulo,
                     a.nro_cuenta,
                     SUM(a.mto_aplicado) mto_aplicado,
                     MAX(a.mto_riesgo) mto_riesgo
                FROM cx_cta_garantias a, cx_cta_importaciones b
               WHERE a.nro_cuenta = b.nro_cuenta
               GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
        WHERE v.mto_aplicado != v.mto_riesgo
    ORDER BY 1,2,3;
    
   -- Cursor que obtiene el rowid de la cuenta para realizar la actualizacion del monto aplicado de la garantia.
    TYPE r_gar_cliente IS RECORD (
      cod_modulo    pv_cta_gar_nocomputables.cod_modulo%TYPE,
      row_id        pv_cta_gar_nocomputables.row_id%TYPE,
      nro_cuenta    pv_cta_gar_nocomputables.nro_cuenta%TYPE,
      nro_garantia  pv_cta_gar_nocomputables.nro_garantia%TYPE,
      cod_garantia  pv_cta_gar_nocomputables.cod_garantia%TYPE
    );
    TYPE t_gar_cliente IS TABLE OF r_gar_cliente INDEX BY PLS_INTEGER;
    v_clientes t_gar_cliente;

   -- Cursor para borra Garantías Abiertas y Propias.
   CURSOR c_del_garantias IS
      SELECT g.nro_garantia, g.cod_garantia,g.cod_persona
        FROM pr_garantias g
       WHERE (g.tipo = 'A' AND nvl(g.ind_uti_tercero, 'N') = 'N')
       and g.cod_garantia not in ( 16 );
    -- Cursor que actualiza el importe de las garantias computables en la tabla ge_cla_operaciones.
   CURSOR c_cla_operaciones IS
      SELECT o.nro_cuenta,
              decode(o.cod_moneda,v_mon_local, nvl(o.mto_apl_computable, 0), pag_gen.fu_con_mon_a_moneda(o.cod_moneda, v_mon_local, nvl(o.mto_apl_computable, 0)))mto_gar_computable,
              decode(o.cod_moneda,v_mon_local, nvl(o.mto_riesgo, 0), pag_gen.fu_con_mon_a_moneda(o.cod_moneda, v_mon_local, nvl(o.mto_riesgo, 0)))as mto_riesgo
        FROM IT.PV_CTA_OPERACIONES o;

        TYPE t_cla_operaciones_record IS RECORD (
       nro_cuenta           pv_cta_operaciones.nro_cuenta%TYPE,
       mto_gar_computable   NUMBER,
       mto_riesgo   NUMBER
    );

   TYPE t_cla_operaciones_table IS TABLE OF t_cla_operaciones_record;
   v_cla_operaciones t_cla_operaciones_table;

   --Cursor que obtiene las cuentas a ser actualizada el monto de riesgo del cliente.
   CURSOR c_act_mto_riesgo IS
      SELECT a.cuenta,a.cod_modulo,a.saldo, a.mto_linea,a.estado
        FROM pv_mto_riesgos a;

   TYPE t_mto_riesgo_rec IS RECORD (
      cuenta     pv_mto_riesgos.cuenta%TYPE,
      cod_modulo pv_mto_riesgos.cod_modulo%TYPE,
      saldo      pv_mto_riesgos.saldo%TYPE,
      mto_linea  pv_mto_riesgos.mto_linea%TYPE,
      estado     pv_mto_riesgos.estado%TYPE
   );

   TYPE t_mto_riesgo_tab IS TABLE OF t_mto_riesgo_rec;
   v_mto_riesgo_tab t_mto_riesgo_tab;
   --coleccionar para update
   TYPE t_riesgo_rec IS RECORD (
        nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
        mto_riesgo  pr_cta_garantias.mto_riesgo%TYPE);
   TYPE t_riesgo_tab IS TABLE OF t_riesgo_rec INDEX BY PLS_INTEGER;
   v_cc_riesgo_tab t_riesgo_tab;
    v_ta_riesgo_tab t_riesgo_tab;
    v_pr_riesgo_tab t_riesgo_tab;
    v_ov_riesgo_tab t_riesgo_tab;
    v_cx_riesgo_tab t_riesgo_tab;

   -- Cursor que obtiene las operaciones que deben ser actualizadas el importe de las garantias CODEUDORIA.
   CURSOR c_act_gar_codeudoria IS
    SELECT ge.cod_modulo,pr.nro_cuenta,pr.cod_garantia, pr.nro_garantia,pr.rowid
            FROM pr_cta_garantias pr, pr_cta_prestamos ge
           WHERE pr.cod_garantia = 1
             AND pr.nro_cuenta = ge.nro_cuenta
             AND EXISTS (SELECT 1
                    FROM pr_cta_garantias pcg
                   WHERE pcg.nro_cuenta = pr.nro_cuenta
                     AND pcg.cod_garantia = 2)
             AND NOT EXISTS (SELECT 1
                    FROM pr_cta_garantias pcg
                   WHERE pcg.nro_cuenta = pr.nro_cuenta
                     AND pcg.cod_garantia NOT IN (1, 2))
       UNION ALL
      -- Cuentas Corrientes.
      SELECT ge.cod_modulo,cc.nro_cuenta,cc.cod_garantia, cc.nro_garantia,cc.rowid
        FROM cc_cta_garantias cc, cc_cta_corrientes ge
       WHERE cc.cod_garantia = 1
         AND cc.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM cc_cta_garantias ccg
               WHERE ccg.nro_cuenta = cc.nro_cuenta
                 AND ccg.cod_garantia = 2)
         AND NOT EXISTS (SELECT 1
                FROM cc_cta_garantias ccg
               WHERE ccg.nro_cuenta = cc.nro_cuenta
                 AND ccg.cod_garantia NOT IN (1, 2))
       UNION ALL
      -- Tarjetas.
      SELECT ge.cod_modulo,ta.nro_cuenta,ta.cod_garantia, ta.nro_garantia,ta.rowid
        FROM ta_cta_garantias ta, ta_cta_tarjetas ge
       WHERE ta.cod_garantia = 1
         AND ta.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM ta_cta_garantias tcg
               WHERE tcg.nro_cuenta = ta.nro_cuenta
                 AND tcg.cod_garantia = 2)
         AND NOT EXISTS (SELECT 1
                FROM ta_cta_garantias tcg
               WHERE tcg.nro_cuenta = ta.nro_cuenta
                 AND tcg.cod_garantia NOT IN (1, 2))
       UNION ALL
      -- Operaciones Vencidas.
      SELECT ge.cod_modulo,ov.nro_cuenta,ov.cod_garantia, ov.nro_garantia,ov.rowid
        FROM ov_cta_garantias ov, ov_cta_vencidas ge
       WHERE ov.cod_garantia = 1
         AND ov.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM ov_cta_garantias ocg
               WHERE ocg.nro_cuenta = ov.nro_cuenta
                 AND ocg.cod_garantia = 2)
         AND NOT EXISTS (SELECT 1
                FROM ov_cta_garantias ocg
               WHERE ocg.nro_cuenta = ov.nro_cuenta
                 AND ocg.cod_garantia NOT IN (1, 2))
       UNION ALL
      -- Comercio Exterior.
      SELECT ge.cod_modulo,cx.nro_cuenta,cx.cod_garantia, cx.nro_garantia,cx.rowid
        FROM cx_cta_garantias cx, cx_cta_importaciones ge
       WHERE cx.cod_garantia = 1
         AND cx.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM cx_cta_garantias xcg
               WHERE xcg.nro_cuenta = cx.nro_cuenta
                 AND xcg.cod_garantia = 2)
         AND NOT EXISTS (SELECT 1
                FROM ta_cta_garantias xcg
               WHERE xcg.nro_cuenta = cx.nro_cuenta
                 AND xcg.cod_garantia NOT IN (1, 2));

   -- Elimina los registros insertados del tipo de garantía SOLA FIRMA de aquellas operaciones que poseen CODEUDORIA.
   CURSOR c_del_gar_solafirma IS
SELECT ge.cod_modulo, pr.nro_cuenta,pr.cod_garantia, pr.nro_garantia,pr.rowid
        FROM pr_cta_garantias pr, pr_cta_prestamos ge
       WHERE pr.cod_garantia = 1
         AND pr.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM pr_cta_garantias pcg
               WHERE pcg.nro_cuenta = pr.nro_cuenta
                 AND pcg.cod_garantia = 2)

     UNION ALL
      SELECT ge.cod_modulo, cc.nro_cuenta,cc.cod_garantia, cc.nro_garantia,cc.rowid
        FROM cc_cta_garantias cc, cc_cta_corrientes ge
       WHERE cc.cod_garantia = 1
         AND cc.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM cc_cta_garantias ccg
               WHERE ccg.nro_cuenta = cc.nro_cuenta
                 AND ccg.cod_garantia = 2)

     UNION ALL
      SELECT ge.cod_modulo, ta.nro_cuenta,ta.cod_garantia, ta.nro_garantia,ta.rowid
        FROM ta_cta_garantias ta, ta_cta_tarjetas ge
       WHERE ta.cod_garantia = 1
         AND ta.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM ta_cta_garantias tcg
               WHERE tcg.nro_cuenta = ta.nro_cuenta
                 AND tcg.cod_garantia = 2)

      UNION ALL
      SELECT ge.cod_modulo, ov.nro_cuenta,ov.cod_garantia, ov.nro_garantia,ov.rowid
        FROM ov_cta_garantias ov, ov_cta_vencidas ge
       WHERE ov.cod_garantia = 1
         AND ov.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM ov_cta_garantias ocg
               WHERE ocg.nro_cuenta = ov.nro_cuenta
                 AND ocg.cod_garantia = 2)

      UNION ALL
      SELECT ge.cod_modulo, cx.nro_cuenta,cx.cod_garantia, cx.nro_garantia,cx.rowid
        FROM cx_cta_garantias cx, cx_cta_importaciones ge
       WHERE cx.cod_garantia = 1
         AND cx.nro_cuenta = ge.nro_cuenta
         AND EXISTS (SELECT 1
                FROM cx_cta_garantias xcg
               WHERE xcg.nro_cuenta = cx.nro_cuenta
                 AND xcg.cod_garantia = 2);
                 
   --Listado de Operaciones vinculadas a garantías cerradas.
   CURSOR c_cta_gar_cerradas(p_nro_garantia IN pr_garantias.nro_garantia%TYPE, p_cod_garantia IN pr_garantias.cod_garantia%TYPE, p_cod_moneda IN pr_garantias.cod_moneda%TYPE, p_valor IN pr_garantias.valor%TYPE) IS
      SELECT g.cod_modulo,
             g.cod_moneda,
             g.nro_cuenta,
             g.mto_riesgo,
             g.mto_aplicado,
             g.cod_garantia,
             g.nro_garantia,
             g.fila
        FROM pv_mto_apl_gar_cerradas g
       WHERE g.nro_garantia = p_nro_garantia
         AND g.cod_garantia = p_cod_garantia
         AND (g.mto_riesgo <= pag_gen.fu_con_mon_a_moneda(p_cod_moneda, g.cod_moneda, p_valor) OR g.mto_aplicado = 0)
       ORDER BY g.cod_moneda;
   --Procedimientos.
   -- Procedimiento Inserta Cta. Garantías.
   PROCEDURE lp_ins_cta_garantia
   (
      p_cod_modulo         NUMBER,
      p_nro_cuenta         VARCHAR2,
      p_nro_garantia       NUMBER,
      p_cod_garantia       NUMBER,
      p_mto_aplicado       NUMBER,
      p_mto_apl_computable NUMBER,
      p_cod_persona        VARCHAR2,
      p_riesgo             NUMBER
   ) IS
   BEGIN
      IF p_cod_modulo = 4 THEN
         -- Cuentas Corrientes.
         BEGIN
           INSERT INTO cc_cta_garantias
              (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_apl_computable, cod_persona,
               mto_riesgo)
           VALUES
              (p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado, p_mto_apl_computable,
               p_cod_persona, p_riesgo);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               update cc_cta_garantias
                  set mto_aplicado       = mto_aplicado + p_mto_aplicado,
                      mto_apl_computable = mto_apl_computable + p_mto_apl_computable,
                      cod_persona  = p_cod_persona,
                      mto_riesgo   = p_riesgo,
                      cod_garantia = p_cod_garantia
                where nro_cuenta   = p_nro_cuenta
                  and nro_garantia = p_nro_garantia
                  and cod_garantia = p_cod_garantia;
         END;
      ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas.
         BEGIN
            INSERT INTO ta_cta_garantias
              (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_apl_computable, cod_persona,
               mto_riesgo)
            VALUES
              (p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado, p_mto_apl_computable,
               p_cod_persona, p_riesgo);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               update ta_cta_garantias
                  set mto_aplicado       = mto_aplicado + p_mto_aplicado,
                      mto_apl_computable = mto_apl_computable + p_mto_apl_computable,
                      cod_persona  = p_cod_persona,
                      mto_riesgo   = p_riesgo,
                      cod_garantia = p_cod_garantia
                where nro_cuenta   = p_nro_cuenta
                  and nro_garantia = p_nro_garantia
                  and cod_garantia = p_cod_garantia;
         END;
      ELSIF p_cod_modulo = 6 THEN
         -- Prestamos.
         BEGIN
            INSERT INTO pr_cta_garantias
               (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_apl_computable, cod_persona,
                mto_riesgo)
            VALUES
               (p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado, p_mto_apl_computable,
                p_cod_persona, p_riesgo);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               update pr_cta_garantias
                  set mto_aplicado       = mto_aplicado + p_mto_aplicado,
                      mto_apl_computable = mto_apl_computable + p_mto_apl_computable,
                      cod_persona  = p_cod_persona,
                      mto_riesgo   = p_riesgo,
                      cod_garantia = p_cod_garantia
                where nro_cuenta   = p_nro_cuenta
                  and nro_garantia = p_nro_garantia
                  and cod_garantia = p_cod_garantia;
         END;
      ELSIF p_cod_modulo = 15 THEN
         -- Operaciones Vencidas.
         BEGIN
           INSERT INTO ov_cta_garantias
              (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_apl_computable, cod_persona,
               mto_riesgo)
           VALUES
              (p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado, p_mto_apl_computable,
               p_cod_persona, p_riesgo);
          EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               update ov_cta_garantias
                  set mto_aplicado       = mto_aplicado + p_mto_aplicado,
                      mto_apl_computable = mto_apl_computable + p_mto_apl_computable,
                      cod_persona  = p_cod_persona,
                      mto_riesgo   = p_riesgo,
                      cod_garantia = p_cod_garantia
                where nro_cuenta   = p_nro_cuenta
                  and nro_garantia = p_nro_garantia
                  and cod_garantia = p_cod_garantia;
         END;
      ELSIF p_cod_modulo = 8 THEN
        -- Comercio Exterior
        BEGIN
           INSERT INTO cx_cta_garantias
              (nro_cuenta, cod_garantia, nro_garantia, mto_aplicado, mto_apl_computable, cod_persona,
               mto_riesgo)
           VALUES
              (p_nro_cuenta, p_cod_garantia, p_nro_garantia, p_mto_aplicado, p_mto_apl_computable,
               p_cod_persona, p_riesgo);
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               update cx_cta_garantias
                  set mto_aplicado       = mto_aplicado + p_mto_aplicado,
                      mto_apl_computable = mto_apl_computable + p_mto_apl_computable,
                      cod_persona  = p_cod_persona,
                      mto_riesgo   = p_riesgo,
                      cod_garantia = p_cod_garantia
                where nro_cuenta   = p_nro_cuenta
                  and nro_garantia = p_nro_garantia
                  and cod_garantia = p_cod_garantia;

         END;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
  -- Procedimiento Inserta Cta. Garantías.
    PROCEDURE lp_ins_col_cta_garantia (
       p_cod_modulo         NUMBER,
       p_nro_cuenta         VARCHAR2,
       p_nro_garantia       NUMBER,
       p_cod_garantia       VARCHAR2,
       p_mto_aplicado       NUMBER,
       p_mto_apl_computable NUMBER,
       p_cod_persona        VARCHAR2,
       p_riesgo             NUMBER) IS
       v_obj typ_cta_garantia;
    BEGIN
       -- Crear objeto con los datos de entrada
       v_obj := typ_cta_garantia(
          p_nro_cuenta,
          p_nro_garantia,
          p_cod_garantia,
          p_mto_aplicado,
          p_mto_apl_computable,
          p_cod_persona,
          p_riesgo
       );
       CASE p_cod_modulo
          WHEN 4 THEN v_cc_ctas.EXTEND; v_cc_ctas(v_cc_ctas.COUNT) := v_obj;
          WHEN 5 THEN v_ta_ctas.EXTEND; v_ta_ctas(v_ta_ctas.COUNT) := v_obj;
          WHEN 6 THEN v_pr_ctas.EXTEND; v_pr_ctas(v_pr_ctas.COUNT) := v_obj;
          WHEN 15 THEN v_ov_ctas.EXTEND; v_ov_ctas(v_ov_ctas.COUNT) := v_obj;
          WHEN 8 THEN v_cx_ctas.EXTEND; v_cx_ctas(v_cx_ctas.COUNT) := v_obj;
       END CASE;
    END;
     --procedimiento que procesa los registros colectados
     PROCEDURE lp_ins_col_garantia is
    BEGIN      
    ---------------------------CUENTA CORRIENTE-------------------------------------------
             IF v_cc_ctas.COUNT > 0 THEN 
                    MERGE INTO cc_cta_garantias dst
                    USING (SELECT * FROM TABLE(v_cc_ctas)) src 
                    ON (dst.nro_cuenta   = src.nro_cuenta AND
                        dst.nro_garantia = src.nro_garantia AND
                        dst.cod_garantia = src.cod_garantia)
                     WHEN MATCHED THEN
                        UPDATE SET dst.mto_aplicado       = dst.mto_aplicado + src.mto_aplicado,
                                   dst.mto_apl_computable = dst.mto_apl_computable + src.mto_apl_computable,
                                   dst.cod_persona        = src.cod_persona,
                                   dst.mto_riesgo         = src.mto_riesgo
                     WHEN NOT MATCHED THEN
                        INSERT (nro_cuenta, nro_garantia, cod_garantia,
                                mto_aplicado, mto_apl_computable,
                                cod_persona, mto_riesgo)
                        VALUES (src.nro_cuenta, src.nro_garantia, src.cod_garantia,
                                src.mto_aplicado, src.mto_apl_computable,
                                src.cod_persona, src.mto_riesgo);
                 END IF;
            ------------------------------------------------------------------------------
            ---------------------------TARJETAS------------------------------------------- 
              IF v_ta_ctas.COUNT > 0 THEN 
                   MERGE INTO ta_cta_garantias dst
                    USING (SELECT * FROM TABLE(v_ta_ctas)) src 
                    ON (dst.nro_cuenta   = src.nro_cuenta AND
                        dst.nro_garantia = src.nro_garantia AND
                        dst.cod_garantia = src.cod_garantia)
                     WHEN MATCHED THEN
                        UPDATE SET dst.mto_aplicado       = dst.mto_aplicado + src.mto_aplicado,
                                   dst.mto_apl_computable = dst.mto_apl_computable + src.mto_apl_computable,
                                   dst.cod_persona        = src.cod_persona,
                                   dst.mto_riesgo         = src.mto_riesgo
                     WHEN NOT MATCHED THEN
                        INSERT (nro_cuenta, nro_garantia, cod_garantia,
                                mto_aplicado, mto_apl_computable,
                                cod_persona, mto_riesgo)
                        VALUES (src.nro_cuenta, src.nro_garantia, src.cod_garantia,
                                src.mto_aplicado, src.mto_apl_computable,
                                src.cod_persona, src.mto_riesgo);
                 END IF;
            -------------------------------------------------------------------------------
            ---------------------------PRESTAMOS-------------------------------------------
              IF v_pr_ctas.COUNT > 0 THEN 
                   MERGE INTO pr_cta_garantias dst
                    USING (SELECT * FROM TABLE(v_pr_ctas)) src 
                    ON (dst.nro_cuenta   = src.nro_cuenta AND
                        dst.nro_garantia = src.nro_garantia AND
                        dst.cod_garantia = src.cod_garantia)
                     WHEN MATCHED THEN
                        UPDATE SET dst.mto_aplicado       = dst.mto_aplicado + src.mto_aplicado,
                                   dst.mto_apl_computable = dst.mto_apl_computable + src.mto_apl_computable,
                                   dst.cod_persona        = src.cod_persona,
                                   dst.mto_riesgo         = src.mto_riesgo
                     WHEN NOT MATCHED THEN
                        INSERT (nro_cuenta, nro_garantia, cod_garantia,
                                mto_aplicado, mto_apl_computable,
                                cod_persona, mto_riesgo)
                        VALUES (src.nro_cuenta, src.nro_garantia, src.cod_garantia,
                                src.mto_aplicado, src.mto_apl_computable,
                                src.cod_persona, src.mto_riesgo);
                 END IF;
            -------------------------------------------------------------------------------
            -------------------------OPERACIONES VENCIDAS-----------------------------------
              IF v_ov_ctas.COUNT > 0 THEN 
                   MERGE INTO ov_cta_garantias dst
                    USING (SELECT * FROM TABLE(v_ov_ctas)) src 
                    ON (dst.nro_cuenta   = src.nro_cuenta AND
                        dst.nro_garantia = src.nro_garantia AND
                        dst.cod_garantia = src.cod_garantia)
                     WHEN MATCHED THEN
                        UPDATE SET dst.mto_aplicado       = dst.mto_aplicado + src.mto_aplicado,
                                   dst.mto_apl_computable = dst.mto_apl_computable + src.mto_apl_computable,
                                   dst.cod_persona        = src.cod_persona,
                                   dst.mto_riesgo         = src.mto_riesgo
                     WHEN NOT MATCHED THEN
                        INSERT (nro_cuenta, nro_garantia, cod_garantia,
                                mto_aplicado, mto_apl_computable,
                                cod_persona, mto_riesgo)
                        VALUES (src.nro_cuenta, src.nro_garantia, src.cod_garantia,
                                src.mto_aplicado, src.mto_apl_computable,
                                src.cod_persona, src.mto_riesgo);
                 END IF;
            -------------------------------------------------------------------------------
            ---------------------------COMERCIO EXTERIOR-----------------------------------
              IF v_cx_ctas.COUNT > 0 THEN   
                   MERGE INTO cx_cta_garantias dst
                    USING (SELECT * FROM TABLE(v_cx_ctas)) src 
                    ON (dst.nro_cuenta   = src.nro_cuenta AND
                        dst.nro_garantia = src.nro_garantia AND
                        dst.cod_garantia = src.cod_garantia)
                     WHEN MATCHED THEN
                        UPDATE SET dst.mto_aplicado       = dst.mto_aplicado + src.mto_aplicado,
                                   dst.mto_apl_computable = dst.mto_apl_computable + src.mto_apl_computable,
                                   dst.cod_persona        = src.cod_persona,
                                   dst.mto_riesgo         = src.mto_riesgo
                     WHEN NOT MATCHED THEN
                        INSERT (nro_cuenta, nro_garantia, cod_garantia,
                                mto_aplicado, mto_apl_computable,
                                cod_persona, mto_riesgo)
                        VALUES (src.nro_cuenta, src.nro_garantia, src.cod_garantia,
                                src.mto_aplicado, src.mto_apl_computable,
                                src.cod_persona, src.mto_riesgo);
                END IF;
        EXCEPTION
          WHEN OTHERS THEN
             NULL;      
       end;
       --limpiar colecciones
    PROCEDURE lp_del_colecciones IS 
    BEGIN
        v_cc_ctas := typ_cta_garantia_tab();
        v_ta_ctas := typ_cta_garantia_tab();
        v_pr_ctas := typ_cta_garantia_tab();
        v_ov_ctas := typ_cta_garantia_tab();
        v_cx_ctas := typ_cta_garantia_tab();
    END;

   -- Procedimiento Actualiza el monto aplicado de las cuentas de Garantias Abiertas.
    PROCEDURE lp_act_cta_garantia
   (
      p_cod_modulo   NUMBER,
      p_nro_garantia NUMBER,
      p_cod_garantia NUMBER,
      p_mto_aplicado NUMBER,
      p_rowid        ROWID,
      p_nro_cuenta   ge_cuentas.nro_cuenta%type,
      p_cod_persona  ba_personas.cod_persona%type,
      p_mto_riesgo   pr_cta_garantias.mto_riesgo%TYPE
   ) IS
      v_ctl_local   NUMBER := 0;
      cc_gar_rows cc_cta_garantias%ROWTYPE;
      ta_gar_rows ta_cta_garantias%ROWTYPE;
      pr_gar_rows pr_cta_garantias%ROWTYPE;
      ov_gar_rows ov_cta_garantias%ROWTYPE;
      cx_gar_rows cx_cta_garantias%ROWTYPE;
      v_tot_mto_apl_computable number(18,2);

   BEGIN
      IF p_cod_modulo = 4 THEN
         -- Cuentas Corrientes.
      BEGIN
         SELECT 1
           INTO v_ctl_local
           FROM cc_cta_garantias a
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia is null
            and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
      END;

      IF v_ctl_local = 1 then
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cc_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia = p_nro_garantia
               and a.cod_garantia = p_cod_garantia;
         EXCEPTION
              when no_data_found then
                     v_ctl_local := 0;
         END;

      IF v_ctl_local = 1 then
        UPDATE cc_cta_garantias a
          SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
         WHERE a.nro_cuenta = p_nro_cuenta
          and a.nro_garantia = p_nro_garantia
          and a.cod_garantia = p_cod_garantia;
      ELSE
        UPDATE cc_cta_garantias a
          SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
             a.nro_garantia = p_nro_garantia,
             a.cod_garantia = p_cod_garantia
         WHERE a.nro_cuenta = p_nro_cuenta
          and a.nro_garantia is null
          and a.cod_garantia = 1;
       END IF;
       ELSE
          BEGIN
             SELECT 1
               INTO v_ctl_local
               FROM cc_cta_garantias a
              WHERE a.nro_cuenta = p_nro_cuenta
                and a.nro_garantia = p_nro_garantia
                and a.cod_garantia = p_cod_garantia;
           EXCEPTION
               WHEN no_data_found THEN
                   v_ctl_local := 0;
           END;
           IF v_ctl_local = 1 THEN
              UPDATE cc_cta_garantias a
                 SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
               WHERE a.nro_cuenta = p_nro_cuenta
                 and a.nro_garantia = p_nro_garantia
                 and a.cod_garantia = p_cod_garantia;
           ELSE
              BEGIN
                 SELECT a.cod_persona, sum(a.mto_apl_computable), sum(a.mto_riesgo)
                   INTO cc_gar_rows.cod_persona, cc_gar_rows.mto_apl_computable, cc_gar_rows.mto_riesgo
                   FROM cc_cta_garantias a
                  WHERE a.nro_cuenta = p_nro_cuenta
                    AND a.nro_garantia = p_nro_garantia
                   GROUP BY a.cod_persona;
                  EXCEPTION
                    when no_data_found then
                     cc_gar_rows.cod_persona := p_cod_persona;
                     cc_gar_rows.mto_apl_computable := 0;
                     cc_gar_rows.mto_riesgo := 0;
               END;

                cc_gar_rows.nro_garantia := p_nro_garantia;
                cc_gar_rows.cod_garantia := p_cod_garantia;
                cc_gar_rows.mto_aplicado := p_mto_aplicado;
                cc_gar_rows.nro_cuenta   := p_nro_cuenta;
                cc_gar_rows.mto_riesgo   := p_mto_riesgo;

                lp_ins_cta_garantia(4, cc_gar_rows.nro_cuenta, cc_gar_rows.nro_garantia,
                                    cc_gar_rows.cod_garantia,
                                    cc_gar_rows.mto_aplicado,
                                    cc_gar_rows.mto_apl_computable,
                                    cc_gar_rows.cod_persona,
                                    cc_gar_rows.mto_riesgo);
           END IF;
      END IF;

    ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas.
        BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ta_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
         END;

          IF v_ctl_local = 1 THEN
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM ta_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
               END;

               IF v_ctl_local = 1 THEN
                  UPDATE ta_cta_garantias a
                     SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     and a.nro_garantia = p_nro_garantia
                     and a.cod_garantia = p_cod_garantia;
                ELSE
                  UPDATE ta_cta_garantias a
                     SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                         a.nro_garantia = p_nro_garantia,
                         a.cod_garantia = p_cod_garantia
                   WHERE a.nro_cuenta = p_nro_cuenta
                     and a.nro_garantia is null
                     and a.cod_garantia = 1;
               END IF;
          ELSE
             BEGIN
              SELECT 1
                INTO v_ctl_local
                FROM ta_cta_garantias a
               WHERE a.nro_cuenta = p_nro_cuenta
                 and a.nro_garantia = p_nro_garantia
                 and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             END;
             IF v_ctl_local = 1 THEN
                UPDATE ta_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
             ELSE
                 BEGIN
                    SELECT a.cod_persona, sum(a.mto_apl_computable), sum(a.mto_riesgo)
                    INTO ta_gar_rows.cod_persona, ta_gar_rows.mto_apl_computable, ta_gar_rows.mto_riesgo
                    FROM ta_cta_garantias a
                   WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_garantia = p_nro_garantia
                   GROUP BY a.cod_persona;
                 EXCEPTION
                    WHEN no_data_found THEN
                       ta_gar_rows.cod_persona := p_cod_persona;
                       ta_gar_rows.mto_apl_computable := 0;
                       ta_gar_rows.mto_riesgo := 0;
                 END;

                ta_gar_rows.nro_garantia := p_nro_garantia;
                ta_gar_rows.cod_garantia := p_cod_garantia;
                ta_gar_rows.mto_aplicado := p_mto_aplicado;
                ta_gar_rows.nro_cuenta   := p_nro_cuenta;
                ta_gar_rows.mto_riesgo   := p_mto_riesgo;

                lp_ins_cta_garantia(5, ta_gar_rows.nro_cuenta, ta_gar_rows.nro_garantia,
                                    ta_gar_rows.cod_garantia,
                                    ta_gar_rows.mto_aplicado,
                                    ta_gar_rows.mto_apl_computable,
                                    ta_gar_rows.cod_persona,
                                    ta_gar_rows.mto_riesgo);
             END IF;
          END IF;


       ELSIF p_cod_modulo = 6 THEN
          BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM pr_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
          END;
          IF v_ctl_local = 1 THEN
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM pr_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
              END;

              IF v_ctl_local = 1 THEN
                 UPDATE pr_cta_garantias a
                    SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                  WHERE a.nro_cuenta = p_nro_cuenta
                    and a.nro_garantia = p_nro_garantia
                    and a.cod_garantia = p_cod_garantia;
               ELSE
                 UPDATE pr_cta_garantias a
                    SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                        a.nro_garantia = p_nro_garantia,
                        a.cod_garantia = p_cod_garantia
                  WHERE a.nro_cuenta = p_nro_cuenta
                    AND a.nro_garantia is null
                    AND a.cod_garantia = 1;
               END IF;
          ELSE
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM pr_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   AND a.nro_garantia = p_nro_garantia
                   AND a.cod_garantia = p_cod_garantia;
             EXCEPTION
                  WHEN no_data_found THEN
                       v_ctl_local := 0;
             END;
             IF v_ctl_local = 1 THEN
                UPDATE pr_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
              ELSE
                 BEGIN
                    SELECT a.cod_persona, sum(a.mto_apl_computable), sum(a.mto_riesgo)
                      INTO pr_gar_rows.cod_persona, pr_gar_rows.mto_apl_computable, pr_gar_rows.mto_riesgo
                      FROM pr_cta_garantias a
                     WHERE a.nro_cuenta = p_nro_cuenta
                       and a.nro_garantia = p_nro_garantia
                     group by a.cod_persona;
                 EXCEPTION
                    WHEN no_data_found then
                       pr_gar_rows.cod_persona := p_cod_persona;
                       pr_gar_rows.mto_apl_computable := 0;
                       pr_gar_rows.mto_riesgo := 0;
                 END;

            pr_gar_rows.nro_garantia := p_nro_garantia;
            pr_gar_rows.cod_garantia := p_cod_garantia;
            pr_gar_rows.mto_aplicado := p_mto_aplicado;
            pr_gar_rows.nro_cuenta   := p_nro_cuenta;
            pr_gar_rows.mto_riesgo   := p_mto_riesgo;

                 lp_ins_cta_garantia(6, pr_gar_rows.nro_cuenta, pr_gar_rows.nro_garantia,
                                    pr_gar_rows.cod_garantia,
                                    pr_gar_rows.mto_aplicado,
                                    pr_gar_rows.mto_apl_computable,
                                    pr_gar_rows.cod_persona,
                                    pr_gar_rows.mto_riesgo);
             END IF;
          END IF;

      ELSIF p_cod_modulo = 15 THEN
         -- Operaciones Vencidas.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ov_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
          END;
          IF v_ctl_local = 1 then
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM ov_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   AND a.nro_garantia = p_nro_garantia
                   AND a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             END;

                IF v_ctl_local = 1 THEN
                   UPDATE ov_cta_garantias a
                      SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                    WHERE a.nro_cuenta = p_nro_cuenta
                      and a.nro_garantia = p_nro_garantia
                      and a.cod_garantia = p_cod_garantia;
                ELSE
                   UPDATE ov_cta_garantias a
                      SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                          a.nro_garantia = p_nro_garantia,
                          a.cod_garantia = p_cod_garantia
                    WHERE a.nro_cuenta = p_nro_cuenta
                      and a.nro_garantia is null
                      and a.cod_garantia = 1;
                END IF;
          ELSE
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM ov_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                  WHEN no_data_found THEN
                   v_ctl_local := 0;
             END;
             IF v_ctl_local = 1 THEN
                UPDATE ov_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
             ELSE
                 BEGIN
                    SELECT a.cod_persona, sum(a.mto_apl_computable), sum(a.mto_riesgo)
                      INTO ov_gar_rows.cod_persona, ov_gar_rows.mto_apl_computable, ov_gar_rows.mto_riesgo
                      FROM ov_cta_garantias a
                     WHERE a.nro_cuenta = p_nro_cuenta
                       AND a.nro_garantia = p_nro_garantia
                    GROUP BY a.cod_persona;
                 EXCEPTION
                    WHEN no_data_found then
                       ov_gar_rows.cod_persona := p_cod_persona;
                       ov_gar_rows.mto_apl_computable := 0;
                       ov_gar_rows.mto_riesgo := 0;
                 END;

                ov_gar_rows.nro_garantia := p_nro_garantia;
                ov_gar_rows.cod_garantia := p_cod_garantia;
                ov_gar_rows.mto_aplicado := p_mto_aplicado;
                ov_gar_rows.nro_cuenta   := p_nro_cuenta;
                ov_gar_rows.mto_riesgo   := p_mto_riesgo;

                lp_ins_cta_garantia(15, ov_gar_rows.nro_cuenta, ov_gar_rows.nro_garantia,
                                    ov_gar_rows.cod_garantia, ov_gar_rows.mto_aplicado,
                                    ov_gar_rows.mto_apl_computable, ov_gar_rows.cod_persona,
                                    ov_gar_rows.mto_riesgo);
             END IF;
          END IF;

      ELSIF p_cod_modulo = 8 THEN
         -- Comercio Exterior
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cx_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
          EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
          END;

          IF v_ctl_local = 1 then
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM cx_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found then
                     v_ctl_local := 0;
             END;
             IF v_ctl_local = 1 then
                UPDATE cx_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
              ELSE
                UPDATE cx_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                       a.nro_garantia = p_nro_garantia,
                       a.cod_garantia = p_cod_garantia
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia is null
                   and a.cod_garantia = 1;
             END IF;
          ELSE
             BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM cx_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             END;
             IF v_ctl_local = 1 THEN
                UPDATE cx_cta_garantias a
                   SET a.mto_aplicado = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
              ELSE
                 BEGIN
                    SELECT a.cod_persona, sum(a.mto_apl_computable), sum(a.mto_riesgo)
                      INTO cx_gar_rows.cod_persona, cx_gar_rows.mto_apl_computable, cx_gar_rows.mto_riesgo
                      FROM cx_cta_garantias a
                     WHERE a.nro_cuenta = p_nro_cuenta
                       and a.nro_garantia = p_nro_garantia
                  group by a.cod_persona;
                 EXCEPTION
                   when no_data_found then
                     cx_gar_rows.cod_persona := p_cod_persona;
                     cx_gar_rows.mto_apl_computable := 0;
                     cx_gar_rows.mto_riesgo := 0;
                 END;

                cx_gar_rows.nro_garantia := p_nro_garantia;
                cx_gar_rows.cod_garantia := p_cod_garantia;
                cx_gar_rows.mto_aplicado := p_mto_aplicado;
                cx_gar_rows.nro_cuenta   := p_nro_cuenta;
                cx_gar_rows.mto_riesgo   := p_mto_riesgo;

                lp_ins_cta_garantia(8, cx_gar_rows.nro_cuenta, cx_gar_rows.nro_garantia,
                                    cx_gar_rows.cod_garantia, cx_gar_rows.mto_aplicado,
                                    cx_gar_rows.mto_apl_computable, cx_gar_rows.cod_persona,
                                    cx_gar_rows.mto_riesgo);
             END IF;
          END IF;
     END IF;
   END;

   -- Procedimiento Actualiza el monto aplicado computable de las operaciones de las Garantías Abiertas.
     PROCEDURE lp_act_apl_gar_abiertas
   (
      p_cod_modulo   NUMBER,
      p_nro_garantia NUMBER,
      p_cod_garantia NUMBER,
      p_mto_aplicado NUMBER,
      p_rowid        ROWID,
      p_nro_cuenta   ge_cuentas.nro_cuenta%type,
      p_cod_persona  ba_personas.cod_persona%type,
      p_computable   pr_gar_tipos.computable%type,
      p_mto_riesgo   pr_cta_garantias.mto_riesgo%TYPE --nuevo
   ) IS
      v_ctl_local   NUMBER := 0;
      v_es_nocomputable NUMBER := 0;
      cc_gar_rows cc_cta_garantias%ROWTYPE;
      ta_gar_rows ta_cta_garantias%ROWTYPE;
      pr_gar_rows pr_cta_garantias%ROWTYPE;
      ov_gar_rows ov_cta_garantias%ROWTYPE;
      cx_gar_rows cx_cta_garantias%ROWTYPE;

   BEGIN
     -- 1. Validar la modalidad una sola vez al inicio del procedimiento
   BEGIN
      SELECT 1
        INTO v_es_nocomputable
        FROM ge_cuentas gc
       WHERE gc.nro_cuenta = p_nro_cuenta
         AND gc.cod_modalidad IN (154, 970, 971);
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         v_es_nocomputable := 0;
   END;
      IF p_cod_modulo = 4 THEN
         -- Cuentas Corrientes.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cc_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
           END;

         if v_ctl_local = 1 then
            BEGIN
               SELECT 1
                 INTO v_ctl_local
                 FROM cc_cta_garantias a
                WHERE a.nro_cuenta = p_nro_cuenta
                  and a.nro_garantia = p_nro_garantia
                  and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
             END;
             IF p_computable = 'S' THEN
                IF v_ctl_local = 1 then
                   UPDATE cc_cta_garantias a
                      SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0)
                    WHERE a.nro_cuenta = p_nro_cuenta
                      and a.nro_garantia = p_nro_garantia
                      and a.cod_garantia = p_cod_garantia;
                ELSE
                   UPDATE cc_cta_garantias a
                      SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                          a.nro_garantia = p_nro_garantia,
                          a.cod_garantia = p_cod_garantia
                    WHERE a.nro_cuenta = p_nro_cuenta
                      and a.nro_garantia is null
                      and a.cod_garantia = 1;
                END IF;
              END IF;
           ELSE
              BEGIN
                 SELECT 1
                   INTO v_ctl_local
                   FROM cc_cta_garantias a
                  WHERE a.nro_cuenta = p_nro_cuenta
                    and a.nro_garantia = p_nro_garantia
                    and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_ctl_local := 0;
               END;
               IF p_computable = 'S' THEN
                  IF v_ctl_local = 1 THEN
                     UPDATE cc_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                            a.nro_garantia = p_nro_garantia,
                            a.cod_garantia = p_cod_garantia
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia = p_nro_garantia
                        and a.cod_garantia = p_cod_garantia;
                  ELSE

                    cc_gar_rows.nro_garantia       := p_nro_garantia;
                    cc_gar_rows.cod_garantia       := p_cod_garantia;
                    cc_gar_rows.mto_aplicado       := 0;
                    cc_gar_rows.mto_apl_computable := p_mto_aplicado;
                    cc_gar_rows.nro_cuenta         := p_nro_cuenta;
                    cc_gar_rows.cod_persona        := p_cod_persona;
                    cc_gar_rows.mto_riesgo         := p_mto_riesgo;

                    lp_ins_cta_garantia(4, cc_gar_rows.nro_cuenta, cc_gar_rows.nro_garantia,
                                        cc_gar_rows.cod_garantia,
                                        cc_gar_rows.mto_aplicado,
                                        cc_gar_rows.mto_apl_computable,
                                        cc_gar_rows.cod_persona,
                                        cc_gar_rows.mto_riesgo);

                   END IF;
                END IF;
          END IF;

      ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas.
          BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ta_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
           END;
           IF v_ctl_local = 1 then
              BEGIN
                 SELECT 1
                   INTO v_ctl_local
                   FROM ta_cta_garantias a
                  WHERE a.nro_cuenta = p_nro_cuenta
                    and a.nro_garantia = p_nro_garantia
                    and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
               END;
               IF p_computable = 'S' THEN
                  IF v_ctl_local = 1 THEN
                   UPDATE ta_cta_garantias a
                     SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     and a.nro_garantia = p_nro_garantia
                     and a.cod_garantia = p_cod_garantia
                      ;
                  else
                     UPDATE ta_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                            a.nro_garantia = p_nro_garantia,
                            a.cod_garantia = p_cod_garantia
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia is null
                        and a.cod_garantia = 1;
                  END IF;
                END IF;
           ELSE
              BEGIN
                 SELECT 1
                   INTO v_ctl_local
                   FROM ta_cta_garantias a
                  WHERE a.nro_cuenta = p_nro_cuenta
                    and a.nro_garantia = p_nro_garantia
                    and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_ctl_local := 0;
               END;
              IF p_computable = 'S' THEN
                 IF v_ctl_local = 1 then
                    UPDATE ta_cta_garantias a
                       SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                           a.nro_garantia = p_nro_garantia,
                           a.cod_garantia = p_cod_garantia
                     WHERE a.nro_cuenta = p_nro_cuenta
                       and a.nro_garantia = p_nro_garantia
                       and a.cod_garantia = p_cod_garantia;
                 ELSE

                    ta_gar_rows.nro_garantia       := p_nro_garantia;
                    ta_gar_rows.cod_garantia       := p_cod_garantia;
                    ta_gar_rows.mto_aplicado       := 0;
                    ta_gar_rows.mto_apl_computable := p_mto_aplicado;
                    ta_gar_rows.nro_cuenta         := p_nro_cuenta;
                    ta_gar_rows.cod_persona        := p_cod_persona;
                    ta_gar_rows.mto_riesgo         := p_mto_riesgo;

                    lp_ins_cta_garantia(5, ta_gar_rows.nro_cuenta, ta_gar_rows.nro_garantia,
                                        ta_gar_rows.cod_garantia,
                                        ta_gar_rows.mto_aplicado,
                                        ta_gar_rows.mto_apl_computable,
                                        ta_gar_rows.cod_persona,
                                        ta_gar_rows.mto_riesgo);

                 END IF;
               END IF;
           END IF;

      ELSIF p_cod_modulo = 6 THEN
        --Prestamos
          BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM pr_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
           end;

           if v_ctl_local = 1 then
              BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM pr_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
               end;
               IF p_computable = 'S' AND v_es_nocomputable = 0 THEN
                  IF v_ctl_local = 1 THEN
                     UPDATE pr_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0)
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia = p_nro_garantia
                        and a.cod_garantia = p_cod_garantia
                        ;
                   ELSE
                     UPDATE pr_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                            a.nro_garantia = p_nro_garantia,
                            a.cod_garantia = p_cod_garantia
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia is null
                        and a.cod_garantia = 1;
                  END IF;
                END IF;
           ELSE
             begin
              SELECT 1
                INTO v_ctl_local
                FROM pr_cta_garantias a
               WHERE a.nro_cuenta = p_nro_cuenta
                 and a.nro_garantia = p_nro_garantia
                 and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             end;
             IF p_computable = 'S' AND v_es_nocomputable = 0 THEN
                IF v_ctl_local = 1 THEN
                   UPDATE pr_cta_garantias a
                      SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                          a.nro_garantia = p_nro_garantia,
                          a.cod_garantia = p_cod_garantia
                    WHERE a.nro_cuenta = p_nro_cuenta 
                      and a.nro_garantia = p_nro_garantia
                      and a.cod_garantia = p_cod_garantia;
                 ELSE

                    pr_gar_rows.nro_garantia       := p_nro_garantia;
                    pr_gar_rows.cod_garantia       := p_cod_garantia;
                    pr_gar_rows.mto_aplicado       := 0;
                    pr_gar_rows.mto_apl_computable := p_mto_aplicado;
                    pr_gar_rows.nro_cuenta         := p_nro_cuenta;
                    pr_gar_rows.cod_persona        := p_cod_persona;
                    pr_gar_rows.mto_riesgo         := p_mto_riesgo;

                    lp_ins_cta_garantia(6, pr_gar_rows.nro_cuenta, pr_gar_rows.nro_garantia,
                                    pr_gar_rows.cod_garantia,
                                    pr_gar_rows.mto_aplicado,
                                    pr_gar_rows.mto_apl_computable,
                                    pr_gar_rows.cod_persona,
                                    pr_gar_rows.mto_riesgo);

                 END IF;
              END IF;
           END IF;
       ELSIF p_cod_modulo = 15 THEN
         -- Operaciones Vencidas.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ov_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
            EXCEPTION
              WHEN no_data_found THEN
                   v_ctl_local := 0;
            END;

            IF v_ctl_local = 1 THEN
               BEGIN
                  SELECT 1
                    INTO v_ctl_local
                    FROM ov_cta_garantias a
                   WHERE a.nro_cuenta = p_nro_cuenta
                     and a.nro_garantia = p_nro_garantia
                     and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
               END;
               IF p_computable = 'S' AND v_es_nocomputable = 0 THEN
                  IF v_ctl_local = 1 THEN
                     UPDATE ov_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0)
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia = p_nro_garantia
                        and a.cod_garantia = p_cod_garantia;
                   ELSE
                      UPDATE ov_cta_garantias a
                         SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                             a.nro_garantia = p_nro_garantia,
                             a.cod_garantia = p_cod_garantia
                       WHERE a.nro_cuenta = p_nro_cuenta
                         and a.nro_garantia is null
                         and a.cod_garantia = 1;
                    END IF;
                END IF;
           ELSE
             begin
              SELECT 1
                INTO v_ctl_local
                FROM ov_cta_garantias a
               WHERE a.nro_cuenta = p_nro_cuenta
                 and a.nro_garantia = p_nro_garantia
                 and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             end;
             IF p_computable = 'S' AND v_es_nocomputable = 0 THEN
                IF v_ctl_local = 1 THEN
                   UPDATE ov_cta_garantias a
                      SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                          a.nro_garantia = p_nro_garantia,
                          a.cod_garantia = p_cod_garantia
                    WHERE a.nro_cuenta = p_nro_cuenta
                      and a.nro_garantia = p_nro_garantia
                      and a.cod_garantia = p_cod_garantia;
                 ELSE

                    ov_gar_rows.nro_garantia       := p_nro_garantia;
                    ov_gar_rows.cod_garantia       := p_cod_garantia;
                    ov_gar_rows.mto_aplicado       := 0;
                    ov_gar_rows.mto_apl_computable := p_mto_aplicado;
                    ov_gar_rows.nro_cuenta         := p_nro_cuenta;
                    ov_gar_rows.cod_persona        := p_cod_persona;
                    ov_gar_rows.mto_riesgo         := p_mto_riesgo;

                    lp_ins_cta_garantia(15, ov_gar_rows.nro_cuenta, ov_gar_rows.nro_garantia,
                                        ov_gar_rows.cod_garantia,
                                        ov_gar_rows.mto_aplicado,
                                        ov_gar_rows.mto_apl_computable,
                                        ov_gar_rows.cod_persona,
                                        ov_gar_rows.mto_riesgo);

                 END IF;
             END IF;
           END IF;

      ELSIF p_cod_modulo = 8 THEN
         -- Comercio Exterior
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cx_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               and a.nro_garantia is null
               and a.cod_garantia = 1;
           EXCEPTION
              WHEN no_data_found THEN
                 v_ctl_local := 0;
           END;

           IF v_ctl_local = 1 THEN
              BEGIN
                SELECT 1
                  INTO v_ctl_local
                  FROM cx_cta_garantias a
                 WHERE a.nro_cuenta = p_nro_cuenta
                   and a.nro_garantia = p_nro_garantia
                   and a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  when no_data_found then
                     v_ctl_local := 0;
               END;
               IF p_computable = 'S' THEN
                  IF v_ctl_local = 1 THEN
                     UPDATE cx_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0)
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia = p_nro_garantia
                        and a.cod_garantia = p_cod_garantia;
                   ELSE
                     UPDATE cx_cta_garantias a
                        SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                            a.nro_garantia = p_nro_garantia,
                            a.cod_garantia = p_cod_garantia
                      WHERE a.nro_cuenta = p_nro_cuenta
                        and a.nro_garantia is null
                        and a.cod_garantia = 1;
                  END IF;
               END IF;
           ELSE
             begin
              SELECT 1
                INTO v_ctl_local
                FROM cx_cta_garantias a
               WHERE a.nro_cuenta = p_nro_cuenta
                 and a.nro_garantia = p_nro_garantia
                 and a.cod_garantia = p_cod_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                   v_ctl_local := 0;
             end;
             IF p_computable = 'S' THEN
                IF v_control = 1 THEN
                   UPDATE cx_cta_garantias a
                      SET a.mto_apl_computable = nvl(a.mto_apl_computable, 0) +
                                                nvl(p_mto_aplicado, 0),
                          a.nro_garantia = p_nro_garantia,
                          a.cod_garantia = p_cod_garantia
                    WHERE a.nro_cuenta   = p_nro_cuenta
                      and a.nro_garantia = p_nro_garantia
                      and a.cod_garantia = p_cod_garantia;
                 ELSE

                    cx_gar_rows.nro_garantia       := p_nro_garantia;
                    cx_gar_rows.cod_garantia       := p_cod_garantia;
                    cx_gar_rows.mto_aplicado       := 0;
                    cx_gar_rows.mto_apl_computable := p_mto_aplicado;
                    cx_gar_rows.nro_cuenta         := p_nro_cuenta;
                    cx_gar_rows.cod_persona        := p_cod_persona;
                    cx_gar_rows.mto_riesgo         := p_mto_riesgo;

                    lp_ins_cta_garantia(8, cx_gar_rows.nro_cuenta, cx_gar_rows.nro_garantia,
                                        cx_gar_rows.cod_garantia,
                                        cx_gar_rows.mto_aplicado,
                                        cx_gar_rows.mto_apl_computable,
                                        cx_gar_rows.cod_persona,
                                        cx_gar_rows.mto_riesgo);
                  END IF;
              END IF;
           END IF;
     END IF;
   END;

   -- Procedimiento que actualiza el importe aplicado computable de las operaciones de las Garantías utilizadas por Terceros.
   PROCEDURE lp_act_apl_garantia
   (
      p_cod_modulo   NUMBER,
      p_nro_garantia NUMBER,
         p_cod_garantia NUMBER,
      p_nro_cuenta   VARCHAR2,
      p_mto_aplicado NUMBER,
      p_gar_aplicado NUMBER
   ) IS
      v_ctl_local NUMBER := 0;
      v_gar_aplicado   NUMBER := p_gar_aplicado;
  BEGIN    
    -- Exclusión de modalidades no computables (154, 970, 971)
   SELECT CASE 
             WHEN gc.cod_modalidad IN (154, 970, 971) THEN 0 
             ELSE p_gar_aplicado 
          END
     INTO v_gar_aplicado
     FROM ge_cuentas gc
    WHERE gc.nro_cuenta = p_nro_cuenta;    
  
      IF p_cod_modulo = 4 THEN
         -- Cuentas Corrientes.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cc_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_garantia = p_nro_garantia
               AND a.cod_garantia = p_cod_garantia;

          IF v_ctl_local = 1 THEN
             BEGIN
                UPDATE cc_cta_garantias a
                   SET a.mto_aplicado       = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                      a.mto_apl_computable = nvl(a.mto_apl_computable, 0) + nvl(p_gar_aplicado, 0)
                 WHERE a.nro_cuenta = p_nro_cuenta
                   AND a.nro_garantia = p_nro_garantia
                   AND a.cod_garantia = p_cod_garantia;

              EXCEPTION
                 WHEN OTHERS THEN
                 NULL;
             END;
          ELSE
                lp_ins_cta_garantia(4, p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado,
                                   p_gar_aplicado, fug_obt_cli_principal(p_nro_cuenta), 0);
           END IF;
         END;
      ELSIF p_cod_modulo = 5 THEN

         -- Tarjetas.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ta_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_garantia = p_nro_garantia
               AND a.cod_garantia = p_cod_garantia;
            IF v_ctl_local = 1 THEN
               BEGIN
                  UPDATE ta_cta_garantias a
                     SET a.mto_aplicado       = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                         a.mto_apl_computable = nvl(a.mto_apl_computable, 0) + nvl(p_gar_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_garantia = p_nro_garantia
                     AND a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            ELSE
               lp_ins_cta_garantia(5, p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado,
                                   p_gar_aplicado, fug_obt_cli_principal(p_nro_cuenta), 0);
            END IF;

         END;
      ELSIF p_cod_modulo = 6 THEN
         -- Préstamos.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM pr_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_garantia = p_nro_garantia
               AND a.cod_garantia = p_cod_garantia;

            IF v_ctl_local = 1 THEN
               BEGIN
                  UPDATE pr_cta_garantias a
                     SET a.mto_aplicado       = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                         a.mto_apl_computable = nvl(a.mto_apl_computable, 0) + nvl(v_gar_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_garantia = p_nro_garantia
                     AND a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            ELSE
               lp_ins_cta_garantia(6, p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado,
                                   v_gar_aplicado, fug_obt_cli_principal(p_nro_cuenta), 0);
            END IF;
         END;
      ELSIF p_cod_modulo = 15 THEN
         -- Operaciones Vencidas.
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM ov_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_garantia = p_nro_garantia
               AND a.cod_garantia = p_cod_garantia;
            --> Jira CROMG-50: Falta un espacio entre el número 1 y el THEN para que se pueda visualizar el contenido del procedimiento
            IF v_ctl_local = 1 THEN
               BEGIN
                  UPDATE ov_cta_garantias a
                     SET a.mto_aplicado       = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                         a.mto_apl_computable = nvl(a.mto_apl_computable, 0) + nvl(v_gar_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_garantia = p_nro_garantia
                     AND a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            ELSE
               lp_ins_cta_garantia(15, p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado,
                                   v_gar_aplicado, fug_obt_cli_principal(p_nro_cuenta), 0);
            END IF;
         END;
      ELSIF p_cod_modulo = 8 THEN
         -- Comercio Exterior
         BEGIN
            SELECT 1
              INTO v_ctl_local
              FROM cx_cta_garantias a
             WHERE a.nro_cuenta = p_nro_cuenta
               AND a.nro_garantia = p_nro_garantia
               AND a.cod_garantia = p_cod_garantia;

            IF v_ctl_local = 1 THEN
               BEGIN
                  UPDATE cx_cta_garantias a
                     SET a.mto_aplicado       = nvl(a.mto_aplicado, 0) + nvl(p_mto_aplicado, 0),
                         a.mto_apl_computable = nvl(a.mto_apl_computable, 0) + nvl(p_gar_aplicado, 0)
                   WHERE a.nro_cuenta = p_nro_cuenta
                     AND a.nro_garantia = p_nro_garantia
                     AND a.cod_garantia = p_cod_garantia;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     NULL;
               END;
            ELSE
               lp_ins_cta_garantia(8, p_nro_cuenta, p_nro_garantia, p_cod_garantia, p_mto_aplicado,
                                   p_gar_aplicado, fug_obt_cli_principal(p_nro_cuenta), 0);
            END IF;
         END;
      END IF;
   END;
   -- Procedimiento que actualiza el importe aplicado de las garantías vinculadas a operaciones de terceros.
   PROCEDURE lp_act_mto_gar_terceros(p_nro_cuenta ge_cta_clientes.nro_cuenta%TYPE) IS
   BEGIN
      -- Cuentas Corrientes.
      UPDATE cc_cta_garantias a SET a.mto_aplicado = 0 WHERE a.nro_cuenta = p_nro_cuenta;
      -- Tarjetas.
      UPDATE ta_cta_garantias a SET a.mto_aplicado = 0 WHERE a.nro_cuenta = p_nro_cuenta;
      -- Prestamos.
      UPDATE pr_cta_garantias a SET a.mto_aplicado = 0 WHERE a.nro_cuenta = p_nro_cuenta;
      -- Operaciones Vencidas.
      UPDATE ov_cta_garantias a SET a.mto_aplicado = 0 WHERE a.nro_cuenta = p_nro_cuenta;
      -- Comercio Exterior
      UPDATE cx_cta_garantias a SET a.mto_aplicado = 0 WHERE a.nro_cuenta = p_nro_cuenta;
   END;
   
   --Procedimiento que actualiza el monto de riesgo de las operaciones vinculadas a garantías cerradas.
   PROCEDURE lp_act_cta_mto_riesgo
   (
      p_cod_modulo ge_cuentas.cod_modulo%TYPE,
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_mto_riesgo pr_cta_garantias.mto_riesgo%TYPE
   )IS
   v_idx PLS_INTEGER;
    BEGIN
       CASE p_cod_modulo
          WHEN 4 THEN
             v_idx := v_cc_riesgo_tab.COUNT + 1;
             v_cc_riesgo_tab(v_idx).nro_cuenta := p_nro_cuenta;
             v_cc_riesgo_tab(v_idx).mto_riesgo := p_mto_riesgo;

          WHEN 5 THEN
             v_idx := v_ta_riesgo_tab.COUNT + 1;
             v_ta_riesgo_tab(v_idx).nro_cuenta := p_nro_cuenta;
             v_ta_riesgo_tab(v_idx).mto_riesgo := p_mto_riesgo;

          WHEN 6 THEN
             v_idx := v_pr_riesgo_tab.COUNT + 1;
             v_pr_riesgo_tab(v_idx).nro_cuenta := p_nro_cuenta;
             v_pr_riesgo_tab(v_idx).mto_riesgo := p_mto_riesgo;

          WHEN 15 THEN
             v_idx := v_ov_riesgo_tab.COUNT + 1;
             v_ov_riesgo_tab(v_idx).nro_cuenta := p_nro_cuenta;
             v_ov_riesgo_tab(v_idx).mto_riesgo := p_mto_riesgo;

          WHEN 8 THEN
             v_idx := v_cx_riesgo_tab.COUNT + 1;
             v_cx_riesgo_tab(v_idx).nro_cuenta := p_nro_cuenta;
             v_cx_riesgo_tab(v_idx).mto_riesgo := p_mto_riesgo;
       END CASE;
    END;
  -- Procedimiento que actualiza el monto de riesgo de las operaciones vinculadas a garantías cerradas.
  --ejecuta actualizacion masiva
 PROCEDURE lp_act_mto_riesgo IS
      BEGIN
         IF v_cc_riesgo_tab.COUNT > 0 THEN
            FORALL i IN v_cc_riesgo_tab.FIRST .. v_cc_riesgo_tab.LAST
               UPDATE cc_cta_garantias
                  SET mto_riesgo = v_cc_riesgo_tab(i).mto_riesgo
                WHERE nro_cuenta = v_cc_riesgo_tab(i).nro_cuenta;
         END IF;

         IF v_ta_riesgo_tab.COUNT > 0 THEN
            FORALL i IN v_ta_riesgo_tab.FIRST .. v_ta_riesgo_tab.LAST
               UPDATE ta_cta_garantias
                  SET mto_riesgo = v_ta_riesgo_tab(i).mto_riesgo
                WHERE nro_cuenta = v_ta_riesgo_tab(i).nro_cuenta;
         END IF;

         IF v_pr_riesgo_tab.COUNT > 0 THEN
            FORALL i IN v_pr_riesgo_tab.FIRST .. v_pr_riesgo_tab.LAST
               UPDATE pr_cta_garantias
                  SET mto_riesgo = v_pr_riesgo_tab(i).mto_riesgo
                WHERE nro_cuenta = v_pr_riesgo_tab(i).nro_cuenta;
         END IF;

         IF v_ov_riesgo_tab.COUNT > 0 THEN
            FORALL i IN v_ov_riesgo_tab.FIRST .. v_ov_riesgo_tab.LAST
               UPDATE ov_cta_garantias
                  SET mto_riesgo = v_ov_riesgo_tab(i).mto_riesgo
                WHERE nro_cuenta = v_ov_riesgo_tab(i).nro_cuenta;
         END IF;

         IF v_cx_riesgo_tab.COUNT > 0 THEN
            FORALL i IN v_cx_riesgo_tab.FIRST .. v_cx_riesgo_tab.LAST
               UPDATE cx_cta_garantias
                  SET mto_riesgo = v_cx_riesgo_tab(i).mto_riesgo
                WHERE nro_cuenta = v_cx_riesgo_tab(i).nro_cuenta;
         END IF;
          IF v_cc_riesgo_tab.COUNT > 0 THEN
              v_cc_riesgo_tab.DELETE;
           END IF;
           IF v_ta_riesgo_tab.COUNT > 0 THEN
              v_ta_riesgo_tab.DELETE;
           END IF;
           IF v_pr_riesgo_tab.COUNT > 0 THEN
              v_pr_riesgo_tab.DELETE;
           END IF;
           IF v_ov_riesgo_tab.COUNT > 0 THEN
              v_ov_riesgo_tab.DELETE;
           END IF;
           IF v_cx_riesgo_tab.COUNT > 0 THEN
              v_cx_riesgo_tab.DELETE;
           END IF;
      END;
   -- Procedimiento que actualiza el monto aplicado de las Garantías no Computables.
 PROCEDURE lp_act_gar_nocomputable
   (
      p_cod_modulo   NUMBER,
      p_mto_aplicado NUMBER,
      p_rowid        ROWID,
      p_nro_cuenta   cc_cta_garantias.nro_cuenta%TYPE,
      p_nro_garantia cc_cta_garantias.nro_garantia%TYPE,
      p_cod_garantia cc_cta_garantias.cod_garantia%TYPE
   ) IS
   BEGIN
      IF p_cod_modulo = 4 THEN
         -- Cuentas Corrientes.
         UPDATE cc_cta_garantias a
            SET a.mto_aplicado = a.mto_aplicado + p_mto_aplicado
          --WHERE a.rowid = p_rowid;
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia = p_nro_garantia
            and a.cod_garantia = p_cod_garantia;
      ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas.
         UPDATE ta_cta_garantias a
            SET a.mto_aplicado = a.mto_aplicado + p_mto_aplicado
          --WHERE a.rowid = p_rowid;
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia = p_nro_garantia
            and a.cod_garantia = p_cod_garantia;
      ELSIF p_cod_modulo = 6 THEN
         -- Préstamos.
         UPDATE pr_cta_garantias a
            SET a.mto_aplicado = a.mto_aplicado + p_mto_aplicado
          --WHERE a.rowid = p_rowid;
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia = p_nro_garantia
            and a.cod_garantia = p_cod_garantia;
      ELSIF p_cod_modulo = 15 THEN
         -- Operaciones Vencidas.
         UPDATE ov_cta_garantias a
            SET a.mto_aplicado = a.mto_aplicado + p_mto_aplicado
          --WHERE a.rowid = p_rowid;
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia = p_nro_garantia
            and a.cod_garantia = p_cod_garantia;
      ELSIF p_cod_modulo = 8 THEN
         -- Comercio Exterior
         UPDATE cx_cta_garantias a
            SET a.mto_aplicado = a.mto_aplicado + p_mto_aplicado
          --WHERE a.rowid = p_rowid;
          WHERE a.nro_cuenta = p_nro_cuenta
            and a.nro_garantia = p_nro_garantia
            and a.cod_garantia = p_cod_garantia;
      END IF;
   END;

  /* -- Funcion obtiene el monto que está garantizado por Garantías Cerrada.
   -- Esta función esta incluida en la vista pv_cta_garantias -- para optimización de tiempos
   FUNCTION lf_obt_mto_garantia */

   --Funcion que obtiene el monto aplicado de las garantías.
  FUNCTION lf_obt_mto_gar_utilizado (
      p_nro_garantia pr_garantias.nro_garantia%TYPE,
      p_nro_cuenta   ge_cuentas.nro_cuenta%TYPE
  ) RETURN NUMBER IS
      v_mto_garantia      pr_garantias.mto_aplicado%TYPE := 0;
  BEGIN
      -- Se consolidan todas las sumas en una única consulta
      SELECT NVL(SUM(CASE
                      WHEN b.cod_moneda = v_mon_local THEN NVL(a.mto_aplicado, 0)
                      ELSE pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_mon_local, NVL(a.mto_aplicado, 0))
                    END), 0)
      INTO v_mto_garantia
      FROM (
          SELECT nro_garantia, nro_cuenta, mto_aplicado 
            FROM pr_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_aplicado 
            FROM cc_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_aplicado 
            FROM ta_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
              
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_aplicado 
            FROM ov_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_aplicado 
            FROM cx_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
      ) a
      JOIN ge_cuentas b ON a.nro_cuenta = b.nro_cuenta;

      RETURN v_mto_garantia;

  EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RETURN 0;
      WHEN OTHERS THEN
          RETURN 0;
  END lf_obt_mto_gar_utilizado;


   --Funcion que obtiene el monto aplicado computable de las garantías para utilizar en el calculo de las previsiones.
  FUNCTION lf_obt_mto_gar_aplicado (
      p_nro_garantia pr_garantias.nro_garantia%TYPE,
      p_nro_cuenta   ge_cuentas.nro_cuenta%TYPE
  ) RETURN NUMBER IS
      v_mto_garantia NUMBER := 0;
  BEGIN
      -- Se consolidan todas las sumas en una única consulta
      SELECT NVL(SUM(
                  CASE
                      WHEN b.cod_moneda = v_mon_local THEN NVL(a.mto_apl_computable, 0)
                      ELSE pag_gen.fu_con_mon_a_moneda(b.cod_moneda, v_mon_local, NVL(a.mto_apl_computable, 0))
                  END), 0)
      INTO v_mto_garantia
      FROM (
          SELECT nro_garantia, nro_cuenta, mto_apl_computable 
            FROM pr_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_apl_computable 
            FROM cc_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          UNION ALL
          SELECT nro_garantia, nro_cuenta, mto_apl_computable 
            FROM ta_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
              
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_apl_computable 
            FROM ov_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
          
          UNION ALL
          
          SELECT nro_garantia, nro_cuenta, mto_apl_computable 
            FROM cx_cta_garantias
           WHERE (p_nro_garantia IS NOT NULL AND nro_garantia = p_nro_garantia)
              OR (p_nro_garantia IS NULL AND p_nro_cuenta IS NOT NULL AND nro_cuenta = p_nro_cuenta)
      ) a
      JOIN ge_cuentas b ON a.nro_cuenta = b.nro_cuenta;

      RETURN v_mto_garantia;

  EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RETURN 0;
      WHEN OTHERS THEN
          RETURN 0;
  END lf_obt_mto_gar_aplicado;

   --Funcion que obtiene el monto de riesgo de las cuentas de los clientes.
   FUNCTION lf_obt_sal_cuenta
   (
      p_cod_modulo IN ba_modulos.cod_modulo%TYPE,
      p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE
   ) RETURN NUMBER AS
      v_sal_comex   cx_cta_garantias.mto_aplicado%TYPE := 0;
      v_sal_comex_1 cx_cta_garantias.mto_aplicado%TYPE := 0;
      v_sal_total   pr_cta_garantias.mto_aplicado%TYPE := 0;
   BEGIN
      IF p_cod_modulo = 15 THEN
         --Operaciones Vencidas
         SELECT nvl(SUM(o.sal_total), 0)
           INTO v_sal_total
           FROM ov_cta_vencidas o, ge_est_cuentas e, ge_cta_clientes cc
          WHERE o.nro_cuenta = cc.nro_cuenta
            AND o.estado = e.estado
            AND o.cod_modulo = e.cod_modulo
            AND o.cod_modalidad = e.cod_modalidad
            AND e.activo = 'S'
            AND cc.relacion = 'P'
            AND o.nro_cuenta = p_nro_cuenta;
       ELSIF p_cod_modulo = 6 THEN
         --Préstamos
         --> Jira CROMG-50: A Pedido de Maria Esther Chavez y Domingo Daniel Ramirez se excluye  los intereses devegandos no cobrados
         SELECT SUM(nvl(p.sal_capital, 0)) /*+ nvl(p.dev_no_cobrado, 0)), 0)*/ saldo
           INTO v_sal_total
           FROM pr_cta_prestamos p, ge_est_cuentas e, ge_cta_clientes cc
          WHERE p.nro_cuenta = cc.nro_cuenta
            AND p.estado = e.estado
            AND p.cod_modulo = e.cod_modulo
            AND p.cod_modalidad = e.cod_modalidad
            AND e.activo = 'S'
            AND cc.relacion = 'P'
            AND p.nro_cuenta = p_nro_cuenta;
       ELSIF p_cod_modulo = 4 THEN
         -- Sobre giros - Cuentas Corrientes
         SELECT nvl(SUM(abs(nvl(c.sal_total, 0) - nvl(c.sal_bloqueado, 0) - nvl(c.sal_retenido, 0))),
                    0) saldo
           INTO v_sal_total
           FROM cc_cta_corrientes c, ge_est_cuentas e, ge_cta_clientes cc
          WHERE c.nro_cuenta = cc.nro_cuenta
            AND c.estado = e.estado
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND e.activo = 'S'
            AND cc.relacion = 'P'
            AND c.sal_total < 0
            AND c.nro_cuenta = p_nro_cuenta;
       ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas
         SELECT nvl(SUM(t.sal_facturar + t.sal_facturado + t.sal_financiado + t.sal_cuo_pendientes),
                    0) saldo,
                nvl(SUM(t.lin_credito), 0),
                nvl(MAX(t.estado), 'N') estado
           INTO v_sal_total, v_mto_linea, v_est_tarjeta
           FROM ta_cta_tarjetas t, ge_est_cuentas e, ge_cta_clientes cc
          WHERE t.nro_cuenta = cc.nro_cuenta
            AND t.estado = e.estado
            AND t.cod_modulo = e.cod_modulo
            AND t.cod_modalidad = e.cod_modalidad
            AND e.activo = 'S'
            AND cc.relacion = 'P'
            AND t.nro_cuenta = p_nro_cuenta;

         IF nvl(v_est_tarjeta, 'N') != 'B' THEN
            IF v_sal_total < v_mto_linea THEN
               v_sal_total := v_mto_linea;
            END IF;
         END IF;
       ELSIF p_cod_modulo = 8 THEN
         -- Comercio Fianzas
         SELECT nvl(SUM(xf.monto), 0) saldo
           INTO v_sal_comex
           FROM cx_fianzas xf, ge_est_cuentas ec
          WHERE xf.estado = ec.estado
            AND xf.cod_modulo = ec.cod_modulo
            AND xf.cod_modalidad = ec.cod_modalidad
            AND ec.activo = 'S'
            AND xf.monto > 0
            AND xf.estado = 'A'
            AND xf.nro_cuenta = p_nro_cuenta;

         -- Comercio Exterior Importaciones
         SELECT nvl(SUM(xi.saldo), 0) saldo
           INTO v_sal_comex_1
           FROM cx_cta_importaciones xi, ge_est_cuentas ec, ge_cta_clientes cc
          WHERE cc.nro_cuenta = xi.nro_cuenta
            AND xi.estado = ec.estado
            AND xi.cod_modulo = ec.cod_modulo
            AND xi.cod_modalidad = ec.cod_modalidad
            AND ec.activo = 'S'
            AND cc.relacion = 'P'
            AND xi.saldo > 0
            AND xi.nro_cuenta = p_nro_cuenta;

         v_sal_total := v_sal_comex + v_sal_comex_1;
      END IF;
      --
      RETURN nvl(v_sal_total, 0);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;
    --Funcion que obtiene fecha de vencimiento de prestamo y fecha vencimiento garantia.
   function lf_obt_fec_cuenta
   (
      p_nro_garantia in pr_garantias.nro_garantia%type,
      p_nro_cuenta in ge_cuentas.nro_cuenta%TYPE
   ) return varchar AS
      v_fec_prestamo pr_cta_prestamos.fec_vencimiento%type := null ;
      v_fec_garantia pr_garantias.fec_vencimiento%type := null ;
      v_var       varchar2(1) := 'N' ; -- variable
   begin
      begin
        select fec_vencimiento
          into v_fec_prestamo
          from pr_cta_prestamos
         where nro_cuenta = p_nro_cuenta ;
      exception
        when others then
          v_fec_prestamo := null ;
      end ;
       begin
        select fec_vencimiento
          into v_fec_garantia
          from pr_garantias
         where nro_garantia = p_nro_garantia ;
      exception
        when others then
          v_fec_garantia := null ;
      end ;
      if v_fec_prestamo >= v_fec_garantia then
        v_var := 'S' ;
      end if ;
      --
      return nvl(v_var, 'N');
   exception
      when others then
         return 'N';
   end;
   -- Proceso Principal.
BEGIN
   DBMS_MVIEW.REFRESH('PV_CTA_GARANTIAS');
   pag_cie.PR_INS_LOG('-FIN- 1. Refresh PV_CTA_GARANTIAS.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   DBMS_MVIEW.REFRESH('PV_MTO_RIESGOS');
   pag_cie.PR_INS_LOG('-FIN- 2. Refresh PV_MTO_RIESGOS.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   DBMS_MVIEW.REFRESH('PV_CTA_GAR_NOCOMPUTABLES');
   pag_cie.PR_INS_LOG('-FIN- 3. Refresh PV_CTA_GAR_NOCOMPUTABLES.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   v_tablas.EXTEND(5);
   v_tablas(1) := 'cc_cta_garantias';
   v_tablas(2) := 'ta_cta_garantias';
   v_tablas(3) := 'pr_cta_garantias';
   v_tablas(4) := 'ov_cta_garantias';
   v_tablas(5) := 'cx_cta_garantias';
   
   -- Elimina las garantías Abiertas y Propias.
   v_control := 1;
    FOR reg IN c_del_garantias LOOP
      v_nro_cuenta := null;
      v_gar := 'Elimina gar abiertas/propias nro_gar :'|| reg.nro_garantia ||'-'|| reg.cod_garantia||'Persona-'||reg.cod_persona ;
      -- Cuenta Corriente
      DELETE cc_cta_garantias c WHERE c.nro_garantia = reg.nro_garantia;
      -- Tarjetas.
      DELETE ta_cta_garantias t WHERE t.nro_garantia = reg.nro_garantia;
      -- Préstamos.
      DELETE pr_cta_garantias p WHERE p.nro_garantia = reg.nro_garantia and p.cod_garantia NOT IN (3, 13) and p.cod_garantia = reg.cod_garantia;--DYDMR-13096
      -- Operaciones Vencidas.
      DELETE ov_cta_garantias o WHERE o.nro_garantia = reg.nro_garantia;
      -- Comercio Exterior.
      DELETE cx_cta_garantias x WHERE x.nro_garantia = reg.nro_garantia;

      /* Para actualización de los Montos Computables de las Garantías Hipotecarias*/
      UPDATE pr_cta_garantias g
         SET g.mto_apl_computable = 0,
             g.mto_aplicado  = 0
       WHERE g.cod_garantia = reg.cod_garantia
         and g.nro_garantia = reg.nro_garantia
         and g.cod_garantia IN ('3', '13');--Hipoteca / Hip-Vivienda

    END LOOP;
    pag_cie.PR_INS_LOG('-FIN- 4. FOR c_del_garantias.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION'); 
   BEGIN
     -- Deshabilitar los triggers
     FOR i IN 1 .. v_tablas.COUNT LOOP
       v_sql := 'alter table ' || v_tablas(i) || ' disable all triggers';
       sql_util.ejecute_dml(v_sql, v_err);
     
       if v_err is not null then
         raise_application_error(-20001,'Al deshabilitar triggers ' || v_err);
       end if;
     END LOOP;
   
     -- Elimina las cuentas a sola firma para distribuir nuevamente las garantias.
     -- Cuenta Corriente
     DELETE cc_cta_garantias c WHERE c.cod_garantia = 1;
     pag_cie.PR_INS_LOG('-FIN- 5. DEL cc_cta_garantias.',it.pag_cie.c_log_TRACE,'AUTONOMOUS_TRANSACTION');
     -- Tarjetas.
     DELETE ta_cta_garantias t WHERE t.cod_garantia = 1;
     pag_cie.PR_INS_LOG('-FIN- 6. DEL ta_cta_garantias.',it.pag_cie.c_log_TRACE,'AUTONOMOUS_TRANSACTION');
     -- Préstamos.
     DELETE pr_cta_garantias p WHERE p.cod_garantia = 1;
     pag_cie.PR_INS_LOG('-FIN- 7. DEL pr_cta_garantias.',it.pag_cie.c_log_TRACE,'AUTONOMOUS_TRANSACTION');
     -- Operaciones Vencidas.
     DELETE ov_cta_garantias o WHERE o.cod_garantia = 1;
     pag_cie.PR_INS_LOG('-FIN- 8. DEL ov_cta_garantias.',it.pag_cie.c_log_TRACE,'AUTONOMOUS_TRANSACTION');
     -- Comercio Exterior.
     DELETE cx_cta_garantias x WHERE x.cod_garantia = 1;
     pag_cie.PR_INS_LOG('-FIN- 9. DEL cx_cta_garantias.',it.pag_cie.c_log_TRACE,'AUTONOMOUS_TRANSACTION');
   
     --habilitar los triggers
     FOR i IN 1 .. v_tablas.COUNT LOOP
       v_sql := 'alter table ' || v_tablas(i) || ' enable all triggers';
       sql_util.ejecute_dml(v_sql, v_err);
     
       if v_err is not null then
         raise_application_error(-20002, 'Al habilitar triggers ' || v_err);
       end if;
     END LOOP;
   
   EXCEPTION
     WHEN OTHERS THEN
       -- guardo el error original
       v_err := sqlerrm;
       v_sql := null; -- limpio 
       -- en caso de errores activo nuevamente los triggers
       FOR i IN 1 .. v_tablas.COUNT LOOP
         v_sql := 'alter table ' || v_tablas(i) || ' enable all triggers';
         sql_util.ejecute_dml(v_sql, v_err_aux); -- uso otra variable por si dee error nuevamente 
       
         if v_err_aux is not null then
           raise_application_error(-20003,'Error original: ' || v_err ||' | Error al habilitar triggers: ' ||v_tablas(i) || ': ' || v_err_aux);
         end if;
       END LOOP;
       -- Si no hubo errores al reactivar triggers, igual lanzo el error original
       RAISE_APPLICATION_ERROR(-20004, 'Error : ' || v_err);
   END;
   
   -- Cera el Valor del Monto Aplicado de la tabla pr_garantias. ----
   UPDATE pr_garantias g
      SET g.mto_apl_valor = 0,
          g.mto_aplicado  = 0
    WHERE g.estado = 'C'
      AND g.tipo = 'A';
   --Actualiza los campos de calculo de cobertura de las garantias de tipo codeudorias asignadas a operaciones.
   -- Cuenta Corriente
   UPDATE cc_cta_garantias cc
      SET cc.mto_aplicado       = (CASE WHEN cc.cod_garantia = 2 THEN 0 ELSE cc.mto_aplicado END),
          cc.mto_apl_computable = 0,
          cc.mto_con_computable = 0;
   -- Tarjetas.
   UPDATE ta_cta_garantias t
      SET t.mto_aplicado       = (CASE WHEN t.cod_garantia = 2 THEN 0 ELSE t.mto_aplicado END),
          t.mto_apl_computable = 0,
          t.mto_con_computable = 0;
   -- Préstamos.
   UPDATE pr_cta_garantias p
      SET p.mto_aplicado       = 0,
          p.mto_apl_computable = 0,
          p.mto_con_computable = 0
    WHERE p.cod_garantia = 2;

   UPDATE pr_cta_garantias p
      SET p.mto_apl_computable = 0,
          p.mto_con_computable = 0
    WHERE p.cod_garantia != 2;
   -- Operaciones Vencidas.
   UPDATE ov_cta_garantias o
      SET o.mto_aplicado       = (CASE WHEN o.cod_garantia = 2 THEN 0 ELSE o.mto_aplicado END),
          o.mto_apl_computable = 0,
          o.mto_con_computable = 0;
   -- Comercio Exterior.
   UPDATE cx_cta_garantias x
      SET x.mto_aplicado       = (CASE WHEN x.cod_garantia = 2 THEN 0 ELSE x.mto_aplicado END),
          x.mto_apl_computable = 0,
          x.mto_con_computable = 0;
   pag_cie.PR_INS_LOG('-FIN- 10. UPD varios.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   -- Inserta las operaciones en las tablas correspondientes a garantias.
   v_control   := 2;
   v_tot_saldo := 0;
   v_tot_utilizado :=0;
   v_tot_aplicado :=0;

   OPEN c_cuentas;
   LOOP
     EXIT WHEN c_cuentas%NOTFOUND;

     FETCH c_cuentas
        BULK COLLECT INTO c_ctas
        LIMIT 50000;
     FOR i IN c_ctas.FIRST .. c_ctas.LAST
     LOOP
      v_nro_cuenta := c_ctas(i).nro_cuenta;
      v_gar := 'Cursor General de Cuentas nro_cta :'|| c_ctas(i).nro_cuenta ||'-'||'Persona-'||c_ctas(i).cod_persona;
      -- Busca la cantidad de decimales que le corresponde a la moneda.
     /* if nvl(v_mon_anterior,c.cod_moneda) <> c.cod_moneda then
         v_red_credito := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, c.cod_moneda),0);
      end if;*/--no se utiliza
      --
      v_valor              := 0;
      v_val_aplicado       := 0;
      v_val_apl_utilizado  := 0;
      v_val_apl_aplicado   := 0;
      v_mto_aplicado       := 0;
      v_mto_gar_aplicado   := 0;
      v_mto_apl_utilizado  := 0;
      v_mto_apl_aplicado   := 0;
      v_mto_apl_computable := 0;
      v_mto_computable     := 0;
      v_mto_disponible     := 0;
      v_mto_uti_disponible := 0;
      v_mto_apl_disponible := 0;
      IF c_ctas(i).tot_saldo > 0 then
         lp_ins_col_cta_garantia(c_ctas(i).cod_modulo, c_ctas(i).nro_cuenta, NULL, 1, v_mto_aplicado,
                             v_mto_apl_computable, substr(c_ctas(i).cod_persona, 1, 10), c_ctas(i).tot_saldo);
      END IF;
    END LOOP;
      lp_ins_col_garantia;
      lp_del_colecciones;
   END LOOP;
   close c_cuentas;
    pag_cie.PR_INS_LOG('-FIN- 11. FOR c_cuentas.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  -- Carga de coleccion --
   OPEN c_act_mto_riesgo;
   LOOP
     EXIT WHEN c_act_mto_riesgo%NOTFOUND;
     FETCH c_act_mto_riesgo BULK COLLECT 
     INTO v_mto_riesgo_tab LIMIT 100000;

   FOR i IN v_mto_riesgo_tab.FIRST .. v_mto_riesgo_tab.LAST LOOP
      v_tot_saldo := v_mto_riesgo_tab(i).saldo;
      v_gar := 'Cur. de mto riesgos Cli. de  nro_cta :'|| v_mto_riesgo_tab(i).cuenta;
      v_nro_cuenta := v_mto_riesgo_tab(i).cuenta;
      -- Lógica para ajustar el saldo.
      IF v_mto_riesgo_tab(i).cod_modulo = 5 AND v_mto_riesgo_tab(i).estado != 'B' THEN
         IF v_mto_riesgo_tab(i).saldo < v_mto_riesgo_tab(i).mto_linea THEN
            v_tot_saldo := v_mto_riesgo_tab(i).mto_linea;
         END IF;
      END IF;

      -- Llamada al procedimiento para actualizar el monto de riesgo.
      lp_act_cta_mto_riesgo(v_mto_riesgo_tab(i).cod_modulo,
                            v_mto_riesgo_tab(i).cuenta,
                            v_tot_saldo);
   END LOOP;
   lp_act_mto_riesgo;
  END LOOP;
  CLOSE c_act_mto_riesgo;
  pag_cie.PR_INS_LOG('-FIN- 12. FOR c_act_mto_riesgo.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   DBMS_MVIEW.REFRESH('PV_DEU_GAR_TERCEROS_JJ');
   pag_cie.PR_INS_LOG('-FIN- 13. REFRESH PV_DEU_GAR_TERCEROS_JJ.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   v_control := 3;
   --Actualiza el monto aplicado de las garantias cerradas vinculadas a operaciones en base al saldo de la operacion.
   FOR reg_gar_cerradas IN c_gar_cerradas LOOP
       v_gar := 'Act. mto aplicado de gar. nro_gar :'|| reg_gar_cerradas.nro_garantia ||'-'|| reg_gar_cerradas.cod_garantia;
       v_nro_cuenta := null;
      --Prestamos
      UPDATE pr_cta_garantias a
         SET a.mto_aplicado = 0
       WHERE a.nro_garantia = reg_gar_cerradas.nro_garantia
         AND a.cod_garantia = reg_gar_cerradas.cod_garantia
         AND a.mto_riesgo <=
             pag_gen.fu_con_mon_a_moneda(reg_gar_cerradas.cod_moneda, fug_obt_mon_cta(a.nro_cuenta),
                                         reg_gar_cerradas.valor);
      --Tarjetas
      UPDATE ta_cta_garantias a
         SET a.mto_aplicado = 0
       WHERE a.nro_garantia = reg_gar_cerradas.nro_garantia
         AND a.cod_garantia = reg_gar_cerradas.cod_garantia
         AND a.mto_riesgo <=
             pag_gen.fu_con_mon_a_moneda(reg_gar_cerradas.cod_moneda, fug_obt_mon_cta(a.nro_cuenta),
                                         reg_gar_cerradas.valor);
      --Cuenta Corriente
      UPDATE cc_cta_garantias a
         SET a.mto_aplicado = 0
       WHERE a.nro_garantia = reg_gar_cerradas.nro_garantia
         AND a.cod_garantia = reg_gar_cerradas.cod_garantia
         AND a.mto_riesgo <=
             pag_gen.fu_con_mon_a_moneda(reg_gar_cerradas.cod_moneda, fug_obt_mon_cta(a.nro_cuenta),
                                         reg_gar_cerradas.valor);
      --Operaciones Vencidas
      UPDATE ov_cta_garantias a
         SET a.mto_aplicado = 0
       WHERE a.nro_garantia = reg_gar_cerradas.nro_garantia
         AND a.cod_garantia = reg_gar_cerradas.cod_garantia
         AND a.mto_riesgo <=
             pag_gen.fu_con_mon_a_moneda(reg_gar_cerradas.cod_moneda, fug_obt_mon_cta(a.nro_cuenta),
                                         reg_gar_cerradas.valor);
      --Comex
      UPDATE cx_cta_garantias a
         SET a.mto_aplicado = 0
       WHERE a.nro_garantia = reg_gar_cerradas.nro_garantia
         AND a.cod_garantia = reg_gar_cerradas.cod_garantia
         AND a.mto_riesgo <=
             pag_gen.fu_con_mon_a_moneda(reg_gar_cerradas.cod_moneda, fug_obt_mon_cta(a.nro_cuenta),
                                         reg_gar_cerradas.valor);

      --Actualiza la tabla pr_garantias.
      UPDATE pr_garantias g
         SET g.mto_apl_valor = 0,
             g.mto_aplicado  = 0
       WHERE g.nro_garantia = reg_gar_cerradas.nro_garantia;
   END LOOP;
   pag_cie.PR_INS_LOG('-FIN- 14. FOR c_gar_cerradas 1.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   --Actualiza el monto aplicado de las garantias cerradas vinculadas a operaciones en base al saldo de la operacion.
   FOR reg_gar_cerradas IN c_gar_cerradas LOOP
      v_mto_aplicado := 0;
      FOR reg IN c_cta_gar_cerradas(reg_gar_cerradas.nro_garantia, reg_gar_cerradas.cod_garantia,
                                    reg_gar_cerradas.cod_moneda, reg_gar_cerradas.valor) LOOP
         v_nro_cuenta := reg.nro_cuenta;
         v_gar := 'Act. mto aplicado de gar cerradas nro_gar:'|| reg_gar_cerradas.nro_garantia ||'-'|| reg_gar_cerradas.cod_garantia||' Modulo: '||reg.cod_modulo;
         --Obtengo el valor aplicado.
          v_mto_aplicado := lf_obt_mto_gar_utilizado(NULL, reg.nro_cuenta);
          --Prestamos.
          IF reg.cod_modulo = 6 THEN
             UPDATE pr_cta_garantias a
                SET a.mto_aplicado = nvl(a.mto_riesgo,0) -
                                    pag_gen.fu_con_mon_a_moneda(v_mon_local, reg.cod_moneda,
                                                                v_mto_aplicado)
              WHERE a.rowid  = reg.fila;
          --Cuentas Corrientes.
           ELSIF reg.cod_modulo = 4 THEN
             UPDATE cc_cta_garantias a
                SET a.mto_aplicado = nvl(a.mto_riesgo,0) -
                                    pag_gen.fu_con_mon_a_moneda(v_mon_local, reg.cod_moneda,
                                                                v_mto_aplicado)
              WHERE a.ROWID = reg.fila;
          -- Tarjetas.
            ELSIF reg.cod_modulo = 5 THEN
             UPDATE ta_cta_garantias a
                SET a.mto_aplicado = nvl(a.mto_riesgo,0) -
                                    pag_gen.fu_con_mon_a_moneda(v_mon_local, reg.cod_moneda,
                                                                v_mto_aplicado)
              WHERE a.ROWID = reg.fila;
          -- Operaciones Vencidas.
              ELSIF reg.cod_modulo = 15 THEN
             UPDATE ov_cta_garantias a
                SET a.mto_aplicado = nvl(a.mto_riesgo,0) -
                                    pag_gen.fu_con_mon_a_moneda(v_mon_local, reg.cod_moneda,
                                                                v_mto_aplicado)
              WHERE a.ROWID = reg.fila;
            -- Comercio Exterior.
              ELSIF reg.cod_modulo = 8 THEN
             UPDATE cx_cta_garantias a
                SET a.mto_aplicado = nvl(a.mto_riesgo,0) -
                                    pag_gen.fu_con_mon_a_moneda(v_mon_local, reg.cod_moneda,
                                                                v_mto_aplicado)
              WHERE a.ROWID = reg.fila;
          END IF;
      END LOOP;
   END LOOP;
    pag_cie.PR_INS_LOG('-FIN- 15. FOR c_gar_cerradas 2.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
    -- Carga de datos del cursor
   OPEN c_deu_garantias;
   LOOP
     EXIT WHEN c_deu_garantias%NOTFOUND;
      FETCH c_deu_garantias BULK COLLECT 
      INTO v_deu_terceros_tab LIMIT 100000;

   -- Calcula el monto aplicado para las operaciones vinculadas a una garantía cerrada.
    FOR i IN 1 .. v_deu_terceros_tab.COUNT LOOP
      v_nro_cuenta := v_deu_terceros_tab(i).nro_cuenta;
      v_gar := 'Calcula mto aplicado en gar cerradas nro_gar:'|| v_deu_terceros_tab(i).nro_garantia ||'-'|| v_deu_terceros_tab(i).cod_garantia;
      -- Distribuye el valor computable de la garantía entre las operaciones vinculadas a las garantías cerradas.
         --Obteniene el importe de riesgo de la operación.
          v_mto_gar_aplicado := lf_obt_mto_gar_aplicado(NULL, v_deu_terceros_tab(i).nro_cuenta);
          v_tot_saldo := nvl(v_deu_terceros_tab(i).mto_riesgo, 0) -
                         pag_gen.fu_con_mon_a_moneda(v_mon_local, v_deu_terceros_tab(i).cod_moneda, v_mto_gar_aplicado);
         -- Obtiene el monto computable de la Garantía.
         v_con_fecha := lf_obt_fec_cuenta(v_deu_terceros_tab(i).nro_garantia, v_deu_terceros_tab(i).nro_cuenta) ;
         if v_deu_terceros_tab(i).cod_garantia in (21) and v_con_fecha = 'S' then
             v_mto_computable := 0 ;
         elsif instr(','||v_cod_gar_fogapy||',', ','||v_deu_terceros_tab(i).cod_garantia||',') > 0 then
             if v_deu_terceros_tab(i).g_estado = 'V' THEN v_mto_computable := 0;           
             ELSE
             v_mto_computable := nvl(v_tot_saldo,0) * v_deu_terceros_tab(i).cobertura / 100;
             END IF;
              begin
                   v_por_mto_riesgo := 0;
                   v_por_mto_riesgo := pap_gar.FU_OBT_VAL_COMPUTABLE(v_deu_terceros_tab(i).NRO_GARANTIA);
                update pr_garantias g
                   set g.valor = v_por_mto_riesgo
                 where g.nro_garantia = v_deu_terceros_tab(i).nro_garantia
                   and g.valor <> v_por_mto_riesgo;
              end;
              
         else
             if v_deu_terceros_tab(i).g_estado = 'V' THEN v_mto_computable := 0; 
             ELSE
             v_mto_computable := nvl(pap_gar.fu_obt_val_computable(v_deu_terceros_tab(i).nro_garantia), 0);
             END IF;
         end if ;
		 
         -- Obtiene el valor ya utilizado.
          v_mto_aplicado := lf_obt_mto_gar_aplicado(v_deu_terceros_tab(i).nro_garantia, NULL);

         IF v_deu_terceros_tab(i).cod_moneda != v_deu_terceros_tab(i).cod_moneda_vencida THEN
            -- Si las monedas son diferentes convierte a la moneda del crédito.
            v_mto_computable := pag_gen.fu_con_mon_a_moneda(v_deu_terceros_tab(i).cod_moneda_vencida,
                                                            v_deu_terceros_tab(i).cod_moneda, nvl(v_mto_computable, 0));
         END IF;
         --
         IF v_deu_terceros_tab(i).cod_moneda != v_mon_local THEN
            v_val_aplicado := pag_gen.fu_con_mon_a_moneda(v_mon_local, v_deu_terceros_tab(i).cod_moneda,
                                                          nvl(v_mto_aplicado, 0));
         ELSE
            v_val_aplicado := nvl(v_mto_aplicado, 0);
         END IF;
         -- El disponible es la diferencia entre el Valor y el Aplicado.
         v_mto_disponible := v_mto_computable - v_val_aplicado;
         IF v_mto_disponible < 0 THEN
            v_mto_disponible := 0;
         END IF;
         --
         IF v_tot_saldo >= v_mto_disponible THEN
            v_mto_aplicado := v_mto_disponible;
            v_tot_saldo    := v_tot_saldo - v_mto_disponible;
         ELSE
            v_mto_aplicado := v_tot_saldo;
            v_tot_saldo    := 0;
         END IF;
         -- Actualiza la cta. garantia correspondiente.
         IF v_mto_aplicado > 0 THEN
                       lp_act_apl_gar_abiertas(v_deu_terceros_tab(i).cod_modulo, v_deu_terceros_tab(i).nro_garantia,
                                    v_deu_terceros_tab(i).cod_garantia, v_mto_aplicado, v_deu_terceros_tab(i).fila,
                                    v_deu_terceros_tab(i).nro_cuenta,v_deu_terceros_tab(i).cod_persona,v_deu_terceros_tab(i).computable,v_deu_terceros_tab(i).mto_riesgo);
         elsif v_mto_aplicado = 0 and v_deu_terceros_tab(i).cod_garantia in (21) and v_con_fecha = 'S' then
                       lp_act_apl_gar_abiertas(v_deu_terceros_tab(i).cod_modulo, v_deu_terceros_tab(i).nro_garantia,
                                                v_deu_terceros_tab(i).cod_garantia, v_mto_aplicado, v_deu_terceros_tab(i).fila,
                                                v_deu_terceros_tab(i).nro_cuenta,v_deu_terceros_tab(i).cod_persona,v_deu_terceros_tab(i).computable,v_deu_terceros_tab(i).mto_riesgo);
         END IF;
         v_con_fecha := 'N' ;
      END LOOP;
     END LOOP;
     CLOSE c_deu_garantias;
     pag_cie.PR_INS_LOG('-FIN- 16. FOR c_deu_garantias.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
 v_control := 4;
  /* Nuevo cursor para que distribuya primeramente los Préstamos Hipotecarios con Garantías Hipotecarias*/
   -- nuevo ajuste --
  FOR reg2 IN c_pre_hipotecarios LOOP
    v_gar := 'Gar hipotecarios nro_cta:'|| reg2.nro_cuenta ||' Persona '|| reg2.cod_persona;
      v_tot_saldo  := reg2.mto_riesgo;
      v_tot_utilizado:= reg2.mto_riesgo;
      v_tot_aplicado := reg2.mto_riesgo;

      v_tot_utilizado  :=   v_tot_utilizado -
                          pag_gen.fu_con_mon_a_moneda(v_mon_local, reg2.cod_moneda,
                                                  lf_obt_mto_gar_utilizado(NULL, reg2.nro_cuenta));

      v_tot_aplicado  :=   v_tot_aplicado -
                         pag_gen.fu_con_mon_a_moneda(v_mon_local, reg2.cod_moneda,
                                                  lf_obt_mto_gar_aplicado(NULL, reg2.nro_cuenta));

      v_nro_cuenta := reg2.nro_cuenta;

     FOR reg3 IN c_gar_hipotecario(reg2.cod_persona) LOOP
         -- Obtiene el monto computable de la Garantía.
         v_mto_computable := pap_gar.fu_obt_val_computable(reg3.nro_garantia);
         -- Obtiene le valor ya utilizado(aplicado y computables).
         v_mto_apl_utilizado := lf_obt_mto_gar_utilizado(reg3.nro_garantia, NULL);
         v_mto_apl_aplicado  := lf_obt_mto_gar_aplicado(reg3.nro_garantia, NULL);
             --
         IF reg2.cod_moneda <> reg3.cod_moneda THEN
            -- Si las monedas son diferentes convierte a la moneda del crédito.
            v_valor          := pag_gen.fu_con_mon_a_moneda(reg3.cod_moneda, reg2.cod_moneda, reg3.valor);
            v_mto_computable := pag_gen.fu_con_mon_a_moneda(reg3.cod_moneda, reg2.cod_moneda,
                                                            nvl(v_mto_computable, 0));
         ELSE
            v_valor := reg3.valor;
         END IF;
        --
         IF reg2.cod_moneda != v_mon_local THEN
            v_val_apl_utilizado := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg2.cod_moneda,
                                                          nvl(v_mto_apl_utilizado, 0));
            v_val_apl_aplicado  := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg2.cod_moneda,
                                                          nvl(v_mto_apl_aplicado, 0));
         ELSE
            v_val_apl_utilizado := nvl(v_mto_apl_utilizado, 0);
            v_val_apl_aplicado  := nvl(v_mto_apl_aplicado, 0);

         END IF;
           -- Montos Utilizados
         v_mto_uti_disponible  := v_valor - v_val_apl_utilizado;
         IF v_mto_uti_disponible < 0 THEN
            v_mto_uti_disponible := 0;
         END IF;
         --Montos Utilizados -- Montos Aplicados
         IF v_tot_utilizado >= v_mto_uti_disponible THEN
            v_mto_apl_utilizado  := v_mto_uti_disponible;
            v_tot_utilizado      := v_tot_utilizado - v_mto_uti_disponible;
         ELSE
            v_mto_apl_utilizado  := v_tot_utilizado;
            v_tot_utilizado   := 0;
         END IF;

           -- Montos Aplicados
         v_mto_apl_disponible :=  v_mto_computable - v_val_apl_aplicado;
         IF v_mto_apl_disponible < 0 THEN
            v_mto_apl_disponible := 0;
         END IF;
           -- Montos Aplicados -- Montos Computables
         IF v_tot_aplicado >= v_mto_apl_disponible THEN
            v_mto_apl_aplicado  := v_mto_apl_disponible;
            v_tot_aplicado:= v_tot_aplicado - v_mto_apl_disponible;
         ELSE
            v_mto_apl_aplicado  := v_tot_aplicado;
            v_tot_aplicado   := 0;
         END IF;
         IF v_mto_apl_utilizado > 0 THEN
            lp_act_cta_garantia(reg2.cod_modulo, reg3.nro_garantia, reg3.cod_garantia,
                                  v_mto_apl_utilizado, reg2.fila,reg2.nro_cuenta, reg2.cod_persona, reg2.mto_riesgo);
         END IF;

         -- Actualiza la cta. garantia correspondiente.
         IF v_mto_apl_aplicado > 0 /*AND reg3.cod_garantia > 2*/ THEN
            lp_act_apl_gar_abiertas(reg2.cod_modulo, reg3.nro_garantia, reg3.cod_garantia,
                                    v_mto_apl_aplicado, reg2.fila,
                                    reg2.nro_cuenta, reg2.cod_persona, reg3.computable, reg2.mto_riesgo);
         END IF;
      END LOOP;
 /*  Verificar Saldo del Préstamo Hipotecario, para realizar la distribución de las garantias que no son hipotecarias*/
      BEGIN
         SELECT (v.mto_riesgo - v.mto_aplicado)
        INTO  v_sal_cliente
           FROM (SELECT b.cod_moneda,
                        b.cod_modulo,
                        a.nro_cuenta,
                        SUM(a.mto_aplicado) mto_aplicado,
                        MAX(a.mto_riesgo) mto_riesgo
                     FROM pr_cta_garantias a, ge_cuentas b
                    WHERE a.nro_cuenta = b.nro_cuenta
                    GROUP BY b.cod_moneda, b.cod_modulo, a.nro_cuenta) v
          WHERE v.nro_cuenta = reg2.nro_cuenta ;
       EXCEPTION
          WHEN OTHERS THEN
            NULL  ;
      END;

      IF v_sal_cliente > 0 THEN
         FOR reg4 IN c_cli_hipotecarios(reg2.nro_cuenta) LOOP
                v_tot_saldo  := reg4.mto_riesgo;
                v_tot_utilizado:= reg4.mto_riesgo;
                v_tot_aplicado := reg4.mto_riesgo;

                v_tot_utilizado  :=   v_tot_utilizado -
                                                pag_gen.fu_con_mon_a_moneda(v_mon_local, reg4.moneda,
                                                           lf_obt_mto_gar_utilizado(NULL, reg4.nro_cuenta));

                v_tot_aplicado  :=   v_tot_aplicado -
                                               pag_gen.fu_con_mon_a_moneda(v_mon_local, reg4.moneda,
                                                           lf_obt_mto_gar_aplicado(NULL, reg4.nro_cuenta));

               v_nro_cuenta := reg4.nro_cuenta;

            FOR reg1 IN c_garantias(reg4.cod_persona) LOOP
                  -- Obtiene el monto computable de la Garantía. v_control 4 y 5
               v_mto_computable := pap_gar.fu_obt_val_computable(reg1.nro_garantia);
                  -- Obtiene le valor ya utilizado(aplicado y computables).
               v_mto_apl_utilizado := lf_obt_mto_gar_utilizado(reg1.nro_garantia, NULL);
               v_mto_apl_aplicado  := lf_obt_mto_gar_aplicado(reg1.nro_garantia, NULL);
                      --
               IF reg4.moneda <> reg1.cod_moneda THEN
                     -- Si las monedas son diferentes convierte a la moneda del crédito.
                  v_valor          := pag_gen.fu_con_mon_a_moneda(reg1.cod_moneda, reg4.moneda, reg1.valor);
                  v_mto_computable := pag_gen.fu_con_mon_a_moneda(reg1.cod_moneda, reg4.moneda,
                                                                     nvl(v_mto_computable, 0));
               ELSE
                  v_valor := reg1.valor;
               END IF;
                 --
               IF reg4.moneda != v_mon_local THEN
                  v_val_apl_utilizado := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg4.moneda,
                                                                   nvl(v_mto_apl_utilizado, 0));
                  v_val_apl_aplicado  := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg4.moneda,
                                                                   nvl(v_mto_apl_aplicado, 0));
               ELSE
                  v_val_apl_utilizado := nvl(v_mto_apl_utilizado, 0);
                  v_val_apl_aplicado  := nvl(v_mto_apl_aplicado, 0);

               END IF;
                    -- Montos Utilizados
               v_mto_uti_disponible  := v_valor - v_val_apl_utilizado;
               IF v_mto_uti_disponible < 0 THEN
                  v_mto_uti_disponible := 0;
               END IF;
                  --Montos Utilizados -- Montos Aplicados
               IF v_tot_utilizado >= v_mto_uti_disponible THEN
                  v_mto_apl_utilizado  := v_mto_uti_disponible;
                  v_tot_utilizado      := v_tot_utilizado - v_mto_uti_disponible;
               ELSE
                  v_mto_apl_utilizado  := v_tot_utilizado;
                  v_tot_utilizado   := 0;
               END IF;

                    -- Montos Aplicados
               v_mto_apl_disponible :=  v_mto_computable - v_val_apl_aplicado;
               IF v_mto_apl_disponible < 0 THEN
                  v_mto_apl_disponible := 0;
               END IF;
                    -- Montos Aplicados -- Montos Computables
               IF v_tot_aplicado >= v_mto_apl_disponible THEN
                  v_mto_apl_aplicado  := v_mto_apl_disponible;
                  v_tot_aplicado:= v_tot_aplicado - v_mto_apl_disponible;
               ELSE
                  v_mto_apl_aplicado  := v_tot_aplicado;
                  v_tot_aplicado   := 0;
               END IF;
               IF v_mto_apl_utilizado > 0 THEN
                  lp_act_cta_garantia(reg4.cod_modulo, reg1.nro_garantia, reg1.cod_garantia,
                                           v_mto_apl_utilizado, reg4.fila,reg4.nro_cuenta, reg4.cod_persona, reg4.mto_riesgo);
               END IF;

                  -- Actualiza la cta. garantia correspondiente.
               IF v_mto_apl_aplicado > 0 AND reg1.cod_garantia > 2 THEN
                  lp_act_apl_gar_abiertas(reg4.cod_modulo, reg1.nro_garantia, reg1.cod_garantia,
                                             v_mto_apl_aplicado, reg4.fila,
                                             reg4.nro_cuenta, reg4.cod_persona, reg1.computable, reg4.mto_riesgo);
               END IF;
            END LOOP;
         END LOOP;
      END IF;
   END LOOP;--prestamos hipotecarios--
   pag_cie.PR_INS_LOG('-FIN- 17. FOR c_pre_hipotecarios.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
 -- Distribuye las garantias abiertas calculando el valor de cobertura a nivel de riesgo.
   v_control := 5;
   -- Se unifico v_control 4 y 5  para optimización
   OPEN c_clientes;
    LOOP
       FETCH c_clientes BULK COLLECT INTO reg LIMIT 50000;
       EXIT WHEN reg.COUNT = 0;

       FOR i IN 1 .. reg.COUNT LOOP
          v_gar := 'Gar clientes nro_cta:'|| reg(i).nro_cuenta ||' Persona '|| reg(i).cod_persona;

          v_tot_saldo      := reg(i).mto_riesgo;
          v_tot_utilizado  := reg(i).mto_riesgo;
          v_tot_aplicado   := reg(i).mto_riesgo;

          -- Calcular utilizados y aplicados en cuenta (conversión si es necesario)
          v_mto_apl_utilizado := lf_obt_mto_gar_utilizado(NULL, reg(i).nro_cuenta);
          IF v_mto_apl_utilizado IS NOT NULL AND v_mto_apl_utilizado != 0 THEN
            IF reg(i).moneda = v_mon_local THEN
               v_tot_utilizado := v_tot_utilizado - v_mto_apl_utilizado;
            ELSE
                v_tot_utilizado := v_tot_utilizado -
                pag_gen.fu_con_mon_a_moneda(v_mon_local, reg(i).moneda, v_mto_apl_utilizado);
             END IF;
          END IF;

          v_mto_apl_aplicado := lf_obt_mto_gar_aplicado(NULL, reg(i).nro_cuenta);
          IF v_mto_apl_aplicado IS NOT NULL AND v_mto_apl_aplicado != 0 THEN
            IF reg(i).moneda = v_mon_local THEN
               v_tot_aplicado := v_tot_aplicado - v_mto_apl_aplicado;             
             ELSE
               v_tot_aplicado := v_tot_aplicado -
                  pag_gen.fu_con_mon_a_moneda(v_mon_local, reg(i).moneda, v_mto_apl_aplicado);
             END IF;
          END IF;

          v_nro_cuenta := reg(i).nro_cuenta;

          FOR reg1 IN c_garantias(reg(i).cod_persona) LOOP
             -------------------------------------------------------------------
             --CIE-1258 Requerimiento 2: salida anticipada si la deuda está 100% cubierta
             -------------------------------------------------------------------
             EXIT WHEN v_tot_utilizado <= 0 AND v_tot_aplicado <= 0;
             v_valor := reg1.valor;
         -- Obtiene el monto computable de la Garantía. v_control 4 y 5
             v_mto_computable := pap_gar.fu_obt_val_computable(reg1.nro_garantia);
         -- Obtiene le valor ya utilizado(aplicado y computables).             
             v_mto_apl_utilizado := lf_obt_mto_gar_utilizado(reg1.nro_garantia, NULL);
             v_mto_apl_aplicado  := lf_obt_mto_gar_aplicado(reg1.nro_garantia, NULL);

            -- Si las monedas son diferentes convierte a la moneda del crédito.
             IF reg(i).moneda <> reg1.cod_moneda THEN
                v_valor := pag_gen.fu_con_mon_a_moneda(reg1.cod_moneda, reg(i).moneda, reg1.valor);
                v_mto_computable := pag_gen.fu_con_mon_a_moneda(reg1.cod_moneda, reg(i).moneda, NVL(v_mto_computable, 0));
             END IF;

             IF reg(i).moneda <> v_mon_local THEN
                v_val_apl_utilizado := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg(i).moneda, NVL(v_mto_apl_utilizado, 0));
                v_val_apl_aplicado  := pag_gen.fu_con_mon_a_moneda(v_mon_local, reg(i).moneda, NVL(v_mto_apl_aplicado, 0));
             ELSE
                v_val_apl_utilizado := NVL(v_mto_apl_utilizado, 0);
                v_val_apl_aplicado  := NVL(v_mto_apl_aplicado, 0);
             END IF;

           -- Montos Utilizados
             v_mto_uti_disponible := v_valor - v_val_apl_utilizado;
             IF v_mto_uti_disponible < 0 THEN
                v_mto_uti_disponible := 0;
             END IF;

              --Montos Utilizados -- Montos Aplicados
             IF v_tot_utilizado >= v_mto_uti_disponible THEN
                v_mto_apl_utilizado := v_mto_uti_disponible;
                v_tot_utilizado := v_tot_utilizado - v_mto_uti_disponible;
             ELSE
                v_mto_apl_utilizado := v_tot_utilizado;
                v_tot_utilizado := 0;
             END IF;

           -- Montos Aplicados
             v_mto_apl_disponible := v_mto_computable - v_val_apl_aplicado;
             IF v_mto_apl_disponible < 0 THEN
                v_mto_apl_disponible := 0;
             END IF;

           -- Montos Aplicados -- Montos Computables
             IF v_tot_aplicado >= v_mto_apl_disponible THEN
                v_mto_apl_aplicado := v_mto_apl_disponible;
                v_tot_aplicado := v_tot_aplicado - v_mto_apl_disponible;
             ELSE
                v_mto_apl_aplicado := v_tot_aplicado;
                v_tot_aplicado := 0;
             END IF;

             IF v_mto_apl_utilizado > 0 THEN
                lp_act_cta_garantia(
                   reg(i).cod_modulo,
                   reg1.nro_garantia,
                   reg1.cod_garantia,
                   v_mto_apl_utilizado,
                   reg(i).fila,
                   reg(i).nro_cuenta,
                   reg(i).cod_persona,
                   reg(i).mto_riesgo
                );
             END IF;

             IF v_mto_apl_aplicado > 0 AND reg1.cod_garantia > 2 THEN
                lp_act_apl_gar_abiertas(
                   reg(i).cod_modulo,
                   reg1.nro_garantia,
                   reg1.cod_garantia,
                   v_mto_apl_aplicado,
                   reg(i).fila,
                   reg(i).nro_cuenta,
                   reg(i).cod_persona,
                   reg1.computable,
                   reg(i).mto_riesgo
                );
             END IF;
          END LOOP;
       END LOOP;
    END LOOP;
    CLOSE c_clientes;
   pag_cie.PR_INS_LOG('-FIN- 18. FOR c_clientes.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   -- Actualiza el importe aplicado de las garantías vinculadas a operaciones de terceros.
   v_control := 6;

   -- Abrir el cursor y cargar la coleccion
   OPEN c_ope_terceros;
   LOOP
     EXIT WHEN c_ope_terceros%NOTFOUND;
     FETCH c_ope_terceros BULK COLLECT 
     INTO v_ope_terceros LIMIT 100000;
   
   FOR i IN 1 .. v_ope_terceros.COUNT LOOP
      v_gar := 'Gar de terceros  nro_cta:'|| v_ope_terceros(i).nro_cuenta;
      v_nro_cuenta := v_ope_terceros(i).nro_cuenta;
      lp_act_mto_gar_terceros(v_ope_terceros(i).nro_cuenta);
   END LOOP;
   END LOOP;
   CLOSE c_ope_terceros;
   pag_cie.PR_INS_LOG('-FIN- 19. FOR c_ope_terceros.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   -- Distribuye las garantias utilizadas por terceros calculando el valor de cobertura a nivel de riesgos.
   -- se uníeron   v_control 7 y 8 para optimización de tiempos
   v_control := 7;

     OPEN c_gara_terceros;
   LOOP
     EXIT WHEN c_gara_terceros%NOTFOUND;
     FETCH c_gara_terceros BULK COLLECT 
     INTO v_gara_terceros LIMIT 100000;

  FOR i IN 1 .. v_gara_terceros.COUNT LOOP
         -- Obtiene el monto computable de la Garantía.
         v_nro_cuenta     := v_gara_terceros(i).nro_cuenta;
         v_con_fecha1 := lf_obt_fec_cuenta(v_gara_terceros(i).nro_garantia, v_gara_terceros(i).nro_cuenta) ;
         v_gar := 'Gar de terceros obt mto computable nro_cta:'|| v_gara_terceros(i).nro_cuenta ||' nro_gar: '||v_gara_terceros(i).nro_garantia;
          if v_gara_terceros(i).cod_garantia in (21) and v_con_fecha1 = 'S' then
               v_mto_computable := 0 ;
          else
               v_mto_computable := pap_gar.fu_obt_val_computable(v_gara_terceros(i).nro_garantia);
          end if ;
         v_tot_utilizado  := v_gara_terceros(i).mto_riesgo -
                             pag_gen.fu_con_mon_a_moneda(v_mon_local, v_gara_terceros(i).cod_moneda,lf_obt_mto_gar_utilizado(NULL,
                                                                                   v_gara_terceros(i).nro_cuenta));-- v_control 7

         v_tot_aplicado      := v_gara_terceros(i).mto_riesgo -
                              pag_gen.fu_con_mon_a_moneda(v_mon_local, v_gara_terceros(i).cod_moneda,lf_obt_mto_gar_aplicado(NULL,
                                                                                   v_gara_terceros(i).nro_cuenta));-- v_control 8
         IF v_tot_utilizado < 0 THEN -- v_control 7
            v_tot_utilizado := 0;
         END IF;

         IF v_tot_aplicado < 0 THEN -- v_control 8
            v_tot_aplicado := 0;
         END IF;

         -- Obtiene le valor ya utilizado.
         IF v_gara_terceros(i).nro_garantia IS NOT NULL  THEN -- v_control 7
            v_mto_apl_utilizado := lf_obt_mto_gar_utilizado(v_gara_terceros(i).nro_garantia, NULL);
         END IF;
             -- Obtiene el valor ya aplicado
         IF v_gara_terceros(i).nro_garantia is not null then -- v_control 8
            v_mto_apl_aplicado := lf_obt_mto_gar_aplicado(v_gara_terceros(i).nro_garantia, NULL);
         END IF;
                  --
         IF v_gara_terceros(i).cod_moneda_b <> v_gara_terceros(i).cod_moneda THEN
            -- Si las monedas son diferentes convierte a la moneda del crédito.
            v_valor          := pag_gen.fu_con_mon_a_moneda(v_gara_terceros(i).cod_moneda_b, v_gara_terceros(i).cod_moneda,
                                                            v_gara_terceros(i).valor);
            v_mto_computable := pag_gen.fu_con_mon_a_moneda(v_gara_terceros(i).cod_moneda_b, v_gara_terceros(i).cod_moneda,
                                                            nvl(v_mto_computable, 0));
         ELSE
            v_valor := v_gara_terceros(i).valor;
         END IF;
         --
         IF v_gara_terceros(i).cod_moneda != v_mon_local THEN
            v_val_apl_utilizado := pag_gen.fu_con_mon_a_moneda(v_mon_local, v_gara_terceros(i).cod_moneda,
                                                          nvl(v_mto_apl_utilizado, 0));-- v_control 7
            v_val_apl_aplicado  := pag_gen.fu_con_mon_a_moneda(v_mon_local, v_gara_terceros(i).cod_moneda,
                                                          nvl(v_mto_apl_aplicado, 0));-- v_control 8
         ELSE
            v_val_apl_utilizado := nvl(v_mto_apl_utilizado, 0);-- v_control 7
            v_val_apl_aplicado := nvl(v_mto_apl_aplicado, 0);-- v_control 8

         END IF;
         -- El disponible es la diferencia entre el Valor y el Aplicado.
         v_mto_uti_disponible := v_valor - v_val_apl_utilizado; -- v_control 7
         v_mto_apl_disponible := v_mto_computable - v_val_apl_aplicado; -- v_control 8

         IF v_mto_uti_disponible < 0 THEN -- v_control 7
            v_mto_uti_disponible := 0;
         END IF;
         IF v_mto_apl_disponible < 0 THEN-- v_control 8
            v_mto_apl_disponible := 0;
         END IF;
         --
         IF v_tot_utilizado >= v_mto_uti_disponible THEN -- v_control 7
            v_mto_apl_utilizado := v_mto_uti_disponible;
            v_tot_utilizado      := v_tot_utilizado - v_mto_uti_disponible;
         ELSE
            v_mto_apl_utilizado := v_tot_utilizado;
            v_tot_utilizado    := 0;
         END IF;

          IF v_tot_aplicado >= v_mto_uti_disponible THEN -- v_control 8
            v_mto_apl_aplicado := v_mto_apl_disponible;
            v_tot_aplicado      := v_tot_aplicado - v_mto_apl_disponible;
         ELSE
            v_mto_apl_aplicado := v_tot_aplicado;
            v_tot_aplicado    := 0;
         END IF;

         -- Actualiza la cta. garantia correspondiente.
         IF v_mto_apl_utilizado > 0 THEN -- v_control 7
            lp_act_cta_garantia(v_gara_terceros(i).cod_modulo,v_gara_terceros(i).nro_garantia,
                                v_gara_terceros(i).cod_garantia,
                                v_mto_apl_utilizado, v_gara_terceros(i).fila,v_gara_terceros(i).nro_cuenta,v_gara_terceros(i).cod_persona, v_gara_terceros(i).mto_riesgo);
         END IF;
         if v_gara_terceros(i).cod_garantia in (21) and v_con_fecha1 = 'S' then
            lp_act_apl_garantia(v_gara_terceros(i).cod_modulo,v_gara_terceros(i).nro_garantia,
                                v_gara_terceros(i).cod_garantia, v_nro_cuenta, 0,
                                v_mto_computable);
         elsif v_mto_apl_aplicado > 0 AND nvl(v_gara_terceros(i).cod_garantia, v_gara_terceros(i).cod_garantia) > 2 THEN -- v_control 8
            lp_act_apl_garantia(v_gara_terceros(i).cod_modulo,v_gara_terceros(i).nro_garantia,
                                v_gara_terceros(i).cod_garantia, v_nro_cuenta, 0,
                                v_mto_apl_aplicado);
         end if ;
         v_con_fecha1 := 'N' ;

  END LOOP;
 END LOOP;
 CLOSE c_gara_terceros;
 pag_cie.PR_INS_LOG('-FIN- 20. FOR c_gara_terceros.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   --Actualiza las garantias vinculas a operaciones correspondientes solamente a codeudoria.
   FOR reg IN c_act_gar_codeudoria LOOP
      v_gar := 'Act. gar a codeudoria nro_cta:'|| reg.nro_cuenta ||' nro_gar: '||reg.nro_garantia|| ' Modulo '||reg.cod_modulo;
      v_nro_cuenta := reg.nro_cuenta;
      IF reg.cod_modulo = 15 THEN
         --Operaciones Vencidas
          DELETE ov_cta_garantias ov WHERE ov.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 6 THEN
         --Préstamos
         DELETE pr_cta_garantias pr WHERE pr.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 4 THEN
         DELETE cc_cta_garantias cc WHERE cc.ROWID = reg.ROWID;
        -- Sobre giros - Cuentas Corrientes
      ELSIF reg.cod_modulo = 5 THEN
         -- Tarjetas
         DELETE ta_cta_garantias ta WHERE ta.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 8 THEN
         -- Comercio Fianzas
         DELETE cx_cta_garantias cx WHERE cx.ROWID = reg.ROWID;
      END IF;
   END LOOP;
   pag_cie.PR_INS_LOG('-FIN- 21. FOR c_act_gar_codeudoria.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   -- Elimina los registros insertados del tipo de garantía SOLA FIRMA de aquellas operaciones que poseen CODEUDORIA.
   v_control := 9;
   FOR reg IN c_del_gar_solafirma LOOP
     v_gar := 'Elimina reg insertados a sola firma nro_cta:'|| reg.nro_cuenta ||' nro_gar: '||reg.nro_garantia|| ' Modulo '||reg.cod_modulo;
      v_nro_cuenta := reg.nro_cuenta;
      IF reg.cod_modulo = 15 THEN
         --Operaciones Vencidas
         DELETE ov_cta_garantias ov WHERE ov.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 6 THEN
         --Préstamos
         DELETE pr_cta_garantias pr WHERE pr.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 4 THEN
         DELETE cc_cta_garantias cc WHERE cc.ROWID = reg.ROWID;
         -- Sobre giros - Cuentas Corrientes
      ELSIF reg.cod_modulo = 5 THEN
         -- Tarjetas
         DELETE ta_cta_garantias ta WHERE ta.ROWID = reg.ROWID;
      ELSIF reg.cod_modulo = 8 THEN
         -- Comercio Fianzas
         DELETE cx_cta_garantias cx WHERE cx.ROWID = reg.ROWID;
      END IF;
   END LOOP;
   pag_cie.PR_INS_LOG('-FIN- 22. FOR c_act_gar_codeudoria.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   --Actualiza el importe total de cobertura de las garantias en base al riesgo total de la operacion
   --en caso de que el monto de cobertura sea menor al riesgo de la operacion.
   v_mon_anterior := pag_gen.FU_OBT_MON_LOCAL; --BBVASOP-1666
   v_red_credito := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_mon_anterior),0);
    FOR reg IN c_aju_tot_garantia LOOP
       -- Inicializar variables
       v_contador    := 0;
       v_monto       := 0;
       v_acu_monto   := 0;
       v_gar := 'Act gar a sola firma nro_cta:' || reg.nro_cuenta || ' Modulo ' || reg.cod_modulo;
       v_nro_cuenta := reg.nro_cuenta;

       -- Actualizar parámetro por corte de control de moneda
       IF NVL(v_mon_anterior, reg.cod_moneda) <> reg.cod_moneda THEN
          BEGIN
             SELECT d.val_parametro
               INTO v_red_credito
               FROM ge_par_dinamicos d
              WHERE d.parametro = 'VAL_RED_MON_EXTRANJERA'
                AND NVL(d.cod_modulo, -1) = -1
                AND NVL(d.cod_modalidad, -1) = -1
                AND d.cod_moneda = reg.cod_moneda;
          EXCEPTION
             WHEN OTHERS THEN
                v_red_credito := 0;
          END;
       END IF;

       -- Cargar clientes en memoria
       SELECT cod_modulo, row_id, nro_cuenta, nro_garantia, cod_garantia
         BULK COLLECT INTO v_clientes
         FROM pv_cta_gar_nocomputables
        WHERE nro_cuenta = reg.nro_cuenta;

       IF v_clientes.COUNT > 0 THEN
          FOR i IN 1 .. v_clientes.COUNT LOOP
             v_contador := v_contador + 1;
             IF v_contador <> v_clientes.COUNT THEN
                v_monto := ROUND((reg.mto_riesgo - reg.mto_aplicado) / v_clientes.COUNT, v_red_credito);
                v_acu_monto := v_acu_monto + v_monto;
             ELSE
                v_monto := ROUND((reg.mto_riesgo - reg.mto_aplicado), v_red_credito) - v_acu_monto;
             END IF;

             -------------------------------------------------------------------
             -- CIE-1258 Requerimiento 3: reemplazo de subprograma por DML directo
             -------------------------------------------------------------------
             IF v_clientes(i).cod_modulo = 4 THEN
                UPDATE cc_cta_garantias a
                   SET a.mto_aplicado = a.mto_aplicado + v_monto
                 WHERE a.nro_cuenta   = v_clientes(i).nro_cuenta
                   AND a.nro_garantia = v_clientes(i).nro_garantia
                   AND a.cod_garantia = v_clientes(i).cod_garantia;
             ELSIF v_clientes(i).cod_modulo = 5 THEN
                UPDATE ta_cta_garantias a
                   SET a.mto_aplicado = a.mto_aplicado + v_monto
                 WHERE a.nro_cuenta   = v_clientes(i).nro_cuenta
                   AND a.nro_garantia = v_clientes(i).nro_garantia
                   AND a.cod_garantia = v_clientes(i).cod_garantia;
             ELSIF v_clientes(i).cod_modulo = 6 THEN
                UPDATE pr_cta_garantias a
                   SET a.mto_aplicado = a.mto_aplicado + v_monto
                 WHERE a.nro_cuenta   = v_clientes(i).nro_cuenta
                   AND a.nro_garantia = v_clientes(i).nro_garantia
                   AND a.cod_garantia = v_clientes(i).cod_garantia;
             ELSIF v_clientes(i).cod_modulo = 15 THEN
                UPDATE ov_cta_garantias a
                   SET a.mto_aplicado = a.mto_aplicado + v_monto
                 WHERE a.nro_cuenta   = v_clientes(i).nro_cuenta
                   AND a.nro_garantia = v_clientes(i).nro_garantia
                   AND a.cod_garantia = v_clientes(i).cod_garantia;
             ELSIF v_clientes(i).cod_modulo = 8 THEN
                UPDATE cx_cta_garantias a
                   SET a.mto_aplicado = a.mto_aplicado + v_monto
                 WHERE a.nro_cuenta   = v_clientes(i).nro_cuenta
                   AND a.nro_garantia = v_clientes(i).nro_garantia
                   AND a.cod_garantia = v_clientes(i).cod_garantia;
             END IF;
          END LOOP;
       ELSE
          -- No hay clientes, insertar en tabla de garantías
          lp_ins_cta_garantia(
             reg.cod_modulo,
             reg.nro_cuenta,
             NULL,
             1,
             ROUND((reg.mto_riesgo - reg.mto_aplicado), v_red_credito),
             0,
             fug_obt_cli_principal(reg.nro_cuenta),
             reg.mto_riesgo
          );
       END IF;

       v_mon_anterior := reg.cod_moneda;
    END LOOP;
   pag_cie.PR_INS_LOG('-FIN- 23. FOR c_aju_tot_garantia.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   --Actualiza el importe de cobertura de garantias en la tabla ge_cla_operaciones.
   v_control := 10;
  -- UPDATE ge_cla_operaciones a SET a.tot_gar_computables = 0; --anterior
     UPDATE ge_cla_operaciones a
        SET a.tot_gar_computables = 0
      WHERE a.tot_gar_computables <> 0
        -- Requerimiento: CNFAIRUNO-3.
        -- Fecha: 22/09/2014.
        AND a.cod_modulo <> 8;
        pag_cie.PR_INS_LOG('-FIN- 24. UPD ge_cla_operaciones.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  OPEN c_cla_operaciones;
   LOOP
     EXIT WHEN c_cla_operaciones%NOTFOUND;
     FETCH c_cla_operaciones BULK COLLECT 
     INTO v_cla_operaciones LIMIT 100000;

   -- Recorrido de la colección v_cla_operaciones
   FOR reg IN 1 .. v_cla_operaciones.COUNT LOOP
      v_gar := 'Act ge_cla_operaciones nro_cta:'|| v_cla_operaciones(reg).nro_cuenta;
      v_nro_cuenta := v_cla_operaciones(reg).nro_cuenta;
      BEGIN
         -- Obtención de información adicional de la tabla ge_clientes y ge_cta_clientes
         BEGIN
            SELECT cl.cat_automatica, v_fec_actual - cl.fec_ult_clasif
              INTO v_cat_automatica, v_can_dia_ult_clasif
            FROM ge_cta_clientes ct, ge_clientes cl
           WHERE ct.nro_cuenta = v_cla_operaciones(reg).nro_cuenta
             AND ct.cod_persona = cl.cod_persona
             AND ct.relacion = 'P';
         EXCEPTION
            WHEN OTHERS THEN
               v_cat_automatica := 1; -- En caso de error, asignar un valor predeterminado
         END;

         -- Condición para verificar la categoría automática y los días de clasificación
         IF v_cat_automatica = 6 AND v_can_dia_ult_clasif >= 545 THEN
            BEGIN
               -- Si se cumple la condición, actualizamos tot_gar_computables a 0
               UPDATE ge_cla_operaciones a
                  SET a.tot_gar_computables = 0
                WHERE a.nro_cuenta = v_cla_operaciones(reg).nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         ELSE
            BEGIN
               -- Si no se cumple la condición, acumulamos el monto computable en tot_gar_computables
               UPDATE ge_cla_operaciones a
               SET a.tot_gar_computables = CASE 
                                           WHEN a.cod_modalidad IN (154, 970, 971) THEN 0 
                                           ELSE NVL(a.tot_gar_computables, 0) + NVL(v_cla_operaciones(reg).mto_gar_computable, 0) 
                                           END
               WHERE a.nro_cuenta = v_cla_operaciones(reg).nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;

      END;
   END LOOP;
   END LOOP;
   CLOSE c_cla_operaciones;
   pag_cie.PR_INS_LOG('-FIN- 26. FOR c_cla_operaciones.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   /*
   || PTFRETECNO-3 Contabilización Garantías Computables
   */
   prp_gen_det_gar_com;
   pag_cie.PR_INS_LOG('-FIN- 25. PR prp_gen_det_gar_com.', it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
   ---
EXCEPTION
   WHEN OTHERS THEN
       v_sql := null; -- limpio 
       -- en caso de errores activo nuevamente los triggers
       FOR i IN 1 .. v_tablas.COUNT LOOP
         v_sql := 'alter table ' || v_tablas(i) || ' enable all triggers';
         sql_util.ejecute_dml(v_sql, v_err_aux); -- uso otra variable por si dee error nuevamente 
       
         if v_err_aux is not null then
           v_error_trg := ('Error al habilitar triggers favor contactar con el DBA '||v_err_aux);
         end if;
       END LOOP;
      raise_application_error(-20000,
                              'Paso ' || v_control || '. Error en la cuenta ' || v_nro_cuenta || ' ' ||v_gar ||' '||v_error_trg||' '||
                               SQLERRM);

END;
/
