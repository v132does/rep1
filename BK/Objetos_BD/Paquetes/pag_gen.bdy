CREATE OR REPLACE PACKAGE BODY IT.PAG_GEN IS

RG_GMOVI GE_MOVIMIENTOS%ROWTYPE;

/* Convertir un monto de una moneda a otra */
PROCEDURE PR_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_MTO_MON_DESTINO OUT NUMBER
 ,P_COT_MON_ORIGINAL IN OUT NUMBER
 ,P_COT_MON_DESTINO IN OUT NUMBER
 )
 IS
   v_cod_mon_base    ba_monedas.cod_moneda%type;
   v_lugar           varchar2(100);
   v_redondeo        number(5);
BEGIN
    v_lugar := 'obtener moneda base';
    v_cod_mon_base  := pag_gen.fu_obt_mon_local();
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,p_cod_mon_destino);
    if p_cod_mon_original = p_cod_mon_destino  then
        p_mto_mon_destino := P_mto_mon_original;
        if p_cod_mon_original <> v_cod_mon_base then
           if p_cot_mon_original is null and p_cot_mon_destino is not null then
              p_cot_mon_original := p_cot_mon_destino;
           elsif p_cot_mon_original is null then
              p_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original);
           end if;
           p_cot_mon_destino := p_cot_mon_original;
        else
           p_cot_mon_destino := 1;
           p_cot_mon_original := 1;
        end if;
   else
       if  p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base then
           --convertir moneda original a base o destino
           if p_cot_mon_original is null then
              p_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original);
           end if;
           p_cot_mon_destino := 1;
           p_mto_mon_destino := round(p_mto_mon_original * p_cot_mon_original,v_redondeo);
       elsif p_cod_mon_original = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           -- pasar moneda original a moneda base
           p_cot_mon_original := 1;
           if p_cot_mon_destino is null then
              p_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino);
           end if;
           p_mto_mon_destino := ROUND(p_mto_mon_original/p_cot_mon_destino,v_redondeo);
       elsif p_cod_mon_original <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           if p_cot_mon_original is null then
              p_cot_mon_original := fug_obt_cotizacion(p_cod_mon_original);
           end if;
           p_mto_mon_destino := p_mto_mon_original * p_cot_mon_original;
           if p_cot_mon_destino is null then
              p_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino);
           end if;
           p_mto_mon_destino := ROUND(p_mto_mon_destino/p_cot_mon_destino,v_redondeo);
       end if;
   end if;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;
/* Calcula el Interes compuesto */
FUNCTION FU_CAL_INT_COMPUESTO
 (P_CAPITAL IN NUMBER := 0
 ,P_CAN_DIAS IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_VAL_TASA IN NUMBER := 0
 )
 RETURN NUMBER
 IS

V_MTO_INTERES NUMBER(18, 2) := 0;
BEGIN
  /*Modificado por CDE
    Fecha: 14-05-2004*/
   IF NVL(p_can_dias,0) <> 0 THEN
      v_mto_interes := (p_capital / p_can_dias) *  power((1 + p_val_tasa/100),(p_can_dias / 365));
      v_mto_interes := v_mto_interes - (p_capital / p_can_dias);
   END IF;
   return v_mto_interes;
END;
/* Calcular interes simple. */
FUNCTION FU_CAL_INT_SIMPLE
 (P_CAPITAL IN NUMBER := 0
 ,P_CAN_DIAS IN AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE
 ,P_VAL_TASA IN NUMBER := 0
 )
 RETURN NUMBER
 IS

V_MTO_INTERES NUMBER(18, 2) := 0;
BEGIN
  v_mto_interes := 0;
  IF NVL(p_can_dias,0) <> 0 THEN
    v_mto_interes := p_capital * p_val_tasa * p_can_dias / 36500;
  END IF;
  RETURN (v_mto_interes);
END;
/* Obtiene la cotizacion de una moneda */
FUNCTION FU_OBT_COTIZACION
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_CONVERSION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_conversion
   INTO  v_val_conversion
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = p_cod_moneda
                           AND fecha <= P_FEC_TRANSACCION)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_conversion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_conversion := NULL;
      Return v_val_conversion;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Al buscar Cotizacion '||SQLERRM);
END;
/* Buscar moneda local. */
FUNCTION FU_OBT_MON_LOCAL
 RETURN VARCHAR2
 IS

V_MON_LOCAL GE_PAR_GENERALES.COD_MON_LOCAL%TYPE;
BEGIN

   SELECT cod_mon_local
   INTO v_mon_local
   FROM ge_par_generales
   WHERE ROWNUM = 1;
   RETURN v_mon_local;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR al buscar moneda local');
END;
/* Obtener cuenta contable. */
FUNCTION FU_OBT_CUE_CONTABLE
 (P_CUENTA IN GE_CTA_CLIENTES.NRO_CUENTA%TYPE
 ,P_PLAZO IN GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 ,P_TIP_MOVIMIENTO IN GE_TIP_ASIENTOS.TIP_MOVIMIENTO%TYPE
 ,P_MONEDA IN GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 RETURN VARCHAR2
 IS

V_COD_SEC_CONTABLE GE_CLIENTES.COD_SEC_CONTABLE%TYPE;
V_RESIDENTE GE_CLIENTES.RESIDENTE%TYPE;
V_COD_TIP_DEUDOR GE_CLIENTES.COD_TIP_DEUDOR%TYPE;
V_COD_PLAZO GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
V_IND_DEUDOR GE_TIP_ASIENTOS.IND_DEUDOR%TYPE;
V_COD_RUBRO GE_TIP_ASIENTOS.COD_RUBRO%TYPE;
V_IND_PLAZO GE_TIP_ASIENTOS.IND_PLAZO%TYPE;
V_LUGAR VARCHAR2(100);
BEGIN
  v_lugar := 'Busca el Sector, Residencia y el tipo de deudor del Cliente ';
   SELECT c.COD_SEC_CONTABLE, c.RESIDENTE, c.COD_TIP_DEUDOR
   INTO v_cod_sec_contable, v_residente , v_cod_tip_deudor
   FROM GE_CLIENTES c, GE_CTA_CLIENTES cc
   WHERE c.COD_PERSONA = cc.COD_PERSONA
   AND cc.NRO_CUENTA = p_cuenta
   AND cc.RELACION = 'P';
   v_lugar := 'Busca el Plazo de la Cuenta ';

   SELECT COD_PLAZO
   INTO v_cod_plazo
   FROM GE_PLZ_CONTABLES
   WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                     FROM GE_PLZ_CONTABLES G
                     WHERE G.CAN_DIAS >= p_plazo);
   v_lugar := 'Busca el Asiento Contable ';

   SELECT G.COD_RUBRO, G.IND_PLAZO, G.IND_DEUDOR
   INTO v_cod_rubro,  v_ind_plazo,  v_ind_deudor
   FROM GE_TIP_ASIENTOS G,GE_TRANSACCIONES GG
   WHERE GG.COD_TRANSACCION = p_cod_transaccion
   AND G.COD_MONEDA = p_moneda
   AND G.TIP_MOVIMIENTO = p_tip_movimiento
   AND G.COD_SEC_CONTABLE = v_cod_sec_contable
   AND G.COD_TIP_ASIENTO = GG.COD_TIP_ASIENTO
   AND(IND_RESIDENTE = v_residente OR IND_RESIDENTE = 'X');

   v_lugar := 'Verifico si importa el Plazo ';
   IF v_ind_plazo = 'S' THEN
      v_cod_rubro := SUBSTR(v_cod_rubro,1,2)||LTRIM(TO_CHAR(v_cod_plazo))||SUBSTR(v_cod_rubro,4,12);
   END IF;

   v_lugar := 'Verifica el Tipo de Deudor ';
   IF v_ind_deudor = 'S' THEN
      v_cod_rubro := SUBSTR(v_cod_rubro,1,8)||LTRIM(TO_CHAR(v_cod_tip_deudor,'00'))||
                   SUBSTR(v_cod_rubro,11,5);
   END IF;
   RETURN(v_cod_rubro);
