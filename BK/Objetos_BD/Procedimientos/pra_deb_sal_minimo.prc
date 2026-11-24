CREATE OR REPLACE PROCEDURE IT.PRA_DEB_SAL_MINIMO
 IS

-- Modificaciones realizadas el 29/06/2004 por OPGM...
-- La tasa toma de la transacción de saldo minimo. Al obtener la fecha actual no tiene porque hacer to_date.
-- Para afectar los saldos mensuales debe tomar la fecha proxima...
-- Se anulo la parte de si es de pago de sueldo...

V_ENCONTRO CHAR(1);
V_IMP_DEBITO NUMBER(18, 2) := 0;
V_SE_PUEDE  varchar2(1);
v_pendiente varchar2(1);
V_ESTADO GE_MOVIMIENTOS.ESTADO%TYPE;
V_CONCEPTO GE_MOVIMIENTOS.CONCEPTO%TYPE;
V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
V_SAL_PARAMETRO NUMBER(18, 2) := 0;
V_TIPO GE_TASAS.TIPO%TYPE;
V_IVA NUMBER(18, 2) := 0;
V_NRO_CUENTA AH_CTA_VISTAS.NRO_CUENTA%TYPE;
V_TAS_PERSONALIZADA AH_CTA_VISTAS.TAS_PERSONALIZADA%TYPE;
V_COD_MONEDA AH_CTA_VISTAS.COD_MONEDA%TYPE;
V_COD_MODULO GE_CALENDARIOS.COD_MODULO%TYPE;
V_EXI_TRA_PROHIBIDA CHAR(1);
V_COD_TASA_AH AH_CTA_VISTAS.COD_TASA%TYPE;
V_EST_MOVIMIENTO GE_MOVIMIENTOS.ESTADO%TYPE;
V_COD_MODALIDAD AH_CTA_VISTAS.COD_MODALIDAD%TYPE;
V_COD_OFICINA AH_CTA_VISTAS.COD_OFICINA%TYPE;
V_COD_TRANSACCION GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_TIP_VALOR GE_TASAS.TIP_VALOR%TYPE;
R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
V_COD_ENTE GE_ENTES.COD_ENTE%TYPE;
V_DB_EMPRE CHAR(1) := 'N';
V_COD_USUARIO VARCHAR2(10);
V_FEC_VIGENCIA GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
V_VAL_TAS_GLOBAL GE_TAS_FECHAS.VAL_TASA%TYPE;
V_FEC_FINAL GE_TAS_FECHAS.FEC_VIGENCIA%TYPE;
V_FECHA GE_MOVIMIENTOS.FECHA%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_EXISTE CHAR(1);
V_DEBITA CHAR(1);
V_DB_EMPRESA CHAR(1) := 'N';
V_CTA_DB_SUELDO VARCHAR2(15);
V_MSJ_ERROR VARCHAR2(1000);
V_PROCESO_OK CHAR(1);
V_COD_TASA AH_CTA_VISTAS.COD_TASA%TYPE;
V_VAL_TASA GE_TAS_FECHAS.VAL_TASA%TYPE;
V_MONTO NUMBER(18, 2) := 0;
V_COD_TASA2 AH_CTA_VISTAS.COD_TASA%TYPE;
V_VAL_TASA2 GE_TAS_FECHAS.VAL_TASA%TYPE;
V_MES_ACTUAL AH_SAL_MENSUALES.MES%TYPE;
V_ANIO_ACTUAL AH_SAL_MENSUALES.ANO%TYPE;
V_TRA_PROHIBIDA AH_CTA_VISTAS.TRA_PROHIBIDA%TYPE;
V_PAG_SUELDO CHAR(1) := 'N';
V_MTO_CARGO NUMBER(18, 2) := 0;
V_MTO_CARGO2 NUMBER(18, 2) := 0;
v_ini_mtocargo  number := 0;
V_SAL_PROMEDIO NUMBER(18, 2) := 0;
V_SAL_MINIMO AH_CTA_VISTAS.SAL_MINIMO%TYPE;
V_SAL_DISPONIBLE AH_CTA_VISTAS.SAL_TOTAL%TYPE;
v_cod_persona ge_cta_clientes.cod_persona%type;
v_nro_documento ge_movimientos.nro_documento%type := 0;
v_redondeo number(4) := 0;
v_cotizacion number;
v_tot_deb_gs number(18);
v_mto_car_gs number(18);
v_mto_iva_gs number(18);
v_cod_sub_modalidad ah_cta_vistas.cod_sub_modalidad%type;
---
v_ent_cta         GE_ENTES.COD_ENTE%TYPE;
v_paquete         number := 0;
v_mto_exoneracion ge_movimientos.monto%type;
v_cod_paq_exnomina ge_paquetes.cod_paquete%type := fug_obt_pardinamico('COD_PAQ_EXNOMINA');
v_eje_pro_deb_sal_minimo varchar2(1)  := fug_obt_pardinamico('EJE_PRO_DEB_SAL_MINIMO');
TYPE t_ah_cta_vista IS RECORD (
     nro_cuenta            AH_CTA_VISTAS.nro_cuenta%TYPE,
     cod_moneda            AH_CTA_VISTAS.cod_moneda%TYPE,
     v_iva                 NUMBER,
     v_existe              VARCHAR2(1),
     cod_persona           GE_CLIENTES.cod_persona%TYPE,
     sal_minimo            AH_CTA_VISTAS.sal_minimo%TYPE,
     estado                AH_CTA_VISTAS.estado%TYPE,
     cod_oficina           AH_CTA_VISTAS.cod_oficina%TYPE,--   
     cod_modalidad         AH_CTA_VISTAS.cod_modalidad%TYPE,
     tas_personalizada     AH_CTA_VISTAS.tas_personalizada%TYPE,
     tra_prohibida         AH_CTA_VISTAS.tra_prohibida%TYPE,
     cod_ente              AH_CTA_VISTAS.cod_ente%TYPE,
     sal_total             AH_CTA_VISTAS.sal_total%TYPE,
     sal_retenido          AH_CTA_VISTAS.sal_retenido%TYPE,
     sal_bloqueado         AH_CTA_VISTAS.sal_bloqueado%TYPE,
     orden                 number
);
 TYPE t_cta_vistas_tab IS TABLE OF t_ah_cta_vista;
 l_cta_vistas t_cta_vistas_tab;
 v_limit PLS_INTEGER := 100000;  -- Ajusta el límite según el entorno   
