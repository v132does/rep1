CREATE OR REPLACE PACKAGE BODY IT.PAP_MES IS

/* Actualizar el estado de un prestamo. */
PROCEDURE PR_ACT_EST_PRESTAMO 
  (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
    P_ESTADO IN PR_CTA_PRESTAMOS.ESTADO%TYPE
  ) 
  IS 
v_existe number(01);

BEGIN 

   select 1 into v_existe
   from  pr_cta_prestamos
   where nro_cuenta = p_nro_cuenta
   for update nowait;

   update pr_cta_prestamos
   set    est_anterior = estado,
          estado = p_estado
   WHERE nro_cuenta = p_nro_cuenta;
EXCEPTION 
    WHEN OTHERS THEN 
        IF sqlcode = -54 THEN 
            raise_application_error(-20000, 'Reg. de prestamo '||p_nro_cuenta||' bloqueado por otro usuario'); 
        ELSIF sqlcode <= -20000 THEN 
            RAISE; 
        ELSE 
            RAISE_APPLICATION_ERROR(-20005, 'Error al actualizar PR_CTA_PRESTAMOS cta '|| p_nro_cuenta || ' - ' || SQLERRM); 
        END IF; 
END;
/* Obtener saldos capital e interes de un prestamo. */
PROCEDURE PR_OBT_CAP_INT_PRES
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_SAL_CAPITAL IN OUT PR_CUOTAS.SAL_CAPITAL%TYPE
 ,P_SAL_INTERES IN OUT PR_CUOTAS.SAL_INTERES%TYPE
 ,P_SAL_X IN OUT PR_CUOTAS.SAL_CAPITAL%TYPE
 )
 IS
BEGIN
   SELECT SUM(NVL(sal_capital,0)), SUM(NVL(sal_interes,0) + NVL(sal_int_documentado,0))
     INTO p_sal_capital, p_sal_interes
     FROM pr_cuotas
    WHERE nro_cuenta = p_nro_cuenta
      AND nro_cuota > 0
      AND estado NOT IN ('N','X');
   --
   SELECT SUM(NVL(sal_interes,0) + NVL(sal_int_documentado,0))
     INTO p_sal_x
     FROM pr_cuotas
    WHERE nro_cuenta = p_nro_cuenta
      AND nro_cuota > 0
      AND estado = 'X';
--
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
        RAISE_APPLICATION_ERROR('-20021', 'NO pudo obtener capital PR_CUOTAS '||
                                'p/el prestamo '||p_nro_cuenta);
      end if;
END;
/* Cambio de Situacion */
PROCEDURE PR_CAM_SITUACION (
    P_COD_MODULO    IN PR_CTA_PRESTAMOS.COD_MODULO%TYPE,
    P_COD_MODALIDAD IN PR_CTA_PRESTAMOS.COD_MODALIDAD%TYPE,
    P_COD_OFICINA   IN PR_CTA_PRESTAMOS.COD_OFICINA%TYPE,
    P_NRO_CUENTA    IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
    P_CATEGORIA     IN GE_CLIENTES.CAT_AUTOMATICA%TYPE,
    P_FECHA         IN GE_MOVIMIENTOS.FECHA%TYPE,
    P_HORA          IN OUT GE_MOVIMIENTOS.HORA%TYPE,
    P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
) IS 
    v_fec_calculo DATE := P_FECHA;
    v_dias        NUMBER;
    