EXCEPTION
   WHEN OTHERS THEN
   RETURN(' ');
END;
/* Agregar Meses a una fecha dada */
FUNCTION FU_AGR_MES
 (P_FECHA IN DATE
 ,P_CAN_MES IN NUMBER
 )
 RETURN DATE
 IS

V_NVA_FECHA DATE;
BEGIN
   ---Ver donde se utiliza
   v_nva_fecha := ADD_MONTHS(p_fecha,p_can_mes);
   LOOP
      EXIT WHEN TO_CHAR(p_fecha,'DD') >= TO_CHAR(v_nva_fecha,'DD');
      v_nva_fecha := v_nva_fecha - 1;
   END LOOP;
   RETURN v_nva_fecha;
END;
/* Encripta PIN del cliente. */
FUNCTION FU_ENC_PIN
 (P_CLAVE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
   p_encriptado Varchar2(16);
   BEGIN
     p_encriptado := PAG_ENC.FU_ENCRIPTAR(P_CLAVE);
     Return p_encriptado;
     EXCEPTION
            WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001,''||'FU_ENC_PIN'||SQLERRM);
   END;
--FUNCION DESACTUALIZADA 
/*FUNCTION FU_ENC_PIN
 (P_CLAVE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
Cad      CHAR(15) := '39z06x8w74y25v1';
   Sec      CHAR(10) := '2804697513';
   Bas      number(02) := 3;
   LCad     number(02);
   I        number(02);
   Letra    char(01);
   CadFinal Varchar2(10);
   CadOrig  Varchar2(10);
   V_Letra  number(2);
   V_Secue  number(2);
   Valor    number(2);
   Lon      number(2);
   v_cliente  number(6);
   Nuevo    varchar2(10);
   vCodProducto varchar2(4);
   vSaldo   Number(14, 2);
   vFecApertura date;
   v_fec_cancel date := trunc(sysdate);
   vMoneda   varchar2(3);
   vpaquete  varchar2(10);
   vEstado   varchar2(1);
   vSistProd varchar2(2);
   vEsfisica varchar2(1);
   v_mensaje varchar2(1000);
   v_mes number(2);
   v_anio number(4);
   v_pos_ini varchar2(1);
   v_numero  number;
BEGIN
   Nuevo := lpad(p_clave, 10, '0');
   CadOrig := Nuevo;
   CadFinal := null;
   LCad := LENGTH(Cad);
   I    := LENGTH(Sec);
   Lon  := LENGTH(CadOrig);
   LOOP
       Letra   := SUBSTR(CadOrig, Lon,1);      -- Determina caracter
       V_Letra := INSTR(Cad,Letra)-1;         -- Valor numerico del caracter
       V_Secue := TO_NUMBER(SUBSTR(Sec,i,1)); -- Valor de la secuencia
       Valor   := V_Letra + V_Secue + Bas;    -- Nvo. valor de la letra
       Valor   := MOD(Valor,LCad);
       Bas     := NVL(Valor,0);
       IF NVL(Valor,0) = 0 THEN
       Valor := LCad;
       END IF;
       IF CadFinal IS NULL THEN
       CadFinal  := SUBSTR(Cad, Valor,1);
       ELSE
       CadFinal  := SUBSTR(Cad, Valor,1) || CadFinal ;
       END IF;
       Lon := Lon - 1;
       I   := I -1;
       IF I < 1 THEN
          I := LENGTH(Sec);
       END IF;
       EXIT WHEN Lon  = 0;
   END LOOP;
   Return CadFinal;

  End;*/




/* Desencripta un PIN */
FUNCTION FU_DES_PIN
 (P_CLAVE IN VARCHAR2
 )
 RETURN NUMBER
 IS
   p_descencriptado number;
   BEGIN
     p_descencriptado := PAG_ENC.FU_DESCENCRIPTAR(P_CLAVE);
     Return p_descencriptado;
     EXCEPTION
            WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001,''||'FU_DES_PIN'||SQLERRM);
   END;
