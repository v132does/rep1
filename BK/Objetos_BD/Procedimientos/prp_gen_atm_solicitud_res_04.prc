CREATE OR REPLACE PROCEDURE IT.PRP_GEN_ATM_SOLICITUD_RES_04
  (p_cod_persona         in varchar2, -- codigo de la persona,
   p_cod_modalidad       in number,   -- tipo de credito
   p_cod_moneda          in varchar2, -- moneda
   p_monto               in number,   -- monto del credito
   p_can_cuotas          in number,   -- nro de cuotas
   p_grabar              in varchar2 default 'S', -- Definir si grabara o no los datos en las tablas
   p_tip_monto           in varchar2 default 'N', -- tipo de monto B-BRUTO o N-NETO
   p_fec_inicio          in date default null,     -- inicio del credito
   p_fec_pri_vencimiento in date default null,     -- primer vencimiento
   p_val_tasa            in number  default null,  -- valor de la tasa
   p_cod_canal           in number  default null,  -- codigo del canal
   p_cod_campana         in number  default null,   -- código de campaña
   p_descripcion         in varchar2 default null,  -- descripcion de la oper.
   p_cod_usu_promotor    in varchar2 default null,
   p_tip_renovacion      in varchar2 default null,
   p_tip_destino         in varchar2 default null,
   p_cod_banca           in number default null,
   p_nro_cta_debito      in varchar2,
   p_cod_sub_modalidad   in varchar2 default null,
   p_cod_rub_economico   in varchar2 default null,
   p_cod_sec_economico   in varchar2 default null,
   p_deb_automatico      in varchar2 default null,
   p_cod_gar_pre_ant     in varchar2 default null,
   p_nro_gar_pre_ant      in varchar2 default null,
   p_nro_solicitud       out number
   ) is
--------------------- Variables del procedimiento -----------------------------
v_dummy             number(9);
v_cod_modulo        number(3)      := 6;    -- prestamos
 --DYDMR-5803--Modificado por rpavon 03.01.17--
--v_cod_usuario       varchar2(10)   := upper(user); --usuario
v_fec_actual        date           := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
v_hor_actual        varchar2(08)   := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
v_cod_oficina       number(3);         -- Codigo de oficina
v_mon_local         varchar2(3)    := pag_gen.fu_obt_mon_local;
v_cotizacion        ge_cotizaciones.val_conversion%type := pag_gen.fu_obt_cotizacion(p_cod_moneda);
v_exo_impuestos     varchar2(1)    := 'N';
v_cod_usu_oficial   varchar2(10);
v_tot_prestamo      number(18,2) := 0;  -- total del prestamo
v_mto_interes       number(18,2) := 0;  -- total de interes
v_mto_cargo         number(18,2) := 0;
v_fec_inicio        date  := nvl(p_fec_inicio,v_fec_actual);
v_fec_pri_vencimiento date := nvl(p_fec_pri_vencimiento, add_months(v_fec_inicio,1));
--Se agrega para comparar
v_fec_pri_vencimiento_ori date; -- := add_months(v_fec_inicio,1);
v_fec_vencimiento   date   := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, p_can_cuotas-1);
v_cod_sec_credito   number(3)  := 1;  -- ver que valor tendra
v_cod_departamento  number(3)  := null;  -- Se obtiene de los datos del cliente o en su defecto de la oficina
v_cod_dep_parametro number(3)  := null;  -- Departamento de Parametros
v_tip_interes       varchar2(1):= 'V';
v_tip_amortizacion  varchar2(1):= 'P';
v_aju_ult_cuota     varchar2(1):= 'N';
v_tip_aju_fecha     varchar2(1):= 'E';
v_aju_gracia        varchar2(1):= 'N';
v_tip_documento     number(1)  := 1;
v_tipo              varchar2(1):= 'A';
v_cod_usu_promotor  varchar2(10);
v_val_tasa          number := p_val_tasa;
v_dia_plazo         number(8);
v_per_gracia        number(8);
v_per_vencimiento   number(4) :=30;
v_per_capital       pr_solicitudes.per_vto_capital%type;
v_nro_solicitud     number(10);
v_por_ajuste        number;
v_ttvalor           number(18,2);
v_denominacion_cp   varchar2(100);
v_fec_vto_campana   date;
v_cod_campana    cr_campanas.cod_campana%type;

v_nro_cuenta        varchar2(15);
v_cantidad          number(3);
-- Datos de los cargos -----------------------------------------------------
v_cod_transaccion   number(4);
v_cod_tas_cargo     number(4);
v_val_tas_cargo     number;
v_cod_mon_cargo     varchar2(3);
v_tpvlpor           varchar2(1);
v_aplicar           varchar2(3);
v_tpdetas           varchar2(1);
v_val_cargo         number(18,2);
v_cod_ent_seguro    number(6);
v_nmtrans           ge_transacciones.descripcion%type;
v_obligatorio       ge_transacciones_det.obligatorio%type;
v_afecta            ge_transacciones.afecta%type;
-- control del redondeo ----------------------------------------------------
v_redondeo          number(2) := 0;   -- redondeo a cero para moneda local
v_red_mon_local     number(2) := 0;
v_limite            number     := 10;     -- limite superior para ajustes de cuotas iguales en moneda local
v_ori_fondo         number;
v_val_car_minimo    number;
v_cod_rub_economico pr_solicitudes.cod_rub_economico%type;
v_por_ori_fondo     pr_solicitudes.por_ori_fondo%type;
v_ind_evaluacion    pr_solicitudes.ind_evaluacion%type := 'N';
v_tip_destino       pr_solicitudes.tip_destino%type;
v_nro_cta_debito    pr_solicitudes.nro_cta_debito%type;
v_deb_automatico    pr_solicitudes.deb_automatico%type:= nvl(p_deb_automatico,'N');
v_min_monto         ge_pro_pre_aprobados.min_monto%type;
v_max_monto         ge_pro_pre_aprobados.max_monto%type;
v_max_plazo         ge_pro_pre_aprobados.max_plazo%type;
v_min_plazo         ge_pro_pre_aprobados.min_plazo%type;
-- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
v_cod_sub_modalidad pr_solicitudes.cod_sub_modalidad%type; -- := nvl(p_cod_sub_modalidad,nvl(fug_obt_pardinamico('COD_SUB_MAD_PRE_APR',6,p_cod_modalidad),10));
v_id                varchar2(30);
--
v_user           ba_usuarios.cod_usuario%type := USER;
v_usu_atm        ba_usuarios.cod_usuario%type := 'ATM';  -- ATM
v_usu_hb         ba_usuarios.cod_usuario%type := user;  -- HBANK
v_existe         varchar2(1):='N';
v_lugar          varchar2(4000);
v_especial       varchar2(1):='N';

------------------ rutinas internas del procedimiento-----------------------
cursor sol_destino(p_nro_cuenta varchar2) is
                      select sd.tip_des_especifico, sd.monto
                        from pr_sol_destinos sd,
                             pr_cta_prestamos cp
                       where cp.nro_solicitud = sd.nro_solicitud
                         and cp.nro_cuenta = p_nro_cuenta;

cursor sol_garantia(p_nro_cuenta varchar2) is
       select nro_garantia, cod_garantia
        from pr_sol_garantias g,
             pr_cta_prestamos p
       where g.nro_solicitud = p.nro_solicitud
         and p.nro_cuenta = p_nro_cuenta;

PROCEDURE PR_VAL_TASA IS
  Cursor pizarras is
    select a.tas_interes, a.tas_minima, a.tas_maxima
    from cr_piz_montos b, cr_piz_plazos a
    where a.cod_modulo = 6--v_cod_modulo
    and a.cod_modalidad = p_cod_modalidad
    and a.cod_moneda = p_cod_moneda
    and b.cod_modulo = a.cod_modulo
    and b.cod_modalidad = a.cod_modalidad
    and b.cod_moneda = a.cod_moneda
    and b.mto_desde = a.mto_desde
    and a.cod_sub_modalidad = v_cod_sub_modalidad  -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
    and p_monto between b.mto_desde and b.mto_hasta
    and v_dia_plazo between a.plz_desde and a.plz_hasta;
    v_tas_interes number;
    v_tas_minima  number;
    v_tas_maxima  number;
BEGIN
   v_lugar := 'obtener_tasas de pizarras';
   open pizarras;
   fetch pizarras into v_tas_interes, v_tas_minima, v_tas_maxima;
   close pizarras;
   if v_val_tasa is null then
      v_val_tasa := v_tas_interes;
   else
      -- valido la tasa ingresada---
      IF NOT v_val_tasa BETWEEN v_tas_minima and v_tas_maxima then
         RAISE_APPLICATION_ERROR(-20000,'ERROR. Tasa fuera de Rango. Verifique la Pizarra');
      END IF;
   end if;
