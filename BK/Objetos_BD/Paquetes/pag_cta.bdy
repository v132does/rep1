CREATE OR REPLACE PACKAGE BODY IT.PAG_CTA IS

G_COD_MON_LOCAL GE_MOVIMIENTOS.COD_MONEDA%TYPE := PAG_GEN.FU_OBT_MON_LOCAL;
G_MOVS PAG_CTA.RG_MOVS;
v_ok     varchar2(1);
v_pedido varchar2(400);
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);
v_sob_autorizado varchar2(1) := 'N';
/* Obtiene el saldo debito atm del registro almacenado en el paquete.*/
FUNCTION FU_SAL_DEB_ATM
 RETURN NUMBER;

/* Obtiene La linea total de Sobregiro vigente */
FUNCTION FU_OBT_LIN_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE default Null
 )
 RETURN NUMBER
 IS

V_VAL_ACUERDO NUMBER(18, 2) := 0;
V_FEC_ACTUAL GE_CALENDARIOS.FEC_ACTUAL%TYPE;
BEGIN
 V_VAL_ACUERDO := 0;
 -- Sino se recibe la fecha, se obtiene la fecha actual del modulo
 if p_fec_actual is null then
    v_fec_actual := pag_cal.fu_obt_fec_actual(nvl(g_ctas.cod_modulo,4));
 else
    v_fec_actual := p_fec_actual;
 end if;
 -- Busco el monto actual de la linea de sobregiro
 SELECT NVL(SUM(MONTO),0)
   INTO v_val_acuerdo
   FROM  cc_lin_sobregiros
  WHERE nro_cuenta = p_nro_cuenta
    AND v_fec_actual between fec_inicio and fec_vencimiento
    AND estado = 'A'; -- aprobado

 Return v_val_acuerdo;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_acuerdo := 0;
      Return v_val_acuerdo;
END;
/* Ver transaccion prohibida. */
FUNCTION FU_VER_TRA_PROHIBIDA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN NUMBER default NULL
 ,P_COD_MODALIDAD IN NUMBER default NULL
 )
 RETURN VARCHAR2
 IS

V_ENCONTRO VARCHAR2(1) := 'N';
BEGIN
  v_encontro := 'N';
  SELECT 'S'
    INTO v_encontro
    FROM GE_TRA_PROHIBIDAS
   WHERE NRO_CUENTA = p_nro_cuenta
     AND COD_TRANSACCION = p_cod_transaccion
     AND COD_MODULO = nvl(p_cod_modulo,g_ctas.cod_modulo)
     AND COD_MODALIDAD = nvl(p_cod_modalidad, g_ctas.cod_modalidad);
  -- se encontro la transaccion prohibida ---
  IF v_encontro = 'S' THEN
     g_msj_error := 'Cuenta '||p_nro_cuenta ||' tiene transaccion prohibida ';
     g_cod_error := 01;
  END IF;

  Return v_encontro;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      g_cod_error := 00;
      g_msj_error := '';
      RETURN V_ENCONTRO;
   WHEN TOO_MANY_ROWS THEN
      g_msj_error := 'Cuenta con Trans.Proh. Duplicada';
      g_cod_error := 02;
      RETURN V_ENCONTRO;
   WHEN OTHERS THEN
      g_msj_error := 'ERROR - Cuando buscaba en GE_TRA_PROHIBIDAS ';
      g_cod_error := 03;
      Return v_encontro;
END;
/* Obtiene la Cta Cte si es una Cuenta Combinada. */
FUNCTION FU_OBT_CTA_CTE_COMB
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NRO_CTA_CTE CC_CTA_COMBINADAS.NRO_CTA_CTE%TYPE;
BEGIN
     SELECT NRO_CTA_CTE
       INTO V_NRO_CTA_CTE
       FROM CC_CTA_COMBINADAS
      WHERE NRO_CTA_AHORRO = P_NRO_CUENTA;
     RETURN V_NRO_CTA_CTE;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      PAG_CTA.G_MSJ_ERROR := 'La Cuenta no posee Cuenta Corriente Combinada ';
      PAG_CTA.G_COD_ERROR := 04;
      RETURN V_NRO_CTA_CTE;
   WHEN OTHERS THEN
      PAG_CTA.G_MSJ_ERROR := 'ERROR - Cuando buscaba en CTA_CTE_COMBINADA ';
      PAG_CTA.G_COD_ERROR := 05;
      RETURN V_NRO_CTA_CTE;
END;
/* Obtiene la Cta Cte si es una Cuenta Combinada. */
FUNCTION LF_OBT_CTA_AHO_COMB
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_NRO_CTA_AHO CC_CTA_COMBINADAS.NRO_CTA_AHORRO%TYPE;
BEGIN
     SELECT NRO_CTA_AHORRO
       INTO V_NRO_CTA_AHO
       FROM CC_CTA_COMBINADAS
      WHERE NRO_CTA_CTE = P_NRO_CUENTA;
     RETURN V_NRO_CTA_AHO;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      PAG_CTA.G_MSJ_ERROR := 'La Cuenta no posee Cuenta Ahorro Combinada ';
      PAG_CTA.G_COD_ERROR := 04;
      RETURN V_NRO_CTA_AHO;
   WHEN OTHERS THEN
      PAG_CTA.G_MSJ_ERROR := 'ERROR - Cuando buscaba en CTA_CTE_COMBINADA ';
      PAG_CTA.G_COD_ERROR := 05;
      RETURN V_NRO_CTA_AHO;
END;
/* Obtiene la moneda que contiene el registro del paquete. */
FUNCTION FU_OBT_MON_CUENTA
 RETURN VARCHAR2
 IS
BEGIN
    return G_CTAS.COD_MONEDA;
END;
/* Retorna el nombre de la cuenta contenida en el registro del paquete. */
FUNCTION FU_OBT_NOM_CUENTA
 RETURN VARCHAR2
 IS
BEGIN
    return G_CTAS.DENOMINACION;
END;
/* Obtiene el saldo total almacenado en el registro del paquete. */
FUNCTION FU_SAL_TOTAL
 RETURN NUMBER
 IS
BEGIN
    RETURN G_CTAS.SAL_TOTAL;
END;
/* Obtiene la transaccion prohibida del registro almacenado en el paq. */
FUNCTION FU_TRA_PROHIBIDA
 RETURN VARCHAR2
 IS
BEGIN
    RETURN G_CTAS.TRA_PROHIBIDA;
END;
/* Obtiene el saldo retenido almacenado en el registro del paquete. */
FUNCTION FU_SAL_RETENIDO
 RETURN NUMBER
 IS
BEGIN
    RETURN G_CTAS.SAL_RETENIDO;
END;
/* Obtiene el saldo disponible almacenado en el registro del paquete. */
FUNCTION FU_SAL_DISPONIBLE
 RETURN NUMBER
 IS
BEGIN
    RETURN NVL(G_CTAS.SAL_DISPONIBLE,0);
END;
/* Obtiene el saldo debito atm del registro almacenado en el paquete. */
FUNCTION FU_SAL_DEB_ATM
 RETURN NUMBER
 IS
BEGIN
    RETURN G_CTAS.MTO_DEB_PENDIENTES;
END;
/* Obtiene el saldo bloqueado almacenado en el registro del paquete. */
FUNCTION FU_SAL_BLOQUEADO
 RETURN NUMBER
 IS
BEGIN
    RETURN G_CTAS.SAL_BLOQUEADO;
END;
/* Obtiene la modalidad de la cuenta contenida en el registro. */
FUNCTION FU_OBT_MAD_CUENTA
 RETURN NUMBER
 IS
BEGIN
    return  G_CTAS.COD_MODALIDAD;
END;
/* Obtiene el datos de acuerdo de sobregiro almacenado en el registro. */
FUNCTION FU_ACU_SOBREGIRO
 RETURN VARCHAR2
 IS
BEGIN
    RETURN G_CTAS.ACUERDO;
END;
/* Obtiene el dato de autorizacion almacenado en el registro. */
FUNCTION FU_OBT_AUTORIZADO
 RETURN VARCHAR2
 IS
BEGIN
    RETURN  G_CTAS.AUTORIZADO;
END;
/* Retorna es la transaccion puede ser vista o no por el cliente. */
FUNCTION FU_VE_CLIENTE
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 RETURN VARCHAR2
 IS

V_VE_CLIENTE VARCHAR2(1) := 'N';
BEGIN
  SELECT VE_CLIENTE
    INTO v_ve_cliente
    FROM GE_TRANSACCIONES
   WHERE cod_modulo = g_ctas.cod_modulo
   and cod_modalidad = g_ctas.cod_modalidad
   and cod_transaccion = p_cod_transaccion;
   RETURN(v_ve_cliente);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    v_ve_cliente := 'S';
    RETURN(v_ve_cliente);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20007,g_msj_error);