BEGIN 
    -- Carga de datos del préstamo una sola vez
    wlugar := 'pap_pre.pr_obt_dat_prestamo';
    PAP_PRE.PR_OBT_DAT_PRESTAMO(P_NRO_CUENTA, rv_pres);   
 
       --- Inicializacion  de variables ---
    v_secuencia     := NVL(p_nro_secuencia,0);
    v_horamovim     := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));
    v_cod_modulo    := P_COD_MODULO;
    v_cod_modalidad := P_COD_MODALIDAD;
    v_cod_oficina   := P_COD_OFICINA;
    v_nro_cuenta    := P_NRO_CUENTA;
    v_categoria     := P_CATEGORIA;
    v_adevengar     := rv_pres.val_int_devengar;

    -- Cálculo de días de atraso
    wlugar := 'pap_dev.fu_obt_vto_sin_pago';
    v_dias := v_fec_calculo - PAP_DEV.FU_OBT_VTO_SIN_PAGO(P_NRO_CUENTA);

 --2= Brios, 3=Atlas
   IF FUG_OBT_TIP_IMPLEMENTACION = 3 then
      IF rv_pres.cod_modalidad in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
        FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6)) then
         if v_dias < 31 THEN
            IF rv_pres.cod_modalidad = FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6) then
               v_estado_cta := 'C';
            else
               v_estado_cta := 'V';
            end if;
         elsif v_dias > 30 and v_dias < 91 then
            v_estado_cta := 'V';
         elsif v_dias > 90 and v_dias < 181 then
            v_estado_cta := 'G';
         elsif v_dias > 180 and rv_pres.estado != 'I' then
            v_estado_cta := 'M';
         elsif rv_pres.estado = 'I' Then
            v_estado_cta := 'I';
         end if;
      ELSE --otras modalidades
         IF v_dias < 61 THEN
            v_estado_cta := 'C';
         ELSIF v_dias > 60 and v_dias < 91 THEN
            v_estado_cta := 'V';
         ELSIF v_dias > 90 and v_dias < 181 THEN
            v_estado_cta := 'G';
         elsif v_dias > 180 and rv_pres.estado != 'I' then
            v_estado_cta := 'M';
         elsif rv_pres.estado = 'I' Then
            v_estado_cta := 'I';
         END IF;
      END IF;--modalidades
   ELSE  --otras implementaciones
      IF v_dias <= 60 THEN
         v_estado_cta := 'C';
      ELSIF v_dias >= 61 and v_dias <= 90 THEN
         v_estado_cta := 'V';
      ELSIF v_dias >= 91 and v_dias <= 180 THEN
         v_estado_cta := 'G';
      ELSIF v_dias >= 181 and rv_pres.estado != 'I' then
         v_estado_cta := 'M';
      elsif rv_pres.estado = 'I' Then
         v_estado_cta := 'I';
      end if;
   END IF; --implementacion
    
    -- Ejecución Condicional: Solo si hay cambio de estado
    IF v_estado_cta <> rv_pres.estado THEN
        -- Preparación de datos para movimientos
        v_fcdehoy    := pag_cal.FU_OBT_FEC_ACTUAL(6);
        v_mone_local := PAG_GEN.FU_OBT_MON_LOCAL;
        
        IF rv_pres.cod_moneda <> v_mone_local THEN
            v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(rv_pres.cod_moneda, v_fcdehoy);
        ELSE
            v_cotizacion := NULL;
        END IF;

        wlugar := 'pr_pro_cam_est_prest';
        PR_PRO_CAM_EST_PREST;        
            
    END IF;
	
	 -- Retorno de valores actualizados tras el movimiento
        P_NRO_SECUENCIA := v_secuencia;
        P_HORA     		:= v_horamovim;

EXCEPTION 
    WHEN OTHERS THEN 
        IF sqlcode <= -20000 THEN 
            RAISE; 
        ELSE 
            RAISE_APPLICATION_ERROR(-20001, 'Error en PR_CAM_SITUACION - ' || wlugar || ': ' || SQLERRM); 
        END IF; 
END;
/* Realizar asientos contables por el cambio de estado del prestamo. */
PROCEDURE PR_INS_ASIE_CAMES
 (P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_ESTADO IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 )
 IS