END;
-- Verificacion del codigo del cliente--------------------------------------
PROCEDURE PR_VAL_COD_PERSONA is
BEGIN
  v_lugar := 'OBTENER_CLIENTE ';
  SELECT EXO_IMPUESTOS, COD_USU_OFICIAL, COD_USU_PROMOTOR,
         COD_OFICINA, COD_DEPARTAMENTO
    INTO v_exo_impuestos, v_cod_usu_oficial, v_cod_usu_promotor,
         v_cod_oficina, v_cod_departamento
    FROM BA_PERSONAS B, GE_CLIENTES G
   WHERE B.COD_PERSONA = G.COD_PERSONA
     AND G.COD_PERSONA = P_COD_PERSONA;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Comentado por Ingrid Larrain 01/07/2004 y modificado para casos de generacion
    -- de solicitud
    BEGIN
       select gen.cod_ofi_matriz, 'N', ciu.cod_departamento
       into v_cod_oficina, v_exo_impuestos, v_cod_departamento
       from ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
       where gen.cod_ofi_matriz = ofi.cod_oficina
       and ofi.cod_ciudad = ciu.cod_ciudad
       and ofi.cod_pais   = ciu.cod_pais;
    END;
---    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cliente no esta definido en el Sistema');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'fu_val_cod_persona '||sqlerrm);
END;
-- Validacion del tipo de credito---------------------------------------------
PROCEDURE PR_VAL_COD_MODALIDAD IS
BEGIN
  SELECT 0 INTO v_dummy
    FROM GE_MODALIDADES
   WHERE COD_MODULO = v_cod_modulo
     AND COD_MODALIDAD = P_COD_MODALIDAD;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Tipo de Prestamo no habilitado');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR: Validar Modalidad '||SQLERRM);
END;
-- Validacion del codigo de la moneda-----------------------------------------
PROCEDURE PR_VAL_COD_MONEDA IS
BEGIN
  SELECT 0 INTO v_dummy
    FROM BA_MONEDAS
   WHERE COD_MONEDA = p_cod_moneda;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de Moneda inexistente');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR: Valida moneda '||SQLERRM);
END;
-- Procedimiento para obtener el tipo de tasa --------------------------------
PROCEDURE PR_OBT_TIPO_DE_TASA
  (WW_CDTRANS IN NUMBER,  WW_NMTRANS IN OUT VARCHAR2,  WW_CDDETAS IN OUT NUMBER,
   WW_APLICAR IN OUT VARCHAR2, WW_TPVLPOR IN OUT VARCHAR2, WW_TPDETAS IN OUT VARCHAR2,
   WW_OBLIGATORIO IN OUT VARCHAR2, WW_AFECTA IN OUT VARCHAR2) IS
BEGIN
  v_lugar := 'OBTENER TIPO DE TASA ';
  --- 1. Busco la tasa asociada a la transaccion ingresada ---
  /*SELECT TR.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO
    INTO WW_CDDETAS,WW_APLICAR,WW_TPVLPOR,WW_TPDETAS
    FROM GE_TRANSACCIONES TR, GE_TASAS TA
   WHERE TR.COD_MODULO = v_cod_modulo
     AND TR.COD_MODALIDAD = p_cod_modalidad
     AND TR.COD_TRANSACCION = WW_CDTRANS
     AND TR.TIPO = 'D'
     AND TR.COD_TASA IS NOT NULL
     AND TR.COD_TASA = TA.COD_TASA
     AND EXISTS (SELECT 0 FROM GE_TRANSACCIONES_DET
                  WHERE COD_MODULO = v_cod_modulo
                    AND COD_MODALIDAD = p_cod_modalidad
                    AND COD_TRANSACCION = 358 \* transaccion de desembolso de prestamos *\
                    AND COD_MOD_HIJO = TR.COD_MODULO
                    AND COD_MAD_HIJO = TR.COD_MODALIDAD
                    AND COD_TRA_HIJO = TR.COD_TRANSACCION); ver!*/
  SELECT initcap(TR.DESCRIPCION),TR.COD_TASA,TA.APLICAR,TA.TIP_VALOR,TA.TIPO, DT.OBLIGATORIO, TR.AFECTA
    INTO WW_NMTRANS,WW_CDDETAS,WW_APLICAR,WW_TPVLPOR,WW_TPDETAS, WW_OBLIGATORIO, WW_AFECTA
    FROM GE_TRANSACCIONES_DET DT, GE_TRANSACCIONES TR, GE_TASAS TA
   WHERE TR.COD_MODULO = v_cod_modulo
     AND TR.COD_MODALIDAD = p_cod_modalidad
     AND TR.COD_TRANSACCION = WW_CDTRANS
     AND TR.TIPO = 'D'
     AND TR.COD_TASA IS NOT NULL
     AND TR.COD_TASA = TA.COD_TASA
     AND DT.COD_MODULO = v_cod_modulo
     AND DT.COD_MODALIDAD = p_cod_modalidad
     AND DT.COD_TRANSACCION = 358 /* transaccion de desembolso de prestamos */
     AND DT.COD_MOD_HIJO = TR.COD_MODULO
     AND DT.COD_MAD_HIJO = TR.COD_MODALIDAD
     AND DT.COD_TRA_HIJO = TR.COD_TRANSACCION;
  --- 2. Si es la trans. 735 o 736, cobro de seguros por tasa, la tasa es nula ---
  /*IF WW_CDTRANS IN (735,736) THEN
     if fug_obt_tip_implementacion <> 2 then
        ww_APLICAR := 'CA';
     else
        ww_APLICAR := 'CI';
     end if;
     WW_TPVLPOR := 'I';
     WW_TPDETAS := 'F';
     WW_CDDETAS := NULL;
  END IF; ver!*/
EXCEPTION
  WHEN NO_DATA_FOUND THEN
     RAISE_APPLICATION_ERROR(-20000,'ERROR: Cargo no definido para Prestamos. Transaccion ' || WW_CDTRANS );
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'ERROR: OBT_TIPO_TASA '||sqlerrm);
END;
-- Funcion que obtiene el valor de la tasa fija ------------------------------
FUNCTION FU_OBT_VALOR_DE_TASA_FIJA
   (WW_CDDETAS IN NUMBER, WW_FCINICI IN DATE)
RETURN NUMBER IS
WW_VLDETAS NUMBER(15,2);
--para probar como esta en el form
V_FEC_VIGENCIA date;
V_TIP_VALOR ge_tasas.tip_valor%type;
V_TIPO ge_tasas.tipo%type;
V_COD_TASA ge_tasas.cod_tasa%type := WW_CDDETAS;
BEGIN
    v_lugar := 'OBTENER VALOR DE TASA FIJA ';
    -- tasa fija, buscar en tasa por fecha ---
    /*SELECT VAL_TASA
      INTO WW_VLDETAS
      FROM GE_TAS_FECHAS F1
     WHERE F1.COD_TASA      = WW_CDDETAS
       AND (F1.COD_MODALIDAD IS NULL OR (F1.COD_MODALIDAD = P_COD_MODALIDAD))
       AND (F1.COD_MODULO    IS NULL OR (F1.COD_MODULO    = V_COD_MODULO))
       AND (F1.COD_MONEDA    IS NULL OR (F1.COD_MONEDA    = P_COD_MONEDA))
       AND (F1.COD_OFICINA   IS NULL OR (F1.COD_OFICINA   = V_COD_OFICINA))
       AND  F1.NRO_CUENTA IS NULL
       AND F1.FEC_VIGENCIA  = (SELECT MAX(FEC_VIGENCIA)
                                 FROM GE_TAS_FECHAS F2
                                WHERE F1.COD_TASA      = F2.COD_TASA
                                 AND (F2.COD_MODALIDAD IS NULL OR (F2.COD_MODALIDAD = P_COD_MODALIDAD))
                                 AND (F2.COD_MODULO    IS NULL OR (F2.COD_MODULO    = V_COD_MODULO))
                                 AND (F2.COD_MONEDA    IS NULL OR (F2.COD_MONEDA    = P_COD_MONEDA))
                                 AND (F2.COD_OFICINA   IS NULL OR (F2.COD_OFICINA   = V_COD_OFICINA))
                                 AND  F2.FEC_VIGENCIA <= ww_fcinici
                                 AND  F2.NRO_CUENTA IS NULL);*/
    pag_gen.PR_OBT_VAL_TASA(v_cod_modulo,
                            p_cod_modalidad,
                            v_cod_oficina,
                            null,
                            p_cod_moneda,--5
                            null,
                            'S',
                            V_COD_TASA,
                            null,
                            v_fec_inicio,--10
                            WW_VLDETAS,
                            V_FEC_VIGENCIA,
                            V_TIP_VALOR,
                            V_TIPO,
                            p_cod_persona,--15
                            v_cod_sub_modalidad       -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
                            );
    v_val_car_minimo := pag_gen.fu_obt_val_minimo;
  RETURN ww_vldetas;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
     RETURN NULL;
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'obt_tasa_fija '||sqlerrm);
END;
-- Funcion que devuelve el valor de la tasa, si es variable ------------------
FUNCTION FU_OBT_VALOR_DE_TASA_VARIABLE
    (WW_CDDETAS IN NUMBER, WW_VLMONTO IN NUMBER, WW_FCINICI IN DATE)
  RETURN NUMBER IS