END;
/* Obtiene el siguiente numero de cuenta. */
FUNCTION FU_OBT_SIG_CTA
 (P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
BEGIN
   return (fug_obt_pardinamico('SIG_NROCTA'));
exception
   when others then
      raise_application_error(-20006,
      'Obt. sgte. cta.-'||sqlerrm);
END;
/* Calcula el digito verificador. */
FUNCTION FU_CAL_DIG_VERIFICA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_digito number(1);
   v_sum    number(10);
   v_con    varchar2(20);
   v_lon    number(10);
   v_tex    varchar2(20);
   v_aux    varchar2(20);
   v_cam    varchar2(20);
   v_mul    number(10);
   v_dig    varchar2(20);
   v_dif    number(10);
   v_may    number(10);
------------------------------------------------------------------------------------
-- Obj. Calcula el digito verificador de la cuenta, retorna el digito verificador --
------------------------------------------------------------------------------------
BEGIN
   V_SUM := 0;
   V_CON := '713971397139713';
   V_LON := LENGTH(p_nro_cuenta);
   V_TEX := SUBSTR(V_CON,(15-TO_NUMBER(V_LON)+1),
                    TO_NUMBER(V_LON));
   FOR I IN 1..TO_NUMBER(V_LON) LOOP
       V_AUX := SUBSTR(V_TEX,I,1);
       V_CAM := SUBSTR(p_nro_cuenta,I,1);
       V_MUL := TO_NUMBER(V_AUX) * TO_NUMBER(V_CAM);
       V_DIG := SUBSTR(V_MUL,TO_NUMBER(LENGTH(V_MUL)),1);
       V_SUM := TO_NUMBER(V_SUM) + TO_NUMBER(V_DIG);
   END LOOP;
   V_MAY := (TO_NUMBER(SUBSTR(V_SUM,1,1))+1);
   V_MAY := V_MAY || '0';
   V_DIF := TO_NUMBER(V_MAY) - TO_NUMBER(V_SUM);
   V_digito  := SUBSTR(V_DIF,TO_NUMBER(LENGTH(V_DIF)),1);
   RETURN v_digito;
END;
/* Valida que existan los datos de tasas. Devuelve nombre */
FUNCTION FU_VAL_COD_TASA
 (P_COD_MODULO IN GE_TAS_FECHAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TAS_FECHAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN GE_TAS_FECHAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_TASA IN GE_TAS_FECHAS.COD_TASA%TYPE
 ,P_FEC_VIGENCIA IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_NRO_CUENTA IN GE_TAS_FECHAS.NRO_CUENTA%TYPE
 ,P_COD_SUB_MODALIDAD IN GE_TAS_FECHAS.COD_SUB_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS
v_descripcion ge_tasas.descripcion%type;
v_tipo ge_tasas.tipo%type;
v_aux varchar2(1);
--v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
v_cod_sub_modalidad number(5) := p_cod_sub_modalidad;
v_cod_ente          ge_entes.cod_ente%type;
BEGIN

  if p_nro_cuenta is not null and v_cod_sub_modalidad is null then
     v_cod_sub_modalidad := fug_obt_cod_sub_modalidad(p_nro_cuenta);
  end if;

  if p_nro_cuenta is not null then
    v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
  else
    v_cod_ente := null;
  end if;

  Begin
    SELECT DESCRIPCION, TIPO
      INTO v_descripcion, v_tipo
      FROM GE_TASAS
     WHERE COD_TASA = p_cod_tasa;
    If v_tipo = 'F' Then
       Begin
          Select '1'  into v_aux
            from GE_TAS_FECHAS
           Where cod_tasa  = p_cod_tasa
             and nvl(COD_OFICINA,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
             AND nvl(COD_MODULO,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
             AND nvl(COD_MODALIDAD,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
             AND nvl(COD_SUB_MODALIDAD,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
             AND nvl(COD_ENTE,nvl(v_cod_ente,-1))            = nvl(v_cod_ente,-1)
             AND nvl(COD_MONEDA,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
             AND nvl(nro_cuenta,nvl(p_nro_cuenta,'x'))      = nvl(p_nro_cuenta,'x')
             and FEC_VIGENCIA  = (select max(FEC_VIGENCIA)
                                    from GE_TAS_FECHAS
                                   Where COD_TASA      = p_cod_tasa
                                     and nvl(COD_OFICINA,nvl(p_cod_oficina,-1))     =
                                         nvl(p_cod_oficina,-1)
                                     AND nvl(COD_MODULO,nvl(p_cod_modulo,-1))       =
                                         nvl(p_cod_modulo,-1)
                                     AND nvl(COD_MODALIDAD,nvl(p_cod_modalidad,-1)) =
                                         nvl(p_cod_modalidad,-1)
                                     AND nvl(COD_SUB_MODALIDAD,nvl(v_cod_sub_modalidad,-1)) =
                                         nvl(v_cod_sub_modalidad,-1)
                                     AND nvl(COD_ENTE,nvl(v_cod_ente,-1))            =
                                         nvl(v_cod_ente,-1)
                                     AND nvl(COD_MONEDA,nvl(p_cod_moneda,'x'))      =
                                         nvl(p_cod_moneda,'x')
                                     and nvl(nro_cuenta,nvl(p_nro_cuenta,'x'))      =
                                         nvl(p_nro_cuenta,'x')
                                     and FEC_VIGENCIA <= p_fec_vigencia);
       Exception
          When NO_DATA_FOUND Then
               raise_application_error(-20007,'Tasa inexistente en GE_TAS_FECHAS, FECHA :'||TO_CHAR(p_fec_vigencia,'DD/MM/RRRR'));
       End;
    Elsif v_tipo = 'V' Then
       Begin
          Select '1'  into v_aux
            from GE_TAS_RANGOS
           Where cod_tasa  = p_cod_tasa
             and nvl(COD_OFICINA,nvl(p_cod_oficina,-1))     = nvl(p_cod_oficina,-1)
             AND nvl(COD_MODULO,nvl(p_cod_modulo,-1))       = nvl(p_cod_modulo,-1)
             AND nvl(COD_MODALIDAD,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
             AND nvl(COD_sub_MODALIDAD,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
             AND nvl(COD_ENTE,nvl(v_cod_ente,-1))            = nvl(v_cod_ente,-1)
             AND nvl(COD_MONEDA,nvl(p_cod_moneda,'x'))      = nvl(p_cod_moneda,'x')
             AND nvl(nro_cuenta,nvl(p_nro_cuenta,'x'))      = nvl(p_nro_cuenta,'x')
             and FEC_VIGENCIA  = (select max(FEC_VIGENCIA)
                                    from GE_TAS_RANGOS
                                   Where COD_TASA      = p_cod_tasa
                                     and nvl(COD_OFICINA,nvl(p_cod_oficina,-1))     =
                                         nvl(p_cod_oficina,-1)
                                     AND nvl(COD_MODULO,nvl(p_cod_modulo,-1))       =
                                         nvl(p_cod_modulo,-1)
                                     AND nvl(COD_MODALIDAD,nvl(p_cod_modalidad,-1)) =
                                         nvl(p_cod_modalidad,-1)
                                     AND nvl(COD_SUB_MODALIDAD,nvl(v_cod_sub_modalidad,-1)) =
                                         nvl(v_cod_sub_modalidad,-1)
                                     AND nvl(COD_ENTE,nvl(v_cod_ente,-1))            =
                                         nvl(v_cod_ente,-1)
                                     AND nvl(COD_MONEDA,nvl(p_cod_moneda,'x'))      =
                                         nvl(p_cod_moneda,'x')
                                    and FEC_VIGENCIA  <= p_fec_vigencia);
       Exception
          When NO_DATA_FOUND Then
               raise_application_error(-20008, 'Tasa inexistente en GE_TAS_RANGOS, FECHA :'||TO_CHAR(p_fec_vigencia,'DD/MM/RRRR'));
          WHEN TOO_MANY_ROWS THEN
               NULL;
       End;
    End If;
  EXCEPTION
      WHEN NO_DATA_FOUND THEN
           raise_application_error(-20009, 'Tasa no definida en el Sistema ');
  End;
  RETURN v_descripcion;
END;
/* Valida que existan los datos de tasas. Devuelve nombre */
FUNCTION FU_VAL_COD_TASA
 (P_COD_MODULO IN GE_TAS_FECHAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TAS_FECHAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN GE_TAS_FECHAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN GE_TAS_FECHAS.COD_OFICINA%TYPE
 ,P_COD_TASA IN GE_TAS_FECHAS.COD_TASA%TYPE
 ,P_FEC_VIGENCIA IN GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_NRO_CUENTA IN GE_TAS_FECHAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_descripcion ge_tasas.descripcion%type;
v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
BEGIN

   v_descripcion :=  FU_VAL_COD_TASA(P_COD_MODULO
                                     ,P_COD_MODALIDAD
                                     ,P_COD_MONEDA
                                     ,P_COD_OFICINA
                                     ,P_COD_TASA
                                     ,P_FEC_VIGENCIA
                                     ,P_NRO_CUENTA
                                     ,v_cod_sub_modalidad);


   RETURN v_descripcion;
END;

/* Llavea la Cuenta */
FUNCTION FU_LLAVEAR_CUENTA
 (P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_NOCTURNO IN CHAR default 'N'
 )
 RETURN VARCHAR2
 IS

V_SAL_TOTAL AH_CTA_VISTAS.SAL_TOTAL%TYPE;
BEGIN

  IF p_cod_modalidad in (31,334) THEN
     IF p_nocturno = 'N' THEN
        SELECT SAL_TOTAL
          INTO v_sal_total
           FROM AH_CTA_VISTAS
         WHERE nro_cuenta = p_nro_cuenta
           FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
     ELSE
        SELECT SAL_TOTAL
          INTO v_sal_total
          FROM AH_CTA_VISTAS_NOC
         WHERE nro_cuenta = p_nro_cuenta
           FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
    END IF;

   ELSIF p_cod_modalidad = 41 THEN
     IF p_nocturno = 'N' THEN
      SELECT sal_total
        INTO v_sal_total
        FROM cc_cta_corrientes
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
     ELSE
      SELECT sal_total
        INTO v_sal_total
        FROM cc_cta_corrientes_noc
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
     END IF;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
   ELSIF p_cod_modalidad in (42, 43, 44, 45, 46, 47, 48, 49, 442, 455) THEN
      SELECT sal_total
        INTO v_sal_total
        FROM cc_cta_bancarias
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
   ELSIF p_cod_modalidad IN (33,34,35,36) THEN
      SELECT sal_total
        INTO v_sal_total
        FROM ah_cta_certificados
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
   ELSIF p_cod_modalidad IN (32,37,38) THEN
      SELECT sal_total
        INTO v_sal_total
        FROM ah_cta_plazos
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE OF nro_cuenta NOWAIT;
      RETURN('S');
   ELSE
       RAISE_APPLICATION_ERROR(-20000,'ERROR. Llaveo de Cuenta '||p_nro_cuenta||' Incorrecta');
   END IF;

   RETURN('N');

EXCEPTION
 WHEN OTHERS THEN
     RETURN('N');
END;
/* Afecta los saldos mensuales */
PROCEDURE PR_ACT_SAL_MENSUAL
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_MONTO IN NUMBER default 0
 )
 IS

V_CAN_DIAS CC_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
V_SAL_MINIMO CC_CTA_CORRIENTES.SAL_MINIMO%TYPE;
V_SAL_ACU_DIARIO CC_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_SAL_INICIAL CC_SAL_MENSUALES.SAL_INI_MES%TYPE;
V_FEC_PROXIMA DATE;
V_FEC_ACTUAL DATE;
V_CTA_COMBINADA CC_CTA_CORRIENTES.CTA_COMBINADA%TYPE;
BEGIN
     -- Busca las fechas que va a utilizar --
    pag_cal.pr_obt_dat_calendar(3);
    v_fec_proxima := pag_cal.g_fec_proxima;
    v_fec_actual := pag_cal.g_fec_actual;

    Select nvl(b.sal_total, 0) - nvl(b.sal_retenido, 0),
            nvl(a.sal_minimo, 0), nvl(b.cta_combinada, 'N')
    into v_sal_inicial, v_sal_minimo, v_cta_combinada
    from cc_cta_combinadas a, cc_cta_corrientes b
    Where a.nro_cta_cte(+) = b.nro_cuenta
    and b.nro_cuenta = p_nro_cuenta;

    If v_cta_combinada = 'S' and v_sal_inicial > v_sal_minimo Then
        v_sal_inicial := v_sal_minimo;
    End If;

   UPDATE cc_sal_mensuales
   SET sal_ini_mes = nvl(v_sal_inicial, 0)
   WHERE nro_cuenta = p_nro_cuenta
   AND ANO = to_number(to_char(v_fec_proxima,'YYYY'))
   AND MES = to_number(to_char(v_fec_proxima,'MM'));

   IF v_fec_actual + 1 <> v_fec_proxima THEN
      v_can_dias := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD')) - 1;
      -- Actualiza valores saldo acumulado del mes
      UPDATE cc_sal_mensuales
      SET sal_acu_diario = v_can_dias * nvl(v_sal_inicial, 0)
      WHERE nro_cuenta = p_nro_cuenta
      AND ANO = TO_NUMBER(TO_CHAR(v_fec_proxima,'YYYY'))
      AND MES = TO_NUMBER(TO_CHAR(v_fec_proxima,'MM'));
       -- SALDOS DEUDORES --
       ------------------------------------------------------------
      If nvl(v_sal_inicial, 0) < 0 Then
         UPDATE cc_sal_mensuales
         SET sal_acu_deudor = v_can_dias * nvl(v_sal_inicial, 0) * -1,
         can_dia_deudor = v_can_dias,
         sal_acu_acreedor = 0,
         can_dia_acreedor = 0
         WHERE nro_cuenta = p_nro_cuenta
         AND ano = to_char(v_fec_proxima,'YYYY')
         AND mes = to_char(v_fec_proxima,'MM');
           -----------------------------------------------------------------
           -- SALDOS ACREEDORES -- menor a cero
           ------------------------------------------------------------
      Else
         UPDATE cc_sal_mensuales
         SET sal_acu_acreedor = v_can_dias * nvl(v_sal_inicial, 0),
             can_dia_acreedor = v_can_dias,
             sal_acu_deudor = 0,
             can_dia_deudor = 0
            WHERE nro_cuenta = p_nro_cuenta
              AND ano = to_char(v_fec_proxima,'YYYY')
              AND mes = to_char(v_fec_proxima,'MM');
         End If;
     END IF;
     IF SQL%NOTFOUND THEN null; /*
        MESSAGE('No existe reg de mes proximo en AH_SAL_MENSUALES 1.
        Continuar.'); PAUSE; */
     END IF;
  EXCEPTION
     WHEN OTHERS THEN  null;
END;
/* Proceso para calcular cargo e impuesto. */
PROCEDURE PR_CAL_CARGO_E_IMPTO
 (P_COD_TRA_CARGO IN OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TRA_IMPUESTO IN OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_NRO_CUENTA IN OUT VARCHAR2
 ,P_COD_MODULO IN OUT AH_CTA_VISTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN OUT AH_CTA_VISTAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN OUT AH_CTA_VISTAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN OUT AH_CTA_VISTAS.COD_OFICINA%TYPE
 ,P_TRA_PROHIBIDA IN OUT AH_CTA_VISTAS.TRA_PROHIBIDA%TYPE
 ,P_AUT_PENDIENTE IN OUT AH_CTA_VISTAS.AUT_PENDIENTE%TYPE
 ,P_TAS_PERSONALIZADA IN OUT AH_CTA_VISTAS.TAS_PERSONALIZADA%TYPE
 ,P_MTO_TRANSACCION IN OUT NUMBER
 ,P_MTO_CARGO IN OUT NUMBER
 ,P_MTO_IMPUESTO IN OUT NUMBER
 ,P_TIP_TASA IN OUT VARCHAR2
 )
 IS

V_FEC_VIG_TASA DATE;
V_TIP_VALOR VARCHAR2(1);
V_TIP_TASA VARCHAR2(1);
V_COD_TASA AH_CTA_VISTAS.COD_TASA%TYPE;
V_VAL_TASA NUMBER := 0;
V_COD_MONEDA AH_CTA_VISTAS.COD_MONEDA%TYPE;
BEGIN
   IF P_NRO_CUENTA IS NOT NULL THEN
      IF P_TRA_PROHIBIDA  = 'S'  THEN
       IF FU_VER_TRA_PROHIBIDA(P_NRO_CUENTA, P_COD_TRA_CARGO) = 'S' THEN
          pag_cta.g_msj_error := 'ERROR. No se puede cobrar cargos - transaccion prohibida '||to_char(P_COD_TRA_CARGO);
          pag_cta.g_cod_error := 08;
          RETURN;
       END IF;
    END IF;
    IF P_AUT_PENDIENTE = 'S' THEN
       PAG_AUT.PR_OBT_AUTORIZACION(P_NRO_CUENTA,               -- nro de cuenta
                           P_COD_TRA_IMPUESTO,         -- transaccion padre
                           P_COD_TRA_IMPUESTO,         -- transaccion hijo
                           0,                          -- importe
                           G_CTAS.COD_USU_AUTORIZADOR, -- Ret. autorizador
                           G_CTAS.COD_AUTORIZACION);   -- Ret. cod autorizacion

         IF g_ctas.COD_AUTORIZACION IS NULL then
            pag_cta.g_msj_error  := 'ERROR. No se puede cobrar cargos a esta cuenta - Tiene Autorizacion';
             pag_cta.g_cod_error := 09;
            RETURN;
         END IF;
      END IF;
   END IF;
   V_COD_MONEDA := P_COD_MONEDA;
   PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO, P_COD_MODALIDAD, P_COD_OFICINA, P_NRO_CUENTA,
                           V_COD_MONEDA, P_MTO_TRANSACCION, P_TAS_PERSONALIZADA,
                           V_COD_TASA,P_COD_TRA_cARGO, NULL, V_VAL_TASA, V_FEC_VIG_TASA,
                           V_TIP_VALOR, V_TIP_TASA);

   IF P_TIP_TASA = V_TIP_VALOR THEN
      pag_cta.g_msj_error := 'ERROR. Esta operacion no permite Tasas tipo '||
                             p_tip_tasa||' - Corrija la tabla de tasas o de tipos de transacciones';
    pag_cta.g_cod_error := 10;
    RETURN;
   END IF;
   IF V_COD_TASA IS NOT NULL AND V_COD_TASA <> 0 AND V_VAL_TASA <> 0 then
      IF V_TIP_VALOR = 'V' then
         P_MTO_CARGO := V_VAL_TASA;
      ELSE
         P_MTO_CARGO := V_VAL_TASA * P_MTO_TRANSACCION/100;
      END IF;
   ELSE
      P_MTO_CARGO := 0;
   END IF;
   V_COD_TASA := null;
   V_VAL_TASA := null;
   PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO, P_COD_MODALIDAD, P_COD_OFICINA, P_NRO_CUENTA,
                           V_COD_MONEDA, P_MTO_CARGO, P_TAS_PERSONALIZADA,
                           V_COD_TASA,P_COD_TRA_IMPUESTO, NULL, V_VAL_TASA, V_FEC_VIG_TASA,
                           V_TIP_VALOR, V_TIP_TASA);
   IF V_COD_TASA IS NOT NULL AND V_COD_TASA <> 0 AND V_VAL_TASA <> 0 THEN
      IF V_TIP_VALOR = 'V' then
         P_MTO_IMPUESTO := V_VAL_TASA;
    ELSE
       P_MTO_IMPUESTO := V_VAL_TASA * P_MTO_CARGO/100;
      END IF;
   ELSE
      P_MTO_IMPUESTO := 0;
   END IF;
   EXCEPTION
      WHEN OTHERS THEN
         pag_cta.g_msj_error := 'Error en Calcula_cargo_e_impuesto'||sqlerrm;
         pag_cta.g_cod_error := 11;
         raise_application_error(-20011, pag_cta.g_msj_error);
END;
/* Proceso para obtner la cuenta. */
PROCEDURE PR_OBT_CUENTA
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 )
 IS

V_COD_MODULO GE_CTA_CLIENTES.COD_MODULO%TYPE;
V_COD_MODALIDAD GE_CTA_CLIENTES.COD_MODALIDAD%TYPE;
V_COD_PERSONA GE_CTA_CLIENTES.COD_PERSONA%TYPE;
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_FEC_VIGENCIA GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
V_TIP_TASA GE_TASAS.TIPO%TYPE;
V_EST_PROCESO BA_MODULOS.ESTADO%TYPE;
V_COD_USU_OFICIAL GE_CLIENTES.COD_USU_OFICIAL%TYPE;
V_COD_SEG_CLIENTE GE_SEG_CLIENTES.COD_SEG_CLIENTE%TYPE;
Begin
   --- Inicializar errores
   g_msj_error := ' ';
   g_cod_error := 0;
   -- inicializar datos de cuentas
   g_ctas.capital := 0;
   g_ctas.mto_apertura := 0;
   g_ctas.cod_autorizacion := null;
   g_ctas.cod_usu_autorizador := null;
   g_ctas.SAL_DIS_COMBINADA := 0;
   g_ctas.NRO_CTA_COMBINADA := NULL;
   -- Trae la modalidad y el cliente principal de la cuenta
   Begin
      select G.COD_MODULO, G.COD_MODALIDAD, G.COD_PERSONA, GG.COD_USU_OFICIAL, GG.COD_SEG_CLIENTE
        INTO V_COD_MODULO, V_COD_MODALIDAD, V_COD_PERSONA, V_COD_USU_OFICIAL, V_COD_SEG_CLIENTE
        from GE_CTA_CLIENTES G, GE_CLIENTES GG
       where G.NRO_CUENTA = P_NRO_CUENTA
         and G.COD_PERSONA = GG.COD_PERSONA
         and RELACION = 'P';
   Exception
      When NO_DATA_FOUND Then
         g_msj_error := 'Cuenta Inexistente!!!';
         g_cod_error := 12;
         return;
   End;
   --- Obtiene el estado del Modulo.
   v_est_proceso := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
   if nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN' then
      v_est_proceso := 2; -- debe tomar como normal
   end if;
   ----------------------------------------------------------------
   -- Si es Ahorro a la vista lee el cursor de Ahorro a la Vista --
   ----------------------------------------------------------------
   If V_COD_MODALIDAD in (31,334) then
      if V_EST_PROCESO = 2 Then
         SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                nvl(AUT_PENDIENTE, 'N') AUT_PENDIENTE, nvl(TRA_PROHIBIDA, 'N') TRA_PROHIBIDA, nvl(CTA_COMBINADA, 'N') CTA_COMBINADA,
                V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                FEC_APERTURA, nvl(SAL_RET_BATCH, 0) SAL_RET_BATCH,
                nvl(SAL_RETENIDO, 0) SAL_RETENIDO, nvl(SAL_BLO_BATCH, 0) SAL_BLO_BATCH, nvl(SAL_BLOQUEADO, 0)SAL_BLOQUEADO, nvl(SAL_TOT_BATCH, 0) SAL_TOT_BATCH,
                nvl(SAL_TOTAL, 0) SAL_TOTAL, nvl(MTO_DEB_PENDIENTES, 0) MTO_DEB_PENDIENTES, nvl(MTO_CRE_PENDIENTES, 0) MTO_CRE_PENDIENTES, nvl(MTO_CRE_A_CONFIRMAR, 0) MTO_CRE_A_CONFIRMAR,
                nvl(MTO_APERTURA, 0) MTO_APERTURA,
                nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)+nvl(MTO_CRE_A_CONFIRMAR,0) TOTAL,
                nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE,
                nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, COD_TASA, SAL_MINIMO,
                0 VAL_TASA, null FEC_VENCIMIENTO, nvl(RET_PERSONALIZADA, 'N'),
                COD_ENTE, FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, FEC_ULT_CAPITALIZACION, V_COD_SEG_CLIENTE
           INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.CTA_COMBINADA, G_CTAS.COD_USU_OFICIAL,
                G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                G_CTAS.MTO_APERTURA, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                G_CTAS.COD_ENTE, G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION, G_CTAS.COD_SEG_CLIENTE
           FROM AH_CTA_VISTAS
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- agregado para cuenta combinada  ---
         if g_ctas.CTA_COMBINADA = 'S' then
            BEGIN
            g_ctas.NRO_CTA_COMBINADA := PAG_CTA.FU_OBT_CTA_CTE_COMB(G_CTAS.NRO_CUENTA);
            select nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)
              into g_ctas.SAL_DIS_COMBINADA
              from CC_CTA_CORRIENTES
             where NRO_CUENTA = g_ctas.NRO_CTA_COMBINADA;
            EXCEPTION
                WHEN OTHERS THEN
                     g_ctas.NRO_CTA_COMBINADA := '';
                     g_ctas.SAL_DIS_COMBINADA := 0;
            END;
         end if;
         -----
      ElsIf V_EST_PROCESO != 6 Then  -- estado bloqueado
          SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                 COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                 nvl(AUT_PENDIENTE, 'N') AUT_PENDIENTE, nvl(TRA_PROHIBIDA, 'N') TRA_PROHIBIDA, nvl(CTA_COMBINADA, 'N') CTA_COMBINADA,
                 V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                 FEC_APERTURA, nvl(SAL_RET_BATCH, 0) SAL_RET_BATCH,
                 nvl(SAL_RETENIDO, 0) SAL_RETENIDO, nvl(SAL_BLO_BATCH, 0) SAL_BLO_BATCH, nvl(SAL_BLOQUEADO, 0)SAL_BLOQUEADO, nvl(SAL_TOT_BATCH, 0) SAL_TOT_BATCH,
                 nvl(SAL_TOTAL, 0) SAL_TOTAL,
                 nvl(MTO_APERTURA, 0) MTO_APERTURA,
                 nvl(SAL_TOTAL,0) TOTAL,
                 nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0) SAL_DISPONIBLE,
                 nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, COD_TASA, SAL_MINIMO,
                 0 VAL_TASA, null FEC_VENCIMIENTO, nvl(RET_PERSONALIZADA, 'N'),
                 COD_ENTE, FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, FEC_ULT_CAPITALIZACION, V_COD_SEG_CLIENTE
            INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                 G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                 G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.CTA_COMBINADA, G_CTAS.COD_USU_OFICIAL,
                 G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                 G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                 G_CTAS.SAL_TOTAL,
                 G_CTAS.MTO_APERTURA, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                 G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                 G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                 G_CTAS.COD_ENTE, G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION, G_CTAS.COD_SEG_CLIENTE
            FROM AH_CTA_VISTAS
           WHERE NRO_CUENTA = P_NRO_CUENTA;
          -- modifico los datos si el modulo no esta abierto, leyendo los datos del NOC
          SELECT nvl(MTO_DEB_PENDIENTES, 0) MTO_DEB_PENDIENTES, nvl(MTO_CRE_PENDIENTES, 0) MTO_CRE_PENDIENTES, nvl(MTO_CRE_A_CONFIRMAR, 0) MTO_CRE_A_CONFIRMAR,
                 NVL(G_CTAS.SAL_ACTUAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)+nvl(MTO_CRE_A_CONFIRMAR,0) TOTAL,
                 NVL(G_CTAS.SAL_DISPONIBLE,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) DISPONIBLE, nvl(ESTADO, 'A') ESTADO, V_COD_SEG_CLIENTE
           INTO G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE, G_CTAS.ESTADO , G_CTAS.COD_SEG_CLIENTE-- DYDMR-5695
            FROM AH_CTA_VISTAS_NOC
           WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- agregado para cuenta combinada  ---
         if g_ctas.CTA_COMBINADA = 'S' then
            BEGIN
            g_ctas.NRO_CTA_COMBINADA := PAG_CTA.FU_OBT_CTA_CTE_COMB(G_CTAS.NRO_CUENTA);
            select nvl(A.SAL_TOTAL,0)-nvl(A.SAL_RETENIDO,0)-nvl(A.SAL_BLOQUEADO,0)-nvl(C.MTO_DEB_PENDIENTES,0)+nvl(C.MTO_CRE_PENDIENTES,0)
              into g_ctas.SAL_DIS_COMBINADA
              from CC_CTA_CORRIENTES A, CC_CTA_CORRIENTES_NOC C
             where C.NRO_CUENTA = g_ctas.NRO_CTA_COMBINADA
               AND C.NRO_CUENTA = A.NRO_CUENTA;
            EXCEPTION
                WHEN OTHERS THEN
                     g_ctas.NRO_CTA_COMBINADA := '';
                     g_ctas.SAL_DIS_COMBINADA := 0;
            END;
         end if;
         -----
      else  /* estado del modulo incorrecto */
           g_msj_error := 'Estado del Modulo incorrecto';
           g_cod_error := 13;
      end if;
    ----------------------------------------------------------------
    -- Si es Cuenta Corriente lee el cursor de Cuentas Corrientes --
    ----------------------------------------------------------------
    Elsif  V_COD_MODALIDAD = 41 then
      if V_EST_PROCESO = 2 Then
         SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                COD_OFICINA, COD_MONEDA, DENOMINACION, ACU_SOBREGIRO ACUERDO,
                nvl(AUT_PENDIENTE, 'N'), nvl(TRA_PROHIBIDA, 'N'), nvl(CTA_COMBINADA, 'N'),
                V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A'), nvl(ESTADO, 'A'),
                FEC_APERTURA, nvl(SAL_RET_BATCH, 0),
                nvl(SAL_RETENIDO, 0), nvl(SAL_BLO_BATCH, 0), nvl(SAL_BLOQUEADO, 0), nvl(SAL_TOT_BATCH, 0),
                nvl(SAL_TOTAL, 0), nvl(MTO_DEB_PENDIENTES,0), nvl(MTO_CRE_PENDIENTES, 0), nvl(MTO_CRE_A_CONFIRMAR,0), nvl(MTO_APERTURA,0),
                nvl(SAL_TOTAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)+nvl(MTO_CRE_A_CONFIRMAR,0) TOTAL,
                nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0) SAL_DISPONIBLE,
                nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, SAL_MINIMO,
                null VAL_TASA, null FEC_VENCIMIENTO, nvl(RET_PERSONALIZADA, 'N'),
                FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, NULL,
                COD_ENTE, V_COD_SEG_CLIENTE
           INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.CTA_COMBINADA, G_CTAS.COD_USU_OFICIAL,
                G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                G_CTAS.MTO_APERTURA, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                G_CTAS.TAS_PERSONALIZADA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                G_CTAS.COD_ENTE, G_CTAS.COD_SEG_CLIENTE
           FROM CC_CTA_CORRIENTES
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- agregado para cuenta combinada  ---
         if g_ctas.CTA_COMBINADA = 'S' then
            BEGIN
            g_ctas.NRO_CTA_COMBINADA := PAG_CTA.LF_OBT_CTA_AHO_COMB(G_CTAS.NRO_CUENTA);
            select nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)
              into g_ctas.SAL_DIS_COMBINADA
              from AH_CTA_VISTAS
             where NRO_CUENTA = g_ctas.NRO_CTA_COMBINADA;
            EXCEPTION
                WHEN OTHERS THEN
                     g_ctas.NRO_CTA_COMBINADA := '';
                     g_ctas.SAL_DIS_COMBINADA := 0;
            END;
         end if;
         -----

     Elsif  V_EST_PROCESO != 6 Then -- 6-bloqueado para operaciones
         SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                COD_OFICINA, COD_MONEDA, DENOMINACION, ACU_SOBREGIRO ACUERDO,
                nvl(AUT_PENDIENTE, 'N'), nvl(TRA_PROHIBIDA, 'N'), nvl(CTA_COMBINADA, 'N'),
                V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A'), nvl(ESTADO, 'A'),
                FEC_APERTURA, nvl(SAL_RET_BATCH, 0),
                nvl(SAL_RETENIDO, 0), nvl(SAL_BLO_BATCH, 0), nvl(SAL_BLOQUEADO, 0), nvl(SAL_TOT_BATCH, 0),
                nvl(SAL_TOTAL, 0), nvl(MTO_APERTURA, 0),
                nvl(SAL_TOTAL,0) TOTAL,
                nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0) SAL_DISPONIBLE,
                nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, SAL_MINIMO,
                null VAL_TASA, null FEC_VENCIMIENTO, nvl(RET_PERSONALIZADA, 'N'),
                FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, NULL,
                COD_ENTE, V_COD_SEG_CLIENTE
           INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.CTA_COMBINADA, G_CTAS.COD_USU_OFICIAL,
                G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                G_CTAS.SAL_TOTAL,
                G_CTAS.MTO_APERTURA, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                G_CTAS.TAS_PERSONALIZADA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                G_CTAS.COD_ENTE, G_CTAS.COD_SEG_CLIENTE
           FROM CC_CTA_CORRIENTES
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- modifico los datos si el modulo no esta abierto, leyendo los datos del NOC
         SELECT nvl(MTO_DEB_PENDIENTES,0), nvl(MTO_CRE_PENDIENTES, 0), nvl(MTO_CRE_A_CONFIRMAR, 0),
                NVL(G_CTAS.SAL_ACTUAL,0)-nvl(MTO_DEB_PENDIENTES,0)+nvl(MTO_CRE_PENDIENTES,0)+nvl(MTO_CRE_A_CONFIRMAR,0) TOTAL,
                NVL(G_CTAS.SAL_DISPONIBLE,0)-nvl(mto_DEB_PENDIENTES,0)+nvl(mto_CRE_PENDIENTES,0) DISPONIBLE, nvl(ESTADO, 'A') Estado, V_COD_SEG_CLIENTE
           INTO G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES, G_CTAS.MTO_CRE_A_CONFIRMAR,
                G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE, G_CTAS.ESTADO, G_CTAS.COD_SEG_CLIENTE -- DYDMR-5695
           FROM CC_CTA_CORRIENTES_NOC
          WHERE NRO_CUENTA = P_NRO_CUENTA;
         -- agregado para cuenta combinada  ---
         if g_ctas.CTA_COMBINADA = 'S' then
            BEGIN
            g_ctas.NRO_CTA_COMBINADA := PAG_CTA.LF_OBT_CTA_AHO_COMB(G_CTAS.NRO_CUENTA);
            select nvl(A.SAL_TOTAL,0)-nvl(A.SAL_RETENIDO,0)-nvl(A.SAL_BLOQUEADO,0)-nvl(C.MTO_DEB_PENDIENTES,0)+nvl(C.MTO_CRE_PENDIENTES,0)
              into g_ctas.SAL_DIS_COMBINADA
              from AH_CTA_VISTAS A, AH_CTA_VISTAS_NOC C
             where C.NRO_CUENTA = g_ctas.NRO_CTA_COMBINADA
               AND C.NRO_CUENTA = A.NRO_CUENTA;
            EXCEPTION
                WHEN OTHERS THEN
                     g_ctas.NRO_CTA_COMBINADA := '';
                     g_ctas.SAL_DIS_COMBINADA := 0;
            END;
         end if;
         -----
      else  /* estado del modulo incorrecto */
           g_msj_error := 'Estado del Modulo incorrecto';
           g_cod_error := 14;
      end if;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
   Elsif  V_COD_MODALIDAD in (42, 43, 44, 45, 46, 47, 48, 49, 442, 455) then
   -----------------------------------------------------------
   -- Si es Cuenta Bancaria  --
   -----------------------------------------------------------
         SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                nvl(EST_BATCH, 'A'), nvl(ESTADO, 'A'),
                FEC_APERTURA, nvl(SAL_RET_BATCH, 0),
                nvl(SAL_RETENIDO, 0), nvl(SAL_BLO_BATCH, 0), nvl(SAL_BLOQUEADO, 0), nvl(SAL_TOT_BATCH, 0),
                nvl(SAL_TOTAL, 0), nvl(MTO_ACUERDO, 0),
                nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0) SAL_DISPONIBLE,
                SAL_MINIMO,
                null VAL_TASA, null FEC_VENCIMIENTO,
                FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, NULL,
                nvl(MTO_DEB_PENDIENTES,0), NVL(MTO_CRE_PENDIENTES,0), V_COD_SEG_CLIENTE
           INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                G_CTAS.SAL_TOTAL,
                G_CTAS.MTO_APERTURA,  G_CTAS.SAL_DISPONIBLE,
                G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                G_CTAS.FEC_VENCIMIENTO,
                G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES, G_CTAS.COD_SEG_CLIENTE
           FROM CC_CTA_BANCARIAS
          WHERE NRO_CUENTA = P_NRO_CUENTA;
   -----------------------------------------------------------
   -- Si es Ahorro a Plazo Fijo lee el cursor de Plazo Fijo --
   -----------------------------------------------------------
   Elsif  V_COD_MODALIDAD IN (32,37,38) Then
          SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                 COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                 nvl(AUT_PENDIENTE, 'N') AUT_PENDIENTE, nvl(TRA_PROHIBIDA, 'N') TRA_PROHIBIDA,
                 V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                 FEC_APERTURA, nvl(SAL_RET_BATCH, 0) SAL_RET_BATCH,
                 nvl(SAL_RETENIDO, 0) SAL_RETENIDO, nvl(SAL_BLO_BATCH, 0) SAL_BLO_BATCH, nvl(SAL_BLOQUEADO, 0)SAL_BLOQUEADO, nvl(SAL_TOT_BATCH, 0) SAL_TOT_BATCH,
                 nvl(SAL_TOTAL, 0) SAL_TOTAL, 0 MTO_DEB_PENDIENTES,0 MTO_CRE_PENDIENTES,0 MTO_CRE_A_CONFIRMAR,
                 nvl(CAPITAL,0) CAPITAL,
                 nVl(SAL_TOTAL,0) SAL_TOTAL,
                 nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0)-nvl(SAL_BLOQUEADO,0) SAL_DISPONIBLE,
                 nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, COD_TASA, 0 SAL_MINIMO,
                 decode(cod_modalidad, 37, val_tasa, 38, val_tasa, 0) VAL_TASA, FEC_VENCIMIENTO, 'N' RET_PERSONALIZADA, 
                 FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, FEC_ULT_CAPITALIZACION, V_COD_SEG_CLIENTE
            INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                 G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                 G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.COD_USU_OFICIAL,
                 G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                 G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                 G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                 G_CTAS.CAPITAL, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                 G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                 G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                 G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION, G_CTAS.COD_SEG_CLIENTE
            FROM AH_CTA_PLAZOS
           WHERE NRO_CUENTA = P_NRO_CUENTA;
           IF G_CTAS.ESTADO NOT IN ('V','P') AND V_COD_MODALIDAD != 38 THEN
              -- el saldo disponible es solo la diferencia entre saldo disp - capital
              G_CTAS.SAL_DISPONIBLE := g_ctas.sal_disponible - g_ctas.capital;
           END IF;

   -------------------------------------------------------------------
   -- Si es Certificado de Depositos de Ahorro lee el cursor de CDA --
   -------------------------------------------------------------------
   Elsif  V_COD_MODALIDAD in (33, 34,35,36) Then
          SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                 COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                 nvl(AUT_PENDIENTE, 'N') AUT_PENDIENTE, nvl(TRA_PROHIBIDA, 'N') TRA_PROHIBIDA,
                 V_COD_USU_OFICIAL, nvl(EST_BATCH, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                 FEC_APERTURA, nvl(SAL_RET_BATCH, 0) SAL_RET_BATCH,
                 nvl(SAL_RETENIDO, 0) SAL_RETENIDO, nvl(SAL_BLO_BATCH, 0) SAL_BLO_BATCH, nvl(SAL_BLOQUEADO, 0)SAL_BLOQUEADO, nvl(SAL_TOT_BATCH, 0) SAL_TOT_BATCH,
                 nvl(SAL_TOTAL, 0) SAL_TOTAL, 0 MTO_DEB_PENDIENTES,0 MTO_CRE_PENDIENTES,0 MTO_CRE_A_CONFIRMAR,
                 nvl(CAPITAL,0) CAPITAL,
                 nvl(SAL_TOTAL,0) SAL_TOTAL,
                 nvl(SAL_TOTAL,0)-nvl(SAL_RETENIDO,0) SAL_DISPONIBLE,
                 nvl(TAS_PERSONALIZADA, 'N') TAS_PERSONALIZADA, COD_TASA, 0 SAL_MINIMO,
                 0 VAL_TASA, FEC_VENCIMIENTO, 'N' RET_PERSONALIZADA,
                 FEC_CAM_ESTADO, FEC_ULT_MOVIMIENTO, HOR_ULT_MOVIMIENTO, FEC_ULT_CAPITALIZACION,
                 EST_CERTIFICADO, BLOQUEADO, V_COD_SEG_CLIENTE
            INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                 G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                 G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.COD_USU_OFICIAL,
                 G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                 G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                 G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                 G_CTAS.CAPITAL, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                 G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                 G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                 G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                 G_CTAS.EST_CERTIFICADO, G_CTAS.BLOQUEADO, G_CTAS.COD_SEG_CLIENTE
            FROM AH_CTA_CERTIFICADOS
           WHERE NRO_CUENTA = P_NRO_CUENTA;
          IF G_CTAS.ESTADO NOT IN ('V','P') THEN
             -- el saldo disponible es solo la diferencia entre saldo disp - capital
             G_CTAS.SAL_DISPONIBLE := g_ctas.sal_disponible - g_ctas.capital;
          ELSE
             -- cuando el cda esta vencido, se resta el saldo bloqueado al saldo total
             G_CTAS.SAL_DISPONIBLE := g_ctas.sal_disponible - G_CTAS.SAL_BLOQUEADO;
          END IF;
          IF G_CTAS.SAL_DISPONIBLE < 0 then
             G_CTAS.SAL_DISPONIBLE := 0;
          END IF;

   Elsif v_cod_modulo = 5 then
       -- Tarjetas de Credito
          SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                 COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                 'N' AUT_PENDIENTE, 'N' TRA_PROHIBIDA,
                 V_COD_USU_OFICIAL, nvl(ESTADO, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                 FEC_APERTURA, 0 SAL_RET_BATCH,
                 0 SAL_RETENIDO, 0 SAL_BLO_BATCH, 0 SAL_BLOQUEADO,
                 0 SAL_TOT_BATCH,
                 0 SAL_TOTAL, 0 MTO_DEB_PENDIENTES,0 MTO_CRE_PENDIENTES,0 MTO_CRE_A_CONFIRMAR,
                 0 CAPITAL,
                 0 SAL_TOTAL,
                 0 SAL_DISPONIBLE,
                 'N' TAS_PERSONALIZADA, NULL COD_TASA, 0 SAL_MINIMO,
                 0 VAL_TASA, null FEC_VENCIMIENTO, 'N' RET_PERSONALIZADA,
                 NULL FEC_CAM_ESTADO, NULL FEC_ULT_MOVIMIENTO, NULL HOR_ULT_MOVIMIENTO, NULL FEC_ULT_CAPITALIZACION,
                 NULL EST_CERTIFICADO, V_COD_SEG_CLIENTE
            INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                 G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                 G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.COD_USU_OFICIAL,
                 G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                 G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                 G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                 G_CTAS.CAPITAL, G_CTAS.SAL_ACTUAL, G_CTAS.SAL_DISPONIBLE,
                 G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                 G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                 G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                 G_CTAS.EST_CERTIFICADO, G_CTAS.COD_SEG_CLIENTE
            FROM TA_CTA_TARJETAS
           WHERE NRO_CUENTA = P_NRO_CUENTA;
   Elsif v_cod_modulo = 7 then
       -- CUENTAS DE CAMBIOS
          SELECT NRO_CUENTA, V_COD_PERSONA, COD_MODULO, COD_MODALIDAD,
                 COD_OFICINA, COD_MONEDA, DENOMINACION, 'N' ACUERDO,
                 'N' AUT_PENDIENTE, 'N' TRA_PROHIBIDA,
                 V_COD_USU_OFICIAL, nvl(ESTADO, 'A') EST_BATCH, nvl(ESTADO, 'A') ESTADO,
                 FEC_APERTURA, 0 SAL_RET_BATCH,
                 0 SAL_RETENIDO, 0 SAL_BLO_BATCH, 0 SAL_BLOQUEADO,
                 0 SAL_TOT_BATCH,
                 NVL(MTO_LIMITE,0) SAL_TOTAL, 0 MTO_DEB_PENDIENTES,0 MTO_CRE_PENDIENTES,0 MTO_CRE_A_CONFIRMAR,
                 0 CAPITAL,
                 NVL(MTO_LIMITE,0)-NVL(MTO_UTILIZADO,0) SAL_DISPONIBLE,
                 'N' TAS_PERSONALIZADA, NULL COD_TASA, 0 SAL_MINIMO,
                 0 VAL_TASA, null FEC_VENCIMIENTO, 'N' RET_PERSONALIZADA,
                 NULL FEC_CAM_ESTADO, NULL FEC_ULT_MOVIMIENTO, NULL HOR_ULT_MOVIMIENTO, NULL FEC_ULT_CAPITALIZACION,
                 NULL EST_CERTIFICADO, V_COD_SEG_CLIENTE
            INTO G_CTAS.NRO_CUENTA, G_CTAS.COD_CLIENTE, G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,
                 G_CTAS.COD_OFICINA, G_CTAS.COD_MONEDA, G_CTAS.DENOMINACION, G_CTAS.ACUERDO,
                 G_CTAS.AUTORIZADO, G_CTAS.TRA_PROHIBIDA, G_CTAS.COD_USU_OFICIAL,
                 G_CTAS.EST_BATCH, G_CTAS.ESTADO, G_CTAS.FEC_APERTURA, G_CTAS.SAL_RET_BATCH,
                 G_CTAS.SAL_RETENIDO, G_CTAS.SAL_BLO_BATCH, G_CTAS.SAL_BLOQUEADO, G_CTAS.SAL_TOT_BATCH,
                 G_CTAS.SAL_TOTAL, G_CTAS.MTO_DEB_PENDIENTES, G_CTAS.MTO_CRE_PENDIENTES , G_CTAS.MTO_CRE_A_CONFIRMAR ,
                 G_CTAS.CAPITAL, G_CTAS.SAL_DISPONIBLE,
                 G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, G_CTAS.SAL_MINIMO, G_CTAS.VAL_TASA,
                 G_CTAS.FEC_VENCIMIENTO, G_CTAS.RET_PERSONALIZADA,
                 G_CTAS.FEC_CAM_ESTADO, G_CTAS.FEC_ULT_MOVIMIENTO, G_CTAS.HOR_ULT_MOVIMIENTO, G_CTAS.FEC_ULT_CAPITALIZACION,
                 G_CTAS.EST_CERTIFICADO, G_CTAS.COD_SEG_CLIENTE
            FROM LC_CTA_CAMBIOS
           WHERE NRO_CUENTA = P_NRO_CUENTA;
   Else
       g_msj_error := 'Tipo de cuenta no valido';
       g_cod_error := 15;
   End if;
   if g_cod_error = 0 and v_cod_modulo NOT IN (4, 5, 7) then --- Solo si no es cuentas corrientes
      if V_COD_MODALIDAD not in (37, 38) then
      -- Busca el valor de la tasa de interes
      pag_gen.pr_obt_val_tasa(G_CTAS.COD_MODULO, G_CTAS.COD_MODALIDAD,G_CTAS.COD_OFICINA,
                              G_CTAS.NRO_CUENTA, G_CTAS.COD_MONEDA,G_CTAS.MTO_APERTURA, --CAPITAL
                              G_CTAS.TAS_PERSONALIZADA, G_CTAS.COD_TASA, NULL,
                              trunc(sysdate), V_VAL_TASA, V_FEC_VIGENCIA,
                              V_TIP_VALOR, V_TIP_TASA);
      G_CTAS.VAL_TASA := V_VAL_TASA;
       End If;
   END IF;
Exception
   When Others then
      g_msj_error := 'Error en pag_cta.pr_obt_cuenta '||sqlerrm;
      g_cod_error := 16;
End;
/* Actualiza siguiente nro. de cuenta. */
PROCEDURE PR_ACT_SIG_CTA
 (P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
 IS
BEGIN
   update ge_par_dinamicos
   set val_parametro = nvl(val_parametro,0) + 1
   where parametro = 'SIG_NROCTA';
   if sql%notfound then
      raise_application_error(-20012,
      'Siguiente Nro. de Cuenta no pudo ser modificado');
   end if;
END;
/* Realiza el update de saldos en las Tablas de Cuentas */
PROCEDURE PR_ACT_SAL_CTA
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN AH_CTA_VISTAS.COD_MODALIDAD%TYPE
 ,P_TIP_MOVIMIENTO IN GE_TIP_ASIENTOS.TIP_MOVIMIENTO%TYPE
 ,P_FECHA IN AH_CTA_VISTAS.FEC_ULT_MOVIMIENTO%TYPE
 ,P_HORA IN VARCHAR2
 ,P_SAL_TOTAL IN AH_CTA_VISTAS.SAL_TOTAL%TYPE
 ,P_SAL_RETENIDO IN AH_CTA_VISTAS.SAL_RETENIDO%TYPE
 ,P_SAL_BLOQUEADO IN AH_CTA_VISTAS.SAL_BLOQUEADO%TYPE
 ,P_AUT_PENDIENTE IN AH_CTA_VISTAS.AUT_PENDIENTE%TYPE
 ,P_ACT_ULT_MOVIMIENTO IN VARCHAR2 default 'S'
 )
 IS

V_SAL_TOTAL AH_CTA_VISTAS.SAL_TOTAL%TYPE;
V_SAL_BLOQUEADO AH_CTA_VISTAS.SAL_BLOQUEADO%TYPE;
V_SAL_RETENIDO AH_CTA_VISTAS.SAL_RETENIDO%TYPE;

V_MTO_DEB_PENDIENTES AH_CTA_VISTAS.MTO_DEB_PENDIENTES%TYPE;
V_MTO_CRE_PENDIENTES AH_CTA_VISTAS.MTO_CRE_PENDIENTES%TYPE;
V_MTO_CRE_A_CONFIRMAR AH_CTA_VISTAS.MTO_CRE_A_CONFIRMAR%TYPE;
V_MTO_DEB_PEN_ACTUAL AH_CTA_VISTAS.MTO_DEB_PENDIENTES%TYPE;
V_MTO_CRE_PEN_ACTUAL AH_CTA_VISTAS.MTO_CRE_PENDIENTES%TYPE;
BEGIN
   --para evitar el uso de nvl en el query, performance
   if P_SAL_TOTAL is null then
      V_SAL_TOTAL := 0;
   else
      V_SAL_TOTAL := P_SAL_TOTAL;
   end if;
   if P_SAL_BLOQUEADO is null then
      V_SAL_BLOQUEADO := 0;
   else
      V_SAL_BLOQUEADO := P_SAL_BLOQUEADO;
   end if;
   if P_SAL_RETENIDO is null then
      V_SAL_RETENIDO := 0;
   else
      V_SAL_RETENIDO  := P_SAL_RETENIDO;
   end if;
   --
   If nvl(pag_cta.g_horario, 'D') = 'D' or p_cod_modalidad not in (31,41,334) then
      IF P_TIP_MOVIMIENTO = 'D' THEN
         V_SAL_TOTAL     := -V_SAL_TOTAL;
         V_SAL_BLOQUEADO := -V_SAL_BLOQUEADO;
         V_SAL_RETENIDO  := -V_SAL_RETENIDO;
      END IF;
   Else
      -- Si ya es de tarde o el módulo está cerrado
      IF P_TIP_MOVIMIENTO = 'D' THEN
         V_MTO_DEB_PENDIENTES := V_SAL_TOTAL;
         V_SAL_TOTAL          := 0;
      ELSE
         V_MTO_CRE_PENDIENTES  := V_SAL_TOTAL;
         V_MTO_CRE_A_CONFIRMAR := V_SAL_RETENIDO;
         V_SAL_TOTAL           := 0;
         V_SAL_RETENIDO        := 0;
      END IF;
   End if;
   --
   IF P_COD_MODALIDAD in (31,334) THEN
      If nvl(pag_cta.g_horario, 'D') IN ('D', 'T') then
         UPDATE AH_CTA_VISTAS
            SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
                SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
                SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
                MTO_DEB_PENDIENTES = NVL(MTO_DEB_PENDIENTES,0) + NVL(V_MTO_DEB_PENDIENTES,0),
                MTO_CRE_PENDIENTES = NVL(MTO_CRE_PENDIENTES,0) + NVL(V_MTO_CRE_PENDIENTES,0),
                MTO_CRE_A_CONFIRMAR = NVL(MTO_CRE_A_CONFIRMAR,0) + NVL(V_MTO_CRE_A_CONFIRMAR,0),
                FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
                HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
                AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
          WHERE NRO_CUENTA = P_NRO_CUENTA;
      Else
         UPDATE AH_CTA_VISTAS_NOC
            SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
                SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
                SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
                MTO_DEB_PENDIENTES = NVL(MTO_DEB_PENDIENTES,0) + NVL(V_MTO_DEB_PENDIENTES,0),
                MTO_CRE_PENDIENTES = NVL(MTO_CRE_PENDIENTES,0) + NVL(V_MTO_CRE_PENDIENTES,0),
                MTO_CRE_A_CONFIRMAR = NVL(MTO_CRE_A_CONFIRMAR,0) + NVL(V_MTO_CRE_A_CONFIRMAR,0),
                FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
                HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
                AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
          WHERE NRO_CUENTA = P_NRO_CUENTA;
      End if;
   ELSIF P_COD_MODALIDAD IN (32,37,38) THEN
      UPDATE AH_CTA_PLAZOS
         SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
             SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
             SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
             FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                 nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
             HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                 nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
             AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
       WHERE NRO_CUENTA = P_NRO_CUENTA;
   ELSIF P_COD_MODALIDAD in (33,34,35,36) THEN
      UPDATE AH_CTA_CERTIFICADOS
         SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
             SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
             SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
             FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                 nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
             HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                 nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
             AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
       WHERE NRO_CUENTA = P_NRO_CUENTA;
   ELSIF P_COD_MODALIDAD = 41 THEN
      If nvl(pag_cta.g_horario, 'D') IN ('D', 'T') then
         UPDATE CC_CTA_CORRIENTES
            SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
                SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
                SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
                MTO_DEB_PENDIENTES = NVL(MTO_DEB_PENDIENTES,0) + NVL(V_MTO_DEB_PENDIENTES,0),
                MTO_CRE_PENDIENTES = NVL(MTO_CRE_PENDIENTES,0) + NVL(V_MTO_CRE_PENDIENTES,0),
                MTO_CRE_A_CONFIRMAR = NVL(MTO_CRE_A_CONFIRMAR,0) + NVL(V_MTO_CRE_A_CONFIRMAR,0),
                FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
                HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                    nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
                AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
          WHERE NRO_CUENTA = P_NRO_CUENTA;
      Else
         UPDATE CC_CTA_CORRIENTES_NOC
            SET SAL_TOTAL = nvl(SAL_TOTAL,0) + nvl(V_SAL_TOTAL,0),
                SAL_RETENIDO = nvl(SAL_RETENIDO,0) + nvl(V_SAL_RETENIDO,0),
                SAL_BLOQUEADO = nvl(SAL_BLOQUEADO,0) + nvl(V_SAL_BLOQUEADO,0),
                MTO_DEB_PENDIENTES = NVL(MTO_DEB_PENDIENTES,0) + NVL(V_MTO_DEB_PENDIENTES,0),
                MTO_CRE_PENDIENTES = NVL(MTO_CRE_PENDIENTES,0) + NVL(V_MTO_CRE_PENDIENTES,0),
                MTO_CRE_A_CONFIRMAR = NVL(MTO_CRE_A_CONFIRMAR,0) + NVL(V_MTO_CRE_A_CONFIRMAR,0),
                FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                     nvl(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
                HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                     nvl(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)/*,
                AUT_PENDIENTE = nvl(P_AUT_PENDIENTE,AUT_PENDIENTE)*/
          WHERE NRO_CUENTA = P_NRO_CUENTA;
      end if;
   --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
   ELSIF P_COD_MODALIDAD in (42, 43, 44, 45, 46, 47, 48, 49, 442, 455) THEN
      BEGIN
         SELECT MTO_DEB_PENDIENTES, MTO_CRE_PENDIENTES
           INTO V_MTO_DEB_PEN_ACTUAL, V_MTO_CRE_PEN_ACTUAL
           FROM CC_CTA_BANCARIAS
          WHERE NRO_CUENTA = P_NRO_CUENTA;
      EXCEPTION WHEN OTHERS then
         V_MTO_DEB_PEN_ACTUAL := 0;
         V_MTO_CRE_PEN_ACTUAL := 0;
      END;
      IF V_MTO_DEB_PEN_ACTUAL IS NULL THEN
         V_MTO_DEB_PEN_ACTUAL := 0;
      END IF;
      IF V_MTO_CRE_PEN_ACTUAL IS NULL THEN
         V_MTO_CRE_PEN_ACTUAL := 0;
      END IF;
      UPDATE CC_CTA_BANCARIAS
         SET SAL_TOTAL = SAL_TOTAL + V_SAL_TOTAL,
             SAL_RETENIDO = SAL_RETENIDO + V_SAL_RETENIDO,
             SAL_BLOQUEADO = SAL_BLOQUEADO + V_SAL_BLOQUEADO,
             MTO_DEB_PENDIENTES = V_MTO_DEB_PEN_ACTUAL + V_MTO_DEB_PENDIENTES,
             MTO_CRE_PENDIENTES = V_MTO_CRE_PEN_ACTUAL + V_MTO_CRE_PENDIENTES,
             FEC_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                   coalesce(P_FECHA, FEC_ULT_MOVIMIENTO),FEC_ULT_MOVIMIENTO),
             HOR_ULT_MOVIMIENTO = DECODE(p_act_ult_movimiento,'S',
                   coalesce(P_HORA,HOR_ULT_MOVIMIENTO),HOR_ULT_MOVIMIENTO)
       WHERE NRO_CUENTA = P_NRO_CUENTA;
   ELSE
      RAISE_APPLICATION_ERROR(-20013,'Modalidad de la Cuenta '||P_NRO_CUENTA||' Incorrecta');
   END IF;
   IF sql%notfound THEN
      RAISE_APPLICATION_ERROR(-20014,'Cuenta no registrada');
   else
      --Verificar si el cliente tiene saldo de embargo pendiente de ejecutar
      IF FUG_VER_SAL_EMBARGO(p_nro_cuenta) > 0 then 
         --Sólo si es un credito, afecta al saldo total y ya no tiene autorizacion pendiente
         if p_tip_movimiento = 'C' and v_sal_total > 0 and p_aut_pendiente is null then
            --Generar bloqueo si la cuenta tiene saldo de embargo pendiente
            PRG_INS_BLOQUEO(p_nro_cuenta,v_sal_total,p_cod_modalidad);
         end if;
      END IF; 
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20015,'Act. Saldo Cta '||P_NRO_CUENTA||
                                   ' Modalidad '||P_COD_MODALIDAD||' '||sqlerrm);
END;
/* Actualiza el saldo de los maestros. */
PROCEDURE PR_ACT_SALDOS
 (P_NRO_CUENTA IN VARCHAR2
 ,P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_COD_MODULO IN GE_MOVIMIENTOS.COD_MODULO%TYPE
 ,P_TIP_MOVIMIENTO IN VARCHAR2
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_AFECTA IN VARCHAR2
 ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
 ,P_COTIZACION IN GE_MOVIMIENTOS.COTIZACION%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_MTO_EQU_LOCAL IN GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE DEFAULT NULL
 ,P_ESTADO        IN VARCHAR2 DEFAULT NULL--DEFAULT 'N' -- AJUSTE C.D. Fase II
 )
 IS
R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
v_afe_sal_total     number := 0;
v_afe_sal_retenido  number := 0;
v_afe_sal_bloqueado number := 0;
v_fec_retencion     ah_retenciones.fec_final%type;
v_nro_tarjeta       ta_tarjetas.nro_tarjeta%type;
v_nocturno          varchar2(1) := 'N';
v_redondeo          number(5);
BEGIN
   IF nvl(pag_cta.g_horario, 'D') = 'D' then
      v_nocturno := 'N';
   ELSE
      v_nocturno := 'S';
   END IF;
   G_LUGAR := 'Bloquear Cuenta ';
   IF p_nro_cuenta IS NULL THEN -- Si no hubo cambio de estado no se bloqueo la cuenta
      IF pag_cta.fu_llavear_cuenta(p_cod_modalidad,p_nro_cuenta) = 'N' THEN
         g_cod_error := 19;
         g_msj_error := 'Cuenta Bloqueada ';
         return;
      ELSE
      g_cod_error := 20;
      g_msj_error := '';
      END IF;
   END IF;
   IF g_cod_error = 00 THEN
      G_LUGAR := 'Actualizar_Saldo_Maestro ';
     if p_afecta = 'R' then -- afecta al saldo retenido
        if p_tip_movimiento = 'C' then
           if nvl(g_movs.estado,'N') = 'N' then
              v_afe_sal_total     := p_monto;
              v_afe_sal_retenido  := p_monto;
              v_afe_sal_bloqueado := 0;
           else
              -- si es un credito, no se acredita aun nada
              v_afe_sal_total     := 0;
              v_afe_sal_retenido  := 0;
              v_afe_sal_bloqueado := 0;
           end if;
        elsif p_tip_movimiento = 'D' then
           v_afe_sal_total     := 0;
           v_afe_sal_retenido  := p_monto;
           v_afe_sal_bloqueado := 0;
        end if;
     elsif p_afecta in ('S','C','I') then  -- afecta al saldo total o capital o al cupon de interes
        if nvl(g_movs.estado,'N') = 'N' then
           v_afe_sal_total     := p_monto;
           v_afe_sal_retenido  := 0;
           v_afe_sal_bloqueado := 0;
        else
           -- no es un movimiento normal
           if p_tip_movimiento = 'C' then
              -- si es un credito, no se acredita aun nada
              v_afe_sal_total     := 0;
              v_afe_sal_retenido  := 0;
              v_afe_sal_bloqueado := 0;
           else
              -- es un debito, se bloquea el monto
              v_afe_sal_total     := 0;
              v_afe_sal_retenido  := 0;
              v_afe_sal_bloqueado := p_monto * -1; -- se bloquea el saldo
           end if;
        end if;
        if g_ctas.cod_autorizacion is not null then
           -- hay autorizacion pendiente, se desbloquea el monto
         ---  v_afe_sal_bloqueado := p_monto * -1; Delia
           IF nvl(g_movs.estado,'N') = 'N' then
              v_afe_sal_bloqueado := p_monto ;
           ELSE
              v_afe_sal_bloqueado := 0;
           END IF;
           -- marco como utilizado la autorizacion
           pag_aut.pr_uti_autorizacion(g_ctas.cod_autorizacion,
                                       g_movs.cod_usuario,
                                       g_movs.fecha,
                                       g_movs.hora);

       end if;
     elsif p_afecta = 'B' then -- afecta al saldo bloqueado
        v_afe_sal_total     := 0;
        v_afe_sal_retenido  := 0;
        v_afe_sal_bloqueado := p_monto;
     else
        g_cod_error := 21;
        g_msj_error := 'Esta operacion no afecta al saldo';
        return;
     end if;
    if p_cod_modulo != 5 then
        /* Cuando se genera un Pedido de Autorización - Cheque de Gerencia no debe Actualizar Saldo,
            hasta que se apruebe el Pedido
            -- Se comenta esta condición, cuando se realiza Transferencias entre cuentas Bancarias, debe afectar el saldo, modalidad 43, 45
       if nvl(P_ESTADO,'N') = 'N' or
          (nvl(P_ESTADO,'N') = 'P' and P_COD_MODALIDAD not in ( 43,45))then -- C.D.Fase III */
         pag_cta.pr_act_sal_cta(p_nro_cuenta,
                                 p_cod_modalidad,
                                 p_tip_movimiento,
                                 g_movs.fecha,
                                 g_movs.hora,
                                 v_afe_sal_total,
                                 v_afe_sal_retenido,
                                 v_afe_sal_bloqueado,
                                 G_CTAS.AUTORIZADO,
                                 g_ctas.act_ult_movimiento);


            -- end if;
          end if;
     -- tratamiento especial para cdas.
     if p_cod_modalidad in (33,34,35,36) then
        if p_afecta = 'C' /* capital */ and p_tip_movimiento = 'D'/*debito*/ then
           -- es un pago de capital, se debe afectar el estado del certificado
           declare
             v_int_vencido number(18,2);
           begin
             g_lugar := 'Actualiz. est_certificado';
             SELECT nvl(sum(mto_interes),0)
               INTO v_int_vencido
               FROM AH_CUPONES
              WHERE NRO_CUENTA = p_nro_cuenta
                AND ESTADO = 'V';
             if p_monto >= g_ctas.sal_total - v_int_vencido  then
                -- se esta pagando el total del capital, se act. el est. certif.
                update ah_cta_certificados a
                   set a.est_certificado = 'P',
                       a.fec_pago = g_movs.fecha
                 where nro_cuenta = p_nro_cuenta;
                 r_gmovi.cod_modulo := g_ctas.cod_modulo;
                 r_gmovi.cod_modalidad := g_ctas.cod_modalidad;
                 r_gmovi.cod_oficina := g_ctas.cod_oficina  ;
                 r_gmovi.nro_cuenta :=  g_ctas.nro_cuenta  ;
                 r_gmovi.cod_moneda := g_movs.cod_moneda   ;
                 r_gmovi.cod_usuario := g_movs.cod_usuario;
                 r_gmovi.hora        := g_movs.hora;
                 r_gmovi.fecha       := g_movs.fecha;
                 -- aumento la secuencia
                 g_movs.nro_secuencia := g_movs.nro_secuencia + 1;
                 r_gmovi.nro_secuencia:= g_movs.nro_secuencia;
                 --
                 r_gmovi.fec_valor := g_movs.fec_valor;
                 r_gmovi.cod_tra_padre :=  g_movs.cod_tra_padre;
                 r_gmovi.cod_mod_padre :=  g_movs.cod_mod_padre;
                 r_gmovi.cod_mad_padre :=  g_movs.cod_mad_padre;
                 r_gmovi.cod_transaccion := 403;
                 r_gmovi.monto := null;
                 r_gmovi.nro_documento := p_nro_documento;
                 r_gmovi.cod_tasa := null;
                 r_gmovi.val_tasa := null;
                 r_gmovi.cotizacion := null;
                 r_gmovi.cod_ofi_origen := g_movs.cod_ofi_origen;
                 r_gmovi.emi_aviso := 'N';
                 r_gmovi.concepto :=  'Cambio de Estado';
                 r_gmovi.est_cuenta := 'P';
                 r_gmovi.estado     := g_movs.estado;
                 r_gmovi.reversado  := g_movs.reversado;
                 r_gmovi.nro_caja   := g_movs.nro_caja;
                 r_gmovi.cod_banco  := null;
                 r_gmovi.cod_causa  := null;

                 -- genero el movimiento por cambio de estado
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_nocturno);
             end if;
           end;
        end if;
     end if;
     --
     G_LUGAR         := 'Ins. GE_MOVIMIENTOS por actualizacion saldo ';
     r_gmovi.cod_modulo      := g_ctas.cod_modulo;
     r_gmovi.cod_modalidad   := g_ctas.cod_modalidad;
     r_gmovi.cod_oficina     := g_ctas.cod_oficina  ;
     r_gmovi.nro_cuenta      := g_ctas.nro_cuenta  ;
     r_gmovi.cod_moneda      := g_movs.cod_moneda   ;
     r_gmovi.cod_usuario     := g_movs.cod_usuario;
     r_gmovi.hora            := g_movs.hora;
     r_gmovi.fecha           := g_movs.fecha;
     -- Aumento la secuencia
     g_movs.nro_secuencia    := g_movs.nro_secuencia + 1;
     r_gmovi.nro_secuencia   := g_movs.nro_secuencia;
     --
     r_gmovi.fec_valor       := g_movs.fec_valor;
     r_gmovi.cod_tra_padre   := g_movs.cod_tra_padre;
     r_gmovi.cod_mod_padre   := g_movs.cod_mod_padre;
     r_gmovi.cod_mad_padre   := g_movs.cod_mad_padre;
     r_gmovi.cod_transaccion := g_movs.cod_transaccion;
     r_gmovi.monto           := p_monto;
     r_gmovi.nro_documento   := p_nro_documento;
     r_gmovi.nro_documento2  := g_movs.nro_documento2;
     r_gmovi.nro_documento3  := g_movs.nro_documento3;
     r_gmovi.referencia      := g_movs.referencia;
     r_gmovi.cod_tasa        := g_movs.cod_tasa;
     r_gmovi.val_tasa        := g_movs.val_tasa;
     if g_movs.cod_moneda <> g_cod_mon_local then
       r_gmovi.cotizacion      := p_cotizacion;
       IF p_cotizacion IS NOT NULL THEN
            if p_mto_equ_local is null then
               v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',g_ctas.cod_modulo,g_ctas.cod_modalidad,g_cod_mon_local);
               r_gmovi.mto_equ_local := round(nvl(r_gmovi.monto,0) * nvl(p_cotizacion,0),v_redondeo);
            else
               r_gmovi.mto_equ_local := p_mto_equ_local;
            end if;
       ELSE
            r_gmovi.mto_equ_local := null;
       END IF;
     else
       r_gmovi.cotizacion := null;
       r_gmovi.mto_equ_local := null;
     end if;
     r_gmovi.cod_ofi_origen  := g_movs.cod_ofi_origen;
     r_gmovi.emi_aviso       := g_movs.emi_aviso;
     r_gmovi.concepto        := p_concepto;
     r_gmovi.estado          := nvl(P_ESTADO,g_movs.estado); --g_movs.estado;--- C.D Fase II
     r_gmovi.reversado       := g_movs.reversado;
     r_gmovi.nro_caja        := g_movs.nro_caja;

     r_gmovi.cod_banco       := g_movs.cod_banco;
     r_gmovi.cod_causa       := g_movs.cod_causa;

     r_gmovi.cod_rubro       := g_movs.cod_rubro;
     r_gmovi.tip_mov_rubro   := g_movs.tip_mov_rubro;
     if g_ctas.cod_autorizacion is not null then
        -- tiene autorizacion
        r_gmovi.cod_autorizacion := g_ctas.cod_autorizacion;
        r_gmovi.cod_usu_autorizador := g_ctas.cod_usu_autorizador;
     end if;
     if p_afecta = 'R' and p_tip_movimiento = 'C' then -- es un credito retenido
        -- grabar registro de retencion
        PR_OBT_RETENCION (r_gmovi.fecha,
                          r_gmovi.nro_cuenta,
                          r_gmovi.cod_modulo,
                          r_gmovi.cod_modalidad,
                          r_gmovi.cod_transaccion,
                          r_gmovi.cod_moneda,
                          r_gmovi.cod_retencion,
                          r_gmovi.fec_fin_retencion);
     end if;
     if p_tip_movimiento = 'C' and p_cod_modalidad in (33,34,35,36) then
        --- Verifico si la cuenta ya no posee una retencion
        begin
           select max(ret.fec_final)
           into v_fec_retencion
           from ah_retenciones ret
           where ret.nro_cuenta = r_gmovi.nro_cuenta
           and ret.liberado = 'N';
        exception
           when no_data_found then v_fec_retencion := null;
        end;
        --- Cuando es un credito verifico la fecha de apertura de la cuenta
        if nvl(r_gmovi.fec_fin_retencion,nvl(v_fec_retencion,g_movs.fec_valor)) <> g_ctas.fec_apertura then
           if nvl(g_ctas.sal_total,0) + p_monto = g_ctas.capital and fug_obt_tip_implementacion != 3 then
              raise_application_error(-20021,
              'Fecha apertura no coincide con deposito o liberacion de retencion');
           end if;
           if v_fec_retencion is not null
           and v_fec_retencion > g_ctas.fec_apertura then
              raise_application_error(-20022,
              'La cuenta posee retencion posterior a fecha de apertura');
           end if;
           if r_gmovi.fec_fin_retencion is not null
           and r_gmovi.fec_fin_retencion > g_ctas.fec_apertura then
              raise_application_error(-20023,
              'Liberacion de retencion no puede ser posterior a fecha de apertura de la cuenta');
           end if;
        end if;
     end if;
     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_nocturno);
     -- inserto la novedad de la cuentas
     pr_gen_nov_cuenta(g_movs.fecha, g_movs.hora);
   END IF;
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20016,SQLERRM||G_LUGAR);
END;
/* Actualiza Cuentas */
PROCEDURE PR_ACT_ESTADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_ESTADO IN GE_CUENTAS.ESTADO%TYPE
 ,P_FEC_PROCESO IN DATE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
 ,P_PROCESAR IN VARCHAR2 DEFAULT NULL
 )
 IS