r_mvto ge_movimientos%rowtype;
v_redondeo number(5);
BEGIN

   if v_secuencia + 3 > 999 then
      v_secuencia := 0;
      v_horamovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_horamovim);
    ELSE
      v_secuencia := v_secuencia + 1;
   end if;
    r_mvto.nro_secuencia   := v_secuencia;
    r_mvto.cod_usuario     := upper(user);
    r_mvto.hora            := v_horamovim;
    r_mvto.cod_modulo      := v_cod_modulo;   --definir hijo
    r_mvto.cod_modalidad   := v_cod_modalidad;  --definir hijo
    r_mvto.cod_oficina     := v_cod_oficina;
    r_mvto.nro_cuenta      := v_nro_cuenta;
    If p_cod_transaccion in (927, 928) then -- Valuaciones.
       r_mvto.cod_moneda := V_MONE_LOCAL;
    Else
       r_mvto.cod_moneda := rv_pres.cod_moneda;
    End if;
    r_mvto.cod_tra_padre   := p_cod_tra_padre;
    r_mvto.cod_transaccion := p_cod_transaccion;
    r_mvto.fecha           := v_fcdehoy;
    r_mvto.fec_valor       := v_fcdehoy;
    r_mvto.nro_documento   := NULL;
    r_mvto.monto           := p_monto;
    r_mvto.estado          := 'N';
    r_mvto.est_cuenta      := p_estado;
    r_mvto.cod_ofi_origen  := v_cod_oficina;
    r_mvto.concepto        := p_concepto;
    r_mvto.reversado       := 'N';
    r_mvto.emi_aviso       := 'N';
    r_mvto.protegido       := 'N';
    r_mvto.cod_mod_padre   := v_cod_modulo;
    r_mvto.cod_mad_padre   := v_cod_modalidad;
    IF r_mvto.cod_moneda = v_mone_local THEN --es moneda local
        r_mvto.mto_equ_local := NULL;
        r_mvto.cotizacion    := NULL;
    ELSE --es moneda extranjera debe redondear a los decimales de la moneda local
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo,v_cod_modalidad,v_mone_local);
        r_mvto.mto_equ_local := ROUND(p_monto*v_cotizacion,v_redondeo);
        r_mvto.cotizacion    := v_cotizacion;
    END IF;
    pag_gen.pr_ins_ge_movimiento(r_mvto);
EXCEPTION
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
        raise_application_error(-20000,SQLERRM||' Al insertar mvto. Cambio Situacion Prestamo '||v_nro_cuenta);
      end if;
END;
/* Permite obtener los datos de la cuenta de prestamos no cancelada. */
PROCEDURE PR_OBT_DAT_PRE_NOCAN
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PCPRE IN OUT PR_CTA_PRESTAMOS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_pcpre
     from pr_cta_prestamos
    where nro_cuenta = p_nro_cuenta
    and estado <> 'N';
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuenta de prestamo '||p_nro_cuenta||' No Registrada o Cancelada');
END;
/* Proceso de cambio de estado de prestamos. */
PROCEDURE PR_PRO_CAM_EST_PREST
 IS

v_mto_ori_fondo pr_Cta_prestamos.mto_capital%type;
v_redondeo number;
v_mto_cap_original number;
v_ori_fon_propio pr_cta_prestamos.cod_ori_fondo%type;
v_cod_tra_fon_prop ge_transacciones.cod_transaccion%type;
v_cod_tra_fon_otro ge_transacciones.cod_transaccion%type;


/* Verificar si el prestamo es documentado. */
PROCEDURE LP_VER_PRES_DOCUMEN
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 );
v_mto_prevision ge_movimientos.monto%type;
v_mto_valuacion ge_movimientos.monto%type;

/* Verificar si el prestamo es documentado. */
PROCEDURE LP_VER_PRES_DOCUMEN
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 IS
BEGIN
   SELECT decode(nvl(mto_interes,0),0,'N','S')
     INTO v_docu
     FROM pr_cuotas
    WHERE nro_cuenta = p_nro_cuenta
      AND nro_cuota = 0;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
     v_docu:='N';
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20019,SQLERRM||'En verificar si es documentado');
      end if;
END;

