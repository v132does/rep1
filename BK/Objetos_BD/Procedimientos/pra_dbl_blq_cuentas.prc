CREATE OR REPLACE PROCEDURE it.pra_dbl_blq_cuentas(p_nro_cuenta        in ge_cuentas.nro_cuenta%type,
                                                p_monto             in number,
                                                p_tip_operacion     in varchar2,
                                                p_sub_tip_operacion in varchar2,
                                                p_cod_causa         in ge_bloqueos.cod_causa%TYPE,
                                                p_cod_error         out number,
                                                p_msj_error         out varchar2) IS

  v_nro_doc_blo     number;
  g_cod_error       varchar2(2000);
  g_lugar           varchar2(4000);
  g_msj_error       varchar2(4000);
  v_hora            ge_movimientos.hora%type := to_char(sysdate,
                                                        'hh24:mi:ss');
  v_fec_actual      date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_nro_secuencia   number;
  v_cod_moneda      ge_cuentas.cod_moneda%TYPE := nvl(pag_cta.g_ctas.COD_MONEDA, 'GS');
  v_cod_oficina     ge_cuentas.cod_oficina%TYPE;
  v_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE;
  v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
  v_cod_tra_cam_est ge_movimientos.cod_transaccion%TYPE;
  v_estado          ge_cuentas.estado%TYPE;
  v_mto_bloqueado   number;

  --------- Insertamos movimientos de Bloqueo de Saldos--------------------------
  PROCEDURE pr_ins_mov_bloqueo(p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                               p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                               p_imp_transaccion ge_movimientos.monto%TYPE,
                               p_nro_documento   ge_movimientos.nro_documento%TYPE,
                               p_cod_causa       ge_movimientos.cod_causa%TYPE,
                               p_emi_aviso       ge_movimientos.emi_aviso%TYPE) IS
    r_gmovi ge_movimientos%rowtype;
    -------------------------------------------------------
    -- Obj. Graba GE_MOVIMIENTOS de acuerdo a los parametros --
    -------------------------------------------------------
  BEGIN
    g_lugar         := 'Genera_ge_movimientos';
    v_nro_secuencia := v_nro_secuencia + 1;
    --- Cargar registro de movimientos
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
    r_gmovi.cod_modulo      := pag_Cta.G_CTAS.COD_MODULO;
    r_gmovi.cod_modalidad   := pag_cta.G_CTAS.COD_MODALIDAD;
    r_gmovi.cod_oficina     := pag_cta.G_CTAS.COD_OFICINA;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := pag_cta.g_ctas.ESTADO;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := TO_NUMBER(nvl(v_cod_oficina,
                                             it.fug_obt_ofi_matriz));
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := p_emi_aviso;
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := nvl(pag_Cta.g_ctas.COD_MODULO, 3);
    r_gmovi.cod_mad_padre   := nvl(pag_cta.g_ctas.COD_MODALIDAD, 31);
    r_gmovi.monto           := p_imp_transaccion;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_causa       := p_cod_causa;
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '010';
      g_lugar     := 'Genera Movimiento de Bloqueo de Saldo';
      g_msj_error := 'Error al generar movimiento de bloqueo ' || SQLERRM;
  END;

