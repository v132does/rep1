CREATE OR REPLACE PACKAGE BODY IT.PAC_MES IS

/* Cambio de Situacion */
PROCEDURE PR_CAM_SITUACION
 (P_COD_MODULO     IN CC_CTA_CORRIENTES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD  IN CC_CTA_CORRIENTES.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA    IN CC_CTA_CORRIENTES.COD_OFICINA%TYPE
 ,P_NRO_CUENTA     IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 ,P_CATEGORIA      IN GE_CLIENTES.CAT_AUTOMATICA%TYPE
 ,P_FECHA          IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_SITUACION      IN CC_SOBREGIROS_RES.SIT_DEUDA%TYPE
 ,P_HORA           IN OUT GE_MOVIMIENTOS.HORA%TYPE    
 ,P_NRO_SECUENCIA  IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
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
   v_est_cuenta    := 'X';

   wlugar:= 'pag_gen.fu_obt_mon_local';
   v_mone_local:= PAG_GEN.FU_OBT_MON_LOCAL;
   wlugar:= 'PR_OBT_DAT_CTA_CORRIENTES';
   PR_OBT_DAT_CTA_CORRIENTES(v_nro_cuenta, rv_ctacte);
   rv_ctacte.estado := nvl(FU_OBT_EST_SOBREGIRO(rv_ctacte.nro_cuenta),rv_ctacte.estado);
   v_fcvenci := rv_ctacte.fec_apertura;
   IF rv_ctacte.cod_moneda <> v_mone_local THEN
      wlugar:= 'pag_gen.fu_obt_cotizacion';
      v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(rv_ctacte.cod_moneda,v_fcdehoy);
   ELSE
      v_cotizacion := null;
   END IF;
   
   --Determino la situacion de la cuenta
   IF p_situacion = 'S' THEN --Normal.
      v_est_cuenta := 'N';
   ELSE 
      v_est_cuenta := nvl(p_situacion,'N');
   END IF;   
   
   --Procesando el cambio de estado.
   IF v_est_cuenta !=  rv_ctacte.estado THEN
      wlugar:= 'pr_pro_cam_estado';
      PR_PRO_CAM_ESTADO;
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

/* Realizar asientos contables por el cambio de estado de la cuentas corrientes. */
PROCEDURE PR_INS_ASI_CAM_ESTADOS
 (P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_ESTADO IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 )
 IS
r_mvto            ge_movimientos%rowtype;
v_redondeo        number(5);
v_cod_mon_local   ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
BEGIN

   --Obtengo el redondeo.
   v_redondeo := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo, v_cod_modalidad,v_cod_mon_local),0);
   --
   if v_secuencia + 3 > 999 then
      v_secuencia := 0;
      v_horamovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_horamovim);
    ELSE
      v_secuencia := v_secuencia + 1;
   end if;
    r_mvto.nro_secuencia   := v_secuencia;
    r_mvto.cod_usuario     := upper(user);
    r_mvto.hora            := v_horamovim;
    r_mvto.cod_modulo      := v_cod_modulo;   
    r_mvto.cod_modalidad   := v_cod_modalidad;  
    r_mvto.cod_oficina     := v_cod_oficina;
    r_mvto.nro_cuenta      := v_nro_cuenta;
    If p_cod_transaccion in (927, 928) then -- Valuaciones.
       r_mvto.cod_moneda := V_MONE_LOCAL;
    Else
       r_mvto.cod_moneda := rv_ctacte.cod_moneda;
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
        r_mvto.mto_equ_local := ROUND((p_monto*v_cotizacion),v_redondeo);
        r_mvto.cotizacion    := v_cotizacion;
    END IF;
    pag_gen.pr_ins_ge_movimiento(r_mvto);
EXCEPTION
    WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
        raise_application_error(-20000,SQLERRM||' Al insertar mvto. Cambio Situacion cuentas corrientes '||v_nro_cuenta);
      end if;
END;

/* Proceso de cambio de estado de las cuentas corrientes. */
PROCEDURE PR_PRO_CAM_ESTADO
IS

--Variables.
v_mto_prevision ge_movimientos.monto%type := 0;
v_mto_valuacion ge_movimientos.monto%type := 0;