BEGIN
   v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,rv_pres.cod_modalidad, rv_pres.cod_moneda);
   v_cod_tra_pad  := 945;
   v_importe      := 0;
   v_sal_intautor := 0;
   PR_OBT_CAP_INT_PRES(v_nro_cuenta,v_sal_cap,v_sal_int,v_sal_intautor); --(sal_int+sal_int_documentado de cuotas)
   IF NVL(rv_pres.dev_no_cobrado,0) > 0 THEN
      rv_pres.dev_no_cobrado := NVL(rv_pres.dev_no_cobrado,0) - NVL(v_sal_intautor,0);
   END IF;
   IF NVL(v_adevengar,0) > 0 THEN
      v_adevengar := NVL(v_adevengar,0) - NVL(v_sal_intautor,0);
   END IF;

   PR_ACT_EST_CUOTAS(v_nro_cuenta, v_estado_cta);--actualiza estado de cuotas
   PR_ACT_EST_PRESTAMO(v_nro_cuenta, v_estado_cta);--actualiza estado de prestamo
   LP_VER_PRES_DOCUMEN(v_nro_cuenta);  /* verifica si el prestamo es doc. o no*/

   --x saldo capital solamente -> determinar el % de origen de fondos para la contabilización
   IF NVL(v_sal_cap,0) > 0 THEN
      v_ori_fon_propio := fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,rv_pres.cod_moneda,null,null);
      if rv_pres.cod_ori_fondo = v_ori_fon_propio then
         --es fondos propios tomar el 100%
         v_mto_cap_original := v_sal_cap; -- todo el capital con fondos propios
      else
         if rv_pres.por_ori_fondo > 0 and rv_pres.por_ori_fondo <= 100 then
            v_mto_ori_fondo := round(v_sal_cap * rv_pres.por_ori_fondo / 100,v_redondeo); --sólo el porcentaje
            v_mto_cap_original := v_sal_cap - v_mto_ori_fondo;
         else
            v_mto_cap_original := v_sal_cap; -- todo el capital con fondos propios
         end if;
      end if;

      IF v_mto_cap_original > 0 THEN --fondos propios
        PRP_OBT_TRANSACCION('CA', rv_pres.estado, rv_pres.tipo, rv_pres.tip_interes, rv_pres.nro_cuenta, v_ori_fon_propio, v_estado_cta, 'E',
                            v_cod_tra_fon_prop, v_concepto);
      end if;
      IF v_mto_ori_fondo > 0 THEN -- x el origen de fondos específico
        PRP_OBT_TRANSACCION('CA', rv_pres.estado, rv_pres.tipo, rv_pres.tip_interes, rv_pres.nro_cuenta, rv_pres.cod_ori_fondo, v_estado_cta, 'E',
                            v_cod_tra_fon_otro, v_concepto);
      end if;

      --si va hacia adelante en los estados, empeora el estado
      IF (rv_pres.estado IN ('C','A')  AND v_estado_cta IN ('V','G','M','I'))  -- de VIGENTE A VENCIDA O EN GESTION O MOROSA
       or (rv_pres.estado = 'V' AND  v_estado_cta = 'G')        -- de VENCIDA a EN GESTION
       or (rv_pres.estado = 'V' AND  v_estado_cta IN ('M','I'))   -- de VENCIDA a MOROSA
       or (rv_pres.estado = 'G' AND  v_estado_cta IN ('M','I')) THEN -- de EN GESTION A MOROSA

          IF v_mto_cap_original > 0 THEN   --fondos propios
             --generar movimiento
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_fon_prop, v_mto_cap_original, v_concepto, v_estado_cta);
          end if;
          IF v_mto_ori_fondo > 0 THEN   -- x el origen de fondos específico
             --generar movimiento
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_fon_otro, v_mto_ori_fondo, v_concepto, v_estado_cta);
          end if;
      end if;

      -- si hay traslado para atrás, mejora el estado
      IF (rv_pres.estado IN ('V','G','M','I') AND v_estado_cta IN ('A','C')) -- de VENCIDA O GESTION O MOROSA a CARTERA VIGENTE
       or (rv_pres.estado = 'G' AND  v_estado_cta = 'V')     -- de GESTION A VENCIDA
       or (rv_pres.estado IN ('M','I') AND v_estado_cta = 'V')  -- de MOROSA A VENCIDA
       or (rv_pres.estado IN ('M','I') AND v_estado_cta = 'G') THEN -- de MOROSA A GESTION

          IF v_mto_cap_original > 0 THEN   --fondos propios
             --generar movimiento en negativo
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_fon_prop, v_mto_cap_original * -1, v_concepto, v_estado_cta);
          end if;
          IF v_mto_ori_fondo > 0 THEN   -- x el origen de fondos específico
             --generar movimiento en negativo
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_fon_otro, v_mto_ori_fondo * -1, v_concepto, v_estado_cta);
          end if;
      end if;
   END IF;

   IF rv_pres.estado IN ('C','A')  AND v_estado_cta IN ('V','G','M','I') THEN
      
      v_cod_tra_hij := 921;
      v_concepto    := 'REV.PR.FIN.DOC.VIGENTE-PF/AM';
      v_mto_trans   := NVL(v_sal_int,0);
      IF NVL(v_sal_int,0) > 0 THEN
         PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
         IF v_estado_cta = 'V' THEN
             v_cod_tra_hij := 925;
             v_concepto    := 'TRANSF.PR.FIN.VIG A VENC.-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_concepto    := 'TRANSF.PR.FIN.ADEV.VIG A VENC-AM';
                v_cod_tra_hij := 905;
                v_mto_trans   := NVL(v_adevengar,0);
                --x int a devengar (- sal_intautor)
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 906;
             END IF;
         ELSIF v_estado_cta = 'G' THEN
             v_cod_tra_hij := 924;
             v_concepto    := 'TRANSF.PR.FIN.VIG A GEST.-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_concepto    := 'TRANSF.PR.FIN.ADEV.VIG A GEST-AM';
                v_cod_tra_hij := 905;
                v_mto_trans   := NVL(v_adevengar,0);
                --x int a devengar (- sal_intautor)
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 909;
             END IF;
         ELSIF v_estado_cta IN ('M','I') THEN
             v_cod_tra_hij := 922;
             v_concepto    := 'TRANSF.PR.FIN.VIG A MORO.-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_concepto    := 'TRANSF.PR.FIN.ADEV.VIG A MORO.-AM';
                v_cod_tra_hij := 905;
                v_mto_trans   := NVL(v_adevengar,0);
                --x int a devengar (- sal_intautor)
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 910;
             END IF;
         END IF;
         PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
      END IF;
   END IF;
   IF rv_pres.estado = 'V' AND  v_estado_cta = 'G' THEN       -- De VENCIDA a EN GESTION
     
      /* Asiento por el Devengado No Cobrado, Saldo del Interes  */
      IF NVL(v_sal_int,0) > 0 THEN
          v_cod_tra_hij := 925;
          --x saldo interes
          v_mto_trans   := nvl(v_sal_int,0) * -1;
          v_concepto    := 'REV.PR.FIN. DE VENCIDA-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 924;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.VENC.A GESTION-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0 THEN
             v_cod_tra_hij := 906;
             v_mto_trans   := nvl(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.Adevengar VENCIDO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 909;
             v_mto_trans   := nvl(v_adevengar,0);
             v_concepto    := 'TRANSF.PR.FIN.ADEV.EN GESTION-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          END IF;
      END IF;
   END IF;
   IF rv_pres.estado = 'V' AND  v_estado_cta IN ('M','I') THEN  -- De VENCIDA a MOROSA
     
      /* Asiento por el Devengado No Cobrado, Saldo del Interes */
      IF NVL(v_sal_int,0) > 0 THEN
          v_cod_tra_hij := 925;
          --x saldo interes
          v_mto_trans   := nvl(v_sal_int,0) * -1;
          v_concepto    := 'REV.PR.FIN.VENCIDO-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 922;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.VENC.A MORO-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0  THEN
             v_cod_tra_hij := 906;
             v_mto_trans   := nvl(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.ADEVENGAR VENCIDO-AM'; 
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 910;
             v_mto_trans   := nvl(v_adevengar,0);
             v_concepto    := 'TRANSF.PR.FIN.ADEV.EN MOROSO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
         END IF;
      END IF;
   END IF;
   IF rv_pres.estado = 'G' AND  v_estado_cta IN ('M','I') THEN -- De EN GESTION A MOROSA
   
      /* Asiento por el Devengado No Cobrado, Saldo del Interes */
      IF NVL(v_sal_int,0) > 0 THEN
          v_cod_tra_hij := 924;
          v_mto_trans   := nvl(v_sal_int,0) * -1;
          v_concepto    := 'REV.PR.FIN.EN GESTION-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 922;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.GEST.A MOROSO-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0 THEN
             v_cod_tra_hij := 909;
             v_mto_trans   := nvl(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.ADEVENGAR GESTION-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 910;
             v_mto_trans   := nvl(v_adevengar,0);
             v_concepto    := 'TRANSF.PR.FIN.ADEV.EN MOROSO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          END IF;
      END IF;
   END IF;

   /* esto solo se hace si hay traslado para atras */
   IF rv_pres.estado IN ('V','G','M','I') AND v_estado_cta IN ('A','C') THEN   
      v_cod_tra_hij := 921;
      v_concepto    := 'TRANSF.PR.FIN.DOC.A VIGENTE-PF/AM';
      v_mto_trans   := NVL(v_sal_int,0) * -1;
      IF NVL(v_sal_int,0) > 0 THEN
         PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
         IF rv_pres.estado = 'V' THEN
             v_cod_tra_hij := 925;
             v_concepto    := 'REV.PR.FIN.DOC.VENCIDA A VIG-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
               PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
               v_cod_tra_hij := 906;
               v_mto_trans   := NVL(v_adevengar,0) * -1;
               v_concepto    := 'REV.PR.FIN.DOC.ADEV.VENC.A VIG-AM';
               PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
               v_cod_tra_hij := 905;
               v_concepto    := 'TRANSF.PR.FIN.NDOC.ADEV.VENC.A VIG';
             END IF;
         ELSIF rv_pres.estado  = 'G' THEN
             v_cod_tra_hij := 924;
             v_concepto    := 'REV.PR.FIN.DOC.GEST-VIGENTE-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 909;
                v_mto_trans   := NVL(v_adevengar,0) * -1;
                v_concepto    := 'REV.PR.FIN.DOC.ADEV.VENC.A VIG-AM';
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 905;
                v_concepto    := 'TRANSF.PR.FIN.NDOC.ADEV.VENC.A VIG';
             END IF;
         ELSIF rv_pres.estado IN ('M','I') THEN
             v_cod_tra_hij := 922;
             v_concepto    := 'REV.PR.FIN.DOC.MORO-VIGENTE-PF/AM';
             IF NVL(v_adevengar,0) > 0 THEN
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 910;
                v_mto_trans := NVL(v_adevengar,0) * -1;
                v_concepto  := 'REV.PRFIN.DOC.ADEV.MORO-VIGENT-AM';
                PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
                v_cod_tra_hij := 905;
                v_concepto    := 'TRANSF.PR.FIN.NDOC.ADEV.MORO.A VIG';
             END IF;
        END IF;
        PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
      END IF;
   END IF;
   IF rv_pres.estado = 'G' AND  v_estado_cta = 'V' THEN -- De GESTION A VENCIDA
     
      /* Asiento por el Saldo del Interes y Adevengar */
      IF NVL(v_sal_int,0) > 0 THEN
          v_mto_trans   := nvl(v_sal_int,0) *  -1;
          v_cod_tra_hij := 924;
          v_concepto    := 'REV.PR.FIN.DOC. GESTION-PF/AM';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 925;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.DOC.GEST.A VENC-AM/PF';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0 THEN
             v_cod_tra_hij := 909;
             v_mto_trans   := NVL(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.DOC.ADEV.DE GEST-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 906;
             v_mto_trans   := NVL(v_adevengar,0);
             v_concepto    := 'TRANS.PR.FIN.DOC.ADEV.GEST.A VENC.';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          END IF;
      END IF;
   END IF;
   IF rv_pres.estado IN ('M','I') AND v_estado_cta = 'V' THEN  -- De MOROSA A VENCIDA
   
      /* Asiento por el Devengado No Cobrado(NDoc) y el Saldo del Interes  */
      IF NVL(v_sal_int,0) > 0 THEN
          v_cod_tra_hij := 922;
          v_mto_trans   := NVL(v_sal_int,0) * -1;
          v_concepto    := 'REV.PR.FIN. MOROSOS-AM/PF';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 925;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.DOC.VENCIDO-AM/PF';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0  THEN
             v_cod_tra_hij := 910;
             v_mto_trans   := NVL(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.ADEV.MOROSO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 906;
             v_mto_trans   := NVL(v_adevengar,0);
             v_concepto    := 'REV.PR.FIN.ADEV.EN VENCIDO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          END IF;
      END IF;
   END IF;
   IF rv_pres.estado IN ('M','I') AND v_estado_cta = 'G' THEN -- De MOROSA A GESTION
    
      /* Asiento por el Saldo Interes y el Adevengar */
      IF NVL(v_sal_int,0) > 0 THEN
          v_cod_tra_hij := 922;
          v_mto_trans   := NVL(v_sal_int,0) * -1;
          v_concepto    := 'REV.PR.FIN.DOC. EN MOROSO-AM/PF';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          v_cod_tra_hij := 924;
          v_mto_trans   := nvl(v_sal_int,0);
          v_concepto    := 'TRANSF.PR.FIN.DOC.MOROSO A GESTION';
          PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          IF NVL(v_adevengar,0) > 0  THEN
             v_cod_tra_hij := 910;
             v_mto_trans   := NVL(v_adevengar,0) * -1;
             v_concepto    := 'REV.PR.FIN.DOC.ADEV.EN MOROSO-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
             v_cod_tra_hij := 909;
             v_mto_trans   := NVL(v_adevengar,0);
             v_concepto    := 'TRANSF.PR.FIN.DOC.ADEV.EN GEST.-AM';
             PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
          END IF;
      END IF;
   END IF;

   -- GENERA ASIENTO X DEV_SUSPENSO x estado anterior y nuevo
   IF NVL(rv_pres.dev_suspenso,0) > 0 THEN
      v_trans := 943;
      v_mto_trans := rv_pres.dev_suspenso;
      v_concepto:='TRANSF. DEV. EN SUSPENSO EST.ANT';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, rv_pres.estado);
      v_trans := 947;
      v_mto_trans := rv_pres.dev_suspenso;
      v_concepto:='TRANSFERENCIA DEV. SUSPENSO';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
      IF  (v_estado_cta IN ('A','C') AND v_categoria IN (1,2))
      AND rv_pres.estado not in ('A','C') THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
         --- Pasa a no cobrado lo que esta en suspenso
         --- Actualizar pr_cta_prestamos
         update pr_cta_prestamos
            set dev_no_cobrado = nvl(dev_no_cobrado,0) + nvl(dev_suspenso,0),
                dev_suspenso = 0
          where nro_cuenta = v_nro_cuenta
            and nvl(dev_suspenso,0) > 0;
         --- Actualizar pr_cuotas
         update pr_cuotas
            set dev_no_cobrado = nvl(dev_no_cobrado,0) + nvl(dev_suspenso,0),
                dev_suspenso = 0
          where nro_cuenta = v_nro_cuenta
            and nvl(dev_suspenso,0) > 0
            and (estado <> 'N'
                or estado = 'N' and fec_ult_pago = v_fcdehoy);
         --- Generar asientos contables por el devengado en suspenso
         --- Reconocimiento de utilidad
         v_trans := 901;
         v_mto_trans := rv_pres.dev_suspenso;
         v_concepto:='EXTORNO DE SUSPENSO';
         PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
         v_trans := 948;
         v_mto_trans := rv_pres.dev_suspenso;
         v_concepto:='EXTORNO DE SUSPENSO';
         PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
      END IF;
   END IF;
   -- GENERA ASIENTO X PREVISION --ojo verif si en el cierre se corre primero la categorizacion y
   -- despues el cambio de estado o sino no va a encontrar datos
   -- x estado anterior y nuevo
   v_mto_prevision := FU_OBT_PREVISION(rv_pres.nro_cuenta);
   IF nvl(v_mto_prevision,0) > 0 then
      v_mto_trans := v_mto_prevision;
      v_trans := 944;
      v_concepto:='TRANSF. PREVISION EST.ANT';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, rv_pres.estado);
      v_trans := 946;
      v_concepto:='TRANSFERENCIA DE PREVISION';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   -- GENERA ASIENTO X VALUACION --
   v_mto_valuacion := FU_OBT_VALUACION(rv_pres.nro_cuenta);
   IF nvl(v_mto_valuacion,0) > 0 then
      v_mto_trans := v_mto_valuacion;
      v_trans := 927;
      v_concepto:='TRANSF. VALUACION EST.ANT';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, rv_pres.estado);
      v_trans := 928;
      v_concepto:='TRANSFERENCIA DE VALUACION';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   v_trans := CASE v_estado_cta
               WHEN 'C' THEN 432
               WHEN 'A' THEN 435
               WHEN 'V' THEN 433
               WHEN 'G' THEN 434
               WHEN 'M' THEN 436
               WHEN 'I' THEN 436               
           END;   
   --- genera cambio de estado de prestamos ---------
   PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, null, null, v_estado_cta);
END;

/* Actualizar el estado de las cuotas del prestamo. */
PROCEDURE PR_ACT_EST_CUOTAS
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
  P_ESTADO     IN PR_CTA_PRESTAMOS.ESTADO%TYPE
 )
 IS