BEGIN
  Begin pre_ini_aplicacion; end; 
  --
  pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
  IF p_tip_operacion = 'B' THEN
    v_cod_tra_padre := 307;
    --Transaccion cambio de estado
    v_cod_tra_cam_est := 409;
    --Transaccion de movimiento de bloqueo
    v_cod_transaccion := 604;
    --bloqueo de Saldo
    IF p_sub_tip_operacion = 'S' THEN
      v_estado        := 'S';
      v_mto_bloqueado := p_monto;
      --Bloqueo de Cuenta
    ELSIF p_sub_tip_operacion = 'T' THEN
      v_cod_tra_padre   := 306;
      v_cod_tra_cam_est := 408;
      v_estado          := 'T';
      v_mto_bloqueado   := 0;
      --Bloqueo de Debito   
    ELSIF p_sub_tip_operacion = 'D' THEN
      v_cod_transaccion := 410;
      v_estado          := 'D';
      v_mto_bloqueado   := 0;
    ELSE
      g_cod_error := '001';
      g_lugar     := 'Genera Movimiento de Bloqueo ';
      g_msj_error := 'La opcion del sub-tipo de operacion es invalida. Las opciones son Bloq. Debito(D), Bloq. Saldo(S) o Bloq. Cuenta(T). ';
    END IF;
  
    IF v_nro_doc_blo is null THEN
      BEGIN
        select s_nro_bloqueo.nextval into v_nro_doc_blo from dual;
      EXCEPTION
        WHEN OTHERS THEN
          g_cod_error := '005';
          g_lugar     := 'Obtiene la secuencia del bloqueo';
          g_msj_error := 'Error al generar secuencia de bloqueo ' ||
                         SQLERRM;
      END;
    END IF;
    --
    --604
  
    BEGIN
      UPDATE ah_cta_vistas a
         SET a.fec_ult_movimiento = v_fec_actual,
             a.hor_ult_movimiento = v_hora,
             a.sal_bloqueado      = nvl(a.sal_bloqueado,0) + v_mto_bloqueado,
             a.estado             = v_estado
       WHERE a.nro_cuenta = p_nro_cuenta;
    
      --seteamos el estado de la cuenta por que desde este punto debe figurar como bloqueado
      --para todos los movimientos
      pag_cta.g_ctas.estado := v_estado;
    
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '007';
        g_lugar     := 'Actualiza Cuenta Ahorro';
        g_msj_error := 'Error al actualizar datos de la cuenta de ahorro ' ||
                       SQLERRM;
    END;
    --        
    v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
    pr_ins_mov_bloqueo(v_cod_tra_padre,
                       v_cod_tra_cam_est,
                       null,
                       v_nro_doc_blo,
                       p_cod_causa,
                       'N');
    --
  
    BEGIN
      insert into ge_bloqueos
        (nro_cuenta,
         fec_inicio,
         nro_documento,
         cod_causa,
         monto,
         hor_inicio,
         fec_fin,
         tipo,
         observacion)
      values
        (p_nro_cuenta,
         v_fec_actual,
         v_nro_doc_blo,
         p_cod_causa,
         p_monto,
         v_hora,
         null,
         'S',
         FUG_OBT_DES_CAUSA(p_cod_causa));
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '006';
        g_lugar     := 'Inserta Bloqueos';
        g_msj_error := 'Error al insertar bloqueos ' || SQLERRM;
        -- 1. Asignar explícitamente los parámetros de salida antes de romper
        p_cod_error := TO_NUMBER(g_cod_error);
        p_msj_error := g_msj_error;
    END;
  
    -- Insert ba_tab_dat_adicionales
    BEGIN
      insert into ba_tab_dat_adicionales
        (TAB_RELACION, REFERENCIA, PARAMETRO, VAL_PARAMETRO)
      values
        ('GE_BLOQUEOS', v_nro_doc_blo, 'BLO_PRE_APROBADO', p_nro_cuenta);
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '008';
        g_lugar     := 'Inserta Dat Adicionales';
        g_msj_error := 'Error al insertar Dat_Adicionales ' || SQLERRM;
    END;
    if p_sub_tip_operacion in ('S', 'D') THEN
      IF p_sub_tip_operacion = 'D' THEN
        v_cod_tra_padre := 308;
      END IF;
      pr_ins_mov_bloqueo(v_cod_tra_padre,
                         v_cod_transaccion,
                         p_monto,
                         v_nro_doc_blo,
                         p_cod_causa,
                         'N');
    END IF;
  ELSIF p_tip_operacion = 'D' THEN
    IF p_sub_tip_operacion = 'T' THEN
       v_cod_tra_padre   := 417;
       v_cod_transaccion := 417;
    ELSIF p_sub_tip_operacion = 'D' THEN
       v_cod_tra_padre   := 416;
       v_cod_transaccion := 416;
    ELSIF p_sub_tip_operacion = 'S' THEN
       v_cod_tra_padre   := 317;
       v_cod_transaccion := 415;   
    END IF;
    v_estado          := 'N';
    --Genera movimientos
    pr_ins_mov_bloqueo(v_cod_tra_padre,
                       v_cod_transaccion,
                       p_monto,
                       v_nro_doc_blo,
                       p_cod_causa,
                       'N');
    --Actualiza de vuelta al estado anterior
    BEGIN
      UPDATE ah_cta_vistas a
         SET a.fec_ult_movimiento = v_fec_actual,
             a.hor_ult_movimiento = v_hora,
             a.sal_bloqueado      = a.sal_bloqueado + v_mto_bloqueado,
             a.estado             = v_estado
       WHERE a.nro_cuenta = p_nro_cuenta;
    
      --seteamos el estado de la cuenta por que desde este punto debe figurar como bloqueado
      --para todos los movimientos
      pag_cta.g_ctas.estado := v_estado;
    
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '017';
        g_lugar     := 'Actualiza Cuenta Ahorro';
        g_msj_error := 'Error al actualizar datos de la cuenta de ahorro ' ||
                       SQLERRM;
    END;
    --Elimina el bloqueo
    delete ge_bloqueos
     where nro_cuenta = p_nro_cuenta
       and tipo = p_sub_tip_operacion;
  END IF;
  --respuesta
  p_cod_error := nvl(g_cod_error, '000');
  p_msj_error := nvl(g_msj_error, 'OK');
END;
/
