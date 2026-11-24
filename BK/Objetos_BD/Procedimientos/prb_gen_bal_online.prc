CREATE OR REPLACE PROCEDURE IT.PRB_GEN_BAL_ONLINE
   (P_FECHA IN DATE            DEFAULT pag_cal.fu_obt_fec_actual(1),    -- fecha de movimiento
    P_HORA IN VARCHAR2         DEFAULT NULL,    -- hora del movimiento
    P_COD_USUARIO IN VARCHAR2  DEFAULT NULL,    -- usuario del movimiento
    P_NRO_SECUENCIA IN NUMBER  DEFAULT NULL,    -- nro de secuencia del movimiento
    P_COD_MOD_PADRE IN NUMBER  DEFAULT NULL,    -- modulo padre del movimiento
    P_COD_MAD_PADRE IN NUMBER  DEFAULT NULL) IS    -- modalidad padre del movimiento

-- Requerimiento : REG-BBVA-CNF_2300_FATD.00-BAL_ONLINE.doc
-- Modificaci�n  : Generar una simulacion del balance en linea.
-- Fecha Solicitud : 20/09/2013.

-- Variables.
v_monto                 ge_movimientos.monto%type;
v_cotizacion            ge_cotizaciones.val_conversion%type;
v_cot_usd               ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte);
v_mto_equ_local         ge_movimientos.mto_equ_local%type;
v_cod_mon_local         ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
v_cod_mon_fuerte        ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
v_tip_mov_rubro         ge_movimientos.tip_mov_rubro%type;
v_cod_rubro             ge_movimientos.cod_rubro%type;
v_nro_documento         ge_movimientos.nro_documento%type;
v_hor_inicio            ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CBD_HOR_INI_GEN_BAL_ONLINE');
v_hor_fin               ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CBD_HOR_FIN_GEN_BAL_ONLINE');
v_fec_actual            date := pag_cal.fu_obt_fec_actual(1);
v_fec_contab            date := pag_cal.fu_obt_fec_actual(2);
v_fec_ult_cierre        date;
v_grabar                number := 0;
v_redondeo_ml           number(5);
v_cod_oficina_01        number(4);
v_lugar                 number;
v_msj                   varchar2(3000);
v_cod_asi_interoficina  varchar2(1) := 'N';
v_cod_rub_interoficina  varchar2(20);
v_tip_mov_rubro_01      varchar2(1);
v_tip_movimiento        varchar2(1);
v_tip_mov_interoficina  varchar2(1);

/* Obtiene el codigo de plazo a partir de la cantidad de dias. */
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

-- Proc. que genera los movimientos imputados directamente a cuentas contables
PROCEDURE LP_PRO_MOV_CONTABLES IS

-- Cursores.
CURSOR c_mov_contables IS
   SELECT fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
          monto, mto_equ_local, tip_mov_rubro, cod_moneda,
          cod_modulo, cod_modalidad, cod_transaccion, nro_cuenta,
          cod_mod_padre, cod_mad_padre, cod_ofi_origen, cotizacion,
          cod_oficina, cod_tra_padre, nro_documento
     FROM ge_movimientos
    WHERE (monto <> 0 OR mto_equ_local <> 0)
      AND estado IN ('N','H')
      AND cod_rubro IS NOT NULL
      AND cod_mod_padre = nvl(p_cod_mod_padre,cod_mod_padre)
      AND cod_mad_padre = nvl(p_cod_mad_padre,cod_mad_padre)
      AND (reversado = 'N' OR (reversado = 'S' AND (p_hora IS NOT NULL OR fecha > fec_valor)))
      AND (cod_usuario = p_cod_usuario OR p_cod_usuario IS NULL)
      AND (fecha = p_fecha OR p_fecha IS NULL)
      AND (hora = p_hora OR p_hora IS NULL)
      AND (nro_secuencia = p_nro_secuencia OR p_nro_secuencia IS NULL);

BEGIN
  FOR mv IN c_mov_contables LOOP
     -- Variables.
     v_monto                := mv.monto;
     v_cotizacion           := mv.cotizacion;
     v_mto_equ_local        := mv.mto_equ_local;
     v_cod_asi_interoficina := 'N';
     ----------------------------------------
     IF mv.cod_oficina <> mv.cod_ofi_origen THEN
         -- ES ASIENTO INTEROFICINA
         v_cod_asi_interoficina := 'S';
     END IF;
     -- veo si no tiene cotizacion para el movimiento
     IF mv.cod_moneda <> v_cod_mon_local THEN
        IF mv.mto_equ_local is null THEN
           if mv.cod_moneda = pag_gen.fu_obt_mon_fuerte then
              v_cotizacion := v_cot_usd;
           else
              v_cotizacion := pag_gen.fu_obt_cotizacion(mv.cod_moneda);
           end if;
           v_redondeo_ml   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',mv.cod_mod_padre, mv.cod_mad_padre,v_cod_mon_local);
           v_mto_equ_local := ROUND(NVL(mv.monto,0)*NVL(v_cotizacion,0),v_redondeo_ml);
        END IF;
     ELSE
        -- si es moneda local, muevo el importe al equivalente en moneda local
        v_mto_equ_local := mv.monto;
        v_monto := 0;
     END IF;
     -- Grabo el movimiento contable en la tabla cb_asientos_tmp----
     v_grabar := v_grabar + 1; /* para hacer commit cada 100 */
     INSERT INTO cb_asientos_tmp
          (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
           monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
           cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
           cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
           nro_documento
           )
     VALUES
          (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, mv.cod_rubro,
           v_monto, v_mto_equ_local, mv.tip_mov_rubro, mv.cod_mod_padre,
           mv.cod_mad_padre, mv.cod_oficina, v_cotizacion, mv.cod_moneda,
           mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
           mv.cod_oficina, mv.nro_cuenta, mv.nro_documento);

     ---------------------------------------------------------------
      ------------------ INTEROFICINA --------------------
      ---------------------------
      IF v_cod_asi_interoficina = 'S' THEN
         -- Recuperar cuenta contable interoficina
         v_cod_rub_interoficina := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,mv.cod_moneda,mv.cod_oficina);
         if mv.tip_mov_rubro = 'D' then
            v_tip_mov_rubro_01 := 'C';
         else
            v_tip_mov_rubro_01 := 'D';
         end if;
         v_cod_rub_interoficina := substr(v_cod_rub_interoficina,1,10)||ltrim(to_char(mv.cod_ofi_origen,'000'))||substr(v_cod_rub_interoficina,14,2);
         INSERT INTO cb_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, v_cod_rub_interoficina,
               v_monto, v_mto_equ_local, v_tip_mov_rubro_01, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_oficina, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_oficina, mv.nro_cuenta, mv.nro_documento);


               v_lugar := 2;
         ---
         v_cod_rub_interoficina := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,mv.cod_moneda,mv.cod_ofi_origen);
         v_cod_rub_interoficina := substr(v_cod_rub_interoficina,1,10)||ltrim(to_char(mv.cod_oficina,'000'))||substr(v_cod_rub_interoficina,14,2);
         if mv.tip_mov_rubro = 'D' then
            v_tip_mov_rubro_01 := 'C';
         else
            v_tip_mov_rubro_01 := 'D';
         end if;
         INSERT INTO cb_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina,
               nro_cuenta, nro_documento
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, v_cod_rub_interoficina,
               v_monto, v_mto_equ_local, mv.tip_mov_rubro, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_ofi_origen, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_ofi_origen, mv.nro_cuenta, mv.nro_documento);
      END IF;

      v_lugar := 3;
      ---------------- FIN INTEROFICINA ------------------
  END LOOP; -- Fin del ciclo
exception
   when others then
       raise_application_error(-20000,'ERROR: en lp_pro_mov_contables '||sqlerrm);
end;  -- fin del procedimiento

-- Proc. que genera los asientos de acuerdo a las transacciones
PROCEDURE LP_PRO_MOV_X_TRANSACCIONES IS
v_cod_tip_asiento ge_tip_asientos.cod_tip_asiento%type;
v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%type;
v_cod_moneda      ge_movimientos.cod_moneda%type;
v_cod_usuario     ge_movimientos.cod_usuario%type;
v_hora            ge_movimientos.hora%type;
v_nro_secuencia   ge_movimientos.nro_secuencia%type;
V_COD_MODULO GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MODALIDAD GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
V_FECHA GE_MOVIMIENTOS.FECHA%TYPE;
V_COD_MAD_PADRE GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
V_COD_TRANSACCION GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_COD_OFI_ORIGEN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE;
V_AFECTA GE_TRANSACCIONES.AFECTA%TYPE;
V_NOM_RUTINA1 VARCHAR2(1000);
V_DETALLE GE_TRANSACCIONES.TIPO%TYPE;
V_HAY_ERROR VARCHAR2(1);
V_ERR_CLIENTE NUMBER(1);
V_RESIDENTE GE_TIP_DEUDORES.IND_RESIDENTE%TYPE;
V_COD_SECTOR GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE;
V_TIP_DEUDOR GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE;
V_COD_PLAZO GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
V_CAN_DIAS GE_PLZ_CONTABLES.CAN_DIAS%TYPE;
V_COD_OFICINA GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_MONTO GE_MOVIMIENTOS.MONTO%TYPE;
V_MTO_EQU_LOCAL GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE;
V_FEC_VALOR GE_MOVIMIENTOS.FEC_VALOR%TYPE;
V_COD_TRA_PADRE GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE;
V_REVERSADO GE_MOVIMIENTOS.REVERSADO%TYPE;
V_COD_MOD_PADRE GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
v_cod_ref_cambio ge_movimientos.cod_ref_cambio%type;
v_nro_documento2 ge_movimientos.nro_documento2%type;
v_cat_automatica ge_movimientos.nro_documento2%type;
v_cod_pro_contable number(3);
v_est_cuenta varchar2(1);
v_tip_cuenta varchar2(1);
v_tip_interes varchar2(1);
v_tip_renovacion varchar2(1);
v_cod_sit_contable number(30);
v_sigue char(1);
v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
cursor MOV_TRANSACCIONES IS
  select a.cod_modulo, a.cod_modalidad, a.cod_transaccion, cod_oficina, nro_cuenta,
         fecha, fec_valor, reversado,
         cod_mod_padre, cod_mad_padre, cod_tra_padre,
         cod_moneda, monto, cotizacion, mto_equ_local,
         cod_ofi_origen, cod_usuario, hora, nro_secuencia,
         cod_tip_asiento, a.cod_ref_cambio, a.nro_documento2,
         est_cuenta, mo.cod_pro_contable, cod_tip_asiento2,
         cod_sit_contable, nro_documento
    from ge_modalidades MO, ge_transacciones b, ge_movimientos a
   where (monto <> 0 OR mto_equ_local <> 0)
     and estado IN ('N','H')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.tipo IN ('C','D') -- solo debitos o creditos
     and (a.reversado = 'N' or (a.reversado='S' and (fecha > fec_valor or p_hora is not null)))
     AND a.cod_tra_padre not in (565,950,317,306)
     and a.cod_transaccion not in (760,560,196)
     and b.batch = 'B'
     AND a.COD_MODULO = MO.COD_MODULO
     AND a.COD_MODALIDAD = MO.COD_MODALIDAD
     and (b.cod_tip_asiento is not null or b.cod_tip_asiento2 is not null)
     AND cod_usuario = nvl(p_cod_usuario, cod_usuario)
     and cod_mod_padre = nvl(p_cod_mod_padre,cod_mod_padre)
     and cod_mad_padre = nvl(p_cod_mad_padre,cod_mad_padre)
     AND (cod_usuario = p_cod_usuario or p_cod_usuario is null)
     AND (fecha = p_fecha or p_fecha is null)
     AND (hora = p_hora OR p_hora IS NULL)
     AND (nro_secuencia = p_nro_secuencia OR p_nro_secuencia IS NULL)
   order by nro_cuenta;