ww_vldetas NUMBER(15,2);
--para probar como esta en el form
V_FEC_VIGENCIA date;
V_TIP_VALOR ge_tasas.tip_valor%type;
V_TIPO ge_tasas.tipo%type;
V_COD_TASA ge_tasas.cod_tasa%type := WW_CDDETAS;
/*CURSOR  TV IS  SELECT TR.VAL_TASA
     FROM GE_TASAS T, GE_TAS_RANGOS TR
    WHERE T.COD_TASA = TR.COD_TASA
      AND T.COD_TASA = WW_CDDETAS
      AND (TR.COD_MODULO = v_COD_MODULO OR TR.COD_MODULO IS NULL)
      AND (TR.COD_MODALIDAD = P_COD_MODALIDAD OR TR.COD_MODALIDAD IS NULL)
      AND (TR.COD_MONEDA  = p_COD_MONEDA OR TR.COD_MONEDA IS NULL)
      AND (TR.COD_OFICINA  = v_COD_OFICINA OR TR.COD_OFICINA IS NULL)
      AND TR.VAL_HASTA >= ww_vlmonto
      AND TR.NRO_CUENTA IS NULL
      AND TR.FEC_VIGENCIA = (SELECT MAX(TRA.FEC_VIGENCIA)
                             FROM GE_TAS_RANGOS TRA
                               WHERE TRA.COD_TASA = WW_CDDETAS
                               AND (TRA.COD_MODULO = v_cod_modulo OR TRA.COD_MODULO IS NULL)
                               AND (TRA.COD_MODALIDAD = p_COD_MODALIDAD OR TRA.COD_MODALIDAD IS NULL)
                               AND (TRA.COD_MONEDA = p_COD_MONEDA OR TRA.COD_MONEDA IS NULL)
                              AND (TRA.COD_OFICINA = v_COD_OFICINA OR TRA.COD_OFICINA IS NULL)
                              AND TRA.VAL_HASTA >= ww_vlmonto
                              AND TRA.NRO_CUENTA IS NULL
                              AND TRA.FEC_VIGENCIA <= ww_fcinici)
    ORDER BY val_hasta;*/
BEGIN
   v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
   -- tasa variable, buscar en tabla de tasas variables ---
   /*OPEN TV;
   FETCH TV INTO ww_vldetas;
   CLOSE TV;*/
   pag_gen.PR_OBT_VAL_TASA(v_cod_modulo,
                           p_cod_modalidad,
                           v_cod_oficina,
                           null,
                           p_cod_moneda,
                           WW_VLMONTO,
                           'S',
                           V_COD_TASA,
                           null,
                           v_fec_inicio,
                           ww_vldetas,
                           V_FEC_VIGENCIA,
                           v_tip_valor,
                           v_tipo,
                           p_cod_persona,
                           v_cod_sub_modalidad       -- PCCFPPTC-1 - Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core  -- 10/2016 --
                           );
   v_val_car_minimo := pag_gen.FU_OBT_VAL_MINIMO;
   IF ww_vldetas is null then
       RAISE_APPLICATION_ERROR(-20000,'No existe Valor para la Tasa '||to_char(ww_cddetas)||' y el Monto '||to_char(ww_vlmonto)||
               ' Fecha '||to_char(ww_fcinici,'DD/MM/YYYY'));
   END IF;
   RETURN ww_vldetas;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
     RETURN NULL;
  WHEN OTHERS THEN
    if sqlcode <= -20000 then
       raise;
    else
       RAISE_APPLICATION_ERROR(-20000,'obt_tasa_variable '||sqlerrm);
    end if;
END;
-- Verificacion del codigo de tasa--------------------------------------------
PROCEDURE PR_OBT_DATOS_CARGO IS
BEGIN
   if v_cod_ent_seguro is not null then
      --- veo que tasa de seguro tiene el ente asegurador
      v_cod_tas_cargo := fug_obt_parentes(v_cod_ent_seguro,'COD_TAS_SEGURO');--'COD_TAS_SEG_SEGURO' ver!
      --- Ahora, busco el codigo de tasa que corresponde al plazo
      v_cod_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,
                                                       nvl(v_dia_plazo,0),
                                                       v_fec_inicio);
   end if;
   -- obtengo los datos de la tasa-----------------
   PR_OBT_TIPO_DE_TASA(v_cod_transaccion,v_nmtrans,v_cod_tas_cargo,
                       v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio, v_afecta);
   --- la tasa es de tipo  valor ---
   IF v_tpdetas= 'F' THEN
      --- tipo de tasa fijo      ---
      v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_FIJA(v_cod_tas_cargo,v_fec_inicio);
   ELSE
      --- tipo de tasa variable  ---
      if v_aplicar in ('PI','PC','PT','PL','CP','IP','TP') then
          if v_aplicar in ('PI','PC','PT','PL') then
            --- El primer rango es por plazo
             v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,v_dia_plazo,v_fec_inicio);
          else
             --- tipo de tasa variable  ---
             v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,nvl(v_tot_prestamo,p_monto),v_fec_inicio);
          end if;
          if v_aplicar IN ('CP','IP','TP') then -- aplicar al capital y plazo, busco ahora el valor por plazo
             v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_val_tas_cargo, v_dia_plazo,v_fec_inicio);
          elsif v_aplicar in ('PC','PT','PI') then
             v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_val_tas_cargo,nvl(v_tot_prestamo,p_monto),v_fec_inicio);
          end if;
      else
         v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,nvl(v_tot_prestamo,p_monto),v_fec_inicio);
      end if;
     /* v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_cod_tas_cargo,nvl(v_tot_prestamo,p_monto),v_fec_inicio);
      if v_aplicar = 'CP' then -- aplicar al capital y plazo, busco ahora el valor por plazo
         v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_VARIABLE(v_val_tas_cargo, v_dia_plazo,v_fec_inicio);
      end if;*/
   END IF;
   IF V_TPVLPOR IN ('I','P') OR V_COD_TRANSACCION IN (735,736) THEN
      --- porcentajes  o transacciones de seguros  ---
      v_cod_mon_cargo :=v_mon_local;
   ELSE
      --- en caso de que sean valores ----------------
      v_cod_mon_cargo := p_cod_moneda;
      v_val_cargo := v_val_tas_cargo;
      v_val_tas_cargo := null;
   END IF;
END;

-- Carga de cargos de la propuesta-------------------------------------------
PROCEDURE PR_GEN_CARGOS IS
v_cod_tip_canal ge_tip_canales.cod_tip_canal%type;
--
CURSOR cargos is
  Select decode(a.cod_transaccion,709,1,710,2,a.cod_transaccion) orden,  -- solo para ordenamiento
         a.cod_transaccion, a.cod_ent_seguro, nvl(b.obligatorio,'N') obligator
    from ge_sol_cargos a, ge_transacciones_det b
   where a.cod_transaccion = b.cod_tra_hijo (+)
     and a.cod_modulo = b.cod_mod_hijo (+)
     and a.cod_modalidad = b.cod_mad_hijo (+)
     and a.cod_modulo = v_cod_modulo
     and a.cod_modalidad = p_cod_modalidad
     and ((NVL(v_exo_impuestos,'N') = 'N') or
          (NVL(v_exo_impuestos,'N') = 'S' and nvl(b.obligatorio,'N') = 'N'))
   order by 1;
