create or replace procedure it.PRG_GEN_ASIENTOS_TMP_ANT
   (P_FECHA IN DATE            DEFAULT NULL,    -- fecha de movimiento
    P_HORA IN VARCHAR2         DEFAULT NULL,    -- hora del movimiento
    P_COD_USUARIO IN VARCHAR2  DEFAULT NULL,    -- usuario del movimiento
    P_NRO_SECUENCIA IN NUMBER  DEFAULT NULL,    -- nro de secuencia del movimiento
    P_COD_OFI_ORIGEN IN NUMBER DEFAULT NULL,    -- oficina origen del movimiento
    P_COD_MOD_PADRE IN NUMBER  DEFAULT NULL,    -- modulo padre del movimiento
    P_COD_MAD_PADRE IN NUMBER  DEFAULT NULL,    -- modalidad padre del movimiento
    P_ELI_ASI_VALIDOS IN VARCHAR2 DEFAULT 'N') is -- para eliminar o no los asientos validos
-- OBJETIVO   : Generar una simulacion de los asientos a ser generados por IT GF.
--              Al finalizar este proceso se generara la tabla ge_asientos_tmp,
--              que contendra
-- PROGRAMADOR: Agustin Meza
-- FECHA      : 09/Feb/2005
-- VERSION: 08/09/2009 Agrego el NRO_DOCUMENTO en GE_ASIENTOS_TMP: Ingrid Larra�n

-- Definicion de variables
wk_lgofici      varchar2(1) := 'N';
wk_cdctaco      varchar2(20);
vh_cod_oficina  number(4);
wk_tip_mov_rubro varchar2(1);
v_tip_movimiento varchar2(1);
x_tip_movimiento varchar2(1);
--
v_monto         ge_movimientos.monto%type;
v_cotizacion    ge_cotizaciones.val_conversion%type;
v_cot_usd       ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(pag_gen.fu_obt_mon_fuerte);
v_mto_equ_local ge_movimientos.mto_equ_local%type;
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
v_tip_mov_rubro ge_movimientos.tip_mov_rubro%type;
v_cod_rubro     ge_movimientos.cod_rubro%type;
v_nro_documento ge_movimientos.nro_documento%type;
v_fec_actual    date := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_grabar        number(4) := 0;
v_msj varchar2(3000);
v_redondeo_ml   number(5);

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

-- borrado de asientos que balancean
PROCEDURE LP_ELI_ASI_BALANCEADOS IS
   CURSOR c1 IS
     SELECT COD_MOD_PADRE, COD_MAD_PADRE, COD_OFI_ORIGEN, FECHA, COD_USUARIO, HORA,
            SUM(DECODE(TIP_MOV_RUBRO,'D',MTO_EQU_LOCAL,0)) "W_TOTDEBE",
            SUM(DECODE(TIP_MOV_RUBRO,'C',MTO_EQU_LOCAL,0)) "W_TOTHABE"
       FROM GE_ASIENTOS_TMP
      WHERE TIP_MOV_RUBRO IS NOT NULL
      GROUP BY COD_MOD_PADRE, COD_MAD_PADRE, COD_OFI_ORIGEN, FECHA, COD_USUARIO, HORA
      HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO,'D',MTO_EQU_LOCAL,0)),0) =
             NVL(SUM(DECODE(TIP_MOV_RUBRO,'C',MTO_EQU_LOCAL,0)),0);
 REG c1%ROWTYPE;
BEGIN
  OPEN C1;
  LOOP
    FETCH C1 INTO REG;
    EXIT WHEN C1%NOTFOUND;
    IF REG.W_TOTDEBE = REG.W_TOTHABE THEN
       DELETE GE_ASIENTOS_TMP
        WHERE COD_MOD_PADRE = REG.COD_MOD_PADRE
          AND COD_MAD_PADRE = REG.COD_MAD_PADRE
          AND COD_OFI_ORIGEN = REG.COD_OFI_ORIGEN
          AND FECHA = REG.FECHA
          AND COD_USUARIO = REG.COD_USUARIO
          AND HORA = REG.HORA
          AND USU_INSERCION = USER;
    END IF;
  END LOOP;
  CLOSE C1;
exception
   when others then
       Raise_application_error(-20000,'ERROR: en Borrado Asientos '||sqlerrm);
END;

