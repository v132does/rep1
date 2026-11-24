CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ASIENTOS_TMP_FEC
   (P_FECHA IN DATE            DEFAULT NULL,    -- fecha de movimiento
    P_HORA IN VARCHAR2         DEFAULT NULL,    -- hora del movimiento
    P_COD_USUARIO IN VARCHAR2  DEFAULT NULL,    -- usuario del movimiento
    P_NRO_SECUENCIA IN NUMBER  DEFAULT NULL,    -- nro de secuencia del movimiento
    P_COD_OFI_ORIGEN IN NUMBER DEFAULT NULL,    -- oficina origen del movimiento
    P_COD_MOD_PADRE IN NUMBER  DEFAULT NULL,    -- modulo padre del movimiento
    P_COD_MAD_PADRE IN NUMBER  DEFAULT NULL,    -- modalidad padre del movimiento
    P_ELI_ASI_VALIDOS IN VARCHAR2 DEFAULT 'N',    -- para eliminar o no los asientos validos
    P_GEN_BAL_LINEA   IN VARCHAR2 DEFAULT 'N') is -- para generar el balance en linea
-- OBJETIVO   : Generar una simulacion de los asientos a ser generados por IT GF.
--              Al finalizar este proceso se generara la tabla ge_asientos_tmp,
--              que contendra
-- PROGRAMADOR: Agustin Meza
-- FECHA      : 09/Feb/2005
-- VERSION: 08/09/2009 Agrego el NRO_DOCUMENTO en GE_ASIENTOS_TMP: Ingrid Larra?n

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
v_cod_mon_fuerte ba_monedas.cod_moneda%type := PAG_GEN.FU_OBT_MON_FUERTE;
v_tip_mov_rubro ge_movimientos.tip_mov_rubro%type;
v_cod_rubro     ge_movimientos.cod_rubro%type;
v_nro_documento ge_movimientos.nro_documento%type;
v_fec_actual    date := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_grabar        number(4) := 0;
v_msj varchar2(3000);
v_redondeo_ml   number(5);
v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
v_lugar number;
v_fec_ult_cierre ge_movimientos.fecha%type;

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
    select nvl(fecha,v_fec_actual) fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
           monto, mto_equ_local, tip_mov_rubro, cod_moneda,
           cod_modulo, cod_modalidad, cod_transaccion, nro_cuenta,
           cod_mod_padre, cod_mad_padre, cod_ofi_origen, cotizacion,
           cod_oficina, cod_tra_padre, nro_documento
      from gv_movimientos
     where (monto <> 0 OR mto_equ_local <> 0)
       --and usu_insercion <> 'IT' -- para evitar interface
       and estado IN ('N','H')
       and cod_rubro IS NOT NULL
       and cod_mod_padre = nvl(p_cod_mod_padre,cod_mod_padre)
       and cod_mad_padre = nvl(p_cod_mad_padre,cod_mad_padre)
       and (reversado = 'N' or (reversado='S' and (p_hora is not null or fecha > fec_valor)))
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
           nro_documento,observacion
           )
     VALUES
          (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, mv.cod_rubro,
           v_monto, v_mto_equ_local, mv.tip_mov_rubro, mv.cod_mod_padre,
           mv.cod_mad_padre, mv.cod_oficina, v_cotizacion, mv.cod_moneda,
           mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
           mv.cod_oficina, mv.nro_cuenta, mv.nro_documento,1);

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
         --wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv.cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);
         INSERT INTO ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento,observacion
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, wk_cdctaco,
               v_monto, v_mto_equ_local, wk_tip_mov_rubro, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_oficina, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_oficina, mv.nro_cuenta, mv.nro_documento,2);


               v_lugar := 2;
         ---
         wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,mv.cod_moneda,mv.cod_ofi_origen);
         --wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv.cod_oficina,'000'))||substr(wk_cdctaco,14,2);
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
               nro_cuenta, nro_documento,observacion
               )
         VALUES
              (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, wk_cdctaco,
               v_monto, v_mto_equ_local, mv.tip_mov_rubro, mv.cod_mod_padre,
               mv.cod_mad_padre, mv.cod_ofi_origen, v_cotizacion, mv.cod_moneda,
               mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion,
               mv.cod_ofi_origen, mv.nro_cuenta, mv.nro_documento,3);
      END IF;

      v_lugar := 3;
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
v_tip_cuenta varchar2(1):= 'N';
v_tip_interes varchar2(1);
v_tip_renovacion varchar2(1);
v_cod_sit_contable number(30);
v_ind_cta_basica varchar2(1);
v_sigue char(1);

