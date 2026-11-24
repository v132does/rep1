CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_SGR
   (
      p_fec_desde   IN DATE,
      p_fec_hasta   IN DATE
   ) IS
      v_mon_fuerte      ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
      v_cod_ciu_origen  ba_oficinas.cod_ciudad%TYPE;
      v_cod_ciu_destino ba_oficinas.cod_ciudad%TYPE;
      p_proceso         char(1) := 'M';
      v_cod_pai_destino ba_oficinas.cod_pais%TYPE;
      v_cod_pai_origen  ba_oficinas.cod_pais%TYPE;
      v_fec_desde       DATE  := NVL(p_fec_desde, PAG_CAL.FU_OBT_FEC_ANT_HAB(PAG_CAL.FU_OBT_FEC_ACTUAL(1), null, 1));
      v_fec_hasta       DATE  := NVL(p_fec_hasta, PAG_CAL.FU_OBT_FEC_ANT_HAB(PAG_CAL.FU_OBT_FEC_ACTUAL(1), null, 1));

      -- Se  carga el cursor de movimientos --
      CURSOR c_mov IS

         SELECT DISTINCT tip_movimiento,
                         region,
                         fecha,
                         cod_usuario,
                         hora,
                         nro_secuencia,
                         cod_transaccion,
                         tipo,
                         nro_cuenta,
                         monto,
                         cod_canal,
                         cod_modulo,
                         cod_modalidad,
                         cod_moneda,
                         cod_ofi_origen,
                         nro_caja,
                         estado,
                         reversado,
                         cod_usu_reversion,
                         cotizacion,
                         cod_tra_padre,
                         cod_mod_padre,
                         cod_mad_padre,
                         cod_persona,
                         cod_ofi_destino,
                         tip_monto,
                         cod_per_solicitante,
                         cod_per_beneficiario,
                         nombre_solicitante,
                         dir_solicitante,
                         cod_ciu_solicitante,
                         cod_pai_solicitante,
                         cod_ciu_beneficiario,
                         nombre_beneficiario,
                         dir_beneficiario,
                         cod_pai_beneficiario,
                         cod_tip_doc_beneficiario,
                         nro_doc_beneficiario,
                         cod_operacion,
                         cod_tip_doc_solicitante,
                         nro_doc_solicitante,
                         ---
                         mto_equ_local,
                         mto_mon_origen,
                         cod_mon_destino,
                         cot_mon_destino,
                         nom_ent_externa,
                         nro_cta_ent_externa,
                         cod_pai_ent_externa,
                         nom_ciu_ent_externa,
                         nro_cheque,
                         nro_boleta,
                         motivo,
                         observacion,
                         cod_pai_bco_intermediario,
                         nom_bco_intermediario ,
                         cod_aba_bco_intermediario,
                         cod_swi_bco_intermediario,
                         nom_corresponsal,
                         INS_SEPRELAD,
                         CTA_DESTINO,
                         CDA,
                         DES_TRA_HIJA,
                         DES_TRA_MADRE
           FROM ld_int_movimientos_tmp;

      v_exi_mov     VARCHAR2(1) := NULL;
      v_exi_cli_ben VARCHAR2(1) := NULL;
      v_exi_cli_lav VARCHAR2(1) := NULL;

      PROCEDURE lp_ins_movimientos_tmp
      (
         v_fec_desde      IN DATE,
         p_mon_fuerte IN ba_monedas.cod_moneda%TYPE
      ) IS
      BEGIN

         EXECUTE IMMEDIATE 'truncate table ld_int_movimientos_tmp';
         -- desde aqui repite los filtros cuando fecha is null
         INSERT INTO

         ld_int_movimientos_tmp
            (tip_movimiento,region, fecha, cod_usuario, hora, nro_secuencia, cod_transaccion, tipo,
             nro_cuenta, monto, cod_canal, cod_modulo, cod_modalidad, cod_moneda, cod_ofi_origen,
             nro_caja, estado, reversado, cod_usu_reversion, cotizacion, cod_tra_padre,
             cod_mod_padre, cod_mad_padre, cod_persona, cod_ofi_destino, tip_monto,
             cod_per_solicitante, cod_per_beneficiario, nombre_solicitante, dir_solicitante,
             cod_ciu_solicitante, cod_pai_solicitante, cod_ciu_beneficiario, nombre_beneficiario,
             dir_beneficiario, cod_pai_beneficiario, cod_tip_doc_beneficiario, nro_doc_beneficiario,
             cod_operacion, cod_tip_doc_solicitante, nro_doc_solicitante,
             ---
             mto_equ_local, mto_mon_origen, cod_mon_destino, cot_mon_destino, nom_ent_externa,
             nro_cta_ent_externa, cod_pai_ent_externa, nom_ciu_ent_externa, nro_cheque, nro_boleta,
             motivo, observacion, cod_pai_bco_intermediario, nom_bco_intermediario,
             cod_aba_bco_intermediario, cod_swi_bco_intermediario, nom_corresponsal,
             INS_SEPRELAD,
             CTA_DESTINO,
             CDA,
             DES_TRA_HIJA,
             DES_TRA_MADRE
             )