-- asientos por transaccion
r_tp GE_TIP_ASIENTOS%rowtype;
CURSOR c_tip_asientos IS
   SELECT *
     FROM GE_TIP_ASIENTOS
    WHERE COD_TIP_ASIENTO in (v_cod_tip_asiento, v_cod_tip_asiento2)
      AND COD_MONEDA = v_cod_moneda
      and (tip_renovacion is null or tip_renovacion = v_tip_renovacion)
      and (tip_interes is null or tip_interes = v_tip_interes)
      and (cod_sit_contable is null or cod_sit_contable = v_cod_sit_contable)
      and ((nvl(v_tip_cuenta, 'x') = 'B' and tip_cuenta = v_tip_cuenta) or
           (nvl(v_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = v_tip_cuenta)))
      AND (nvl(cat_automatica,v_cat_automatica) = v_cat_automatica or cat_automatica is null)
      and (nvl(est_cuenta,v_est_cuenta) = v_est_cuenta or
           est_cuenta is null and v_est_cuenta is null)
      AND (COD_SEC_CONTABLE = v_cod_sector or COD_SEC_CONTABLE IS NULL)
      AND (IND_RESIDENTE = v_residente OR IND_RESIDENTE = 'X');
v_nro_cta_anterior VARCHAR2(15) := 'x';
wk_can_debitos number(5) := 0;
wk_can_creditos number(5) := 0;
v_cod_sec_rubro varchar2(3);
begin
  v_grabar := 0;
  v_hay_error := 'N';
  v_err_cliente := 0;
  -------------------------------------------
  open MOV_TRANSACCIONES;
  loop
     fetch MOV_TRANSACCIONES INTO
         v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
         v_nro_cuenta, v_fecha, v_fec_valor, v_reversado,
         v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre,
         v_cod_moneda, v_monto, v_cotizacion, v_mto_equ_local,
         v_cod_ofi_origen, v_cod_usuario, v_hora, v_nro_secuencia,
         v_cod_tip_asiento, v_cod_ref_cambio, v_nro_documento2,
         v_est_cuenta, v_cod_pro_contable, v_cod_tip_asiento2,
         v_cod_sit_contable, v_nro_documento;
     exit when MOV_TRANSACCIONES%notfound;
     v_cod_asi_interoficina := 'N';
     wk_can_debitos := 0;
     wk_can_creditos := 0;
     IF v_cod_oficina <> v_cod_ofi_origen THEN
         -- ES ASIENTO INTEROFICINA
         v_cod_asi_interoficina := 'S';
     END IF;
     -- veo si no tiene cotizacion para el movimiento------------------
     IF v_cod_moneda <> v_cod_mon_local THEN
        IF v_mto_equ_local is null THEN
           if v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
              v_cotizacion := v_cot_usd;
           else
              v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda);
           end if;
           v_redondeo_ml   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo, v_cod_modalidad,v_cod_mon_local);
           v_mto_equ_local := ROUND(NVL(v_monto,0)*NVL(v_cotizacion,0),v_redondeo_ml);
        END IF;
     ELSE
        -- si es moneda local, muevo el importe al equiv. en mon.local--
        v_mto_equ_local := v_monto;
        v_monto := 0;
     END IF;
     v_hay_error := 'N';
     -- si cambio la cuenta del cliente---------------------------------
   --
    -- if nvl(v_nro_cuenta,'0') <> nvl(v_nro_cta_anterior,'0') then
        v_nro_cta_anterior := v_nro_cuenta;
        --- asigno valores por defecto, por si exista cuenta cliente ---
        v_residente  := 'S';
        v_cod_sector := 'N';
        v_tip_deudor := '2';
        v_cod_plazo  := 0;
        v_tip_cuenta := null;
        --v_cod_sit_contable := null;
        --- Comun a todos los modulos-----------------------------------
        BEGIN
            SELECT lower(rtrim(RUTINA1)), TIPO, AFECTA
              INTO v_nom_rutina1, v_detalle, v_afecta
              FROM GE_TRANSACCIONES
             WHERE COD_MODULO = v_cod_modulo
               AND COD_MODALIDAD = v_cod_modalidad
               AND COD_TRANSACCION = v_cod_transaccion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_hay_error := 'S';
              raise_application_error(-20000,'Trans. no existe '||to_char(v_cod_modulo)||' '
                                      ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion));
        END;
        v_err_cliente := 0;
        v_cod_sec_rubro := '';
        IF v_hay_error = 'N' THEN
          --- busco el cliente principal de la cuenta ------------------
          IF v_nro_cuenta IS NOT NULL THEN
               BEGIN
                   SELECT GE_CLIENTES.RESIDENTE,
                          GE_CLIENTES.COD_SEC_CONTABLE,
                          GE_CLIENTES.COD_TIP_DEUDOR,
                          nvl(v_cod_sit_contable,GE_CUENTAS.COD_SIT_CONTABLE)
                     INTO v_residente, v_cod_sector, v_tip_deudor, v_cod_sit_contable
                     FROM GE_CLIENTES, GE_CTA_CLIENTES, GE_CUENTAS
                    WHERE GE_CUENTAS.NRO_CUENTA = v_nro_cuenta
                      AND GE_CTA_CLIENTES.NRO_CUENTA  = v_nro_cuenta
                      AND GE_CTA_CLIENTES.RELACION = 'P'
                      AND GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA;
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
                  ELSIF v_cod_modalidad in (33,34,36) THEN
                         SELECT FEC_VENCIMIENTO - FEC_APERTURA
                           INTO v_can_dias
                           FROM AH_CTA_CERTIFICADOS
                          WHERE COD_MODULO = v_cod_modulo
                            AND COD_MODALIDAD = v_cod_modalidad
                            AND COD_OFICINA = v_cod_oficina
                            AND NRO_CUENTA = v_nro_cuenta;
                            lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                  ELSIF v_cod_modalidad = 31 THEN
                    begin
                      select cod_sub_modalidad
                        into v_cod_sub_modalidad
                        from ah_cta_vistas
                       where cod_modulo = v_cod_modulo
                         and cod_modalidad = v_cod_modalidad
                         and nro_cuenta = v_nro_cuenta;
                     exception
                       when others then
                         v_cod_sub_modalidad := 1;
                     end;
                     begin
                       v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(v_cod_modulo)||trim(v_cod_modalidad)||trim(v_cod_sub_modalidad));
                     exception
                       when others then
                         v_tip_cuenta := null;
                     end;
                  ELSIF v_cod_modulo = 6 THEN
                     BEGIN
                     SELECT FEC_VENCIMIENTO - FEC_INICIO,
                            tipo, tip_interes, nvl(tip_renovacion,'A'),
                            nvl(v_est_cuenta,estado), FUP_OBT_SEC_RUBRO(cod_sec_credito)
                      INTO v_can_dias, v_tip_cuenta, v_tip_interes,
                           v_tip_renovacion, v_est_cuenta, v_cod_sec_rubro
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
                  ELSIF v_cod_modulo = 10 THEN
                     BEGIN
                     SELECT NVL(FEC_VENCIMIENTO - FEC_INICIO,0)
                           /* tipo, tip_interes, nvl(tip_renovacion,'A'),
                            nvl(v_est_cuenta,estado)*/
                      INTO v_can_dias--, v_tip_cuenta, v_tip_interes,
                           --v_tip_renovacion, v_est_cuenta
                      FROM MD_CTA_DOCUMENTOS
                     WHERE NRO_CUENTA = v_nro_cuenta;
                       lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                     EXCEPTION
                        WHEN no_data_found then
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                       END;

                  END IF;
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
        END IF;
      -- END IF;
      IF v_hay_error = 'N' and v_err_cliente = 0 then
          ------- ----------ciclo de ge_tip_asientos --------------
          IF c_tip_asientos%isopen then
             CLOSE c_tip_asientos;
          END IF;
          OPEN c_tip_asientos;
          v_sigue := 'N';
          LOOP   -- para cada registro de tipos de asientos
            FETCH c_tip_asientos INTO r_tp;
            v_tip_mov_rubro := r_tp.tip_movimiento;
            EXIT WHEN c_tip_asientos%notfound;
            ---Reemplaza el tipo de deudor -----------------------
            IF r_tp.IND_DEUDOR = 'S' THEN
              v_cod_rubro := SUBSTR(r_tp.COD_RUBRO,1,8)||
                            LTRIM(TO_CHAR(v_tip_deudor,'00'))||
                            SUBSTR(r_tp.COD_RUBRO,11,5);
            ELSE
              v_cod_rubro := r_tp.COD_RUBRO;
            END IF;
            ---Reemplaza el codigo del plazo-----------------------
            IF r_tp.IND_PLAZO = 'S' THEN
              v_cod_rubro := SUBSTR(v_cod_rubro,1,2)||
                            LTRIM(TO_CHAR(v_cod_plazo))||
                            SUBSTR(v_cod_rubro,4,12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_tp.IND_PRODUCTO = 'S' THEN
              v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                             LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                             SUBSTR(v_cod_rubro,14,2);
            END IF;
            IF substr(v_cod_rubro,11,3)  = 'SEC' THEN
               -- es solo para prestamos, para contabilizar por sector
               v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                             LTRIM(TO_CHAR(v_cod_sec_rubro,'000'))||
                             SUBSTR(v_cod_rubro,14,2);
            END IF;
           -------------------------------------------------
            IF v_sigue = 'S' THEN
             -- ya hubo otra linea interoficina
             if v_tip_movimiento <>  r_tp.TIP_MOVIMIENTO and r_tp.NRO_LINEA = 1 then
                v_sigue := 'N'; -- se apaga para que no genere interoficina
             end if;
            ELSE
             IF v_cod_asi_interoficina = 'S' AND r_tp.NRO_LINEA = 1 THEN
                v_tip_movimiento := r_tp.TIP_MOVIMIENTO;
                v_tip_mov_interoficina := r_tp.tip_movimiento; -- para el interoficina
                v_sigue    := 'S'; /* se hara interoficina */
             END IF;
            END IF;
            -----------------------------------------------------------
            v_grabar := v_grabar + 1; /* para hacer commit cada 100 */
            --
            IF r_tp.NRO_LINEA = 1 THEN
               v_cod_oficina_01 := v_cod_oficina;
            ELSE
               v_cod_oficina_01 := v_cod_ofi_origen;
            END IF;
            --
            if v_tip_mov_rubro = 'D' then
               wk_can_debitos := wk_can_debitos +1;
            else
               wk_can_creditos := wk_can_creditos + 1;
            end if;
            INSERT INTO cb_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento
              )
            VALUES
              (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rubro,
               v_monto, v_mto_equ_local, v_tip_mov_rubro, v_cod_mod_padre,
               v_cod_mad_padre, v_cod_oficina_01, v_cotizacion, v_cod_moneda,
               v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina_01,
               v_nro_cuenta, v_nro_documento);
            -----------------------------------------------------------
          END LOOP;
            ---------------------------
            IF v_cod_asi_interoficina = 'S' AND v_sigue = 'S' /*and wk_can_debitos <> wk_can_creditos*/  THEN
               -- tomo el tipo de movimiento de la linea 1
               v_tip_movimiento := v_tip_mov_interoficina;
               -- Recuperar cuenta contable interoficina
               v_cod_rub_interoficina := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,v_cod_moneda,v_cod_oficina);
               -------------------------------------------------------------
               --- VER SI EL TIPO DE MOVIMIENTO ES DE DEBITO O CREDITO
               ------------------------------------------------------------
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
               v_cod_rub_interoficina := substr(v_cod_rub_interoficina,1,10)||ltrim(to_char(v_cod_ofi_origen,'000'))||substr(v_cod_rub_interoficina,14,2);

               INSERT INTO cb_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rub_interoficina,
                   v_monto, v_mto_equ_local, v_tip_movimiento, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_oficina, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
                   v_nro_cuenta, v_nro_documento);
               -- Recuperar cuenta contable interoficina
               v_cod_rub_interoficina := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,v_cod_moneda,v_cod_ofi_origen);
               v_cod_rub_interoficina := substr(v_cod_rub_interoficina,1,10)||ltrim(to_char(v_cod_oficina,'000'))||substr(v_cod_rub_interoficina,14,2);

               INSERT INTO cb_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rub_interoficina,
                   v_monto, v_mto_equ_local, v_tip_mov_interoficina, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_ofi_origen, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_ofi_origen,
                   v_nro_cuenta, v_nro_documento);
            END IF;
            ---------------- FIN INTEROFICINA ------------------

          IF c_tip_asientos%ROWCOUNT = 0 THEN
            -- no existe asiento definido para la transaccion --
           IF (v_cod_modalidad <> 455 ) AND
               (v_cod_tip_asiento  NOT IN (124,111,535) OR
               v_cod_moneda <> v_cod_mon_local) THEN
             INSERT INTO cb_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   observacion,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, NULL,
                   v_monto, v_mto_equ_local, NULL, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_oficina, v_cotizacion, v_cod_moneda,
                   substr('No existe Asiento.p/: Asi='||to_char(v_cod_tip_asiento)||
                   ' Mon='||v_cod_moneda||' Sec='||v_cod_sector||' Res='||v_residente||
                   ' Deu='||to_char(v_tip_deudor)||
                   ' Cta='||v_nro_cuenta||' Tranp='||to_char(v_cod_tra_padre)||
                   ' Trans='||to_char(v_cod_modalidad)||'-'||
                   to_char(v_cod_transaccion)||' Usu='||v_cod_usuario||' Hor='||v_hora
                   || ' Sit='||pab_asi.fu_obt_des_sit_contable(v_cod_sit_contable)||
                   ' Est='||v_est_cuenta,1,1000),
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
                   v_nro_cuenta, v_nro_documento);
            END IF;
          END IF;
          IF c_tip_asientos%ISOPEN THEN
             CLOSE c_tip_asientos;
          END IF;
          if v_grabar > 99 then
             COMMIT;
             v_grabar := 0;
          end if;
       end if;
  end loop;
  close MOV_TRANSACCIONES;
