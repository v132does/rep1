CREATE OR REPLACE PROCEDURE IT.prp_gen_pre_apr_des_com_car(p_nro_solicitud     in pr_solicitudes.nro_solicitud%TYPE,
                                                          p_mto_desembolsar   in pr_solicitudes.monto%TYPE,
                                                          p_nro_cta_acreditar in ge_movimientos.nro_cuenta%TYPE,
                                                          p_clave             in number,
                                                          p_cod_persona       in ba_personas.cod_persona%TYPE,
                                                          p_nro_cuenta        out pr_cta_prestamos.nro_cuenta%TYPE,
                                                          p_cod_error         out NUMBER,
                                                          p_msj_error         out VARCHAR2) IS
  ---------------------------------------------------------------------------
  g_lugar     VARCHAR2(250);
  g_msj_error VARCHAR2(4000);
  g_cod_error NUMBER(3) DEFAULT 0;
  --------------------------------------------------------------------------
  v_fec_actual    DATE := pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_tip_documento pr_solicitudes.tip_documento%TYPE := 1;
  v_nro_doc_desde number := 1;
  v_nro_doc_hasta number := 1;
  v_cod_oficina   ba_oficinas.cod_oficina%TYPE;
  v_cod_ori_fondo pr_solicitudes.cod_ori_fondo%TYPE;
  v_hora          ge_movimientos.hora%type := to_char(sysdate, 'hh24:mi:ss');
  v_cod_modulo    pr_solicitudes.cod_modulo%TYPE := 6;
  v_cod_modalidad pr_solicitudes.cod_modalidad%TYPE := 65;
  v_cod_moneda    pr_solicitudes.cod_moneda%type :=  nvl(pag_cta.g_ctas.COD_MONEDA, 'GS');
  ---------------------------------------------------------------------------

  v_mto_cargo          number;
  v_mto_int_adelantado number;
  ---------------------------------------------------------------------------
  v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
  v_nro_cuenta    ge_movimientos.nro_cuenta%TYPE;
  v_cotizacion    ge_movimientos.cotizacion%TYPE;
  v_impuesto      ge_movimientos.monto%type;
  ----------------------------------------------------------------------------
  v_nro_doc_blo ge_movimientos.nro_documento%TYPE;
  v_cod_causa   ge_movimientos.cod_causa%TYPE;
  ----------------------------------------------------------------------------
  v_dir_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('MAI_BLO_DESEMBOLSO');
  v_texto     varchar2(4000);
  v_remitente ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  v_asunto    varchar2(4000);
  ----------------------------------------------------------------------------
  v_mto_sue_minimo     pr_parametros.sal_min_vigente%type;
  v_can_sue_minimo     ge_par_dinamicos.val_parametro%type;
  v_mto_lim_cta_basica ge_movimientos.monto%type;
  v_sal_acu_mes        ah_sal_mensuales.tot_creditos%type;
  ----------------------------------------------------------------------------
  v_msj_error VARCHAR2(4000);
  v_cod_error NUMBER(3) DEFAULT 0;
  ----------------------------------------------------------------------------
  v_cod_mon_solicitud pr_solicitudes.cod_moneda%type;
  ----------------------------------------------------------------------------
  v_exite      varchar2(1);
  v_existe_tc   varchar2(1);
  v_est_doc     number := 0;
  v_est_wf48    number := 0;

  PROCEDURE pr_obt_dat_solicitud IS
    r_psoli pr_solicitudes%rowtype;
  BEGIN
    pap_pre.PR_OBT_DAT_SOLICITUD(p_nro_solicitud,
                                 r_psoli,
                                 v_mto_cargo,
                                 v_mto_int_adelantado);
    IF r_psoli.estado = 'L' THEN
      v_tip_documento := r_psoli.tip_documento;
      v_cod_ori_fondo := r_psoli.cod_ori_fondo;
      v_cod_oficina   := r_psoli.cod_oficina;
    END IF;
    v_cod_modalidad := r_psoli.cod_modalidad;
    v_cod_mon_solicitud:=r_psoli.cod_moneda;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '001';
      g_lugar     := 'Obtener Solicitud ' || p_nro_solicitud;
      g_msj_error := 'Error al obtener solicitudes ' || SQLERRM;
  END;
  --------- Insertamos movimientos de Bloqueo de Saldos--------------------------
  PROCEDURE pr_ins_mov_rub_cta(p_cod_tra_padre   ge_movimientos.cod_tra_padre%TYPE,
                               p_cod_transaccion ge_movimientos.cod_transaccion%TYPE,
                               p_imp_transaccion ge_movimientos.monto%TYPE,
                               p_nro_documento   ge_movimientos.nro_documento%TYPE,
                               p_cotizacion      ge_movimientos.cotizacion%TYPE) IS
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
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
    r_gmovi.cod_modulo      := pag_Cta.G_CTAS.COD_MODULO;
    r_gmovi.cod_modalidad   := pag_cta.G_CTAS.COD_MODALIDAD;
    r_gmovi.cod_oficina     := pag_cta.G_CTAS.COD_OFICINA;
    
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;

    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_mod_padre   := nvl(pag_Cta.g_ctas.COD_MODULO, 3);
    r_gmovi.cod_mad_padre   := nvl(pag_cta.g_ctas.COD_MODALIDAD, 31);    
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.monto           := p_imp_transaccion;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_ofi_origen  := TO_NUMBER(nvl(v_cod_oficina,
                                             it.fug_obt_ofi_matriz));
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := 'Desembolso de Solicitud '||p_nro_documento; 
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.cod_rubro       := p_nro_cta_acreditar;
    r_gmovi.nro_cuenta      := null;
    r_gmovi.tip_mov_rubro   := 'C';
    r_gmovi.cotizacion      := p_cotizacion;
    r_gmovi.mto_equ_local   := round(trunc(p_imp_transaccion,2)*p_cotizacion,2);
     
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
    v_nro_secuencia := nvl(v_nro_secuencia, 1) + 1;
  EXCEPTION
    WHEN OTHERS THEN
      g_cod_error := '010';
      g_lugar     := 'Genera Movimiento de Bloqueo de Saldo';
      g_msj_error := 'Error al generar movimiento de bloqueo ' || SQLERRM;
  END;