/*
|| SELECT 1/12
|| InstrumentoSEPRELAD:
|| GE_TRA_INTERNAS: Tabla en la que se registran todos los pedidos de Transferencias Internas de Dinero.
*/
            SELECT 'T' iden,
                   'A' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   ce.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   nvl(ce.cod_per_remitente, ce.cod_per_beneficiario) cod_persona,
                   ce.cod_ofi_destino,
                   ce.for_pago tip_monto,
                   ce.cod_per_remitente,
                   ce.cod_per_beneficiario,

                   NULL nombre_solicitante,
                   NULL dir_solicitante,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,

                   NULL ciu_beneficiario,

                   NULL nombre_beneficiario,
                   NULL dir_beneficiario,
                   NULL cod_pai_beneficiario,

                   NULL             cod_tip_doc_beneficiario,
                   NULL             nro_doc_beneficiario,
                   ge.cod_operacion,
                   NULL             cod_tip_doc_solicitante,
                   NULL             nro_doc_solicitante,
                   ----
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   NULL cod_mon_destino,
                   NULL cot_mon_destino,
                   NULL nom_ent_externa,
                   NULL nro_cta_ent_externa,
                   NULL cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL cod_pais_bco_intermediario,
                   NULL nom_bco_intermediario,
                   NULL cod_aba_banco,
                   NULL cod_swi_banco,
                   NULL cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN GE_TRA_INTERNAS CE ON C.MONTO          = CE.MONTO
                                      AND C.COD_MONEDA    = CE.COD_MONEDA
                                      AND C.NRO_DOCUMENTO = CE.COD_TRANSFERENCIA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

             WHERE NVL(CE.ESTADO, 'X') = 'P'
               AND C.COD_TRA_PADRE     = 297
               AND C.COD_MODULO        = 9
               AND C.COD_TRANSACCION IN (661, 941, 962, 663)
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELET 2/12
|| InstrumentoSEPRELAD: CAMCANJ
|| LC_TRANSFERENCIAS: Contiene los datos de las Libranzas o Transferencias de Cambios.
*/
            UNION ALL
            SELECT 'T' iden,
                   'B' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.COD_OFI_ORIGEN cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA))cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   nvl(cx.cod_per_solicitante, cx.cod_per_beneficiario) cod_persona,
                   NULL,
                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          'E') tip_monto,

                   cx.cod_per_solicitante,
                   cx.cod_per_beneficiario,

                   cx.nom_solicitante     nombre_solicitante,
                   cx.dir_solicitante     dir_solicitante,
                   cx.cod_ciu_solicitante ciudad_solicitante,
                   cx.cod_pai_solicitante pais_solicitante,
                   cx.cod_ciu_beneficiario ciu_beneficiario,
                   cx.nom_beneficiario     nombre_beneficiario,
                   cx.dir_beneficiario     dir_beneficiario,
                   cx.cod_pai_beneficiario cod_pai_beneficiario,
                   /*decode(cx.cod_per_beneficiario, NULL, cx.cod_tip_doc_beneficiario, NULL)*/NULL cod_tip_doc_beneficiario,
                   decode(cx.cod_per_beneficiario, NULL, cx.nro_doc_beneficiario, NULL) nro_doc_beneficiario,
                   ge.cod_operacion,
                   /*decode(cx.cod_per_solicitante, NULL, cx.cod_tip_doc_solicitante, NULL)*/NULL cod_tip_doc_solicitante,
                   /*decode(cx.cod_per_solicitante, NULL, cx.nro_doc_solicitante, NULL)*/NULL nro_doc_solicitante,
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   (SELECT mo.cod_moneda
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora = lc.hora
                       AND c.fecha = lc.fecha
                       AND c.cod_usuario = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda = mo.cod_moneda) cod_mon_destino,

                   (SELECT lc.cotizacion
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora = lc.hora
                       AND c.fecha = lc.fecha
                       AND c.cod_usuario = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda = mo.cod_moneda) cot_mon_destino,

                   substr(CX.NOM_BANCO, 1, 30) nom_ent_externa,
                   NVL(cx.nro_cta_referencia,0) nro_cta_ent_externa,
                   P.COD_PAI_ISO, --NULL cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL cod_pais_bco_intermediario,
                   substr(cx.nom_beneficiario, 1, 100) nom_bco_intermediario,
                   cx.cod_aba_banco cod_aba_banco,
                   NVL(cx.cod_swi_banco, 'n/a') cod_swi_banco,
                   fug_obt_des_banco(cx.cod_bco_corresponsal) cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,
                   /*Verificar el DES_TRA_HIJA*/
                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                                        --AND C.MONTO         = CX.MONTO
                                        --AND C.COD_MONEDA    = CX.COD_MONEDA
                                        AND C.FECHA         = CX.FEC_OPERACION
                                        AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD   --NEW
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION --NEW
                                           --AND C.COD_MAD_PADRE = GE.COD_MODALIDAD
                                           --AND C.COD_TRA_PADRE = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

              LEFT JOIN BA_PAISES P ON CX.COD_PAI_BANCO = P.COD_PAIS

            WHERE C.COD_MOD_PADRE  = 7
              AND C.COD_TRA_PADRE  <> 297
              --AND C.COD_TRANSACCION NOT IN (661, 941, 962, 663)
              --AND C.COD_TRANSACCION NOT IN (661, 941, 962, 663, 503) -- Agregamos el 503 por casos de TRAEXREM
              AND C.COD_TRANSACCION NOT IN (661, 941, 962, 663, 503, 602, 760) -- Agregamos el 602 y 760 por casos de TRAEXTREC duplicados
              AND C.ESTADO         = 'N'
              AND C.REVERSADO       <> 'S'
              AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELET 3/12
|| InstrumentoSEPRELAD: TRAINTER, TRANACREC
|| GE_SNP_TRANSFERENCIAS: Contiene los datos de Transferencias Interbancarias.
*/
            UNION ALL
            SELECT 'T' iden,
                   'C' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   ex.cod_oficina cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   fug_obt_cli_principal(c.nro_cuenta) cod_persona,
                   ex.cod_oficina,
                   'N' tip_monto,
                   ex.cod_per_solicitante,
                   ex.cod_per_beneficiario,
                   ex.nom_solicitante nombre_solicitante,
                   ex.dir_solicitante dir_solicitante,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,
                   NULL ciu_beneficiario,
                   ex.nom_beneficiario nombre_beneficiario,
                   ex.dir_beneficiario dir_beneficiario,
                   NULL cod_pai_beneficiario,

                   CASE
                      WHEN cod_per_beneficiario IS NULL THEN
                       ex.cod_tip_doc_beneficiario
                      ELSE
                       NULL
                   END cod_tip_doc_beneficiario,

                   CASE
                      WHEN cod_per_beneficiario IS NULL THEN
                       ex.nro_doc_beneficiario
                      when ex.nro_doc_beneficiario IS NULL THEN
                       fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA))
                       ELSE NULL
                   END nro_doc_beneficiario,

                   --fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA)) nro_doc_beneficiario,

                   ge.cod_operacion,

                   CASE
                      WHEN cod_per_solicitante IS NULL THEN
                       ex.cod_tip_doc_solicitante
                      ELSE
                       NULL
                   END cod_tip_doc_solicitante,
                   CASE
                      WHEN cod_per_solicitante IS NULL THEN
                       ex.nro_doc_solicitante
                      ELSE
                       NULL
                   END nro_doc_solicitante,

                   -----
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   NULL cod_mon_destino,
                   NULL cot_mon_destino,
                   NULL nom_ent_externa,
                   nvl(ex.nro_cta_pte_beneficiario,0) nro_cta_ent_externa,
                   NULL cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL                        cod_pais_bco_intermediario,
                   NULL                        nom_bco_intermediario,
                   NULL                        cod_aba_banco,
                   ex.cod_swi_pte_beneficiario cod_swi_banco,
                   NULL                        cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN GE_SNP_TRANSFERENCIAS EX ON C.MONTO          = EX.MONTO
                                            AND C.COD_MONEDA    = EX.COD_MONEDA
                                            AND C.NRO_DOCUMENTO = EX.NRO_REFERENCIA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

             WHERE C.COD_TRA_PADRE   = 303
               AND C.COD_MOD_PADRE   = 4
               AND C.COD_MAD_PADRE   = 455
               AND EX.NRO_DOC_SOLICITANTE IS NOT NULL
               AND EX.ESTADO         = 'A'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 4/12