-- Proc. que genera los movimientos imputados directamente a cuentas contables
PROCEDURE LP_PRO_MOV_CONTABLES IS
cursor MOV_CONTABLES is
    select fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
           monto, mto_equ_local, tip_mov_rubro, cod_moneda,
           cod_modulo, cod_modalidad, cod_transaccion, nro_cuenta,
           cod_mod_padre, cod_mad_padre, cod_ofi_origen, cotizacion,
           cod_oficina, cod_tra_padre, nro_documento
      from ge_movimientos_ant
     where (monto <> 0 OR mto_equ_local <> 0)
       --and usu_insercion <> 'IT' -- para evitar interface
       and estado IN ('N','H')
       and cod_rubro IS NOT NULL
       and cod_mod_padre = nvl(p_cod_mod_padre,cod_mod_padre)
       and cod_mad_padre = nvl(p_cod_mad_padre,cod_mad_padre)
       and (reversado = 'N' or (reversado='S' and p_hora is not null))
       --and cod_tra_padre = 364
       AND (cod_usuario = p_cod_usuario or p_cod_usuario is null)
       AND (fecha = p_fecha or p_fecha is null)
       AND (hora = p_hora OR p_hora IS NULL)
       AND (nro_secuencia = p_nro_secuencia OR p_nro_secuencia IS NULL);
       -- solo temporal para que genere solo cuentas a plazo
       --and cod_mad_padre in (33,34,35,91);


begin
  -- ciclo de movimientos
  FOR mv IN mov_contables LOOP
     -- montos del movimiento
     v_monto         := mv.monto;
     v_cotizacion    := mv.cotizacion;
     v_mto_equ_local := mv.mto_equ_local;
     wk_lgofici := 'N';
     ----------------------------------------
     IF mv.cod_oficina <> mv.cod_ofi_origen THEN
         -- ES ASIENTO INTEROFICINA
         wk_lgofici := 'S';
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
     -- Grabo el movimiento contable en la tabla ge_asientos_tmp----
     v_grabar := v_grabar + 1; /* para hacer commit cada 100 */
     INSERT INTO ge_asientos_tmp
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
      IF wk_lgofici = 'S' THEN
         -- Recuperar cuenta contable interoficina
         wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,mv.cod_moneda,mv.cod_oficina);
         if mv.tip_mov_rubro = 'D' then
            wk_tip_mov_rubro := 'C';
         else
            wk_tip_mov_rubro := 'D';
         end if;
         wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv.cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);
         INSERT INTO ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, wk_cdctaco,
               v_monto, v_mto_equ_local, wk_tip_mov_rubro, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_oficina, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_oficina, mv.nro_cuenta, mv.nro_documento);
         ---
         wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,mv.cod_moneda,mv.cod_ofi_origen);
         wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv.cod_oficina,'000'))||substr(wk_cdctaco,14,2);
         if mv.tip_mov_rubro = 'D' then
            wk_tip_mov_rubro := 'C';
         else
            wk_tip_mov_rubro := 'D';
         end if;
         INSERT INTO ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina,
               nro_cuenta, nro_documento
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, wk_cdctaco,
               v_monto, v_mto_equ_local, mv.tip_mov_rubro, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_ofi_origen, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_ofi_origen, mv.nro_cuenta, mv.nro_documento);
      END IF;
      ---------------- FIN INTEROFICINA ------------------