R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
V_ESTADO GE_EST_CUENTAS.ESTADO%TYPE;
V_LLAMADO VARCHAR2(1) := 'N';
V_TRA_CAM_ESTADO NUMBER(3);
v_nocturno          varchar2(1) := 'N';
BEGIN
   IF nvl(pag_cta.g_horario, 'D') = 'D' then
      v_nocturno := 'N';
   ELSE
      v_nocturno := 'S';
   END IF;

  g_ctas.nvo_estado  := p_estado;
  --
   If P_PROCESAR is not null then
     g_ok_procesar := p_procesar;
   End if;
   IF p_estado = 'N' THEN
      v_tra_cam_estado:= 425; -- Pasar a (N)ormal
   ELSIF p_estado = 'P' THEN
      v_tra_cam_estado:= 405; -- Pasar a (P)endiente de Cancelacion
   ELSIF p_estado = 'C' THEN
      v_tra_cam_estado:= 406; -- Pasar a (C)ancelado
   ELSIF p_estado = 'I' then
      v_tra_cam_estado:= 420; -- Pasar a (I)nactivo
   ELSIF p_estado = 'T' THEN
      v_tra_cam_estado:= 424; -- Pasar a CDA totamente Pagada
   ELSIF p_estado = 'V' then
      v_tra_cam_estado:= 422; -- Pasar a CDA a Vencido
   ELSIF p_estado = 'S' then
      v_tra_cam_estado:= 409; -- Pasa a (S) Bloqueo de Saldo
   END IF;
   --- Agregado cuando la transaccion viene por cambio de verificacion
   IF p_estado in ('A','X') then
      v_tra_cam_estado := 401;
   END IF;
   IF g_movs.cod_usuario is null then
      -- inicializo porque no se cargaron los datos
      g_movs.cod_usuario := UPPER(user);
      g_movs.nro_secuencia := 1;
      g_movs.COD_TRA_PADRE := v_tra_cam_estado;

   END IF;
  /* Si la cuenta cambio o es la primera vez que se llama */
   IF  nvl(p_nro_cuenta,' ') <> nvl(g_ctas.nro_cuenta,' ') THEN
      g_lugar := 'Pr_obt_cuenta';
      pag_cta.pr_obt_cuenta(p_nro_cuenta );
      IF g_ok_procesar = 'N' THEN
          pag_cta.g_cod_error := 22; --Hubo error
      ELSE
         pag_cta.g_cod_error := 00; --Sin error
      END IF;
      v_llamado := 'S';
      --
      g_movs.cod_mod_padre := nvl(g_movs.cod_mod_padre,g_ctas.cod_modulo);
      g_movs.cod_mad_padre := nvl(g_movs.cod_mad_padre,g_ctas.cod_modalidad);
      g_movs.cod_ofi_origen := nvl(g_movs.cod_ofi_origen,g_ctas.cod_oficina);
      --
   END IF;
  --
   if pag_cta.g_cod_error = 00 then  -- si no hubo error
      g_lugar := 'Llavea_cuenta';
    if pag_cta.fu_llavear_cuenta(g_ctas.cod_modalidad, p_nro_cuenta) = 'N' then
       pag_cta.g_cod_error := 23;
       pag_cta.g_msj_error := 'Cuenta Llaveada';
    end if;
   end if;
   if pag_cta.g_cod_error = 00 then  -- si no hubo error
      g_lugar := 'Pr_act_estado - Update Estado';
      --Actualiza el estado de las Cuentas
      pr_act_est_cta(p_nro_cuenta,
                    g_ctas.cod_modalidad,
                    p_estado,
                    p_fec_proceso);

      g_lugar := 'Pr_act_est_cta - Insert Ge_movimientos' ;
      r_gmovi.cod_modulo := g_ctas.cod_modulo;
      r_gmovi.cod_modalidad := g_ctas.cod_modalidad;
      r_gmovi.cod_oficina := g_ctas.cod_oficina  ;
      r_gmovi.nro_cuenta :=  g_ctas.nro_cuenta  ;
      r_gmovi.cod_moneda := g_ctas.cod_moneda   ;
      r_gmovi.cod_usuario := g_movs.cod_usuario;
      -- aumento la secuencia
      g_movs.nro_secuencia := g_movs.nro_secuencia + 1;
      r_gmovi.nro_secuencia  := g_movs.nro_secuencia;
      --
      r_gmovi.hora :=  p_hora    ;
      r_gmovi.fecha := p_fec_proceso   ;
      r_gmovi.fec_valor := g_movs.fec_valor;
      r_gmovi.cod_tra_padre :=  g_movs.cod_tra_padre;
      r_gmovi.cod_mod_padre :=  g_movs.cod_mod_padre;
      r_gmovi.cod_mad_padre :=  g_movs.cod_mad_padre;
      r_gmovi.cod_transaccion := v_tra_cam_estado;
      r_gmovi.monto := null;
      r_gmovi.nro_documento := p_nro_documento;
      r_gmovi.cod_tasa := null;
      r_gmovi.val_tasa := null;
      r_gmovi.cotizacion := null;
      r_gmovi.cod_ofi_origen := g_movs.cod_ofi_origen;
      r_gmovi.emi_aviso := 'N';
      r_gmovi.concepto :=  'Cambio de Estado';
      r_gmovi.est_cuenta := p_estado;
      r_gmovi.estado          := g_movs.estado;
      r_gmovi.reversado       := g_movs.reversado;
      r_gmovi.nro_caja        := g_movs.nro_caja;
      r_gmovi.nro_documento2 := g_movs.nro_documento2;
      r_gmovi.nro_documento3 := g_movs.nro_documento3;
      r_gmovi.referencia     := g_movs.referencia;
      -- genero el movimiento por cambio de estado
      pag_gen.pr_ins_ge_movimiento(r_gmovi,v_nocturno);
      -- inserto la novedad de la cuentas
      pr_gen_nov_cuenta(p_fec_proceso, p_hora);
   end if;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20017,SQLERRM||g_lugar);