|| InstrumentoSEPRELAD: CANANCREF
|| PR_CTA_PRESTAMOS: Contiene los datos principales de los Prestamos.
*/
            UNION ALL
            SELECT 'P' iden,
                   'D' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   (select distinct nro_caja from GV_MOVIMIENTOS
                   where fecha=c.fecha and hora=c.hora and cod_tra_padre=c.cod_tra_padre
                   and cod_mod_padre=c.cod_mod_padre and cod_mad_padre=c.cod_mad_padre
                   and nro_caja is not null
                   and rownum=1) nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   (SELECT cc.cod_persona
                      FROM LV_cta_clientes cc
                     WHERE cc.nro_cuenta = c.nro_cuenta
                       AND cc.relacion = 'P'
                       AND rownum = 1) cod_persona,
                   c.cod_oficina,
                   decode((select distinct nro_caja from GV_MOVIMIENTOS
                   where fecha=c.fecha and hora=c.hora and cod_tra_padre=c.cod_tra_padre
                   and cod_mod_padre=c.cod_mod_padre and cod_mad_padre=c.cod_mad_padre
                   and nro_caja is not null
                   AND rownum = 1), NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                   decode((select distinct cod_retencion from GV_MOVIMIENTOS
                   where fecha=c.fecha and hora=c.hora and cod_tra_padre=c.cod_tra_padre
                   and cod_mod_padre=c.cod_mod_padre and cod_mad_padre=c.cod_mad_padre
                   and nro_caja is not null
                   and rownum=1 ),null,'E','O')) tip_monto,

                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,
                   NULL ciu_beneficiario,
                   NULL nombre_beneficiario,
                   NULL dir_beneficiario,
                   NULL cod_pai_beneficiario,
                   NULL cod_tip_doc_beneficiario,
                   NULL nro_doc_beneficiario,
                   ge.cod_operacion,
                   NULL,
                   NULL,
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   NULL            cod_mon_destino,
                   NULL            cot_mon_destino,
                   NULL            nom_ent_externa,
                   NULL            nro_cta_ent_externa,
                   NULL            cod_pai_ent_externa,
                   NULL            nom_ciu_ent_externa,
                   NULL            nro_cheque,

                   case when c.nro_documento in (0,1) then c.nro_documento4
                        else c.nro_documento
                          end nro_documento, -- Agregamos el CASE - HU - 07/04/2022

                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL            observacion,
                   NULL            cod_pais_bco_intermediario,
                   NULL            nom_bco_intermediario,
                   NULL            cod_aba_banco,
                   NULL            cod_swi_banco,
                   NULL            cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LV_CTA_PRESTAMOS PP ON C.NRO_CUENTA = PP.NRO_CUENTA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

             WHERE C.COD_TRA_PADRE IN (358, 360, 362,364, 359, 950, 900)
               AND C.MONTO           > 0
               AND C.ESTADO          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 5/12
|| InstrumentoSEPRELAD: EXTEFEC, CANANCREF, TRAEXTREC, TRAINTER
|| AH_CTA_VISTAS: Contiene datos de los Ahorros a la Vista.
*/
            UNION ALL
            SELECT 'A' iden,
                   'E' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,

                   (SELECT cc.cod_persona FROM lv_cta_clientes cc
                                          WHERE cc.nro_cuenta = c.nro_cuenta
                                          AND cc.relacion = 'P'
                                          AND rownum = 1) cod_persona,

                   c.cod_oficina,

                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          decode(c.cod_transaccion, 607, 'O', 'E')) tip_monto,

                   NULL,
                   NULL,
                   --CX.NOM_SOLICITANTE                                           nombre_solicitante,
                   
                   -- Agregamos de esta forma porque había casos de CANVENT que figuraban es esta región
                   NVL(CX.NOM_SOLICITANTE ,decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nom_completo
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nom_completo
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1))))) nombre_solicitante,
                   
                   cx.dir_solicitante                                           dir_solicitante,
                   cx.cod_ciu_solicitante                                       ciudad_solicitante,
                   cx.cod_pai_solicitante                                       pais_solicitante,
                   cx.cod_ciu_beneficiario                                      ciu_beneficiario,
                   NVL(cx.nom_beneficiario, fue_obt_nom_persona(PV.COD_PERSONA)) nombre_beneficiario,
                   cx.dir_beneficiario                                          dir_beneficiario,
                   cx.cod_pai_beneficiario                                      cod_pai_beneficiario,
                   /*cx.cod_tip_doc_beneficiario*/ NULL                         cod_tip_doc_beneficiario,
                   fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA)) nro_doc_beneficiario,
                   ge.cod_operacion                                             cod_operacion,
                   /*decode(cx.cod_per_solicitante, NULL, cx.cod_tip_doc_solicitante, NULL)*/NULL cod_tip_doc_solicitante,
                   --decode(cx.cod_per_solicitante, NULL, cx.nro_doc_solicitante, NULL)     nro_doc_solicitante,
                   
                     NVL(/*cx.nro_doc_solicitante*/NULL,
                        decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nro_documento
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nro_documento
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1))))) nro_doc_solicitante,
                   
                   
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   --NULL cod_mon_destino,
                   
                   (SELECT mo.cod_moneda
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora           = lc.hora
                       AND c.fecha          = lc.fecha
                       AND c.cod_usuario    = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda    = mo.cod_moneda) cod_mon_destino,
                   
                   NULL cot_mon_destino,
                   NVL(substr(CX.NOM_BANCO, 1, 30), substr(fug_obt_des_banco(cx.cod_bco_corresponsal),1,30)) nom_ent_externa,
                   NVL(cx.nro_cta_referencia,0) nro_cta_ent_externa, --Actualmente en ITGF NO guardan el 'nro_cta_ent_externa' para casos de TRAEXTREC
                   p.cod_pai_iso cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   substr(cx.observacion, 1, 30) observacion,
                   NULL cod_pais_bco_intermediario,
                   NULL nom_bco_intermediario,
                   cx.cod_aba_banco cod_aba_banco,
                   cx.cod_swi_banco,
                   fug_obt_des_banco(cx.cod_bco_corresponsal) cod_bco_corresponsal, --cx.cod_bco_corresponsal cod_bco_corresponsal,
                   th.ins_seprelad,
                                                 
                  (SELECT DISTINCT LM.NRO_CUENTA FROM GV_MOVIMIENTOS LM
                                                 WHERE LM.FECHA            = C.FECHA
                                                 AND LM.HORA               = C.HORA
                                                 AND LM.COD_USUARIO        = C.COD_USUARIO
                                                 --AND LM.COD_TRA_PADRE      IN (388, 309)
                                                 --AND LM.COD_TRANSACCION    in (602)
                                                 --AND LM.COD_TIP_MOVIMIENTO = 'C'
                                                 and lm.NRO_SECUENCIA in (select max(nro_secuencia) from gv_movimientos h
                                                                                                     where h.FECHA           = lm.FECHA
                                                                                                     and h.HORA              = lm.hora
                                                                                                     and h.COD_USUARIO       = lm.COD_USUARIO
                                                                                                     AND h.COD_TRA_PADRE     IN (388, 309)
                                                                                                     AND h.COD_TRANSACCION   in (602)
                                                                                                     AND h.COD_TIP_MOVIMIENTO = 'C')) CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LV_CTA_AHORROS PV ON C.NRO_CUENTA = PV.NRO_CUENTA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

              LEFT JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                                             --AND C.MONTO         = CX.MONTO
                                             --AND C.COD_MONEDA    = CX.COD_MONEDA
                                             AND C.FECHA         = CX.FEC_OPERACION
                                             AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

              LEFT JOIN BA_PAISES P ON CX.COD_PAI_BANCO = P.COD_PAIS

             WHERE C.MONTO           > 0
               AND C.COD_TRANSACCION IS NOT NULL
               AND C.COD_TRA_PADRE NOT IN (358, 360, 359, 362, /*309,*/ 297, 303, 264, 901)
               AND C.COD_MOD_PADRE NOT IN (5, 6)
               AND C.ESTADO          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 6/12
