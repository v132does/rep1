CREATE OR REPLACE FUNCTION it.FUG_WSI_REC_CHE_PRODEP
   (P_NRO_REFERENCIA IN       cj_mov_prodep.nro_referencia%type,
    P_NRO_REF_DEP    IN       VARCHAR2,
    P_NRO_CUENTA     IN       cj_mov_prodep.nro_cuenta%type,
    P_COD_MON_ISO    IN       ba_monedas.cod_mon_iso%type,
    P_MON_TOTAL      IN       cj_mov_prodep.monto%type,
    P_CAN_CHEQUES    IN       NUMBER,
    P_COD_OFICINA    IN       cj_mov_prodep.cod_oficina%type,
    P_DIA            IN       NUMBER,
    P_ESTADO         IN       VARCHAR2,
    P_DETCHEQUES     IN       TYP_DETALLEPRODCHEQUES,
    P_TIP_CONECTOR   IN       VARCHAR2) RETURN TYP_RETORNODEPOSITOS IS

   v_cheques       typ_prodcheques;
   v_detcheques    typ_detalleprodcheques;
   v_fecha         date := pag_cal.fu_obt_fec_actual(4);
   v_ret_dep       typ_retornodepositos := typ_retornodepositos();
   v_nro_ref       cj_mov_prodep.nro_referencia%type;
   v_nro_cuenta    cj_movimientos.nro_cuenta%type;
   v_nro_documento cj_movimientos.nro_documento%type;
   v_mon_total     cj_movimientos.monto%type;
   v_cod_moneda    cj_movimientos.cod_moneda%type;
   v_mon_iso       ba_monedas.cod_mon_iso%type;
   v_cod_usuario   cj_mov_prodep.cod_usuario%type;
   v_nro_caja      cj_mov_prodep.nro_caja%type;
   v_nro_lote      cc_che_remitidos.nro_lote%type;
   v_cod_oficina   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_OFI_TESORERIA');
   v_estado        cj_mov_prodep.estado%type := 'N';
   v_tip_dato      cc_che_remitidos_res.tip_dato%type := 1;
   v_retencion     cc_che_remitidos.retencion%type;
   v_cod_retencion ge_movimientos.cod_retencion%type;
   v_nro_pedido    number := 0;
   v_msj_salida    varchar2(8000);
   v_cod_banco     cc_che_remitidos.cod_banco%type;
   v_usu_insercion cc_che_remitidos_tmp.usu_insercion%type;
   v_men_error     varchar2(1000);
   error exception;
   v_che_det       varchar2(8000);
   v_cheq varchar2(2000);
PROCEDURE lp_ins_log(P_MENSAJE   cj_log_prodep.mensaje%type,
                      p_estado   cj_log_prodep.estado%type,
                      p_cant_cheques number
                      ) IS
  pragma autonomous_transaction;
  BEGIN
    INSERT INTO cj_log_prodep
      (nro_referencia, mensaje, estado,
      nro_ref_dep,
      nro_cuenta,
      cod_mon_iso,
      mon_total,
      can_cheques,
      cod_oficina,
      dia,
      estado_prodep,
      tip_conector
      )
    VALUES(P_NRO_REFERENCIA, P_MENSAJE, p_estado,
    P_NRO_REF_DEP,
    P_NRO_CUENTA,
    P_COD_MON_ISO,
    P_MON_TOTAL  ,
    P_CANT_CHEQUES,
    P_COD_OFICINA,
    P_DIA        ,
    P_ESTADO,
    P_TIP_CONECTOR  );
    commit;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