cursor MOV_TRANSACCIONES IS
  select a.cod_modulo, a.cod_modalidad, a.cod_transaccion, cod_oficina, nro_cuenta,
         fecha, fec_valor, reversado,
         cod_mod_padre, cod_mad_padre, cod_tra_padre,
         cod_moneda, monto, cotizacion, mto_equ_local,
         cod_ofi_origen, cod_usuario, hora, nro_secuencia,
         cod_tip_asiento, a.cod_ref_cambio, a.nro_documento2,
         est_cuenta, mo.cod_pro_contable, cod_tip_asiento2,
         cod_sit_contable, nro_documento
    from ge_modalidades MO, ge_transacciones b, gv_movimientos a
   where (monto <> 0 OR mto_equ_local <> 0)
     and estado IN ('N','H')
     --and a.usu_insercion <> 'IT' -- para evitar interface
     --and cod_tra_padre = 364
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.tipo IN ('C','D') -- solo debitos o creditos
     and (a.reversado = 'N' or (a.reversado='S' and (fecha > fec_valor or p_hora is not null)))
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
      and ((NVL(v_ind_cta_Basica, 'N') = 'N' and (tip_cuenta is null or tip_cuenta = v_tip_cuenta)) or
          (NVL(v_ind_cta_Basica, 'N') = 'S' and tip_cuenta = v_tip_cuenta))
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
                     begin
                          SELECT FEC_VENCIMIENTO - FEC_APERTURA
                           INTO v_can_dias
                           FROM AH_CTA_PLAZOS
                          WHERE COD_MODULO = v_cod_modulo
                            AND COD_MODALIDAD = v_cod_modalidad
                            AND COD_OFICINA = v_cod_oficina
                            AND NRO_CUENTA = v_nro_cuenta;
                            lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                                          EXCEPTION
                       WHEN no_data_found then
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta 1: '||v_nro_cuenta||' - '||sqlerrm);
                       END;
                  ELSIF v_cod_modalidad in (33,34,36) THEN
                    begin
                         SELECT FEC_VENCIMIENTO - FEC_APERTURA
                           INTO v_can_dias
                           FROM AH_CTA_CERTIFICADOS
                          WHERE COD_MODULO = v_cod_modulo
                            AND COD_MODALIDAD = v_cod_modalidad
                            AND COD_OFICINA = v_cod_oficina
                            AND NRO_CUENTA = v_nro_cuenta;
                            lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                                         EXCEPTION
                     WHEN no_data_found then
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta 2: '||v_nro_cuenta||' - '||sqlerrm);
                     END;
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
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta '||v_nro_cuenta||' - '||sqlerrm);
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
                   --Agregado para separar contabilizacion de Cta Basica--
                  if v_cod_modulo = 3 and v_cod_modalidad = 31 THEN
                   begin
                     select x.cod_sub_modalidad
                       into v_cod_sub_modalidad
                       from ah_cta_vistas x
                      where x.nro_cuenta = v_nro_cuenta;
                   EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'Error al obtener sub-modalidad de cuenta: '||v_nro_cuenta);
                   END;
                   begin
                     if v_cod_sub_modalidad = 26 then
                        v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(v_cod_modulo)||trim(v_cod_modalidad)||trim(v_cod_sub_modalidad));
                        v_ind_cta_basica := 'S';
                     else
                        v_tip_cuenta := null;
                        v_ind_cta_basica := 'N';
                     end if;
                   exception
                     when others then
                       v_tip_cuenta := null;
                       v_ind_cta_basica := 'N';
                   end;
                  else
                    v_ind_cta_basica := 'N';
                  end if;
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
               nro_documento,observacion
              )
            VALUES
              (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, v_cod_rubro,
               v_monto, v_mto_equ_local, v_tip_mov_rubro, v_cod_mod_padre,
               v_cod_mad_padre, vh_cod_oficina, v_cotizacion, v_cod_moneda,
               v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
               v_nro_cuenta, v_nro_documento,4);
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
               --wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(v_cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);

               INSERT INTO ge_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento,observacion
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, wk_cdctaco,
                   v_monto, v_mto_equ_local, v_tip_movimiento, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_oficina, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_oficina,
                   v_nro_cuenta, v_nro_documento,5);
               -- Recuperar cuenta contable interoficina
               wk_cdctaco := fug_obt_pardinamico('COD_RUB_INTEROFICINA',null,null,v_cod_moneda,v_cod_ofi_origen);
               --wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(v_cod_oficina,'000'))||substr(wk_cdctaco,14,2);

               INSERT INTO ge_asientos_tmp
                  (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
                   monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
                   cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
                   cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
                   nro_documento,observacion
                  )
               VALUES
                  (v_fecha, v_cod_usuario, v_hora, v_nro_secuencia, wk_cdctaco,
                   v_monto, v_mto_equ_local, x_tip_movimiento, v_cod_mod_padre,
                   v_cod_mad_padre, v_cod_ofi_origen, v_cotizacion, v_cod_moneda,
                   v_cod_tra_padre, v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_ofi_origen,
                   v_nro_cuenta, v_nro_documento,6);
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
           IF (v_cod_modalidad <> 455 ) AND
               (v_cod_tip_asiento  NOT IN (124,111,535) OR
               v_cod_moneda <> v_cod_mon_local) THEN

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
      raise_application_error(-20000,'ERROR: PRG_GEN_ASIENTOS_TMP '||SQLERRM || ' ' || v_lugar);
