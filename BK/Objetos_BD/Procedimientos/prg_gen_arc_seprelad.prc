create or replace procedure it.prg_gen_arc_seprelad(p_fec_ini in date, p_fec_fin in date) is
/**Generación Datos para Informe SEPRELAD - SDCIRSEP04-1 - Circular 04-2019 Seprelad - Etapa 1**/

  v_fecha                     date :=      pag_cal.fu_obt_fec_actual(1);
  v_fec_ini                   date;
  v_fec_fin                   date;
  v_mto_cambios               ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('MTO_INF_SEPRELAD');
  v_cod_swift ge_bancos.cod_swift%type;

  PROCEDURE lp_ins_datos IS
  BEGIN

  ---Insertar Datos Depositos Efectivo
  insert into ge_sep_depositos (nro_orden,
                                cod_oficina,
                                fec_operacion,
                                nro_comprobante,
                                nom_completo,
                                nro_documento,
                                cod_moneda,
                                monto,
                                nro_cuenta,
                                tip_doc_depositante,
                                nro_doc_depositante,
                                nom_beneficiario,
                                tip_doc_beneficiario,
                                cod_instrumento,
                                cotizacion,
                                sal_cuenta,
                                tip_persona,
                                cod_tra_padre,
                                cod_mod_padre,
                                cod_mad_padre,
                                cod_transaccion,
                                cod_modulo,
                                cod_modalidad)

    select rownum item,
           a.COD_OFICINA,
           a.FECHA,
           a.NRO_DOCUMENTO,
           translate(a.RAZON_SOCIAL,
                  'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                  'AEIOUYAEIOUAEIOUNN') RAZON_SOCIAL,
           a.NRO_DOC_BENEFICIARIO,
           a.moneda,
           a.monto,
           a.NRO_CUENTA,
           a.tip_doc_depositante,
           a.doc_depositante,
           translate(a.nombre_benef,
                  'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                  'AEIOUYAEIOUAEIOUNN') nombre_benef,
           a.tip_doc_ben,
           a.cod_instrumento,
           a.COTIZACION,
           a.saldoCtann,
           a.tip_persona,
           a.cod_tra_padre,
           a.cod_mod_padre,
           a.cod_mad_padre,
           a.cod_transaccion,
           a.cod_modulo,
           a.cod_modalidad

         from (
    SELECT c.COD_OFICINA,
           c.FECHA,
           c.NRO_DOCUMENTO,
           p.nom_completo RAZON_SOCIAL,
           P.NRO_DOCUMENTO nro_doc_beneficiario,
           pas_tra.fu_obt_mon_iso(c.COD_MONEDA) moneda,
           C.MONTO monto,
           c.NRO_CUENTA,
           '' tip_doc_depositante,
           '' doc_depositante,
           P.NOM_COMPLETO nombre_benef,
           fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_doc_ben,
           'DEPEFEC' cod_instrumento,
           decode(c.COD_MONEDA, 'GS', 1, fug_obt_cotizacion(c.cod_moneda, c.fecha)) cotizacion,
           c.MONTO saldoCtann,
           p.tipo tip_persona,
           c.cod_tra_padre,
           c.cod_mod_padre,
           c.cod_mad_padre,
           c.cod_transaccion,
           c.cod_modulo,
           c.cod_modalidad
      from ah_movimientos_his c,
           GE_CTA_CLIENTES CL,
           BA_PERSONAS P,
           ge_sep_transacciones sep,
           ge_transacciones t
     where (C.FECHA >= v_fec_ini AND C.FECHA <= v_fec_FIN)
       AND t.tipo = 'C'
       and sep.ref_archivo = 'DEPEFEC'
       and sep.ref_dat_reportar = 'DEPOSITO_EFE'
       and sep.cod_mod_padre = c.cod_mod_padre
       and sep.cod_mad_padre = c.cod_mad_padre
       and sep.cod_tra_padre = c.cod_tra_padre
       and sep.cod_modulo = c.cod_modulo
       and sep.cod_modalidad = c.cod_modalidad
       and sep.cod_transaccion = c.cod_transaccion
       AND (TO_NUMBER(DECODE(c.COD_MONEDA,
                             'GS', c.monto/fug_obt_cotizacion('USD', c.FECHA),
                             'USD', c.monto/1,
                             c.MTO_EQU_LOCAL/fug_obt_cotizacion('USD', c.FECHA)))) >= sep.mto_reportar
       and c.cod_modulo = t.cod_modulo
       and c.cod_modalidad = t.cod_modalidad
       and c.Cod_Transaccion = t.cod_transaccion
       AND c.ESTADO = 'N'
       AND c.REVERSADO = 'N'
       AND C.NRO_CUENTA = CL.NRO_CUENTA
       AND CL.COD_PERSONA = P.COD_PERSONA
       and cl.relacion = 'P'
       and cl.cod_modulo = 3
       and cl.cod_modalidad = 31
    union all
    SELECT c.COD_OFICINA,
           c.FECHA,
           c.NRO_DOCUMENTO,
           p.nom_completo rAZON_SOCIAL,
           P.NRO_DOCUMENTO nro_doc_beneficiario, --PROPIETARIO DE LA CUENTA
           pas_tra.fu_obt_mon_iso(c.COD_MONEDA) moneda,
           C.MONTO monto,
           c.NRO_CUENTA,
           '' tip_doc_depositante,
           '' doc_depositante,
           P.NOM_COMPLETO nombre_benef,
           fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_doc_ben,
           'DEPEFEC' cod_instrumento,
           decode(c.COD_MONEDA, 'GS', 1, fug_obt_cotizacion(c.cod_moneda, c.fecha)) cotizacion,
           c.MONTO saldoCta,
           p.tipo tip_persona,
           c.cod_tra_padre,
           c.cod_mod_padre,
           c.cod_mad_padre,
           c.cod_transaccion,
           c.cod_modulo,
           c.cod_modalidad
      from cc_movimientos_his c,
           ge_sep_transacciones sep,
           GE_CTA_CLIENTES CL,
           BA_PERSONAS P,
           ge_transacciones t
     where (C.FECHA >= v_fec_ini AND C.FECHA <= v_fec_FIN)
       AND t.tipo = 'C'
       and sep.ref_archivo = 'DEPEFEC'
       and sep.ref_dat_reportar = 'DEPOSITO_EFE'
       and sep.cod_mod_padre = c.cod_mod_padre
       and sep.cod_mad_padre = c.cod_mad_padre
       and sep.cod_tra_padre = c.cod_tra_padre
       and sep.cod_modulo = c.cod_modulo
       and sep.cod_modalidad = c.cod_modalidad
       and sep.cod_transaccion = c.cod_transaccion
       AND (TO_NUMBER(DECODE(c.COD_MONEDA,
                             'GS', c.monto/fug_obt_cotizacion('USD', c.FECHA),
                             'USD', c.monto/1,
                             c.MTO_EQU_LOCAL/fug_obt_cotizacion('USD', c.FECHA)))) >= sep.mto_reportar

       and c.cod_modulo = t.cod_modulo
       and c.cod_modalidad = t.cod_modalidad
       and c.Cod_Transaccion = t.cod_transaccion
       AND c.ESTADO = 'N'
       AND c.REVERSADO = 'N'
       AND C.NRO_CUENTA = CL.NRO_CUENTA
       AND CL.COD_PERSONA = P.COD_PERSONA
       and cl.relacion = 'P') a;


--Transacciones a considerar para: Extracciones en Efectivo

--Insertar Datos Extracciones EFECTIVO y DEBITO POR PAGOS DE CHEQUES NUESTRO BANCO
insert into ge_sep_extracciones
  (nro_orden,
   cod_oficina,
   fec_operacion,
   nro_comprobante,
   nom_completo,
   nro_documento,
   cod_moneda,
   monto,
   nro_cuenta,
   nro_doc_beneficiario,
   nom_beneficiario,
   tip_documento,
   tip_doc_beneficiario,
   cod_instrumento,
   cotizacion,
   sal_cuenta,
   tip_persona,
   cod_tra_padre,
   cod_mod_padre,
   cod_mad_padre,
   cod_transaccion,
   cod_modulo,
   cod_modalidad)
  select rownum item, a.*
    from (SELECT x.COD_OFICINA                               sucursal,
                 x.FECHA                                     fechaoperacion,
                 x.NRO_DOCUMENTO                             NumeroComprobante,
                 translate(ba.nom_completo,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN')             NombreRazonSocial,
                 ba.nro_documento                            NumeroDocumento,
                 pas_tra.fu_obt_mon_iso(x.COD_MONEDA)        Moneda,
                 x.monto                                     Monto,
                 x.NRO_CUENTA,
                 ''                                           nro_doc_beneficiario,
                 ''                                           nombre_benef,
                 fue_obt_tip_doc_abreviatura(ba.cod_tip_documento),
                 ''                                           tipodocumentoben,
                 'EXTEFEC'                                    codInstrumento,
                 x.cotizacion                                 COTIZACION,
                 0                                            saldo_cta_beneficiario,
                 ba.tipo                                      tip_persona,
                 x.cod_tra_padre                              cod_tra_padre,
                 x.cod_mod_padre                              cod_mod_padre,
                 x.cod_mad_padre                              cod_mad_padre,
                 x.cod_transaccion                            cod_transaccion,
                 x.cod_modulo                                 cod_modulo,
                 x.cod_modalidad                              cod_modalidad
            from ( --Extracciones AH_Cta_Vistas
                  select A.fecha,
                          cod_oficina,
                          A.cod_moneda,
                          nro_cuenta,
                          a.monto,
                          A.MTO_EQU_LOCAL,
                          nro_documento,
                          cod_persona,
                          estado,
                          decode(a.COD_MONEDA, 'GS', 1, fug_obt_cotizacion(a.cod_moneda, a.fecha)) COTIZACION,
                          0 saldo_cta_beneficiario,
                          a.cod_tra_padre,
                          a.cod_mod_padre,
                          a.cod_mad_padre,
                          a.cod_transaccion,
                          a.cod_modulo,
                          a.cod_modalidad
                    from ah_movimientos_his a, ge_sep_transacciones sep
                   where sep.ref_archivo = 'EXTEFEC'
                     and sep.ref_dat_reportar = 'EXTRACCION_EFE'
                     and sep.cod_mod_padre = a.cod_mod_padre
                     and sep.cod_mad_padre = a.cod_mad_padre
                     and sep.cod_tra_padre = a.cod_tra_padre
                     and sep.cod_modulo = a.cod_modulo
                     and sep.cod_modalidad = a.cod_modalidad
                     and sep.cod_transaccion = a.cod_transaccion
                     AND (TO_NUMBER(DECODE(a.COD_MONEDA,
                                           'GS', a.monto/fug_obt_cotizacion('USD', a.FECHA),
                                           'USD', a.monto/1,
                                           a.MTO_EQU_LOCAL/fug_obt_cotizacion('USD', a.FECHA)))) >= sep.mto_reportar
                     and a.reversado = 'N'
                     and A.FECHA >= v_fec_ini
                     AND A.FECHA <= v_fec_FIN
                     and a.estado = 'N'
                  union all
                  --Extracciones Cta Cte
                  select ec.fecha,
                          ec.cod_oficina,
                          ec.cod_moneda,
                          ec.nro_cuenta,
                          ec.monto,
                          ec.MTO_EQU_LOCAL,
                          ec.nro_documento,
                          ec.cod_persona,
                          ec.estado,
                          decode (ec.cod_moneda, 'GS',1,fug_obt_cotizacion(ec.cod_moneda, ec.fecha)) cotizacion,
                          0 saldo_cta_beneficiario,
                          ec.cod_tra_padre,
                          ec.cod_mod_padre,
                          ec.cod_mad_padre,
                          ec.cod_transaccion,
                          ec.cod_modulo,
                          ec.cod_modalidad
                    from cc_movimientos_his ec, ge_sep_transacciones sep
                   where sep.ref_archivo = 'EXTEFEC'
                     and sep.ref_dat_reportar = 'EXTRACCION_EFE'
                     and sep.cod_mod_padre = ec.cod_mod_padre
                     and sep.cod_mad_padre = ec.cod_mad_padre
                     and sep.cod_tra_padre = ec.cod_tra_padre
                     and sep.cod_modulo = ec.cod_modulo
                     and sep.cod_modalidad = ec.cod_modalidad
                     and sep.cod_transaccion = ec.cod_transaccion
                     AND (TO_NUMBER(DECODE(ec.COD_MONEDA,
                                             'GS', ec.monto/fug_obt_cotizacion('USD', ec.FECHA),
                                             'USD', ec.monto/1,
                                             ec.MTO_EQU_LOCAL/fug_obt_cotizacion('USD', ec.FECHA)))) >= sep.mto_reportar
                     and ec.FECHA >= v_fec_ini
                     AND ec.FECHA <= v_fec_FIN
                     and ec.reversado = 'N'
                     and ec.estado = 'N'
                  union all
                  ---Pago Cheques por Caja y Compensación
                  select mc.fecha,
                          mc.cod_oficina,
                          mc.cod_moneda,
                          mc.nro_cuenta,
                          mc.monto,
                          mc.MTO_EQU_LOCAL,
                          cp.nro_cheque,
                          mc.cod_persona,
                          mc.estado,
                          decode(mc.cod_moneda,'GS',1, fug_obt_cotizacion(mc.cod_moneda, mc.FECHA)) cotizacion,
                          0 saldo_cta_beneficiario,
                          mc.cod_tra_padre,
                          mc.cod_mod_padre,
                          mc.cod_mad_padre,
                          mc.cod_transaccion,
                          mc.cod_modulo,
                          mc.cod_modalidad
                    from cc_movimientos_his mc, cc_che_pagados cp, ge_sep_transacciones sep
                   where sep.ref_archivo = 'EXTEFEC'
                     and sep.ref_dat_reportar = 'PAGO_CHEQUE'
                     and sep.cod_mod_padre = mc.cod_mod_padre
                     and sep.cod_mad_padre = mc.cod_mad_padre
                     and sep.cod_tra_padre = mc.cod_tra_padre
                     and sep.cod_modulo = mc.cod_modulo
                     and sep.cod_modalidad = mc.cod_modalidad
                     and sep.cod_transaccion = mc.cod_transaccion
                     AND (TO_NUMBER(DECODE(mc.COD_MONEDA,
                                             'GS', mc.monto/fug_obt_cotizacion('USD', mc.FECHA),
                                             'USD', mc.monto/1,
                                             mc.MTO_EQU_LOCAL/fug_obt_cotizacion('USD', mc.FECHA)))) >= sep.mto_reportar

                     and mc.FECHA >= v_fec_ini
                     AND mc.FECHA <= v_fec_FIN
                     and mc.reversado = 'N'
                     and mc.estado = 'N'
                     and mc.nro_cuenta = cp.nro_cuenta
                     and mc.nro_documento = cp.nro_cheque
                     and mc.fecha = cp.fecha
                     and cp.cod_cau_devolucion is null) x,
                 ge_cta_clientes gcc,
                 ba_personas ba
           Where x.nro_cuenta = gcc.nro_cuenta
             and gcc.relacion = 'P'
             and gcc.cod_persona = ba.cod_persona) a;

  -- Transacciones a considerar para: Cambios (Compra, Venta, Canje y Arbitraje)

  INSERT INTO ge_sep_operaciones
    (nro_orden,
     fec_operacion,
     cod_oficina,
     nro_comprobante,
     cod_instrumento,
     nom_completo,
     nro_documento,
     cod_moneda,
     monto,--10
     cotizacion,
     mto_equ_gs,
     nro_doc_beneficiario,
     nom_beneficiario,
     nro_cuenta,
     tip_documento,
     tip_doc_beneficiario,
     nro_cheque,
     bco_emisor,
     sal_cuenta,--20
     tip_persona,
     cod_tra_padre,
     cod_mod_padre,
     cod_mad_padre,
     cod_transaccion,
     cod_modulo,
     cod_modalidad)--27
    SELECT rownum item, a.*
      FROM (-- Reporte Cambios Historico
            SELECT to_date(to_char(lv.fecha,'DD/MM/YYYY') || ' ' || lv.hora, 'DD/MM/YYYY HH24:MI:SS') fechaoperacion,
                   lv.cod_oficina                                               sucursal,
                   to_char(lv.nro_documento)                                    numeroComprobante,
                   DECODE(lv.cod_mad_padre,
                          71,
                          'CAMCOMP',
                          72,
                          'CAMVENT',
                          73,
                          DECODE(lv.nro_secuencia,1,'CAMARBITCO',2,'CAMARBITVE'),
                          74,
                          'CAMCANJ')                                            codInstrumento,
                   translate(cliente.nombre,
                             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                             'AEIOUYAEIOUAEIOUNN')                              nombreRazonSocial, -- 5
                   cliente.nro_doc_persona                                      numeroDocumento,
                   lv.cod_moneda                                                monedaOperacion,
                   lv.monto                                                     monto,
                   DECODE(lv.cod_moneda, 'GS', 1, lv.cotizacion)                cotizacion,
                   ROUND(lv.monto*DECODE(lv.cod_moneda, 'GS', 1, lv.cotizacion)) montoOperacionGs, -- 10
                   cliente.nro_doc_persona                                      numeroDocumentoBenficiario,
                   translate(cliente.nombre,
                             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                             'AEIOUYAEIOUAEIOUNN')                              nombreBeneficiario,

                   DECODE(lv.nro_cuenta,'','Cliente - operación caja',lv.nro_cuenta) numeroCuenta,
                   fue_obt_tip_doc_abreviatura(cliente.cod_tip_documento)       tipoDocumento,
                   fue_obt_tip_doc_abreviatura(cliente.cod_tip_documento)       tipodocumentoben, -- 15
                   ''                                                           numeroCheque, -- solo canje
                   ''                                                           bancoEmisor,
                   0                                                            saldo_cta_beneficiario,
                   cliente.tipo                                                 tip_persona,
                   lv.cod_tra_padre                                             cod_tra_padre, -- 20
                   lv.cod_mod_padre                                             cod_mod_padre,
                   lv.cod_mad_padre                                             cod_mad_padre,
                   lv.cod_transaccion                                           cod_transaccion,
                   lv.cod_modulo                                                cod_modulo,
                   lv.cod_modalidad                                             cod_modalidad -- 25
            --**--**--
              FROM ba_monedas,
                   lv_movimientos_his lv,
                   lc_tip_operaciones,
                   (select lc.nro_documento,
                           lc.nro_documento2 nro_doc,
                           lc.fecha,
                           lc.hora,
                           lc.cod_usuario,
                           ba_personas.nom_completo nombre,
                           ba_personas.cod_persona,
                           ba_personas.nro_documento nro_doc_persona,
                           ba_personas.cod_tip_documento,
                           ba_personas.tipo
                      from ba_personas, lv_movimientos_his lc
                     where nvl(lc.nro_documento2,lc.cod_persona) = ba_personas.cod_persona
                       and lc.cod_transaccion = 760
                       and lc.COD_MOD_PADRE = 7
                       and lc.reversado = 'N') cliente
             WHERE ba_monedas.cod_moneda = lv.cod_moneda
               AND (lv.nro_secuencia = 1 OR
                   (lv.nro_secuencia = 2 AND lv.cod_mad_padre IN (73, 77)))
               AND lv.monto IS NOT NULL
               AND lv.cotizacion IS NOT NULL
               AND lv.mto_equ_local IS NOT NULL
               and cliente.fecha(+) = lv.fecha
               and cliente.cod_usuario(+) = lv.cod_usuario
               and cliente.hora(+) = lv.hora
               AND lv.estado in ('N', 'H')
               AND lv.reversado = 'N'
               AND lv.cod_tip_ope_cambio = lc_tip_operaciones.cod_tip_operacion
               AND afe_posicion IN ('E', 'O')
               AND cod_mad_padre <> 74
               AND lv.cod_tip_ope_cambio NOT IN (78,79) -- 1752 rows
               AND lv.fecha >= v_fec_ini
               AND lv.fecha <= v_fec_fin
               AND (to_number(decode(lv.cod_moneda,
                                     'GS',
                                     lv.monto / fug_obt_cotizacion('USD', lv.fecha),
                                     'USD',
                                     lv.monto / 1,
                                     lv.mto_equ_local /
                                     fug_obt_cotizacion('USD', lv.fecha)))) >= v_mto_cambios
            UNION ALL
            -- Operaciones Futuras
            SELECT to_date(to_char(f.fec_operacion,'DD/MM/YYYY'), 'DD/MM/YYYY HH24:MI:SS') fechaoperacion,
                   f.cod_ofi_origen                                                        sucursal,
                   f.cod_tip_referencia || '/' || f.nro_referencia                         numeroComprobante,
                   'FORWARD'                                                               codInstrumento,
                   translate(p.nom_completo,
                             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                             'AEIOUYAEIOUAEIOUNN')                                         nombreRazonSocial, -- 5
                   p.nro_documento                                                         numeroDocumento,
                   f.cod_moneda                                                            monedaOperacion,
                   f.monto                                                                 monto,
                   f.cot_vencimiento                                                       cotizacion,
                   round(f.monto * f.cot_vencimiento)                                      montoOperacionGs, -- 10
                   p.nro_documento                                                         numeroDocumentoBenficiario,
                   translate(p.nom_completo,
                             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                             'AEIOUYAEIOUAEIOUNN')                                         nombreBeneficiario,
                   f.nro_cuenta                                                            numeroCuenta,
                   fue_obt_tip_doc_abreviatura(p.cod_tip_documento)                        tipoDocumento,
                   fue_obt_tip_doc_abreviatura(p.cod_tip_documento)                        tipodocumentoben, -- 15
                   ''                                                                      numeroCheque, -- solo canje
                   ''                                                                      bancoEmisor,
                   0                                                                       saldo_cta_beneficiario,
                   p.tipo                                                                  tip_persona,
                   761/*f.cod_tra_padre*/                                                  cod_tra_padre, -- 20
                   7/*f.cod_mod_padre*/                                                    cod_mod_padre,
                   f.cod_mad_padre                                                         cod_mad_padre,
                   761/*f.cod_transaccion*/                                                cod_transaccion,
                   f.cod_modulo                                                            cod_modulo,
                   f.cod_modalidad                                                         cod_modalidad -- 25
              FROM lc_ope_futuras     f,
                   ba_personas        p,
                   ba_cod_referencias r,
                   ge_modalidades     x
             WHERE f.cod_persona = p.cod_persona
               AND f.estado = r.val_minimo
               AND r.dominio = 'EST_OPE_FUTURA'
               AND x.cod_modulo = 7
               AND x.cod_modalidad = f.cod_mad_transaccion
               AND f.fec_operacion >= v_fec_ini
               AND f.fec_operacion <= v_fec_fin
               AND (TO_NUMBER(DECODE(f.COD_MONEDA,
                                     'GS',
                                     f.monto /
                                     fug_obt_cotizacion('USD', f.fec_operacion),
                                     'USD',
                                     f.MONTO / 1,
                                     round(f.monto * f.cot_vencimiento) /
                                     fug_obt_cotizacion('USD', f.fec_operacion)))) >= v_mto_cambios

             ORDER BY 1--lv.fecha, lv.hora
            ) a;

  --Inserta datos Transferencias SIPAP--
  INSERT INTO ge_sep_operaciones
  (nro_orden,
   fec_operacion,
   cod_oficina,
   nro_comprobante,
   cod_instrumento,
   nom_completo,
   nro_documento,
   cod_moneda,
   monto,
   cotizacion,
   mto_equ_gs,
   nro_doc_beneficiario,
   nom_beneficiario,
   nro_cuenta,
   tip_documento,
   tip_doc_beneficiario,
   swift,
   nro_cta_otr_entidad,
   swi_beneficiario,
   ciudad,
   motivo,
   pai_ent_internacional,
   ent_origen,
   ent_destino,
   cod_tra_padre,
   cod_mod_padre,
   cod_mad_padre,
   cod_transaccion,
   cod_modulo,
   cod_modalidad)
  SELECT rownum nroOrden, a.*
    FROM (select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRANACREC' codInstrumento, --TRANSFERENCIA NACIONAL RECIBIDA
                 UPPER(NVL(translate(t.nom_solicitante,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreRazonSocial,
                 nvl(t.nro_doc_solicitante, 111) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(t.cod_moneda) monedaOperacion,
                 t.monto monto,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(T.cod_moneda, T.fecha)
                   ELSE
                    1
                 END) cotizacion,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    Round((T.monto * fug_obt_cotizacion(T.cod_moneda, T.fecha)),fug_obt_redondeo_seg(T.COD_MONEDA))
                   ELSE
                    ((T.monto) * 1)
                 END) montoOperacionEnGs,
                 nvl(t.nro_doc_beneficiario, 111) numeroDocumentoBeneficiario,
                 UPPER(NVL(translate(t.nom_beneficiario,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreBeneficiario,
                 t.nro_cta_beneficiario numeroCuenta,
                 (CASE
                   WHEN T.COD_TIP_DOC_SOLICITANTE IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_SOLICITANTE)
                   WHEN T.COD_TIP_DOC_SOLICITANTE = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumento,
                 (CASE
                   WHEN T.COD_TIP_DOC_BENEFICIARIO IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_BENEFICIARIO)
                   WHEN T.COD_TIP_DOC_BENEFICIARIO = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumentoBen,
                 t.cod_swi_pte_solicitante Swift,
                 t.nro_cta_solicitante numeroCuentaOtraEntidad,
                 T.COD_SWI_PTE_BENEFICIARIO swiftBeneficiario,
                 fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                 REPLACE(t.observacion, '"', '') motivo,
                 'PRY' paisEntidadInternacional,
                 NVL(ba.cod_banco, ba.cod_ente) entidadOrigen,
                 fug_obt_cod_entidad entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from AH_MOVIMIENTOS_HIS    M,
                 GE_SNP_TRANSFERENCIAS T,
                 ba_oficinas           o,
                 GV_SNP_PARTICIPANTES  ba,
                 ge_sep_transacciones  sep,
                 ge_transacciones      te
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND te.tipo = 'C'
             and sep.ref_archivo = 'TRANACREC'
             and sep.ref_dat_reportar = 'TRA_NAC_RECIBIDA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
             AND (TO_NUMBER(DECODE(t.COD_MONEDA,
                         'GS',
                         t.monto / fug_obt_cotizacion('USD', m.fecha),
                         'USD',
                         t.monto / 1,
                         round(t.monto * fug_obt_cotizacion(t.cod_moneda, m.fecha)) /
                         fug_obt_cotizacion('USD', m.fecha)))) >=  sep.mto_reportar
             and m.cod_modulo = te.cod_modulo
             and m.cod_modalidad = te.cod_modalidad
             and m.Cod_Transaccion = te.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.NRO_DOCUMENTO = T.NRO_REFERENCIA
             AND M.COD_OFICINA = O.COD_OFICINA
             AND T.COD_SWI_PTE_SOLICITANTE = BA.COD_SWIFT
          UNION ALL
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRANACREC' codInstrumento, --TRANSFERENCIA NACIONAL RECIBIDA
                 UPPER(NVL(translate(t.nom_solicitante,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreRazonSocial,
                 nvl(t.nro_doc_solicitante, 111) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(t.cod_moneda) monedaOperacion,
                 t.monto monto,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(T.cod_moneda, T.fecha)
                   ELSE
                    1
                 END) cotizacion,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    Round((T.monto * fug_obt_cotizacion(T.cod_moneda, T.fecha)),fug_obt_redondeo_seg(T.COD_MONEDA))
                   ELSE
                    ((T.monto) * 1)
                 END) montoOperacionEnGs,
                 nvl(t.nro_doc_beneficiario, 111) numeroDocumentoBeneficiario,
                 UPPER(NVL(translate(t.nom_beneficiario,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreBeneficiario,
                 t.nro_cta_beneficiario numeroCuenta,
                 (CASE
                   WHEN T.COD_TIP_DOC_SOLICITANTE IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_SOLICITANTE)
                   WHEN T.COD_TIP_DOC_SOLICITANTE = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumento,
                 (CASE
                   WHEN T.COD_TIP_DOC_BENEFICIARIO IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_BENEFICIARIO)
                   WHEN T.COD_TIP_DOC_BENEFICIARIO = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumentoBen,
                 t.cod_swi_pte_solicitante Swift,
                 t.nro_cta_solicitante numeroCuentaOtraEntidad,
                 T.COD_SWI_PTE_BENEFICIARIO swiftBeneficiario,
                 fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                 REPLACE(t.observacion, '"', '') motivo,
                 'PRY' paisEntidadInternacional,
                 NVL(ba.cod_banco, ba.cod_ente) entidadOrigen,
                 fug_obt_cod_entidad entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from CC_MOVIMIENTOS_HIS    M,
                 GE_SNP_TRANSFERENCIAS T,
                 ba_oficinas           o,
                 GV_SNP_PARTICIPANTES  ba,
                 ge_sep_transacciones  sep,
                 ge_transacciones      te
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND te.tipo = 'C'
             and sep.ref_archivo = 'TRANACREC'
             and sep.ref_dat_reportar = 'TRA_NAC_RECIBIDA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
             AND (TO_NUMBER(DECODE(t.COD_MONEDA,
                         'GS',
                         t.monto / fug_obt_cotizacion('USD', m.fecha),
                         'USD',
                         t.monto / 1,
                         round(t.monto * fug_obt_cotizacion(t.cod_moneda, m.fecha)) /
                         fug_obt_cotizacion('USD', m.fecha)))) >=  sep.mto_reportar
             and m.cod_modulo = te.cod_modulo
             and m.cod_modalidad = te.cod_modalidad
             and m.Cod_Transaccion = te.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.NRO_DOCUMENTO = T.NRO_REFERENCIA
             AND M.COD_OFICINA = O.COD_OFICINA
             AND T.COD_SWI_PTE_SOLICITANTE = BA.COD_SWIFT
          UNION ALL
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRANACREM' codInstrumento, --TRANSFERENCIA NACIONAL REMITIDA
                 UPPER(NVL(translate(t.nom_solicitante,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreRazonSocial,
                 nvl(t.nro_doc_solicitante, 111) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(t.cod_moneda) monedaOperacion,
                 t.monto monto,
                (CASE
                 WHEN T.COD_MONEDA <> 'GS' THEN
                  fug_obt_cotizacion(T.cod_moneda, T.fecha)
                 ELSE
                  1
               END) cotizacion,
                (CASE
                 WHEN T.COD_MONEDA <> 'GS' THEN
                  Round((T.monto * fug_obt_cotizacion(T.cod_moneda, T.fecha)),fug_obt_redondeo_seg(T.COD_MONEDA))
                 ELSE
                  ((T.monto) * 1)
               END) montoOperacionEnGs,
                 nvl(t.nro_doc_beneficiario, 111) numeroDocumentoBeneficiario,
                 UPPER(NVL(translate(t.nom_beneficiario,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreBeneficiario,
                 t.nro_cta_solicitante numeroCuenta,
                 (CASE
                   WHEN T.COD_TIP_DOC_SOLICITANTE IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_SOLICITANTE)
                   WHEN T.COD_TIP_DOC_SOLICITANTE = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumento,
                 (CASE
                   WHEN T.COD_TIP_DOC_BENEFICIARIO IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_BENEFICIARIO)
                   WHEN T.COD_TIP_DOC_BENEFICIARIO = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumentoBen,
                 t.cod_swi_pte_solicitante Swift,
                 t.nro_cta_beneficiario numeroCuentaOtraEntidad,
                 T.COD_SWI_PTE_BENEFICIARIO swiftBeneficiario,
                 NULL ciudad,
                 REPLACE(t.observacion, '"', '') motivo,
                 'PRY' paisEntidadInternacional,
                 fug_obt_cod_entidad entidadOrigen,
                 NVL(ba.cod_banco, ba.cod_ente) entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from AH_MOVIMIENTOS_HIS    M,
                 GE_SNP_TRANSFERENCIAS T,
                 ba_oficinas           o,
                 GV_SNP_PARTICIPANTES  ba,
                 ge_sep_transacciones  sep,
                 ge_transacciones      te
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND te.tipo = 'D'
             and sep.ref_archivo = 'TRANACREM'
             and sep.ref_dat_reportar = 'TRA_NAC_REMITIDA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
             AND (TO_NUMBER(DECODE(t.COD_MONEDA,
                         'GS',
                         t.monto / fug_obt_cotizacion('USD', m.fecha),
                         'USD',
                         t.monto / 1,
                         round(t.monto * fug_obt_cotizacion(t.cod_moneda, m.fecha)) /
                         fug_obt_cotizacion('USD', m.fecha)))) >=  sep.mto_reportar
             and m.cod_modulo = te.cod_modulo
             and m.cod_modalidad = te.cod_modalidad
             and m.Cod_Transaccion = te.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.NRO_DOCUMENTO = T.NRO_REFERENCIA
             AND M.COD_OFICINA = O.COD_OFICINA
             AND T.COD_SWI_PTE_BENEFICIARIO = BA.COD_SWIFT
          UNION ALL
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRANACREM' codInstrumento, --TRANSFERENCIA NACIONAL REMITIDA
                 UPPER(NVL(translate(t.nom_solicitante,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreRazonSocial,
                 nvl(t.nro_doc_solicitante, 111) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(t.cod_moneda) monedaOperacion,
                 t.monto monto,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(T.cod_moneda, T.fecha)
                   ELSE
                    1
                 END) cotizacion,
                  (CASE
                   WHEN T.COD_MONEDA <> 'GS' THEN
                    Round((T.monto * fug_obt_cotizacion(T.cod_moneda, T.fecha)),fug_obt_redondeo_seg(T.COD_MONEDA))
                   ELSE
                    ((T.monto) * 1)
                 END) montoOperacionEnGs,
                 nvl(t.nro_doc_beneficiario, 111) numeroDocumentoBeneficiario,
                 UPPER(NVL(translate(t.nom_beneficiario,
                                     'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                                     'AEIOUYAEIOUAEIOUNN'),
                           'SIN NOMBRE')) nombreBeneficiario,
                 t.nro_cta_solicitante numeroCuenta,
                 (CASE
                   WHEN T.COD_TIP_DOC_SOLICITANTE IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_SOLICITANTE)
                   WHEN T.COD_TIP_DOC_SOLICITANTE = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumento,
                 (CASE
                   WHEN T.COD_TIP_DOC_BENEFICIARIO IN (1, 6) THEN
                    FUE_OBT_TIP_DOC_ABREVIATURA(T.COD_TIP_DOC_BENEFICIARIO)
                   WHEN T.COD_TIP_DOC_BENEFICIARIO = 2 THEN
                    'PA'
                   ELSE
                    'RUC'
                 END) tipoDocumentoBen,
                 t.cod_swi_pte_solicitante Swift,
                 t.nro_cta_beneficiario numeroCuentaOtraEntidad,
                 T.COD_SWI_PTE_BENEFICIARIO swiftBeneficiario,
                 NULL ciudad,
                 REPLACE(t.observacion, '"', '') motivo,
                 'PRY' paisEntidadInternacional,
                 fug_obt_cod_entidad entidadOrigen,
                 NVL(ba.cod_banco, ba.cod_ente) entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from CC_MOVIMIENTOS_HIS    M,
                 GE_SNP_TRANSFERENCIAS T,
                 ba_oficinas           o,
                 GV_SNP_PARTICIPANTES  ba,
                 ge_sep_transacciones  sep,
                 ge_transacciones      te
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND te.tipo = 'D'
             and sep.ref_archivo = 'TRANACREM'
             and sep.ref_dat_reportar = 'TRA_NAC_REMITIDA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
            AND (TO_NUMBER(DECODE(t.COD_MONEDA,
                         'GS',
                         t.monto / fug_obt_cotizacion('USD', m.fecha),
                         'USD',
                         t.monto / 1,
                         round(t.monto * fug_obt_cotizacion(t.cod_moneda, m.fecha)) /
                         fug_obt_cotizacion('USD', m.fecha)))) >=  sep.mto_reportar
             and m.cod_modulo = te.cod_modulo
             and m.cod_modalidad = te.cod_modalidad
             and m.Cod_Transaccion = te.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.NRO_DOCUMENTO = T.NRO_REFERENCIA
             AND M.COD_OFICINA = O.COD_OFICINA
             AND T.COD_SWI_PTE_BENEFICIARIO = BA.COD_SWIFT) a;


  --Transferencias Interna entre cuentas--
  INSERT INTO ge_sep_operaciones
  (nro_orden,
   fec_operacion,
   cod_oficina,
   nro_comprobante,
   cod_instrumento,
   nom_completo,
   nro_documento,
   cod_moneda,
   monto,
   cotizacion,
   mto_equ_gs,
   nro_doc_beneficiario,
   nom_beneficiario,
   nro_cuenta,
   tip_documento,
   tip_doc_beneficiario,
   swift,
   nro_cta_otr_entidad,
   swi_beneficiario,
   ciudad,
   motivo,
   pai_ent_internacional,
   ent_origen,
   ent_destino,
   cod_tra_padre,
   cod_mod_padre,
   cod_mad_padre,
   cod_transaccion,
   cod_modulo,
   cod_modalidad)
  SELECT rownum nroOrden, a.*
    FROM (select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAINTER' codInstrumento, --TRANSFERENCIA INTERNA
                 fug_obt_nom_cuenta(M.NRO_CUENTA) nombreRazonSocial,
                 FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(M.cod_moneda) monedaOperacion,
                 M.monto monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto *
                          fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumentoBeneficiario,
                 fug_obt_nom_cuenta(M.NRO_CUENTA) nombreBeneficiario,
                 (SELECT M2.NRO_CUENTA
                    FROM ah_movimientos_his M2
                   WHERE M2.FECHA = M.FECHA
                     AND M2.HORA = M.HORA
                     AND M2.COD_USUARIO = M.COD_USUARIO
                     AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                     AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                     AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                     AND M2.COD_TRANSACCION = 503) numeroCuenta,
                 fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                               from ba_personas p
                                              where p.cod_persona =
                                                    fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumento,
                 fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                               from ba_personas p
                                              where p.cod_persona =
                                                    fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumentoBen,
                 NULL Swift,
                 M.NRO_CUENTA numeroCuentaOtraEntidad,
                 NULL swiftBeneficiario,
                 fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                 NULL motivo,
                 'PRY' paisEntidadInternacional,
                 fug_obt_cod_entidad entidadOrigen,
                 fug_obt_cod_entidad entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            FROM ah_movimientos_his   M,
                 BA_OFICINAS          O,
                 GE_SEP_TRANSACCIONES SEP,
                 GE_TRANSACCIONES     T
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND t.tipo = 'C'
             and sep.ref_archivo = 'TRAINTER'
             and sep.ref_dat_reportar = 'TRA_INTERNA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >= sep.mto_reportar
             and m.cod_modulo = t.cod_modulo
             and m.cod_modalidad = t.cod_modalidad
             and m.Cod_Transaccion = t.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.COD_OFICINA = O.COD_OFICINA
             AND fug_obt_cli_principal(M.NRO_CUENTA) =
                 (SELECT fug_obt_cli_principal(M2.NRO_CUENTA)
                    FROM ah_movimientos_his M2
                   WHERE M2.FECHA = M.FECHA
                     AND M2.HORA = M.HORA
                     AND M2.COD_USUARIO = M.COD_USUARIO
                     AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                     AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                     AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                     AND M2.COD_TRANSACCION = 503)
          union all
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' || m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAINTER' codInstrumento, --TRANSFERENCIA INTERNA
                 fug_obt_nom_cuenta(M.NRO_CUENTA) nombreRazonSocial,
                 FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(M.cod_moneda) monedaOperacion,
                 M.monto monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto *
                          fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumentoBeneficiario,
                 fug_obt_nom_cuenta(M.NRO_CUENTA) nombreBeneficiario,
                 (SELECT M2.NRO_CUENTA
                    FROM cc_movimientos_his M2
                   WHERE M2.FECHA = M.FECHA
                     AND M2.HORA = M.HORA
                     AND M2.COD_USUARIO = M.COD_USUARIO
                     AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                     AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                     AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                     AND M2.COD_TRANSACCION = 503) numeroCuenta,
                 fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                               from ba_personas p
                                              where p.cod_persona =
                                                    fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumento,
                 fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                               from ba_personas p
                                              where p.cod_persona =
                                                    fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumentoBen,
                 NULL Swift,
                 M.NRO_CUENTA numeroCuentaOtraEntidad,
                 NULL swiftBeneficiario,
                 fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                 NULL motivo,
                 'PRY' paisEntidadInternacional,
                 fug_obt_cod_entidad entidadOrigen,
                 fug_obt_cod_entidad entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            FROM cc_movimientos_his   M,
                 BA_OFICINAS          O,
                 GE_SEP_TRANSACCIONES SEP,
                 GE_TRANSACCIONES     T
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             AND t.tipo = 'C'
             and sep.ref_archivo = 'TRAINTER'
             and sep.ref_dat_reportar = 'TRA_INTERNA'
             and sep.cod_mod_padre = m.cod_mod_padre
             and sep.cod_mad_padre = m.cod_mad_padre
             and sep.cod_tra_padre = m.cod_tra_padre
             and sep.cod_modulo = m.cod_modulo
             and sep.cod_modalidad = m.cod_modalidad
             and sep.cod_transaccion = m.cod_transaccion
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >= sep.mto_reportar
             and m.cod_modulo = t.cod_modulo
             and m.cod_modalidad = t.cod_modalidad
             and m.Cod_Transaccion = t.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             AND M.COD_OFICINA = O.COD_OFICINA
             AND fug_obt_cli_principal(M.NRO_CUENTA) =
                 (SELECT fug_obt_cli_principal(M2.NRO_CUENTA)
                    FROM cc_movimientos_his M2
                   WHERE M2.FECHA = M.FECHA
                     AND M2.HORA = M.HORA
                     AND M2.COD_USUARIO = M.COD_USUARIO
                     AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                     AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                     AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                     AND M2.COD_TRANSACCION = 503)) a;


  --Transferencias Internacional Swift--
  INSERT INTO ge_sep_operaciones
  (nro_orden,
   fec_operacion,
   cod_oficina,
   nro_comprobante,
   cod_instrumento,
   nom_completo,
   nro_documento,
   cod_moneda,
   monto,
   cotizacion,
   mto_equ_gs,
   nro_doc_beneficiario,
   nom_beneficiario,
   nro_cuenta,
   tip_documento,
   tip_doc_beneficiario,
   swift,
   nro_cta_otr_entidad,
   swi_beneficiario,
   ciudad,
   motivo,
   pai_ent_internacional,
   ent_origen,
   ent_destino,
   cod_tra_padre,
   cod_mod_padre,
   cod_mad_padre,
   cod_transaccion,
   cod_modulo,
   cod_modalidad)
  SELECT rownum nroOrden, a.*
    FROM (
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                          m.hora,
                          'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                  M.COD_OFI_ORIGEN sucursalOrigen,
                  M.NRO_DOCUMENTO numeroComprobante,
                  'TRAEXTREC' codInstrumento, --TRANSFERENCIA INTERNACIONAL RECIBIDA
                  translate(T.NOM_SOLICITANTE,
                            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                            'AEIOUYAEIOUAEIOUNN') nombreRazonSocial,
                  NULL numeroDocumento,
                  pas_tra.fu_obt_mon_iso(T.COD_MONEDA) monedaOperacion,
                  T.MONTO monto,
                  (CASE
                    WHEN m.COD_MONEDA <> 'GS' THEN
                     fug_obt_cotizacion(m.cod_moneda, m.fecha)
                    ELSE
                     1
                  END) cotizacion,
                  (CASE
                    WHEN m.COD_MONEDA <> 'GS' THEN
                     Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                           fug_obt_redondeo_seg(m.COD_MONEDA))
                    ELSE
                     ((m.monto) * 1)
                  END) montoOperacionEnGs,
                  T.NRO_DOC_BENEFICIARIO numeroDocumentoBeneficiario,
                  translate(T.NOM_BENEFICIARIO,
                            'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                            'AEIOUYAEIOUAEIOUNN') nombreBeneficiario,
                  T.NRO_CTA_REFERENCIA numeroCuenta,
                  NULL tipoDocumento,
                  NULL tipoDocumentoBen,
                  T.COD_SWI_BANCO Swift,
                  substr(decode(instr(T.MSJ_SWIFT, ':50K:/'),
                                0,
                                NULL,
                                TRIM(REPLACE(substr(substr(substr(T.MSJ_SWIFT,
                                                                  instr(T.MSJ_SWIFT,
                                                                        ':50K:/')),
                                                           1,
                                                           instr(substr(T.MSJ_SWIFT,
                                                                        instr(T.MSJ_SWIFT,
                                                                              ':50K:/')),
                                                                 chr(10),
                                                                 1)),
                                                    instr(substr(substr(T.MSJ_SWIFT,
                                                                        instr(T.MSJ_SWIFT,
                                                                              ':50K:/')),
                                                                 1,
                                                                 instr(substr(T.MSJ_SWIFT,
                                                                              instr(T.MSJ_SWIFT,
                                                                                    ':50K:/')),
                                                                       chr(10),
                                                                       1)),
                                                          '/') + 1),
                                             chr(10),
                                             ' '))),
                         1,
                         30) numeroCuentaOtraEntidad,
                 v_cod_swift swiftBeneficiario,
                  fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                  REPLACE(T.OBSERVACION, '"', '') motivo,
                  TAB.VAL_PARAMETRO paisEntidadInternacional,
                  NVL(T.COD_BANCO,T.COD_BCO_CORRESPONSAL) entidadOrigen,
                  7 entidadDestino,
                  m.COD_TRA_PADRE,
                  m.cod_mod_padre,
                  m.cod_mad_padre,
                  m.COD_TRANSACCION,
                  m.COD_MODULO,
                  m.COD_MODALIDAD
            from lc_transferencias    t,
                  cc_movimientos_his   m,
                  GE_SEP_TRANSACCIONES s,
                  ge_transacciones     k,
                  ba_oficinas          o,
                  ba_tab_dat_adicionales tab
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             and k.tipo = 'C'
             and s.ref_archivo = 'TRAEXTREC'
             and s.ref_dat_reportar = 'TRA_EXT_RECIBIDA'
             and t.nro_operacion = m.NRO_DOCUMENTO
             and m.COD_TRA_PADRE = s.cod_tra_padre
             and m.COD_MOD_PADRE = s.cod_mod_padre
             and m.COD_MAD_PADRE = s.cod_mad_padre
             AND M.COD_TRANSACCION = s.cod_transaccion
             AND M.COD_MODULO = s.cod_modulo
             AND M.COD_MODALIDAD = s.cod_modalidad
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >=
                 s.mto_reportar
             and m.cod_modulo = k.cod_modulo
             and m.cod_modalidad = k.cod_modalidad
             and m.Cod_Transaccion = k.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             and t.nro_cta_referencia = m.NRO_CUENTA
             and t.nro_operacion = m.nro_documento
             AND M.COD_OFICINA = O.COD_OFICINA
             AND TAB.TAB_RELACION = 'BA_PAISES'
             AND TAB.PARAMETRO = 'COD_PAI_ISO3'
             AND T.COD_PAI_BANCO = TAB.REFERENCIA
          union all
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                         m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAEXTREC' codInstrumento, --TRANSFERENCIA INTERNACIONAL RECIBIDA
                 translate(T.NOM_SOLICITANTE,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreRazonSocial,
                 NULL numeroDocumento,
                 pas_tra.fu_obt_mon_iso(T.COD_MONEDA) monedaOperacion,
                 T.MONTO monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 T.NRO_DOC_BENEFICIARIO numeroDocumentoBeneficiario,
                 translate(T.NOM_BENEFICIARIO,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreBeneficiario,
                 T.NRO_CTA_REFERENCIA numeroCuenta,
                 NULL tipoDocumento,
                 NULL tipoDocumentoBen,
                 T.COD_SWI_BANCO Swift,
                 substr(decode(instr(T.MSJ_SWIFT, ':50K:/'),
                               0,
                               NULL,
                               TRIM(REPLACE(substr(substr(substr(T.MSJ_SWIFT,
                                                                 instr(T.MSJ_SWIFT,
                                                                       ':50K:/')),
                                                          1,
                                                          instr(substr(T.MSJ_SWIFT,
                                                                       instr(T.MSJ_SWIFT,
                                                                             ':50K:/')),
                                                                chr(10),
                                                                1)),
                                                   instr(substr(substr(T.MSJ_SWIFT,
                                                                       instr(T.MSJ_SWIFT,
                                                                             ':50K:/')),
                                                                1,
                                                                instr(substr(T.MSJ_SWIFT,
                                                                             instr(T.MSJ_SWIFT,
                                                                                   ':50K:/')),
                                                                      chr(10),
                                                                      1)),
                                                         '/') + 1),
                                            chr(10),
                                            ' '))),
                        1,
                        30) numeroCuentaOtraEntidad,
                v_cod_swift swiftBeneficiario,
                 fue_obt_des_ciudad(o.cod_pais, o.cod_ciudad) ciudad,
                 REPLACE(T.OBSERVACION, '"', '') motivo,
                 TAB.VAL_PARAMETRO paisEntidadInternacional,
                 NVL(T.COD_BANCO,T.COD_BCO_CORRESPONSAL) entidadOrigen,
                 7 entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from lc_transferencias    t,
                 ah_movimientos_his   m,
                 GE_SEP_TRANSACCIONES s,
                 ge_transacciones     k,
                 ba_oficinas          o,
                 ba_tab_dat_adicionales tab
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             and k.tipo = 'C'
             and s.ref_archivo = 'TRAEXTREC'
             and s.ref_dat_reportar = 'TRA_EXT_RECIBIDA'
             and t.nro_operacion = m.NRO_DOCUMENTO
             and m.COD_TRA_PADRE = s.cod_tra_padre
             and m.COD_MOD_PADRE = s.cod_mod_padre
             and m.COD_MAD_PADRE = s.cod_mad_padre
             AND M.COD_TRANSACCION = s.cod_transaccion
             AND M.COD_MODULO = s.cod_modulo
             AND M.COD_MODALIDAD = s.cod_modalidad
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >=
                 s.mto_reportar
             and m.cod_modulo = k.cod_modulo
             and m.cod_modalidad = k.cod_modalidad
             and m.Cod_Transaccion = k.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             and t.nro_cta_referencia = m.NRO_CUENTA
             and t.nro_operacion = m.nro_documento
             AND M.COD_OFICINA = O.COD_OFICINA
             AND TAB.TAB_RELACION = 'BA_PAISES'
             AND TAB.PARAMETRO = 'COD_PAI_ISO3'
             AND T.COD_PAI_BANCO = TAB.REFERENCIA
          --*******************************--
          union all
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                         m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAEXTREM' codInstrumento, --TRANSFERENCIA INTERNACIONAL REMITIDA
                 translate(T.NOM_SOLICITANTE,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreRazonSocial,
                 fue_obt_nro_doc_persona(T.COD_PER_SOLICITANTE) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(T.COD_MONEDA) monedaOperacion,
                 T.MONTO monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 T.NRO_DOC_BENEFICIARIO numeroDocumentoBeneficiario,
                 translate(T.NOM_BENEFICIARIO,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreBeneficiario,
                 nvl(nvl(T.NRO_CTA_REFERENCIA, t.nro_cta_debito),
                     t.cod_per_solicitante) numeroCuenta,
                 NULL tipoDocumento,
                 NULL tipoDocumentoBen,
                v_cod_swift Swift,
                 T.NRO_CTA_REFERENCIA numeroCuentaOtraEntidad,
                 T.COD_SWI_BANCO swiftBeneficiario,
                 NULL ciudad,
                 REPLACE(T.OBSERVACION, '"', '') motivo,
                 TAB.VAL_PARAMETRO paisEntidadInternacional,
                 7 entidadOrigen,
                 NVL(T.COD_BANCO,T.COD_BCO_CORRESPONSAL) entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from lc_transferencias    t,
                 lc_movimientos_his   m,
                 GE_SEP_TRANSACCIONES s,
                 ge_transacciones     k,
                 ba_oficinas          o,
                 ba_tab_dat_adicionales tab
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             and k.tipo = 'C'
             and s.ref_archivo = 'TRAEXTREM'
             and s.ref_dat_reportar = 'TRA_EXT_REMITIDA'
             and t.nro_operacion = m.NRO_DOCUMENTO
             and m.COD_TRA_PADRE = s.cod_tra_padre
             and m.COD_MOD_PADRE = s.cod_mod_padre
             and m.COD_MAD_PADRE = s.cod_mad_padre
             AND M.COD_TRANSACCION = s.cod_transaccion
             AND M.COD_MODULO = s.cod_modulo
             AND M.COD_MODALIDAD = s.cod_modalidad
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >=
                 s.mto_reportar
             and m.cod_modulo = k.cod_modulo
             and m.cod_modalidad = k.cod_modalidad
             and m.Cod_Transaccion = k.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             and T.NRO_REFERENCIA = M.NRO_DOCUMENTO2
             AND T.NRO_OPERACION = M.NRO_DOCUMENTO
             AND M.COD_OFICINA = O.COD_OFICINA
             AND TAB.TAB_RELACION = 'BA_PAISES'
             AND TAB.PARAMETRO = 'COD_PAI_ISO3'
             AND T.COD_PAI_BENEFICIARIO = TAB.REFERENCIA
          union all
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                         m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAEXTREM' codInstrumento, --TRANSFERENCIA INTERNACIONAL REMITIDA
                 translate(T.NOM_SOLICITANTE,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreRazonSocial,
                 fue_obt_nro_doc_persona(T.COD_PER_SOLICITANTE) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(T.COD_MONEDA) monedaOperacion,
                 T.MONTO monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 T.NRO_DOC_BENEFICIARIO numeroDocumentoBeneficiario,
                 translate(T.NOM_BENEFICIARIO,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreBeneficiario,
                 nvl(nvl(T.NRO_CTA_REFERENCIA, t.nro_cta_debito),
                     t.cod_per_solicitante) numeroCuenta,
                 NULL tipoDocumento,
                 NULL tipoDocumentoBen,
                v_cod_swift Swift,
                 T.NRO_CTA_REFERENCIA numeroCuentaOtraEntidad,
                 T.COD_SWI_BANCO swiftBeneficiario,
                 NULL ciudad,
                 REPLACE(T.OBSERVACION, '"', '') motivo,
                 TAB.VAL_PARAMETRO paisEntidadInternacional,
                 7 entidadOrigen,
                 NVL(T.COD_BANCO,T.COD_BCO_CORRESPONSAL) entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from lc_transferencias    t,
                 cc_movimientos_his   m,
                 GE_SEP_TRANSACCIONES s,
                 ge_transacciones     k,
                 ba_oficinas          o,
                 ba_tab_dat_adicionales tab
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             and k.tipo = 'C'
             and s.ref_archivo = 'TRAEXTREM'
             and s.ref_dat_reportar = 'TRA_EXT_REMITIDA'
             and m.COD_TRA_PADRE = s.cod_tra_padre
             and m.COD_MOD_PADRE = s.cod_mod_padre
             and m.COD_MAD_PADRE = s.cod_mad_padre
             AND M.COD_TRANSACCION = s.cod_transaccion
             AND M.COD_MODULO = s.cod_modulo
             AND M.COD_MODALIDAD = s.cod_modalidad
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >=
                 s.mto_reportar
             and m.cod_modulo = k.cod_modulo
             and m.cod_modalidad = k.cod_modalidad
             and m.Cod_Transaccion = k.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             and m.NRO_DOCUMENTO = t.nro_referencia
             and m.COD_MOD_PADRE = t.cod_modulo
             and m.COD_MAD_PADRE = t.cod_modalidad
             and m.FECHA = t.fec_operacion
             AND M.COD_OFICINA = O.COD_OFICINA
             AND TAB.TAB_RELACION = 'BA_PAISES'
             AND TAB.PARAMETRO = 'COD_PAI_ISO3'
             AND T.COD_PAI_BENEFICIARIO = TAB.REFERENCIA
          union all
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                         m.hora,
                         'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                 M.COD_OFI_ORIGEN sucursalOrigen,
                 M.NRO_DOCUMENTO numeroComprobante,
                 'TRAEXTREM' codInstrumento, --TRANSFERENCIA INTERNACIONAL REMITIDA
                 translate(T.NOM_SOLICITANTE,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreRazonSocial,
                 fue_obt_nro_doc_persona(T.COD_PER_SOLICITANTE) numeroDocumento,
                 pas_tra.fu_obt_mon_iso(T.COD_MONEDA) monedaOperacion,
                 T.MONTO monto,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    fug_obt_cotizacion(m.cod_moneda, m.fecha)
                   ELSE
                    1
                 END) cotizacion,
                 (CASE
                   WHEN m.COD_MONEDA <> 'GS' THEN
                    Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                          fug_obt_redondeo_seg(m.COD_MONEDA))
                   ELSE
                    ((m.monto) * 1)
                 END) montoOperacionEnGs,
                 T.NRO_DOC_BENEFICIARIO numeroDocumentoBeneficiario,
                 translate(T.NOM_BENEFICIARIO,
                           'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
                           'AEIOUYAEIOUAEIOUNN') nombreBeneficiario,
                 nvl(nvl(T.NRO_CTA_REFERENCIA, t.nro_cta_debito),
                     t.cod_per_solicitante) numeroCuenta,
                 NULL tipoDocumento,
                 NULL tipoDocumentoBen,
                 /*'BBVAPYPAA'*/v_cod_swift Swift,
                 T.NRO_CTA_REFERENCIA numeroCuentaOtraEntidad,
                 T.COD_SWI_BANCO swiftBeneficiario,
                 NULL ciudad,
                 REPLACE(T.OBSERVACION, '"', '') motivo,
                 TAB.VAL_PARAMETRO paisEntidadInternacional,
                 7 entidadOrigen,
                 NVL(T.COD_BANCO,T.COD_BCO_CORRESPONSAL) entidadDestino,
                 m.COD_TRA_PADRE,
                 m.cod_mod_padre,
                 m.cod_mad_padre,
                 m.COD_TRANSACCION,
                 m.COD_MODULO,
                 m.COD_MODALIDAD
            from lc_transferencias    t,
                 ah_movimientos_his   m,
                 GE_SEP_TRANSACCIONES s,
                 ge_transacciones     k,
                 ba_oficinas          o,
                 ba_tab_dat_adicionales tab
           WHERE m.FECHA between v_fec_ini and v_fec_FIN
             and k.tipo = 'C'
             and s.ref_archivo = 'TRAEXTREM'
             and s.ref_dat_reportar = 'TRA_EXT_REMITIDA'
             and m.COD_TRA_PADRE = s.cod_tra_padre
             and m.COD_MOD_PADRE = s.cod_mod_padre
             and m.COD_MAD_PADRE = s.cod_mad_padre
             AND M.COD_TRANSACCION = s.cod_transaccion
             AND M.COD_MODULO = s.cod_modulo
             AND M.COD_MODALIDAD = s.cod_modalidad
             AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                   'GS',
                                   m.monto /
                                   fug_obt_cotizacion('USD', m.fecha),
                                   'USD',
                                   m.monto / 1,
                                   round(m.monto * m.cotizacion) /
                                   fug_obt_cotizacion('USD', m.fecha)))) >=
                 s.mto_reportar
             and m.cod_modulo = k.cod_modulo
             and m.cod_modalidad = k.cod_modalidad
             and m.Cod_Transaccion = k.cod_transaccion
             AND M.ESTADO = 'N'
             AND M.REVERSADO = 'N'
             and m.NRO_DOCUMENTO = t.nro_referencia
             and m.COD_MOD_PADRE = t.cod_modulo
             and m.COD_MAD_PADRE = t.cod_modalidad
             and m.FECHA = t.fec_operacion
             AND M.COD_OFICINA = O.COD_OFICINA
             AND TAB.TAB_RELACION = 'BA_PAISES'
             AND TAB.PARAMETRO = 'COD_PAI_ISO3'
             AND T.COD_PAI_BENEFICIARIO = TAB.REFERENCIA) a;

         --CANCELACION ANTICIPADA DE PRESTAMOS DEBITO EN CUENTA CANAPREDC--
            INSERT INTO ge_sep_operaciones
            (nro_orden,
             fec_operacion,
             cod_oficina,
             nro_comprobante,
             cod_instrumento,
             nom_completo,
             nro_documento,
             cod_moneda,
             monto,
             cotizacion,
             mto_equ_gs,
             tip_documento,
             nro_cuenta,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad)
            SELECT rownum nroOrden, a.*
              FROM (
                    select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                                    m.hora,
                                    'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                            M.COD_OFI_ORIGEN sucursal,
                            substr(m.CONCEPTO, 25) || M.NRO_DOCUMENTO numeroComprobante,
                            'CANAPREDC' cod_instrumento,
                            fug_obt_nom_cuenta(M.NRO_CUENTA) nombreRazonSocialDeudor,
                            FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumentoDeudor,
                            pas_tra.fu_obt_mon_iso(M.cod_moneda) monedaOperacion,
                            M.monto monto,
                            (CASE
                              WHEN M.COD_MONEDA <> 'GS' THEN
                               fug_obt_cotizacion(M.COD_MONEDA, m.fecha)
                              ELSE
                               1
                            END) cotizacion,
                            (CASE
                              WHEN M.COD_MONEDA <> 'GS' THEN
                               Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                                     fug_obt_redondeo_seg(m.COD_MONEDA))
                              ELSE
                               (m.monto * 1)
                            END) montoOperacionEnGs,
                            fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                                          from ba_personas p
                                                         where p.cod_persona =
                                                               fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumentoDeu,
                            substr(m.CONCEPTO, 25) numeroCredito,
                            m.COD_TRA_PADRE,
                            m.cod_mod_padre,
                            m.cod_mad_padre,
                            m.COD_TRANSACCION,
                            m.COD_MODULO,
                            m.COD_MODALIDAD
                      from  CC_MOVIMIENTOS_HIS   M,
                            BA_OFICINAS          O,
                            GE_SEP_TRANSACCIONES SEP,
                            GE_TRANSACCIONES     T,
                            PR_CTA_PRESTAMOS     PR
                     where m.FECHA between v_fec_ini and v_fec_FIN
                       AND M.ESTADO = 'N'
                       AND M.REVERSADO = 'N'
                       AND M.COD_OFICINA = O.COD_OFICINA
                       and m.cod_mod_padre = sep.cod_mod_padre
                       and m.cod_mad_padre = sep.cod_mad_padre
                       and m.cod_tra_padre = sep.cod_tra_padre
                       and m.cod_modulo = sep.cod_modulo
                       and m.cod_modalidad = sep.cod_modalidad
                       and m.cod_transaccion = sep.cod_transaccion
                       and sep.ref_archivo = 'CANAPREDC'
                       and sep.ref_dat_reportar = 'CAN_ANT_PRESTAMO'
                       AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                             'GS',
                                             m.monto /
                                             fug_obt_cotizacion('USD', m.fecha),
                                             'USD',
                                             m.monto / 1,
                                             round(m.monto * m.cotizacion) /
                                             fug_obt_cotizacion('USD', m.fecha)))) >= sep.mto_reportar
                       and m.cod_modulo = t.cod_modulo
                       and m.cod_modalidad = t.cod_modalidad
                       and m.Cod_Transaccion = t.cod_transaccion
                       AND t.tipo = 'D'
                       AND PR.NRO_CUENTA =
                           (SELECT substr(m.CONCEPTO, 25)
                              FROM CC_MOVIMIENTOS_HIS M2
                             WHERE M2.FECHA = M.FECHA
                               AND M2.HORA = M.HORA
                               AND M2.COD_USUARIO = M.COD_USUARIO
                               AND M2.NRO_SECUENCIA = M.NRO_SECUENCIA
                               AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                               AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                               AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                               AND M2.COD_TRANSACCION = M.COD_TRANSACCION
                               AND M2.COD_MODULO = M.COD_MODULO
                               AND M2.COD_MODALIDAD = M.COD_MODALIDAD)
                       AND PR.FEC_CANCELACION < PR.FEC_VENCIMIENTO
                       AND fug_obt_cli_principal(M.NRO_CUENTA) =
                           (SELECT fug_obt_cli_principal(substr(m.CONCEPTO, 25))
                              FROM CC_MOVIMIENTOS_HIS M2
                             WHERE M2.FECHA = M.FECHA
                               AND M2.HORA = M.HORA
                               AND M2.COD_USUARIO = M.COD_USUARIO
                               AND M2.NRO_SECUENCIA = M.NRO_SECUENCIA
                               AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                               AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                               AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                               AND M2.COD_TRANSACCION = M.COD_TRANSACCION
                               AND M2.COD_MODULO = M.COD_MODULO
                               AND M2.COD_MODALIDAD = M.COD_MODALIDAD)
                              AND PR.NRO_CUENTA NOT IN (SELECT RF.NRO_CUENTA
                                                          FROM PR_CTA_PRE_REF_RES4 RF
                                                         WHERE RF.REVERSADO = 'N')
                              AND PR.NRO_CUENTA NOT IN (SELECT RF.NRO_CUENTA
                                                          FROM PR_CTA_PRE_REF_RES4 RF
                                                         WHERE RF.REVERSADO = 'N')
          UNION ALL
          select to_date(to_char(m.fecha, 'DD/MM/YYYY') || ' ' ||
                                    m.hora,
                                    'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                            M.COD_OFI_ORIGEN sucursal,
                            substr(m.CONCEPTO, 25) || M.NRO_DOCUMENTO numeroComprobante,
                            'CANAPREDC' cod_instrumento,
                            fug_obt_nom_cuenta(M.NRO_CUENTA) nombreRazonSocialDeudor,
                            FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(M.NRO_CUENTA)) numeroDocumentoDeudor,
                            pas_tra.fu_obt_mon_iso(M.cod_moneda) monedaOperacion,
                            M.monto monto,
                            (CASE
                              WHEN M.COD_MONEDA <> 'GS' THEN
                               fug_obt_cotizacion(M.COD_MONEDA, m.fecha)
                              ELSE
                               1
                            END) cotizacion,
                            (CASE
                              WHEN M.COD_MONEDA <> 'GS' THEN
                               Round((m.monto * fug_obt_cotizacion(m.cod_moneda, m.fecha)),
                                     fug_obt_redondeo_seg(m.COD_MONEDA))
                              ELSE
                               (m.monto * 1)
                            END) montoOperacionEnGs,
                            fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                                          from ba_personas p
                                                         where p.cod_persona =
                                                               fug_obt_cli_principal(M.NRO_CUENTA))) tipoDocumentoDeu,
                            substr(m.CONCEPTO, 25) numeroCredito,
                            m.COD_TRA_PADRE,
                            m.cod_mod_padre,
                            m.cod_mad_padre,
                            m.COD_TRANSACCION,
                            m.COD_MODULO,
                            m.COD_MODALIDAD
                      from  AH_MOVIMIENTOS_HIS   M,
                            BA_OFICINAS          O,
                            GE_SEP_TRANSACCIONES SEP,
                            GE_TRANSACCIONES     T,
                            PR_CTA_PRESTAMOS     PR
                     where m.FECHA between v_fec_ini and v_fec_FIN
                       AND M.ESTADO = 'N'
                       AND M.REVERSADO = 'N'
                       AND M.COD_OFICINA = O.COD_OFICINA
                       and m.cod_mod_padre = sep.cod_mod_padre
                       and m.cod_mad_padre = sep.cod_mad_padre
                       and m.cod_tra_padre = sep.cod_tra_padre
                       and m.cod_modulo = sep.cod_modulo
                       and m.cod_modalidad = sep.cod_modalidad
                       and m.cod_transaccion = sep.cod_transaccion
                       and sep.ref_archivo = 'CANAPREDC'
                       and sep.ref_dat_reportar = 'CAN_ANT_PRESTAMO'
                       AND (TO_NUMBER(DECODE(m.COD_MONEDA,
                                             'GS',
                                             m.monto /
                                             fug_obt_cotizacion('USD', m.fecha),
                                             'USD',
                                             m.monto / 1,
                                             round(m.monto * m.cotizacion) /
                                             fug_obt_cotizacion('USD', m.fecha)))) >= sep.mto_reportar
                       and m.cod_modulo = t.cod_modulo
                       and m.cod_modalidad = t.cod_modalidad
                       and m.Cod_Transaccion = t.cod_transaccion
                       AND t.tipo = 'D'
                       AND PR.NRO_CUENTA =
                           (SELECT substr(m.CONCEPTO, 25)
                              FROM AH_MOVIMIENTOS_HIS M2
                             WHERE M2.FECHA = M.FECHA
                               AND M2.HORA = M.HORA
                               AND M2.COD_USUARIO = M.COD_USUARIO
                               AND M2.NRO_SECUENCIA = M.NRO_SECUENCIA
                               AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                               AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                               AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                               AND M2.COD_TRANSACCION = M.COD_TRANSACCION
                               AND M2.COD_MODULO = M.COD_MODULO
                               AND M2.COD_MODALIDAD = M.COD_MODALIDAD)
                       AND PR.FEC_CANCELACION < PR.FEC_VENCIMIENTO
                       AND fug_obt_cli_principal(M.NRO_CUENTA) =
                           (SELECT fug_obt_cli_principal(substr(m.CONCEPTO, 25))
                              FROM AH_MOVIMIENTOS_HIS M2
                             WHERE M2.FECHA = M.FECHA
                               AND M2.HORA = M.HORA
                               AND M2.COD_USUARIO = M.COD_USUARIO
                               AND M2.NRO_SECUENCIA = M.NRO_SECUENCIA
                               AND M2.COD_TRA_PADRE = M.COD_TRA_PADRE
                               AND M2.COD_MOD_PADRE = M.COD_MOD_PADRE
                               AND M2.COD_MAD_PADRE = M.COD_MAD_PADRE
                               AND M2.COD_TRANSACCION = M.COD_TRANSACCION
                               AND M2.COD_MODULO = M.COD_MODULO
                               AND M2.COD_MODALIDAD = M.COD_MODALIDAD)
                               AND PR.NRO_CUENTA NOT IN (SELECT RF.NRO_CUENTA
                                                          FROM PR_CTA_PRE_REF_RES4 RF
                                                         WHERE RF.REVERSADO = 'N')
                               AND PR.NRO_CUENTA NOT IN (SELECT RF.NRO_CUENTA
                                                          FROM PR_CTA_PRE_REF_RES4 RF
                                                         WHERE RF.REVERSADO = 'N')) a;

          --CANCELACION ANTICIPADA CUOTA PRESTAMOS DEBITO EN CUENTA CANAPREDC--
          INSERT INTO ge_sep_operaciones
            (nro_orden,
             fec_operacion,
             cod_oficina,
             nro_comprobante,
             cod_instrumento,
             nom_completo,
             nro_documento,
             cod_moneda,
             monto,
             cotizacion,
             mto_equ_gs,
             tip_documento,
             nro_cuenta,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad)
            SELECT rownum nroOrden, a.*
              FROM (select to_date(to_char(pc.fecha, 'DD/MM/YYYY') || ' ' || pc.hora,
                                   'DD/MM/YYYY HH24:MI:SS') fechaOperacion,
                           pr.cod_oficina sucursal,
                           pr.nro_cuenta || pc.nro_cuota numeroComprobante,
                           'CANAPREDC' cod_instrumento,
                           fug_obt_nom_cuenta(pr.nro_cuenta) nombreRazonSocialDeudor,
                           FUE_OBT_NRO_DOC_PERSONA(fug_obt_cli_principal(pr.NRO_CUENTA)) numeroDocumentoDeudor,
                           pas_tra.fu_obt_mon_iso(pr.cod_moneda) monedaOperacion,
                           (pc.mto_capital + pc.mto_interes + pc.mto_impuesto) monto,
                           (CASE
                             WHEN pr.COD_MONEDA <> 'GS' THEN
                              fug_obt_cotizacion(pr.cod_moneda, pc.fecha)
                             ELSE
                              1
                           END) cotizacion,
                           (CASE
                             WHEN pr.COD_MONEDA <> 'GS' THEN
                              Round(((pc.mto_capital + pc.mto_interes + pc.mto_impuesto) *
                                    fug_obt_cotizacion(pr.cod_moneda, pc.fecha)),
                                    fug_obt_redondeo_seg(PR.COD_MONEDA))
                             ELSE
                              ((pc.mto_capital + pc.mto_interes + pc.mto_impuesto) * 1)
                           END) montoOperacionEnGs,
                           fue_obt_tip_doc_abreviatura((select p.cod_tip_documento
                                                         from ba_personas p
                                                        where p.cod_persona =
                                                              fug_obt_cli_principal(pr.NRO_CUENTA))) tipoDocumentoDeu,
                           pr.nro_cuenta numeroCredito,
                           360 COD_TRA_PADRE,
                           PR.COD_MODULO cod_mod_padre,
                           PR.COD_MODALIDAD cod_mad_padre,
                           null COD_TRANSACCION,
                           pr.COD_MODULO,
                           pr.COD_MODALIDAD
                      from pr_cobros pc, pr_cta_prestamos pr, ge_sep_transacciones sep
                     where pr.nro_cuenta = pc.nro_cuenta
                       and pc.fecha between v_fec_ini and v_fec_FIN
                       and (pc.fec_vencimiento - pc.fecha) >= 31
                       and sep.ref_archivo = 'CANAPREDC'
                       and sep.ref_dat_reportar = 'CAN_ANT_CUO_PRESTAMO' -- CANCELACION ANTICIPADA CUOTA PRESTAMOS
                       AND (TO_NUMBER(DECODE(pr.cod_moneda,
                                             'GS', -- si es GS
                                             (select sum(pc.mto_capital + pc.mto_interes +
                                                         pc.mto_impuesto)
                                                from pr_cobros pc2
                                               where pc2.nro_cuenta = pr.nro_cuenta
                                                 and pc2.fecha between v_fec_ini and v_fec_FIN
                                                 and (pc2.fec_vencimiento - pc.fecha) >= 31) /
                                             fug_obt_cotizacion('USD', pc.fecha),
                                             'USD', -- si es USD
                                             (select sum(pc.mto_capital + pc.mto_interes +
                                                         pc.mto_impuesto)
                                                from pr_cobros pc2
                                               where pc2.nro_cuenta = pr.nro_cuenta
                                                 and pc2.fecha between v_fec_ini and v_fec_FIN
                                                 and (pc2.fec_vencimiento - pc.fecha) >= 31) / 1,
                                             round((select sum(pc.mto_capital +
                                                               pc.mto_interes +
                                                               pc.mto_impuesto) --Si es otra moneda
                                                      from pr_cobros pc2
                                                     where pc2.nro_cuenta =
                                                           pr.nro_cuenta
                                                       and pc2.fecha between v_fec_ini and v_fec_FIN
                                                       and (pc2.fec_vencimiento -
                                                           pc.fecha) >= 31) *
                                                   fug_obt_cotizacion(pr.cod_moneda,
                                                                      pc.fecha)) /
                                             fug_obt_cotizacion('USD', pc.fecha)))) >= sep.mto_reportar
                       and pr.nro_cuenta not in
                           (select rf.nro_cuenta
                              from pr_cta_pre_ref_res4 rf
                             where rf.reversado = 'N')
                       and pr.nro_cuenta not in
                           (select rf.nro_cuenta
                              from pr_cta_pre_ref_res4 rf
                             where rf.reversado = 'N')
                          --Excluye pago de cuotas anticipadas cuando el prestamo se cancela en el mismo periodo
                       AND pr.nro_cuenta not in
                           (select pct.nro_cuenta
                              from pr_cta_prestamos pct
                             where pct.nro_cuenta = pr.nro_cuenta
                               and pct.estado = 'N'
                               and pct.fec_cancelacion between v_fec_ini and v_fec_FIN)) a;

  END;


procedure lp_ins_saldos is
 PRAGMA AUTONOMOUS_TRANSACTION;
begin

  insert into ge_sep_sal_diarios
    (select fecha, nro_cuenta, cod_moneda, sal_tot_cap
       from GE_SAL_DIARIOS r
      where r.fecha between v_fec_ini and v_fec_fin);
  commit;
end;

PROCEDURE lp_act_cheques(p_nro_orden       NUMBER,
                         p_nro_comprobante VARCHAR2) IS

  v_nro_cheque cc_che_enviados.nro_cheque%TYPE;
  v_can_cheque NUMBER(3);
  rg_sep_ope  ge_sep_operaciones%ROWTYPE;

  CURSOR c_cheques IS
    SELECT rownum nro, a.cod_banco, a.nro_cheque, a.nro_boleta, a.monto, a.cod_moneda
      FROM cc_che_enviados a
     WHERE EXISTS (SELECT 1
                     FROM ge_sep_operaciones b
                    WHERE b.nro_comprobante = a.nro_boleta
                      AND b.cod_instrumento = 'CAMCANJ')
       AND a.nro_boleta = p_nro_comprobante
       AND a.fecha >= v_fec_ini
       AND a.fecha <= v_fec_fin;
  BEGIN
    BEGIN
      SELECT *
        INTO rg_sep_ope
        FROM ge_sep_operaciones a
       WHERE a.nro_orden = p_nro_orden
         AND a.nro_comprobante = p_nro_comprobante;

      FOR i IN c_cheques LOOP
        IF i.nro = 1 THEN
          UPDATE ge_sep_operaciones a
             SET a.nro_cheque  = i.nro_cheque,
                 a.bco_emisor  = fug_obt_des_banco(i.cod_banco),
                 a.monto       = i.monto,
                 a.mto_equ_gs  = round(i.monto * rg_sep_ope.cotizacion),
                 a.observacion = a.observacion||' Actualizado por cheque detallado.'
           WHERE a.nro_comprobante = p_nro_comprobante
             AND a.nro_orden = p_nro_orden;
        ELSE
          INSERT INTO ge_sep_operaciones
                (nro_orden, fec_operacion, cod_oficina, nro_comprobante, cod_instrumento,
                 nom_completo, nro_documento, cod_moneda, monto, cotizacion, mto_equ_gs,
                 nro_doc_beneficiario, nom_beneficiario, nro_cuenta, tip_documento, tip_doc_beneficiario,
                 nro_cheque, bco_emisor, tip_persona, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                 cod_transaccion, cod_modulo, cod_modalidad, observacion, sal_cuenta)
          VALUES(rg_sep_ope.nro_orden, rg_sep_ope.fec_operacion, rg_sep_ope.cod_oficina, rg_sep_ope.nro_comprobante, rg_sep_ope.cod_instrumento,
                 rg_sep_ope.nom_completo, rg_sep_ope.nro_documento, rg_sep_ope.cod_moneda, i.monto, rg_sep_ope.cotizacion, round(i.monto * rg_sep_ope.cotizacion),
                 rg_sep_ope.nro_doc_beneficiario, rg_sep_ope.nom_beneficiario, rg_sep_ope.nro_cuenta, rg_sep_ope.tip_documento, rg_sep_ope.tip_doc_beneficiario,
                 i.nro_cheque, fug_obt_des_banco(i.cod_banco), rg_sep_ope.tip_persona, rg_sep_ope.cod_tra_padre, rg_sep_ope.cod_mod_padre, rg_sep_ope.cod_mad_padre,
                 rg_sep_ope.cod_transaccion, rg_sep_ope.cod_modulo, rg_sep_ope.cod_modalidad, 'Insertado por cheque detallado', rg_sep_ope.sal_cuenta);
        END IF;
      END LOOP;
    EXCEPTION
      WHEN no_data_found THEN
        --no tiene cheque
        NULL;
    END;

  END;

procedure lp_upd_datos is

v_tip_doc_valido       varchar2(60) := fug_obt_pardinamico('TIP_DOC_VAL_SEPRELAD');
v_tip_doc_per_fis      varchar2(4) := 'PA';
v_tip_doc_per_jur      varchar2(4) := 'RUC';

Cursor c_ver_doc_depositos is
select g.nro_orden, g.fec_operacion, g.nro_comprobante, g.nro_cuenta
  from ge_sep_depositos g
 where g.fec_operacion between v_fec_ini and v_fec_fin
   and exists (select 1
                 from ge_sep_depositos e
                where e.nro_comprobante = g.nro_comprobante
                  and e.fec_operacion < v_fec_ini);

Cursor c_ver_doc_extracciones is
select g.nro_orden, g.fec_operacion, g.nro_comprobante, g.nro_cuenta
  from ge_sep_extracciones g
 where g.fec_operacion between v_fec_ini and v_fec_fin
   and exists (select 1
                 from ge_sep_extracciones e
                where e.nro_comprobante = g.nro_comprobante
                  and e.fec_operacion < v_fec_ini);

CURSOR c_ver_doc_operaciones IS
  select g.nro_orden, trunc(g.fec_operacion) fec_operacion, g.nro_comprobante, g.nro_cuenta
    from ge_sep_operaciones g
   where trunc(g.fec_operacion) between v_fec_ini and v_fec_fin
     and exists (select 1
                   from ge_sep_operaciones e
                  where e.nro_comprobante = g.nro_comprobante
                    and trunc(e.fec_operacion) < v_fec_ini);

CURSOR c_act_cheques IS
  SELECT *
    FROM ge_sep_operaciones a
   WHERE trunc(a.fec_operacion) between v_fec_ini and v_fec_fin
     AND a.cod_instrumento = 'CAMCANJ';

begin

  update ge_sep_depositos g
     set g.sal_cuenta = round(fug_obt_sep_sal_diario(g.nro_cuenta, g.fec_operacion));

  update ge_sep_extracciones g
     set g.sal_cuenta = round(fug_obt_sep_sal_diario(g.nro_cuenta, g.fec_operacion));

  update ge_sep_operaciones g
     set g.sal_cuenta = round(fug_obt_sep_sal_diario(g.nro_cuenta, g.fec_operacion));

  update ge_sep_depositos r
     set r.observacion = 'Tipo Doc. Ajustado Anterior: '||r.tip_doc_beneficiario ||' - Actual: '||decode(r.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur),
         r.tip_doc_beneficiario = decode(r.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur)
   where instr(','||nvl(v_tip_doc_valido,'X')||',',r.tip_doc_beneficiario ) < 1;

  update ge_sep_extracciones e
     set e.observacion = 'Tipo Doc. Ajustado Anterior: '||e.tip_documento ||' - Actual: '||decode(e.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur),
         e.tip_documento = decode(e.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur)
   where instr(','||nvl(v_tip_doc_valido,'X')||',', e.tip_documento ) < 1;

  update ge_sep_operaciones o
     set o.observacion = 'Tipo Doc. Ajustado Anterior: '||o.tip_documento ||' - Actual: '||decode(o.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur),
         o.tip_documento = decode(o.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur)
   where instr(','||nvl(v_tip_doc_valido,'X')||',', o.tip_documento ) < 1;

  update ge_sep_operaciones o
     set o.observacion = o.observacion||' '||'Tipo Doc. Beneficiario Ajustado Anterior: '||o.tip_doc_beneficiario ||' - Actual: '||decode(o.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur),
         o.tip_doc_beneficiario = decode(o.tip_persona, 'F', v_tip_doc_per_fis,v_tip_doc_per_jur)
   where instr(','||nvl(v_tip_doc_valido,'X')||',', o.tip_doc_beneficiario ) < 1;

  for act_doc in c_ver_doc_depositos loop
      update ge_sep_depositos t
         set t.nro_comprobante = '0'||act_doc.nro_comprobante,
             t.observacion     = t.observacion ||' Nro. Comprobante ajustado, anterior: '|| act_doc.nro_comprobante
       where t.nro_orden       = act_doc.nro_orden
         and t.fec_operacion   = act_doc.fec_operacion
         and t.nro_comprobante = act_doc.nro_comprobante
         and t.nro_cuenta      = act_doc.nro_cuenta;

  end loop;

  for act_doc in c_ver_doc_extracciones loop
      update ge_sep_extracciones t
         set t.nro_comprobante = '0'||act_doc.nro_comprobante,
             t.observacion     = t.observacion ||' Nro. Comprobante ajustado, anterior: '|| act_doc.nro_comprobante
       where t.nro_orden       = act_doc.nro_orden
         and t.fec_operacion   = act_doc.fec_operacion
         and t.nro_comprobante = act_doc.nro_comprobante
         and t.nro_cuenta      = act_doc.nro_cuenta;

  end loop;

  -- buscar cheques
  FOR act_che IN c_act_cheques LOOP
      lp_act_cheques(act_che.nro_orden, act_che.nro_comprobante);
  END LOOP;


  FOR act_doc in c_ver_doc_operaciones LOOP

      UPDATE ge_sep_operaciones t
         SET t.nro_comprobante = '0'||act_doc.nro_comprobante,
             t.observacion     = t.observacion ||' Nro. Comprobante ajustado, anterior: '|| act_doc.nro_comprobante
       WHERE t.nro_orden       = act_doc.nro_orden
         AND t.fec_operacion   = act_doc.fec_operacion
         AND t.nro_comprobante = act_doc.nro_comprobante
         AND t.nro_cuenta      = act_doc.nro_cuenta;

  END LOOP;

end;

procedure lp_del_datos is

begin

delete ge_sep_depositos g
 where  g.fec_operacion between v_fec_ini and v_fec_fin;

delete ge_sep_extracciones g
 where g.fec_operacion between v_fec_ini and v_fec_fin;

delete ge_sep_operaciones g
 where trunc(g.fec_operacion) between v_fec_ini and v_fec_fin;

end;

begin

  ---Limpiar tablas al iniciar Proceso
  execute immediate ('truncate table ge_sep_sal_diarios');

  --Asignación Rango Fecha para proceso
  v_fec_ini := nvl(p_fec_ini, v_fecha);
  v_fec_fin := nvl(p_fec_fin, v_fecha);
  begin
  select cod_swift into v_cod_swift from ge_bancos where cod_banco = fug_obt_cod_banco;
  exception
    when no_data_found then
       v_cod_swift := null;
  end;  

  ---Actualizar datos tablas Seprelad
  lp_del_datos;
  lp_ins_datos;
  lp_ins_saldos;
  lp_upd_datos;

end;
/