---DYDMR-6560
  v_deb_pendiente   AH_CTA_VISTAS_NOC.MTO_DEB_PENDIENTES%TYPE := 0;

V_HAB_DEV_GRUPAL GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;

--- DYDMR-9521 IEC03 - Relevamiento y Ajustes a PRA_DEB_SAL_MINIMO
V_VAL_TAS_GENERICA    GE_TAS_FECHAS.VAL_TASA%TYPE;
  
/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
 (P_COD_MODULO IN AH_SAL_MENSUALES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN AH_SAL_MENSUALES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_SAL_MENSUALES.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_ANIO_ACTUAL IN AH_SAL_MENSUALES.ANO%TYPE
 ,P_MES_ACTUAL IN AH_SAL_MENSUALES.MES%TYPE
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_ENCONTRO IN OUT CHAR
 );
/* Actualiza los saldos mensuales. */
PROCEDURE LP_AFE_SAL_MENSUALES
 (P_COD_MODULO IN AH_SAL_MENSUALES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN AH_SAL_MENSUALES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_SAL_MENSUALES.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_MONTO IN AH_SAL_MENSUALES.SAL_INI_MES%TYPE
 );
/* Verifica si una cta. dada es cta. de débito en prestamos o tarjetas. */
PROCEDURE LP_VER_CTA_DEBITO
 (P_NRO_CUENTA IN VARCHAR2
 ,P_EXISTE IN OUT CHAR
 );

v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
           --
CURSOR aho IS
           SELECT NRO_CUENTA, COD_MONEDA,
                  0, 'N', fug_obt_cli_principal(nro_cuenta) cod_persona, a.sal_minimo,
                  a.estado, a.cod_oficina, a.cod_modalidad, a.tas_personalizada,
                  a.tra_prohibida, a.cod_ente, a.sal_total, a.sal_retenido, a.sal_bloqueado, 1 orden
             FROM AH_CTA_VISTAS A
            WHERE ESTADO NOT IN ('C','P','A','T','D','X')
              AND FEC_APERTURA < v_fecha
              AND CTA_COMBINADA = 'N' 
              AND ((V_HAB_DEV_GRUPAL = 'N') OR (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1 
                                                                                         FROM AH_DEV_GRU_CUENTAS X
                                                                                        WHERE X.NRO_CUENTA = A.NRO_CUENTA)))
              AND sal_minimo > ( SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0)
                                   FROM AH_SAL_MENSUALES
                                  WHERE NRO_CUENTA = a.nro_cuenta
                                    AND ANO = v_anio_actual
                                    AND MES = v_mes_actual
                                    AND NVL(CAN_DIA_ACUMULADO,0) <> 0)
            AND sal_minimo is not null
            union 
            SELECT NRO_CUENTA, COD_MONEDA,
                  0, 'N', fug_obt_cli_principal(nro_cuenta) cod_persona, 
                  case 
                    WHEN FUG_ES_EMPLEADO(fug_obt_cli_principal(nro_cuenta)) = 'S' then
                     TO_NUMBER(NVL(FUG_OBT_PARDINAMICO('SAL_MIN_PAC_EMPLEADO',3,a.cod_modalidad,a.cod_moneda,a.cod_oficina,a.cod_sub_modalidad),0))
                  else
                     TO_NUMBER(NVL(FUG_OBT_PARDINAMICO('SAL_MIN_PACTADO',3,a.cod_modalidad,a.cod_moneda,a.cod_oficina,a.cod_sub_modalidad),0))
                  end,
                  a.estado, a.cod_oficina, a.cod_modalidad, a.tas_personalizada,
                  a.tra_prohibida, a.cod_ente, a.sal_total, a.sal_retenido, a.sal_bloqueado, 2   
             FROM AH_CTA_VISTAS A
            WHERE ESTADO NOT IN ('C','P','A','T','D','X')
              AND FEC_APERTURA < v_fecha
              AND CTA_COMBINADA = 'N'
              AND ((V_HAB_DEV_GRUPAL = 'N') OR (V_HAB_DEV_GRUPAL = 'S' AND NOT EXISTS (SELECT 1 
                                                                                         FROM AH_DEV_GRU_CUENTAS X
                                                                                        WHERE X.NRO_CUENTA = A.NRO_CUENTA)))
                                                                                        
             and a.sal_minimo is null
            ORDER BY 16, 1, 2, 4;