/*     IF mv.cod_transaccion IN (592,630) AND mv.cod_moneda = v_cod_mon_local then
        --- son casos excepcionales de generacion de asientos ------
        IF mv.cod_transaccion = 592 THEN
           v_tip_mov_rubro := 'C';
           v_cod_rubro := '111201110200099';
        ELSE
           v_tip_mov_rubro := 'D';
           v_cod_rubro := '250202780100099';
        END IF;
        -- situacion especial de cheques a compensar(totales) ------
        v_grabar := v_grabar + 1; \* para hacer commit cada 100 *\
        INSERT INTO ge_asientos_tmp
          (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
           monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
           cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda
           )
        VALUES
          (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, v_cod_rubro,
           v_monto, v_mto_equ_local, v_tip_mov_rubro, mv.cod_mod_padre,
           mv.cod_mad_padre, mv.cod_ofi_origen, v_cotizacion, mv.cod_moneda);
        ------------------------------------------------------------
     END IF;*/
     -- si hay mas de 99 registros ingresados se hace commit;
     if v_grabar > 99 then
        COMMIT;
        v_grabar := 0;
     end if;
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
    from ge_modalidades MO, ge_transacciones b, ge_movimientos_ant a
   where (monto <> 0 OR mto_equ_local <> 0)
     and estado IN ('N','H')
     --and a.usu_insercion <> 'IT' -- para evitar interface
     --and cod_tra_padre = 364
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.tipo IN ('C','D') -- solo debitos o creditos
     and (a.reversado = 'N' or (a.reversado='S' and p_hora is not null))
     AND a.cod_tra_padre not in (565,950,317,306)
     and a.cod_transaccion not in (760,560,196)
     and (/*cod_tip_asiento IS NOT NULL and */ b.batch = 'B') -- especial
     -- por ahora solo toma cuentas a plazo
     --and cod_mad_padre in (33,34,35,91)
     AND a.COD_MODULO = MO.COD_MODULO
     AND a.COD_MODALIDAD = MO.COD_MODALIDAD
     --AND a.cod_rubro is null --
     --and a.nro_cuenta = '01633302393'
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
      --and (tip_cuenta is null or tip_cuenta = v_tip_cuenta)
      and ((NVL(v_tip_cuenta, 'X') = 'B' and tip_cuenta = v_tip_cuenta) or
          (NVL(v_tip_cuenta, 'X') <> 'B' and (tip_cuenta is null or tip_cuenta = v_tip_cuenta)))
      AND (nvl(cat_automatica,v_cat_automatica) = v_cat_automatica or cat_automatica is null)
      and (nvl(est_cuenta,v_est_cuenta) = v_est_cuenta or
           est_cuenta is null and v_est_cuenta is null)
      AND (COD_SEC_CONTABLE = v_cod_sector or COD_SEC_CONTABLE IS NULL)
      AND (IND_RESIDENTE = v_residente OR IND_RESIDENTE = 'X');
v_nro_cta_anterior VARCHAR2(15) := 'x';
wk_can_debitos number(5) := 0;
wk_can_creditos number(5) := 0;
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
     wk_lgofici := 'N';
     wk_can_debitos := 0;
     wk_can_creditos := 0;
     IF v_cod_oficina <> v_cod_ofi_origen THEN
         -- ES ASIENTO INTEROFICINA
         wk_lgofici := 'S';
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
                      AND GE_CTA_CLIENTES.COD_MODULO = v_cod_modulo
                      AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad
                      AND GE_CTA_CLIENTES.COD_OFICINA = v_cod_oficina
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
                  ELSIF v_cod_modalidad = 31 then
                    begin
                      select cod_sub_modalidad
                        into v_cod_sub_modalidad
                        from ah_cta_vistas
                       where nro_cuenta = v_nro_cuenta;
                    exception
                      when others then
                         v_cod_sub_modalidad := null;
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
           -------------------------------------------------
            IF v_sigue = 'S' THEN
             -- ya hubo otra linea interoficina
             if v_tip_movimiento <>  r_tp.TIP_MOVIMIENTO and r_tp.NRO_LINEA = 1 then
                v_sigue := 'N'; -- se apaga para que no genere interoficina
             end if;
            ELSE
             IF wk_lgofici = 'S' AND r_tp.NRO_LINEA = 1 THEN
                v_tip_movimiento := r_tp.TIP_MOVIMIENTO;
                x_tip_movimiento := r_tp.tip_movimiento; -- para el interoficina
                v_sigue    := 'S'; /* se hara interoficina */
             END IF;
            END IF;
            /* control de cuentas contables no se hace
            BEGIN
              SELECT 0 INTO v_dato
                FROM FBPLCTA WHERE PC_CDCUENT = wk_cdctcon;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
               INSERT INTO EALERMOV VALUES
               ('ERROR.Cuenta Contable no existe '||wk_cdctcon||' cta '||
                v_nro_cuenta||' tranp '||to_char(wk_cdtranp)||' trans'||
                to_char(wk_cdtrans)||' ope '||wk_cdopera||' hr '||wk_hrmovim);
            END;
            */
            -----------------------------------------------------------
            v_grabar := v_grabar + 1; /* para hacer commit cada 100 */
            --
            IF r_tp.NRO_LINEA = 1 THEN
               vh_cod_oficina := v_cod_oficina;
            ELSE
               vh_cod_oficina := v_cod_ofi_origen;
            END IF;
            --
            if v_tip_mov_rubro = 'D' then
               wk_can_debitos := wk_can_debitos +1;
            else
               wk_can_creditos := wk_can_creditos + 1;
            end if;
            INSERT INTO ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento
              )
            VALUES
              (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rubro,
               v_monto, v_mto_equ_local, v_tip_mov_rubro, v_cod_mod_padre,
               v_cod_mad_padre, vh_cod_oficina, v_cotizacion, v_cod_moneda,
               v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
               v_nro_cuenta, v_nro_documento);
            -----------------------------------------------------------
          END LOOP;
            ---------------------------
            IF wk_lgofici = 'S' AND v_sigue = 'S' /*and wk_can_debitos <> wk_can_creditos*/  THEN
               -- tomo el tipo de movimiento de la linea 1
               v_tip_movimiento := x_tip_movimiento;
               -- Recuperar cuenta contable interoficina
               wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,v_cod_moneda,v_cod_oficina);
               -------------------------------------------------------------
               --- VER SI EL TIPO DE MOVIMIENTO ES DE DEBITO O CREDITO
               ------------------------------------------------------------
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
               wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(v_cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);

               INSERT INTO ge_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, wk_cdctaco,
                   v_monto, v_mto_equ_local, v_tip_movimiento, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_oficina, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
                   v_nro_cuenta, v_nro_documento);
               -- Recuperar cuenta contable interoficina
               wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,v_cod_moneda,v_cod_ofi_origen);
               wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(v_cod_oficina,'000'))||substr(wk_cdctaco,14,2);

               INSERT INTO ge_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, wk_cdctaco,
                   v_monto, v_mto_equ_local, x_tip_movimiento, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_ofi_origen, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_ofi_origen,
                   v_nro_cuenta, v_nro_documento);
            END IF;
            ---------------- FIN INTEROFICINA ------------------