|| InstrumentoSEPRELAD: EXTCHEQ, TRAEXTREC, TRAEXTREM, TRAINTER, TRANACREC
|| CC_CTA_CORRIENTES: Maestro de Cuentas Corrientes.
*/
            UNION ALL
            SELECT 'A' iden,
                   'F' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   (SELECT cc.cod_persona
                      FROM lv_cta_clientes cc
                     WHERE cc.nro_cuenta = c.nro_cuenta
                       AND cc.relacion = 'P'
                       AND rownum = 1) cod_persona,
                   c.cod_oficina,
                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          decode(c.cod_transaccion, 607, 'O', 'E')) tip_monto,
                   cx.cod_per_solicitante,
                   cx.cod_per_beneficiario,
                   cx.nom_solicitante       nombre_solicitante,
                   cx.dir_solicitante,
                   cx.cod_ciu_solicitante   ciudad_solicitante,
                   cx.cod_pai_solicitante   pais_solicitante,
                   cx.cod_ciu_beneficiario  ciu_beneficiario,
                   NVL(cx.nom_beneficiario, fue_obt_nom_persona(PV.COD_PERSONA)) nombre_beneficiario, 
                   cx.dir_beneficiario                                           dir_beneficiario,
                   cx.cod_pai_beneficiario                                       cod_pai_beneficiario,
                   --cx.cod_tip_doc_beneficiario                                   cod_tip_doc_beneficiario,
                   /*NVL(B.COD_TIP_DOCUMENTO, cx.cod_tip_doc_beneficiario)*/NULL cod_tip_doc_beneficiario,
                   fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA))  nro_doc_beneficiario,
                   ge.cod_operacion,
                   /*NVL(CX.COD_TIP_DOC_SOLICITANTE, fue_obt_tip_doc_persona(pv.COD_PERSONA))*/NULL cod_tip_doc_solicitante,
                   /*decode(cx.cod_per_solicitante, NULL, cx.nro_doc_solicitante, NULL)*/NULL       nro_doc_solicitante,
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   NULL cod_mon_destino,
                   NULL cot_mon_destino,
                   substr(CX.NOM_BANCO, 1, 30), 

                   NVL((select case when c.COD_transaccion = 503 then gg.NRO_CUENTA else null end

                                 from gv_movimientos gg,
                                      ge_transacciones gt

                                 where gt.cod_transaccion = c.cod_transaccion
                                 AND gt.cod_modulo        = c.cod_modulo
                                 AND gt.cod_modalidad     = c.cod_modalidad
                                 and gg.COD_transaccion   = 602
                                 and gt.tipo              = 'D'
                                 ---
                                 and gg.NRO_DOCUMENTO     = c.NRO_DOCUMENTO
                                 and gg.FECHA             = c.FECHA
                                 and gg.HORA              = c.HORA
                                 and gg.COD_USUARIO       = c.COD_USUARIO
                                 ---
                                 and gg.NRO_SECUENCIA     = 2),cx.nro_cta_referencia) nro_cta_ent_externa, 

                   P.COD_PAI_ISO,
                   NULL nom_ciu_ent_externa,
                   c.NRO_DOCUMENTO nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL cod_pais_bco_intermediario,
                   NULL nom_bco_intermediario,
                   NULL cod_aba_banco,
                   NVL(cx.cod_swi_banco, 'n/a') cod_swi_banco,
                   NULL cod_bco_corresponsal,
                   th.ins_seprelad,

                  (SELECT DISTINCT LM.NRO_CUENTA FROM GV_MOVIMIENTOS LM
                                                 WHERE LM.FECHA            = C.FECHA
                                                 AND LM.HORA               = C.HORA
                                                 AND LM.COD_USUARIO        = C.COD_USUARIO
                                                 --AND LM.COD_TRA_PADRE      IN (388, 309)
                                                 --AND LM.COD_TRANSACCION    in (602)
                                                 --AND LM.COD_TIP_MOVIMIENTO = 'C'
                                                 and lm.NRO_SECUENCIA in (select max(nro_secuencia) from gv_movimientos h
                                                                                                     where h.FECHA           = lm.FECHA
                                                                                                     and h.HORA              = lm.hora
                                                                                                     and h.COD_USUARIO       = lm.COD_USUARIO
                                                                                                     AND h.COD_TRA_PADRE     IN (388, 309)
                                                                                                     AND h.COD_TRANSACCION   in (602)
                                                                                                     AND h.COD_TIP_MOVIMIENTO = 'C')) CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LV_CTA_CORRIENTES PV ON C.NRO_CUENTA = PV.NRO_CUENTA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

               /*LEFT*/ JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                                             --AND C.MONTO         = CX.MONTO
                                             --AND C.COD_MONEDA    = CX.COD_MONEDA
                                             AND C.FECHA         = CX.FEC_OPERACION
                                             AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

              LEFT JOIN BA_PAISES P ON CX.COD_PAI_BANCO = P.COD_PAIS
              
              LEFT JOIN BA_PERSONAS B ON fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA)) = B.NRO_DOCUMENTO

             WHERE C.MONTO           > 0
               AND C.COD_TRANSACCION IS NOT NULL
               --AND C.COD_TRA_PADRE NOT IN (358, 360, 359, 362, 309, 297, 303, 264, 901)
               AND C.COD_TRA_PADRE NOT IN (358, 360, 359, 362, 297, 303, 901) -- Quitamos el 309 para casos de TRAINTER y 264 por TRAEXTREM
               AND C.COD_MOD_PADRE NOT IN (5, 6)
               AND C.ESTADO          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 7/12
|| InstrumentoSEPRELAD:
|| AH_CTA_CERTIFICADOS: Contiene datos de los Certificados de Depositos de Ahorro.
*/
            UNION ALL
            SELECT 'A' iden,
                   'G' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   (SELECT cc.cod_persona
                      FROM lv_cta_clientes cc
                     WHERE cc.nro_cuenta = c.nro_cuenta
                       AND cc.relacion = 'P'
                       AND rownum = 1) cod_persona,
                   c.cod_oficina,
                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          decode(c.cod_transaccion, 607, 'O', 'E')) tip_monto,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,
                   NULL ciu_beneficiario,
                   B.NOM_COMPLETO nombre_beneficiario,
                   NULL dir_beneficiario,
                   NULL cod_pai_beneficiario,
                   B.COD_TIP_DOCUMENTO cod_tip_doc_beneficiario,
                   B.NRO_DOCUMENTO nro_doc_beneficiario,
                   ge.cod_operacion,
                   NULL,
                   NULL,
                   c.mto_equ_local,
                   c.monto mto_mon_origen,

                   NULL            cod_mon_destino,
                   NULL            cot_mon_destino,
                   NULL            nom_ent_externa,
                   NULL            nro_cta_ent_externa,
                   NULL            cod_pai_ent_externa,
                   NULL            nom_ciu_ent_externa,
                   NULL            nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL            observacion,
                   NULL            cod_pais_bco_intermediario,
                   NULL            nom_bco_intermediario,
                   NULL            cod_aba_banco,
                   NULL            cod_swi_banco,
                   NULL            cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LV_CTA_CERTIFICADOS PCE ON C.NRO_CUENTA = PCE.NRO_CUENTA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion
                                                
              LEFT JOIN BA_PERSONAS B ON B.COD_PERSONA = C.NRO_DOCUMENTO3 -- Para casos de DEPEFEC

             WHERE C.MONTO           > 0
               AND C.COD_TRANSACCION IS NOT NULL
               AND C.ESTADO          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta


