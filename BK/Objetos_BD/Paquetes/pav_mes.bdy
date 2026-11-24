CREATE OR REPLACE PACKAGE BODY IT.PAV_MES IS

/* Actualizar el estado de un operación vencida. */
PROCEDURE PR_ACT_EST_OPE_VENCIDA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_ESTADO IN OV_CTA_VENCIDAS.ESTADO%TYPE
 )
 IS
v_existe number(01);
BEGIN
   select 1 into v_existe
   from  OV_CTA_VENCIDAS
   where nro_cuenta = p_nro_cuenta
   for update nowait;

   update OV_CTA_VENCIDAS
   set    est_anterior = estado,
          estado = p_estado
   WHERE nro_cuenta = p_nro_cuenta;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode = -54 then
         raise_application_error(-20000,'Reg. de operación vencida '||p_nro_cuenta||' bloqueado por otro usuario');
      elsif sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR('-20005', 'Actu. OV_CTA_VENCIDAS cta '|| p_nro_cuenta );
      end if;
END;
/* Cambio de Situacion */
PROCEDURE PR_CAM_SITUACION
 (P_COD_MODULO IN OV_CTA_VENCIDAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN OV_CTA_VENCIDAS.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN OV_CTA_VENCIDAS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_CATEGORIA  IN GE_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN OUT GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 )
 IS
BEGIN
   --- Inicializacion  de variables ---
   v_secuencia     := NVL(p_nro_secuencia,0);
   v_fcdehoy       := p_fecha;
   v_horamovim     := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));
   v_cod_modulo    := p_cod_modulo;
   v_cod_modalidad := p_cod_modalidad;
   v_cod_oficina   := p_cod_oficina;
   v_nro_cuenta    := p_nro_cuenta;
   v_categoria     := p_categoria;
   v_estado_cta    := 'X';

   wlugar:= 'pag_gen.fu_obt_mon_local';
   v_mone_local:= PAG_GEN.FU_OBT_MON_LOCAL;
   wlugar:= 'PAV_OVE.PR_OBT_DAT_OPE_VENCIDA';
   PAV_OVE.PR_OBT_DAT_OPE_VENCIDA(v_nro_cuenta, rv_venc);
   v_fcvenci := rv_venc.fec_apertura;
   IF rv_venc.cod_moneda <> v_mone_local THEN
      wlugar:= 'pag_gen.fu_obt_cotizacion';
      v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(rv_venc.cod_moneda,v_fcdehoy);
   ELSE
      v_cotizacion := null;
   END IF;
   ---v_dias := v_fcdehoy - v_fcvenci;
   v_dias := v_fcdehoy - v_fcvenci + nvl(rv_venc.dia_atr_inicial,0);
   IF v_dias <= 60 THEN
     IF v_cod_modulo = 15 AND v_cod_modalidad in (151,153) THEN
      v_estado_cta := 'N';
     ELSE 
      v_estado_cta := 'V';--'N'; ---DYDMR-4007 NA 03/06/2016
     END IF; 
   ELSIF v_dias >= 61 and v_dias <= 90 THEN
      v_estado_cta := 'V';
   ELSIF v_dias >= 91 and v_dias <= 180 THEN
      v_estado_cta := 'G';
   ELSIF v_dias >= 181 and rv_venc.estado != 'I' then
      v_estado_cta := 'M';
   elsif rv_venc.estado = 'I' Then
      v_estado_cta := 'I';
   end if;
   IF v_estado_cta <>  rv_venc.estado THEN
      wlugar:= 'pr_pro_cam_est_prest';
      PR_PRO_CAM_EST_PREST;
   END IF;
   p_nro_secuencia := v_secuencia;
   p_hora          := v_horamovim;

EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20001,SQLERRM||' '||wlugar);
      end if;
END;
/* Realizar asientos contables por el cambio de estado del operación vencida. */
PROCEDURE PR_INS_ASIE_CAMES
 (P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_ESTADO IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 )
 IS
r_mvto ge_movimientos%rowtype;
BEGIN

   if v_secuencia + 3 > 999 then
      v_secuencia := 0;
      v_horamovim := fug_obt_hor_disponible(v_fcdehoy,v_horamovim,user,'N');
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
       r_mvto.cod_moneda := rv_venc.cod_moneda;
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
    IF r_mvto.cod_moneda = v_mone_local THEN
        r_mvto.mto_equ_local := NULL;
        r_mvto.cotizacion    := NULL;
    ELSE
        r_mvto.mto_equ_local := ROUND(p_monto*v_cotizacion,0);
        r_mvto.cotizacion    := v_cotizacion;
    END IF;
    pag_gen.pr_ins_ge_movimiento(r_mvto);