CURSOR CUO IS
   SELECT *
     FROM pr_cuotas
    WHERE nro_cuenta = p_nro_cuenta
      AND estado     NOT IN ('N', 'X')
      AND nro_cuota  > 0
      FOR UPDATE NOWAIT;

BEGIN
    FOR reg IN cuo LOOP
        -- 1. Insertar en histórico solo si el estado es 'I'
        IF p_estado = 'I' THEN
            INSERT INTO pr_cuotas_his (
                nro_cuenta, nro_cuota, mto_capital, fec_vencimiento, 
                mto_interes, estado, sal_capital, sal_interes, 
                prioridad, fec_ult_pago, val_recargo, mto_int_documentado, 
                nro_documento, sal_int_documentado, dev_no_cobrado, 
                dev_suspenso, dev_acumulado, mto_int_descontado, mto_cap_adelantado
            ) VALUES (
                reg.nro_cuenta, reg.nro_cuota, reg.mto_capital, reg.fec_vencimiento, 
                reg.mto_interes, p_estado, reg.sal_capital, reg.sal_interes, 
                reg.prioridad, reg.fec_ult_pago, reg.val_recargo, reg.mto_int_documentado, 
                reg.nro_documento, reg.sal_int_documentado, reg.dev_no_cobrado, 
                reg.dev_suspenso, reg.dev_acumulado, reg.mto_int_descontado, reg.mto_cap_adelantado
            );
        END IF;

        -- 2. Update único con lógica condicional
        UPDATE pr_cuotas
        SET estado         = p_estado,
            sal_interes    = CASE WHEN p_estado = 'I' THEN dev_no_cobrado ELSE sal_interes END,
            dev_no_cobrado = CASE WHEN p_estado = 'I' THEN 0 ELSE dev_no_cobrado END,
            dev_suspenso   = CASE WHEN p_estado = 'I' THEN 0 ELSE dev_suspenso END
        WHERE CURRENT OF cuo;

    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -54 THEN
            RAISE_APPLICATION_ERROR(-20000, 'Reg. de cuotas '||p_nro_cuenta||' bloqueado por otro usuario');
        ELSIF SQLCODE <= -20000 THEN
            RAISE;
        ELSE

            RAISE_APPLICATION_ERROR(-20005, 'Actu. CUOTAS p/prest '||p_nro_cuenta||' - '||SQLERRM);
        END IF;