--FUNCION DESACTUALIZADA
/*FUNCTION FU_DES_PIN
 (P_CLAVE IN VARCHAR2
 )
 RETURN number
 IS
Cad      CHAR(15) := '39z06x8w74y25v1';
Sec      CHAR(10) := '2804697513';
Letra    char(01);
S_Letra  varchar2(02);
CadFinal number(10);
LCad     number(02);
I        number(02);
J        number(02);
V_Letra  number(2);
V_Secue  number(2);
Valor    number(2);
Lon      number(2):= 1;
A1       number(2);
VsLetra  number(2);
BEGIN
   CadFinal := null;
   LCad := LENGTH(Cad);
   I    := LENGTH(Sec);
   J    := LENGTH(p_clave);
   IF J < I + 1  THEN
      I := (i - j) + 1;
   ELSE
      A1 := MOD(J,I);
      I := (I - A1)+1;
      IF I > LENGTH(Sec) THEN
         I := 1;
      END IF;
   END IF;
   LOOP
      Letra := SUBSTR(p_clave,Lon,1);        -- Ubicar Letra
      V_Letra := INSTR(Cad,Letra);           -- Valor de la letra
      V_secue := TO_NUMBER(SUBSTR(Sec,i,1)); -- Numero en la secuencia
      IF Lon = j THEN
        VsLetra := 3;
      ELSE
        S_Letra := SUBSTR(p_clave, lon+1,1);  -- sgte. letra
        VsLetra := INSTR(Cad, S_Letra);       -- valor sgte. letra
      END IF;
      Valor := V_Letra - (VsLetra + V_Secue -1);  --obtener nuevo valor
      IF Valor = 0 THEN
        Valor := LCad;
      ELSE
         LOOP
            EXIT WHEN Valor >= 1;
            Valor := Valor + LCad;
        END LOOP;
      END IF;
      IF CadFinal IS NULL THEN
         CadFinal  := SUBSTR(Cad, Valor,1);
      ELSE
         CadFinal  := CadFinal||SUBSTR(Cad, Valor,1)  ;
      END IF;
      Lon := Lon + 1;
      I := I + 1;
      IF I > LENGTH(Sec) THEN
         I := 1;
      END IF;
      EXIT WHEN Lon >= J+1;
   END LOOP;
   RETURN CadFinal;
END;*/

/* Obtiene el tipo de persona. */
FUNCTION FU_ES_PER_FISICA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS

V_ESFISICA VARCHAR2(1) := 'N';
begin
   select decode(nvl(TIPO ,'O'), 'F', 'S', 'N')
   into v_esfisica
   from BA_PERSONAS
   where COD_PERSONA = P_COD_PERSONA;
   return(v_esfisica);
exception
   when no_data_found then
   return('O');
   when others then
   return('O');
end;
/* Obtiene el Valor de la tasa a aplicar */
PROCEDURE PR_OBT_VAL_TASA
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_TRANSACCION IN NUMBER default 0
 ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
 ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_TIP_VALOR OUT GE_TASAS.TIP_VALOR%TYPE
 ,P_TIPO OUT GE_TASAS.TIPO%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN NUMBER)

 IS

  v_lugar                  VARCHAR2(250);
  v_fec_final              DATE;
  v_fec_vigencia           GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
  v_encontro_tas_pers      VARCHAR2(1) := 'N';
  v_cod_persona            BA_PERSONAS.COD_PERSONA%TYPE;
  v_tip_iva                BA_PERSONAS.TIP_IVA%TYPE;
  v_tas_personalizada      BA_PERSONAS.TAS_PERSONALIZADA%TYPE;
  v_spread                 GE_TAS_FECHAS.VAL_EXTENSION%TYPE;
  v_cod_sub_modalidad      GE_TAS_FECHAS.COD_SUB_MODALIDAD%TYPE := p_cod_sub_modalidad;
  v_val_tasa               GE_TAS_FECHAS.VAL_TASA%TYPE := -999;
  v_aux_val_min            GE_TAS_FECHAS.VAL_MINIMO%TYPE;   --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_aux_val_max            GE_TAS_FECHAS.VAL_MAXIMO%TYPE;   --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_aux_val_hasta          GE_TAS_RANGOS.VAL_HASTA%TYPE;    --Es una columna auxiliar donde se descargara los datos a nivel general, dependiendo del caso se utilizará o no este campo para retornar valores.
  v_redondeo               number(4);
  v_cod_ente               ge_entes.cod_ente%type;
/*
    Rutina que permite buscar el valor de la tasa a aplicar
    dependiendo del cod.tasa a utilizar. Se debe pasar los siguientes parametros:
    cod_modulo          Modulo de la Cuenta
    cod_modalidad       Modalidad de la Cuenta
    cod_sub_modalidad   Sub Modalidad de la Cuenta
    cod_oficina         Oficina de la Cuenta
    nro_cuenta          Numero de Cuenta
    cod_moneda          Moneda
    cod_transaccion     Codigo de la transaccion (puede ser null)
    mto_transaccion     Monto de la Transaccion (puede ser null)
    fec_final           Fecha final
    tas_personalizada   Si posee tasa personalizada
    cod_tasa            Codigo de la tasa (puede ser null)
    val_tasa            Envia como respuesta el Valor de la tasa
    cod_persona         Codigo de la Persona (puede ser null
*/