exception
   when others then
      raise_application_error(-20000,'ERROR: PRB_GEN_BAL_ONLINE '||SQLERRM || ' ' || v_lugar);
end;

procedure LP_PRO_MOV_HISTORICOS is
cursor mov_hist is
   select a.fecha, a.cod_usuario, a.hora, a.nro_secuencia, b.cod_rubro,
          decode(a.cod_moneda, v_cod_mon_local,0,a.monto) monto,
          decode(a.cod_moneda, v_cod_mon_local,a.monto,mto_equ_local) mto_equ_local, b.tip_movimiento, cod_mod_padre,
          cod_mad_padre, b.cod_oficina cod_ofi_origen, cotizacion, cod_moneda,
          b.cod_oficina, nvl(c.nro_asi_real,b.nro_asiento) nro_asiento, b.nro_linea,
          a.cod_tra_padre,
          a.cod_modulo, a.cod_modalidad, a.cod_transaccion,
          b.cod_oficina cod_ofi_cta, a.nro_cuenta, a.NRO_DOCUMENTO
     from cb_asi_automaticos c,cb_asi_automaticos_det b, gv_movimientos a
    where (a.monto <> 0 OR a.mto_equ_local <> 0)
      and a.estado IN ('N','H')
      and (a.cod_usuario = p_cod_usuario/* or p_cod_usuario is null*/)
      and (a.fecha = p_fecha/* or p_fecha is null*/)
      and (a.hora = p_hora/* OR p_hora IS NULL*/)
      and a.FECHA = b.fecha
      and a.nro_documento4 = b.ref_movimiento
      and b.fecha = c.fecha
      and b.cod_oficina = c.cod_oficina
      and b.nro_asiento = c.nro_asiento
      and c.nro_asi_real is null
      and not exists
             (select 1
                from ge_movimientos
               where FECHA = a.fecha
                 and hora = a.hora
                 and cod_usuario = a.cod_usuario);

begin
   for mv in mov_hist loop

      INSERT INTO cb_asientos_tmp
        (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
         cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
         nro_asiento,nro_linea,
         cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
         nro_documento
        )
      VALUES
        (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, mv.cod_rubro,
         mv.monto, mv.mto_equ_local, mv.tip_movimiento, mv.cod_mod_padre,
         mv.cod_mad_padre, mv.cod_oficina, mv.cotizacion, mv.cod_moneda,
         mv.nro_asiento, mv.nro_linea,
         mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion, mv.cod_ofi_cta,
         mv.nro_cuenta, v_nro_documento);

   end loop;
end;

--Proc. que genera los asientos de acuerdo a los asientos manuales
PROCEDURE LP_PRO_MOV_MANUALES IS
  CURSOR c_asi_manuales IS
    SELECT c.fecha, c.cod_usuario, TO_CHAR(c.fec_insercion,'HH24:MI:SS') hora, b.nro_linea nro_secuencia, b.cod_rubro,
           b.mto_mon_rubro monto, b.mto_mon_local mto_equ_local, b.tip_movimiento, c.cod_modulo cod_mod_padre,
           c.cod_modalidad cod_mad_padre, b.cod_oficina cod_ofi_origen, b.val_cotizacion cotizacion,a.cod_moneda,
           b.cod_oficina, b.nro_asiento, b.nro_linea,
           NULL cod_tra_padre,
           NULL cod_modulo, NULL cod_modalidad, NULL cod_transaccion,
           b.cod_oficina cod_ofi_cta, NULL nro_cuenta, NULL NRO_DOCUMENTO
     FROM cb_asientos c,cb_asientos_det b, cb_rubros a
    WHERE cod_usuario = NVL(p_cod_usuario, cod_usuario)
      AND (c.fecha = p_fecha OR p_fecha IS NULL)
      AND (TO_CHAR(c.fec_insercion,'HH24:MI:SS') = p_hora OR p_hora IS NULL)
      AND b.fecha = c.fecha
      AND b.cod_oficina = c.cod_oficina
      AND b.nro_asiento = c.nro_asiento
      AND b.cod_rubro = a.cod_rubro
      AND c.fecha > v_fec_ult_cierre
      AND c.confirmado = 'S'
      AND c.actualizado = 'N';