/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
 (P_COD_MODULO IN AH_SAL_MENSUALES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN AH_SAL_MENSUALES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_SAL_MENSUALES.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_ANIO_ACTUAL IN AH_SAL_MENSUALES.ANO%TYPE
 ,P_MES_ACTUAL IN AH_SAL_MENSUALES.MES%TYPE
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_ENCONTRO IN OUT CHAR
 )
 IS
BEGIN
  p_encontro := 'S';
  SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0)
    INTO p_sal_promedio
    FROM AH_SAL_MENSUALES
   WHERE NRO_CUENTA = p_nro_cuenta
     AND ANO = p_anio_actual
     AND MES = p_mes_actual
     AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
EXCEPTION
     WHEN NO_DATA_FOUND THEN
       p_sal_promedio := 0;
       p_encontro := 'N';
END;
/* Actualiza los saldos mensuales. */
PROCEDURE LP_AFE_SAL_MENSUALES
 (P_COD_MODULO IN AH_SAL_MENSUALES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN AH_SAL_MENSUALES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN AH_SAL_MENSUALES.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_MONTO IN AH_SAL_MENSUALES.SAL_INI_MES%TYPE
 )
 IS

V_CAN_DIAS NUMBER(2, 0);
V_FEC_PROXIMA GE_CALENDARIOS.FEC_PROXIMA%TYPE;
BEGIN
   v_fec_proxima := pag_cal.FU_OBT_FEC_PROXIMA(v_cod_modulo);
   UPDATE AH_SAL_MENSUALES
      SET SAL_INI_MES = nvl(SAL_INI_MES,0) - nvl(p_monto,0)
    WHERE COD_MODULO = p_cod_modulo
      AND COD_MODALIDAD = p_cod_modalidad
      AND COD_OFICINA = p_cod_oficina
      AND NRO_CUENTA = p_nro_cuenta
      AND ANO = to_number(to_char(v_fec_proxima,'YYYY'))
      AND MES = to_number(to_char(v_fec_proxima,'MM'));
   IF v_fecha + 1 <> v_fec_proxima THEN
      v_can_dias := TO_NUMBER(TO_CHAR(v_fec_proxima,'DD')) - 1;
      /* Actualiza valores saldo acumulado del mes*/
      UPDATE AH_SAL_MENSUALES
         SET SAL_ACU_DIARIO = NVL(SAL_ACU_DIARIO,0) - v_can_dias * NVL(p_monto,0)
       WHERE COD_MODULO = p_cod_modulo
         AND COD_MODALIDAD = p_cod_modalidad
         AND COD_OFICINA = p_cod_oficina
         AND NRO_CUENTA = p_nro_cuenta
         AND ANO = TO_NUMBER(TO_CHAR(v_fec_proxima,'YYYY'))
         AND MES = TO_NUMBER(TO_CHAR(v_fec_proxima,'MM'));
         IF SQL%NOTFOUND THEN
             RAISE_APPLICATION_ERROR(-20000,'No se encontro registro de mes proximo en AH_SAL_MENSUALES');
         END IF;
   END IF;
END;
/* Verifica si una cta. dada es cta. de débito en prestamos o tarjetas. */
PROCEDURE LP_VER_CTA_DEBITO
 (P_NRO_CUENTA IN VARCHAR2
 ,P_EXISTE IN OUT CHAR
 )
 IS