EXCEPTION
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
        raise_application_error(-20000,SQLERRM||' Al insertar mvto. Cambio Situacion operación vencida '||v_nro_cuenta);
      end if;
END;
/* Permite obtener los datos de la cuenta de operación vencidas no cancelada. */
PROCEDURE PR_OBT_DAT_PRE_NOCAN
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_PCPRE IN OUT OV_CTA_VENCIDAS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_pcpre
     from OV_CTA_VENCIDAS
    where nro_cuenta = p_nro_cuenta
    and estado <> 'C';
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuenta de operación vencida '||p_nro_cuenta||' No Registrada o Cancelada');
END;
/* Proceso de cambio de estado de operación vencidas. */
PROCEDURE PR_PRO_CAM_EST_PREST
 IS

/* Verificar si el operación vencida es documentado. */
PROCEDURE LP_VER_PRES_DOCUMEN
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 );
v_mto_prevision ge_movimientos.monto%type;
v_mto_valuacion ge_movimientos.monto%type;

/* Verificar si el operación vencida es documentado. */
PROCEDURE LP_VER_PRES_DOCUMEN
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
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
   v_cod_tra_pad  := 945;
   v_importe      := 0;
   v_sal_capital  := rv_venc.sal_total;
   PR_ACT_EST_OPE_VENCIDA(v_nro_cuenta, v_estado_cta);--actualiza estado de operación vencida
   LP_VER_PRES_DOCUMEN(v_nro_cuenta);  /* verifica si el operación vencida es doc. o no*/
/*   IF rv_venc.estado IN ('C','A')  AND v_estado_cta IN ('V','G','M','I') THEN
      -- transf. de VIGENTE A VENCIDA O GESTION O MOROSA ---
      -- x saldo
      v_mto_trans := v_sal_capital;
      IF v_estado_cta = 'V' THEN
         v_cod_tra_hij := 920;
         v_concepto    := 'TRANSF.SAL.VIG.A VENC-PF';
      ELSIF v_estado_cta = 'G' THEN
         v_cod_tra_hij := 933;
         v_concepto   := 'TRANSF.SAL.VIG.A GEST-PF';
      ELSIF v_estado_cta IN ('M','I') THEN
         v_cod_tra_hij := 936;
         v_concepto    := 'TRANSF.SAL.VIG.A MORO-PF';
      END IF;
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;*/
   ---DYDMR-4007
   IF rv_venc.estado = 'N' AND  v_estado_cta = 'V' THEN       -- De VIGENTE a EN GESTION
      v_cod_tra_hij := 920;
      v_mto_trans   := v_sal_capital;
      --x saldo total
      v_concepto    := 'TRANSF. SALDO VIG. A EN VEN.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado = 'N' AND  v_estado_cta = 'G' THEN       -- De VIGENTE a EN GESTION
      v_cod_tra_hij := 933;
      v_mto_trans   := v_sal_capital;
      --x saldo total
      v_concepto    := 'TRANSF. SALDO VIG. A EN GEST.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado = 'N' AND  v_estado_cta in ('M','I') THEN       -- De VIGENTE a EN MOROSA
      v_cod_tra_hij := 936;
      v_mto_trans   := v_sal_capital;
      --x saldo total
      v_concepto    := 'TRANSF. SALDO VIG. A EN MOROSA.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   ---
   IF rv_venc.estado = 'V' AND  v_estado_cta = 'G' THEN       -- De VENCIDA a EN GESTION
      v_cod_tra_hij := 926;
      v_mto_trans   := v_sal_capital;
      --x saldo total
      v_concepto    := 'TRANSF. SALDO VENC. A EN GEST.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado = 'V' AND  v_estado_cta IN ('M','I') THEN  -- De VENCIDA a MOROSA
      v_cod_tra_hij := 939;
      --x saldo total
      v_mto_trans   := v_sal_capital;
      v_concepto    := 'TRANSF. SALDO VENC. A MOROSA';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado = 'G' AND  v_estado_cta IN ('M','I') THEN -- De EN GESTION A MOROSA
      v_cod_tra_hij := 929;
      --x saldo total
      v_mto_trans   := v_sal_capital;
      v_concepto    := 'TRANSF. SALDO EN GEST. A MOROSA';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   /* esto solo se hace si hay traslado para atras */