END;

/*Actualiza el estado de Ah_Titulos a T al pagar el último certificado (ah_cta_certificados )*/
PROCEDURE PR_ACT_EST_TITULO
   (p_nro_cuenta IN ah_cta_certificados.nro_cuenta%TYPE
   ) IS
   v_existe         VARCHAR2(1) := 'S';
   v_serie          ah_titulos.serie%TYPE;
   v_nro_titulo     ah_titulos.nro_titulo%TYPE;
BEGIN
   BEGIN
      SELECT accer.serie, accer.nro_titulo
        INTO v_serie, v_nro_titulo
        FROM ah_cta_certificados accer
       WHERE accer.nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RAISE_APPLICATION_ERROR(-20019,'No existe Certificado para la Cta. Nro.: '||p_nro_cuenta);
   END;

   BEGIN
      --  si no existe ningun certificado con estado diferente a T para el Título actual
      --quiere decir que todos sus certificados estan pagados
      SELECT DISTINCT 'S'
        INTO v_existe
        FROM ah_cta_certificados accer
       WHERE accer.serie = v_serie
         AND accer.nro_titulo = v_nro_titulo
         AND accer.estado <> 'T';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         --si ya se pagó el ultimo certificado actualizar a T (totalmente pagado) el estado del Título.
         UPDATE ah_titulos
            SET estado = 'T'
          WHERE serie = v_serie
            AND nro_titulo = v_nro_titulo;
   END;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20020,'PR_ACT_EST_TITULO : '||p_nro_cuenta||SQLERRM);