/*          IF v_cod_transaccion IN (607,521) AND v_cod_moneda = v_cod_mon_local THEN
            IF v_cod_transaccion = 607 THEN
                v_tip_mov_rubro := 'D';
                v_cod_rubro := '111201110200099';
            ELSE
                v_tip_mov_rubro := 'C';
                v_cod_rubro := '250202780100099';
            END IF;
            --- caso especial de cheq.cargo otros bancos gs -----------
            v_grabar := v_grabar + 1; \* para hacer commit cada 100 *\
            INSERT INTO ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda
              )
            VALUES
              (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rubro,
               v_monto, v_mto_equ_local, v_tip_mov_rubro, v_cod_mod_padre,
               v_cod_mad_padre, v_cod_ofi_origen, v_cotizacion, v_cod_moneda);
            -----------------------------------------------------------
          END IF;*/
          IF c_tip_asientos%ROWCOUNT = 0 THEN
            -- no existe asiento definido para la transaccion --
            IF v_cod_tip_asiento  NOT IN (124,111,535) OR v_cod_moneda <> v_cod_mon_local THEN
             INSERT INTO ge_asientos_tmp
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
                   || ' Sit='||pab_asi.fu_obt_des_sit_contable(v_cod_sit_contable) ,1,1000),
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
      raise_application_error(-20000,'ERROR: PRG_GEN_ASIENTOS_TMP_ANT '||SQLERRM);
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
      and (a.cod_usuario = p_cod_usuario or p_cod_usuario is null)
      and (a.fecha = p_fecha or p_fecha is null)
      and (a.hora = p_hora OR p_hora IS NULL)
      and a.FECHA = b.fecha
      and a.nro_documento4 = b.ref_movimiento
      and b.fecha = c.fecha
      and b.cod_oficina = c.cod_oficina
      and b.nro_asiento = c.nro_asiento;

begin
   for mv in mov_hist loop

      INSERT INTO ge_asientos_tmp
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
         mv.nro_cuenta, v_nro_documento
                  );

   end loop;

end;

PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
-- inicio del proceso principal
begin
  -- borro los asientos generados anteriormente
  if p_cod_usuario is null and p_hora is null and p_fecha is null then
     sql_util.ejecute_dml('TRUNCATE TABLE GE_ASIENTOS_TMP DROP STORAGE', v_msj);
  else
     -- borro solo los del usuario
     delete from ge_asientos_tmp where usu_insercion = user;
  end if;
  if v_msj is not null then
      raise_application_error(-20000, v_msj);
  end if;
  if nvl(p_fecha,v_fec_actual) = v_fec_actual then
      -- procesa los movimientos contables directos
      lp_pro_mov_contables;
      -- procesa los movimientos contables por transacciones
      lp_pro_mov_x_transacciones;
  else
      lp_pro_mov_historicos;
  end if;
  -- elimina los asientos que balancean
  if nvl(p_eli_asi_validos,'S') = 'S' then
     lp_eli_asi_balanceados;
  end if;
  commit;
end PRG_GEN_ASIENTOS_TMP_ANT;
/

