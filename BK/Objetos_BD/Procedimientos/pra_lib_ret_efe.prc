CREATE OR REPLACE PROCEDURE IT.PRA_LIB_RET_EFE(P_CTA_DESDE     IN VARCHAR2 default null,
                                               P_CTA_HASTA     IN VARCHAR2 default null,
                                               P_LIB_POSTERIOR IN VARCHAR2 DEFAULT null,
                                               P_MUE_ERROR     IN VARCHAR2 DEFAULT 'S',
                                               P_NRO_BOLETA    IN NUMBER DEFAULT NULL) IS

  V_MENSAJE       VARCHAR2(250);
  V_COD_USUARIO   BA_USUARIOS.COD_USUARIO%TYPE;
  V_HORA          GE_MOVIMIENTOS.HORA%TYPE;
  V_COD_MONEDA    AH_CTA_VISTAS.COD_MONEDA%TYPE;
  V_COD_MOD_PADRE BA_MODULOS.COD_MODULO%TYPE;
  V_COD_MAD_PADRE GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
  V_FEC_ACTUAL    DATE;
  V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
  R_GMOVI         GE_MOVIMIENTOS%ROWTYPE;
  V_ENCONTRO      VARCHAR2(1) := 'N';
  v_cta_desde     ge_cuentas.nro_cuenta%type;
  v_cta_hasta     ge_cuentas.nro_cuenta%type;
  v_existe        varchar2(1) := 'N';
  v_est_modulo    ba_modulos.estado%TYPE;
  v_es_nocturno   VARCHAR2(1) := 'N';
  --Transacciones parametrizadas para Deposito Normal(Deposito de Dinero)
  v_cod_tra_pad_lib_efe GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_PAD_EFE_LIB'); --515
  v_cod_tra_hij_lib_efe GE_PAR_DINAMICOS.VAL_PARAMETRO%type := fug_obt_pardinamico('CJ_TRA_HIJ_EFE_LIB'); --515
  v_cod_ret_efe_24      GE_PAR_DINAMICOS.VAL_PARAMETRO%type := to_number(fug_obt_pardinamico('CJ_COD_RET_EFE_24')); --10
  v_cod_ret_efe_48      GE_PAR_DINAMICOS.VAL_PARAMETRO%type := to_number(fug_obt_pardinamico('CJ_COD_RET_EFE_48')); --11
  v_cod_ret_efe_72      GE_PAR_DINAMICOS.VAL_PARAMETRO%type := to_number(fug_obt_pardinamico('CJ_COD_RET_EFE_72')); --12
  CURSOR C_AH_RETENCIONES IS
    SELECT AH_RETENCIONES.*, AH_RETENCIONES.ROWID FILA
      FROM AH_RETENCIONES
     WHERE LIBERADO = 'N'
       AND COD_MODULO IN (3, 4)
       AND COD_RETENCION IN
           (v_cod_ret_efe_24, v_cod_ret_efe_48, v_cod_ret_efe_72)
       AND NRO_DOCUMENTO = NVL(P_NRO_BOLETA, NRO_DOCUMENTO)
       AND ((FEC_FINAL <= V_FEC_ACTUAL) or (LIB_POSTERIOR = 'S'))
       AND NVL(P_LIB_POSTERIOR, LIB_POSTERIOR) = LIB_POSTERIOR
       AND NRO_CUENTA between v_CTA_DESDE AND v_CTA_HASTA;
  R_RETENCION C_AH_RETENCIONES%ROWTYPE;
---
PROCEDURE lp_ver_horario IS
  BEGIN
    --- Buscar si es nocturno o diurno
      if v_est_modulo = 2 then
         v_es_nocturno := 'N';
      else
         v_es_nocturno := 'S';
      end if;
  END lp_ver_horario;
  ---
  /* Actualizar el saldo retenido en AH_CTA_VISTAS. */
  PROCEDURE LP_ACT_SAL_RET_VISTA IS
  
    CURSOR C_AH_CTA_VISTAS IS
      SELECT COD_MONEDA, NRO_CUENTA
        FROM AH_CTA_VISTAS
       WHERE NRO_CUENTA = R_RETENCION.NRO_CUENTA
         FOR UPDATE OF SAL_RETENIDO;
    V_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE;
  BEGIN
    IF C_AH_CTA_VISTAS%ISOPEN THEN
      CLOSE C_AH_CTA_VISTAS;
    END IF;
    OPEN C_AH_CTA_VISTAS;
    V_ENCONTRO := 'N';
    FETCH C_AH_CTA_VISTAS
      INTO V_COD_MONEDA, V_NRO_CUENTA;
  
    IF C_AH_CTA_VISTAS%FOUND THEN
      V_ENCONTRO := 'S';
      BEGIN
        UPDATE AH_CTA_VISTAS
           SET SAL_RETENIDO       = NVL(SAL_RETENIDO, 0) -
                                    NVL(R_RETENCION.SAL_RETENIDO, 0),
               FEC_ULT_MOVIMIENTO = V_FEC_ACTUAL,
               HOR_ULT_MOVIMIENTO = v_hora
         WHERE CURRENT OF C_AH_CTA_VISTAS;
        IF SQL%NOTFOUND THEN
          --no se puede procesar
          V_MENSAJE := ' No se encontraron datos de saldos para actualizar ...';
          raise_application_error(-20000, V_MENSAJE);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          --no se puede procesar
          V_MENSAJE := ' No se encontraron datos de saldos para actualizar ...';
          raise_application_error(-20000, V_MENSAJE);
      END;
    ELSE
      V_MENSAJE := ' No se encontro cuenta ' || R_RETENCION.NRO_CUENTA ||
                   ' en AH_CTA_VISTAS...';
    END IF;
    CLOSE C_AH_CTA_VISTAS;
  END;

  --- Inicio del proceso principal