END;

/* Actualiza los estados en las tablas de cuentas */
PROCEDURE PR_ACT_EST_CTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_EST_CUENTA IN GE_CUENTAS.ESTADO%TYPE
 ,P_FEC_PROCESO IN DATE
 )
 IS
v_nocturno          varchar2(1) := 'N';
BEGIN
   IF nvl(pag_cta.g_horario, 'D') = 'D' then
      v_nocturno := 'N';
   ELSE
      v_nocturno := 'S';
   END IF;
   --Actualiza Estado en la Tablas de Cuentas
   IF p_cod_modalidad in (31,334) THEN
     IF v_nocturno = 'S' then
       UPDATE AH_CTA_VISTAS_NOC
          SET estado = p_est_cuenta,
              fec_apertura = decode(estado,'A',decode(p_est_cuenta,'N',p_fec_proceso,fec_apertura),fec_apertura),
              fec_cam_estado = p_fec_proceso
        WHERE nro_cuenta = p_nro_cuenta;
     else
       UPDATE AH_CTA_VISTAS
          SET estado = p_est_cuenta,
              fec_apertura = decode(estado,'A',decode(p_est_cuenta,'N',p_fec_proceso,fec_apertura),fec_apertura),
              fec_cam_estado = p_fec_proceso
        WHERE nro_cuenta = p_nro_cuenta;
     end if;
   ELSIF p_cod_modalidad IN (32,37) THEN
    UPDATE AH_CTA_PLAZOS
       SET estado = p_est_cuenta,
           fec_cam_estado = p_fec_proceso
     WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad IN (38) THEN
    UPDATE AH_CTA_PLAZOS
       SET estado = p_est_cuenta,
           fec_apertura = decode(estado,'A',decode(p_est_cuenta,'N',p_fec_proceso,fec_apertura),fec_apertura),
           fec_cam_estado = p_fec_proceso
     WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad IN (33,34,35,36) THEN
     UPDATE AH_CTA_CERTIFICADOS
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso
      WHERE nro_cuenta = p_nro_cuenta;

      --solo los certificados de la modalidad 36 bonos subordinados tienen títulos
      IF p_cod_modalidad = 36 THEN
         pag_cta.pr_act_est_titulo(p_nro_cuenta);
      END IF;
   ELSIF p_cod_modalidad = 41 THEN
     IF v_nocturno = 'S' then
       UPDATE cc_cta_corrientes_noc
          SET estado = p_est_cuenta,
              fec_apertura = decode(estado,'A',decode(p_est_cuenta,'N',p_fec_proceso,fec_apertura),fec_apertura),
              fec_cam_estado = p_fec_proceso
        WHERE nro_cuenta = p_nro_cuenta;
     else
       UPDATE cc_cta_corrientes
          SET estado = p_est_cuenta,
              fec_apertura = decode(estado,'A',decode(p_est_cuenta,'N',p_fec_proceso,fec_apertura),fec_apertura),
              fec_cam_estado = p_fec_proceso
        WHERE nro_cuenta = p_nro_cuenta;
     end if;
   ELSIF p_cod_modalidad in ( 42, 43, 44, 45, 46, 47, 48, 49, 442, 455 ) then
     UPDATE cc_cta_bancarias
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso
      WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad = 81 then
     UPDATE cx_cta_importaciones
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso,
            fec_cancelacion = decode(estado,'C',null, fec_cancelacion),
            cod_cau_cancelacion = decode(estado,'C',null, cod_cau_cancelacion)
      WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad = 82 then
     UPDATE cx_cta_exportaciones
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso,
            fec_cancelacion = decode(estado,'C',null, fec_cancelacion),
            cod_cau_cancelacion = decode(estado,'C',null, cod_cau_cancelacion)
      WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad in (83, 84) then
     UPDATE cx_cta_cobranzas
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso,
            fec_cancelacion = decode(estado,'C',null, fec_cancelacion),
            cod_cau_cancelacion = decode(estado,'C',null, cod_cau_cancelacion)
      WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad in (87, 88, 89) then
     UPDATE cx_fianzas
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso,
            fec_cancelacion = decode(estado,'C',null, fec_cancelacion),
            cod_cau_cancelacion = decode(estado,'C',null, cod_cau_cancelacion)
      WHERE nro_cuenta = p_nro_cuenta;
   ELSIF p_cod_modalidad = 70 then
     UPDATE lc_cta_cambios
        SET estado = p_est_cuenta,
            fec_cam_estado = p_fec_proceso
      WHERE nro_cuenta = p_nro_cuenta;
   ELSE
      RAISE_APPLICATION_ERROR(-20018,'Modalidad de la Cuenta '||p_nro_cuenta||' Incorrecta');
   END IF;
   IF sql%notfound then
      raise_application_error(-20019,'Cuenta no registrada '||p_nro_cuenta);
   END IF;
EXCEPTION
 WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20020,'Act. estado Cta '||p_nro_cuenta||
                                   ' Modalidad '||p_cod_modalidad||' '||SQLERRM);
END;
/* Verifica la operacion de una Cuenta */
PROCEDURE PR_VER_OPERACION
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MOD_PADRE IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MAD_PADRE IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_TIP_MOVIMIENTO IN VARCHAR2
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MONTO IN NUMBER default 0
 ,P_COD_OFI_ORIGEN IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_COD_MODULO IN OUT GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN OUT GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_NVO_ESTADO IN OUT AH_CTA_VISTAS.ESTADO%TYPE
 ,P_SAL_DISPONIBLE IN OUT NUMBER
 ,P_PROCESA IN OUT VARCHAR2
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE default null
 )
 IS