BEGIN
  FOR reg IN c_asi_manuales LOOP
    INSERT INTO cb_asientos_tmp
        (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
         cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
         nro_asiento,nro_linea,
         cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
         nro_documento
        )
      VALUES
        (reg.fecha, reg.cod_usuario, reg.hora, reg.nro_secuencia, reg.cod_rubro,
         reg.monto, reg.mto_equ_local, reg.tip_movimiento, reg.cod_mod_padre,
         reg.cod_mad_padre, reg.cod_oficina, reg.cotizacion, reg.cod_moneda,
         reg.nro_asiento, reg.nro_linea,
         reg.cod_tra_padre, reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_ofi_cta,
         reg.nro_cuenta, v_nro_documento);
  END LOOP;
END;

--Proc. que genera los asientos de acuerdo a los asientos futuros
PROCEDURE LP_PRO_MOV_FUTUROS IS
  CURSOR c_asi_futuros is
    SELECT c.fecha, c.cod_usuario, TO_CHAR(c.fec_insercion,'HH24:MI:SS') hora, b.nro_linea nro_secuencia, b.cod_rubro,
          b.mto_mon_rubro monto, b.mto_mon_local mto_equ_local, b.tip_movimiento, c.cod_modulo cod_mod_padre,
          c.cod_modalidad cod_mad_padre, b.cod_oficina cod_ofi_origen, b.val_cotizacion cotizacion,a.cod_moneda,
          b.cod_oficina, NVL(c.nro_asi_real,b.nro_asiento) nro_asiento, b.nro_linea,
          NULL cod_tra_padre,
          NULL cod_modulo, NULL cod_modalidad, NULL cod_transaccion,
          b.cod_oficina cod_ofi_cta, NULL nro_cuenta, NULL NRO_DOCUMENTO
     FROM cb_asi_futuros c,cb_asi_futuros_det b, cb_rubros a
    WHERE cod_usuario = nvl(p_cod_usuario, cod_usuario)
      AND (c.fecha = p_fecha OR p_fecha IS NULL)
      AND (to_char(c.fec_insercion,'HH24:MI:SS') = p_hora OR p_hora IS NULL)
      AND b.fecha = c.fecha
      AND b.cod_oficina = c.cod_oficina
      AND b.nro_asiento = c.nro_asiento
      and b.cod_rubro = a.cod_rubro
      AND c.fecha > v_fec_ult_cierre
      AND c.confirmado = 'S'
      AND c.actualizado = 'N';

BEGIN
  FOR reg IN c_asi_futuros LOOP
    INSERT INTO cb_asientos_tmp
        (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
         cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
         nro_asiento,nro_linea,
         cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
         nro_documento
        )
      VALUES
        (reg.fecha, reg.cod_usuario, reg.hora, reg.nro_secuencia, reg.cod_rubro,
         reg.monto, reg.mto_equ_local, reg.tip_movimiento, reg.cod_mod_padre,
         reg.cod_mad_padre, reg.cod_oficina, reg.cotizacion, reg.cod_moneda,
         reg.nro_asiento, reg.nro_linea,
         reg.cod_tra_padre, reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_ofi_cta,
         reg.nro_cuenta, v_nro_documento);
  END LOOP;
END;

-- Genera los movimientos contables estimados de devengado a la fecha de proceso.
PROCEDURE LP_PRO_MOV_DEVENGADO IS

-- Cursores.
CURSOR c_mov_devengado IS
   SELECT p_fecha fecha, b.usu_insercion cod_usuario, TO_CHAR(b.fec_insercion,'HH24:MI:SS') hora, 1 nro_secuencia, b.cod_rubro,
          b.mto_mon_rubro monto, b.mto_mon_local mto_equ_local,
          b.tip_movimiento, b.cod_modulo cod_mod_padre, b.cod_modalidad cod_mad_padre, b.cod_oficina cod_ofi_origen, b.val_cotizacion cotizacion,
          a.cod_moneda cod_moneda, b.cod_oficina, NULL nro_asiento, NULL nro_linea, NULL cod_tra_padre, NULL cod_modulo, NULL cod_modalidad,
          NULL cod_transaccion, b.cod_oficina cod_ofi_cta, NULL nro_cuenta, NULL nro_documento
     FROM cb_asi_automaticos c,cb_asi_automaticos_det b, cb_rubros a
    WHERE b.fecha = c.fecha
      AND b.cod_oficina = c.cod_oficina
      AND b.nro_asiento = c.nro_asiento
      AND b.cod_rubro = a.cod_rubro
      AND trim(b.referencia) = 'DEVENG.'
      AND b.fecha = (SELECT MAX(ca.fecha) FROM cb_asi_automaticos ca);

BEGIN
   FOR mv IN c_mov_devengado LOOP

      INSERT INTO cb_asientos_tmp
        (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
         cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
         nro_asiento, nro_linea, cod_tra_padre, cod_modulo, cod_modalidad,
         cod_transaccion, cod_oficina, nro_cuenta, nro_documento)
      VALUES
        (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, mv.cod_rubro,
         mv.monto, mv.mto_equ_local, mv.tip_movimiento, mv.cod_mod_padre,
         mv.cod_mad_padre, mv.cod_oficina, mv.cotizacion, mv.cod_moneda,
         mv.nro_asiento, mv.nro_linea, mv.cod_tra_padre, mv.cod_modulo,
         mv.cod_modalidad, mv.cod_transaccion, mv.cod_ofi_cta, mv.nro_cuenta, v_nro_documento);
   END LOOP;
END;

-- Genera los movimientos por ajuste cambiario.
procedure lp_aju_dif_cambios is
  -- Variables.
   v_cod_oficina      NUMBER(03);
   v_sal_mon_local    NUMBER(16,2);
   v_sal_mon_rubro    NUMBER(16,2);
   v_cod_tip_cuenta   NUMBER(2);
   v_cod_ofi_matriz   NUMBER(3);
   v_tot_control      NUMBER;
   v_tot_acumulado    NUMBER;
   v_nro_linea        NUMBER;
   v_imp_dif_cambios  NUMBER;
   v_diferencia       NUMBER;
   v_tip_movimiento   VARCHAR2(1);
   v_tip_mov_contra   VARCHAR2(1);
   v_cod_rubro        VARCHAR2(15);
   v_aju_oficina      VARCHAR2(01);
   v_cod_rub_dif_cam  VARCHAR2(15);
   v_cod_moneda       VARCHAR2(3);
   v_cod_rub_utilidad VARCHAR2(15);
   v_cod_rub_perdida  VARCHAR2(15);
   -- Variables de corte.
   v_cot_corte         NUMBER;
   v_cod_ofi_corte     NUMBER(03);
   v_mto_aju_corte     NUMBER(22);
   v_tot_mon_ext_corte NUMBER(22,2);
   v_tot_mon_loc_corte NUMBER(22, 2);
   v_cod_rub_aju_corte VARCHAR2(15);
   v_cod_rub_corte     VARCHAR2(15) := '12';
   v_aju_corte         VARCHAR2(01) := 'N';
   v_cod_mon_corte     VARCHAR2(03);
   v_hay_asiento       VARCHAR2(1) := 'N';
   v_gen_cabecera      VARCHAR2(1) := 'N';
   v_lugar             VARCHAR2(300);

  -- Cursores.
  CURSOR c_aju_cambiario IS
    SELECT cb_rubros.cod_rubro,
           cod_oficina,
           ajustable,
           nvl(sal_mon_loc_ant, 0) + nvl(deb_mon_local, 0) - nvl(cre_mon_local, 0),
           nvl(sal_mon_rub_ant, 0) + nvl(deb_mon_rubro, 0) - nvl(cre_mon_rubro, 0),
           tipo, cod_moneda
      FROM cb_sal_oficinas_tmp, cb_rubros
     WHERE cb_sal_oficinas_tmp.cod_rubro = cb_rubros.cod_rubro
       AND imputable = 'S'
       AND (tipo IN (1, 2, 3, 4, 5, 9))
       AND substr(CB_RUBROS.cod_rubro,1,2) not in ('42','52')
       AND cod_moneda != v_cod_mon_local
       AND cb_sal_oficinas_tmp.usu_insercion = USER
     ORDER BY cod_moneda, cb_rubros.cod_rubro, cod_oficina;

  -- Procedimientos.
  PROCEDURE LP_OBT_RUB_AJUSTE(p_cod_rubro        IN CHAR,
                              p_cod_rub_utilidad IN OUT CHAR,
                              p_cod_rub_perdida  IN OUT CHAR) IS

    -- Variables.
    v_cod_sector    varchar2(01) := SUBSTR(p_cod_rubro, 1, 1);
    v_cod_capitulo  varchar2(01) := SUBSTR(p_cod_rubro, 2, 1);
    v_cod_grupo     varchar2(01) := SUBSTR(p_cod_rubro, 4, 1);
    v_sub_cuenta    varchar2(02) := SUBSTR(p_cod_rubro, 9, 2);
    v_tip_sub_cta   varchar2(1)  := 'P';
    v_nro_cuenta    varchar2(3)  := SUBSTR(p_cod_rubro, 6, 3);
    v_mod_interno   varchar2(3)  := substr(p_cod_rubro, 11, 3);

    CURSOR C1 IS
      SELECT COD_RUB_UTILIDAD, COD_RUB_PERDIDA
        FROM CB_AJUSTES
       WHERE COD_SECTOR = v_cod_sector
         AND COD_CAPITULO = v_cod_capitulo
         AND (COD_GRUPO = 'T' OR COD_GRUPO = v_cod_grupo)
         AND (NRO_CUENTA = v_nro_cuenta OR NRO_CUENTA IS NULL)
         AND (COD_SUBCUENTA = 'T' OR
             COD_SUBCUENTA IN (v_tip_sub_cta, v_sub_cuenta))
         AND (MOD_INTERNO = v_mod_interno OR MOD_INTERNO IS NULL)
       ORDER BY COD_GRUPO, NRO_CUENTA, COD_SUBCUENTA, MOD_INTERNO;
    R1 C1%ROWTYPE;
  BEGIN
    select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
    -- Busco las cuentas dif.cambios a ser asignadas --------------------
    IF (MOD(TO_NUMBER(v_sub_cuenta), 2) = 0) OR
       (v_sub_cuenta = '01' AND v_cod_sector || v_cod_capitulo <> '12') THEN
      v_tip_sub_cta := 'P';
    ELSE
      v_tip_sub_cta := 'I';
    END IF;
    IF C1%ISOPEN THEN
      CLOSE C1;
    END IF;
    OPEN C1;
    FETCH C1
      INTO R1;
    IF C1%NOTFOUND THEN
      CLOSE C1;
    END IF;
    p_cod_rub_utilidad := R1.COD_RUB_UTILIDAD;
    p_cod_rub_perdida  := R1.COD_RUB_PERDIDA;
    CLOSE C1;
  END;