end;

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
    INSERT INTO ge_asientos_tmp
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
    INSERT INTO ge_asientos_tmp
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
      and (a.fecha = nvl(p_fecha,v_fec_actual) /* or p_fecha is null*/)
      and (a.hora = p_hora/* OR p_hora IS NULL*/)
      and a.FECHA = b.fecha
      and a.nro_documento4 = b.ref_movimiento
      and b.fecha = c.fecha
      and b.cod_oficina = c.cod_oficina
      and b.nro_asiento = c.nro_asiento
      and ((P_GEN_BAL_LINEA = 'S' and
          (c.nro_asi_real is null and not exists
           (select 1
                from gv_movimientos
               where FECHA = a.fecha
                 and hora = a.hora
                 and cod_usuario = a.cod_usuario))) or
          P_GEN_BAL_LINEA = 'N')
    UNION
       select a.fecha, a.cod_usuario, a.hora, a.nro_secuencia, b.cod_rubro,
          decode(a.cod_moneda, v_cod_mon_local,0,a.monto) monto,
          decode(a.cod_moneda, v_cod_mon_local,a.monto,mto_equ_local) mto_equ_local, b.tip_movimiento, cod_mod_padre,
          cod_mad_padre, b.cod_oficina cod_ofi_origen, cotizacion, cod_moneda,
          b.cod_oficina, c.nro_asiento, b.nro_linea,
          a.cod_tra_padre,
          a.cod_modulo, a.cod_modalidad, a.cod_transaccion,
          b.cod_oficina cod_ofi_cta, a.nro_cuenta, a.NRO_DOCUMENTO
     from cb_asientos_his c,cb_asientos_det_his b, gv_movimientos a
    where (a.monto <> 0 OR a.mto_equ_local <> 0)
      and a.estado IN ('N','H')
      and (a.cod_usuario = p_cod_usuario/* or p_cod_usuario is null*/)
      and (a.fecha = nvl(p_fecha,v_fec_actual)/* or p_fecha is null*/)
      and (a.hora = p_hora/* OR p_hora IS NULL*/)
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
         nro_documento,observacion
        )
      VALUES
        (mv.fecha, mv.cod_usuario, mv.hora, mv.nro_secuencia, mv.cod_rubro,
         mv.monto, mv.mto_equ_local, mv.tip_movimiento, mv.cod_mod_padre,
         mv.cod_mad_padre, mv.cod_oficina, mv.cotizacion, mv.cod_moneda,
         mv.nro_asiento, mv.nro_linea,
         mv.cod_tra_padre, mv.cod_modulo, mv.cod_modalidad, mv.cod_transaccion, mv.cod_ofi_cta,
         mv.nro_cuenta, v_nro_documento,7
                  );

   end loop;

end;