V_COD_OFICINA GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA VARCHAR2(15);
V_CTA_COMBINADA VARCHAR2(15);
V_CONCEPTO GE_MOVIMIENTOS.CONCEPTO%TYPE;
V_COD_MONEDA GE_MOVIMIENTOS.COD_MONEDA%TYPE;
V_TRA_PROHIBIDA VARCHAR2(1) := 'N';
V_MTO_SOBREGIRO NUMBER(18, 2) := 0;
V_CAN_CUPONES   NUMBER(8) := 0;
v_redondeo number := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',g_ctas.cod_modulo,g_ctas.cod_modalidad,P_COD_MONEDA);
v_tot_pendiente ge_movimientos.monto%type := 0;
v_causa          number(8);
v_cod_tra        ge_movimientos.cod_transaccion%type;
v_error number;
v_mensaje varchar2(1000);
BEGIN
    pre_cam_for_numerico('.,');
    -- Inicializo las variables ---
    v_sob_autorizado := 'N';
    p_procesa        := 'N'; -- por defecto no procesa
    p_nvo_estado     := NULL;
    g_cod_error      := 00;
    g_msj_error      := NULL;
    v_mto_sobregiro  := 0;
    p_sal_disponible := 0;
    v_nro_cuenta     := p_nro_cuenta;
    g_ctas.sal_dis_combinada := 0;
    -- Datos generales de la operacion
    g_movs.cod_ofi_origen := p_cod_ofi_origen;
    g_movs.cod_mod_padre  := p_cod_mod_padre;
    g_movs.cod_mad_padre  := p_cod_mad_padre;
    g_movs.cod_tra_padre  := p_cod_tra_padre;
    -- Busco los datos de la cuenta
    g_lugar := 'Buscar_Cuenta';
    PAG_CTA.PR_OBT_CUENTA(V_NRO_CUENTA);
    --
    p_cod_modulo    := g_ctas.cod_modulo;
    p_cod_modalidad := g_ctas.cod_modalidad;
    v_cod_oficina   := g_ctas.cod_oficina;
    v_cod_moneda    := p_cod_moneda;
    --
    g_lugar := 'Verifica_Transaccion_Prohibida';
    IF g_cod_error = 00 AND g_ctas.tra_prohibida = 'S' THEN
       v_tra_prohibida := FU_VER_TRA_PROHIBIDA(p_nro_cuenta,
                                               p_cod_tra_padre,
                                               p_cod_mod_padre,
                                               p_cod_mad_padre);
    END IF;
    -- verifica a que saldo afectara el monto recibido
    g_movs.afecta := null;
    if p_cod_transaccion is not null then
       g_lugar := 'Ver tipo de afectacion';
       g_movs.afecta          := fu_ver_tip_afecta(p_cod_transaccion,
                                                   g_ctas.cod_modulo,
                                                   g_ctas.cod_modalidad);
    end if;
    --si no recibe monto o es negativo, rechazar
    IF p_monto < 0 then
        p_procesa:= 'N';
        g_msj_error := 'Monto de la op. no puede ser negativo';
        g_cod_error  := 88;
    ELSIF v_cod_moneda <> g_ctas.cod_moneda THEN
        p_procesa:= 'N';
        g_msj_error := 'Moneda de la op. '||v_cod_moneda||' dif. a la de la cuenta '||g_ctas.cod_moneda;
        g_cod_error  := 43;
    ELSIF p_monto <> round(p_monto,v_redondeo) then
        p_procesa:= 'N';
        g_msj_error := 'Decimales no permitidos para esta moneda';
        g_cod_error  := 44;
    --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
    ELSIF g_ctas.cod_modalidad not in (31, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 442, 455, 334) and g_ctas.cod_modulo != 5 THEN
        p_procesa:= 'N';
        g_msj_error := 'Tipo de Cuenta no habilitado';
        g_cod_error  := 43;
    ELSE
    --
        IF g_cod_error = 00 THEN
            -- Verifico si actualizara la fecha y hora del ultimo mov de la cta.
            g_lugar := 'obtener si act. hora y fecha ult.mov. Tra : '||p_cod_tra_padre||' Mod : '||p_cod_mod_padre||' Mad : '||p_cod_mad_padre;
            g_ctas.act_ult_movimiento := fu_ver_act_ult_movim(p_cod_tra_padre);
            --
            g_lugar := 'Obtener_nombre_estado';
            v_concepto := PAG_CTA.fu_obt_nom_estado(p_cod_modulo,p_cod_modalidad,g_ctas.estado);
            g_lugar := 'Condiciones generales ';
            if p_cod_modalidad = 43 or p_cod_modulo = 5 then
               p_procesa := 'S';
            end if;
           --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
           IF p_cod_modalidad IN (31, 41, 42, 43, 44, 45, 46, 47, 48, 49, 442, 455, 334) THEN  --Ahorro Vista(31) y Cta.Corriente(41 y 42)
                IF p_tip_movimiento = 'D' THEN -- Debito o extraccion de Dinero de la cta.
                    IF g_ctas.estado IN ('A','C','T','D') THEN
                    -- No se podra extraer si la cta esta en :
                    -- (A)bierta, (C)ancelada, Bloqueo (T)otal y Bloqueo por (D)ebito
                        p_procesa := 'N';
                        g_msj_error := 'No se puede DEBITAR a cuenta con estado '
                                ||v_concepto;
                        g_cod_error := 24;
                    ELSIF nvl(g_movs.afecta,'x') = 'B' THEN -- afecta al saldo bloqueado
                    -- bloqueo de saldo, se quiere desbloquear
                        IF g_ctas.sal_bloqueado >= p_monto THEN
                           p_procesa := 'S'; -- se puede
                        ELSE
                           p_procesa := 'N';
                           g_msj_error := 'Saldo bloqueado de la Cta. menor al monto a desbloquear';
                           g_cod_error := 24;
                        END IF;
                    ELSIF g_ctas.estado IN ('I','S','N','P') THEN
                    -- Se podra extraer si la cta esta en :
                    -- (P)endiente de Cancelacion, Bloqueo de (S)aldo, (N)ormal, (I)nactiva
                        IF g_ctas.estado = 'I' and g_ctas.act_ult_movimiento = 'S' THEN
                            p_nvo_estado := 'N'; -- (N)ormal
                        END IF;
                        /*If g_ctas.nro_cuenta = '589' then
                          raise_application_error(-20000,'parar '||' 1 '||g_ctas.sal_disponible||' 2 '||p_monto||' 3 '||g_ctas.sal_total||' 4 '||G_CTAS.SAL_BLOQUEADO);
                        End if;*/
                        p_sal_disponible := g_ctas.sal_disponible;
                        IF g_ctas.estado = 'P' and p_cod_tra_padre not in (305,113,309) then
                            /* solo se permite extracciones por cheque gerencia, transferencia a una cuenta cerrada */
                            p_procesa := 'N';
                            g_msj_error := 'No se puede DEBITAR a cuenta '||v_concepto||'. Sólo puede extraer por Cheque Gerencia';
                            g_cod_error := 24;
                        ELSIF g_ctas.estado = 'P' then
                            IF g_ctas.sal_total  - p_monto = 0 and g_ctas.sal_disponible - p_monto >= 0 and g_ctas.sal_bloqueado = 0 and g_ctas.sal_retenido = 0 THEN
                                p_nvo_estado  := 'C'; -- (C)ancelada
                                p_procesa := 'S';
                            ELSIF g_ctas.sal_disponible < p_monto then
                                p_procesa := 'N';
                                g_msj_error := 'Cuenta Pendiente de Cancelar con saldo Insuficiente';
                                g_cod_error  := 25;
                            ELSE
                                p_procesa := 'S';
                            END IF;
                        ELSIF g_ctas.sal_total  - p_monto = 0 and g_ctas.sal_disponible - p_monto >= 0 THEN
                            p_procesa:= 'S';
                        ELSIF g_ctas.sal_disponible - p_monto >= 0  THEN
                            p_procesa:= 'S';
                        ELSIF (p_cod_modalidad = 43 AND g_ctas.sal_disponible - p_monto <= 0 AND
                               nvl(fug_obt_pardinamico('CCO_MAD_SOBREGIRO'), 'N') = 'S') THEN
                            p_procesa := 'S';
                        --30/07/2014: BBVANOR-1259 - Operaciones con Financieras del País sin Banco Sponsor
                        ELSIF p_cod_modalidad in (42, 45, 46, 47, 48, 49, 442, 455) then
                            p_procesa := 'S';
                        ELSIF p_cod_modalidad in (41, 42, 43, 44, 46, 47, 48, 49, 442, 455) and (p_cod_tra_padre = 355 or g_sobregira = 'S') then
                            -- no controla el saldo, si es detalle de transacciones
                            p_procesa := 'S';
                            v_sob_autorizado := 'S';
                        ELSIF (p_cod_modulo = 3 and p_cod_tra_padre = 131 and p_cod_transaccion in (505,791) and p_monto <= g_ctas.sal_total and p_monto <= g_ctas.sal_retenido) or
                              (p_cod_modulo = 4 and p_cod_tra_padre = 131 and p_cod_transaccion in (505,791) and p_monto <= g_ctas.sal_retenido) then
                            -- para devolver directamente cheques retenidos por depositos
                            p_procesa := 'S';
                        ELSIF p_cod_modalidad = 41  THEN
                            v_mto_sobregiro := pag_cta.fu_obt_lin_sobregiro(p_nro_cuenta);
                            IF v_mto_sobregiro + p_sal_disponible >= p_monto THEN
                                p_procesa := 'S';
                                v_sob_autorizado := 'S';
                            ELSE
                               -- Verificar si posee autorizacion previa
                               pag_aut.PR_OBT_AUT_PENDIENTE(p_nro_cuenta,
                               p_cod_tra_padre,
                               p_cod_mod_padre,
                               p_cod_mad_padre,
                               p_monto,
                               g_ctas.cod_autorizacion,
                               g_ctas.cod_usu_autorizador);
                               IF g_ctas.cod_autorizacion is not null THEN
                                  p_procesa := 'S'; -- autorizacion
                                  v_sob_autorizado := 'S';
                               ELSE
                                  If p_cod_tra_padre = 132 then
                                     p_procesa := 'S';
                                     v_sob_autorizado := 'S';
                                  Else
                                    p_procesa:= 'N';
                                    g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                    g_cod_error  := 25;
                                    -- agregado por RAMG
                                    if g_ctas.cta_combinada = 'S' then
                                        g_ctas.sal_dis_combinada := nvl(g_ctas.sal_disponible,0);
                                        v_cta_combinada := lf_obt_cta_aho_comb(p_nro_cuenta);
                                        g_cod_error := 0;
                                        IF v_cta_combinada IS NOT NULL  THEN
                                            --
                                            g_lugar := 'Buscar_Cuenta(Comb)';
                                            pag_cta.pr_obt_cuenta(v_cta_combinada);
                                            g_lugar := 'Verifica_Transaccion_Prohibida (Comb)';
                                            IF g_cod_error = 0 THEN
                                                v_tra_prohibida := FU_VER_TRA_PROHIBIDA(p_nro_cuenta,
                                                                                        p_cod_tra_padre,
                                                                                        p_cod_mod_padre,
                                                                                        p_cod_mad_padre);
                                            END IF;
                                            --
                                            g_lugar := 'Obtener_nombre_estado (Comb)';
                                            IF g_cod_error = 0 THEN
                                               v_concepto:= PAG_CTA.fu_obt_nom_estado(g_ctas.cod_modulo,g_ctas.cod_modalidad,g_ctas.estado);
                                            END IF;
                                            IF g_cod_error = 0 THEN
                                                IF p_cod_moneda <> g_ctas.cod_moneda THEN
                                                   p_procesa:= 'N';
                                                   g_msj_error := 'Mon.Cta.Comb. '||v_cta_combinada||' es dif. ';
                                                   g_cod_error  := 26;
                                                ELSIF g_ctas.estado IN ('A','C','T','D') THEN
                                                    -- No se podra extraer si la cta esta en :
                                                    -- (A)bierta, (C)ancelada, Bloqueo (T)otal y Bloqueo por (D)ebito
                                                    p_procesa := 'N';
                                                    g_msj_error := 'No se puede DEBITAR a ctacomb con estado '||v_concepto;
                                                    g_cod_error := 27;
                                                ELSIF g_ctas.estado IN ('I','N','S','P') THEN
                                                    -- Se podra extraer si la cta esta en :
                                                    -- (P)endiente de Cancelacion, Bloqueo de (S)aldo, (N)ormal,
                                                    -- (I)nactiva
                                                    p_sal_disponible := g_ctas.sal_disponible;
                                                    IF g_ctas.sal_disponible - p_monto >= 0 THEN
                                                       p_procesa := 'S';
                                                    ELSIF (g_ctas.sal_disponible + g_ctas.sal_dis_combinada) - p_monto >= 0  then
                                                       p_procesa := 'S';
                                                       p_sal_disponible := g_ctas.sal_disponible;
                                                    ELSE
                                                        p_procesa := 'N';
                                                        g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                                        g_cod_error  := 29;
                                                    END IF;
                                                ELSE
                                                    p_procesa := 'N';
                                                    g_msj_error := 'No se puede DEBITAR por estado incorrecto '||g_ctas.estado;
                                                    g_cod_error  := 30;
                                                END IF;
                                            END IF;
                                            declare
                                              v_cod_error number;
                                              v_msj_error varchar2(4000);
                                            begin
                                              v_cod_error := g_cod_error;
                                              v_msj_error := g_msj_error;
                                              -- fin de control de la cuenta combinada, restauro los datos de la cuenta av
                                              g_lugar := 'Buscar_Cuenta_AV(Comb)';
                                              g_ctas.sal_dis_combinada :=  nvl(g_ctas.sal_disponible,0);
                                              pag_cta.pr_obt_cuenta(p_nro_cuenta);
                                              p_sal_disponible := g_ctas.sal_disponible;
                                              g_cod_error := v_cod_error;
                                              g_msj_error := v_msj_error;
                                            end;
                                        ELSE
                                            p_procesa:= 'N';
                                            g_msj_error := g_lugar;
                                        END IF;
                                    end if;
                                  End if;
                               END IF;
                            END IF;
                        ELSIF p_cod_modalidad in (31,334) AND g_ctas.cta_combinada = 'S' AND nvl(g_ctas.sal_disponible,0) < p_monto THEN
                            --- cuenta conmbinada sin saldo
                            p_procesa := 'N';
                            g_ctas.sal_dis_combinada := nvl(g_ctas.sal_disponible,0);
                            v_cta_combinada := pag_cta.fu_obt_cta_cte_comb(p_nro_cuenta);
                            IF v_cta_combinada IS NOT NULL AND g_cod_error = 00 THEN
                                --
                                g_lugar := 'Buscar_Cuenta(Comb)';
                                pag_cta.pr_obt_cuenta(v_cta_combinada);
                                g_lugar := 'Verifica_Transaccion_Prohibida (Comb)';
                                IF g_cod_error = 00 THEN
                                    v_tra_prohibida := FU_VER_TRA_PROHIBIDA(p_nro_cuenta,
                                                                            p_cod_tra_padre,
                                                                            p_cod_mod_padre,
                                                                            p_cod_mad_padre);
                                END IF;
                                --
                                g_lugar := 'Obtener_nombre_estado (Comb)';
                                IF g_cod_error = 00 THEN
                                   v_concepto:= PAG_CTA.fu_obt_nom_estado(g_ctas.cod_modulo,g_ctas.cod_modalidad,g_ctas.estado);
                                END IF;
                                IF g_cod_error = 00 THEN
                                    IF p_cod_moneda <> g_ctas.cod_moneda THEN
                                       p_procesa:= 'N';
                                       g_msj_error := 'Mon.Cta.Comb. '||v_cta_combinada||' es dif. ';
                                       g_cod_error  := 26;
                                    ELSIF g_ctas.estado IN ('A','C','T','D') THEN
                                        -- No se podra extraer si la cta esta en :
                                        -- (A)bierta, (C)ancelada, Bloqueo (T)otal y Bloqueo por (D)ebito
                                        p_procesa := 'N';
                                        g_msj_error := 'No se puede DEBITAR a ctacomb con estado '||v_concepto;
                                        g_cod_error := 27;
                                    ELSIF g_ctas.estado IN ('I','N','S','P') THEN
                                        -- Se podra extraer si la cta esta en :
                                        -- (P)endiente de Cancelacion, Bloqueo de (S)aldo, (N)ormal,
                                        -- (I)nactiva
                                        p_sal_disponible := g_ctas.sal_disponible;
                                        IF g_ctas.sal_disponible - p_monto >= 0 THEN
                                           p_procesa := 'S';
                                        ELSIF (g_ctas.sal_disponible + g_ctas.sal_dis_combinada) - p_monto >= 0  then
                                           p_procesa := 'S';
                                           p_sal_disponible := g_ctas.sal_disponible;
                                        ELSE
                                            p_procesa := 'N';
                                            g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                            g_cod_error  := 29;
                                        END IF;
                                    ELSE
                                        p_procesa := 'N';
                                        g_msj_error := 'No se puede DEBITAR por estado incorrecto '||g_ctas.estado;
                                        g_cod_error  := 30;
                                    END IF;
                                END IF;
                                declare
                                  v_cod_error number;
                                  v_msj_error varchar2(4000);
                                begin
                                  v_cod_error := g_cod_error;
                                  v_msj_error := g_msj_error;
                                  -- fin de control de la cuenta combinada, restauro los datos de la cuenta av
                                  g_lugar := 'Buscar_Cuenta_CC(Comb)';
                                  g_ctas.sal_dis_combinada :=  nvl(g_ctas.sal_disponible,0);
                                  pag_cta.pr_obt_cuenta(p_nro_cuenta);
                                  p_sal_disponible := g_ctas.sal_disponible;
                                  g_cod_error := v_cod_error;
                                  g_msj_error := v_msj_error;
                                end;
                            ELSE
                                p_procesa:= 'N';
                                g_msj_error := g_lugar;
                            END IF;
                        ELSIF p_cod_modalidad in (31,334) and  g_ctas.sal_total >= p_monto and
                              ((g_ctas.estado <> 'S') or
                               (g_ctas.estado = 'S' and g_ctas.sal_total - g_ctas.sal_bloqueado >= p_monto))then
                             -- Verificar si posee autorizacion previa
                             pag_aut.PR_OBT_AUT_PENDIENTE(p_nro_cuenta,
                             p_cod_tra_padre,
                             p_cod_mod_padre,
                             p_cod_mad_padre,
                             p_monto,
                             g_ctas.cod_autorizacion,
                             g_ctas.cod_usu_autorizador);
                             IF g_ctas.cod_autorizacion is not null THEN
                                p_procesa := 'S'; -- autorizacion
                             ELSIF g_ctas.sal_bloqueado > 0 then
                                p_procesa:= 'N';
                                --g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Bloqueado';
                                g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Bloqueado p/ el debito de '||p_cod_moneda||' '||p_monto;
                                g_cod_error  := 25;
                             ELSE
                                p_procesa:= 'N';
                                g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                g_cod_error  := 25;
                             END IF;
                        ELSE
                          IF P_COD_TRA_PADRE = 321 Then
                               IF g_ctas.sal_total - p_monto >= 0 THEN -- Solo retira Interes
                                  p_procesa := 'S';
                                  p_sal_disponible := g_ctas.sal_disponible;
                               ELSE
                                  p_procesa := 'N';
                                  g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                  g_cod_error  := 31;
                               END IF;
                          ELSE
                            p_procesa:= 'N';
                            g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                            g_cod_error  := 31;
                          END IF;
                        END IF;
                    ELSE
                        p_procesa := 'N';
                        g_msj_error := 'No se puede DEBITAR por estado incorrecto '||g_ctas.estado;
                        g_cod_error  := 32;
                    END IF;
                ELSIF p_tip_movimiento = 'C' THEN -- Acreeditar a la cuenta del Cliente
                    -- No se podra acreditar si la cta esta en :
                    -- (C)ancelada, Bloqueo (T)otal, (P)endiente de Cancelacion
                    IF g_ctas.estado IN ('C','T','P') THEN
                        --si es cta cte,esta pendiente de cancelacion y tiene saldo negativo puede recibir depositos. VC 13/10/2006
                        if p_cod_modalidad = 41 and g_ctas.estado = 'P' and g_ctas.sal_disponible < 0 then
                           IF g_ctas.sal_total + p_monto = 0 and g_ctas.sal_disponible + p_monto = 0 and
                              g_ctas.sal_bloqueado = 0 and g_ctas.sal_retenido = 0 THEN
                              p_nvo_estado  := 'C'; -- (C)ancelada
                           END IF;
                           p_procesa := 'S';
                        else
                           p_procesa := 'N';
                           g_msj_error := 'No se puede ACREDITAR a cuenta con estado '||v_concepto;
                           g_cod_error  := 33;
                        end if;
                    ELSIF g_ctas.estado IN ('A','I','N','S','D') THEN
                        if nvl(g_movs.afecta,'x') = 'B' then
                           -- afecta al saldo bloqueado
                           IF nvl(g_ctas.sal_disponible,0) - nvl(p_monto,0) >= 0 THEN
                              p_procesa:= 'S';
                           else
                          begin
                            --Obtener el codigo de la causa de bloqueo por embargo
                            v_causa := FUG_OBT_PARDINAMICO('COD_CAU_BLO_EMBAR');
                            --Obtener la transaccion para el bloqueo de la causa del embargo
                            begin
                              select val_parametro
                                into v_cod_tra
                                from ge_par_causales
                               where cod_causa = v_causa
                                 and parametro = 'COD_CAU_BLO_TRANSACCION';
                            exception
                              when no_data_found then
                                v_cod_tra := 604;
                            end;
                          exception
                            when others then
                              null;
                          end;
                          if v_cod_tra not in (59,73) then--que la transaccion no sea igual al definido en el ge_par_causales
                            p_procesa := 'S';
                          else
                              g_msj_error := 'Saldo insuficiente para ser bloqueado';
                              g_cod_error  := 33;
                              p_procesa := 'N';
                          end if;
                        END IF;
                     ELSE
                          -- Podra acreditarse en la cta. con estado:
                          -- (A)bierta, (I)nactiva, (N)ormal, Bloqueo (S)aldo, Bloqueo (D)ebito
                          IF g_ctas.estado = 'I' and g_ctas.act_ult_movimiento = 'S' THEN
                             p_nvo_estado := 'N'; -- (N)ormal
                          ELSIF g_ctas.estado = 'A' THEN
                             p_nvo_estado :=  'N'; --(N)ormal
                          END IF;
                          p_procesa := 'S';
                          if /*g_ctas.COD_MODALIDAD = '334'*/ fug_obt_paradicional(p_nro_cuenta, 'LIM_CRE_TRANSACCIONES') is not null  then
                              it.prg_val_cta_baj_riesgo(p_nro_cuenta,
                                 p_cod_moneda,
                                 p_cod_modulo,
                                 p_cod_modalidad,
                                 p_monto,
                                 v_error,
                                 v_mensaje) ;
                             if nvl(v_error,0) != 0 then
                              g_cod_error := 41;
                              g_msj_error:=substr(v_mensaje,1,1000);
                              p_procesa := 'N';
                             end if;  
                          end if;
                       end if;
                    ELSE
                        p_procesa := 'N';
                        g_msj_error := 'Al ACREDITAR por estado incorrecto ('||g_ctas.estado||')
                                      Modal '||TO_CHAR(g_ctas.cod_modalidad);
                        g_cod_error  := 34;
                    END IF;
                ELSE
                    p_procesa := 'N';
                    g_msj_error := 'Tipo Operacion debe ser (D)ebito o (C)redito';
                    g_cod_error := 35;
                END IF;
            ELSIF p_cod_modalidad IN (32,33,34,35,36,37,38) THEN -- Plazo Fijo(32) - CDA(33) y TIF(34) CALL(35) PLZ FIJO DIGITAL() AHO PROG(38)
                IF p_tip_movimiento = 'D' THEN
                    --Debito a la Cuenta del Cliente
                    -- Solo si esta en (V)encido lleva Capital (PF,CDA Y TIF)
                    --                 (N)ormal  lleva INteres (PF)
                    --                 (P)endiente de Cancelacion
                    IF g_ctas.estado IN ('N','V','P') and nvl(g_movs.afecta,'x') <> 'B' THEN
                        IF g_ctas.estado IN ('V','P')    THEN
                               IF g_ctas.sal_disponible - p_monto >= 0 THEN
                                   p_procesa := 'S';
                                   p_sal_disponible := g_ctas.sal_disponible;
                                   IF g_ctas.sal_total - p_monto = 0 THEN
                                      IF p_cod_modalidad IN (33,34,35,36,37,38) THEN
                                         IF g_ctas.fec_vencimiento <= pag_cal.FU_OBT_FEC_ACTUAL(3) then
                                            p_nvo_estado := 'T'; --(T)otalmente Pagada
                                         ELSE
                                            p_nvo_estado := 'C'; --(C)ancelado anticipadamente
                                         END IF;
                                      ELSE
                                         p_nvo_estado := 'C'; --(C)ancelado
                                      END IF;
                                   ELSE  --- Solo para CDA --- Por bloqueo de encajes
                                      IF p_cod_modalidad in (33,34,35,36) THEN
                                         IF g_ctas.sal_disponible - p_monto = 0 THEN
                                            --**si paga el ultimo cupon pero el CDA tiene saldo bloqueado,
                                            --debe quedar en el mismo estado (V)encido la cuenta
                                            if nvl(G_CTAS.SAL_BLOQUEADO,0) = 0 then
                                              p_nvo_estado := 'C'; --(C)ancelado
                                            end if;
                                         END IF;
                                      END IF;
                                   END IF;
                               ELSE
                                   p_procesa := 'N';
                                   g_msj_error := 'Saldo de la Cuenta Insuficiente';
                                   g_cod_error := 36;
                               END IF;
                            --END IF;
                        ELSE
                           IF P_COD_TRA_PADRE = 321 Then
                               IF g_ctas.sal_total - p_monto >= 0 THEN -- Solo retira Interes
                                  p_procesa := 'S';
                                  p_sal_disponible := g_ctas.sal_disponible;
                               ELSE
                                  p_procesa := 'N';
                                  g_msj_error := 'Cuenta '||p_nro_cuenta||' con Saldo Insuficiente p/ el debito de '||p_cod_moneda||' '||p_monto;
                                  g_cod_error  := 31;
                               END IF;
                            ELSE
                              IF g_ctas.sal_disponible - p_monto >= 0  then
                                   If  p_cod_modalidad <> 38  or  ( p_cod_modalidad = 38 and P_COD_TRA_PADRE = 301 ) then -- cancelacion automática de AH. P.(38) o modalidad distinta a la 38
                                     p_procesa := 'S';
                                     p_sal_disponible := g_ctas.sal_disponible;
                                   Else
                                     p_procesa := 'N';
                                     g_msj_error:= 'No corresponde debitar de esta modalidad';
                                     g_cod_error := 37;
                                   End if;
                              ELSE
                                  p_procesa := 'N';
                                  IF p_cod_modalidad IN (32,37,38) THEN
                                      --Si es ejecución de Embargo
                                      IF P_COD_TRA_PADRE = 113 AND g_ctas.sal_total - p_monto > 0  THEN
                                         p_procesa := 'S';
                                      ELSE
                                      g_msj_error:= 'Plazo Fijo sin Interes o Saldo Insuficiente';
                                      g_cod_error := 37;
                                      END IF;
                                  ELSE
                                      g_msj_error:='Certificado sin Interes';
                                      g_cod_error := 38;
                                  END IF;
                              END IF;
                            END IF;
                        END IF;
                    ELSIF nvl(g_movs.afecta,'x') = 'B' THEN -- afecta al saldo bloqueado
                    -- bloqueo de saldo, se quiere desbloquear
                        IF g_ctas.sal_bloqueado >= p_monto THEN
                           p_procesa := 'S'; -- se puede
                        ELSE
                           p_procesa := 'N';
                           g_msj_error := 'Saldo bloqueado de la Cta. menor al monto a desbloquear';
                           g_cod_error := 24;
                        END IF;
                    ELSE
                        p_procesa := 'N';
                        g_msj_error := 'No se puede DEBITAR a una cuenta con estado '||
                        fug_obt_des_est_cta(p_cod_modulo, p_cod_modalidad, g_ctas.estado);
                        g_cod_error  := 39;
                    END IF;
                ELSIF p_tip_movimiento = 'C' THEN -- Credito a la Cuenta
                    IF g_ctas.estado = 'A' THEN
                        begin
                          select nvl(sum(a.monto),0)
                          into v_tot_pendiente
                          from ge_movimientos a
                          where a.nro_cuenta = P_NRO_CUENTA
                          and a.reversado = 'N'
                          and a.estado = 'P';
                        exception
                          when no_data_found then
                          v_tot_pendiente := 0;
                          when others then
                          v_tot_pendiente := 0;
                        end;

                        IF p_cod_modalidad = 38 THEN -- En Ahorro programado el capital va aumentando
                          p_nvo_estado := 'N'; --(N)ormal
                          p_procesa := 'S';
                        ELSE
                          IF ((p_monto <= (g_ctas.capital - g_ctas.sal_total))
                           and ((v_tot_pendiente + p_monto) <= (g_ctas.capital - g_ctas.sal_total))) THEN --se verifica que con los mov pendientes no supere el capital
                              -- Credito a la Cuenta si se encuentra (A)bierta y el Saldo
                              -- Capital - Sltotol debe ser menor igual  al INgresado
                              IF v_tot_pendiente + p_monto = g_ctas.capital - g_ctas.sal_total THEN
                                  -- Pasa a (N)ormal si SLTOTOL = CAPI
                                  p_nvo_estado := 'N'; --(N)ormal
                              END IF;
                              p_procesa := 'S';
                          ELSE
                              p_procesa := 'N';
                              g_msj_error := 'Monto a acreditar supera al Capital';
                              g_cod_error  := 40;
                          END IF;
                        END IF;
                    ELSIF g_ctas.estado = 'N' THEN
                          if nvl(g_movs.afecta,'x') = 'B' then
                             -- afecta al saldo bloqueado
                             IF (g_ctas.sal_total - g_ctas.sal_bloqueado) - p_monto >= 0  THEN
                                --- No se descuenta el capital para poder bloquear el saldo
                                p_procesa:= 'S';
                             else
                                g_msj_error := 'Saldo insuficiente para ser bloqueado';
                                g_cod_error  := 33;
                                p_procesa := 'N';
                             END IF;
                          else
                            IF p_cod_modalidad = 38 THEN -- Ahorro programado afecta saldo
                              if nvl(g_movs.afecta,'x') = 'S' then
                                if p_monto >= 0 then
                                  p_procesa := 'S';
                                else
                                  p_procesa := 'N';
                                  g_msj_error := 'Estado de la cuenta no permite Creditos';
                                  g_cod_error := 41;
                                end if;
                              end if;
                            ELSE
                              p_procesa := 'N';
                              g_msj_error := 'Estado de la cuenta no permite Creditos';
                              g_cod_error := 41;
                            END IF;
                          end if;
                    ELSIF g_ctas.estado = 'V' THEN
                        if nvl(g_movs.afecta,'x') = 'B' then
                           -- afecta al saldo bloqueado
                           IF (g_ctas.sal_total - g_ctas.sal_bloqueado) - p_monto >= 0  THEN
                              --- No se descuenta el capital para poder bloquear el saldo
                              p_procesa:= 'S';
                           else
                              g_msj_error := 'Saldo insuficiente para ser bloqueado';
                              g_cod_error  := 33;
                              p_procesa := 'N';
                           END IF;
                        else
                           p_procesa := 'N';
                           g_msj_error := 'Estado de la cuenta no permite Creditos';
                           g_cod_error := 41;
                        end if;
                    ELSE
                       p_procesa := 'N';
                       g_msj_error := 'Estado de la cuenta no permite Creditos';
                       g_cod_error := 41;
                    END IF;

                ELSE
                    p_procesa := 'N';
                    g_msj_error:= 'Tipo Operacion debe ser (D)ebito o (C)redito';
                    g_cod_error := 42;
                END IF;
            END IF;
        ELSE
            p_procesa := 'N';
        END IF;
    END IF;
EXCEPTION
  WHEN OTHERS THEN
    g_ok_procesar := 'N';
    g_msj_error := SQLERRM||' '||G_LUGAR;
    g_movs.cod_transaccion := null; -- inicializo para no dejar basura
    RAISE_APPLICATION_ERROR(-20021,g_msj_error);
END;
/* Actualiza los datos de las cuentas con movimientos. */
PROCEDURE PR_ACT_OPERACION
 (P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_TIP_MOVIMIENTO IN VARCHAR2
 ,P_COD_MONEDA IN GE_MOVIMIENTOS.COD_MONEDA%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_NRO_DOCUMENTO IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
 ,P_COTIZACION IN GE_MOVIMIENTOS.COTIZACION%TYPE
 ,P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE
 ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
 ,P_COD_TASA IN GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TASA IN GE_MOVIMIENTOS.VAL_TASA%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_EMI_AVISO IN GE_MOVIMIENTOS.EMI_AVISO%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_FEC_VALOR IN GE_MOVIMIENTOS.FEC_VALOR%TYPE
 ,P_COD_BANCO IN NUMBER default Null
 ,P_COD_CAUSA IN NUMBER default Null
 ,P_MTO_EQU_LOCAL IN GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE DEFAULT NULL
 ,P_ESTADO        IN VARCHAR2 DEFAULT NULL--DEFAULT 'N' -- AJUSTE C.D. Fase II
 )
 IS
 v_referencia varchar2(100);
 v_sal_dis_combinada number(18,2);
 v_tipo ge_transacciones.tipo%type;
 v_tot_cre_mes ge_movimientos.monto%type;
 v_exc_transaccion varchar2(1) := 'N';
 v_pri_dia_mes ge_movimientos.fecha%type;
 v_per_cta_basica varchar2(1);
 v_mto_sal_lim_cta_basica number(18,2);
 v_cod_modulo ge_cuentas.cod_modulo%type;
 v_cod_modalidad ge_cuentas.cod_modalidad%type;
