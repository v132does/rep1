CREATE OR REPLACE PROCEDURE IT.PRF_CON_TRANSACCION
 IS
V_COD_MODULO GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MODALIDAD GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
V_SENTENCIA VARCHAR2(240);
V_FEC_ACT_FIJO GE_MOVIMIENTOS.FECHA%TYPE;
V_COD_MAD_PADRE GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
V_COD_TRANSACCION GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_COD_MONEDA GE_MOVIMIENTOS.COD_MONEDA%TYPE;
V_COD_OFI_ORIGEN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE;
V_MOV_FILA VARCHAR2(18);
V_AFECTA GE_TRANSACCIONES.AFECTA%TYPE;
V_TRA_FILA VARCHAR2(18);
V_NOM_RUTINA1 VARCHAR2(1000);
V_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_HAY_ERROR VARCHAR2(1);
V_ERR_CLIENTE NUMBER(1);
V_MSJ_ERROR VARCHAR2(150);
V_RESIDENTE GE_TIP_DEUDORES.IND_RESIDENTE%TYPE;
V_COD_SECTOR GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE;
V_TIP_DEUDOR GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE;
V_COD_PLAZO GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
V_CAN_DIAS GE_PLZ_CONTABLES.CAN_DIAS%TYPE;
V_SIG_NRO_REFERENCIA NUMBER(7);
V_NRO_REFERENCIA NUMBER(7);
V_COD_OFICINA GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_MONTO GE_MOVIMIENTOS.MONTO%TYPE;
V_MTO_EQU_LOCAL GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE;
V_EST_CUENTA GE_MOVIMIENTOS.EST_CUENTA%TYPE;
V_FEC_VALOR GE_MOVIMIENTOS.FEC_VALOR%TYPE;
V_COD_TRA_PADRE GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE;
V_REVERSADO GE_MOVIMIENTOS.REVERSADO%TYPE;
V_EST_MOVIMIENTO GE_MOVIMIENTOS.ESTADO%TYPE;
V_COD_MOD_PADRE GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
v_cod_mon_local ba_monedas.cod_moneda%type;
v_nro_documento2 ge_movimientos.nro_documento2%type;
/* Actualiza los historicos de AF a partir de los movimientos diarios. */
PROCEDURE LP_ACT_HIS_AF;
/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 );
v_tip_cuenta ge_con_transacciones.tip_cuenta%type;
v_tip_interes ge_con_transacciones.tip_interes%type;
v_tip_renovacion ge_con_transacciones.tip_renovacion%type;
v_cat_automatica ge_con_transacciones.cat_automatica%type;
CURSOR CURSOR1 IS
   SELECT g.COD_MODULO, g.COD_MODALIDAD, g.COD_OFICINA, g.NRO_CUENTA, nvl(g.MONTO,0),
          g.EST_CUENTA, g.FEC_VALOR, g.COD_TRA_PADRE, g.REVERSADO, g.ESTADO,
          g.COD_MOD_PADRE, g.COD_MAD_PADRE, g.COD_TRANSACCION, g.COD_MONEDA, g.COD_OFI_ORIGEN,
          g.MTO_EQU_LOCAL, g.NRO_DOCUMENTO2, rowid
     FROM GE_MOVIMIENTOS g
    WHERE g.COD_MODULO = 13
      AND g.COD_TRANSACCION > 0
      AND g.ESTADO = 'N'
      AND NOT EXISTS (Select 1
                      from   cb_asi_automaticos_det c,
                             cb_asi_automaticos a,
                             ge_con_transacciones t
                      where  t.nro_referencia = c.ref_movimiento
                      and    a.nro_asiento = c.nro_asiento
                      and    a.nro_asi_real is not null
                      and    t.nro_referencia = g.nro_documento4)
      ORDER BY FECHA,HORA,NRO_SECUENCIA;
/* Actualiza los historicos de AF a partir de los movimientos diarios. */
PROCEDURE LP_ACT_HIS_AF
 IS
BEGIN
  begin
  INSERT INTO AF_MOVIMIENTOS_HIS
                  (fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                   monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                   cod_retencion, fec_fin_retencion, est_cuenta, estado,
                   cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                   val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                   hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                   cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                   cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                   nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador,
                   tip_mov_rubro, cod_tip_ope_cambio, referencia,
                   usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
       SELECT  fecha, hora, cod_usuario, nro_secuencia, fec_valor,
                   monto, nro_cuenta, cod_moneda, cod_oficina, cod_error,
                   cod_retencion, fec_fin_retencion, est_cuenta, estado,
                   cod_causa, cod_banco, cod_ofi_origen, concepto, cod_tasa,
                   val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion,
                   hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                   cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja,
                   cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
                   nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador,
                   tip_mov_rubro, cod_tip_ope_cambio, referencia,
                   usu_insercion, fec_insercion, usu_modificacion, fec_modificacion
        FROM  GE_MOVIMIENTOS
        WHERE FECHA = v_fec_act_fijo
          AND COD_MODULO = 13;
   exception
      when dup_val_on_index then
         null;
   end;
END;
/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 )
 IS