BEGIN

  -- Inicializo las variables a ser utilizadas en el proceso.
  v_tot_acumulado := 0;
  v_nro_linea     := 0;
  v_tot_control   := 0;
  v_cod_mon_corte := 'WQX';
  --
  v_cod_rub_aju_corte := fug_obt_pardinamico('COD_RUB_TEMPORAL');
  -- Ciclo de lectura de las cuentas ordenado por Moneda,Cuenta,Of.
  OPEN c_aju_cambiario;
  v_mto_aju_corte     := 0;
  v_tot_mon_ext_corte := 0;
  v_tot_mon_loc_corte := 0;
  v_aju_corte         := 'N';
  LOOP
    FETCH c_aju_cambiario
      INTO v_cod_rubro,
           v_cod_oficina,
           v_aju_oficina,
           v_sal_mon_local,
           v_sal_mon_rubro,
           v_cod_tip_cuenta,
           v_cod_moneda;
    v_lugar := 'Despues del fectch CURX';
    EXIT WHEN c_aju_cambiario%notfound;
    IF v_cod_rubro <> v_cod_rub_corte THEN
      IF v_aju_corte = 'S' THEN
        /* hubo ajuste */
        IF NVL(v_tot_mon_ext_corte, 0) = 0 AND NVL(v_tot_mon_loc_corte, 0) IN (1, -1) THEN
          IF v_mto_aju_corte <> 0 THEN
            /* solo si se hara ajuste of.central*/
            /* hay que ajustar la ultima linea generada */
            v_mto_aju_corte := NVL(v_mto_aju_corte, 0) + NVL(v_tot_mon_loc_corte, 0);
          END IF;
          IF v_tip_movimiento = 'D' THEN
            /* si la ultima linea es debito */
            v_tot_mon_loc_corte := v_tot_mon_loc_corte * -1; /* cambio el signo*/
          END IF;
          UPDATE cb_asientos_tmp
             SET MTO_EQU_LOCAL = NVL(MTO_EQU_LOCAL, 0) + NVL(v_tot_mon_loc_corte, 0)
           WHERE FECHA = v_fec_actual
             AND COD_OFICINA = v_cod_ofi_corte
             AND NRO_LINEA IN (v_nro_linea, v_nro_linea - 1)
             AND OBSERVACION = 'AJUSTE CAMBIARIO'
             AND USU_INSERCION = USER;
        END IF;
      END IF;
      IF v_mto_aju_corte <> 0 THEN
        /* se debe ajustar en la ofC.Central */
        --- busca las cuentas de ajuste correspondientes ---------
        LP_OBT_RUB_AJUSTE(v_cod_rub_corte,
                          v_cod_rub_utilidad,
                          v_cod_rub_perdida);
        ----------------------------------------------------------
        IF v_mto_aju_corte > 0 THEN
          -- SE HACE credito a la cuenta puente
          v_diferencia      := v_mto_aju_corte;
          v_tip_movimiento  := 'C';
          v_tip_mov_contra  := 'D';
          v_cod_rub_dif_cam := v_cod_rub_perdida;
        ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia      := v_mto_aju_corte * -1;
          v_tip_movimiento  := 'D';
          v_tip_mov_contra  := 'C';
          v_cod_rub_dif_cam := v_cod_rub_utilidad;
        END IF;
        --
        v_nro_linea := v_nro_linea + 1;
        INSERT INTO cb_asientos_tmp
          (cod_ofi_origen,
           nro_linea,
           cod_rubro,
           mto_equ_local,
           monto,
           tip_mov_rubro,
           fecha,
           cod_usuario,
           hora,
           nro_secuencia,
           cod_mod_padre,
           cod_mad_padre,
           cod_moneda,
           observacion,
           cod_oficina)
        VALUES
          (v_cod_ofi_matriz,
           v_nro_linea,
           v_cod_rub_aju_corte,
           v_diferencia,
           0,
           v_tip_movimiento,
           v_fec_actual,
           user,
           to_char(sysdate, 'HH24:MM:SS'),
           v_nro_linea,
           2,
           21,
           v_cod_mon_local,
           'AJUSTE CAMBIARIO',
           v_cod_oficina);
        ---
        v_nro_linea := v_nro_linea + 1;
        INSERT INTO cb_asientos_tmp
          (cod_ofi_origen,
           nro_linea,
           cod_rubro,
           mto_equ_local,
           monto,
           tip_mov_rubro,
           fecha,
           cod_usuario,
           hora,
           nro_secuencia,
           cod_mod_padre,
           cod_mad_padre,
           cod_moneda,
           observacion,
           cod_oficina)
        VALUES
          (v_cod_ofi_matriz,
           v_nro_linea,
           v_cod_rub_dif_cam,
           v_diferencia,
           0,
           v_tip_mov_contra,
           v_fec_actual,
           user,
           to_char(sysdate, 'HH24:MM:SS'),
           v_nro_linea,
           2,
           21,
           v_cod_mon_local,
           'AJUSTE CAMBIARIO',
           v_cod_oficina);
      END IF;
      --- actualizo las variables para el siguiente corte ----
      v_cod_rub_corte     := v_cod_rubro;
      v_mto_aju_corte     := 0;
      v_tot_mon_ext_corte := 0;
      v_tot_mon_loc_corte := 0;
      v_aju_corte         := 'N';
    END IF;
    --- busco la cotizacion de la moneda solo si hubo cambio de moneda
    IF v_cod_mon_corte <> v_cod_moneda THEN
      v_cot_corte := FUG_OBT_COTIZACION(v_cod_moneda, v_fec_contab);
      v_cod_mon_corte := v_cod_moneda;
    END IF;
    --- Calculo el valor en M/L del saldol en M/e para si es necesario-
    v_imp_dif_cambios := NVL(v_sal_mon_rubro, 0) * NVL(v_cot_corte, 0) -
                         NVL(v_sal_mon_local, 0);
    v_imp_dif_cambios := ROUND(v_imp_dif_cambios, 0);
    -- voy calculando el consolidado de la cuenta -----------------------
    v_tot_mon_ext_corte := NVL(v_tot_mon_ext_corte, 0) + NVL(v_sal_mon_rubro, 0);
    v_tot_mon_loc_corte := NVL(v_tot_mon_loc_corte, 0) + (NVL(v_sal_mon_local, 0) + NVL(v_imp_dif_cambios, 0));
    ---------------------------------------------------------------------
    v_tot_acumulado := v_tot_acumulado + v_imp_dif_cambios;
    v_tot_control   := v_tot_control + ABS(v_imp_dif_cambios);
    v_diferencia    := 0;
    IF v_imp_dif_cambios != 0 THEN
      IF v_imp_dif_cambios > 0 THEN
        -- SE HACE DEBITO A LA CUENTA
        v_diferencia     := v_imp_dif_cambios;
        v_tip_movimiento := 'D';
      ELSE
        -- SE HACE CREDITO A LA CUENTA
        v_diferencia     := v_imp_dif_cambios * -1;
        v_tip_movimiento := 'C';
      END IF;
      v_hay_asiento  := 'S';
      v_gen_cabecera := 'S';
      -- carga detalles (1a. Linea)           --
      -- La cuenta que tuvo diferencia        --
      ------------------------------------------
      v_nro_linea := v_nro_linea + 1;
      v_lugar     := 'Genera cb_asientos_tmp';
      INSERT INTO cb_asientos_tmp
        (cod_ofi_origen,
         nro_linea,
         cod_rubro,
         mto_equ_local,
         monto,
         tip_mov_rubro,
         fecha,
         cod_usuario,
         hora,
         nro_secuencia,
         cod_mod_padre,
         cod_mad_padre,
         cod_moneda,
         observacion,
         cod_oficina)
      VALUES
        (v_cod_oficina,
         v_nro_linea,
         v_cod_rubro,
         v_diferencia,
         0,
         v_tip_movimiento,
         v_fec_actual,
         user,
         to_char(sysdate, 'HH24:MM:SS'),
         v_nro_linea,
         2,
         21,
         v_cod_mon_local,
         'AJUSTE CAMBIARIO',
         v_cod_oficina);
      -- guardo los valores para el ajuste de 1guarani si es necesario
      v_aju_corte  := 'S';
      v_cod_ofi_corte := v_cod_oficina;
      ----------------------------------------------------------------
      IF v_aju_oficina = 'S' THEN
        --- busca las cuentas de ajuste correspondientes ---------
        LP_OBT_RUB_AJUSTE(v_cod_rubro,
                          v_cod_rub_utilidad,
                          v_cod_rub_perdida);
        ----------------------------------------------------------
        IF v_tip_movimiento = 'D' THEN
          v_cod_rub_dif_cam := v_cod_rub_utilidad;
          v_tip_mov_contra  := 'C';
        ELSE
          v_cod_rub_dif_cam := v_cod_rub_perdida;
          v_tip_mov_contra  := 'D';
        END IF;
      ELSE
        v_cod_rub_dif_cam := v_cod_rub_aju_corte; /* cuenta puente de ajuste */
        IF v_tip_movimiento = 'D' THEN
          v_mto_aju_corte  := NVL(v_mto_aju_corte, 0) - NVL(v_diferencia, 0);
          v_tip_mov_contra := 'C';
        ELSE
          v_mto_aju_corte  := NVL(v_mto_aju_corte, 0) + NVL(v_diferencia, 0);
          v_tip_mov_contra := 'D';
        END IF;
      END IF;
      -----------------------------------------------
      -- carga detalle CUENTA DIFERENCIA DE CAMBIO --
      -----------------------------------------------
      v_nro_linea := v_nro_linea + 1;
      INSERT INTO cb_asientos_tmp
        (cod_ofi_origen,
         nro_linea,
         cod_rubro,
         mto_equ_local,
         monto,
         tip_mov_rubro,
         fecha,
         cod_usuario,
         hora,
         nro_secuencia,
         cod_mod_padre,
         cod_mad_padre,
         cod_moneda,
         observacion,
         cod_oficina)
      VALUES
        (v_cod_oficina,
         v_nro_linea,
         v_cod_rub_dif_cam,
         v_diferencia,
         0,
         v_tip_mov_contra,
         v_fec_actual,
         user,
         to_char(sysdate, 'HH24:MM:SS'),
         v_nro_linea,
         2,
         21,
         v_cod_mon_local,
         'AJUSTE CAMBIARIO',
         v_cod_oficina);
    END IF;
    ------------------------------------------------------------------
  END LOOP;
  CLOSE c_aju_cambiario;
  /* El ultimo corte leido */
  IF v_aju_corte = 'S' THEN
    /* hubo ajuste */
    IF NVL(v_tot_mon_ext_corte, 0) = 0 AND NVL(v_tot_mon_loc_corte, 0) IN (1, -1) THEN
      /* hay que ajustar la ultima linea generada */
      v_mto_aju_corte := NVL(v_mto_aju_corte, 0) + NVL(v_tot_mon_loc_corte, 0);
      IF v_tip_movimiento = 'D' THEN
        /* si la ultima linea es debito */
        v_tot_mon_loc_corte := v_tot_mon_loc_corte * -1; /* cambio el signo*/
      END IF;
      UPDATE cb_asientos_tmp
         SET MTO_EQU_LOCAL = NVL(MTO_EQU_LOCAL, 0) + NVL(v_tot_mon_loc_corte, 0)
       WHERE FECHA = v_fec_actual
         AND COD_OFICINA = v_cod_ofi_corte
         AND NRO_LINEA IN (v_nro_linea, v_nro_linea - 1)
         AND OBSERVACION = 'AJUSTE CAMBIARIO'
         AND USU_INSERCION = USER;
    END IF;
  END IF;
  IF v_mto_aju_corte <> 0 THEN
    /* se debe ajustar en la ofC.Central */
    IF v_mto_aju_corte > 0 THEN
      -- SE HACE credito a la cuenta puente
      v_diferencia      := v_mto_aju_corte;
      v_tip_movimiento  := 'C';
      v_tip_mov_contra  := 'D';
      v_cod_rub_dif_cam := v_cod_rub_perdida;
    ELSE
      -- SE HACE CREDITO A LA CUENTA
      v_diferencia      := v_mto_aju_corte * -1;
      v_tip_movimiento  := 'D';
      v_tip_mov_contra  := 'C';
      v_cod_rub_dif_cam := v_cod_rub_utilidad;
    END IF;
    --
    v_nro_linea := v_nro_linea + 1;
    INSERT INTO cb_asientos_tmp
      (cod_ofi_origen,
       nro_linea,
       cod_rubro,
       mto_equ_local,
       monto,
       tip_mov_rubro,
       fecha,
       cod_usuario,
       hora,
       nro_secuencia,
       cod_mod_padre,
       cod_mad_padre,
       cod_moneda,
       observacion,
       cod_oficina)
    VALUES
      (v_cod_ofi_matriz,
       v_nro_linea,
       v_cod_rub_aju_corte,
       v_diferencia,
       0,
       v_tip_movimiento,
       v_fec_actual,
       user,
       to_char(sysdate, 'HH24:MM:SS'),
       v_nro_linea,
       2,
       21,
       v_cod_mon_local,
       'AJUSTE CAMBIARIO',
       v_cod_oficina);
    ---
    v_nro_linea := v_nro_linea + 1;
    INSERT INTO cb_asientos_tmp
      (cod_ofi_origen,
       nro_linea,
       cod_rubro,
       mto_equ_local,
       monto,
       tip_mov_rubro,
       fecha,
       cod_usuario,
       hora,
       nro_secuencia,
       cod_mod_padre,
       cod_mad_padre,
       cod_moneda,
       observacion,
       cod_oficina)
    VALUES
      (v_cod_ofi_matriz,
       v_nro_linea,
       v_cod_rub_dif_cam,
       v_diferencia,
       0,
       v_tip_mov_contra,
       v_fec_actual,
       user,
       to_char(sysdate, 'HH24:MM:SS'),
       v_nro_linea,
       2,
       21,
       v_cod_mon_local,
       'AJUSTE CAMBIARIO',
       v_cod_oficina);
  END IF;