BEGIN
    g_ctas.sal_dis_combinada := 0;
    -- Controles de errores: Codigo y mensaje de error
    g_cod_error       := 00;
    g_msj_error       := NULL;
    g_ok_procesar     := 'S';
    v_sob_autorizado  := 'N';
    g_lugar                := 'asignacion de valores a variables ';
    g_ctas.cta_cte_combinada := NULL;
    -- Inicializo los datos de la operacion
    g_movs.cod_usuario     := nvl(g_movs.cod_usuario,user);
    g_movs.nro_secuencia   := p_nro_secuencia;
    g_movs.hora            := p_hora;
    g_movs.fec_valor       := p_fec_valor;
    g_movs.nro_cuenta      := p_nro_cuenta;
    -- Transaccion padre
    g_movs.cod_tra_padre   := p_cod_tra_padre;
    g_movs.cod_mod_padre   := p_cod_mod_padre;
    g_movs.cod_mad_padre   := p_cod_mad_padre;
    -- Transaccion hijo
    g_movs.cod_transaccion := p_cod_transaccion;

    g_movs.concepto        := p_concepto;
    g_movs.tip_movimiento  := p_tip_movimiento;
    g_movs.cod_moneda      := p_cod_moneda;
    g_movs.monto           := p_monto;
    g_movs.nro_documento   := p_nro_documento;
    g_movs.cotizacion      := p_cotizacion;
    g_movs.cod_ofi_origen  := p_cod_ofi_origen;
    g_movs.emi_aviso       := p_emi_aviso;
    g_movs.cod_tasa        := p_cod_tasa;
    g_movs.val_tasa        := p_val_tasa;
    g_movs.cod_banco       := p_cod_banco;
    g_movs.cod_causa       := p_cod_causa;
    g_movs.mto_equ_local   := p_mto_equ_local;

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    --
    g_lugar := 'verifica operacion';
    pag_cta.pr_ver_operacion (p_nro_cuenta,
                              p_cod_tra_padre,
                              p_cod_mod_padre,
                              p_cod_mad_padre,
                              p_tip_movimiento,
                              p_cod_moneda,
                              p_monto,
                              p_cod_ofi_origen,
                              g_ctas.cod_modulo,
                              g_ctas.cod_modalidad,
                              g_ctas.nvo_estado,
                              g_ctas.sal_disponible,
                              g_ok_procesar,
                              g_movs.cod_transaccion);
    IF NVL(g_ok_procesar,'N') = 'S' THEN -- VC- no permitir op. monto 0 01/11/2006
       --verifica el monto, si es cero da error
       if g_cod_error = 00 then
          if p_monto = 0 then
             g_ok_procesar := 'N';
             g_msj_error := 'No puede procesar oper. con Monto Cero. Cta. '||(p_nro_cuenta);
             g_cod_error := 89;
--             RAISE_APPLICATION_ERROR(-20033,g_msj_error);
          end if;
       end if;
    end if;
    IF NVL(g_ok_procesar,'N') = 'S' THEN
       -- verifica a que saldo afectara el monto recibido
       g_lugar := 'Ver tipo de afectacion';
       g_movs.afecta          := fu_ver_tip_afecta(p_cod_transaccion,
                                                   g_ctas.cod_modulo,
                                                   g_ctas.cod_modalidad);
       -- Verifico si actualizara la fecha y hora del ultimo mov de la cta.
       g_lugar := 'obtener si act. hora y fecha ult.mov. Tra : '||p_cod_tra_padre||' Mod : '||p_cod_mod_padre||' Mad : '||p_cod_mad_padre;
       g_ctas.act_ult_movimiento := fu_ver_act_ult_movim(p_cod_tra_padre);
       --
       g_lugar := 'busca fecha del modulo (PAG_CAL.FU_OBT_FEC_ACTUAL(g_ctas.cod_modulo))';
       if (pae_cnf.FU_OBT_EST_MODULO(g_movs.cod_mod_padre) = 2  and  nvl(pag_cta.g_horario, 'D') = 'D') or
          (nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN') then
           g_movs.fecha := PAG_CAL.FU_OBT_FEC_ACTUAL(g_movs.cod_mod_padre);
       else
           pag_cal.pr_obt_dat_calendar(g_movs.cod_mod_padre);
           g_movs.fecha :=  pag_cal.g_fec_proxima;
       end if;
       if g_movs.fec_valor is null then
          g_movs.fec_valor := g_movs.fecha;
       end if;
       --
       g_lugar:= 'buscar_moneda_local';
       g_cod_mon_local:= PAG_GEN.FU_OBT_MON_LOCAL;
       --
       g_lugar := 'buscar cotizacion';
       --IF g_movs.cotizacion IS NULL AND
       --   g_movs.cod_moneda <> g_cod_mon_local THEN
       --g_movs.cotizacion:= pag_gen.fu_obt_cotizacion(g_movs.cod_moneda,g_movs.fecha);
       --END IF;
       -- verifico si es un pago de capital de cda, y si el mismo esta vencido
       if p_tip_movimiento = 'D' then  -- solo para debitos
         if g_ctas.cod_modalidad in (33,34,35,36) then
              if g_movs.afecta = 'C' and g_ctas.est_certificado not in ('V','P') then
               -- se corta el proceso porque afecta al capital y este no esta vencido
               g_ok_procesar := 'N';
               g_msj_error := 'Certificado no esta vencido ni Pend.de Canc.! (campo: est_certificado)';
               RAISE_APPLICATION_ERROR(-20021,g_msj_error);
            elsif g_movs.afecta = 'I' then
               -- veo si el monto corresponde al cupon, y si es asi, lo actualizo como pagado
               declare
                  v_mto_interes number(18,2);
                  v_est_cupon   varchar2(1);
                  v_row_cupon   varchar2(100);
                  v_cup_bloqueado   varchar2(01);
               begin
                 select mto_interes, estado, bloqueado, rowid
                   into v_mto_interes, v_est_cupon, v_cup_bloqueado, v_row_cupon
                   from ah_cupones
                  where nro_cuenta = p_nro_cuenta
                    and nro_cupon  = p_nro_documento;
                 if v_est_cupon <> 'V' then
                    -- no se puede pagar cupon, no esta vencido
                    g_ok_procesar := 'N';
                    g_msj_error := 'Cupon '||to_char(p_nro_documento)||' no esta Vencido!!';
                    RAISE_APPLICATION_ERROR(-20021,g_msj_error);
                 elsif v_cup_bloqueado = 'S' then
                    -- no se puede pagar cupon, CUPON BLOQUEADO
                    g_ok_procesar := 'N';
                    g_msj_error := 'Cupon '||to_char(p_nro_documento)||' esta bloqueado.!!';
                    RAISE_APPLICATION_ERROR(-20021,g_msj_error);
                 elsif nvl(v_mto_interes,0) <> nvl(p_monto,0) then
                    -- no se puede pagar cupon, no corresponde al monto
                    g_ok_procesar := 'N';
                    g_msj_error := 'Monto ingresado no corresponde al Cupon';
                    RAISE_APPLICATION_ERROR(-20021,g_msj_error);
                 else
                    -- corresponde pagar, se actualiza el cupon
                    update ah_cupones
                       set estado = 'P',
                           fec_pago = g_movs.fecha
                     where rowid = v_row_cupon;
                 end if;
               exception
                  when no_data_found then
                      g_ok_procesar := 'N';
                      g_msj_error := 'Nro de Cupon '||to_char(p_nro_documento)||' no existe ';
                      RAISE_APPLICATION_ERROR(-20021,g_msj_error);
                  when others then
                      g_ok_procesar := 'N';
                      g_msj_error := 'Cupon '||to_char(p_nro_documento)||'-'||sqlerrm;
                      RAISE_APPLICATION_ERROR(-20021,g_msj_error);
               end;
            end if;
         end if;
       end if;
       --

       G_LUGAR := 'Actualizar estado Maestro ';
       IF g_ctas.nvo_estado IS NOT NULL AND g_cod_error = 00 THEN
          pag_cta.pr_act_estado(g_ctas.nro_cuenta,
                                g_ctas.nvo_estado,
                                g_movs.fecha,
                                g_movs.hora,
                                g_movs.nro_documento
                                );
       END IF;
       g_ctas.nro_cta_combinada := null;
       if g_ctas.cod_modalidad in (31,41,334) and p_cod_tra_padre = 131 and g_movs.monto <= g_ctas.SAL_RETENIDO then --FQ Req.SPI 2580 Se agrega el signo = a la condición del monto < saldo retenido.
          -- ok, transaccion 131, cheque devuelto no debe controlar
          g_cod_error := 0;
       elsif g_ctas.cod_modalidad in (31,41,334) AND g_cod_error = 00 AND g_movs.tip_movimiento = 'D' AND g_ctas.cta_combinada = 'S' and
          g_ctas.sal_disponible < g_movs.monto THEN
          g_lugar := 'Obtener Cuenta Combinada ';
         if g_movs.afecta = 'B' and  g_ctas.sal_bloqueado >= g_movs.monto then -- afecta al saldo bloqueado
            g_ctas.nro_cta_combinada := null; -- para que se debite el av, xq tiene saldo
         else
           if v_sob_autorizado = 'N' then
               if g_movs.monto > g_ctas.sal_disponible   then
                  if g_ctas.cod_modalidad in (31,334) then
                     g_ctas.nro_cta_combinada := pag_cta.fu_obt_cta_cte_comb(p_nro_cuenta);
                  else
                     g_ctas.nro_cta_combinada := lf_obt_cta_aho_comb(p_nro_cuenta);
                  end if;
               else
                  g_ctas.nro_cta_combinada := null; -- para que se debite el av, xq tiene saldo
               end if;
           end if;
         end if;
       END IF;
       IF g_ctas.nro_cta_combinada IS NOT NULL AND g_cod_error = 0 THEN
          --
          G_LUGAR  := 'TRANSFERENCIA DE SALDO (ctacomb)';
           -- Cambio los valores del movimiento: Credito en la cuenta de AV
          g_movs.concepto := 'Transf.CComb.Nro. '||g_ctas.nro_cta_combinada;
          g_movs.cod_transaccion := 602;
          g_movs.tip_movimiento := 'C';
          -- se procesa como transferencia entre cuentas
          g_movs.cod_mod_padre := 4;
          g_movs.cod_mad_padre := 41;
          g_movs.cod_tra_padre := 309;
          --
          v_sal_dis_combinada := nvl(g_ctas.sal_disponible,0);
          if nvl(v_sal_dis_combinada,0) < 0 then
            v_sal_dis_combinada := 0;
          end if;
          pag_cta.pr_act_saldos(g_ctas.nro_cuenta,
                                g_ctas.cod_modalidad,
                                g_ctas.cod_modulo,
                                g_movs.tip_movimiento,
                                nvl(g_movs.monto,0) - nvl(v_sal_dis_combinada,0),
                                'S', -- afectara al saldo
                                g_movs.nro_documento,
                                g_movs.cotizacion,
                                g_movs.concepto,
                                g_movs.mto_equ_local,
                                p_estado );-- C.D.Fase II

          IF g_cod_error = 0 THEN

               -- Cambio los valores del movimiento: Debito en cuenta de AV.
              g_movs.concepto := p_concepto;
              g_movs.cod_transaccion := p_cod_transaccion;
              g_movs.tip_movimiento := p_tip_movimiento;
              -- se procesa como transferencia entre cuentas
              g_movs.cod_tra_padre   := p_cod_tra_padre;
              g_movs.cod_mod_padre   := p_cod_mod_padre;
              g_movs.cod_mad_padre   := p_cod_mad_padre;

              g_lugar := 'Debito Saldo Maestro AV - Cta.Comb. ';
              pag_cta.pr_act_saldos(g_ctas.nro_cuenta,
                                    g_ctas.cod_modalidad,
                                    g_ctas.cod_modulo,
                                    g_movs.tip_movimiento,  -- debito
                                    g_movs.monto,
                                    g_movs.afecta,    -- afecta al saldo, ret, bloq. etc.
                                    g_movs.nro_documento,
                                    g_movs.cotizacion,
                                    g_movs.concepto,
                                    g_movs.mto_equ_local,
                                    p_estado -- C.D.Fase II
                                     );
          END IF;

          IF g_cod_error = 00 THEN

              G_LUGAR  := 'TRANSFERENCIA DE SALDO (ctacomb)';
              -- se procesa como transferencia entre cuentas
              g_movs.cod_mod_padre := 4;
              g_movs.cod_mad_padre := 41;
              g_movs.cod_tra_padre := 309;

              -- Ahora, armo el debito a la cuenta corriente
              g_movs.concepto       := 'Transf.a la Cta: '||g_ctas.nro_cuenta;
              g_movs.nro_cuenta     := g_ctas.nro_cta_combinada;
              g_movs.tip_movimiento := 'D';
              g_movs.cod_transaccion := 503;
              G_LUGAR  := 'Verif. de la Cta.Cte.Comb. '||g_ctas.nro_cta_combinada;
              pag_cta.pr_ver_operacion (g_movs.nro_cuenta,
                                        p_cod_tra_padre,
                                        p_cod_mod_padre,
                                        p_cod_mad_padre,
                                        g_movs.tip_movimiento,
                                        p_cod_moneda,
                                        nvl(p_monto,0) - nvl(v_sal_dis_combinada,0),
                                        p_cod_ofi_origen,
                                        g_ctas.cod_modulo,
                                        g_ctas.cod_modalidad,
                                        g_ctas.nvo_estado,
                                        g_ctas.sal_disponible,
                                        g_ok_procesar,
                                        g_movs.cod_transaccion);
              IF NVL(g_ok_procesar,'N') = 'S' AND g_cod_error = 00 THEN
                  IF g_ctas.nvo_estado IS NOT NULL  THEN
                    --Actualizo el estado de la cta.cte.combinada
                    pag_cta.pr_act_est_cta(g_ctas.nro_cuenta,
                                           g_ctas.cod_modalidad,
                                           g_ctas.nvo_estado,
                                           g_movs.fecha);
                  END IF;
                  IF g_cod_error = 0 THEN
                    -- se procesa como transferencia entre cuentas
                    g_movs.cod_mod_padre := 4;
                    g_movs.cod_mad_padre := 41;
                    g_movs.cod_tra_padre := 309;
                    -- Actualizo el saldo de la cuenta corriente combinada
                    pag_cta.pr_act_saldos(g_ctas.nro_cuenta,
                                          g_ctas.cod_modalidad,
                                          g_ctas.cod_modulo,
                                          g_movs.tip_movimiento,
                                          nvl(g_movs.monto,0) - nvl(v_sal_dis_combinada,0),
                                          'S', -- afectara al saldo total
                                          g_movs.nro_documento,
                                          g_movs.cotizacion,
                                          g_movs.concepto,
                                          g_movs.mto_equ_local,
                                          p_estado -- C.D.Fase II
                                          );
                    G_LUGAR := 'Actualizar estado Maestro ';
                    IF g_ctas.nvo_estado IS NOT NULL AND g_cod_error = 00 THEN
                        pag_cta.pr_act_estado(g_ctas.nro_cuenta,
                                              g_ctas.nvo_estado,
                                              g_movs.fecha,
                                              g_movs.hora,
                                              g_movs.nro_documento
                                              );
                    END IF;
                  END IF;
              END IF;
          END IF;
       ELSIF g_cod_error = 0 THEN
         if nvl(fug_obt_pardinamico('ACT_VAL_CTA_BASICA'),'N') = 'S' then --ACTIVA VALIDACIONES DE CUENTA BASICA
           -- Verifica si corresponde a una cuenta basica
           v_per_cta_basica := fua_es_cta_basica(g_ctas.nro_cuenta);
           if v_per_cta_basica = 'S' then
              begin
                select cod_modulo, cod_modalidad
                  into v_cod_modulo, v_cod_modalidad
                  from ge_cuentas
                 where nro_cuenta = g_ctas.nro_cuenta;
              exception
                when others then
                  null;
              end;    
              begin
                select 'S'
                    into v_exc_transaccion
                    from ge_gru_transacciones_det t
                   where cod_gru_transaccion = 91
                     and cod_modulo = v_cod_modulo
                     and cod_modalidad = v_cod_modalidad
                     and cod_transaccion = g_movs.cod_tra_padre;
               
              exception
                when others then
                  v_exc_transaccion := 'N';
              end;
              
              if nvl(v_exc_transaccion, 'N') = 'N' then
                begin
                  select 'S'
                    into v_exc_transaccion
                    from ge_gru_transacciones_det t
                   where cod_gru_transaccion = 91
                     and cod_modulo = v_cod_modulo      --cod_modulo
                     and cod_modalidad = v_cod_modalidad   --cod_modalidad
                     and cod_transaccion = g_movs.cod_transaccion;
                exception
                  when others then
                    v_exc_transaccion := 'N';
                end;
              end if;              

              if nvl(v_exc_transaccion, 'N') = 'N' then
                 --Verificar si es un credito--
                 begin
                   select b.tipo
                     into v_tipo
                     from ge_transacciones b
                    where b.cod_modulo = v_cod_modulo
                      and b.cod_modalidad = v_cod_modalidad --cod_modalidad
                      and b.cod_transaccion = g_movs.cod_transaccion;
                 exception
                   when others then
                     v_tipo := 'X';
                 end;
                 if nvl(v_tipo, 'X') = 'C' then
                    --Buscar el saldo de la cuenta--
                    declare
                      v_pri_dia_mes ge_movimientos.fecha%type;
                    begin
                      v_pri_dia_mes := (trunc(pag_cal.FU_OBT_FEC_HABIL(g_movs.fecha, 1, 1), 'mm'));
                      select sum(monto)
                        into v_tot_cre_mes
                        from ge_mov_cre_cta_bas
                       where fecha between v_pri_dia_mes and g_movs.fecha
                         and nro_cuenta = g_ctas.nro_cuenta;
                     exception
                       when others then
                         v_tot_cre_mes := 0;
                     end;

                    --Buscar el limite de la cuenta basica--
                    v_mto_sal_lim_cta_basica := NVL(fug_obt_pardinamico('MTO_MAX_AHO_CTA_BASICA',NULL,NULL,g_movs.COD_MONEDA),0);
                    if ( nvl(v_tot_cre_mes,0) + nvl(g_movs.monto,0)) > nvl(v_mto_sal_lim_cta_basica,0) then
                      g_cod_error := 77;
                      g_msj_error := 'La Cuenta Basica no puede superar Limite de Credito establecido';
                   end if;
                 end if;
              end if;
           end if;
         end if;
         
         /*VALIDACIONES DE CUENTA BAJO RIESGO*/
         if fug_obt_paradicional(g_ctas.nro_cuenta, 'LIM_CRE_TRANSACCIONES') is not null
                                            and user not in ('APICAJERO','JNICORA','OGONZALEZ','RSALAZAR') then
           if NVL(g_movs.tip_movimiento, 'X') = 'C' then
             --control solo si es credito
              begin
                select cod_modulo, cod_modalidad
                  into v_cod_modulo, v_cod_modalidad
                  from ge_cuentas
                 where nro_cuenta = g_ctas.nro_cuenta;
              exception
                when others then
                  null;
              end;
              
              it.prg_val_cta_baj_riesgo(g_ctas.nro_cuenta,
                                        g_movs.cod_moneda,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        g_movs.monto,
                                        g_cod_error,
                                        g_msj_error);

              if nvl(g_cod_error, 0) != 0 then
                 G_COD_ERROR := 41;
                 G_MSJ_ERROR := 'Monto acreditado supera el limite de cuenta de Bajo Riesgo ';
              end if;

           end if;
         end if;
         
         if g_cod_error = 0 then
           -- No es combinada, se actualiza directamente la cuenta

           pag_cta.pr_act_saldos(g_ctas.nro_cuenta,
                                 g_ctas.cod_modalidad,
                                 g_ctas.cod_modulo,
                                 g_movs.tip_movimiento,
                                 g_movs.monto,
                                 g_movs.afecta, -- indica a que saldo afecta
                                 g_movs.nro_documento,
                                 g_movs.cotizacion,
                                 g_movs.concepto,
                                 g_movs.mto_equ_local,
                                 p_estado -- C.D.Fase II
                                 );
          end if;                     
       END IF;
       --
       IF g_cod_error <> 00 THEN
          g_ok_procesar := 'N';
       ELSE
          p_nro_secuencia := g_movs.nro_secuencia;
       END IF;
    ELSE
       g_ok_procesar := 'N';
       if g_cod_error = 0 then
          g_cod_error := 99;
       end if;
    END IF;
    -- inicializo la transaccion hijo para no dejar basura
    g_movs.cod_transaccion := null;
    g_movs.cod_rubro       := null;
    g_movs.tip_mov_rubro   := null;
    g_movs.cod_usuario     := null;

   -- mensaje_error := mensaje_error||' '||wlugar;
EXCEPTION
  WHEN OTHERS THEN

    g_msj_error := 999;
    g_ok_procesar := 'N';
    g_msj_error := SQLERRM||' '||G_LUGAR;
    g_movs.cod_transaccion := null; -- inicializo para no dejar basura
    RAISE_APPLICATION_ERROR(-20021,g_msj_error);
END;
/* Obtiene el Saldo Promedio de una Cuenta */
PROCEDURE PR_OBT_SAL_PROMEDIO
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FEC_INI IN DATE
 ,P_FEC_FIN IN DATE
 ,P_SAL_ACUMULADO IN OUT NUMBER
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 )
 IS
V_FEC_ACTUAL DATE;
V_ANIO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_SAL_ACU_DIARIO AH_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_CAN_DIA_ACUMULADO AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
g_lugar varchar2(250);
---Optimizar el codigo para que obtenga el saldo promedio
---de todas las cuentas cc, ah, pr, ta
---Pedido por Agustin, 16-04-2004
---Ver si se puede utilizar Parametros Diferenciados
CURSOR saldo_promedio IS
   SELECT nvl(sal_acu_diario,0), nvl(can_dia_acumulado,0)
   FROM AH_SAL_MENSUALES
   WHERE nro_cuenta = p_nro_cuenta AND
         ano = v_anio_actual AND
         mes = v_mes_actual
   union
   SELECT nvl(sal_acu_diario,0), nvl(can_dia_acumulado,0)
   FROM CC_SAL_MENSUALES
   WHERE  nro_cuenta = p_nro_cuenta AND
          ano = v_anio_actual AND
          mes = v_mes_actual;