V_CANTIDAD NUMBER(9) := 0;
BEGIN
    SELECT NVL(COUNT(*),0) INTO v_cantidad
      FROM PR_CTA_PRESTAMOS
     WHERE NRO_CTA_DEBITO = p_nro_cuenta
       AND ESTADO <> 'N'
       AND COB_AUTOMATICO = 'S'
       AND ROWNUM = 1;
    IF NVL(v_cantidad,0) = 0 THEN
       SELECT NVL(COUNT(*),0) INTO v_cantidad
         FROM TA_CTA_TARJETAS
        WHERE NRO_CTA_DEBITO = p_nro_cuenta
          AND ESTADO <> 'C'
          AND NVL(DEB_AUTOMATICO,'N') = 'S'
          AND ROWNUM = 1;
    END IF;
    IF NVL(v_cantidad,0) > 0 THEN
       p_existe := 'S';
    ELSE
       p_existe := 'N';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,SQLERRM||' Cta.: '||p_nro_cuenta||' '
      ||'LP_VER_CTA_DEBITO');
END;
/* Obtiene el tipo de persona. */
FUNCTION FU_OBT_TIP_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2 IS
v_tip_persona varchar2(1);
BEGIN
     SELECT TIPO
       INTO v_tip_persona
       FROM BA_PERSONAS
      WHERE COD_PERSONA = P_COD_PERSONA;
     return v_tip_persona;
EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR (-20000,'Error al traer tipo de persona : '||p_cod_persona||' - '||sqlerrm);
END;
/* DYDMR-6560 - 09/06/2017*/
PROCEDURE LP_OBT_DEB_PENDIENTES
 (P_NRO_CUENTA IN AH_CTA_VISTAS_NOC.NRO_CUENTA%TYPE,
  P_DEB_PENDIENTE IN OUT AH_CTA_VISTAS_NOC.MTO_DEB_PENDIENTES%TYPE)
 IS
BEGIN
     SELECT NVL(MTO_DEB_PENDIENTES,0)
       INTO P_DEB_PENDIENTE
       FROM AH_CTA_VISTAS_NOC
      WHERE NRO_CUENTA = P_NRO_CUENTA;
EXCEPTION
  WHEN OTHERS THEN
       P_DEB_PENDIENTE := 0;