BEGIN
   v_lugar     := 'pr_obt_val_tasa';
   v_fec_final := p_fec_final;
   --
   if p_nro_cuenta is not null then
     v_cod_ente := fug_obt_ent_pag_sue(p_nro_cuenta);
   else
     v_cod_ente := null;
   end if;
      -- Recuperar el valor para el redondeo correspondiente
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',p_cod_modulo,p_cod_modalidad,p_cod_moneda);
   IF v_fec_final IS NULL THEN
      -- Recuperar la fecha del modulo desde donde se esta ejecutando
      v_fec_final := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   END IF;
   --limpiar globales
   pr_ini_variables(null, null);

   -- Recupera el codigo de tasa en el caso de fuere null de la tabla GE_TRANSACCIONES
   IF p_cod_tasa IS NULL AND p_cod_transaccion IS NOT NULL THEN
      BEGIN
         v_lugar := 'pr_obt_val_tasa: GE_TRANSACCIONES: Mad '||p_cod_modalidad||' Tra '||p_cod_transaccion;
         SELECT cod_tasa
           INTO p_cod_tasa
           FROM ge_transacciones
          WHERE cod_modulo      = p_cod_modulo
            AND cod_modalidad   = p_cod_modalidad
            AND cod_transaccion = p_cod_transaccion;
      EXCEPTION
            WHEN OTHERS THEN
             RAISE_APPLICATION_ERROR(-20001,v_lugar||' '||SQLERRM);
      END;
      IF p_cod_tasa IS NULL THEN
         p_val_tasa := 0;
         RETURN;
      END IF;
   END IF;
   -- Lee la Tabla de tasas para saber si es tarifa o porcentaje.
   BEGIN
      v_lugar := 'pr_obt_val_tasa: GE_TASAS';
      SELECT tip_valor, tipo
        INTO p_tip_valor, p_tipo
        FROM ge_tasas
       WHERE cod_tasa = p_cod_tasa;
   EXCEPTION
         WHEN OTHERS THEN
              RAISE_APPLICATION_ERROR(-20002,' Tasa '||TO_CHAR(p_cod_tasa)||' '||p_cod_moneda||
                                     to_char(p_cod_oficina,'999')||' '||p_nro_cuenta||' '||v_lugar||' '||SQLERRM);
   END;
   -- buscar principal de cuenta y tipo de contribuyente, siempre q tenga cuenta y no venga de apertura(sin cta asignada)
   IF p_nro_cuenta is not null and p_nro_cuenta <> '999999999999999' THEN
      BEGIN
        v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
      EXCEPTION
        when others then
           NULL; --que no caiga por error
      END;
   ELSIF p_cod_persona is not null THEN
     v_cod_persona := p_cod_persona; -- buscar x la persona, ya que no tiene cuenta
   END IF;
   IF p_nro_cuenta is not null and v_cod_sub_modalidad is null THEN
     v_cod_sub_modalidad := fug_obt_cod_sub_modalidad(p_nro_cuenta);
   END IF;
   ----------------
   IF v_cod_persona is not null THEN
      v_tip_iva     := fue_obt_per_tip_iva(v_cod_persona);
      -- ver si la persona tiene personalización de tasas
      BEGIN
        v_lugar := 'pr_obt_val_tasa: Buscando Personalización de Tasas';
         select nvl(tas_personalizada,'N')
           into v_tas_personalizada
           from ba_personas
          where cod_persona = v_cod_persona;
      EXCEPTION
         when others then
            raise_application_error(-20003,' Persona '||v_cod_persona||' '||v_lugar||' '||SQLERRM);
      END;
   END IF;
   --DYDMR-5313 verificar sí solo tiene personalización de tasas por cuenta (ALV-NOV/2016)
   IF v_tas_personalizada <> 'S' and p_nro_cuenta is not null THEN 
      Begin
        v_lugar := 'pr_obt_val_tasa: Buscando Personalización de Cuentas';
        select nvl(c.tas_personalizada,'N')
          into v_tas_personalizada        
          from ge_cuentas c
         where c.nro_cuenta = p_nro_cuenta;
      Exception
        when others then
          raise_application_error(-20003,' Cuenta '||p_nro_cuenta||' '||v_lugar||' '||SQLERRM);
      End;
   END IF;
      
   /* Si la tasa es personalizada busca primero el valor de la tasa en GE_TAS_FECHAS o en GE_TAS_RANGOS
      ya sea por cuenta o por persona, si no encuentra valores para procesar se busca la personalizacion
      de la tasa a nivel GENERAL
   */
   IF (p_tas_personalizada = 'S' or v_tas_personalizada = 'S') THEN
      IF  p_tipo = 'F' THEN
          --buscar tasa personalizada x cuenta
          BEGIN
             v_lugar := 'pr_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x cuenta)';
             SELECT nvl(val_tasa,-999), fec_vigencia, val_minimo, val_maximo, val_extension
               INTO v_val_tasa, p_fec_vigencia, g_val_minimo, g_val_maximo, v_spread
               FROM ge_tas_fechas
              WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                --AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x') DYDMR-5313 La personalizacion por cuentas asume la moneda de la cuenta automaticamente
                AND nro_cuenta                                         = p_nro_cuenta --cuenta
                AND cod_tasa                                           = p_cod_tasa
                AND fec_vigencia                                       =(SELECT MAX(fec_vigencia)
                                                                           FROM  ge_tas_fechas
                                                                          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                                                                            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                                                                            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                                                                            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                                                                            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                                                                           -- AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x') DYDMR-5313
                                                                            AND nro_cuenta                                         = p_nro_cuenta --cuenta
                                                                            AND cod_tasa                                           = p_cod_tasa
                                                                            AND fec_vigencia                                      <= v_fec_final);
             v_encontro_tas_pers := 'S';
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                   --buscar tasa personalizada x persona
                   v_lugar := 'pr_obt_val_tasa: GE_TAS_FECHAS (personalizado fijo x persona)';
                   begin
                     SELECT nvl(val_tasa,-999), fec_vigencia, val_minimo, val_maximo, val_extension
                       INTO v_val_tasa, p_fec_vigencia, g_val_minimo, g_val_maximo, v_spread
                       FROM ge_tas_fechas
                      WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                        AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                        AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                        AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                        AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                        AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                        AND nro_cuenta IS NULL
                        AND cod_tasa                                           = p_cod_tasa
                        and cod_persona                                        = v_cod_persona  --persona
                        AND fec_vigencia                                       =(SELECT MAX(fec_vigencia)
                                                                                   FROM  ge_tas_fechas
                                                                                  WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                                                                                    AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                                                                                    AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                                                                                    AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                                                                                    AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                                                                                    AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                                                                                    AND nro_cuenta IS NULL
                                                                                    AND cod_tasa                                           = p_cod_tasa
                                                                                    and cod_persona                                        = v_cod_persona --persona
                                                                                    AND fec_vigencia                                      <= v_fec_final);
                     v_encontro_tas_pers := 'S';
                   exception
                      when no_data_found then
                         v_encontro_tas_pers := 'N';
                      when others then
                         RAISE_APPLICATION_ERROR(-20004,' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                        v_lugar||' - para Persona '||v_cod_persona||' '||SQLERRM);
                   end; --hasta aquí persona
             WHEN OTHERS THEN
                 RAISE_APPLICATION_ERROR(-20005,' Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                                v_lugar||' - para '||p_cod_moneda||' '||v_fec_final||' '||SQLERRM);
          END;
       ELSIF p_tipo = 'V' THEN -- JG : 20/05/11 : Buscar personalizacion de tasa por rangos
            DECLARE CURSOR rango IS
               SELECT fec_vigencia, nvl(val_Tasa,-999), val_extension, val_hasta
                 FROM ge_tas_rangos
                WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                  AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                  AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                  AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                  AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                  AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                  AND nro_cuenta                                         = p_nro_cuenta
                  AND cod_tasa                                           = p_cod_tasa
                  AND val_hasta                                         >= NVL(p_mto_transaccion,0)
                  AND fec_vigencia                                      <= v_fec_final
               ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                      DECODE(COD_MODALIDAD, NULL, 0, 1) +
                      DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC,
                      DECODE(NRO_CUENTA, NULL, 0, 1) DESC,
                      fec_vigencia DESC, val_hasta ASC;

            BEGIN
               v_lugar := 'pr_obt_val_tasa: GE_TAS_RANGOS (personalizado variable x cuenta)';
               IF rango%isopen THEN
                  CLOSE rango;
               END IF;
               OPEN rango;
                 FETCH rango INTO p_fec_vigencia, v_val_Tasa, v_spread, g_val_hasta;
                    IF RANGO%NOTFOUND THEN  -- si no encuentra por cuenta busca por persona
                      -- Buscar si esta personalizado por Persona
                      DECLARE CURSOR rango IS
                       SELECT fec_vigencia, nvl(val_Tasa,-999), val_extension, val_hasta
                         FROM ge_tas_rangos
                        WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
                          AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
                          AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
                          AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
                          AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
                          AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
                          AND nro_cuenta IS NULL
                          AND cod_tasa                                           = p_cod_tasa
                          and cod_persona                                        = v_cod_persona
                          AND val_hasta                                         >= NVL(p_mto_transaccion,0)
                          AND fec_vigencia                                      <= v_fec_final
                        ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                                 DECODE(COD_MODALIDAD, NULL, 0, 1) +
                                 DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC,
                                 DECODE(COD_PERSONA,NULL,0,1) DESC,
                                 fec_vigencia DESC, val_hasta ASC;
                      BEGIN
                        v_lugar := 'pr_obt_val_tasa: GE_TAS_RANGOS (personalizado variable x persona)';
                        IF rango%isopen THEN
                          CLOSE rango;
                        END IF;
                        OPEN rango;
                          FETCH rango INTO p_fec_vigencia, v_val_tasa, v_spread, g_val_hasta;
                        IF RANGO%NOTFOUND THEN
                           v_encontro_tas_pers := 'N';
                        ELSE
                           v_encontro_tas_pers := 'S';
                        END IF;
                        CLOSE RANGO;
                      END;
                    ELSE
                      v_encontro_tas_pers := 'S';
                    END IF;
               CLOSE RANGO;
             END;
       END IF;
   END IF;
   -- Si es fija se busca el valor en GE_TAS_FECHAS a nivel GENERAL (GENERAL no tiene spread)
   IF p_tipo = 'F' and v_val_tasa = -999 THEN
      --si no encontró o tiene spread o no tiene val_tasa, busca la tasa base
      DECLARE CURSOR fijas IS
         SELECT nvl(val_tasa,0), fec_vigencia, val_minimo, val_maximo
           FROM ge_tas_fechas
          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
            and nvl(tip_iva,nvl(v_tip_iva,'x'))                    = nvl(v_tip_iva,'x')
            AND cod_tasa                                           = p_cod_tasa
            AND nro_cuenta  IS NULL
            and cod_persona IS NULL
            and fec_vigencia                                      <= v_fec_final
       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;

        BEGIN
           v_lugar := 'pr_obt_val_tasa: GE_TAS_FECHAS (gral)';
           IF fijas%isopen THEN
              CLOSE fijas;
           END IF;
           OPEN fijas;
              FETCH fijas INTO v_val_tasa, p_fec_vigencia, v_aux_val_min, v_aux_val_max;
           IF FIJAS%NOTFOUND THEN
              --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
              RAISE_APPLICATION_ERROR(-20006,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                              v_lugar||'- para '||p_cod_moneda);
           END IF;
           CLOSE FIJAS;
            --Si a nivel personalizado no se ha definido tampoco el val_minimo y el val_maximo,
            --se carga dichos valores del nivel general
           IF g_val_minimo IS NULL THEN
              g_val_minimo := v_aux_val_min;
           END IF;
           IF g_val_maximo IS NULL THEN
              g_val_maximo := v_aux_val_max;
           END IF;
        END;
   ELSIF p_tipo = 'V' and v_val_tasa = -999 THEN
      --si no encontró o tiene spread o no tiene val_tasa, busca la tasa base
      DECLARE CURSOR rango IS
         SELECT fec_vigencia, nvl(val_tasa,0), val_hasta
           FROM ge_tas_rangos
          WHERE nvl(cod_modulo,nvl(p_cod_modulo,-1))               = nvl(p_cod_modulo,-1)
            AND nvl(cod_modalidad,nvl(p_cod_modalidad,-1))         = nvl(p_cod_modalidad,-1)
            AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
            AND nvl(cod_oficina,nvl(p_cod_oficina,-1))             = nvl(p_cod_oficina,-1)
            AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
            AND nvl(cod_moneda,nvl(p_cod_moneda,'x'))              = nvl(p_cod_moneda,'x')
            AND nro_cuenta  IS NULL
            and cod_persona IS NULL
            AND cod_tasa                                           = p_cod_tasa
            AND val_hasta                                         >= NVL(p_mto_transaccion,0)
            AND fec_vigencia                                      <= v_fec_final
       ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
                DECODE(COD_MODALIDAD, NULL, 0, 1) +
                DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC, val_hasta ASC;

        BEGIN
           v_lugar := 'pr_obt_val_tasa: GE_TAS_RANGOS (gral. 01)';
           IF rango%isopen THEN
              CLOSE rango;
           END IF;
           OPEN rango;
              FETCH rango INTO p_fec_vigencia, v_val_tasa, v_aux_val_hasta;
           IF RANGO%NOTFOUND THEN
              --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
              RAISE_APPLICATION_ERROR(-20008,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)||' '||
                                             v_lugar||'- para '||p_cod_moneda||' '||p_mto_transaccion);
           END IF;
           CLOSE RANGO;
           --Si a nivel personalizado no se ha definido tampoco el val_hasta,
           --se carga el val_hasta del nivel general
           IF nvl(g_val_hasta,0) = 0 THEN
              g_val_hasta := nvl(v_aux_val_hasta, 0);
           END IF;
        END;
     END IF;
     IF v_val_tasa = -999 THEN
        v_lugar := 'pr_obt_val_tasa: despues de recuperar tasa a nivel gral.';
        --limpiar globales
        pr_ini_variables(null, null);
        --Si por algun motivo no ha ingresado en ninguno de los procedimientos
        --se debe tratar el v_val_tasa= -999, para el proceso.
        RAISE_APPLICATION_ERROR(-20009,'El valor para la Tasa ' || p_cod_tasa || ' no puede ser ' || TO_CHAR(v_val_tasa) || ' ' || v_lugar);
     END IF;
     p_val_tasa := nvl(v_val_tasa,0);
     IF v_spread IS NOT NULL THEN
       if nvl(p_tip_valor,'X') = 'P' then -- No se redondea para porcentaje. V.O. 05-02-14
         p_val_tasa := nvl(p_val_tasa,0) - (nvl(p_val_tasa,0) * (v_spread/100));
       else
         p_val_tasa := round(nvl(p_val_tasa,0) - (nvl(p_val_tasa,0) * (v_spread/100)),v_redondeo);
       end if;
     END IF;
END;

/* Obtiene el Valor de la tasa a aplicar */
PROCEDURE PR_OBT_VAL_TASA
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_TRANSACCION IN NUMBER default 0
 ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
 ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_FEC_FINAL IN DATE
 ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
 ,P_FEC_VIGENCIA OUT GE_TAS_FECHAS.FEC_VIGENCIA%TYPE
 ,P_TIP_VALOR OUT GE_TASAS.TIP_VALOR%TYPE
 ,P_TIPO OUT GE_TASAS.TIPO%TYPE
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL)
 IS
 v_cod_sub_modalidad number(5) := fug_obt_cod_sub_modalidad(p_nro_cuenta);