EXCEPTION
  WHEN VALUE_ERROR THEN
    CLOSE c_aju_cambiario;
  WHEN OTHERS THEN
    CLOSE c_aju_cambiario;
END;

-- Correcci�n de asientos. Rubro 555.
PROCEDURE lp_aju_asientos IS

-- Variables.
v_mto_acreedor NUMBER(18,2) := 0;
v_mto_deudor   NUMBER(18,2) := 0;
v_diferencia   NUMBER(18,2) := 0;

-- Cursores.
CURSOR c_oficinas IS
   SELECT DISTINCT cod_oficina
     FROM cb_sal_oficinas_tmp;

BEGIN

  -- Actualiza el Balance Online.
  FOR reg in c_oficinas LOOP
    v_mto_acreedor := 0;
    v_mto_deudor := 0;

    BEGIN
       -- Saldo de las Cuentas Deudoras.
       SELECT SUM(nvl((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)),0))
         INTO v_mto_deudor
         FROM cb_sal_oficinas_tmp s, cb_rubros cr
        WHERE s.cod_rubro = cr.cod_rubro
          AND cr.imputable = 'S'
          AND substr(cr.cod_rubro,1,1) = '1'
          AND s.usu_insercion = USER
          AND cod_oficina = reg.cod_oficina;

       -- Saldo de las Cuentas Acreedoras.
       SELECT SUM(nvl((nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)),0))
         INTO v_mto_acreedor
         FROM cb_sal_oficinas_tmp s, cb_rubros cr
        WHERE s.cod_rubro = cr.cod_rubro
          AND cr.imputable = 'S'
          AND substr(cr.cod_rubro,1,1) in ('2','3')
          AND s.usu_insercion = USER
          AND cod_oficina = reg.cod_oficina;
    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20000,'Error al buscar los Saldos Deudores y Acreedores de la Oficina '||reg.cod_oficina);
    END;

    -- Calculo el saldo actual.
    v_diferencia := nvl(v_mto_deudor,0) + nvl(v_mto_acreedor,0);

    -- Actualizo del Saldo del Balance Online.
    IF v_diferencia < 0 THEN
       UPDATE cb_sal_oficinas_tmp
          SET cre_mon_local   = NVL(cre_mon_local,0) + NVL(v_diferencia,0)
        WHERE cod_rubro = '240402600255599'
          AND usu_insercion = USER
          AND cod_oficina = reg.cod_oficina;
    ELSE
       UPDATE cb_sal_oficinas_tmp
          SET deb_mon_local   = NVL(deb_mon_local,0) - NVL(v_diferencia,0)
        WHERE cod_rubro = '240402600255599'
          AND usu_insercion = USER
          AND cod_oficina = reg.cod_oficina;
    END IF;
  END LOOP;
END;

-- Proc. que genera el balance en linea
PROCEDURE LP_PRO_BAL_LINEA IS
BEGIN
  --Obtener la fecha del ultimo cierre contable.
  SELECT MAX(fecha)
    INTO v_fec_ult_cierre
    FROM cb_sal_consolidados_dia;

  -- Genera los movimientos contables directos del d�a.
  lp_pro_mov_contables;
  -- Genera los movimientos contables por transacciones del d�a.
  lp_pro_mov_x_transacciones;
  -- Genera los movimientos contables manuales a la fecha de proceso.
  lp_pro_mov_manuales;
  -- Genera los movimientos contables futuros que correspondan a la fecha de proceso.
  lp_pro_mov_futuros;
  -- Genera los movimientos contables historicos que correspondan a la fecha de proceso.
  lp_pro_mov_historicos;
  -- Genera los movimientos contables estimados de devengado a la fecha de proceso.
  lp_pro_mov_devengado;
END;

PROCEDURE lp_sum_sal_oficinas(P_COD_OFICINA IN NUMBER,
                                P_NRO_CUENTA IN CHAR,
                                P_TIP_MOV IN CHAR,
                                P_MTO_LOCAL IN NUMBER,
                                P_MTO_FUERTE IN NUMBER,
                                P_COD_MONEDA IN VARCHAR2) IS
  v_nro_cuenta VARCHAR2(15);
  v_cod_rub_padre VARCHAR2(15);
  v_existe  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO v_nro_cuenta, v_cod_rub_padre
    FROM CB_RUBROS
   WHERE COD_RUBRO = P_NRO_CUENTA;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO v_nro_cuenta, v_cod_rub_padre
           FROM CB_RUBROS
          WHERE COD_RUBRO = v_cod_rub_padre;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN cb_sal_oficinas_tmp
                  ---------------------------------------------------------
                  SELECT 'X' INTO v_existe
                    FROM cb_sal_oficinas_tmp
                   WHERE COD_OFICINA = P_COD_OFICINA
                     AND COD_RUBRO = v_nro_cuenta
                     AND FECHA = P_FECHA
                     AND USU_INSERCION = USER
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA)
                                        VALUES (P_COD_OFICINA, v_nro_cuenta, P_FECHA);
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||v_nro_cuenta||' - Ofic '||P_COD_OFICINA||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   IF P_TIP_MOV = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE cb_sal_oficinas_tmp
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(P_COD_MONEDA,v_cod_mon_local,0,PAG_GEN.FU_CON_MON_A_MONEDA(P_COD_MONEDA,v_cod_mon_local,NVL(P_MTO_FUERTE,0)))
                       WHERE COD_OFICINA = P_COD_OFICINA
                         AND COD_RUBRO = v_nro_cuenta
                         AND FECHA = P_FECHA
                         AND USU_INSERCION = USER;
                   ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE cb_sal_oficinas_tmp
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(P_COD_MONEDA,v_cod_mon_local,0,PAG_GEN.FU_CON_MON_A_MONEDA(P_COD_MONEDA,v_cod_mon_local,NVL(P_MTO_FUERTE,0)))
                       WHERE COD_OFICINA = P_COD_OFICINA
                         AND COD_RUBRO = v_nro_cuenta
                         AND FECHA = P_FECHA
                         AND USU_INSERCION = USER;
                   END IF;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||P_NRO_CUENTA||' inexistente en Plan de Cuenta');