BEGIN

  FOR cc in cargos loop
      v_cod_transaccion := cc.cod_transaccion;
      v_cod_ent_seguro  := cc.cod_ent_seguro;
      v_val_tas_cargo   := null;
      v_val_cargo       := null;
      v_cod_tas_cargo   := null;
      v_cod_mon_cargo   := null;
      pr_obt_datos_cargo;

      --If cc.obligator = 'S' or nvl(v_val_cargo,0) != 0 Then
          insert into pr_sol_cargos
               (nro_solicitud, cod_transaccion, fec_tasa, val_tasa,
                monto, cod_tasa, cod_ent_seguro, cod_moneda,
                mto_mon_prestamo)
          values
               (v_nro_solicitud,v_cod_transaccion,v_fec_inicio, v_val_tas_cargo,
                v_val_cargo, v_cod_tas_cargo, cc.cod_ent_seguro,v_cod_mon_cargo,
                null);
      --End If;
  end loop;
END;
-- Generacion de cuotas -----------------------------------------------------
PROCEDURE PR_GEN_CUOTAS  IS
  WW_DIAVENC VARCHAR2(02);
  WW_FRANCES NUMBER;
  WW_TASADIV NUMBER := v_val_tasa / 36500 * 30.416666666666666666666666666667; --ver!
  WW_VLSALAN NUMBER(18,2) := v_tot_prestamo;
  WW_TTCUOTA NUMBER(18,2) := NULL;
  WW_DFCUOTA NUMBER(18,2);
  WW_TTCAPIT NUMBER(18,2) := 0;
  WW_TTREFUE NUMBER(18,2) := 0;
  WW_REFREAL NUMBER(18,2) := 0;
  WW_CTREFUE NUMBER(6)  := 0;
  WW_NRO     NUMBER(6)  := 0;
  WW_VECES   NUMBER(3)  := 0;
  V_VAL_INT_ORIGINAL NUMBER(18,2) :=0;
  --
  V_FEC_VTO_HABIL    DATE;
  V_FEC_VTO_EXACTO       DATE;
  V_SAL_CAP_ANTERIOR NUMBER(18,2);
  V_DIA_PERIORO      NUMBER(6);
  V_DIA_INTERES      NUMBER(6);
  V_VAL_INTERES      NUMBER(18,2);
  V_TTCUOTA          NUMBER(18,2);
  V_DIA_PERIODO      NUMBER(8);
  V_MTO_CAPITAL      NUMBER(18,2);
  v_fec_ven_anterior date;
  v_val_cuota        number(18,2);
  v_dias             number;
BEGIN
-- dia de vencimiento
ww_diavenc := TO_CHAR(V_FEC_PRI_VENCIMIENTO,'DD');
------------------------------------------------------------------------
LOOP
  v_fec_ven_anterior := v_fec_inicio;
  ww_veces := NVL(ww_veces,0)  + 1;
  --- calculo del valor del metodo frances ----------------------------- ver!
  --if ww_tasadiv = 0 and p_can_cuotas = 1 then ver!
  if (power((1+WW_TASADIV),(p_can_cuotas-WW_CTREFUE))-1) > 0 then
     --ww_frances := nvl(v_tot_prestamo,0); ver!
     ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(p_can_cuotas-ww_ctrefue)) - 1);
  else
     ww_frances := ((NVL(v_tot_prestamo,0)-NVL(WW_TTREFUE,0)))/
                   ((p_can_cuotas-WW_CTREFUE));
      /*ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(p_can_cuotas-ww_ctrefue)) - 1); ver!*/
  end if;
  v_val_cuota := round((WW_FRANCES * power(1 + WW_TASADIV, (0))),v_redondeo) +
                 round(WW_VLSALAN * WW_TASADIV, v_redondeo);
  --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
  ----------------------------------------------------------------------
  v_mto_interes := 0;
  ww_vlsalan  := v_tot_prestamo;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
  -- borro las cuotas si existen
  delete from pr_sol_cuotas
   where nro_solicitud = v_nro_solicitud;
  FOR CUOTA IN 1..p_can_cuotas LOOP

        if cuota = 1 then
           V_FEC_VTO_HABIL := V_FEC_PRI_VENCIMIENTO;
           V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO;
        else
           V_FEC_VTO_HABIL := add_months(V_FEC_PRI_VENCIMIENTO,(cuota-1));
           V_FEC_VTO_EXACTO := v_fec_pri_vencimiento + (((cuota-1)*30));
        end if;
        --V_FEC_VTO_HABIL := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, cuota -1); ver!
        --V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
        v_dias := V_FEC_VTO_HABIL - v_fec_ven_anterior;
        V_SAL_CAP_ANTERIOR := ww_vlsalan;
        V_DIA_PERIODO      := v_dias;
        V_DIA_INTERES      := v_dias;
        V_VAL_INTERES      := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
        /*IF CUOTA = 1 AND ABS(30 - (V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO)) > 2 THEN
           \* se hace el calculo del interes por el plazo del periodo de gracia *\
           V_DIA_PERIODO := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_DIA_INTERES := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
           v_val_cuota   := null;
        ELSE --ver!
           if fug_obt_tip_implementacion in (1,7,9) then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           else
              V_DIA_PERIODO := 30;
              V_DIA_INTERES := 30;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           end if;
        END IF;*/
        IF V_VAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
           IF p_tip_monto = 'N' THEN  -- NETO
              V_MTO_CAPITAL := V_MTO_CAPITAL;
           ELSE
              V_MTO_CAPITAL := nvl(V_VAL_INT_ORIGINAL,0) - nvl(V_MTO_INTERES,0);
           END IF;
           ww_refreal := NVL(ww_refreal,0) + NVL(V_MTO_CAPITAL,0);
           --v_val_cuota := null;
        ELSE
           ww_nro := ww_nro + 1;
           /*if v_val_cuota is not null and fug_obt_tip_implementacion in (1,7,9) then
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
           else
              V_MTO_CAPITAL := ROUND((ww_frances * power((1 + ww_tasadiv), (ww_nro - 1))),v_redondeo);
           end if;
           v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;*/
           if cuota = 1 and abs(30 - (v_fec_pri_vencimiento - v_fec_inicio)) > 2 then
              V_MTO_CAPITAL := round(WW_FRANCES * power((1 + WW_TASADIV),(WW_NRO -1)),v_redondeo);
           else
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
           end if;
        END IF;
        V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL,0);
        V_TTCUOTA := NVL(V_MTO_CAPITAL,0) + NVL(V_VAL_INTERES,0);
        ww_dfcuota :=  NVL(ww_ttcuota,V_TTCUOTA) - NVL(V_TTCUOTA,0);
        -- ajuste de cuotas para que sean iguales solo se hace en guaranies
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND v_limite)  THEN
           V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
           V_TTCUOTA := V_TTCUOTA + ww_dfcuota;
        END IF;
        if V_VAL_INT_ORIGINAL = 0 then
           WW_TTCUOTA := V_TTCUOTA;
        end if;
        --ww_ttcuota := V_TTCUOTA;
        ww_vlsalan := NVL(ww_vlsalan,0) - V_MTO_CAPITAL;
        ww_ttcapit := NVL(ww_ttcapit,0) + NVL(V_MTO_CAPITAL,0);
        V_MTO_INTERES := V_MTO_INTERES + NVL(V_VAL_INTERES,0);
        v_fec_ven_anterior := V_FEC_VTO_HABIL;
        if p_cod_modalidad = 660 then
           V_DIA_PERIODO := 1;
           V_DIA_INTERES := 1;
        end if;
        -- inserto el registro en la tabla de cuotas
        if p_cod_modalidad = 699 then
           v_fec_vto_exacto := pag_cal.fu_obt_fec_habil(last_day(p_fec_pri_vencimiento), -1, NULL);
           INSERT INTO pr_sol_cuotas
               (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil,
                fec_vto_exacto, val_interes, sal_capital, sal_cap_anterior,
                dia_periodo, dia_transcurridos, dia_interes, tip_calculo,
                val_int_original, val_int_adelantado)
           VALUES
               (v_nro_solicitud, cuota, p_monto, p_fec_pri_vencimiento,
                v_fec_vto_exacto, 0, 0, p_monto,
                p_fec_pri_vencimiento - p_fec_inicio, p_fec_pri_vencimiento - p_fec_inicio,
                p_fec_pri_vencimiento - p_fec_inicio,
                'A', p_monto, nvl(v_val_interes,0));
        else
           insert into pr_sol_cuotas
               (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil,
                fec_vto_exacto, val_interes, sal_capital, sal_cap_anterior,
                dia_periodo, dia_transcurridos, dia_interes, tip_calculo,
                val_int_original, val_int_adelantado)
           values
               (v_nro_solicitud, cuota, nvl(v_mto_capital,0), v_fec_vto_habil,
                v_fec_vto_exacto, nvl(v_val_interes,0), ww_vlsalan, ww_vlsalan + v_mto_capital,
                v_dia_periodo, v_dia_periodo, v_dia_interes, 'V',
                v_val_int_original, 0 );
        end if;
  END LOOP;
  --- veo si se necesita ajustar la ultima cuota de capital ------
  --IF NVL(:PR_SOL_CUOTAS.NRO_CUOTA,-1) <> :PR_SOLICITUDES.SC_CTCUOTA THEN
  --  PREVIOUS_RECORD;
  --END IF;
  IF ABS(NVL(ww_refreal,0) - NVL(ww_ttrefue,0)) < 10 OR ww_veces > 12 OR p_tip_monto = 'N' THEN
     EXIT;
  END IF;