/*
|| SELECT 8/12
|| InstrumentoSEPRELAD: TRAINTER
|| TA_CTA_TARJETAS: Es la tabla maestra de Cuentas de Tarjetas
*/
            UNION ALL
            SELECT 'R' iden,
                   'H' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   (SELECT cc.cod_persona
                      FROM LV_cta_clientes cc
                     WHERE cc.nro_cuenta = c.nro_cuenta
                       AND cc.relacion = 'P'
                       AND rownum = 1) cod_persona,
                   c.cod_oficina,
                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          'E') tip_monto,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,
                   NULL ciu_beneficiario,
                   NULL nombre_beneficiario,
                   NULL dir_beneficiario,
                   NULL cod_pai_beneficiario,
                   NULL cod_tip_doc_beneficiario,
                   NULL nro_doc_beneficiario,
                   ge.cod_operacion,
                   NULL,
                   NULL,
                   c.mto_equ_local,
                   c.monto mto_mon_origen,

                   NULL            cod_mon_destino,
                   NULL            cot_mon_destino,
                   NULL            nom_ent_externa,
                   NULL            nro_cta_ent_externa,
                   NULL            cod_pai_ent_externa,
                   NULL            nom_ciu_ent_externa,
                   NULL            nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL            observacion,
                   NULL            cod_pais_bco_intermediario,
                   NULL            nom_bco_intermediario,
                   NULL            cod_aba_banco,
                   NULL            cod_swi_banco,
                   NULL            cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C,
                   LV_CTA_TARJETAS PCT,
                   LD_INT_TRANSACCIONES GE,
                   LD_INT_TRANSACCIONES TH

             WHERE C.NRO_CUENTA      = PCT.NRO_CUENTA
               --
               AND C.COD_MODULO      = GE.COD_MODULO
               AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
               AND C.COD_TRANSACCION = GE.COD_TRANSACCION
               -- DES_TRA_MADRE
               AND C.cod_mod_padre   = TH.cod_modulo(+)
               AND C.cod_mad_padre   = TH.cod_modalidad(+)
               AND C.cod_tra_padre   = TH.cod_transaccion(+)
               --
               AND C.MONTO           > 0
               AND C.COD_TRANSACCION IS NOT NULL
               AND C.ESTADO          = 'N'
               AND NOT EXISTS (SELECT 1 FROM GE_SNP_TRANSFERENCIAS EX
                                         WHERE EX.MONTO        = C.MONTO
                                         AND EX.COD_MONEDA     = C.COD_MONEDA
                                         AND EX.NRO_REFERENCIA = C.NRO_DOCUMENTO)
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 9/12
|| InstrumentoSEPRELAD: CAMCOMP, CAMVENT, TRAINTER, TRANACREC
|| LD_INT_TRANSACCIONES: Transacciones Padres.
|| select * from lc_tip_operaciones l where l.cod_modulo = 7
                                      and l.cod_modalidad in (71,72,73,74)
                                      and l.cod_tip_operacion not in (1,2,3,4,5,6,7,8,9)
*/
            UNION ALL
            SELECT 'T' iden,
                   'I' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,

                   (SELECT gt.tipo
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_tra_padre
                       AND gt.cod_modulo = c.cod_mod_padre
                       AND gt.cod_modalidad = c.cod_mad_padre
                       AND rownum = 1) tipo,

                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_oficina cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   fug_obt_per_transferencia(nvl(c.cod_persona,(SELECT b.nro_documento2
                                                     FROM GV_MOVIMIENTOS b
                                                    WHERE fecha = c.fecha
                                                      AND hora = c.hora
                                                      AND cod_usuario = c.cod_usuario
                                                      AND cod_modalidad = 70
                                                      AND b.nro_documento2 IS NOT NULL
                                                      AND rownum = 1))) cod_persona,
                   c.cod_oficina cod_ofi_destino,
                   (SELECT afe_posicion
                      FROM lc_tip_operaciones
                     WHERE cod_tip_operacion = c.cod_tip_ope_cambio) tip_monto,
                   (nvl(c.cod_persona,
                        (SELECT b.nro_documento2
                            FROM GV_MOVIMIENTOS b
                           WHERE fecha = c.fecha
                             AND hora = c.hora
                             AND cod_usuario = c.cod_usuario
                             AND cod_modalidad = 70
                             AND b.nro_documento2 IS NOT NULL
                             AND rownum = 1))) cod_per_solicitante,

                   NULL, --cx.cod_per_beneficiario,
                   --c.concepto nombre_solicitante,
                   
                   decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nom_completo
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nom_completo
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1))))nombre_solicitante,
                   
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   NULL,
                   ge.cod_operacion,

                   NULL, --decode(cx.cod_per_solicitante, NULL, cx.cod_tip_doc_solicitante, NULL) cod_tip_doc_solicitante,

                   decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nro_documento
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nro_documento
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1)))) nro_doc_solicitante,

                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   (SELECT mo.cod_moneda
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora = lc.hora
                       AND c.fecha = lc.fecha
                       AND c.cod_usuario = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda = mo.cod_moneda) cod_mon_destino,

                   (SELECT lc.cotizacion
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora = lc.hora
                       AND c.fecha = lc.fecha
                       AND c.cod_usuario = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda = mo.cod_moneda) cot_mon_destino,

                   NULL nom_ent_externa,
                   NULL nro_cta_ent_externa,
                   NULL cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL cod_pais_bco_intermediario,
                   NULL nom_bco_intermediario,
                   NULL cod_aba_banco,
                   NULL cod_swi_banco,
                   NULL cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.COD_MOD_PADRE  = TH.COD_MODULO
                                                AND C.COD_MAD_PADRE = TH.COD_MODALIDAD
                                                AND C.COD_TRA_PADRE = TH.COD_TRANSACCION
                                                
              JOIN LC_TIP_OPERACIONES LC ON C.COD_MODULO       = LC.COD_MODULO
                                         AND C.COD_MODALIDAD   = LC.COD_MODALIDAD
                                         AND C.COD_TRANSACCION = LC.COD_TRANSACCION

             WHERE C.COD_MOD_PADRE      = 7
               AND C.COD_MAD_PADRE IN (71, 72, 73, 74)
               AND LC.COD_TIP_OPERACION NOT IN (1,2,3,4,5,6,7,8,9)
               AND C.ESTADO             = 'N'
               --Comentamos el original para probar la versión del cliente INT_Banco
               --AND ((c.cod_mad_padre IN (73, 74) AND c.cod_modalidad = 72) OR c.cod_mad_padre IN (71, 72) AND c.cod_tip_ope_cambio is not null) 
               ------------
               -- Esta parte lo quitamos del Query del Cliente
               AND ((C.COD_MAD_PADRE IN (71, 72) AND C.NRO_SECUENCIA = 1) OR
                    (C.COD_MAD_PADRE IN (73, 74) AND C.NRO_SECUENCIA IN (1, 2)))

               ------------
               --AND C.COD_TRANSACCION NOT IN (188, 277, 942, 901, 760) -- Comentamos el original
               AND NOT EXISTS (SELECT 1 FROM LC_TRANSFERENCIAS CX
                                         WHERE C.COD_MOD_PADRE = CX.COD_MODULO
                                           AND C.FECHA         = CX.FEC_OPERACION
                                           AND C.NRO_DOCUMENTO = CX.NRO_OPERACION)
              AND C.REVERSADO       <> 'S'
              AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 10/12