BEGIN
   BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1;  END;

   v_nro_ref := lpad(p_nro_referencia, 15, '0');
   prj_obt_dat_mov_prodep(v_nro_ref,
                          null,
                          null,
                          v_cod_usuario,
                          v_cod_moneda,
                          v_nro_cuenta,
                          v_nro_documento,
                          v_nro_caja,
                          v_mon_total,
                          v_estado);
   IF v_mon_total = 0 THEN
      v_mon_total := (p_mon_total)/100;
      prj_obt_dat_mov_prodep(v_nro_ref,
                          null,
                          null,
                          v_cod_usuario,
                          v_cod_moneda,
                          v_nro_cuenta,
                          v_nro_documento,
                          v_nro_caja,
                          v_mon_total,
                          v_estado);
   END IF;
   IF p_tip_conector = 'C' THEN -- Conector Caja se inserta el detalle de cheques procesados en Prodep
      IF p_dia = 1 THEN
         v_fecha := pag_cal.fu_obt_fec_proxima(4);
      END IF;
      IF p_estado = 'OK' THEN
         IF p_cod_mon_iso = pag_gen.fu_obt_mon_fuerte THEN
            v_tip_dato := 2;
         END IF;
         v_ret_dep.estado := 0;
         IF v_tip_dato = 1 THEN
            DELETE cc_che_remitidos d
             WHERE EXISTS ( SELECT 0
                              FROM cc_che_remitidos_res r
                             WHERE r.fecha = v_fecha
                               AND r.nro_boleta = v_nro_ref
                               AND r.tip_dato = v_tip_dato
                               AND r.monto = v_mon_total
                               AND d.fecha = r.fecha
                               AND d.cod_oficina = r.cod_oficina
                               AND d.nro_lote = r.nro_lote );
            DELETE cc_che_remitidos_res r
             WHERE r.fecha = v_fecha
               AND r.nro_boleta = v_nro_ref
               AND r.tip_dato = v_tip_dato
               AND r.monto = v_mon_total;
            BEGIN
              SELECT MIN(nro_lote)
                INTO v_nro_lote
                FROM cc_che_remitidos_res
               WHERE fecha = v_fecha
                 AND usu_insercion = user
                 AND tip_dato = v_tip_dato;
            EXCEPTION
              WHEN OTHERS THEN
                v_nro_lote := null;
            END;
            IF v_nro_lote IS NULL THEN
               v_nro_lote := 999;
            ELSE
               v_nro_lote := v_nro_lote - 1;
            END IF;
            IF nvl(p_nro_cuenta, '0') <> '0' THEN
               v_nro_cuenta := p_nro_cuenta;
            END IF;
            BEGIN
              INSERT INTO cc_che_remitidos_res( fecha,
                                                cod_oficina,
                                                nro_referencia,
                                                nro_boleta,
                                                monto,
                                                nro_lote,
                                                nro_caja,
                                                cod_ofi_origen,
                                                tip_dato)
                                        VALUES( v_fecha,
                                                v_cod_oficina,
                                                v_nro_cuenta,
                                                v_nro_ref,
                                                (p_mon_total)/100,
                                                v_nro_lote,
                                                nvl(v_nro_caja, 998),
                                                p_cod_oficina,
                                                v_tip_dato );
            EXCEPTION
              WHEN OTHERS THEN
                v_ret_dep.estado := 1;
                v_ret_dep.mensaje := 'Al insertar la cabecera. - '||sqlerrm;
            END;
         ELSE
            BEGIN
              SELECT t.usu_insercion
                INTO v_usu_insercion
                FROM cc_che_remitidos_tmp t
               WHERE t.tip_dato = v_tip_dato
                 AND t.nro_boleta = v_nro_ref
                 AND t.usu_insercion <> user;
            EXCEPTION
              WHEN OTHERS THEN
                v_usu_insercion := null;
            END;
            DELETE cc_che_remitidos_tmp d
             WHERE d.tip_dato = v_tip_dato
               AND d.nro_boleta = v_nro_ref;
         END IF;
         v_detcheques := P_DETCHEQUES;
         FOR c in 1 .. v_detcheques.count LOOP
             v_cheques := v_detcheques(c);
             v_che_det := v_che_det||' - '||v_cheques.nroCheque||'= '||v_cheques.monto;
             v_cod_banco := substr(v_cheques.banda, 1, 2);
             v_retencion := '24';
             v_cod_retencion := 2;
             IF v_cheques.ciclo = 0 THEN
                v_retencion := '00';
             END IF;
             IF p_dia = 0 THEN
                IF v_retencion = '00' THEN
                   v_cod_retencion := 1;
                END IF;
             ELSE
                v_cod_retencion := 3;
             END IF;
             IF v_estado = 'P' THEN
                v_nro_pedido := 1; -- se asigna un número diferente a cero(0) para indicar que tiene pedido de autorización.
             END IF;

             v_cheq := 'nroCheque: '||v_cheques.nroCheque||' - nroCuenta: '|| v_cheques.nroCuenta||' - moneda: '||v_cheques.codMonIso||' - importe: '||v_cheques.monto||' - motivo: '||v_cheques.motivo||' - usuario: '||v_cheques.usuario||' - banda: '||v_cheques.banda||' - chequeid: '||v_cheques.chequeId|| 'ciclo:'||v_cheques.ciclo;
             lp_ins_log( SUBSTR(v_cheq  ,0,2000)
                            , v_ret_dep.estado, v_detcheques.count);
             IF (p_mon_total)/100 = v_mon_total THEN
                prg_cre_savepoint('detche');
                lp_ins_log( SUBSTR('Llamada a fuj_pro_tra_det_133: '||'99999'||'-'||v_nro_caja||'-'||v_nro_documento||'-'||v_cod_retencion||'-'||v_cod_banco||'-'||v_cheques.nroCheque||'-'||(v_cheques.monto)/100||'-'||v_cod_oficina||'-'||nvl(v_nro_pedido, 0)||'-'||nvl(v_cod_usuario, upper(v_cheques.usuario))||'-'||v_mon_total  ,0,2000)
                            , v_ret_dep.estado, v_detcheques.count);
                v_msj_salida := fuj_pro_tra_det_133(99999, --p_nro_operacion
                                                    v_nro_caja,
                                                    v_nro_documento,
                                                    v_cod_retencion,
                                                    v_cod_banco,
                                                    v_cheques.nroCheque,
                                                    (v_cheques.monto)/100,
                                                    v_cod_oficina,
                                                    nvl(v_nro_pedido, 0),
                                                    nvl(v_cod_usuario, upper(v_cheques.usuario)),
                                                    v_mon_total);
                lp_ins_log( SUBSTR('Retorno fuj_pro_tra_det_133: '||v_msj_salida,0,2000), v_ret_dep.estado, v_detcheques.count);
                IF v_msj_salida NOT LIKE '%~000~%' THEN
                   prg_rol_savepoint('detche');
                END IF;
             END IF;
             IF v_tip_dato = 1 THEN
                BEGIN
                  INSERT INTO cc_che_remitidos( nro_registro,
                                                cod_banco,
                                                monto,
                                                nro_cheque,
                                                nro_cuenta,
                                                cod_oficina,
                                                nro_lote,
                                                tip_dato,
                                                fecha,
                                                cod_bandacm7,
                                                usu_captura,
                                                retencion )
                                        VALUES( c,
                                                substr(v_cheques.banda, 1, 2),
                                                (v_cheques.monto)/100,
                                                v_cheques.nroCheque,
                                                v_cheques.nroCuenta,
                                                v_cod_oficina,
                                                v_nro_lote,
                                                v_tip_dato,
                                                v_fecha,
                                                v_cheques.banda,
                                                upper(v_cheques.usuario),
                                                v_retencion );
                EXCEPTION
                   WHEN OTHERS THEN
                     v_ret_dep.estado := 1;
                     v_ret_dep.mensaje := substr( 'Al insertar el detalle. - '||sqlerrm, 1, 200);
                END;
             ELSE
                sql_util.ejecute_dml( 'ALTER TRIGGER AB_CC_CHE_REMITIDOS_TMP DISABLE', v_men_error );--deshabilitar para insertar el usu_insercion
                BEGIN
                  INSERT INTO cc_che_remitidos_tmp( nro_registro,
                                                    cod_banco,
                                                    monto,
                                                    nro_cheque,
                                                    nro_cuenta,
                                                    cod_oficina,
                                                    nro_lote,
                                                    tip_dato,
                                                    fecha,
                                                    nro_boleta,
                                                    nro_referencia,
                                                    cod_bandacm7,
                                                    usu_captura,
                                                    retencion,
                                                    usu_insercion,
                                                    usu_modificacion
                                                     )
                                            VALUES( c,
                                                    substr(v_cheques.banda, 1, 2),
                                                    (v_cheques.monto)/100,
                                                    v_cheques.nroCheque,
                                                    v_cheques.nroCuenta,
                                                    v_cod_oficina,
                                                    v_nro_lote,
                                                    v_tip_dato,
                                                    v_fecha,
                                                    v_nro_ref,
                                                    v_nro_cuenta,
                                                    v_cheques.banda,
                                                    upper(v_cheques.usuario),
                                                    v_retencion,
                                                    nvl(v_usu_insercion, user),
                                                    nvl(v_usu_insercion, user)
                                                    );
                EXCEPTION
                   WHEN OTHERS THEN
                     v_ret_dep.estado := 1;
                     v_ret_dep.mensaje := substr('Al insertar el detalle. - '||sqlerrm,1,200);
                END;
                sql_util.ejecute_dml( 'ALTER TRIGGER AB_CC_CHE_REMITIDOS_TMP ENABLE', v_men_error ); --volver a habilitar
             END IF;
         END LOOP;
         COMMIT;
         v_ret_dep.nroReferencia := p_nro_referencia;
      ELSE
         v_ret_dep.estado := 0;
      END IF;
   ELSIF p_tip_conector = 'B' THEN  -- Conector Backoffice retorna los datos del depósito
      IF v_cod_moneda IS NOT NULL AND v_mon_total IS NOT NULL THEN
         v_mon_iso := pas_cri.fu_obt_mon_iso(v_cod_moneda);
         v_ret_dep.monIso := v_mon_iso;
         v_ret_dep.numCuenta := 0;
         v_ret_dep.monto := v_mon_total;
         v_ret_dep.estado := 0;
      ELSE
         v_ret_dep.estado := 1;
      END IF;
   END IF;


  lp_ins_log( SUBSTR('Respuesta: '||v_ret_dep.mensaje,0,2000), v_ret_dep.estado, v_detcheques.count);
  RETURN v_ret_dep;


EXCEPTION
   WHEN OTHERS THEN
      v_ret_dep.estado := 1;
      IF v_ret_dep.mensaje IS NULL THEN
         v_ret_dep.mensaje := substr('Error en FUG_WSI_REC_CHE_PRODEP: '||sqlerrm, 1, 200);
      END IF;
      lp_ins_log( v_ret_dep.mensaje, v_ret_dep.estado, v_detcheques.count);
      RETURN v_ret_dep;
END;
/