begin
   PR_OBT_VAL_TASA(P_COD_MODULO
                   ,P_COD_MODALIDAD
                   ,P_COD_OFICINA
                   ,P_NRO_CUENTA
                   ,P_COD_MONEDA
                   ,P_MTO_TRANSACCION
                   ,P_TAS_PERSONALIZADA
                   ,P_COD_TASA
                   ,P_COD_TRANSACCION
                   ,P_FEC_FINAL
                   ,P_VAL_TASA
                   ,P_FEC_VIGENCIA
                   ,P_TIP_VALOR
                   ,P_TIPO
                   ,P_COD_PERSONA
                   ,V_COD_SUB_MODALIDAD);

end;

/* Inserta datos en la Tabla GE_MOVIMIENTOS */
PROCEDURE PR_INS_GE_MOVIMIENTO
 (RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE
 ,P_ES_NOCTURNO IN CHAR := 'X'
 )
 IS
v_est_modulo ba_modulos.estado%type;
   v_es_nocturno varchar2(1);
   v_error varchar2(30);
BEGIN
   IF NVL(rp_gmovi.cod_modalidad,0) != 149 AND NVL(rp_gmovi.cod_mad_padre,0) != 149 THEN --GMPEREIRA TN-929
       
       v_es_nocturno := nvl(p_es_nocturno,'N');
       if nvl(p_es_nocturno,'X') = 'X' then
          v_es_nocturno := 'N'; -- si se omite este parametro debe tomarse como ge_movimientos
       end if;
       if v_es_nocturno = 'N' then
          v_error := 'GE_MOVIMIENTOS';
          insert into ge_movimientos(
                    cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina,
            nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha, fec_valor, nro_documento,
            monto, cod_autorizacion, cod_usu_autorizador, cod_error, cod_retencion, fec_fin_retencion, est_cuenta,
            nro_documento2, nro_documento3, estado, cod_causa, cod_banco,  cod_ofi_origen,
            cod_bco_central, concepto, cod_tip_ope_cambio, cod_tasa, val_tasa, reversado, cod_usu_reversion,
            hor_reversion, emi_aviso, protegido, cod_mod_padre, cod_mad_padre, tip_mov_rubro, cod_rubro,
            mto_equ_local, cotizacion, nro_documento4, nro_caja, cod_ref_cambio,
            referencia, cod_persona, cod_sit_contable)
           values (
                    rp_gmovi.cod_usuario, rp_gmovi.hora, rp_gmovi.nro_secuencia, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina,
            rp_gmovi.nro_cuenta, rp_gmovi.cod_moneda, rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.fecha, rp_gmovi.fec_valor, rp_gmovi.nro_documento,
            rp_gmovi.monto, rp_gmovi.cod_autorizacion, rp_gmovi.cod_usu_autorizador, rp_gmovi.cod_error, rp_gmovi.cod_retencion, rp_gmovi.fec_fin_retencion, rp_gmovi.est_cuenta,
            rp_gmovi.nro_documento2, rp_gmovi.nro_documento3, rp_gmovi.estado, rp_gmovi.cod_causa, rp_gmovi.cod_banco,  rp_gmovi.cod_ofi_origen,
            rp_gmovi.cod_bco_central, rp_gmovi.concepto, rp_gmovi.cod_tip_ope_cambio, rp_gmovi.cod_tasa, rp_gmovi.val_tasa, rp_gmovi.reversado, rp_gmovi.cod_usu_reversion,
            rp_gmovi.hor_reversion, rp_gmovi.emi_aviso, rp_gmovi.protegido, rp_gmovi.cod_mod_padre, rp_gmovi.cod_mad_padre, rp_gmovi.tip_mov_rubro, rp_gmovi.cod_rubro,
            rp_gmovi.mto_equ_local, rp_gmovi.cotizacion, rp_gmovi.nro_documento4, rp_gmovi.nro_caja, rp_gmovi.cod_ref_cambio,
            rp_gmovi.referencia, rp_gmovi.cod_persona, rp_gmovi.cod_sit_contable);
       ELSIF v_es_nocturno = 'S' THEN
          v_error := 'GE_MOVIMIENTOS_NOC';
          insert into ge_movimientos_noc(
                    cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina,
            nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha, fec_valor, nro_documento,
            monto, cod_autorizacion, cod_usu_autorizador, cod_error, cod_retencion, fec_fin_retencion, est_cuenta,
            nro_documento2, nro_documento3, estado, cod_causa, cod_banco,  cod_ofi_origen,
            cod_bco_central, concepto, cod_tip_ope_cambio, cod_tasa, val_tasa, reversado, cod_usu_reversion,
            hor_reversion, emi_aviso, protegido, cod_mod_padre, cod_mad_padre, tip_mov_rubro, cod_rubro,
            mto_equ_local, cotizacion, nro_documento4, nro_caja, cod_ref_cambio,
            referencia, cod_persona, cod_sit_contable)
           values (
                    rp_gmovi.cod_usuario, rp_gmovi.hora, rp_gmovi.nro_secuencia, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina,
            rp_gmovi.nro_cuenta, rp_gmovi.cod_moneda, rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.fecha, rp_gmovi.fec_valor, rp_gmovi.nro_documento,
            rp_gmovi.monto, rp_gmovi.cod_autorizacion, rp_gmovi.cod_usu_autorizador, rp_gmovi.cod_error, rp_gmovi.cod_retencion, rp_gmovi.fec_fin_retencion, rp_gmovi.est_cuenta,
            rp_gmovi.nro_documento2, rp_gmovi.nro_documento3, rp_gmovi.estado, rp_gmovi.cod_causa, rp_gmovi.cod_banco,  rp_gmovi.cod_ofi_origen,
            rp_gmovi.cod_bco_central, rp_gmovi.concepto, rp_gmovi.cod_tip_ope_cambio, rp_gmovi.cod_tasa, rp_gmovi.val_tasa, rp_gmovi.reversado, rp_gmovi.cod_usu_reversion,
            rp_gmovi.hor_reversion, rp_gmovi.emi_aviso, rp_gmovi.protegido, rp_gmovi.cod_mod_padre, rp_gmovi.cod_mad_padre, rp_gmovi.tip_mov_rubro, rp_gmovi.cod_rubro,
            rp_gmovi.mto_equ_local, rp_gmovi.cotizacion, rp_gmovi.nro_documento4, rp_gmovi.nro_caja, rp_gmovi.cod_ref_cambio,
            rp_gmovi.referencia, rp_gmovi.cod_persona, rp_gmovi.cod_sit_contable);
       END IF;
	END IF; --FIN GMPEREIRA TN-929