END LOOP;
ww_dfcuota := nvl(v_tot_prestamo,0) - nvl(ww_ttcapit,0);
IF ww_dfcuota <> 0 THEN
   V_MTO_CAPITAL := nvl(V_MTO_CAPITAL,0) + ww_dfcuota;
    IF NVL(V_VAL_INTERES,0) >= ww_dfcuota and abs(WW_DFCUOTA) <= -1 /* solo se ajusta si existe interes*/
      and nvl(V_VAL_INTERES,0) > 0 THEN
       V_VAL_INTERES := nvl(V_VAL_INTERES,0) - ww_dfcuota;
       V_MTO_INTERES := nvl(V_MTO_INTERES,0) - ww_dfcuota;
    ELSE
         V_TTCUOTA := NVL(V_MTO_CAPITAL,0) + NVL(V_VAL_INTERES,0);
   END IF;
   -- Actualizo la ultima cuota
   update pr_sol_cuotas
      set mto_capital = nvl(v_mto_capital,0),
          val_interes = nvl(v_val_interes,0)
    where nro_solicitud = v_nro_solicitud
      and nro_cuota = p_can_cuotas; -- ultima cuota
END IF;
-- vencimiento final del prestamo es igual al de la ult.cuota--
update pr_solicitudes
   set fec_vencimiento = V_FEC_VTO_HABIL,
       mto_interes     = V_MTO_INTERES
 where nro_solicitud = v_nro_solicitud;
----------------------------------------------------------------
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'GENERACION_CUOTAS '||SQLERRM);
END;
-- Generacion de cuotas -----------------------------------------------------
PROCEDURE PR_GEN_CUOTAS_ESP(P_ESPECIAL IN VARCHAR2)  IS
  WW_DIAVENC VARCHAR2(02);
  WW_FRANCES NUMBER;
  WW_TASADIV NUMBER := v_val_tasa / 36500 * 30.416666666666666666666666666667; --ver!
  WW_VLSALAN NUMBER(18,2) := v_tot_prestamo;
  WW_TTCUOTA NUMBER(18,2) := NULL;
  WW_DFCUOTA NUMBER(18,2);
  WW_TTCAPIT NUMBER(18,2) := 0;
  WW_TTREFUE NUMBER(18,2) := 0;
  WW_REFREAL NUMBER(18,2) := 0;
  WW_CTREFUE NUMBER(6)  := 0;
  WW_NRO     NUMBER(6)  := 0;
  WW_VECES   NUMBER(3)  := 0;
  V_VAL_INT_ORIGINAL NUMBER(18,2) :=0;
  --
  V_FEC_VTO_HABIL    DATE;
  V_FEC_VTO_EXACTO       DATE;
  V_SAL_CAP_ANTERIOR NUMBER(18,2);
  V_DIA_PERIORO      NUMBER(6);
  V_DIA_INTERES      NUMBER(6);
  V_VAL_INTERES      NUMBER(18,2);
  V_TTCUOTA          NUMBER(18,2);
  V_DIA_PERIODO      NUMBER(8);
  V_MTO_CAPITAL      NUMBER(18,2);
  v_fec_ven_anterior date;
  v_val_cuota        number(18,2);
  v_dias             number;
  v_can_cuotas       number(10):=0;
BEGIN
-- dia de vencimiento
ww_diavenc := TO_CHAR(V_FEC_PRI_VENCIMIENTO,'DD');
------------------------------------------------------------------------
LOOP
  v_fec_ven_anterior := v_fec_inicio;
  ww_veces := NVL(ww_veces,0)  + 1;
  --- calculo del valor del metodo frances ----------------------------- ver!
  --if ww_tasadiv = 0 and p_can_cuotas = 1 then ver!
  if P_ESPECIAL='S' then
    v_can_cuotas:= p_can_cuotas -1;
  else
    v_can_cuotas:= p_can_cuotas;
  end if;

  if (power((1+WW_TASADIV),(v_can_cuotas/*p_can_cuotas*/-WW_CTREFUE))-1) > 0 then
     --ww_frances := nvl(v_tot_prestamo,0); ver!
     ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(v_can_cuotas/*p_can_cuotas*/-ww_ctrefue)) - 1);
  else
     ww_frances := ((NVL(v_tot_prestamo,0)-NVL(WW_TTREFUE,0)))/
                   ((v_can_cuotas/*p_can_cuotas*/-WW_CTREFUE));
      /*ww_frances := ((NVL(V_TOT_PRESTAMO,0)-NVL(ww_ttrefue,0))* ww_tasadiv) /
                (power((1 + ww_tasadiv),(p_can_cuotas-ww_ctrefue)) - 1); ver!*/
  end if;
  v_val_cuota := round((WW_FRANCES * power(1 + WW_TASADIV, (0))),v_redondeo) +
                 round(WW_VLSALAN * WW_TASADIV, v_redondeo);
  --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
  ----------------------------------------------------------------------
  v_mto_interes := 0;
  ww_vlsalan  := v_tot_prestamo;
  ww_ttcapit  := 0;
  ww_refreal  := 0;
  ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
  -- borro las cuotas si existen
  delete from pr_sol_cuotas
   where nro_solicitud = v_nro_solicitud;
  FOR CUOTA IN 1..p_can_cuotas LOOP

        if cuota = 1 then
           V_FEC_VTO_HABIL := V_FEC_PRI_VENCIMIENTO;
           V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO;
        else
           V_FEC_VTO_HABIL := add_months(V_FEC_PRI_VENCIMIENTO,(cuota-1));
           V_FEC_VTO_EXACTO := v_fec_pri_vencimiento + (((cuota-1)*30));
        end if;
        --V_FEC_VTO_HABIL := ADD_MONTHS(V_FEC_PRI_VENCIMIENTO, cuota -1); ver!
        --V_FEC_VTO_EXACTO := V_FEC_PRI_VENCIMIENTO + ((cuota -1) * 30);
        v_dias := V_FEC_VTO_HABIL - v_fec_ven_anterior;
        V_SAL_CAP_ANTERIOR := ww_vlsalan;
        V_DIA_PERIODO      := v_dias;
        V_DIA_INTERES      := v_dias;
        V_VAL_INTERES      := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
        /*IF CUOTA = 1 AND ABS(30 - (V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO)) > 2 THEN
           \* se hace el calculo del interes por el plazo del periodo de gracia *\
           V_DIA_PERIODO := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_DIA_INTERES := V_FEC_PRI_VENCIMIENTO - V_FEC_INICIO;
           V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv / 30.416666666666666666666666666667 * V_DIAS),v_redondeo);
           v_val_cuota   := null;
        ELSE --ver!
           if fug_obt_tip_implementacion in (1,7,9) then
              V_DIA_PERIODO := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_DIA_INTERES := V_FEC_VTO_HABIL - v_fec_ven_anterior;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           else
              V_DIA_PERIODO := 30;
              V_DIA_INTERES := 30;
              V_VAL_INTERES := ROUND((ww_vlsalan * ww_tasadiv),v_redondeo);
           end if;
        END IF;*/
        IF V_VAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
           IF p_tip_monto = 'N' THEN  -- NETO
              V_MTO_CAPITAL := V_MTO_CAPITAL;
           ELSE
              V_MTO_CAPITAL := nvl(V_VAL_INT_ORIGINAL,0) - nvl(V_MTO_INTERES,0);
           END IF;
           ww_refreal := NVL(ww_refreal,0) + NVL(V_MTO_CAPITAL,0);
           --v_val_cuota := null;
        ELSE
           ww_nro := ww_nro + 1;
           /*if v_val_cuota is not null and fug_obt_tip_implementacion in (1,7,9) then
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
           else
              V_MTO_CAPITAL := ROUND((ww_frances * power((1 + ww_tasadiv), (ww_nro - 1))),v_redondeo);
           end if;
           v_val_cuota := V_MTO_CAPITAL + V_VAL_INTERES;*/
           if cuota = 1 and P_ESPECIAL='S' then
              V_MTO_CAPITAL := 0;
           elsif cuota = 2/*1*/ and abs(30 - (v_fec_pri_vencimiento - v_fec_inicio)) > 2 then
              V_MTO_CAPITAL := round(WW_FRANCES * power((1 + WW_TASADIV),(1/*WW_NRO*/ -1)),v_redondeo);
           else
              V_MTO_CAPITAL := v_val_cuota - V_VAL_INTERES;
           end if;
        END IF;
        V_VAL_INT_ORIGINAL := NVL(V_VAL_INT_ORIGINAL,0);
        V_TTCUOTA := NVL(V_MTO_CAPITAL,0) + NVL(V_VAL_INTERES,0);
        ww_dfcuota :=  NVL(ww_ttcuota,V_TTCUOTA) - NVL(V_TTCUOTA,0);
        -- ajuste de cuotas para que sean iguales solo se hace en guaranies
        IF (ABS(ww_dfcuota) BETWEEN 0.001 AND v_limite)  THEN
           V_VAL_INTERES := V_VAL_INTERES + ww_dfcuota;
           V_TTCUOTA := V_TTCUOTA + ww_dfcuota;
        END IF;
        if V_VAL_INT_ORIGINAL = 0 then
           WW_TTCUOTA := V_TTCUOTA;
        end if;
        --ww_ttcuota := V_TTCUOTA;
        ww_vlsalan := NVL(ww_vlsalan,0) - V_MTO_CAPITAL;
        ww_ttcapit := NVL(ww_ttcapit,0) + NVL(V_MTO_CAPITAL,0);
        V_MTO_INTERES := V_MTO_INTERES + NVL(V_VAL_INTERES,0);
        v_fec_ven_anterior := V_FEC_VTO_HABIL;

           insert into pr_sol_cuotas
               (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil,
                fec_vto_exacto, val_interes, sal_capital, sal_cap_anterior,
                dia_periodo, dia_transcurridos, dia_interes, tip_calculo,
                val_int_original, val_int_adelantado)
           values
               (v_nro_solicitud, cuota, nvl(v_mto_capital,0), v_fec_vto_habil,
                v_fec_vto_exacto, nvl(v_val_interes,0), ww_vlsalan, ww_vlsalan + v_mto_capital,
                v_dia_periodo, v_dia_periodo, v_dia_interes, 'V',
                v_val_int_original, 0 );

  END LOOP;
  --- veo si se necesita ajustar la ultima cuota de capital ------
  --IF NVL(:PR_SOL_CUOTAS.NRO_CUOTA,-1) <> :PR_SOLICITUDES.SC_CTCUOTA THEN
  --  PREVIOUS_RECORD;
  --END IF;
  IF ABS(NVL(ww_refreal,0) - NVL(ww_ttrefue,0)) < 10 OR ww_veces > 12 OR p_tip_monto = 'N' THEN
     EXIT;
  END IF;