BEGIN
   g_lugar := 'Calcula_saldo_promedio_av';
   p_can_dia_acumulado:= 0;
   p_sal_acumulado := 0;
   p_sal_promedio := 0;
   v_fec_actual  := p_fec_ini;
   v_anio_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'YYYY'));
   v_mes_actual := TO_NUMBER(TO_CHAR(p_fec_ini,'MM'));
   /* La fecha  actual se va incrementando en 1 mes. Mientras que sea menor que la fecha final
      recibida como parametros. Calcula el acumulado de saldo y el saldo promedio */
   WHILE TO_NUMBER(TO_CHAR(v_fec_actual,'YYYYMM')) <= TO_NUMBER(TO_CHAR(p_fec_fin,'YYYYMM')) LOOP
      IF saldo_promedio%ISOPEN THEN
         CLOSE saldo_promedio;
      END IF;
      OPEN saldo_promedio;
         FETCH saldo_promedio
         INTO v_sal_acu_diario, v_can_dia_acumulado;

         g_lugar := 'acumula saldo acumulado y cantidad de dias';
         p_sal_acumulado:= p_sal_acumulado + NVL(v_sal_acu_diario,0);
         p_can_dia_acumulado:= p_can_dia_acumulado + NVL(v_can_dia_acumulado,0);
         v_fec_actual:= ADD_MONTHS(v_fec_actual, 1);
         v_anio_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'YYYY'));
         v_mes_actual := TO_NUMBER(TO_CHAR(v_fec_actual,'MM'));
   END LOOP;
   IF saldo_promedio%ISOPEN THEN
      CLOSE saldo_promedio;
   END IF;
   g_lugar := 'calcula saldo promedio';
   IF NVL(p_can_dia_acumulado,0) > 0 THEN
     p_sal_promedio := p_sal_acumulado / p_can_dia_acumulado;
   END IF;
EXCEPTION
  WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20022,SQLERRM||' -  '||g_lugar);
END;
/* Obtiene los datos de la autorizacion pendiente. */
/* Retorna si la transaccion actualiza o no el ultimo mov. de la cuenta. */
FUNCTION FU_VER_ACT_ULT_MOVIM
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN NUMBER default NULL
 ,P_COD_MODALIDAD IN NUMBER default NULL
 )
 RETURN VARCHAR2
 IS

V_RESULTADO VARCHAR2(1) := 'N';
BEGIN
  SELECT DECODE(INTERNO,'S','N','N','S')
    INTO v_resultado
    FROM GE_TRANSACCIONES
   WHERE cod_modulo = nvl(p_cod_modulo,g_movs.cod_mod_padre)
   and cod_modalidad = nvl(p_cod_modalidad,g_movs.cod_mad_padre)
   and cod_transaccion = p_cod_transaccion;
   RETURN(v_resultado);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    g_cod_error := 21;
    g_msj_error := 'Transaccion  inexistente '||
                    to_char(nvl(p_cod_modulo,g_movs.cod_mod_padre))||'-'||
                    to_char(nvl(p_cod_modalidad,g_movs.cod_mad_padre))||'-'||
                    to_char(p_cod_transaccion);
    RAISE_APPLICATION_ERROR(-20004,g_msj_error);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20003,sqlerrm);
END;
/* Retorna a que saldo afecta la transaccion hijo. */
FUNCTION FU_VER_TIP_AFECTA
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS

V_RESULTADO VARCHAR2(1) := 'N';
BEGIN
  SELECT afecta
    INTO v_resultado
    FROM GE_TRANSACCIONES
   WHERE cod_modulo = nvl(p_cod_modulo,g_ctas.cod_modulo)
     and cod_modalidad = nvl(p_cod_modalidad,g_ctas.cod_modalidad)
     and cod_transaccion = p_cod_transaccion;
   RETURN(v_resultado);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    g_cod_error := 06;
    g_msj_error := 'Transaccion inexistente '||
                    to_char(nvl(p_cod_modulo,g_ctas.cod_modulo))||'-'||
                    to_char(nvl(p_cod_modalidad,g_ctas.cod_modalidad))||'-'||
                    to_char(p_cod_transaccion);
    RAISE_APPLICATION_ERROR(-20004,g_msj_error);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20005,sqlerrm);
END;
/* Obtiene datos de la Retencion. */
PROCEDURE PR_OBT_RETENCION
 (P_FEC_TRANSACCION IN DATE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_RETENCION IN OUT GE_RETENCIONES.COD_RETENCION%TYPE
 ,P_FIN_RETENCION IN OUT DATE
 )
 IS
v_fec_transaccion   date;
v_error varchar2(200) := null;
v_can_dia_retencion number(4) := 0;
Begin

     v_fec_transaccion := p_fec_transaccion;
     If p_cod_transaccion is not null Then
        Begin
           Select COD_RETENCION into p_cod_retencion
             from GE_TRANSACCIONES
            where COD_MODULO = p_cod_modulo
              and COD_MODALIDAD = p_cod_modalidad
              and COD_TRANSACCION = p_cod_transaccion;
        exception
           when no_data_found then
              v_error := 'Transaccion no existe '||to_char(p_cod_transaccion);
           when others then
              v_error := sqlerrm;
        End;
     End If;
     If p_cod_moneda is null Then
        v_error := 'Moneda no definida';
     ElsIf p_cod_retencion is null Then
        v_error := 'Retencion no definida';
     End If;
     if v_error is null then
       -- busco en primer lugar sino tiene retencion personalizada la cuenta
       v_can_dia_retencion := -1; -- inicializo como sin dato
       Begin
          Select can_dia_retencion
            into v_can_dia_retencion
            from GE_RET_CUENTAS
           where NRO_CUENTA = p_nro_cuenta
             and COD_RETENCION = p_cod_retencion;
       Exception
            When NO_DATA_FOUND Then
                 v_can_dia_retencion := -1;
       End;
       If v_can_dia_retencion = -1 Then
         -- no tiene retencion personalizada, busco la retencion general
         Select CAN_DIAS
           into v_can_dia_retencion
           from GE_RET_MONEDAS
          where COD_MONEDA = p_cod_moneda
            and COD_RETENCION = p_cod_retencion;
       End If;
       -- ya se tienen los dias de retencion, debo calcular la fecha
       If p_fec_transaccion is null Then
          v_fec_transaccion := pag_cal.fu_obt_fec_actual(p_cod_modulo);
       end if;
       -- obtiene la fecha habil sgte de la retencion
       p_fin_retencion := pag_cal.fu_obt_fec_fin_ret(v_fec_transaccion,
                                                     nvl(g_movs.cod_ofi_origen,
                                                         g_ctas.cod_oficina),
                                                     v_can_dia_retencion);
     end if;
     -- Verifico sino hubo errores
     if v_error is not null then
        PAG_CTA.G_MSJ_ERROR := v_error;
        PAG_CTA.G_COD_ERROR := 07;
     end if;
     Return;
End;
/* Obtiene la descripcion del estado de una cuenta. */
FUNCTION FU_OBT_NOM_ESTADO
 (P_COD_MODULO IN GE_EST_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_EST_CUENTAS.COD_MODALIDAD%TYPE
 ,P_ESTADO IN GE_EST_CUENTAS.ESTADO%TYPE
 )
 RETURN VARCHAR2
 IS

V_DESCRIPCION GE_EST_CUENTAS.DESCRIPCION%TYPE;
BEGIN
  SELECT DESCRIPCION
    INTO v_descripcion
    FROM GE_EST_CUENTAS
   WHERE COD_MODULO = p_cod_modulo
     AND COD_MODALIDAD = p_cod_modalidad
     AND ESTADO = p_estado;
  RETURN v_descripcion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      g_msj_error := 'Estado Inexistente '||to_char(p_cod_modulo)||' '
                       ||to_char(p_cod_modalidad)||' '||p_estado;
      g_cod_error  := 17;
      return ('ERROR: Estado no identificado');
   WHEN OTHERS THEN
      g_msj_error  := 'ERROR - Cuando buscaba en GE_EST_CUENTAS ';
      g_cod_error := 18;
      return ('ERROR: Estado '||sqlerrm);
END;
/* Obtiene el codigo de error del registro del paquete. */
FUNCTION FU_OBT_COD_ERROR
 RETURN NUMBER
 IS
BEGIN
    return pag_cta.g_cod_error;
END;
/* Obtener el lugar en el que quedo cargado el registro del paquete. */
FUNCTION FU_OBT_LUGAR
 RETURN VARCHAR2
 IS
BEGIN
    return pag_cta.g_lugar;
END;
/* Obtiene el mensaje de error contenido en el registro del paquete. */
FUNCTION FU_OBT_MSJ_ERROR
 RETURN VARCHAR2
 IS
BEGIN
    return pag_cta.g_msj_error;
END;
/* Obtiene el g_ok_procesar del registro del paquete. */
FUNCTION FU_OBT_OK_PROCESAR
 RETURN VARCHAR2
 IS
BEGIN
    return pag_cta.g_ok_procesar;
END;
/* Obtener estado de la cuenta. */
FUNCTION FU_OBT_EST_CUENTA
 RETURN VARCHAR2
 IS
BEGIN
    return G_CTAS.ESTADO;
END;

/* Toma el saldo disponible total (AV+CC) de una cuenta combinada. */
FUNCTION FU_SAL_DIS_COMBINADA
 RETURN number
 IS
BEGIN
    return NVL(G_CTAS.SAL_DISPONIBLE,0) + NVL(g_ctas.sal_dis_combinada,0);
END;
/* Genera el movimiento de novedad de la cuenta */
PROCEDURE PR_GEN_NOV_CUENTA
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 )
 IS
v_est_anterior    varchar2(01) := null;
v_est_actual      varchar2(01) := null;
v_fec_cam_est_ant date         := null;
v_fec_ult_mov_ant date         := null;
v_hor_ult_mov_ant varchar2(8)  := null;
v_insertar        varchar2(1)  := 'N';
BEGIN
   IF (nvl(g_ctas.nvo_estado,g_ctas.estado) <> g_ctas.estado) then
      -- cambiara de estado
      v_est_anterior    := g_ctas.estado;
      v_est_actual      := g_ctas.nvo_estado;
      v_fec_cam_est_ant := g_ctas.fec_cam_estado;
      v_insertar        := 'S';
   end if;
   if nvl(g_ctas.act_ult_movimiento,'N') = 'S' then
      -- cambio de fecha ultimo movimiento
      v_fec_ult_mov_ant := g_ctas.fec_ult_movimiento;
      v_hor_ult_mov_ant := g_ctas.hor_ult_movimiento;
      v_insertar        := 'S';
   end if;
   if v_insertar = 'S' then
     -- Actualizo el registro si ya existe
     update ge_cuentas_nov
        set est_anterior    = nvl(v_est_anterior,est_anterior),
            est_actual      = nvl(v_est_actual,est_actual),
            fec_cam_est_ant = nvl(v_fec_cam_est_ant,fec_cam_est_ant),
            fec_ult_mov_ant = nvl(v_fec_ult_mov_ant,fec_ult_mov_ant),
            hor_ult_mov_ant = nvl(v_hor_ult_mov_ant,hor_ult_mov_ant)
      where cod_usuario = g_movs.cod_usuario
        and fecha       = p_fecha
        and hora        = p_hora
        and nro_cuenta  = g_movs.nro_cuenta;
     if sql%notfound then
        insert into ge_cuentas_nov
           (fecha, hora, cod_usuario,
            nro_cuenta, nro_detalle,
            cod_modulo, cod_modalidad,
            est_anterior, est_actual, fec_cam_est_ant,
            fec_ult_mov_ant, hor_ult_mov_ant, fec_ult_cap_ant )
        values
           (p_fecha, p_hora, g_movs.cod_usuario,
            g_movs.nro_cuenta, null,
            g_ctas.cod_modulo, g_ctas.cod_modalidad,
            v_est_anterior, v_est_actual, v_fec_cam_est_ant,
            v_fec_ult_mov_ant, v_hor_ult_mov_ant, g_ctas.fec_ult_capitalizacion);

     end if;
   end if;
exception
  when others then
     raise_application_error(-20000,'PR_GEN_NOV_CUENTA '||sqlerrm);
END;
/* Obtener tasas de pizarra. */
PROCEDURE PR_OBT_TAS_PIZARRA
  ( p_cod_modulo         IN GE_CUENTAS.COD_MODULO%TYPE
   ,p_cod_modalidad      IN GE_CUENTAS.COD_MODALIDAD%TYPE
   ,p_cod_moneda         IN GE_CUENTAS.COD_MONEDA%TYPE
   ,p_plazo              IN NUMBER
   ,p_monto              IN GE_CUENTAS.SAL_PROMEDIO%TYPE
   ,p_tas_minima         IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
   ,p_tas_maxima         IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
   ,p_tas_interes        IN OUT GE_TAS_FECHAS.VAL_TASA%TYPE
   ,p_tip_capitalizacion IN AH_CTA_VISTAS.TIP_CAPITALIZACION%TYPE
   ,p_cod_sub_modalidad  IN GE_TAS_FECHAS.COD_SUB_MODALIDAD%TYPE default null
  )
  is
    cursor c_tas_pizarras is
           select nvl(tas_minima,0) tas_minima, nvl(tas_maxima,0) tas_maxima, nvl(tas_interes,0) tas_interes
             from cr_piz_montos a, cr_piz_plazos b
            where nvl(b.cod_moneda,        nvl(p_cod_moneda,'x'))         = nvl(p_cod_moneda,'x')
              and nvl(b.cod_modulo,        nvl(p_cod_modulo,-1))          = nvl(p_cod_modulo,-1)
              and nvl(b.cod_modalidad,     nvl(p_cod_modalidad,-1))       = nvl(p_cod_modalidad,-1)
              and nvl(b.cod_sub_modalidad, nvl(p_cod_sub_modalidad,-1))   = nvl(p_cod_sub_modalidad,-1)
              and p_plazo between b.plz_desde and b.plz_hasta
              and p_monto between a.mto_desde and a.mto_hasta
              and nvl(b.tip_capitalizacion, nvl(p_tip_capitalizacion,-1)) = nvl(p_tip_capitalizacion,-1)
              and nvl(a.cod_moneda,        nvl(p_cod_moneda,-1))          = nvl(p_cod_moneda,-1)
              and nvl(a.cod_modulo,        nvl(p_cod_modulo,-1))          = nvl(p_cod_modulo,-1)
              and nvl(a.cod_modalidad,     nvl(p_cod_modalidad,-1))       = nvl(p_cod_modalidad,-1)
              and nvl(a.cod_sub_modalidad, nvl(p_cod_sub_modalidad,-1))   = nvl(p_cod_sub_modalidad,-1)
              and a.mto_desde = b.mto_desde
       order by decode(b.cod_modulo,null,0,1) +
             decode(b.cod_modalidad,null,0,1) +
             decode(b.cod_sub_modalidad,null,0,1) +
             decode(b.cod_moneda,null,0,1) desc;
BEGIN
   p_tas_minima  :=0;
   p_tas_maxima  :=0;
   p_tas_interes :=0;

   if c_tas_pizarras%isopen THEN
      close c_tas_pizarras;
   end if;

   open c_tas_pizarras;
   fetch c_tas_pizarras into p_tas_minima, p_tas_maxima, p_tas_interes;

   if c_tas_pizarras%isopen then
      close c_tas_pizarras;
   end if;

exception
   when others then
      if c_tas_pizarras%isopen then
         close c_tas_pizarras;
      end if;
      raise_application_error(-20000, 'Obt. Tasa Pizarra '||sqlerrm);
end;

/* Asigna el nro de caja */
PROCEDURE PR_NRO_CAJA
    (P_NRO_CAJA IN NUMBER)
 IS
BEGIN
   g_movs.nro_caja := p_nro_caja;
END;
/* Asigna variables para para vencimiento de Certificados */

PROCEDURE PR_SET_VARIABLES
    (p_cod_usuario IN ba_usuarios.cod_usuario%type,
     p_fec_valor in ge_movimientos.fec_valor%type,
     p_cod_tra_padre in ge_movimientos.cod_tra_padre%type,
     p_estado in ge_movimientos.estado%type,
     p_reversado in ge_movimientos.reversado%type,
     p_nro_secuencia  IN OUT number,
     p_est_cuenta in ge_cuentas.estado%type default 'V',
     p_cod_ofi_origen in ge_cuentas.cod_oficina%type default null,
     p_cod_mod_padre  in ge_movimientos.cod_mod_padre%type default null,
     p_cod_mad_padre  in ge_movimientos.cod_mad_padre%type default null)
IS
BEGIN
   pag_cta.g_movs.cod_usuario    := p_cod_usuario;
   pag_cta.g_movs.nro_secuencia  := p_nro_secuencia;
   pag_cta.g_movs.fec_valor      := p_fec_valor;
   pag_cta.g_movs.cod_tra_padre  := p_cod_tra_padre;
   pag_cta.g_movs.estado         := p_estado;
   pag_cta.g_movs.cod_ofi_origen := nvl(p_cod_ofi_origen,pag_cta.g_ctas.cod_oficina);
   pag_cta.g_movs.reversado      := p_reversado;
   pag_cta.g_movs.nro_cuenta     := pag_cta.g_ctas.nro_cuenta;
   g_ctas.nvo_estado             := p_est_cuenta;
   g_ctas.fec_cam_estado         := p_fec_valor;
   pag_cta.g_movs.cod_mod_padre  := nvl(p_cod_mod_padre, pag_cta.g_ctas.cod_modulo);
   pag_cta.g_movs.cod_mad_padre  := nvl(p_cod_mad_padre, pag_cta.g_ctas.cod_modalidad);
END;

PROCEDURE PR_SET_VTO_CERTIFICADO
    (p_cod_usuario IN ba_usuarios.cod_usuario%type,
     p_fec_valor in ge_movimientos.fec_valor%type,
     p_cod_tra_padre in ge_movimientos.cod_tra_padre%type,
     p_estado in ge_movimientos.estado%type,
     p_reversado in ge_movimientos.reversado%type,
     p_nro_secuencia  IN OUT number,
     p_est_cuenta in ge_cuentas.estado%type default 'V')
IS
BEGIN
   pag_cta.g_movs.cod_usuario    := p_cod_usuario;
   pag_cta.g_movs.nro_secuencia  := p_nro_secuencia;
   pag_cta.g_movs.fec_valor      := p_fec_valor;
   pag_cta.g_movs.cod_tra_padre  := p_cod_tra_padre;
   pag_cta.g_movs.estado         := p_estado;
   pag_cta.g_movs.cod_ofi_origen := pag_cta.g_ctas.cod_oficina;
   pag_cta.g_movs.cod_mod_padre  := pag_cta.g_ctas.cod_modulo;
   pag_cta.g_movs.cod_mad_padre  := pag_cta.g_ctas.cod_modalidad;
   pag_cta.g_movs.reversado      := p_reversado;
   pag_cta.g_movs.nro_cuenta     := pag_cta.g_ctas.nro_cuenta;
   g_ctas.nvo_estado             := p_est_cuenta;
   g_ctas.fec_cam_estado         := p_fec_valor;
END;

/* Asigna variables seteo del cod_rubro de g_movs */
PROCEDURE PR_SET_COD_RUBRO
     (p_cod_rubro in ge_movimientos.cod_rubro%type,
      p_tip_mov_rubro in ge_movimientos.tip_mov_rubro%type) IS
BEGIN
   pag_cta.g_movs.cod_rubro     := p_cod_rubro;
   pag_cta.g_movs.tip_mov_rubro := p_tip_mov_rubro;
END;

/* Asigna variables seteo del NRO DOCUMENTO 2 de g_movs */
PROCEDURE PR_SET_NRO_DOCUMENTO2
     (p_nro_documento2 in ge_movimientos.nro_documento2%type) IS
BEGIN
   pag_cta.g_movs.nro_documento2 := p_nro_documento2;
END;

/* Asigna variables seteo del NRO DOCUMENTO 3 de g_movs */
PROCEDURE PR_SET_NRO_DOCUMENTO3
     (p_nro_documento3 in ge_movimientos.nro_documento3%type) IS
BEGIN
   pag_cta.g_movs.nro_documento3 := p_nro_documento3;
END;


/*Actualiza el campo bloqueo de ah_cta_certificados */
PROCEDURE PR_ACT_CTA_BLOQUEO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_BLOQUEADO IN AH_CTA_CERTIFICADOS.BLOQUEADO%TYPE
 )
 IS
BEGIN
   if pag_cta.fu_llavear_cuenta(33, p_nro_cuenta) = 'N' then
      RAISE_APPLICATION_ERROR(-20001,'Cuenta llaveada '||p_nro_cuenta);
  end if;
   --Actualiza el bloqueado de la Cuenta
   update ah_cta_certificados
   set bloqueado = p_bloqueado
  where nro_cuenta = p_nro_cuenta;
   IF sql%notfound then
      raise_application_error(-20002,'Cuenta no registrada '||p_nro_cuenta);
   END IF;
EXCEPTION
 WHEN OTHERS THEN
   if sqlcode <= -20000 then
      raise;
   else
      RAISE_APPLICATION_ERROR(-20010,'Act.Bloq.Cta '||p_nro_cuenta||'-'||SQLERRM);
   end if;
END;
-- devuelve el codigo de la autorizacion previa
procedure pr_obt_autorizacion
 (p_cod_autorizacion    out ge_movimientos.cod_autorizacion%type,
  p_cod_usu_autorizador out ge_movimientos.cod_usu_autorizador%type)
  is
begin

p_cod_autorizacion    := g_ctas.cod_autorizacion;
p_cod_usu_autorizador := g_ctas.cod_usu_autorizador;
end ;
-- seteo el estado del movimiento
PROCEDURE PR_SET_EST_MOVIMIENTO
    (p_est_movimiento in ge_movimientos.estado%type)
IS
BEGIN
   pag_cta.g_movs.estado         := p_est_movimiento;
END;
/* Asigna variables seteo de referencia de g_movs */
PROCEDURE PR_SET_REFERENCIA
     (p_referencia in ge_movimientos.referencia%type) IS
BEGIN
   pag_cta.g_movs.referencia := p_referencia;
END;
END PAG_CTA;
/