END;
  ---
PROCEDURE lp_ins_sal_oficinas(P_COD_OFICINA IN NUMBER,
                             P_NRO_CUENTA IN CHAR,
                             P_TIP_MOV IN CHAR,
                             P_MTO_LOCAL IN NUMBER,
                             P_MTO_FUERTE IN NUMBER,
                             WIMMOUSD IN NUMBER,
                             P_COD_MONEDA IN VARCHAR2) IS
  v_nro_cuenta VARCHAR2(15);
  v_cod_rub_padre VARCHAR2(15);
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO v_nro_cuenta, v_cod_rub_padre
    FROM CB_RUBROS
   WHERE COD_RUBRO = P_NRO_CUENTA;
  IF SQL%FOUND THEN
    IF P_COD_MONEDA <> v_cod_mon_local THEN
      V_MON_EQU_LOCAL := P_MTO_LOCAL;
    END IF;
    IF P_TIP_MOV = 'D' THEN
      -----------------------------------------------------------------
      -- INSERTA SALDO DE DEBITO
      -----------------------------------------------------------------
      INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA, DEB_MON_LOCAL, DEB_MON_RUBRO,
                           DEB_EQU_LOCAL)
                   VALUES (P_COD_OFICINA, v_nro_cuenta, P_FECHA, P_MTO_LOCAL, P_MTO_FUERTE,
                           V_MON_EQU_LOCAL);
    ELSE
      -----------------------------------------------------------------
      -- INSERTA SALDO DE CREDITO
      -----------------------------------------------------------------
      INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA, CRE_MON_LOCAL, CRE_MON_RUBRO,
                           CRE_EQU_LOCAL)
                   VALUES (P_COD_OFICINA, v_nro_cuenta,P_FECHA, P_MTO_LOCAL, P_MTO_FUERTE,
                           V_MON_EQU_LOCAL);
    END IF;
    lp_sum_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,WIMMOUSD,P_COD_MONEDA);
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||P_NRO_CUENTA||
        ' inexistente en Plan de Cuentas Consolidado');
END;

PROCEDURE lp_act_sal_oficinas(P_COD_OFICINA IN NUMBER,
                              P_NRO_CUENTA IN CHAR,
                              P_TIP_MOV IN CHAR,
                              P_MTO_LOCAL IN NUMBER,
                              P_MTO_FUERTE IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              P_COD_MONEDA IN VARCHAR2) IS
  v_existe   CHAR(1);
BEGIN
  SELECT 'X' INTO v_existe
    FROM cb_sal_oficinas_tmp
   WHERE COD_OFICINA = P_COD_OFICINA
     AND COD_RUBRO = P_NRO_CUENTA
     AND FECHA = P_FECHA
     AND USU_INSERCION = USER
     FOR UPDATE OF COD_RUBRO;
  IF SQL%FOUND THEN
    IF P_TIP_MOV = 'D' THEN
      ------------------------------------------------------------
      -- ACTUALIZA POR MOVIMIENTO DE DEBITO
      ------------------------------------------------------------
      UPDATE cb_sal_oficinas_tmp
        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(P_COD_MONEDA,v_cod_mon_local,0,PAG_GEN.FU_CON_MON_A_MONEDA(P_COD_MONEDA,v_cod_mon_local,NVL(P_MTO_FUERTE,0)))
      WHERE COD_OFICINA = P_COD_OFICINA
        AND COD_RUBRO = P_NRO_CUENTA
        AND FECHA = P_FECHA
        AND USU_INSERCION = USER;
      lp_sum_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,WIMMOUSD,P_COD_MONEDA);
    ELSE
      ------------------------------------------------------------
      -- ACTUALIZA POR MOVIMIENTO DE CREDITO
      ------------------------------------------------------------
      UPDATE cb_sal_oficinas_tmp
        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(P_COD_MONEDA,v_cod_mon_local,0,PAG_GEN.FU_CON_MON_A_MONEDA(P_COD_MONEDA,v_cod_mon_local,NVL(P_MTO_FUERTE,0)))
      WHERE COD_OFICINA = P_COD_OFICINA
        AND COD_RUBRO = P_NRO_CUENTA
        AND FECHA = P_FECHA
        AND USU_INSERCION = USER;
      lp_sum_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,WIMMOUSD,P_COD_MONEDA);
    END IF;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ----------------------------------------------------------------
    -- NO ENCONTRO REGISTRO EN cb_sal_oficinas_tmp POR LO TANTO SE DEBE INSERTAR
    -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
    ----------------------------------------------------------------
    BEGIN
      SELECT 'X'
        INTO v_existe
        FROM CB_RUB_OFICINAS_TMP
       WHERE COD_OFICINA = P_COD_OFICINA
         AND COD_RUBRO = P_NRO_CUENTA
         AND USU_INSERCION = USER;
      IF SQL%FOUND THEN
        lp_ins_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,P_MTO_FUERTE,WIMMOUSD,P_COD_MONEDA);
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         lp_ins_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,P_MTO_FUERTE,WIMMOUSD,P_COD_MONEDA);
    END;
END;

PROCEDURE lp_con_sal_oficinas(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              p_sal_mon_loc_ant in number,
                              p_deb_mon_local in number,
                              p_cre_mon_local  in number,
                              p_sal_mon_rub_ant in number,
                              p_deb_mon_rubro in number,
                              p_cre_mon_rubro in number,
                              p_sal_equ_loc_ant in number,
                              p_deb_equ_local in number,
                              p_cre_equ_local in number) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN cb_sal_oficinas_tmp
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM cb_sal_oficinas_tmp
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND FECHA = P_FECHA
                     AND USU_INSERCION = USER
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA)
                                        VALUES (WCDOFICI, CDCUENT, P_FECHA);
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                    ----------------------------------------
                      UPDATE cb_sal_oficinas_tmp
                        SET sal_mon_loc_ant = nvl(sal_mon_loc_ant,0) + nvl(p_sal_mon_loc_ant,0),
                            deb_mon_local = nvl(deb_mon_local,0) + nvl(p_deb_mon_local,0),
                            cre_mon_local =  nvl(cre_mon_local,0) + nvl(p_cre_mon_local,0),
                            sal_mon_rub_ant = nvl(sal_mon_rub_ant,0) + nvl(p_sal_mon_rub_ant,0),
                            deb_mon_rubro = nvl(deb_mon_rubro,0) + nvl(p_deb_mon_rubro,0),
                            cre_mon_rubro = nvl(cre_mon_rubro,0) + nvl(p_cre_mon_rubro,0),
                            sal_equ_loc_ant = nvl(sal_equ_loc_ant,0) + nvl(p_sal_equ_loc_ant,0),
                            deb_equ_local = nvl(deb_equ_local,0) + nvl(p_deb_equ_local,0),
                            cre_equ_local = nvl(cre_equ_local,0) + nvl(p_cre_equ_local,0)
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND FECHA = P_FECHA
                         AND USU_INSERCION = USER;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||' inexistente en Plan de Cuenta');
  END;