END;
--***************************
BEGIN
IF NVL(v_EJE_PRO_DEB_SAL_MINIMO, 'N') = 'S' THEN
  it.pag_cie.PR_SET_PARAMETROS (11, 263, 'PRA_DEB_SAL_MINIMO', 'SECUENCIAL', 'TRACE');  
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   V_HAB_DEV_GRUPAL := NVL(fug_obt_pardinamico('DEV_GRU_HAB_DEV_GRUPAL'),'N');
   v_cod_modulo     := 3; -- Modulo de Ahorro
   v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
   v_hora           := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_nro_secuencia  := 0;
   v_anio_actual    := to_char(v_fecha,'YYYY');
   v_mes_actual     := to_char(v_fecha,'MM');
   v_cod_usuario    := user;
   v_encontro       := 'S';
   --cursor por cuenta de ahorro
   IF aho%ISOPEN THEN
      CLOSE aho;
   END IF;
   OPEN aho;
   LOOP
     FETCH aho BULK COLLECT INTO l_cta_vistas LIMIT v_limit;
     EXIT WHEN l_cta_vistas.COUNT = 0;
     
     FOR i IN 1 .. l_cta_vistas.COUNT LOOP  
       
      v_msj_error     := null; -- Indic. si el mov.tiene o no error 
      v_sal_parametro := 0;
      
      if v_nro_secuencia > 990 then
         v_hora          := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
         v_nro_secuencia := 0;
      end if;
      
      v_estado            := l_cta_vistas(i).estado;
      v_cod_oficina       := l_cta_vistas(i).cod_oficina;
      v_cod_modalidad     := l_cta_vistas(i).cod_modalidad;
      v_cod_sub_modalidad := fug_obt_cod_sub_modalidad(l_cta_vistas(i).nro_cuenta);
      v_tas_personalizada := nvl(l_cta_vistas(i).tas_personalizada,'N');
      v_tra_prohibida     := l_cta_vistas(i).tra_prohibida;
      v_cod_ente          := l_cta_vistas(i).cod_ente;
      v_ent_cta           := l_cta_vistas(i).cod_ente;
      v_cod_moneda        := l_cta_vistas(i).cod_moneda;
      v_db_empre          := 'N';
      v_cta_db_sueldo     := NULL;
      v_sal_promedio      := 0;
      v_monto             := 0;
      v_mto_cargo         := 0;
      v_imp_debito        := 0;
      v_mto_cargo         := 0;
      v_mto_cargo2        := 0;
      v_tot_deb_gs        := 0;
      v_mto_iva_gs        := 0;
      v_mto_car_gs        := 0;
      v_encontro          := 'N';
      v_se_puede          := 'S';
      v_pendiente         := 'N';
      v_cod_tasa_ah       := null;
      v_deb_pendiente     := 0;
      
      If FU_OBT_TIP_PERSONA(l_cta_vistas(i).cod_persona) = 'F' then -- Para personas fisicas
         v_cod_transaccion := 528; -- Trans.Saldo Minimo - Pers.fisicas
      else
         v_cod_transaccion := 4110; -- Trans.Saldo Minimo - Pers.Juridicas
      end if;

      -- ve si tiene transacciones prohibidas para la comision  
      v_exi_tra_prohibida := 'N';
      IF v_tra_prohibida = 'S' THEN
         
         --busca transacción prohibida x la transacción padre
         v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(l_cta_vistas(i).nro_cuenta, v_cod_transaccion);
         IF v_encontro = 'S' THEN
            v_exi_tra_prohibida := 'S';
         END IF;
      END IF;
      
      v_pag_sueldo := 'N';
      IF v_cod_ente IS NOT NULL THEN
         -- Es para evitar cobrar a ctas de pagos de sueldos 
         -- v_pag_sueldo := 'S'; 30/06/2004 OPGM
         v_pag_sueldo := 'N';
         --Debita comisión a la empresa
         v_db_empre := 'N';
      END IF;
      
      -- Si no es una cuenta con transaccion prohibida se procesa dicha cuenta 
      -- ve saldo promedio 
         lp_ver_sal_promedio(v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                             l_cta_vistas(i).nro_cuenta, v_anio_actual  , v_mes_actual,
                             v_sal_promedio , v_encontro);
         
         IF v_encontro = 'N' THEN
            v_msj_error :='Cta '||l_cta_vistas(i).nro_cuenta||' sin saldo promedio !!! ';
         END IF;
         -- Verifica que la cuenta en proceso tenga saldo minimo 
         v_sal_minimo := l_cta_vistas(i).SAL_MINIMO;
         
         IF v_sal_promedio < v_sal_minimo THEN
            -- calcular el monto del cargo a debitar             
            --   DYDMR-6560 - 09/06/2017 se utiliza el proc.LP_OBT_DEB_PENDIENTES
            --   para obtener el monto de debito pendiente del NOC
            
            LP_OBT_DEB_PENDIENTES(l_cta_vistas(i).nro_cuenta, v_deb_pendiente);
            v_sal_disponible := NVL(l_cta_vistas(i).SAL_TOTAL,0) - NVL(l_cta_vistas(i).SAL_RETENIDO,0) -
                                NVL(l_cta_vistas(i).SAL_BLOQUEADO,0) - v_deb_pendiente;
            
            -- Busco valor de la tasa saldo min. actual para dicha cta 
            IF l_cta_vistas(i).v_existe = 'S' THEN
               IF v_exi_tra_prohibida = 'S' OR v_pag_sueldo = 'S' THEN
                  
                  --|| PCC-Exoneración y Extorno de Comisiones y Tasas      
                  prg_ins_exoneracion(v_cod_transaccion,v_cod_modulo,v_cod_modalidad,v_cod_moneda,
                                      l_cta_vistas(i).nro_cuenta,null,null,v_mto_cargo,v_mto_cargo,
                                      null,v_mto_cargo);
                  ---
                  v_mto_cargo := 0;
               ELSE
                  v_mto_cargo := l_cta_vistas(i).sal_total;
                  v_val_tasa  := l_cta_vistas(i).sal_total;
               END IF;
                 v_mto_cargo2 := l_cta_vistas(i).sal_total;
                 v_monto      := l_cta_vistas(i).v_iva;
            
            ELSE--siempre entra x acá
               
               v_debita := 'N';
               IF v_pag_sueldo = 'N' then
                  lp_ver_cta_debito(l_cta_vistas(i).nro_cuenta,v_debita);
               END IF;
               v_fec_final   := v_fecha;
               v_tip_valor   := ' ';
               v_cod_tasa_ah := null;
               
               --DYDMR-9521 IEC03 - Busca el valor de la tasa Generica
               PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,
                                       v_cod_modalidad,
                                       v_cod_oficina,
                                       null,
                                       v_cod_moneda,
                                       null,
                                       'N',
                                       v_cod_tasa_ah,
                                       v_cod_transaccion,
                                       v_fec_final,
                                       -- OUT
                                       v_val_tas_generica,
                                       v_fec_vigencia,
                                       v_tip_valor,
                                       v_tipo);
               --busca_valor_de_tasa_a_aplicar;
               PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                       l_cta_vistas(i).nro_cuenta,v_cod_moneda,v_sal_promedio,
                                       v_tas_personalizada, v_cod_tasa_ah,v_cod_transaccion,v_fec_final,
                                       -- OUT
                                       v_val_tas_global,v_fec_vigencia,v_tip_valor,v_tipo);
               IF v_tip_valor = 'V' THEN
                  IF v_exi_tra_prohibida = 'S' OR v_pag_sueldo = 'S' THEN
                    --
                    -- || PCC-Exoneración y Extorno de Comisiones y Tasas
                    --
                     prg_ins_exoneracion(v_cod_transaccion,v_cod_modulo,v_cod_modalidad,v_cod_moneda,
                                         l_cta_vistas(i).nro_cuenta,null,null,v_val_tas_global,v_val_tas_global,
                                         null,v_val_tas_global);
                     ---
                     v_mto_cargo := 0;
                  ELSE
                     v_mto_cargo := v_val_tas_global;
                  END IF;
                  v_mto_cargo2    := v_val_tas_global;
               ELSE
                  RAISE_APPLICATION_ERROR (-20000,'saldo min. no puede ser porcentual');
               END IF;
               IF v_cod_tasa_ah  IS NULL THEN
                  v_mto_cargo  := 0;
                  v_mto_cargo2 := 0;
               END IF;
               
               v_cod_tasa := v_cod_tasa_ah;
               v_val_tasa := v_val_tas_global;
               v_monto    := 0;
            END IF;
            -- ve si tiene transacciones prohibidas para el cobro iva
            -- sólo si ya no tiene prohibida para la transacción padre
            IF NVL(v_exi_tra_prohibida,'N') <> 'S' and v_mto_cargo <> 0 then
               v_exi_tra_prohibida := 'N';
               IF v_tra_prohibida = 'S' THEN
                  v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(l_cta_vistas(i).nro_cuenta, 517);
                  IF v_encontro = 'S' THEN
                     v_exi_tra_prohibida := 'S';
                  END IF;
               END IF;
               v_tas_personalizada := nvl(l_cta_vistas(i).tas_personalizada,'N');
               v_cod_tasa_ah := null;
               v_fec_final   := v_fecha;
               v_tip_valor   := ' ';
               PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                       l_cta_vistas(i).nro_cuenta,v_cod_moneda,0,
                                       v_tas_personalizada,v_cod_tasa_ah,517,v_fec_final,
                                       -- OUT
                                       v_val_tas_global,v_fec_vigencia,v_tip_valor,v_tipo);
               v_val_tasa2 := v_val_tas_global;
               v_cod_tasa2 := v_cod_tasa_ah;
               v_redondeo  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo, v_cod_modalidad, v_cod_moneda);

              IF v_tip_valor = 'V' or v_tipo = 'V' THEN
                  RAISE_APPLICATION_ERROR(-20001,'IVA debe ser porcentual'||
                                          TO_CHAR(V_COD_MODULO)||' '||TO_CHAR(V_COD_MODALIDAD)
                                          ||' '||l_cta_vistas(i).nro_cuenta);
               ELSE
                     
                     IF v_mto_cargo2  > 0 THEN
                        IF v_cod_moneda = v_cod_mon_local THEN
                           v_monto := ROUND(nvl(v_mto_cargo2,0) *
                                      nvl(v_val_tasa2,0) / 100, v_redondeo);
                        ELSE
                           v_monto := ROUND(nvl(v_mto_cargo2,0) *
                                      nvl(v_val_tasa2,0) / 100, v_redondeo);
                        END IF;
                        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                        v_monto := pag_gen.FU_OBT_VAL_FINAL(v_monto);
                     END IF;
                     
                    -- || PCC-Exoneración y Extorno de Comisiones y Tasas                    
                     IF v_exi_tra_prohibida = 'S' THEN
                        prg_ins_exoneracion(517,v_cod_modulo,v_cod_modalidad,v_cod_moneda,
                                            l_cta_vistas(i).nro_cuenta,null,null,v_monto,v_monto,
                                            null,v_monto);
                        v_monto := 0;
                     END IF;
                     ---
               END IF;
               -- calcular la dif.para saber si el sl. disponible  alcanza p/el debito del cargo  
               v_imp_debito := nvl(v_mto_cargo,0) + nvl(v_monto, 0);
               
               -- guardo el valor inicial del cargo
               v_ini_mtocargo := v_mto_Cargo;
               IF v_db_empre = 'N' then
                  -- Se debita a la Cuenta, no a la Empresa 
                  if v_sal_disponible < v_imp_debito then
                    if v_sal_disponible <= 0 then    -- no se le cobra, pero se deja pendiente
                      v_pendiente := 'S';
                      v_se_puede  := 'N';
                    else
                      
                      -- recalculo para cobrarle hasta el monto disponible
                      -- la diferencia queda pendiente
                       IF v_cod_moneda = v_cod_mon_local THEN
                          v_redondeo := 0;
                       else
                          v_redondeo := 2;
                       end if;
                       
                       v_mto_cargo  := round(v_sal_disponible * v_mto_cargo / v_imp_debito, v_redondeo);
                       v_monto      := v_sal_disponible - v_mto_cargo;
                       v_imp_debito := nvl(v_mto_cargo,0) + nvl(v_monto, 0);
                       v_pendiente  := 'S';
                       v_se_puede   := 'S';
                    end if;
                  else
                    v_se_puede := 'S';
                  end if;
               END IF;
               if v_cod_moneda <> v_cod_mon_local then
                  v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fecha);
                  v_tot_deb_gs := round(v_imp_debito * v_cotizacion,0);
                  v_mto_iva_gs := ROUND(nvl(v_tot_deb_gs,0) *
                                        nvl(v_val_tasa2,0) / (100+nvl(v_val_tasa2,0)), 0);
                  v_mto_car_gs := v_tot_deb_gs - v_mto_iva_gs;
               else
                  v_cotizacion := null;
                  v_mto_iva_gs := null;
                  v_mto_car_gs := null;
               end if;
               v_concepto := 'DEBITO POR SALDO MINIMO';
               v_est_movimiento := 'N';
               
               --|| PCC-Exoneración y Extorno de Comisiones y Tasas
               
               v_paquete := 0;
               begin
                  SELECT count(1)
                    INTO v_paquete
                    FROM ge_paq_modalidades b, ge_paquetes c
                   WHERE v_cod_modulo = b.cod_modulo
                     AND v_cod_modalidad = b.cod_modalidad
                     AND v_cod_sub_modalidad = b.cod_sub_modalidad
                     AND b.cod_paquete = c.cod_paquete
                     AND (c.estado = 'A' or (c.estado = 'I' and c.cod_paquete = v_cod_paq_exnomina));
               exception
                  when no_data_found then
                     v_paquete := 0;
                  when too_many_rows then
                     v_paquete := 1;
                  when others then
                     raise_application_error(-20000,'AL Obt.Paquete:'||sqlerrm);
               end;
               -- DYDMR-9521 IEC03 - Relevamiento y Ajustes a PRA_DEB_SAL_MINIMO
               -- si es Nomina o Paquete tiene exoneracion 100%
               if v_ent_cta IS NOT NULL or -- es PLAN SUELDOS
                  nvl(v_paquete, 0) <> 0 then -- es paquete
                 -- tiene exoneracion
                 prg_ins_exoneracion(v_cod_Transaccion,
                                     v_cod_modulo,
                                     v_cod_modalidad,
                                     v_cod_moneda,
                                     l_cta_vistas(i).nro_cuenta,
                                     null,
                                     v_cod_tasa,
                                     v_val_tas_generica,
                                     v_val_tas_generica,
                                     null,
                                     v_val_tas_generica);
                 v_se_puede  := 'N';
                 v_pendiente := 'N';
               else
                 -- Falta de saldo no es exoneracion
                 -- se busca tasa personalizada y se compara con la tasa generica
                 -- si tiene exoneracion REAL se registra la exoneracion
                 if nvl(v_val_tas_generica, 0) <> nvl(v_val_tasa, 0) then
                   v_mto_exoneracion := nvl(v_val_tas_generica, 0) - nvl(v_val_tasa, 0);
                   -- tiene exoneracion
                   prg_ins_exoneracion(v_cod_Transaccion,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       v_cod_moneda,
                                       l_cta_vistas(i).nro_cuenta,
                                       null,
                                       v_cod_tasa,
                                       v_mto_exoneracion,
                                       v_val_tas_generica,
                                       null,
                                       v_mto_exoneracion);
                  end if;
               end if;
               ---
               --IF v_msj_error IS NOT NULL THEN
               if v_se_puede = 'S' then
                  --generar movimientos
                  v_nro_documento := v_nro_documento + 1;

                  r_gmovi.cod_usuario    := v_cod_usuario;
                  r_gmovi.hora           := v_hora;
                  r_gmovi.cod_modulo     := v_cod_modulo;
                  r_gmovi.cod_modalidad  := v_cod_modalidad;
                  r_gmovi.cod_oficina    := v_cod_oficina;
                  r_gmovi.nro_cuenta     := l_cta_vistas(i).nro_cuenta;
                  r_gmovi.cod_moneda     := v_cod_moneda;
                  r_gmovi.fecha          := v_fecha;
                  r_gmovi.fec_valor      := v_fecha;
                  r_gmovi.estado         := 'N';
                  r_gmovi.cod_ofi_origen := v_cod_oficina;
                  r_gmovi.cod_mod_padre  := v_cod_modulo;
                  r_gmovi.cod_mad_padre  := v_cod_modalidad;
                  r_gmovi.reversado      := 'N';
                  r_gmovi.protegido      := 'N';
                  r_gmovi.nro_documento  := v_nro_documento;
                  
                  IF v_mto_cargo > 0 THEN
                     -- Genera el movimiento de debito en GE_MOVIMIENTOS 
                     r_gmovi.cod_tra_padre   := v_cod_Transaccion;
                     r_gmovi.cod_transaccion := v_cod_Transaccion;
                     r_gmovi.monto           := v_mto_cargo;
                     r_gmovi.cod_tasa        := v_cod_tasa;
                     r_gmovi.val_tasa        := v_val_tasa;
                     r_gmovi.concepto        := v_concepto||' '||to_char(v_fecha,'dd/mm/yyyy');
                     r_gmovi.cotizacion      := v_cotizacion;
                     r_gmovi.mto_equ_local   := v_mto_car_gs;
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
                  END IF;
                  IF v_monto > 0
                  and nvl(V_DB_EMPRE,'N') = 'N' THEN
                     -- Genera el movimiento de debito en GE_MOVIMIENTOS
                     r_gmovi.cod_tra_padre   := 517;
                     r_gmovi.cod_transaccion := 517;
                     r_gmovi.monto           := v_monto;
                     r_gmovi.cod_tasa        := v_cod_tasa2;
                     r_gmovi.val_tasa        := v_val_tasa2;
                     r_gmovi.concepto        := v_concepto||' '||to_char(v_fecha,'dd/mm/yyyy');
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.cotizacion      := v_cotizacion;
                     r_gmovi.mto_equ_local   := v_mto_iva_gs;
                     PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
                  END IF;
                  IF nvl(v_imp_debito, 0) > 0 AND nvl(v_db_empre,'N')='N' THEN
                     -- actualizar el maestro de ahorros 
                     UPDATE AH_CTA_VISTAS
                        SET SAL_TOTAL = SAL_TOTAL - v_imp_debito ,
                            FEC_ULT_MOVIMIENTO = v_fecha,
                            HOR_ULT_MOVIMIENTO = V_HORA
                      WHERE NRO_CUENTA = l_cta_vistas(i).nro_cuenta;
                     -- actualizar el acumulado de saldos mensuales 
                     LP_AFE_SAL_MENSUALES(v_cod_modulo,v_cod_modalidad,
                                          v_cod_oficina,l_cta_vistas(i).nro_cuenta,v_imp_debito);
                  END IF;
               End if;
               --  Generar movimiento Pendiente 
               If v_pendiente = 'S' then
                  v_est_movimiento := 'E';
                   --Ver si queda pendiente solo una porcion o totalmente
                    if v_mto_cargo <> v_ini_mtocargo then   --queda pendiente la porcion que no se pudo debitar
                       v_mto_cargo := v_ini_mtocargo-v_mto_cargo;
                       if  v_monto <> 0 then   --si tiene importe por impuesto
                          v_monto := Round(nvl(v_mto_cargo,0) *
                                        nvl(v_val_tasa2,0) / 100, v_redondeo);
                         --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                          v_monto := pag_gen.FU_OBT_VAL_FINAL(v_monto);
                       end if;
                    end if;
                    If v_mto_cargo > 0 then
                     --Genera el movimiento de debito en GE_MOV_PENDIENTES 
                     -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
                     If  v_sal_disponible = 0 and v_estado = 'I' then
                       null;
                     else
                       v_nro_documento := v_nro_documento + 1;
                       Insert into Ge_Mov_Pendientes
                       (nro_cuenta,Fecha,Cod_modulo,Cod_modalidad,Cod_transaccion,
                        Cod_mod_padre,Cod_mad_padre,Cod_tra_padre,Monto,Hora,Cod_usuario,
                        Cod_moneda,Cod_oficina,Estado,Cod_ofi_origen,
                        Concepto,
                        Cod_tasa,Val_tasa,Nro_documento, saldo)
                       Values
                       (l_cta_vistas(i).nro_cuenta,v_Fecha,v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                        v_cod_modulo,v_cod_modalidad,v_cod_transaccion,nvl(v_mto_cargo,0)+nvl(v_monto,0),v_hora,v_cod_usuario,
                        v_cod_moneda,v_cod_oficina,'I',v_cod_oficina,
                        v_concepto||' '||to_char(v_fecha,'dd/mm/yyyy'),
                        v_cod_Tasa,v_val_tasa,v_nro_documento,
                         nvl(v_mto_cargo,0)+nvl(v_monto,0) );
                      end if;
                    End if;
               END IF;--si msj is null
            end if; --si no tiene transacción padre prohibida
         END IF;--si sal-promedio < minimo 
     END LOOP; 
   END LOOP;
   IF aho%ISOPEN THEN
      CLOSE aho;
   END IF;
 END IF;  
END;
/