-- Proc. que genera el balance en linea
PROCEDURE LP_PRO_BAL_LINEA IS
BEGIN
  --Obtener la fecha del ultimo cierre contable
  SELECT MAX(fecha)
    INTO v_fec_ult_cierre
    FROM cb_sal_consolidados_dia;

  -- procesa los movimientos contables directos del dia
  lp_pro_mov_contables;
  -- procesa los movimientos contables por transacciones del dia
  lp_pro_mov_x_transacciones;
  -- procesa los movimientos contables manuales a la fecha de proceso
  lp_pro_mov_manuales;
  -- procesa los movimientos contables futuros que correspondan a la fecha de proceso
  lp_pro_mov_futuros;
  -- procesa los movimientos contables historicos que correspondan a la fecha de proceso
  lp_pro_mov_historicos;
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
                     AND FECHA = nvl(P_FECHA,v_fec_actual)
                     AND USU_INSERCION = USER
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA)
                                        VALUES (P_COD_OFICINA, v_nro_cuenta, nvl(P_FECHA,v_fec_actual));
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20008,'Error al bloquear el rubro '||v_nro_cuenta||' - Ofic '||P_COD_OFICINA||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   IF P_TIP_MOV = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE cb_sal_oficinas_tmp
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_FUERTE,0),NVL(P_MTO_LOCAL,0))
                       WHERE COD_OFICINA = P_COD_OFICINA
                         AND COD_RUBRO = v_nro_cuenta
                         AND FECHA = nvl(P_FECHA,v_fec_actual)
                         AND USU_INSERCION = USER;
                   ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE cb_sal_oficinas_tmp
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(P_MTO_LOCAL,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_FUERTE,0),NVL(P_MTO_LOCAL,0))
                       WHERE COD_OFICINA = P_COD_OFICINA
                         AND COD_RUBRO = v_nro_cuenta
                         AND FECHA = nvl(P_FECHA,v_fec_actual)
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
   RAISE_APPLICATION_ERROR(-20009,'ERROR. Codigo de la Cuenta '||P_NRO_CUENTA||
          ' inexistente en Plan de Cuenta');
END;

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
                   VALUES (P_COD_OFICINA, v_nro_cuenta, nvl(P_FECHA,v_fec_actual), P_MTO_LOCAL, P_MTO_FUERTE,
                           V_MON_EQU_LOCAL);
    ELSE
      -----------------------------------------------------------------
      -- INSERTA SALDO DE CREDITO
      -----------------------------------------------------------------
      INSERT INTO cb_sal_oficinas_tmp (COD_OFICINA, COD_RUBRO, FECHA, CRE_MON_LOCAL, CRE_MON_RUBRO,
                           CRE_EQU_LOCAL)
                   VALUES (P_COD_OFICINA, v_nro_cuenta,nvl(P_FECHA,v_fec_actual), P_MTO_LOCAL, P_MTO_FUERTE,
                           V_MON_EQU_LOCAL);
    END IF;
    lp_sum_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,WIMMOUSD,P_COD_MONEDA);
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20010,'ERROR. Cuenta '||P_NRO_CUENTA||
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
     AND FECHA = nvl(P_FECHA,v_fec_actual)
     AND USU_INSERCION = USER
     FOR UPDATE OF COD_RUBRO;
  IF SQL%FOUND THEN
    IF P_TIP_MOV = 'D' THEN
      ------------------------------------------------------------
      -- ACTUALIZA POR MOVIMIENTO DE DEBITO
      ------------------------------------------------------------
      UPDATE cb_sal_oficinas_tmp
        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_LOCAL,0),0),
            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_FUERTE,0),NVL(P_MTO_LOCAL,0))
      WHERE COD_OFICINA = P_COD_OFICINA
        AND COD_RUBRO = P_NRO_CUENTA
        AND FECHA = nvl(P_FECHA,v_fec_actual)
        AND USU_INSERCION = USER;
      lp_sum_sal_oficinas(P_COD_OFICINA,P_NRO_CUENTA,P_TIP_MOV,P_MTO_LOCAL,WIMMOUSD,P_COD_MONEDA);
    ELSE
      ------------------------------------------------------------
      -- ACTUALIZA POR MOVIMIENTO DE CREDITO
      ------------------------------------------------------------
      UPDATE cb_sal_oficinas_tmp
        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_LOCAL,0),0),
            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(P_MTO_FUERTE,0),
            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(NVL(P_MTO_FUERTE,0),0,NVL(P_MTO_FUERTE,0),NVL(P_MTO_LOCAL,0))
      WHERE COD_OFICINA = P_COD_OFICINA
        AND COD_RUBRO = P_NRO_CUENTA
        AND FECHA = nvl(P_FECHA,v_fec_actual)
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