exception
  when others then
          raise_application_error(-20000,'insertar en '||v_error
                            ||' usuario '||substr(lower(user),1,6)
                            ||' hora '||rp_gmovi.hora||' secuencia '||to_char(rp_gmovi.nro_secuencia)||' cuenta '||rp_gmovi.nro_cuenta
                            ||' moneda '||rp_gmovi.cod_moneda||' trhijo '||to_char(rp_gmovi.cod_transaccion)
                            ||' modalidad '||to_char(rp_gmovi.cod_modalidad)||' rubro '||rp_gmovi.cod_rubro
                            ||' fecha  '||to_char(rp_gmovi.fecha)||' importe '||to_char(rp_gmovi.monto)
                            ||' cotizacion '||to_char(rp_gmovi.cotizacion)||' '||sqlerrm);
END;
/* Obtiene la Cotizacion de compra y venta */
PROCEDURE PR_OBT_COT_COM_VENTA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FECHA IN GE_COTIZACIONES.FECHA%TYPE
 ,P_VAL_COMPRA IN OUT GE_COTIZACIONES.VAL_COMPRA%TYPE
 ,P_VAL_VENTA IN OUT GE_COTIZACIONES.VAL_VENTA%TYPE
 )
 IS
Begin
--------------------------------------------------------------
 -- Procedimiento que obtiene las cotizaciones de una moneda --
 --------------------------------------------------------------

   --Creado por CDE - Fecha: 14-06/2004 */
   Select val_venta, val_compra
   into p_val_venta, p_val_compra
   from GE_COTIZACIONES a
   where COD_MONEDA = p_cod_moneda
   and FECHA = (Select max(FECHA)
                              from GE_COTIZACIONES
                             where COD_MONEDA = p_cod_moneda
                               AND FECHA <= p_fecha
                             );