END;
/* Recupera monto prevision de ge_cla_operaciones. */
FUNCTION FU_OBT_PREVISION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_prevision ge_cla_operaciones.tot_prevision%type;
begin
   select nvl(sum(nvl(monto,0)),0)
     into v_prevision
     from pr_previsiones
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from pr_previsiones
                    where nro_cuenta = p_nro_cuenta
                      and fecha <= v_fcdehoy);
   return v_prevision;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Recup. Prevision - Cta: '||p_nro_cuenta);
      end if;
end;
/* Recupera monto valuacion de pr_valuaciones. */
FUNCTION FU_OBT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_valuacion pr_valuaciones.tot_val_capital%type;
begin
   select nvl(sum((nvl(tot_val_capital,0)+
                  nvl(tot_val_interes,0)+
                  nvl(tot_val_int_ade,0)) -
                  nvl(tot_val_prevision,0)-
                  nvl(tot_val_suspenso,0)-
                  nvl(tot_val_int_devengar,0)
                  ),0)
     into v_valuacion
     from pr_valuaciones
    where nro_cuenta = p_nro_cuenta
      and fecha = (Select max(fecha)
                     from pr_valuaciones
                    where nro_cuenta = p_nro_cuenta);
   return v_valuacion;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Recup. Valuacion - Cta: '||p_nro_cuenta);
      end if;
end;
END PAP_MES;