/*   IF rv_venc.estado IN ('V','G','M','I') AND v_estado_cta IN ('A','C') THEN
      -- transf. de VENCIDA O GESTION O MOROSA a CARTERA VIGENTE ---
      -- el importe es negativo --- saldo total
      v_mto_trans := v_sal_capital * -1;
      IF rv_venc.estado = 'V' THEN
         v_cod_tra_hij := 920;
         v_concepto    := 'TRANSF.SAL.VENC.A VIG.-PF';
      ELSIF rv_venc.estado = 'G' THEN
         v_cod_tra_hij := 933;
         v_concepto    := 'TRANSF.SAL.GEST.A VIG.-PF';
      ELSIF rv_venc.estado IN ('M','I') THEN
         v_cod_tra_hij := 936;
         v_concepto    := 'TRANSF.SAL.MORO.A VIG.-PF';
      END IF;
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;*/
   
   IF rv_venc.estado = 'V' AND  v_estado_cta = 'N' THEN -- De VIGENTE A VENCIDA
      v_cod_tra_hij := 920;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE VENC A VIG.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado = 'G' AND  v_estado_cta = 'N' THEN -- De VIGENTE A GESTION
      v_cod_tra_hij := 933;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE GEST A VIG.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
     IF rv_venc.estado IN('M','I') AND  v_estado_cta = 'N' THEN -- De VIGENTE A MOROSA
      v_cod_tra_hij := 936;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE MOR A VIG.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   --
   IF rv_venc.estado = 'G' AND  v_estado_cta = 'V' THEN -- De GESTION A VENCIDA
      v_cod_tra_hij := 926;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE GEST A VENC.';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado IN ('M','I') AND v_estado_cta = 'V' THEN  -- De MOROSA A VENCIDA
      v_cod_tra_hij := 939;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE MOROSA A VENC';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   IF rv_venc.estado IN ('M','I') AND v_estado_cta = 'G' THEN -- De MOROSA A GESTION
      v_cod_tra_hij := 929;
      --x saldo total
      v_mto_trans   := v_sal_capital * -1;
      v_concepto    := 'TRANSF. SALDO DE MOROSA A GESTION';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   -- GENERA ASIENTO X PREVISION --ojo verif si en el cierre se corre primero la categorizacion y
   -- despues el cambio de estado o sino no va a encontrar datos
   -- x estado anterior y nuevo
   v_mto_prevision := FU_OBT_PREVISION(rv_venc.nro_cuenta);
   IF nvl(v_mto_prevision,0) > 0 then
      v_mto_trans := v_mto_prevision;
      v_trans := 944;
      v_concepto:='TRANSF. PREVISION EST.ANT';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, rv_venc.estado);
      v_trans := 946;
      v_concepto:='TRANSFERENCIA DE PREVISION';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
   -- GENERA ASIENTO X VALUACION --
   v_mto_valuacion := FU_OBT_VALUACION(rv_venc.nro_cuenta);
   IF nvl(v_mto_valuacion,0) > 0 then
      v_mto_trans := v_mto_valuacion;
      v_trans := 927;
      v_concepto:='TRANSF. VALUACION EST.ANT';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, rv_venc.estado);
      v_trans := 928;
      v_concepto:='TRANSFERENCIA DE VALUACION';
      PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_estado_cta);
   END IF;
/*   IF v_estado_cta = 'C' THEN
      v_trans := 432;
   ELSIF v_estado_cta = 'A' THEN
      v_trans := 435;
   ELS*/
   IF v_estado_cta = 'N' THEN
      v_trans := 435;
   ELSIF v_estado_cta = 'V' THEN
      v_trans := 433;
   ELSIF v_estado_cta = 'G' THEN
      v_trans := 434;
   ELSIF v_estado_cta IN ('M','I') THEN
      v_trans := 436;
   END IF;
   --- genera cambio de estado de operación vencidas ---------
   PR_INS_ASIE_CAMES(v_cod_tra_pad, v_trans, null, null, v_estado_cta);
END;
/* Recupera monto prevision de ge_cla_operaciones. */
FUNCTION FU_OBT_PREVISION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_prevision ge_cla_operaciones.tot_prevision%type;
begin
   select nvl(sum(nvl(monto,0)),0)
     into v_prevision
     from ov_previsiones
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from ov_previsiones
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
/* Recupera monto valuacion de OV_VALUACIONES. */
FUNCTION FU_OBT_VALUACION
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_valuacion OV_VALUACIONES.tot_val_saldo%type;
begin
   select nvl(sum(nvl(tot_val_saldo,0) -
                  nvl(tot_val_prevision,0)
                  ),0)
     into v_valuacion
     from OV_VALUACIONES
    where nro_cuenta = p_nro_cuenta
      and fecha = (Select max(fecha)
                     from OV_VALUACIONES
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
END PAV_MES;
/