|| InstrumentoSEPRELAD: EXTCHEQ
|| LD_INT_TRANSACCIONES: Transacciones Padres.
*/

  union all

  SELECT 'C' iden,
         'J' region,
         c.fecha,
         c.cod_usuario,
         c.hora,
         c.nro_secuencia,
         c.cod_transaccion,
         (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
            FROM ge_transacciones gt
           WHERE gt.cod_transaccion = c.cod_transaccion
             AND gt.cod_modulo = c.cod_modulo
             AND gt.cod_modalidad = c.cod_modalidad) tipo,
         c.nro_cuenta,
         pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
         to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
         c.cod_modulo,
         c.cod_modalidad,
         c.cod_moneda,
         c.cod_ofi_origen,
         c.nro_caja,
         c.estado,
         c.reversado,
         c.cod_usu_reversion,
         nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,c.FECHA)) cotizacion,
         c.cod_tra_padre,
         c.cod_mod_padre,
         c.cod_mad_padre,
         (SELECT cc.cod_persona
            FROM lv_cta_clientes cc
           WHERE cc.nro_cuenta = c.nro_cuenta
             AND cc.relacion = 'P'
             AND rownum = 1) cod_persona,
         c.cod_oficina,
         decode(c.nro_caja, NULL,
                decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                        386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                decode(c.cod_transaccion, 607, 'O', 'E')) tip_monto,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL ciudad_solicitante,
         NULL pais_solicitante,
         NULL ciu_beneficiario,
         NULL nombre_beneficiario,
         NULL dir_beneficiario,
         NULL cod_pai_beneficiario,
         NULL cod_tip_doc_beneficiario,
         NULL nro_doc_beneficiario,
         ge.cod_operacion,
         NULL,
         NULL,
         c.mto_equ_local,
         c.monto mto_mon_origen,
         NULL cod_mon_destino,
         NULL cot_mon_destino,
         NULL nom_ent_externa,
         NULL nro_cta_ent_externa,
         NULL cod_pai_ent_externa,
         NULL nom_ciu_ent_externa,
         c.NRO_DOCUMENTO nro_cheque,
         c.nro_documento,
         fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
         NULL observacion,
         NULL cod_pais_bco_intermediario,
         NULL nom_bco_intermediario,
         NULL cod_aba_banco,
         NULL cod_swi_banco,
         NULL cod_bco_corresponsal,
         th.ins_seprelad,
         NULL CTA_DESTINO,

         CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
           ELSE NULL END CDA,

         'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
         'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

    FROM GV_MOVIMIENTOS C
    JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                 AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                 AND C.COD_TRANSACCION = GE.COD_TRANSACCION

    LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                      AND C.cod_mad_padre = TH.cod_modalidad
                                      AND C.cod_tra_padre = TH.cod_transaccion

    WHERE C.MONTO > 0
     AND C.COD_TRA_PADRE IN (354)
     AND C.ESTADO = 'N'
     AND C.REVERSADO       <> 'S'
     AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

/*
|| SELECT 11/12
|| InstrumentoSEPRELAD: TRAEXTERM, TRAEXTREC
|| LD_INT_TRANSACCIONES: Transacciones Padres.
*/
   union all
               SELECT 'H' iden,
                   'K' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.COD_OFICINA cod_ofi_origen, --ex.cod_oficina cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,
                   fug_obt_cli_principal(c.nro_cuenta) cod_persona,
                   c.COD_OFICINA cod_oficina, --ex.cod_oficina,
                   'N' tip_monto,
                   null cod_per_solicitante, --ex.cod_per_solicitante,
                   null cod_per_beneficiario, --ex.cod_per_beneficiario,
                   null nombre_solicitante, --ex.nom_solicitante nombre_solicitante,
                   null dir_solicitante, --ex.dir_solicitante dir_solicitante,
                   NULL ciudad_solicitante,
                   NULL pais_solicitante,
                   NULL ciu_beneficiario,
                   null nombre_beneficiario, --ex.nom_beneficiario nombre_beneficiario,
                   null dir_beneficiario, --ex.dir_beneficiario dir_beneficiario,
                   NULL cod_pai_beneficiario,

                   /*
                   CASE
                      WHEN cod_per_beneficiario IS NULL THEN
                       ex.cod_tip_doc_beneficiario
                      ELSE
                       NULL
                   END cod_tip_doc_beneficiario,
                   */
                   null cod_tip_doc_beneficiario,
                   /*
                   CASE
                      WHEN cod_per_beneficiario IS NULL THEN
                       ex.nro_doc_beneficiario
                      ELSE
                       NULL
                   END nro_doc_beneficiario,
                   */
                   null nro_doc_beneficiario,
                   ge.cod_operacion,

                   /*
                   CASE
                      WHEN cod_per_solicitante IS NULL THEN
                       ex.cod_tip_doc_solicitante
                      ELSE
                       NULL
                   END cod_tip_doc_solicitante,
                   */
                   null cod_tip_doc_solicitante,
                   /*
                   CASE
                      WHEN cod_per_solicitante IS NULL THEN
                       ex.nro_doc_solicitante
                      ELSE
                       NULL
                   END nro_doc_solicitante,*/
                   null nro_doc_solicitante,

                   -----
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   NULL cod_mon_destino,
                   NULL cot_mon_destino,
                   substr(CX.NOM_BANCO, 1, 30) nom_ent_externa, --NULL nom_ent_externa,
                   null nro_cta_ent_externa, --ex.nro_cta_pte_beneficiario nro_cta_ent_externa,
                   p.cod_pai_iso cod_pai_ent_externa, --NULL cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   NULL observacion,
                   NULL                        cod_pais_bco_intermediario,
                   NULL                        nom_bco_intermediario,
                   NULL                        cod_aba_banco,
                   null cod_swi_banco, --ex.cod_swi_pte_beneficiario cod_swi_banco,
                   NULL                        cod_bco_corresponsal,
                   th.ins_seprelad,
                   NULL CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              LEFT JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                                AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                                AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

              LEFT JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                                             AND C.MONTO         = CX.MONTO
                                             AND C.COD_MONEDA    = CX.COD_MONEDA
                                             AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

              LEFT JOIN BA_PAISES P ON CX.COD_PAI_BANCO = P.COD_PAIS

             WHERE C.COD_TRA_PADRE   in (800, 803)
               AND C.COD_MOD_PADRE   = 4
               AND C.COD_MAD_PADRE   = 41
               AND c.estado          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta
               