BEGIN
   --Asignacion de la transacción padre para cambio de situacion de las cuentas corrientes.
   v_cod_tra_padre  := 945;
   
   -- GENERA ASIENTO POR PREVISION 
   -- Ojo verificar si en el cierre se corre primero el proceso "prc_gen_sobregiros" y despues el cambio de estado.

   v_mto_prevision := FU_OBT_PREVISION(rv_ctacte.nro_cuenta);
   IF nvl(v_mto_prevision,0) > 0 then
      v_mto_transaccion := v_mto_prevision;
      v_transaccion := 944;
      v_concepto:='TRANSF. PREVISION EST.ANT';
      --PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, rv_ctacte.estado);
	  --Para insertar este movimiento debe enviar el estado anterior-- CN 09/05/2014
      PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, v_est_cuenta);
      v_transaccion := 946;
      v_concepto:='TRANSFERENCIA DE PREVISION';
      --PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, v_est_cuenta);
	  --Para insertar este movimiento debe enviar el estado actual-- CN 09/05/2014
      PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, rv_ctacte.estado);
   END IF;
   
   -- GENERA ASIENTO POR VALUACION --
   v_mto_valuacion := FU_OBT_VALUACION(rv_ctacte.nro_cuenta);
   IF nvl(v_mto_valuacion,0) > 0 then
      v_mto_transaccion := v_mto_valuacion;
      v_transaccion := 927;
      v_concepto:='TRANSF. VALUACION EST.ANT';
      PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, rv_ctacte.estado);
      v_transaccion := 928;
      v_concepto:='TRANSFERENCIA DE VALUACION';
      PR_INS_ASI_CAM_ESTADOS(v_cod_tra_padre, v_transaccion, v_mto_transaccion, v_concepto, v_est_cuenta);
   END IF;
END;

/* Recupera monto prevision de ge_cla_operaciones. */
FUNCTION FU_OBT_PREVISION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_prevision ge_cla_operaciones.tot_prevision%type;
begin
   select nvl(sum(nvl(monto,0)),0) - NVL(SUM(tot_prv_contingencia), 0)
     into v_prevision
     from cc_previsiones
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from cc_previsiones
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

/* Recupera monto valuacion de CC_VALUACIONES. */
FUNCTION FU_OBT_VALUACION
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE)
 RETURN NUMBER
 IS
v_valuacion cc_valuaciones.sal_total%type;
begin
   select nvl(sum(nvl(tot_valuacion,0) - nvl(tot_val_prevision,0)),0)
     into v_valuacion
     from CC_VALUACIONES
    where nro_cuenta = p_nro_cuenta
      and fecha = (Select max(fecha)
                     from CC_VALUACIONES
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

/* Permite obtener los datos de las cuentas corrientes. */
PROCEDURE PR_OBT_DAT_CTA_CORRIENTES
  (P_NRO_CUENTA     IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE,
   RG_CTA_CORRIENTE IN OUT CC_CTA_CORRIENTES%ROWTYPE)
IS
BEGIN
   select *
     into rg_cta_corriente
     from CC_CTA_CORRIENTES
    where nro_cuenta = p_nro_cuenta
      and estado != 'C';
exception
   when no_data_found then
      raise_application_error(-20000,'Cuentas Corrientes '||p_nro_cuenta||' no registrada');
END;

/* Obtener la situación del sobregiro. */
FUNCTION FU_OBT_EST_SOBREGIRO(P_NRO_CUENTA IN CC_CTA_CORRIENTES.NRO_CUENTA%TYPE)
RETURN VARCHAR2
AS
v_sit_deuda cc_sobregiros_res.sit_deuda%type;
BEGIN
      select csr.sit_deuda
        into v_sit_deuda
       from cc_sobregiros_res csr
       where csr.nro_cuenta = P_NRO_CUENTA;
       
       -- Agregado por MS en el mes 03/2014
       IF v_sit_deuda = 'S' THEN
           v_sit_deuda := 'N';
       END IF;
       --
       return v_sit_deuda;
    
EXCEPTION
  WHEN OTHERS THEN
     RETURN null;
END;

END PAC_MES;
/