END LOOP;
ww_dfcuota := nvl(v_tot_prestamo,0) - nvl(ww_ttcapit,0);
IF ww_dfcuota <> 0 THEN
   V_MTO_CAPITAL := nvl(V_MTO_CAPITAL,0) + ww_dfcuota;
    IF NVL(V_VAL_INTERES,0) >= ww_dfcuota and abs(WW_DFCUOTA) <= -1 /* solo se ajusta si existe interes*/
      and nvl(V_VAL_INTERES,0) > 0 THEN
       V_VAL_INTERES := nvl(V_VAL_INTERES,0) - ww_dfcuota;
       V_MTO_INTERES := nvl(V_MTO_INTERES,0) - ww_dfcuota;
    ELSE
         V_TTCUOTA := NVL(V_MTO_CAPITAL,0) + NVL(V_VAL_INTERES,0);
   END IF;
   -- Actualizo la ultima cuota
   update pr_sol_cuotas
      set mto_capital = nvl(v_mto_capital,0),
          val_interes = nvl(v_val_interes,0)
    where nro_solicitud = v_nro_solicitud
      and nro_cuota = p_can_cuotas; -- ultima cuota
END IF;
-- vencimiento final del prestamo es igual al de la ult.cuota--
update pr_solicitudes
   set fec_vencimiento = V_FEC_VTO_HABIL,
       mto_interes     = V_MTO_INTERES
 where nro_solicitud = v_nro_solicitud;
----------------------------------------------------------------
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'GENERACION_CUOTAS '||SQLERRM);
END;



---------------------------------------------------------------
-- Calculo de los cargos ----------------------------------------------------
PROCEDURE PR_CAL_CARGOS IS
ww_dfcargos number(18,2);
v_mto_equivalente number(18,2);
v_cod_tra_ajuste  number(4);
v_monto           number(18,2);
cursor cargos is
   select cod_transaccion, cod_tasa, cod_ent_seguro,val_tasa, monto,cod_moneda, mto_mon_prestamo
     from pr_sol_cargos
    where nro_solicitud = v_nro_solicitud
      for update of monto
    order by decode(cod_transaccion,709,1,710,2,cod_transaccion);