-- Proc. que genera los saldos consolidados.
PROCEDURE LP_CON_BAL_LINEA IS
  -- Variables.
  v_cod_oficina     ba_oficinas.cod_oficina%type;
  v_nro_cuenta      cb_asientos_tmp.nro_cuenta%type;
  v_tip_movimiento  cb_asientos_tmp.tip_mov_rubro%type;
  v_des_oficina     ba_oficinas.descripcion%type;
  v_mto_local       cb_asientos_tmp.monto%type;
  v_mto_extranjero  cb_asientos_tmp.monto%type;
  v_mto_fuerte      cb_asientos_tmp.monto%type;
  v_cod_moneda      ba_monedas.cod_moneda%type;

  -- Cursores.
  CURSOR c_mov_contables IS
     SELECT cb_asientos_tmp.cod_oficina, cb_asientos_tmp.cod_rubro,
            cb_asientos_tmp.tip_mov_rubro, ba_oficinas.descripcion,
            decode(cb_asientos_tmp.cod_moneda,v_cod_mon_local,sum(nvl(cb_asientos_tmp.mto_equ_local,0)),0),
            decode(cb_asientos_tmp.cod_moneda,v_cod_mon_local,0,sum(nvl(cb_asientos_tmp.monto,0))),
            decode(substr(cb_rubros.cod_rubro,14,2),'98',v_cod_mon_fuerte,cb_rubros.cod_moneda)
       FROM cb_rubros, cb_asientos_tmp, ba_oficinas
      WHERE cb_asientos_tmp.cod_oficina = ba_oficinas.cod_oficina
        AND cb_rubros.cod_rubro = cb_asientos_tmp.cod_rubro
        AND cb_asientos_tmp.usu_insercion = USER
        AND cb_asientos_tmp.actualizado = 'N'
      GROUP BY cb_asientos_tmp.cod_oficina, cb_asientos_tmp.cod_rubro,
               cb_asientos_tmp.tip_mov_rubro, ba_oficinas.descripcion,
               cb_asientos_tmp.cod_moneda,
               decode(substr(cb_rubros.cod_rubro,14,2),'98',v_cod_mon_fuerte,cb_rubros.cod_moneda);

  -- Obtiene los saldos para actualizar el saldo anterior.
  CURSOR c_act_saldo IS
  SELECT b.cod_oficina, b.cod_rubro,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_local,0) - decode(b.tip_movimiento,'C',b.mto_mon_local,0)) mto_mon_local,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_rubro,0) - decode(b.tip_movimiento,'C',b.mto_mon_rubro,0)) mto_mon_rubro
    FROM cb_asientos_det b, cb_asientos c
   WHERE b.fecha = c.fecha
     AND b.cod_oficina = c.cod_oficina
     AND b.nro_asiento = c.nro_asiento
     AND c.fecha > v_fec_ult_cierre
     AND c.fecha <= p_fecha
     AND c.confirmado = 'S'
     AND c.actualizado = 'N'
   GROUP BY b.cod_oficina, b.cod_rubro;

  CURSOR c_act_saldo_01 IS
  SELECT b.cod_oficina, b.cod_rubro,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_local,0) - decode(b.tip_movimiento,'C',b.mto_mon_local,0)) mto_mon_local,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_rubro,0) - decode(b.tip_movimiento,'C',b.mto_mon_rubro,0)) mto_mon_rubro
    FROM cb_asi_automaticos_det b,
         cb_asi_automaticos     c
   WHERE b.fecha = c.fecha
     AND b.cod_oficina = c.cod_oficina
     AND b.nro_asiento = c.nro_asiento
     AND c.fecha > v_fec_ult_cierre
     AND c.fecha <= p_fecha
     AND c.nro_asi_real IS NULL
   GROUP BY b.cod_oficina, b.cod_rubro;

  CURSOR c_act_saldo_02 IS
  SELECT b.cod_oficina, b.cod_rubro,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_local,0) - decode(b.tip_movimiento,'C',b.mto_mon_local,0)) mto_mon_local,
         SUM(decode(b.tip_movimiento,'D',b.mto_mon_rubro,0) - decode(b.tip_movimiento,'C',b.mto_mon_rubro,0)) mto_mon_rubro
    FROM cb_asi_futuros_det b, cb_asi_futuros c
   WHERE b.fecha = c.fecha
     AND b.cod_oficina = c.cod_oficina
     AND b.nro_asiento = c.nro_asiento
     AND c.fecha > v_fec_ult_cierre
     AND c.fecha <= p_fecha
     AND c.nro_asi_real IS NULL
   GROUP BY b.cod_oficina, b.cod_rubro;

  -- Procedimientos.
  PROCEDURE lp_act_asientos(P_COD_OFICINA IN NUMBER,
                            P_COD_RUBRO   IN VARCHAR2,
                            P_TIP_MOV     IN VARCHAR2) IS
  BEGIN
    UPDATE cb_asientos_tmp
       SET cb_asientos_tmp.actualizado = 'S'
     WHERE cb_asientos_tmp.cod_oficina   = p_cod_oficina
       AND cb_asientos_tmp.cod_rubro     = p_cod_rubro
       AND cb_asientos_tmp.tip_mov_rubro = p_tip_mov
       AND cb_asientos_tmp.actualizado   = 'N';
  END;

BEGIN
  -- inicializar el saldo anterior
  INSERT INTO cb_sal_oficinas_tmp(cod_oficina, cod_rubro, fecha, sal_mon_loc_ant,
                                  sal_mon_rub_ant, deb_mon_local, cre_mon_local,deb_mon_rubro,cre_mon_rubro,
                                  sal_equ_loc_ant, deb_equ_local, cre_equ_local, usu_insercion)
  (SELECT cod_oficina, cod_rubro, p_fecha, (nvl(sal_mon_loc_ant,0) + nvl(deb_mon_local,0) - nvl(cre_mon_local,0)),
          (nvl(sal_mon_rub_ant,0) + nvl(deb_mon_rubro,0) - nvl(cre_mon_rubro,0)), 0, 0,0, 0,
          (nvl(sal_equ_loc_ant,0) + nvl(deb_equ_local,0) - nvl(cre_equ_local,0)) ,0,0,user
     FROM cb_sal_oficinas);

  -- inserto los rubros nuevos.
  insert into cb_sal_oficinas_tmp
  select distinct b.cod_oficina, b.cod_rubro, p_fecha, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asi_automaticos_det b,
         cb_asi_automaticos     c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha <= p_fecha
     and c.nro_asi_real is null
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro)
  union
  select distinct b.cod_oficina, b.cod_rubro, p_fecha, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asientos_det b, cb_asientos c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha <= p_fecha
     and c.confirmado = 'S'
     and c.actualizado = 'N'
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro)
  union
  select distinct b.cod_oficina, b.cod_rubro, p_fecha, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asi_futuros_det b, cb_asi_futuros c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha <= p_fecha
     and c.nro_asi_real is null
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro);

  -- Actualiza el saldo anterior con los movimientos hasta la fecha de proceso
  FOR reg IN c_act_saldo LOOP
     update cb_sal_oficinas_tmp a
        set a.sal_mon_loc_ant = nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0) + NVL(reg.mto_mon_local,0),
            a.sal_mon_rub_ant = nvl(a.sal_mon_rub_ant, 0) + nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0) + NVL(reg.mto_mon_rubro,0)
      where a.cod_oficina = reg.cod_oficina
        and a.cod_rubro = reg.cod_rubro
        and a.fecha = p_fecha
        and a.usu_insercion = user;
  END LOOP;

  FOR reg IN c_act_saldo_01 LOOP
     update cb_sal_oficinas_tmp a
        set a.sal_mon_loc_ant = nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0) + NVL(reg.mto_mon_local,0),
            a.sal_mon_rub_ant = nvl(a.sal_mon_rub_ant, 0) + nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0) + NVL(reg.mto_mon_rubro,0)
      where a.cod_oficina = reg.cod_oficina
        and a.cod_rubro = reg.cod_rubro
        and a.fecha = p_fecha
        and a.usu_insercion = user;

  END LOOP;

  FOR reg IN c_act_saldo_02 LOOP
     update cb_sal_oficinas_tmp a
        set a.sal_mon_loc_ant = nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0) + NVL(reg.mto_mon_local,0),
            a.sal_mon_rub_ant = nvl(a.sal_mon_rub_ant, 0) + nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0) + NVL(reg.mto_mon_rubro,0)
      where a.cod_oficina = reg.cod_oficina
        and a.cod_rubro = reg.cod_rubro
        and a.fecha = p_fecha
        and a.usu_insercion = user;

  END LOOP;

  If c_mov_contables%ISOPEN THEN
    close c_mov_contables;
  End if;

  Open c_mov_contables;
  Loop
    Fetch c_mov_contables INTO v_cod_oficina, v_nro_cuenta, v_tip_movimiento, v_des_oficina, v_mto_local, v_mto_extranjero, v_cod_moneda;
    v_mto_fuerte := PAG_GEN.FU_CON_MON_A_MONEDA(v_cod_moneda,v_cod_mon_fuerte,v_mto_extranjero);
    EXIT WHEN c_mov_contables%notfound;
    If c_mov_contables%FOUND THEN
      lp_act_sal_oficinas(v_cod_oficina, v_nro_cuenta, v_tip_movimiento, v_mto_local, v_mto_extranjero,v_mto_fuerte,v_cod_moneda);
    End if;
    lp_act_asientos(v_cod_oficina, v_nro_cuenta, v_tip_movimiento);
  End loop;

  -- genera los movimientos por ajuste cambiario
  lp_aju_dif_cambios;

  If c_mov_contables%ISOPEN THEN
     CLOSE c_mov_contables;
  End if;

  Open c_mov_contables;
  Loop
    Fetch c_mov_contables INTO v_cod_oficina, v_nro_cuenta, v_tip_movimiento, v_des_oficina, v_mto_local, v_mto_extranjero, v_cod_moneda;
    v_mto_fuerte := PAG_GEN.FU_CON_MON_A_MONEDA(v_cod_moneda,v_cod_mon_fuerte,v_mto_extranjero);
    EXIT WHEN c_mov_contables%notfound;
    If c_mov_contables%FOUND THEN
      lp_act_sal_oficinas(v_cod_oficina, v_nro_cuenta, v_tip_movimiento, v_mto_local, v_mto_extranjero,v_mto_fuerte,v_cod_moneda);
    End if;
    lp_act_asientos(v_cod_oficina, v_nro_cuenta, v_tip_movimiento);
  End loop;

  If c_mov_contables%ISOPEN THEN
     CLOSE c_mov_contables;
  End if;

  lp_aju_asientos;

END;

PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
-- inicio del proceso principal
BEGIN

  -- Verifica el rol del usuario y el horario de ejecuci�n.
  IF fug_val_usu_rol('CBD_ROL_GEN_BAL_ONLINE', USER) = FALSE THEN
     IF to_char(sysdate,'HH24:MI:SS') NOT BETWEEN v_hor_inicio AND v_hor_fin THEN
        raise_application_error(-20000, 'El horario permitido para la generaci�n del Balance Online es de '||v_hor_inicio||' a '||v_hor_fin||' '||sqlerrm);
     END IF;
  END IF;

  v_lugar := 1;
  -- borro solo los del usuario
  DELETE FROM cb_asientos_tmp WHERE usu_insercion = USER;
  DELETE FROM cb_sal_oficinas_tmp WHERE usu_insercion = USER;
  DELETE FROM cb_sal_consolidados_tmp WHERE usu_insercion = USER;

  v_lugar := 2;
  IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
  END IF;

  -- procesa los asientos para el balance
  v_lugar := 8;
  lp_pro_bal_linea;
  -- proceso que genera los saldos consolidados
  v_lugar := 9;
  lp_con_bal_linea;
  -- Sumarizo las cuentas padres.
  v_lugar := 10;
  prb_sum_sal_oficinas_tmp;
  -- Calculo el balance consolidado.
  v_lugar := 11;
  prb_sum_sal_consolidados_tmp;

  COMMIT;
END PRB_GEN_BAL_ONLINE;
/