BEGIN
  g_msj_error := ' ';
  g_cod_error := 0;
  BEGIN
    pre_ini_aplicacion;
  END;
  PAE_CNF.G_PROGRAMA := 'PRP_GEN_PRE_APR_DESEMBOLSO';
  -- Inicialmente controlamos que la ---------------------------------------------
  -- clave introducida sea correcta  ---------------------------------------------
  IF nvl(g_cod_error, '000') = '000' THEN    
    -- Obtenemos la solicitud del cliente -------------------------------------------
    IF nvl(g_cod_error, '000') = '000' THEN
      pr_obt_dat_solicitud;
    END IF;
     -- Generamos la cuenta y el desembolso -------------------------------------------
    IF nvl(g_cod_error, '000') = '000' THEN

      pap_pre.pr_des_prestamos(p_nro_solicitud,
                               p_mto_desembolsar,
                               v_fec_actual,
                               v_tip_documento,
                               v_nro_doc_desde,
                               v_nro_doc_hasta,
                               v_cod_oficina,
                               v_cod_ori_fondo,
                               v_hora,
                               v_nro_secuencia,
                               v_nro_cuenta);
      -----------------------------------------------------------------------------------
      IF p_nro_cta_acreditar is not null THEN
        --
        pag_cta.PR_OBT_CUENTA(p_nro_cta_acreditar);
        --
        v_cotizacion := null;
        prg_ver_cob_cargos(p_nro_cta_acreditar,
                           v_nro_cuenta,
                           v_cod_modulo,
                           v_cod_modalidad,
                           v_cod_oficina,
                           v_cod_moneda,
                           abs(p_mto_desembolsar),
                           'Desembolso de Préstamo ' || v_nro_cuenta,
                           null,
                           v_fec_actual,
                           v_hora,
                           v_impuesto,
                           v_nro_secuencia,
                           'S',
                           v_cotizacion);
        --
        IF p_mto_desembolsar <> 0 THEN
          IF p_mto_desembolsar > 0 THEN
            begin
              pr_ins_mov_rub_cta(358,
                                 741,
                                 p_mto_desembolsar - nvl(v_impuesto,0),
                                 p_nro_solicitud,
                                 v_cotizacion);
/*              pag_cta.PR_ACT_OPERACION(p_nro_cta_acreditar,
                                       v_hora,
                                       'C',
                                       v_cod_moneda,
                                       p_mto_desembolsar - nvl(v_impuesto, 0),
                                       358,
                                       741,
                                       p_nro_solicitud,
                                       v_cotizacion,
                                       v_cod_oficina,
                                       v_cod_modulo,
                                       v_cod_modalidad,
                                       null,
                                       null,
                                       'Desembolso de Sol. ' ||
                                       p_nro_solicitud,
                                       'S',
                                       v_nro_secuencia,
                                       v_fec_actual);*/
            exception
              when others then
                g_cod_error := '004';
                g_lugar     := 'Credito Rubro Contable';
                g_msj_error := 'Error al realizar credito de pre-aprobados ' ||
                               SQLERRM;
            end;
          END IF;
        END IF;
        --          
      END IF;      
    END IF;
  END IF;
  --
  IF nvl(g_cod_error, '000') <> '000' THEN
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  ELSE
    g_cod_error  := '000';
    g_msj_error  := 'PROCESO CONCLUIDO CON EXITO.';
    p_nro_cuenta := v_nro_cuenta;
    p_cod_error  := g_cod_error;
    p_msj_error  := g_msj_error;   
  END IF;
END;
/