/*
|| SELECT 12/12
|| InstrumentoSEPRELAD: DEPEFEC
|| CC_CTA_CORRIENTES: Maestro de Cuentas Corrientes.
|| Similar a la region E pero en vez de usar la vista LV_CTA_AHORROS usamos LV_CTA_CORRIENTES
*/
            UNION ALL
            SELECT 'A' iden,
                   'L' region,
                   c.fecha,
                   c.cod_usuario,
                   c.hora,
                   c.nro_secuencia,
                   c.cod_transaccion,
                   (SELECT decode(c.cod_transaccion, 515, 'C', 560, 'C', tipo)
                      FROM ge_transacciones gt
                     WHERE gt.cod_transaccion = c.cod_transaccion
                       AND gt.cod_modulo = c.cod_modulo
                       AND gt.cod_modalidad = c.cod_modalidad) tipo,
                   c.nro_cuenta,
                   pag_gen.fu_con_mon_a_moneda(c.cod_moneda, p_mon_fuerte, c.monto,null, c.fecha, null) monto,
                   to_number(nvl(fue_tab_dat_adicional('BA_USUARIOS', 'COD_CANAL', c.cod_usuario), 2)) tip_canal,
                   c.cod_modulo,
                   c.cod_modalidad,
                   c.cod_moneda,
                   c.cod_ofi_origen,
                   c.nro_caja,
                   c.estado,
                   c.reversado,
                   c.cod_usu_reversion,
                   nvl(c.cotizacion,pag_gen.FU_OBT_COTIZACION(p_mon_fuerte,c.FECHA)) cotizacion,
                   c.cod_tra_padre,
                   c.cod_mod_padre,
                   c.cod_mad_padre,

                   (SELECT cc.cod_persona FROM lv_cta_clientes cc
                                          WHERE cc.nro_cuenta = c.nro_cuenta
                                          AND cc.relacion = 'P'
                                          AND rownum = 1) cod_persona,

                   c.cod_oficina,

                   decode(c.nro_caja, NULL,
                          decode(c.cod_transaccion, 840, 'E', 740, 'E', 250, 'E', 261, 'E', 352, 'O',
                                  386, 'O', 452, 'O', 553, 'O', 607, 'O', 614, 'O', 632, 'O', 'N'),
                          decode(c.cod_transaccion, 607, 'O', 'E')) tip_monto,

                   NULL,
                   NULL,
                   --CX.NOM_SOLICITANTE                                           nombre_solicitante,
                   
                   -- Agregamos de esta forma porque había casos de CANVENT que figuraban es esta región
                   NVL(CX.NOM_SOLICITANTE ,decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nom_completo
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nom_completo
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1))))) nombre_solicitante,
                   
                   cx.dir_solicitante                                           dir_solicitante,
                   cx.cod_ciu_solicitante                                       ciudad_solicitante,
                   cx.cod_pai_solicitante                                       pais_solicitante,
                   cx.cod_ciu_beneficiario                                      ciu_beneficiario,
                   NVL(cx.nom_beneficiario, fue_obt_nom_persona(PV.COD_PERSONA)) nombre_beneficiario,
                   cx.dir_beneficiario                                          dir_beneficiario,
                   cx.cod_pai_beneficiario                                      cod_pai_beneficiario,
                   /*cx.cod_tip_doc_beneficiario*/NULL                          cod_tip_doc_beneficiario,
                   fue_obt_nro_doc_persona(fug_obt_cli_principal(c.NRO_CUENTA)) nro_doc_beneficiario,
                   ge.cod_operacion                                             cod_operacion,
                   /*decode(cx.cod_per_solicitante, NULL, cx.cod_tip_doc_solicitante, NULL)*/NULL cod_tip_doc_solicitante,
                   --decode(cx.cod_per_solicitante, NULL, cx.nro_doc_solicitante, NULL)     nro_doc_solicitante,
                   
                     NVL(/*cx.nro_doc_solicitante*/NULL,
                        decode(c.cod_persona, NULL,
                          nvl((SELECT b.referencia
                                 FROM GV_MOVIMIENTOS b
                                WHERE fecha = c.fecha
                                  AND hora = c.hora
                                  AND cod_usuario = c.cod_usuario
                                  AND referencia IS NOT NULL
                                  AND rownum = 1),
                               (SELECT nro_documento
                                   FROM ba_personas
                                  WHERE cod_persona = nvl(c.cod_persona,
                                                          (SELECT b.nro_documento2
                                                              FROM GV_MOVIMIENTOS b
                                                             WHERE fecha = c.fecha
                                                               AND hora = c.hora
                                                               AND cod_usuario = c.cod_usuario
                                                               AND cod_modalidad = 70
                                                               AND b.nro_documento2 IS NOT NULL
                                                               AND rownum = 1)))),
                          (SELECT nro_documento
                              FROM ba_personas
                             WHERE cod_persona = nvl(c.cod_persona,
                                                     (SELECT b.nro_documento2
                                                         FROM GV_MOVIMIENTOS b
                                                        WHERE fecha = c.fecha
                                                          AND hora = c.hora
                                                          AND cod_usuario = c.cod_usuario
                                                          AND cod_modalidad = 70
                                                          AND b.nro_documento2 IS NOT NULL
                                                          AND rownum = 1))))) nro_doc_solicitante,
                   
                   
                   c.mto_equ_local,
                   c.monto mto_mon_origen,
                   --NULL cod_mon_destino,
                   
                   (SELECT mo.cod_moneda
                      FROM GV_MOVIMIENTOS lc, ba_monedas mo
                     WHERE c.hora           = lc.hora
                       AND c.fecha          = lc.fecha
                       AND c.cod_usuario    = lc.cod_usuario
                       AND lc.nro_secuencia = 1
                       AND lc.cod_moneda    = mo.cod_moneda) cod_mon_destino,
                   
                   NULL cot_mon_destino,
                   NVL(substr(CX.NOM_BANCO, 1, 30), substr(fug_obt_des_banco(cx.cod_bco_corresponsal),1,30)) nom_ent_externa,
                   NVL(cx.nro_cta_referencia,0) nro_cta_ent_externa, --Actualmente en ITGF NO guardan el 'nro_cta_ent_externa' para casos de TRAEXTREC
                   p.cod_pai_iso cod_pai_ent_externa,
                   NULL nom_ciu_ent_externa,
                   NULL nro_cheque,
                   c.nro_documento,
                   fug_obt_des_transaccion(c.cod_modulo, c.cod_modalidad, c.cod_transaccion) motivo,
                   substr(cx.observacion, 1, 30) observacion,
                   NULL cod_pais_bco_intermediario,
                   NULL nom_bco_intermediario,
                   cx.cod_aba_banco cod_aba_banco,
                   cx.cod_swi_banco,
                   fug_obt_des_banco(cx.cod_bco_corresponsal) cod_bco_corresponsal, --cx.cod_bco_corresponsal cod_bco_corresponsal,
                   th.ins_seprelad,
                                                 
                  (SELECT DISTINCT LM.NRO_CUENTA FROM GV_MOVIMIENTOS LM
                                                 WHERE LM.FECHA            = C.FECHA
                                                 AND LM.HORA               = C.HORA
                                                 AND LM.COD_USUARIO        = C.COD_USUARIO
                                                 --AND LM.COD_TRA_PADRE      IN (388, 309)
                                                 --AND LM.COD_TRANSACCION    in (602)
                                                 --AND LM.COD_TIP_MOVIMIENTO = 'C'
                                                 and lm.NRO_SECUENCIA in (select max(nro_secuencia) from gv_movimientos h
                                                                                                     where h.FECHA           = lm.FECHA
                                                                                                     and h.HORA              = lm.hora
                                                                                                     and h.COD_USUARIO       = lm.COD_USUARIO
                                                                                                     AND h.COD_TRA_PADRE     IN (388, 309)
                                                                                                     AND h.COD_TRANSACCION   in (602)
                                                                                                     AND h.COD_TIP_MOVIMIENTO = 'C')) CTA_DESTINO,

                   CASE WHEN C.COD_TRA_PADRE = 309 AND C.COD_TRANSACCION = 602 AND C.COD_MODALIDAD = 33 THEN 1
                     ELSE NULL END CDA,

                   'COD_MODULO: ' || C.cod_modulo || ' - COD_MODALIDAD: ' || c.cod_modalidad ||' - COD_TRANSACCION: ' || c.cod_transaccion || '(' || ge.descripcion || ')' DES_TRA_HIJA,
                   'COD_MOD_PADRE: ' || C.cod_mod_padre || ' - COD_MAD_PADRE: ' || c.cod_mad_padre || ' - COD_TRA_PADRE: ' || c.Cod_Tra_Padre || '(' || th.descripcion || ')'  DES_TRA_MADRE

              FROM GV_MOVIMIENTOS C
              JOIN LV_CTA_CORRIENTES PV ON C.NRO_CUENTA = PV.NRO_CUENTA

              JOIN LD_INT_TRANSACCIONES GE ON C.COD_MODULO       = GE.COD_MODULO
                                           AND C.COD_MODALIDAD   = GE.COD_MODALIDAD
                                           AND C.COD_TRANSACCION = GE.COD_TRANSACCION

              LEFT JOIN LD_INT_TRANSACCIONES TH ON C.cod_mod_padre  = TH.cod_modulo
                                                AND C.cod_mad_padre = TH.cod_modalidad
                                                AND C.cod_tra_padre = TH.cod_transaccion

              LEFT JOIN LC_TRANSFERENCIAS CX ON C.COD_MOD_PADRE  = CX.COD_MODULO
                                             AND C.FECHA         = CX.FEC_OPERACION
                                             AND C.NRO_DOCUMENTO = CX.NRO_OPERACION

              LEFT JOIN BA_PAISES P ON CX.COD_PAI_BANCO = P.COD_PAIS

             WHERE C.MONTO           > 0
               AND C.COD_TRANSACCION IS NOT NULL
               AND C.COD_TRA_PADRE NOT IN (358, 360, 359, 362, /*309,*/ 297, 303, 264, 901)
               AND C.COD_MOD_PADRE NOT IN (5, 6)
               AND C.ESTADO          = 'N'
               AND C.REVERSADO       <> 'S'
               AND C.FECHA BETWEEN v_fec_desde AND v_fec_hasta

               ;
         COMMIT;
      END;
   BEGIN
      /*Cargamos primeramente la tabla temporal, (previamente a la carga esta sera truncada)*/
       lp_ins_movimientos_tmp(v_fec_desde, v_mon_fuerte);
      /*Cargo el cursor de movimiento en la tabla ld_int_movimientos*/
      FOR m IN c_mov LOOP
         v_exi_mov := 'N';
         /*IF m.cod_persona IS NOT NULL THEN
            pr_ins_personas(rtrim(ltrim(m.cod_persona)), NULL, NULL);
         END IF;
         IF m.nro_doc_solicitante IS NOT NULL THEN
            pr_ins_personas(NULL, m.nro_doc_solicitante, NULL);
         END IF;
         IF m.nro_doc_beneficiario IS NOT NULL THEN
            pr_ins_personas(NULL, NULL, m.nro_doc_beneficiario);
         END IF;*/
         IF m.tip_movimiento = 'T' THEN
            IF m.cod_ofi_origen IS NOT NULL THEN
               SELECT ba.cod_ciudad, ba.cod_pais
                 INTO v_cod_ciu_origen, v_cod_pai_origen
                 FROM ba_oficinas ba
                WHERE ba.cod_oficina = m.cod_ofi_origen;
            ELSE
               v_cod_pai_origen := m.cod_pai_solicitante;
               v_cod_ciu_origen := m.cod_ciu_solicitante;
            END IF;

            IF m.cod_ofi_destino IS NOT NULL THEN
               IF m.cod_ofi_origen = m.cod_ofi_destino THEN
                  v_cod_pai_destino := m.cod_pai_beneficiario;
                  v_cod_ciu_destino := m.cod_ciu_beneficiario;
               ELSE
                  SELECT ba.cod_ciudad, ba.cod_pais
                    INTO v_cod_ciu_destino, v_cod_pai_destino
                    FROM ba_oficinas ba
                   WHERE ba.cod_oficina = m.cod_ofi_destino;
               END IF;
            ELSE
               v_cod_pai_destino := m.cod_pai_beneficiario;
               v_cod_ciu_destino := m.cod_ciu_beneficiario;
            END IF;
         END IF;

         IF nvl(v_exi_mov, 'N') = 'N' THEN
            BEGIN
               INSERT INTO ld_int_movimientos
                  (region,fecha, hora, nro_secuencia, cod_usuario, cod_transaccion, tipo, nro_cuenta,
                   monto, cod_canal, cod_pai_beneficiario, fec_generacion, fec_proceso,
                   est_informacion, cod_modulo, cod_modalidad, cod_moneda, cod_ofi_origen, nro_caja,
                   estado, reversado, cod_usu_reversion, cotizacion, cod_tra_padre, cod_mod_padre,
                   cod_mad_padre, cod_per_solicitante, cod_per_beneficiario, cod_persona, tip_monto,
                   cod_tip_doc_solicitante, nro_doc_solicitante, cod_pai_solicitante,
                   cod_ciu_solicitante, cod_ciu_beneficiario, cod_operacion,
                   cod_tip_doc_beneficiario, nro_doc_beneficiario, mto_equ_local, mto_mon_origen,
                   cod_mon_destino, cot_mon_destino, nom_ent_externa, nro_cta_ent_externa,
                   cod_pai_ent_externa, nom_ciu_ent_externa, nro_cheque, nro_boleta, motivo,
                   observacion, cod_pai_bco_intermediario, nom_bco_intermediario,
                   cod_aba_bco_intermediario, cod_swi_bco_intermediario, nom_corresponsal,
                   nombre_solicitante,
                   nombre_beneficiario,
                   INS_SEPRELAD,
                   CTA_DESTINO,
                   CDA,
                   DES_TRA_HIJA,
                   DES_TRA_MADRE,
                   COD_MON_ORIGINAL)
               VALUES
                  (m.region,m.fecha, m.hora, m.nro_secuencia, m.cod_usuario, m.cod_transaccion, m.tipo,
                   m.nro_cuenta, m.monto, m.cod_canal, v_cod_pai_destino, trunc(SYSDATE), SYSDATE,
                   'A', m.cod_modulo, m.cod_modalidad, v_mon_fuerte, m.cod_ofi_origen, m.nro_caja,
                   m.estado, m.reversado, m.cod_usu_reversion, m.cotizacion, m.cod_tra_padre,
                   m.cod_mod_padre, m.cod_mad_padre, m.cod_per_solicitante, m.cod_per_beneficiario,
                   rtrim(ltrim(m.cod_persona)), nvl(m.tip_monto,'N'), m.cod_tip_doc_solicitante,
                   m.nro_doc_solicitante, v_cod_pai_origen, v_cod_ciu_origen, v_cod_ciu_destino,
                   m.cod_operacion, m.cod_tip_doc_beneficiario, m.nro_doc_beneficiario,
                   m.mto_equ_local, m.mto_mon_origen, m.cod_mon_destino, m.cot_mon_destino,
                   m.nom_ent_externa, m.nro_cta_ent_externa, m.cod_pai_ent_externa,
                   m.nom_ciu_ent_externa, m.nro_cheque, m.nro_boleta, m.motivo, m.observacion,
                   m.cod_pai_bco_intermediario, m.nom_bco_intermediario, m.cod_aba_bco_intermediario,
                   m.cod_swi_bco_intermediario, m.nom_corresponsal,
                   m.nombre_solicitante,
                   m.nombre_beneficiario,
                   m.ins_seprelad,
                   m.CTA_DESTINO,
                   m.CDA,
                   m.DES_TRA_HIJA,
                   m.DES_TRA_MADRE,
                   m.cod_moneda);
              COMMIT;
            EXCEPTION
               WHEN OTHERS THEN
                  IF p_proceso = 'A' THEN
                     raise_application_error(-20013,
                                             'Error al insertar en LD_INT_MOVIMIENTOS. ' || SQLERRM);
                  END IF;
            END;
         END IF;
         v_exi_cli_ben     := NULL;
         v_exi_mov         := NULL;
         v_cod_pai_destino := NULL;
         v_cod_pai_origen  := NULL;
         v_cod_ciu_origen  := NULL;
         v_cod_ciu_destino := NULL;
         v_exi_cli_lav     := NULL;
      END LOOP;
   END PRG_GEN_MOV_SGR;
/