-- Proc. que genera los saldos consolidados
PROCEDURE LP_CON_BAL_LINEA IS
  v_cod_oficina ba_oficinas.cod_oficina%type;
  v_nro_cuenta  ge_asientos_tmp.nro_cuenta%type;
  v_tip_mov     ge_asientos_tmp.tip_mov_rubro%type;
  v_des_oficina ba_oficinas.descripcion%type;
  v_mto_local   ge_asientos_tmp.monto%type;
  v_mto_ext     ge_asientos_tmp.monto%type;
  v_mto_fuerte  ge_asientos_tmp.monto%type;
  v_cod_moneda  ba_monedas.cod_moneda%type;

  CURSOR MOV IS
     SELECT GE_ASIENTOS_TMP.COD_OFICINA, GE_ASIENTOS_TMP.COD_RUBRO,
            GE_ASIENTOS_TMP.TIP_MOV_RUBRO, BA_OFICINAS.DESCRIPCION,
            SUM(NVL(GE_ASIENTOS_TMP.MTO_EQU_LOCAL,0)),
            DECODE(GE_ASIENTOS_TMP.cod_moneda,v_cod_mon_local,0,SUM(NVL(GE_ASIENTOS_TMP.MONTO,0))),
            decode(substr(cb_rubros.cod_rubro,14,2),'98',v_cod_mon_fuerte,CB_RUBROS.COD_MONEDA)
       FROM CB_RUBROS, GE_ASIENTOS_TMP, BA_OFICINAS
      WHERE GE_ASIENTOS_TMP.COD_OFICINA = BA_OFICINAS.COD_OFICINA
        AND CB_RUBROS.COD_RUBRO = GE_ASIENTOS_TMP.COD_RUBRO
        AND GE_ASIENTOS_TMP.USU_INSERCION = USER
        AND GE_ASIENTOS_TMP.ACTUALIZADO = 'N'

      GROUP BY GE_ASIENTOS_TMP.COD_OFICINA, GE_ASIENTOS_TMP.COD_RUBRO,
               GE_ASIENTOS_TMP.TIP_MOV_RUBRO, BA_OFICINAS.DESCRIPCION,
               GE_ASIENTOS_TMP.cod_Moneda,
               decode(substr(cb_rubros.cod_rubro,14,2),'98',v_cod_mon_fuerte,CB_RUBROS.COD_MONEDA);

  procedure lp_act_asientos(P_COD_OFICINA IN NUMBER,
                            P_COD_RUBRO   IN VARCHAR2,
                            P_TIP_MOV     IN VARCHAR2) IS
  begin
    update ge_asientos_tmp
       set ge_asientos_tmp.actualizado = 'S'
     where ge_asientos_tmp.cod_oficina   = p_cod_oficina
       and ge_asientos_tmp.cod_rubro     = p_cod_rubro
       and ge_asientos_tmp.tip_mov_rubro = p_tip_mov
       and ge_asientos_tmp.actualizado   = 'N';
  end;

  procedure lp_cal_utilidad is
    ww_sal7    number;
    ww_sal6    number;
    ww_debi    number;
    ww_cred    number;
    ww_dife    number;
    ww_deb_hoy number;
    ww_cre_hoy number;
    ww_sal_act number;

    cursor ofi is
      select distinct cod_oficina
        from cb_sal_oficinas_tmp
       where usu_insercion = user;
  begin
    for o in ofi loop
      ww_sal7 := 0;
      ww_sal6 := 0;
      ww_debi := 0;
      ww_cred := 0;
      -- cargo los rubros de utilidad por si no existan
      insert into cb_sal_oficinas_tmp
        (cod_oficina, cod_rubro)
        select o.cod_oficina, b.cod_rubro
          from cb_rubros b
         where cod_rubro in ('310604180000000',
                             '310604180100000',
                             '310604180100099',
                             '310604220000000',
                             '310604220100000',
                             '310604220100099',
                             '310600000000000',
                             '310000000000000',
                             '300000000000000')
           and not exists (select 0
                  from cb_sal_oficinas_tmp a
                 where a.cod_rubro = b.cod_rubro
                   and a.cod_oficina = o.cod_oficina
                   and a.usu_insercion = user);
      -- saldo de la cuenta GANANCIAS
      begin
        select sum(nvl(sal_mon_loc_ant, 0))
          into ww_sal6
          from cb_sal_oficinas_tmp
         where cod_rubro = '600000000000000'
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
        -- saldo de la cuenta PERDIDAS
        select sum(nvl(sal_mon_loc_ant, 0))
          into ww_sal7
          from cb_sal_oficinas_tmp
         where cod_rubro = '700000000000000'
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
      exception
        when others then
          raise_application_error(-20013,
                                  'Error al buscar la Ganancia o Perdida de la Oficina ' ||o.cod_oficina );
      end;
      -- movimiento debito de hoy de la cuenta 6000000000 y 7000000000
      select sum(nvl(DEB_MON_LOCAL, 0))
        into ww_debi
        from cb_sal_oficinas_tmp, cb_rubros
       where cb_rubros.cod_rubro = cb_sal_oficinas_tmp.cod_rubro
         and imputable = 'S'
         and cod_oficina = o.cod_oficina
         and substr(cb_rubros.cod_rubro, 1, 1) in ('6', '7')
         and cb_sal_oficinas_tmp.usu_insercion = user;
      -- movimiento credito de hoy de la cuenta 6000000000 y 7000000000
      select sum(nvl(CRE_MON_LOCAL, 0))
        into ww_cred
        from cb_sal_oficinas_tmp, cb_rubros
       where cb_rubros.cod_rubro = cb_sal_oficinas_tmp.cod_rubro
         and imputable = 'S'
         and cod_oficina = o.cod_oficina
         and substr(cb_rubros.cod_rubro, 1, 1) in ('6', '7')
         and cb_sal_oficinas_tmp.usu_insercion = user;
      -- halla la diferencia entre ambos movimientos debitos y creditos
      ww_dife := abs(nvl(ww_debi, 0) - nvl(ww_cred, 0));
      -- calculo el saldo actual
      ww_sal_act := nvl(ww_sal6, 0) + nvl(ww_sal7, 0) + nvl(ww_debi, 0) -
                    nvl(ww_cred, 0);
      -- calculo el debito y credito de hoy
      if nvl(ww_debi, 0) > nvl(ww_cred, 0) then
        ww_deb_hoy := nvl(ww_dife, 0);
        ww_cre_hoy := 0;
      else
        ww_cre_hoy := nvl(ww_dife, 0);
        ww_deb_hoy := 0;
      end if;
      -- si es ganancia
      if ww_sal_act < 0 then
        -- actualiza con la diferencia entre ambos saldos
        update cb_sal_oficinas_tmp
           set sal_mon_loc_ant = nvl(ww_sal6, 0) + nvl(ww_sal7, 0),
               deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in
               ('310604180000000', '310604180100000', '310604180100099')
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
        -- cero los datos de las perdidas
        update cb_sal_oficinas_tmp
           set sal_mon_loc_ant = 0, deb_mon_local = 0, cre_mon_local = 0
         where cod_rubro in
               ('310604220000000', '310604220100000', '310604220100099')
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
      else
        -- perdida
        -- actualiza con la diferencia entre ambos saldos
        update cb_sal_oficinas_tmp
           set sal_mon_loc_ant = nvl(ww_sal6, 0) + nvl(ww_sal7, 0),
               deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in
               ('310604220000000', '310604220100000', '310604220100099')
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
        -- actualiza en cero las ganancias
        update cb_sal_oficinas_tmp
           set sal_mon_loc_ant = 0, deb_mon_local = 0, cre_mon_local = 0
         where cod_rubro in
               ('310604180000000', '310604180100000', '310604180100099')
           and cod_oficina = o.cod_oficina
           and usu_insercion = user;
      end if;
      -- actualizo el padre comun
      update cb_sal_oficinas_tmp
         set deb_mon_local = ww_deb_hoy, cre_mon_local = ww_cre_hoy
       where cod_rubro = '310600000000000'
         and cod_oficina = o.cod_oficina
         and usu_insercion = user;
      ----------------------------------------
      -- sumarizacion de patrimonio
      ----------------------------------------
      update cb_sal_oficinas_tmp
         set deb_mon_local = nvl(deb_mon_local, 0) + nvl(ww_deb_hoy, 0),
             cre_mon_local = nvl(cre_mon_local, 0) + nvl(ww_cre_hoy, 0)
       where cod_rubro in ('300000000000000', '310000000000000')
         and cod_oficina = o.cod_oficina
         and usu_insercion = user;
    end loop;
  end;