exception
    when no_data_found then
       raise_application_error(-20000,'NO existe cotizacion Compra/Vta para :' ||
       p_cod_moneda || ' en fecha: '|| to_char(p_fecha,'DD/MM/YYYY'));
  End;
/* Obtiene la Cotizacion de compra y venta */
PROCEDURE PR_OBT_COT_BCA_ELECT
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FECHA IN GE_COTIZACIONES.FECHA%TYPE
 ,P_VAL_COM_ELECTRONICA IN OUT GE_COTIZACIONES.VAL_COM_ELECTRONICA%TYPE
 ,P_VAL_VEN_ELECTRONICA IN OUT GE_COTIZACIONES.VAL_VEN_ELECTRONICA%TYPE
 )
 IS
Begin
 --------------------------------------------------------------
 -- Procedimiento que obtiene las cotizaciones de una moneda --
 -- Para la Banca Electronica                                --
 --------------------------------------------------------------
   Select val_ven_electronica, val_com_electronica
   into p_val_ven_electronica, p_val_com_electronica
   from GE_COTIZACIONES a
   where COD_MONEDA = p_cod_moneda
   and FECHA = (Select max(FECHA)
                              from GE_COTIZACIONES
                             where COD_MONEDA = p_cod_moneda
                               AND FECHA <= p_fecha
                             );
exception
    when no_data_found then
       raise_application_error(-20000,'NO existe cotizacion Compra/Vta para :' ||
       p_cod_moneda || ' en fecha: '|| to_char(p_fecha,'DD/MM/YYYY'));
End;
/* Obtiene el siguiente segundo a partir de una hora dada. */
FUNCTION FU_OBT_SIG_SEGUNDO
 (P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 )
 RETURN VARCHAR2
 IS

V_HORA VARCHAR2(2);
V_MINUTO VARCHAR2(2);
V_SEGUNDO VARCHAR2(2);
BEGIN
     V_HORA    := SUBSTR(P_HORA,1,2);
     V_MINUTO  := SUBSTR(P_HORA,4,2);
     V_SEGUNDO := SUBSTR(P_HORA,7,2);
     IF P_HORA = P_HORA THEN
        V_SEGUNDO := TO_NUMBER(V_SEGUNDO) + 1;
        IF TO_NUMBER(V_SEGUNDO) > 59 THEN
           V_SEGUNDO := 0;
           V_MINUTO := TO_NUMBER(V_MINUTO) + 1;
           IF TO_NUMBER(V_MINUTO) > 59 THEN
              V_MINUTO := 0;
              V_HORA := TO_NUMBER(V_HORA) + 1;
              IF TO_NUMBER(V_HORA) > 23 THEN
                 V_HORA := 0;
              END IF;
           END IF;
        END IF;
     END IF;
     -- espera dos segundo para q no se asigne el mismo seg en el sgte llamado
     --if fug_obt_tip_implementacion not in (1,3) then
     --   sys.dbms_lock.sleep(2);
     --end if;
     -- retorna el siguiente segundo a la hora dada ----------
     RETURN  LPAD(V_HORA,2,'0')||':'||LPAD(V_MINUTO,2,'0')||':'||
             LPAD(V_SEGUNDO,2,'0');
     ---------------------------------------------------------
END;
/* Buscar moneda fuerte. */
FUNCTION FU_OBT_MON_FUERTE
 RETURN VARCHAR2
 IS

V_MON_FUERTE GE_PAR_GENERALES.COD_MON_FUERTE%TYPE;
BEGIN

   SELECT cod_mon_fuerte
   INTO v_mon_fuerte
   FROM ge_par_generales
   WHERE ROWNUM = 1;
   RETURN v_mon_fuerte;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR al buscar moneda fuerte');
END;
/* Obtiene la cotizacion de venta de una moneda */
FUNCTION FU_OBT_COT_VENTA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_VENTA GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_venta
   INTO  v_val_venta
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = a.cod_moneda
                           AND fecha <= P_FEC_TRANSACCION)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_venta;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_venta := NULL;
      Return v_val_venta;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Al buscar Cotizacion de Venta '||SQLERRM);