BEGIN
  If p_cta_desde is null then
    v_cta_desde := '0';
  Else
    v_cta_desde := p_cta_desde;
  End If;
  If p_cta_hasta is null then
    v_cta_hasta := '999999999999999';
  Else
    v_cta_hasta := p_cta_hasta;
  End If;

  V_COD_MOD_PADRE := 3;
  V_COD_MAD_PADRE := 31;
  V_COD_USUARIO   := USER;
  V_FEC_ACTUAL    := PAG_CAL.FU_OBT_FEC_ACTUAL(3);
  v_hora          := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  v_hora          := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
  v_nro_secuencia := nvl(pae_cnf.G_NRO_SECUENCIA, 0);
  IF C_AH_RETENCIONES%ISOPEN THEN
    CLOSE C_AH_RETENCIONES;
  END IF;
  OPEN C_AH_RETENCIONES;
  LOOP
    FETCH C_AH_RETENCIONES
      INTO R_RETENCION;
    EXIT WHEN C_AH_RETENCIONES%NOTFOUND;
    V_ENCONTRO := 'N';
    --Verificar los cheques cargo otros bancos en moneda extranjera que esten todos
    --confirmados
    v_existe := 'N';
    IF (R_RETENCION.COD_MODULO = 3 AND
       R_RETENCION.COD_MODALIDAD in (31, 38, 39, 334) AND V_EXISTE = 'N') THEN
      LP_ACT_SAL_RET_VISTA;
      -- Actualiza la retencion que ya fue liberada
      ---------------------------------------------
      IF V_ENCONTRO = 'S' THEN
        BEGIN
          UPDATE AH_RETENCIONES
             SET LIBERADO = 'S', SAL_RETENIDO = 0
           WHERE ROWID = R_RETENCION.FILA;
          IF SQL%NOTFOUND THEN
            --no se puede procesar
            V_MENSAJE := ' No se encontraron retenciones para actualizar ...';
            raise_application_error(-20000, V_MENSAJE);
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            --no se puede procesar
            V_MENSAJE := ' No se encontraron retenciones para actualizar ...';
            raise_application_error(-20000, V_MENSAJE);
        END;
      END IF;
    END IF;
    v_est_modulo := pae_cnf.fu_obt_est_modulo(3);
    -- Verifica el horario.
    lp_ver_horario;
    --- Actualiza diario ---
    ------------------------
    IF V_ENCONTRO = 'S' AND V_EXISTE = 'N' THEN
      if v_nro_secuencia > 990 then
        v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
        v_nro_secuencia := 1;
      end if;
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.cod_usuario   := v_cod_usuario;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      r_gmovi.cod_modulo    := r_retencion.cod_modulo;
      r_gmovi.cod_modalidad := r_retencion.cod_modalidad;
      r_gmovi.cod_oficina   := r_retencion.cod_oficina;
      if r_retencion.cod_modulo = 9 then
        r_gmovi.nro_cuenta := null;
      else
        r_gmovi.nro_cuenta := r_retencion.nro_cuenta;
      end if;
      r_gmovi.cod_moneda      := r_retencion.cod_moneda;
      r_gmovi.fec_valor       := r_retencion.fec_inicio;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.cod_tra_padre   := v_cod_tra_pad_lib_efe;
      r_gmovi.cod_transaccion := v_cod_tra_hij_lib_efe;
      r_gmovi.nro_documento   := r_retencion.nro_documento;
      r_gmovi.monto           := r_retencion.sal_retenido;
      r_gmovi.cod_retencion   := r_retencion.cod_retencion;
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := r_retencion.cod_oficina;
      r_gmovi.reversado       := 'N';
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.cod_mod_padre   := v_cod_mod_padre;
      r_gmovi.cod_mad_padre   := v_cod_mad_padre;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
      pae_cnf.G_NRO_SECUENCIA := v_nro_secuencia;
      IF r_retencion.cod_modalidad = 33 then
        -- Generar movimiento por cambio de estado N-ormal
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.monto           := null;
        r_gmovi.est_cuenta      := 'N';
        r_gmovi.cod_tra_padre   := 425;
        r_gmovi.cod_transaccion := 425;
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
      END IF;
    END IF;
  END LOOP;
  IF C_AH_RETENCIONES%ROWCOUNT = 0 THEN
    V_MENSAJE := ' No se encontraron retenciones para liberar ...';
  
  END IF;
END;
/