begin
  -- inicializar el saldo anterior
  insert into cb_sal_oficinas_tmp(cod_oficina, cod_rubro, fecha, sal_mon_loc_ant,
                                  sal_mon_rub_ant, deb_mon_local, cre_mon_local,deb_mon_rubro,cre_mon_rubro,
                                  sal_equ_loc_ant, deb_equ_local, cre_equ_local, usu_insercion)
  (select cod_oficina, cod_rubro, nvl(P_FECHA,v_fec_actual), (nvl(sal_mon_loc_ant,0) + nvl(deb_mon_local,0) - nvl(cre_mon_local,0)),
          (nvl(sal_mon_rub_ant,0) + nvl(deb_mon_rubro,0) - nvl(cre_mon_rubro,0)), 0, 0,0, 0,
          (nvl(sal_equ_loc_ant,0) + nvl(deb_equ_local,0) - nvl(cre_equ_local,0)) ,0,0,user
     from cb_sal_oficinas);

  -- inserto los rubros nuevos.
  insert into cb_sal_oficinas_tmp
  select distinct b.cod_oficina, b.cod_rubro, nvl(P_FECHA,v_fec_actual), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asi_automaticos_det b,
         cb_asi_automaticos     c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha < nvl(P_FECHA,v_fec_actual)
     and c.nro_asi_real is null
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro)
  union
  select distinct b.cod_oficina, b.cod_rubro, nvl(P_FECHA,v_fec_actual), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asientos_det b, cb_asientos c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha < nvl(P_FECHA,v_fec_actual)
     and c.confirmado = 'S'
     and c.actualizado = 'N'
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro)
  union
  select distinct b.cod_oficina, b.cod_rubro, nvl(P_FECHA,v_fec_actual), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, USER, SYSDATE, USER, SYSDATE
    from cb_asi_futuros_det b, cb_asi_futuros c
   where b.fecha = c.fecha
     and b.cod_oficina = c.cod_oficina
     and b.nro_asiento = c.nro_asiento
     and c.fecha > v_fec_ult_cierre
     and c.fecha < nvl(P_FECHA,v_fec_actual)
     and c.nro_asi_real is null
     and not exists (select 1 from cb_sal_oficinas_tmp cs where cs.cod_rubro = b.cod_rubro);

  -- Actualiza el saldo anterior con los movimientos hasta la fecha de proceso
  update cb_sal_oficinas_tmp a
     set a.sal_mon_loc_ant = nvl(a.sal_mon_loc_ant, 0) + nvl(a.deb_mon_local, 0) - nvl(a.cre_mon_local, 0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_local),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_local),
                                                        0))
                                from cb_asientos_det b, cb_asientos c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.confirmado = 'S'
                                 and c.actualizado = 'N'
                               group by tip_movimiento),0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_local),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_local),
                                                        0))
                                from cb_asi_automaticos_det b,
                                     cb_asi_automaticos     c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.nro_asi_real is null
                               group by tip_movimiento),0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_local),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_local),
                                                        0))
                                from cb_asi_futuros_det b, cb_asi_futuros c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.nro_asi_real is null
                               group by tip_movimiento),0),
         a.sal_mon_rub_ant = nvl(a.sal_mon_rub_ant, 0) + nvl(a.deb_mon_rubro, 0) - nvl(a.cre_mon_rubro, 0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_rubro),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_rubro),
                                                        0))
                                from cb_asientos_det b, cb_asientos c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.confirmado = 'S'
                                 and c.actualizado = 'N'
                               group by tip_movimiento),0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_rubro),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_rubro),
                                                        0))
                                from cb_asi_automaticos_det b,
                                     cb_asi_automaticos     c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.nro_asi_real is null
                               group by tip_movimiento),0) +
                             nvl((select sum(decode(b.tip_movimiento,
                                            'D',
                                            sum(b.mto_mon_rubro),
                                            0) - decode(b.tip_movimiento,
                                                        'C',
                                                        sum(b.mto_mon_rubro),
                                                        0))
                                from cb_asi_futuros_det b, cb_asi_futuros c
                               where b.fecha = c.fecha
                                 and b.cod_oficina = c.cod_oficina
                                 and b.nro_asiento = c.nro_asiento
                                 and c.cod_oficina = a.cod_oficina
                                 and b.cod_rubro   = a.cod_rubro
                                 and c.fecha > v_fec_ult_cierre
                                 and c.fecha < nvl(P_FECHA,v_fec_actual)
                                 and c.nro_asi_real is null
                               group by tip_movimiento),0)
  where usu_insercion = user;

  If MOV%ISOPEN THEN
    close MOV;
  End if;

  Open MOV;
  Loop
    Fetch MOV INTO v_cod_oficina, v_nro_cuenta, v_tip_mov, v_des_oficina, v_mto_local, v_mto_ext, v_cod_moneda;
    v_mto_fuerte := PAG_GEN.FU_CON_MON_A_MONEDA(v_cod_moneda,v_cod_mon_fuerte,v_mto_ext);
    EXIT WHEN MOV%notfound;
    If MOV%FOUND THEN
      lp_act_sal_oficinas(v_cod_oficina, v_nro_cuenta, v_tip_mov, v_mto_local, v_mto_ext,v_mto_fuerte,v_cod_moneda);
    End if;
    lp_act_asientos(v_cod_oficina, v_nro_cuenta, v_tip_mov);
  End loop;

  -- genera los movimientos por ajuste cambiario
  --lp_aju_dif_cambios;

  If MOV%ISOPEN THEN
    close MOV;
  End if;

  Open MOV;
  Loop
    Fetch MOV INTO v_cod_oficina, v_nro_cuenta, v_tip_mov, v_des_oficina, v_mto_local, v_mto_ext, v_cod_moneda;
    v_mto_fuerte := PAG_GEN.FU_CON_MON_A_MONEDA(v_cod_moneda,v_cod_mon_fuerte,v_mto_ext);
    EXIT WHEN MOV%notfound;
    If MOV%FOUND THEN
      lp_act_sal_oficinas(v_cod_oficina, v_nro_cuenta, v_tip_mov, v_mto_local, v_mto_ext,v_mto_fuerte,v_cod_moneda);
    End if;
    lp_act_asientos(v_cod_oficina, v_nro_cuenta, v_tip_mov);
  End loop;

  --proceso que calcula la utilidad
  --lp_cal_utilidad;