END;
/* Obtiene la cotizacion de compra de una moneda */
FUNCTION FU_OBT_COT_COMPRA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default sysdate
 )
 RETURN NUMBER
 IS

V_VAL_COMPRA GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_compra
   INTO  v_val_compra
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = a.cod_moneda
                           AND fecha <= P_FEC_TRANSACCION)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_compra;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_compra := NULL;
      Return v_val_compra;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR. Al buscar Cotizacion de Venta '||SQLERRM);
END;
/* retorna el codigo de la entidad */
FUNCTION FU_OBT_COD_ENTIDAD
 RETURN VARCHAR2
 IS
v_cod_entidad ge_par_generales.cod_entidad%type;
BEGIN
    select cod_entidad
    into v_cod_entidad
    from ge_par_generales
    where rownum=1;
    RETURN v_cod_entidad;
Exception
     when others then
      raise_application_error(-20000,'No existen Param. Entidad');
END;

/* Convertir un monto de una moneda a otra */
FUNCTION FU_CON_MON_A_MONEDA
   (P_COD_MON_ORIGEN  IN BA_MONEDAS.COD_MONEDA%TYPE
   ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
   ,P_MTO_MON_ORIGEN  IN NUMBER
   ,P_COTIZACION      IN NUMBER 
   ,P_FECHA           IN DATE 
   ,P_COT_MON_DESTINO IN NUMBER 
 )
 RETURN NUMBER
  IS
   v_cod_mon_base     ba_monedas.cod_moneda%type;
   v_mto_mon_destino  NUMBER;
   v_cot_mon_destino  number := p_cot_mon_destino;
   v_cot_mon_origen   number := p_cotizacion;
   v_lugar            varchar2(4000);
   v_redondeo         number(5);
   v_fecha date := NVL(P_FECHA,PAG_CAL.FU_OBT_FEC_ACTUAL(1));
BEGIN
    v_lugar := 'obtener moneda base';
    v_cod_mon_base  := pag_gen.fu_obt_mon_local();
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,p_cod_mon_destino);
    if p_cod_mon_origen = p_cod_mon_destino  then
       v_mto_mon_destino := p_mto_mon_origen;
        if p_cod_mon_origen <> v_cod_mon_base then
           if v_cot_mon_origen is null and v_cot_mon_destino is not null then
              v_cot_mon_origen := v_cot_mon_destino;
           elsif v_cot_mon_origen is null then
              v_cot_mon_origen := fug_obt_cotizacion(p_cod_mon_origen, v_fecha);
           end if;              
           v_cot_mon_destino := v_cot_mon_origen;
        else
           v_cot_mon_destino := 1;
           v_cot_mon_origen := 1;
        end if;
   else
       if  p_cod_mon_origen <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base then
           --convertir moneda origen a base o destino
           if v_cot_mon_origen is null then
              v_cot_mon_origen := fug_obt_cotizacion(p_cod_mon_origen, v_fecha);
           end if;           
           v_cot_mon_destino := 1;
           v_mto_mon_destino := round(p_mto_mon_origen * v_cot_mon_origen,v_redondeo);
       elsif p_cod_mon_origen = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           -- pasar moneda origen a moneda base
           if v_cot_mon_destino is null then
              v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino, v_fecha);
           end if;           
           v_cot_mon_origen := 1;
           v_mto_mon_destino := round(p_mto_mon_origen/v_cot_mon_destino,v_redondeo);
       elsif p_cod_mon_origen <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           if v_cot_mon_origen is null then
              v_cot_mon_origen := fug_obt_cotizacion(p_cod_mon_origen, v_fecha);
           end if;
           v_mto_mon_destino := p_mto_mon_origen * v_cot_mon_origen;
           if v_cot_mon_destino is null then
              v_cot_mon_destino := fug_obt_cotizacion(p_cod_mon_destino, v_fecha);
           end if;       
           v_mto_mon_destino := round(v_mto_mon_destino/v_cot_mon_destino,v_redondeo);
       end if;
   end if;
   return v_mto_mon_destino;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;

/* Convertir un monto de una moneda a otra */
FUNCTION FU_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_COT_MON_ORIGINAL IN NUMBER default null
 )
 RETURN NUMBER
  IS
   v_fecha date := PAG_CAL.FU_OBT_FEC_ACTUAL(1); 
BEGIN
   RETURN (FU_CON_MON_A_MONEDA(
                              P_COD_MON_ORIGINAL,
                              P_COD_MON_DESTINO,
                              P_MTO_MON_ORIGINAL,
                              P_COT_MON_ORIGINAL,
                              v_fecha,
                              NULL));
                  
END;
 
/* Obtiene el valor mínimo de la global del paquete*/
FUNCTION FU_OBT_VAL_MINIMO
 RETURN number
 IS
BEGIN
    return g_val_minimo;
END;
/* Obtiene el valor máximo de la global del paquete*/
FUNCTION FU_OBT_VAL_MAXIMO
 RETURN number
 IS
BEGIN
    return g_val_maximo;
END;

/* Obtiene el valor definitivo final, evaluando mínimo y máximo*/
FUNCTION FU_OBT_VAL_FINAL
 (P_MONTO IN NUMBER)
 RETURN NUMBER
 IS
v_monto ge_tas_fechas.val_maximo%type;
BEGIN
  --si es mayor al máximo devuelve máximo
  if g_val_maximo is not null and p_monto > g_val_maximo then
    v_monto := g_val_maximo;
  elsif g_val_minimo is not null and p_monto < g_val_minimo then --si es menor al mínimo devuelve mínimo
    v_monto := g_val_minimo;
  else
    v_monto := p_monto;
  end if;
  return v_monto;
END;

/* Asigna o limpia variables globales del paquete*/
PROCEDURE PR_INI_VARIABLES
    (p_val_minimo  in ge_tas_fechas.val_minimo%type,
     p_val_maximo  in ge_tas_fechas.val_maximo%type,
     p_val_hasta   in ge_tas_rangos.val_hasta%type default 0,
     p_cod_persona in ge_tas_fechas.cod_persona%type default null,
     p_nro_cuenta  in ge_tas_fechas.nro_cuenta%type default null,
     p_tip_cuenta in varchar2 default null)
 IS
BEGIN
  g_val_minimo := p_val_minimo;
  g_val_maximo := p_val_maximo;
  g_val_hasta  := p_val_hasta;
  g_cod_persona:= p_cod_persona;
  g_nro_cuenta := p_nro_cuenta;
  g_tip_cuenta := p_tip_cuenta;
END;

END PAG_GEN;
/