BEGIN
  SELECT COD_PLAZO
    INTO p_cod_plazo
    FROM GE_PLZ_CONTABLES
   WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                       FROM GE_PLZ_CONTABLES
                      WHERE CAN_DIAS >= p_can_dias);
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'En lp_obt_cod_plazo '||SQLERRM);
END;
BEGIN
   v_err_cliente   := 0;
   v_fec_act_fijo  := pag_cal.FU_OBT_FEC_ACTUAL(13);
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   v_msj_error   := ' ';
   ---1. Cerando los posibles registro del dia, si existen----------
   UPDATE GE_CON_TRANSACCIONES g
      SET g.CANTIDAD = 0,
          g.TOTAL = 0,
          g.TOT_MON_LOCAL = 0,
          g.NRO_REFERENCIA = null
    WHERE g.FECHA = v_fec_act_fijo
      AND g.COD_MODULO = 13
      AND NOT EXISTS (Select 1
                      from   cb_asi_automaticos_det c,
                             cb_asi_automaticos a
                      where  a.nro_asiento = c.nro_asiento
                      and    a.nro_asi_real is not null
                      and    c.ref_movimiento = g.nro_referencia);
   ---2. Leo el sgte. nro. de referencia del GE_PAR_GENERALES ---------------
   v_sig_nro_referencia := fug_obt_pardinamico('SIG_NRO_REFERENCIA',v_cod_modulo, v_cod_modalidad, v_cod_oficina,v_cod_moneda);
   ---3. Leyendo los datos del diario (GE_MOVIMIENTOS) y act.GE_CON_TRANSACCIONES-------
   IF cursor1%ISOPEN THEN
      CLOSE cursor1;
   END IF;
   OPEN cursor1;
   LOOP
      --- leo el registro del GE_MOVIMIENTOS --------------------------------
      FETCH cursor1
      INTO  v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_cuenta, v_monto,
            v_est_cuenta, v_fec_valor, v_cod_tra_padre, v_reversado, v_est_movimiento,
            v_cod_mod_padre, v_cod_mad_padre, v_cod_transaccion, v_cod_moneda, v_cod_ofi_origen,
            v_mto_equ_local, v_nro_documento2, v_mov_fila;
      EXIT WHEN cursor1%NOTFOUND;
      --- asigno valores por defecto, por si exista cuenta cliente ---
      v_residente  := 'S';
      v_cod_sector := 'N';
      v_tip_deudor := '2';
      v_cod_plazo  := 0;
      v_tip_cuenta := NULL;
      --v_est_cuenta := null;
      v_tip_interes := null;
      v_tip_renovacion := null;
      v_cat_automatica := null;
      v_can_dias := null;
      --- Comun a todos los modulos-----------------------------------
      v_hay_error  := 'N';
      BEGIN
          SELECT lower(rtrim(RUTINA1)),
                 TIPO, AFECTA
            INTO v_nom_rutina1, v_detalle, v_afecta
            FROM GE_TRANSACCIONES
           WHERE COD_TRANSACCION = v_cod_transaccion
             AND COD_MODULO = v_cod_modulo
             AND COD_MODALIDAD = v_cod_modalidad;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_hay_error := 'S';
            raise_application_error(-20000,'Trans. no existe '||to_char(v_cod_modulo)||' '
                                    ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion));
           UPDATE GE_MOVIMIENTOS
           SET    ESTADO = 'E'
           WHERE rowid = v_mov_fila;
      END;
      v_err_cliente := 0;
      IF v_hay_error = 'N' THEN
         --- busco el cliente principal de la cuenta ------------------
         IF v_nro_cuenta IS NOT NULL THEN
             BEGIN
                 SELECT GE_CLIENTES.RESIDENTE,
                        GE_CLIENTES.COD_SEC_CONTABLE,
                        GE_CLIENTES.COD_TIP_DEUDOR
                   INTO v_residente, v_cod_sector, v_tip_deudor
                   FROM GE_CTA_CLIENTES,GE_CLIENTES
                  WHERE GE_CTA_CLIENTES.NRO_CUENTA  = v_nro_cuenta
                    AND GE_CTA_CLIENTES.RELACION = 'P'
                    AND GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
                    AND GE_CTA_CLIENTES.COD_MODULO = v_cod_modulo
                    AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad
                    AND GE_CTA_CLIENTES.COD_OFICINA = v_cod_oficina;
             EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     raise_application_error(-20000,'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                     v_err_cliente := 1;
                 WHEN TOO_MANY_ROWS THEN
                     raise_application_error(-20000,'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                     v_err_cliente := 2;
             END;
             -- si no hubo error en la busqueda de la Clte Principal---
             IF v_err_cliente = 0 THEN
                IF v_cod_modalidad in (32,37,38) THEN
                   --Busqueda del Plazo de la Cuentas plazo fijo y CDA.---
                        SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_PLAZOS
                        WHERE COD_MODULO = v_cod_modulo
                          AND COD_MODALIDAD = v_cod_modalidad
                          AND COD_OFICINA = v_cod_oficina
                          AND NRO_CUENTA = v_nro_cuenta;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                ELSIF v_cod_modalidad in (33,34,35,36) THEN
                     BEGIN
                       SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_CERTIFICADOS
                        WHERE NRO_CUENTA = v_nro_cuenta
                          AND COD_MODULO = v_cod_modulo
                          AND COD_MODALIDAD = v_cod_modalidad
                          AND COD_OFICINA = v_cod_oficina;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                    EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                END IF;
                --si es prestamo calculo el plazo entre las fechas
                IF v_cod_modulo = 6 THEN
                   BEGIN
                   SELECT FEC_VENCIMIENTO - FEC_INICIO,
                          tipo, tip_interes, nvl(tip_renovacion,'A'),
                          nvl(v_est_cuenta,estado)
                    INTO v_can_dias, v_tip_cuenta, v_tip_interes,
                         v_tip_renovacion, v_est_cuenta
                    FROM PR_CTA_PRESTAMOS
                   WHERE NRO_CUENTA = v_nro_cuenta
                     AND COD_MODULO = v_cod_modulo
                     AND COD_MODALIDAD = v_cod_modalidad
                     AND COD_OFICINA = v_cod_oficina;
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                END IF;
                if v_cod_modulo = 5 then
                   --- Para la parametrizacion contable el estado de la tarjeta
                   --- se hace igual que el prestamo
                   select decode(t.cat_automatica,'1','C',
                          '2','V','3','G','4','M','M') estado
                     into v_est_cuenta
                     from ta_cta_tarjetas t
                    where t.nro_cuenta = V_NRO_CUENTA;
                end if;
                ------------------------------------------------------
                if v_cod_modulo in (4,5,6) then
                   --- Verifico categoria
                   begin
                      select fup_obt_categoria(c.cat_automatica,c.cat_subjetiva)
                        into v_cat_automatica
                        from ge_clientes c, ge_cta_clientes cc
                       where c.cod_persona = cc.cod_persona
                         and cc.relacion = 'P'
                         and cc.nro_cuenta = v_nro_cuenta;
                   exception
                      when no_data_found then
                         v_cat_automatica := 1;
                   end;
                   --- Recuperar categoria para valuaciones
                   if v_cod_modulo = 6 and v_cod_tra_padre = 150 then
                      if v_nro_documento2 is not null then
                         --- El movimiento trae categoria
                         v_cat_automatica := v_nro_documento2;
                      end if;
                   end if;
                end if;
             END IF;
         END IF;
         IF v_err_cliente = 0 AND v_detalle IN ('C','D') THEN
                 --- Busco si existe en Nro. de Referencia del GE_CON_TRANSACCIONES--------
                 BEGIN
                   SELECT NRO_REFERENCIA,rowid
                     INTO v_nro_referencia,v_tra_fila
                     FROM GE_CON_TRANSACCIONES
                    WHERE FECHA           = v_fec_act_fijo
                      AND COD_MOD_PADRE   = v_cod_mod_padre
                      AND COD_MAD_PADRE   = v_cod_mad_padre
                      AND COD_OFI_ORIGEN  = v_cod_ofi_origen
                      AND COD_OFICINA     = v_cod_oficina
                      AND COD_MONEDA      = v_cod_moneda
                      AND COD_MODULO      = v_cod_modulo
                      AND COD_MODALIDAD   = v_cod_modalidad
                      AND COD_TRANSACCION = v_cod_transaccion
                      AND COD_SECTOR      = v_cod_sector
                      AND COD_TIP_DEUDOR  = v_tip_deudor
                      AND RESIDENTE       = v_residente
                      AND COD_PLAZO       = v_cod_plazo
                      AND nvl(est_cuenta,'X')     = nvl(v_est_cuenta,'X')
                      AND nvl(tip_cuenta,'X')     = nvl(v_tip_cuenta,'X')
                      AND nvl(tip_interes,'X')    = nvl(v_tip_interes,'X')
                      AND nvl(tip_renovacion,'X') = nvl(v_tip_renovacion,'X')
                      AND nvl(cat_automatica,'9') = nvl(v_cat_automatica,'9');
                   if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                      v_mto_equ_local := nvl(v_monto,0) * pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_act_fijo);
                   end if;
                   -- actualizo el registro del GE_CON_TRANSACCIONES.-------------------
                   UPDATE GE_CON_TRANSACCIONES
                      SET CANTIDAD = NVL(CANTIDAD,0)+1,
                          TOTAL = NVL(TOTAL,0)+NVL(v_monto,0),
                          TOT_MON_LOCAL = nvl(TOT_MON_LOCAL,0) + nvl(v_mto_equ_local,0)
                    WHERE ROWID = v_tra_fila;
                   --------------------------------------------------------
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      -- asigno sgte.valor al Nro.Ref e incremento contador--
                      v_nro_referencia := v_sig_nro_referencia;
                      v_sig_nro_referencia := nvl(v_sig_nro_referencia,0) + 1;
                       if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                          v_mto_equ_local := nvl(v_monto,0) * pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_act_fijo);
                       end if;
                      -- no existe registro, se debe generar ----------------
                      INSERT INTO GE_CON_TRANSACCIONES
                          (FECHA,COD_MOD_PADRE,COD_MAD_PADRE,COD_OFI_ORIGEN,
                           COD_OFICINA,COD_MONEDA,COD_MODULO,COD_MODALIDAD,
                           COD_TRANSACCION,COD_SECTOR,COD_TIP_DEUDOR,RESIDENTE,
                           COD_PLAZO,CANTIDAD,TOTAL,TOT_MON_LOCAL,
                           est_cuenta, tip_cuenta, tip_interes, tip_renovacion,
                           cat_automatica, NRO_REFERENCIA)
                       VALUES
                          (v_fec_act_fijo,v_cod_mod_padre,v_cod_mad_padre,v_cod_ofi_origen,
                           v_cod_oficina,v_cod_moneda,v_cod_modulo,v_cod_modalidad,
                           v_cod_transaccion,v_cod_sector,v_tip_deudor,v_residente,
                           v_cod_plazo,1         ,v_monto,v_mto_equ_local,
                           v_est_cuenta, v_tip_cuenta, v_tip_interes, v_tip_renovacion,
                           v_cat_automatica, v_nro_referencia);
                         ------------------------------------------------------
                    WHEN TOO_MANY_ROWS THEN
                       v_hay_error := 'S';
                       raise_application_error(-20000,'Existen reg. duplicados en GE_CON_TRANSACCIONES');
                 END;
                 --- actualizo el mov. del GE_MOVIMIENTOS con el nro. de ref.-----
                 UPDATE GE_MOVIMIENTOS
                    SET PROTEGIDO = 'S',
                        NRO_DOCUMENTO4 = v_nro_referencia
                 WHERE ROWID = v_mov_fila;
                 ----------------------------------------------------------
         END IF;
         --- veo si existe act. batch, siempre que haya Cuenta---------
         IF v_nro_cuenta IS NOT NULL THEN
                 v_sentencia := '(to_date('
                 --to_char(v_fec_valor,'DDMMYYYY')||','||
                 ||chr(39)||to_char(v_fec_valor,'DDMMYYYY')||chr(39)||','
                 ||chr(39)||'DDMMYYYY'||chr(39)||'),'
                 ||'to_number('||chr(39)||v_cod_oficina||chr(39)||'),'
                 ||chr(39)||v_nro_cuenta||chr(39)||','
                 ||'to_number('||chr(39)||v_cod_modalidad||chr(39)||'),'
                 ||'to_number('||chr(39)||v_monto||chr(39)||'),'
                 ||chr(39)||v_est_cuenta||chr(39)||','
                 ||chr(39)||v_reversado||chr(39)||','
                 ||chr(39)||v_detalle||chr(39)||','||''''||v_afecta||''''||')';
----dbms_output.put_line('Sentencia '||v_sentencia||' Rutina '||v_nom_rutina1);
                 IF v_nom_rutina1 IS NOT NULL THEN
                    v_nom_rutina1 := 'BEGIN '||v_nom_rutina1||v_sentencia||'; END;';
                    sql_util.ejecute_dml(v_nom_rutina1,v_msj_error);
                    if v_msj_error is not null then
                       raise_application_error(-20000,'Ejec.Rutina '||v_msj_error);
                    end if;
                 END IF;
         END IF;
         ---------------------------------------------------------------
      END IF;
   END LOOP;
   CLOSE cursor1;
   --- Actualizo el Sgte.Nro.Ref de la tabla GE_PAR_GENERALES -----------
   PRG_ACT_PAR_DINAMICO('SIG_NRO_REFERENCIA',v_cod_modulo, v_cod_modalidad,v_cod_moneda, v_cod_oficina,v_sig_nro_referencia);
   -------------------------------------------------------------
   LP_ACT_HIS_AF;

END;
/