end;

PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
-- inicio del proceso principal
begin
  -- borro los asientos generados anteriormente
  if p_cod_usuario is null and p_hora is null and p_fecha is null then
     sql_util.ejecute_dml('TRUNCATE TABLE GE_ASIENTOS_TMP DROP STORAGE', v_msj);
     sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_OFICINAS_TMP DROP STORAGE', v_msj);
  else
    v_lugar := 1;
     -- borro solo los del usuario
     delete from ge_asientos_tmp where usu_insercion = user;
     delete from cb_sal_oficinas_tmp where usu_insercion = user;
  end if;

  v_lugar := 2;
  if v_msj is not null then
      raise_application_error(-20000, v_msj);
  end if;
  IF p_gen_bal_linea = 'N' THEN
    --IF nvl(p_fecha,v_fec_actual) = v_fec_actual THEN
      v_lugar := 4;
      -- procesa los movimientos contables directos
      lp_pro_mov_contables;

      v_lugar := 5;
      -- procesa los movimientos contables por transacciones
      lp_pro_mov_x_transacciones;
      v_lugar := 6;
    --ELSE
    --lp_pro_mov_historicos;
    --  v_lugar := 7;
   -- END IF;
  ELSE
    -- procesa los asientos para el balance
    lp_pro_bal_linea;
    -- proceso que genera los saldos consolidados
    lp_con_bal_linea;
    -- actualizo a la cotizacion del dia.
    prb_sum_sal_oficinas_tmp;
  END IF;
  -- elimina los asientos que balancean
  if nvl(p_eli_asi_validos,'S') = 'S' then

     lp_eli_asi_balanceados;
     v_lugar := 8;
  end if;
  commit;
end PRG_GEN_ASIENTOS_TMP_FEC;
/