BEGIN
   --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
   --- cero los totales de cargo de tipo valor y el total general de cargos -------------
   V_TTVALOR := 0;
   V_MTO_CARGO := 0;
   v_cod_tra_ajuste := null;
   for cc in cargos loop
     v_mto_equivalente := 0;
     -- para realizar ajustes si es necesario----------
     if v_cod_tra_ajuste is null then
        v_cod_tra_ajuste := cc.cod_transaccion;
     end if;
     -- obtengo los datos de la tasa-----------------
     PR_OBT_TIPO_DE_TASA(cc.cod_transaccion,v_nmtrans,cc.cod_tasa,
                       v_aplicar,v_tpvlpor,v_tpdetas,v_obligatorio, v_afecta);
     v_val_tas_cargo := FU_OBT_VALOR_DE_TASA_FIJA(cc.cod_tasa,v_fec_inicio);
     IF cc.COD_TRANSACCION IS NOT NULL AND
        (cc.COD_MONEDA IS NULL OR (v_TPVLPOR = 'V' AND nvl(cc.MONTO,0) = 0)) THEN
         RAISE_APPLICATION_ERROR(-20000,'Valores nulos en Cargos. Verificar la Trans. '||to_char(cc.cod_transaccion));
     END IF;
     IF v_TPVLPOR = 'P' THEN
        v_MTO_EQUIVALENTE := 0;
        --- la tasa es un porcentaje-----------------------------------------------------
        --IF v_APLICAR IN ('CI','IN','PI','IP','PT','TP') THEN ver!
        IF v_aplicar in ('CI','IN') then
           --- aplicable al interes -----------------------------------------------------
           v_MTO_EQUIVALENTE :=  ROUND(v_MTO_INTERES */* v_DIA_PLAZO * */cc.val_tasa / 100,v_redondeo);
           --v_MTO_EQUIVALENTE :=  ROUND(v_MTO_INTERES * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
        ELSIF v_APLICAR IN ('PI','IP','PT','TP') then
           v_mto_equivalente := round(v_mto_interes * v_dia_plazo * cc.val_tasa / 36500,v_redondeo);
        END IF;
        --IF v_APLICAR IN ('CA','CI','PC','CP','PT','TP') THEN
        IF v_APLICAR IN ('CA','CI','CP') THEN
           --- es aplicable al capital --------------------------------------------------
           v_MTO_EQUIVALENTE :=  NVL(v_MTO_EQUIVALENTE,0) +
                           ROUND(v_TOT_PRESTAMO * /*v_DIA_PLAZO **/ cc.val_tasa / 100,v_redondeo);
                           --ROUND(v_TOT_PRESTAMO * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
        ELSIF v_aplicar in ('PC','PT','TP') then
           v_mto_equivalente := nvl(v_mto_equivalente,0) +
                                round(v_tot_prestamo * v_dia_plazo / 36500,v_redondeo);
        END IF;
        if nvl(v_mto_equivalente,0) <= nvl(v_val_car_minimo,0) then
           v_mto_equivalente := nvl(v_val_car_minimo,0);
        end if;
     ELSIF v_TPVLPOR = 'I' THEN
        v_MTO_EQUIVALENTE := 0;
        ---v_cod_tra_ajuste  := cc.cod_transaccion; --siempre se ajusta si ha y impuesto
        --- la tasa es un impuesto ------------------------------------------------------
        IF v_APLICAR IN ('CI','IN','PI','IP','PT','TP') THEN
           --- aplicable al interes -----------------------------------------------------
           IF v_DIA_PLAZO < 365 THEN
              v_MTO_EQUIVALENTE :=  ROUND(v_MTO_INTERES * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
           ELSE
              v_MTO_EQUIVALENTE :=  ROUND(v_MTO_INTERES * cc.val_tasa / 100,v_redondeo);
           END IF;
        END IF;
        IF v_APLICAR IN  ('CA','CI','PC','CP','PT','TP') THEN
           --- es aplicable al capital --------------------------------------------------
           IF CC.COD_ENT_SEGURO IS NOT NULL THEN
              --- es un seguro ----------------------------------------------------------
              v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE,0) +
                             ROUND(v_TOT_PRESTAMO * cc.val_tasa / 100,v_redondeo);
           ELSE
              --- es un impuesto sobre el capital ---------------------------------------
              IF v_DIA_PLAZO < 365 THEN
                 v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE,0) +
                                ROUND(v_TOT_PRESTAMO * v_DIA_PLAZO * cc.val_tasa / 36500,v_redondeo);
              ELSE
                 v_MTO_EQUIVALENTE := NVL(v_MTO_EQUIVALENTE,0) +
                                ROUND(v_TOT_PRESTAMO * cc.val_tasa / 100,v_redondeo);
              END IF;
           END IF;
        END IF;
     ELSIF v_TPVLPOR = 'V' THEN
        --- es un monto valor -----------------------------------------------------------
        v_mto_equivalente := cc.monto;
        v_TTVALOR := NVL(v_TTVALOR,0) + NVL(v_MTO_EQUIVALENTE,0);
     END IF;
     --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
     if nvl(v_afecta,'Z') <> 'G' then
       v_MTO_CARGO := NVL(v_MTO_CARGO,0) + NVL(v_MTO_EQUIVALENTE,0);
     end if;
     ------------------------------------------------------------------------------------
     v_monto := null;
     IF V_TPVLPOR IN ('I','P') THEN  /* solo si es porcentaje */
        IF CC.COD_MONEDA = P_COD_MONEDA THEN
           -- moneda del cargo es igual a la moneda de la simulacion ----------------------
           V_MONTO := V_MTO_EQUIVALENTE;
        ELSE
           -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
           v_red_mon_local :=  fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,p_cod_modalidad,v_mon_local);
           /*
           || PCCLIANC-4
           || El Monto del Cargo debe ser sin decimales
           || Siempre es en moneda local
           */
           V_MONTO := ROUND(V_MTO_EQUIVALENTE * v_cotizacion,/*v_redondeo*/v_red_mon_local);
        END IF;
     END IF;
     update pr_sol_cargos
        set mto_mon_prestamo = NVL(v_MTO_EQUIVALENTE,0),
            monto            = nvl(v_monto,monto)
      where current of cargos;
   END LOOP;
   IF v_MTO_CARGO >= v_TOT_PRESTAMO THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Total de Cargos '||v_MTO_CARGO||' es superior al Total del Préstamo '||v_TOT_PRESTAMO);
   ELSE
      IF P_TIP_MONTO = 'N' AND V_TOT_PRESTAMO <> P_MONTO THEN
         --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
         IF NVL(V_TOT_PRESTAMO,0)-NVL(V_MTO_CARGO,0) <> P_MONTO THEN
            -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
            ww_dfcargos := P_MONTO - (NVL(V_TOT_PRESTAMO,0)-NVL(V_MTO_CARGO,0));
            for cc in cargos loop
              if cc.cod_transaccion = 704 then
                 v_mto_equivalente := NVL(V_MTO_EQUIVALENTE,0) - ww_dfcargos;
                 v_mto_cargo       := NVL(V_MTO_CARGO,0) - ww_dfcargos;
                 update pr_sol_cargos
                    set mto_mon_prestamo =  NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                        monto =  decode(cod_moneda,p_cod_moneda,NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                                       decode(cod_moneda,v_mon_local,
                                       round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo),
                                       round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo)))
                  where nro_solicitud = v_nro_solicitud
                   and cod_transaccion = cc.cod_transaccion;
              end if;
            end loop;
            --V_MTO_EQUIVALENTE := NVL(V_MTO_EQUIVALENTE,0) - ww_dfcargos;
            --V_MTO_CARGO := NVL(V_MTO_CARGO,0) - ww_dfcargos;
            /*update pr_sol_cargos
               set mto_mon_prestamo = NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                   monto = decode(cod_moneda,p_cod_moneda,NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0),
                                  decode(cod_moneda,v_mon_local,
                                  round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo),
                                  round(((NVL(mto_mon_prestamo,0) - nvl(ww_dfcargos,0)) * v_cotizacion),v_redondeo)))
             where nro_solicitud = v_nro_solicitud
               and cod_transaccion = v_cod_tra_ajuste;*/
         END IF;
      END IF;
   END IF;
   -- actualizo el total de cargos de  la solicitud
   update pr_solicitudes
      set mto_cargo = v_mto_cargo
    where nro_solicitud = v_nro_solicitud;
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'CALCULAR_CARGOS '||SQLERRM);
END;
-- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
begin
   v_lugar:= 'Inicio de Proceso';
   v_user:= user;
   v_especial:='N';
   v_cod_campana := p_cod_campana;
   v_cod_sub_modalidad:=p_cod_sub_modalidad;
   --- Veo el tipo de redondeo de los calculos ------------------------------------------
   IF P_COD_MONEDA <> V_MON_LOCAL THEN
      v_limite   := 0.05;
   END IF;
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,p_cod_modalidad,p_cod_moneda);
   v_lugar:= 'Validaciones iniciales';
   -- Valido el codigo del cliente-------------------------------------------
   PR_VAL_COD_PERSONA;
   -- Valido el codigo de la modalidad que recibo----------------------------
   PR_VAL_COD_MODALIDAD;
   -- valido la moneda-------------------------------------------------------
   PR_VAL_COD_MONEDA;
   -- valido el monto -------------------------------------------------------
   IF NVL(p_monto,0) <= 0 THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Ingrese Monto del Credito');
   END IF;
   v_tot_prestamo :=  p_monto;
   -- valido el tipo de monto -----------------------------------------------
   IF nvl(p_tip_monto,'X') not in ('B','N') then
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
   END IF;
   -- valido la cantidad de cuotas ------------------------------------------
   IF nvl(p_can_cuotas,0) < 1 then
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Ingrese la cantidad de cuotas');
   END IF;
   -- Valido la fecha del primer vencimiento --------------------------------
   IF v_fec_pri_vencimiento <= v_fec_actual and p_cod_modalidad <> 660 THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Primer Vencimiento debe ser posterior a la fecha de Hoy');
   END IF;
   -- Cargo los datos por defecto de la tabla de parametros -----------------
   v_lugar:= 'Obtener Datos por defecto';
   declare
     x_val_tasa number;
   Begin
      Select tip_interes, tip_amortizacion, aju_ult_cuota, tip_aju_fecha,
             aju_gracia, cod_sec_credito, cod_departamento,
             tip_documento, tipo, val_tasa
        into v_tip_interes, v_tip_amortizacion, v_aju_ult_cuota, v_tip_aju_fecha,
             v_aju_gracia, v_cod_sec_credito, v_cod_dep_parametro,
             v_tip_documento, v_tipo, x_val_tasa
        from pr_sol_parametros
       where cod_modulo = v_cod_modulo
         and cod_modalidad = p_cod_modalidad;

       -- si se habilito la tasa de interes por defecto, se carga
       if nvl(x_val_tasa,0) > 0 and p_val_tasa is null then
          v_val_tasa := x_val_tasa;
       end if;
   exception
      when no_data_found then
         v_tip_interes := 'V';
         v_tip_amortizacion := 'P';
         v_aju_ult_cuota := 'N';
         v_tip_aju_fecha := 'E';
         v_aju_gracia := 'N';
         v_cod_sec_credito := 1;
         v_tip_documento := 1;
         v_tipo := 'A';
         v_cod_dep_parametro := 3;
   end;
   --
   v_dia_plazo := ADD_MONTHS(v_fec_pri_vencimiento,p_can_cuotas-1) - v_fec_inicio;
   v_per_gracia := v_fec_pri_vencimiento - v_fec_inicio;
   v_per_capital := 30;
   v_lugar:= 'Valida Tasa';
   -- Valido la tasa de interes ---------------------------------------------
   PR_VAL_TASA;
   -- Asigno el nro de la solicitud -----------------------------------------
   if p_grabar = 'S' then
      select s_nro_solicitud.nextval into v_nro_solicitud from dual;
   else
      --- Recupero secuencia negativa para solicitud auxiliar
      select s_nro_sol_negativo.nextval into v_nro_solicitud from dual;
   end if;
    v_lugar:= 'Origen de Fondos';
    ---- Origen de Fondos
    if p_cod_moneda IS NOT NULL  THEN
       if  p_cod_moneda= 'GS' then 
           v_ori_fondo := 1;
       elsif p_cod_moneda= 'USD' THEN
           v_ori_fondo := 2;
           v_por_ori_fondo := 100;
        end if;
    end if;

 
    v_lugar:= 'Obtener Sectores de Credito y Rubro';
    if p_cod_modalidad = 68 then
       v_cod_rub_economico := fug_obt_pardinamico('COD_RUB_ECO_PRE_APR_ATM');
       BEGIN
          SELECT referencia
            INTO v_cod_sec_credito
            FROM pr_rub_economicos
           WHERE cod_rub_economico = v_cod_rub_economico;
       EXCEPTION
          WHEN OTHERS THEN
           Raise_application_error(-20000, 'Error al obtener el Código de Sector de Crédito.');
       END;
       v_ind_evaluacion := null;
    else
       v_cod_rub_economico:= p_cod_rub_economico;
       v_cod_sec_credito:= p_cod_sec_economico;
       v_ind_evaluacion := null;
    end if;
    v_lugar:= 'Obteniendo Tipo de Destino';
    if p_tip_destino is not null then
       v_tip_destino := p_tip_destino;
    else
       v_tip_destino := fup_obt_tip_destino(p_cod_persona,
                                         p_cod_modalidad,
                                         p_cod_moneda,
                                         0,
                                         v_mto_interes,
                                         p_monto,
                                         v_dia_plazo,
                                         p_tip_monto);
    end if;

   v_lugar:= 'Insertando en pr_solicitudes:';
   -- inserto el registro en la tabla de solicitudes ------------------------
   begin

   -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013
   v_cod_oficina := FUG_OBT_OFI_OFICIAL(p_cod_persona);
   insert into pr_solicitudes
          (nro_solicitud, descripcion, monto, tip_amortizacion,
           dia_plazo, fec_vencimiento, mto_interes,
           per_vto_capital, per_gracia, cod_persona,
           fec_inicio, tip_monto, tot_prestamo,
           cod_modulo, cod_modalidad, cod_sub_modalidad, cod_moneda,
           cod_oficina, fec_pri_vencimiento, cod_sec_credito,
           cod_departamento, tip_documento, exo_impuesto, cod_usu_promotor,
           cod_canal, cod_campana, tip_destino, cod_banca, tip_renovacion, cod_ori_fondo,
           cod_rub_economico, por_ori_fondo, ind_evaluacion, nro_cta_debito, deb_automatico,
           tip_interes, iva_desglose)
   values (v_nro_solicitud, nvl(p_descripcion,'.'), p_monto, v_tip_amortizacion,  /* price */
           v_dia_plazo, v_fec_vencimiento, v_mto_interes,
           v_per_capital, v_per_gracia, p_cod_persona,
           v_fec_inicio, p_tip_monto, v_tot_prestamo,
           v_cod_modulo, p_cod_modalidad, v_cod_sub_modalidad, p_cod_moneda,
           v_cod_oficina, v_fec_pri_vencimiento, v_cod_sec_credito,
           nvl(v_cod_departamento, v_cod_dep_parametro),
           v_tip_documento /* vista*/, v_exo_impuestos, nvl(p_cod_usu_promotor,v_cod_usu_promotor),
           null, null, v_tip_destino, p_cod_banca, 'A', v_ori_fondo ,
           v_cod_rub_economico, v_por_ori_fondo, v_ind_evaluacion, v_nro_cta_debito, v_deb_automatico,
           v_tip_interes, 'S');
   exception
     when others then
       --dbms_output.put_line('Pr_solicitudes '||sqlerrm);
       raise_application_error(-20001,'Insert PR_SOLICITUDES '||sqlerrm);
   end;
   -- No se generan cargos
   ----PR_GEN_CARGOS;
   -- generar cuotas --------------------------------------------------------
   v_lugar:= 'Generando Cuotas';
   --Si es especial llamamos a otro proceso
   if v_especial ='N' then
      PR_GEN_CUOTAS;
   else
      PR_GEN_CUOTAS_ESP(v_especial);
   end if;
   -- No se calculan los cargos ----------------------------------------------------
   ---PR_CAL_CARGOS;
   -- verifico el tipo de prestamo
   if p_tip_monto = 'B' then
      update pr_solicitudes
         set tot_prestamo = v_tot_prestamo,
             mto_cargo    = v_mto_cargo,
             tot_desembolsar = v_tot_prestamo - v_mto_cargo
       where nro_solicitud = v_nro_solicitud;

    END IF;
    v_lugar:= 'Insertando en pr_sol_cuotas';
    -- finalmente inserto la cuota 0 ------------------------------------------------------
       begin
         INSERT INTO PR_SOL_CUOTAS
               (NRO_SOLICITUD,NRO_CUOTA,FEC_VTO_EXACTO,FEC_VTO_HABIL,VAL_INTERES,VAL_INT_ADELANTADO,
                MTO_CAPITAL,SAL_CAPITAL,DIA_TRANSCURRIDOS,DIA_INTERES,DIA_PERIODO)
            VALUES
               (V_NRO_SOLICITUD,0,V_FEC_INICIO,V_FEC_INICIO,0,0,0,V_TOT_PRESTAMO,0,0,0);
       EXCEPTION
         WHEN OTHERS THEN
           raise_application_error(-20001,'Error al insertar cuotas '||sqlerrm);
       END;
    v_lugar:= 'Insertando en pr_sol_tasas';
    -- inserto el registro de la tasa ----------------------------------------------------
    begin
       INSERT INTO PR_SOL_TASAS
             (NRO_SOLICITUD, FEC_VIGENCIA, VAL_TASA, TIP_COBRO, PER_VENCIMIENTO)
       VALUES
            (V_NRO_SOLICITUD,V_FEC_INICIO,V_VAL_TASA,'V',v_per_vencimiento);
    EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20002,'Error al insertar el registro de tasas '||sqlerrm);
    END;
    -- inserto el registro de la garantía --------------------------------------------------
    v_lugar:= 'Insertando en pr_sol_garantias';
    begin
       if p_cod_gar_pre_ant is not null then
            INSERT INTO PR_SOL_GARANTIAS
                (NRO_SOLICITUD, COD_GARANTIA,NRO_GARANTIA, MTO_APLICADO)
           VALUES
                (V_NRO_SOLICITUD, p_cod_gar_pre_ant,p_nro_gar_pre_ant,v_tot_prestamo);
       else
           INSERT INTO PR_SOL_GARANTIAS
                (NRO_SOLICITUD, COD_GARANTIA, MTO_APLICADO)
           VALUES
                (V_NRO_SOLICITUD, 1,v_tot_prestamo);
       end if;     
    EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20003,'Error al insertar el registro de garantia '||sqlerrm);
    END;
    v_lugar:= 'Insertando en pr_sol_destinos';
    -- inserto el registro del destino ----------------------------------------------------
    begin
       INSERT INTO PR_SOL_DESTINOS
            (NRO_SOLICITUD, TIP_DES_ESPECIFICO, MONTO)
       VALUES
            (V_NRO_SOLICITUD, nvl(v_tip_destino,3),v_tot_prestamo);
    EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20003,'Error al insertar el registro de garantia '||sqlerrm);
    END;

     update ge_pro_pre_aprobados a
        set a.nro_solicitud = v_nro_solicitud
      where a.rowid = v_id;
    v_lugar:= 'Ajuste de TAE';
    --Ajustamos el valor del TAE(Solicitud)
    -- PRP_AJU_VAL_TAE_RES_04(v_nro_solicitud,'SO',null);

   --*****************************************
     p_nro_solicitud := v_nro_solicitud;

   EXCEPTION
     WHEN OTHERS THEN
        if sqlcode <= -20000 then
           raise;
        else
            raise_application_error(-20000,'Propuesta Nueva-persona: '||p_cod_persona||' '||v_lugar||' '||sqlerrm);
        end if;
end PRP_GEN_ATM_SOLICITUD_RES_04;
/

