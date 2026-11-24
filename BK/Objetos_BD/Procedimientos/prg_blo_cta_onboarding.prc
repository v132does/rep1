CREATE OR REPLACE PROCEDURE IT.PRG_BLO_CTA_ONBOARDING(p_nro_cuenta  in ge_cuentas.nro_cuenta%type,
                                                  p_cod_causa   in ge_causales.cod_causa%type,
                                                  p_observacion in ge_bloqueos.observacion%type,
                                                  p_cob_cargo   in varchar2 default 'S',
                                                  p_cod_error   out number,
                                                  p_mensaje     out varchar2) IS
  v_nrdocum    ge_movimientos.nro_documento%type;
  v_hor_blo    ge_bloqueos.hor_inicio%type;
  v_secuencia  ge_movimientos.nro_secuencia%type;
  v_horario    varchar2(1);
  v_es_mov_noc varchar2(1);
  v_es_cta_noc varchar2(1);
  v_fec_valor  ge_calendarios.fec_actual%type;
  v_est_modulo ba_modulos.estado%type := pae_cnf.fu_obt_est_modulo(3);
  v_fec_actual ge_calendarios.fec_actual%type;
  V_DIFEREN    GE_MOVIMIENTOS.MONTO%TYPE;
  V_CARIMP     GE_MOVIMIENTOS.MONTO%TYPE;
  V_CDTASCA    GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VLTASCA    GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_MONTCAR    GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_CDTASAS    GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VLTASA     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_MONTIMP    GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
  PROCEDURE VALIDA_COBRO_CARGOS IS
    V_DIF        NUMBER(21) := 0;
    IMPOR_TRANS  NUMBER(21) := 0;
    moneda_local varchar2(3);
    v_cdtranp    number(3);
    v_cdtrans    number(3);
    V_SLDISPO    ah_cta_vistas.sal_total%type;
    V_CDTRANI    GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;

  BEGIN
    v_cdtranp := 306;
    v_cdtrans := 505;

    if nvl(p_cob_cargo, 'S') = 'S' Then
      moneda_local := pag_gen.FU_OBT_MON_LOCAL;
      V_SLDISPO    := nvl(pag_cta.G_CTAS.SAL_DISPONIBLE, 0);
      If nvl(V_SLDISPO, 0) = 0 then
        p_mensaje   := 'Bloqueo no permitido - Saldo insuficiente para cobro de cargos';
        p_cod_error := 4;
      End if;
      prg_obt_cargos(pag_cta.G_CTAS.COD_OFICINA,
                     P_NRO_CUENTA,
                     pag_cta.G_CTAS.cod_moneda,
                     0,
                     pag_cta.G_CTAS.COD_MODULO,
                     pag_cta.G_CTAS.COD_MODALIDAD,
                     V_cdtrans,
                     V_CDTASCA,
                     V_VLTASCA,
                     V_MONTCAR, -- cargo
                     V_CDTRANI,
                     v_CDTASAS,
                     v_VLTASA,
                     V_MONTIMP);

      V_CARIMP := nvl(V_MONTCAR, 0) + nvl(V_MONTIMP, 0);

      IF NVL(V_SLDISPO, 0) > 0 THEN
        V_DIF := (NVL(V_SLDISPO, 0) - NVL(V_CARIMP, 0));
      END IF;
      IF V_DIF < 0 THEN
        V_MONTCAR := ((V_SLDISPO * 100) / (100 + NVL(V_VLTASA, 0)));
        V_MONTIMP := (NVL(V_SLDISPO, 0) - NVL(V_MONTCAR, 0));
        V_CARIMP  := NVL(V_MONTCAR, 0) + NVL(V_MONTIMP, 0);
        /*V_DIFEREN := (NVL(V_SLDISPO,0) -  NVL(V_CARIMP,0));
        ELSIF V_DIF >0 THEN
              V_DIFEREN := v_DIF;
        ELSIF V_DIF =0 THEN
              V_DIFEREN := 0;*/
      END IF;
    Else
      V_CARIMP  := 0;
      v_montcar := 0;
      v_montimp := 0;
      -- v_diferen := nvl(v_sldispo,0);
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_mensaje   := substr('Error en el proceso de cobro de cargos ' ||
                            sqlerrm,
                            1,
                            4000);
      p_cod_error := 6;
  END;

  PROCEDURE PR_VER_HORARIO(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_fec_actual     OUT DATE,
                           p_fec_valor      OUT DATE,
                           p_cod_error      OUT number,
                           p_men_error      OUT varchar2) is

    v_est_modulo ba_modulos.estado%TYPE;
  BEGIN
    p_cod_error  := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
    p_horario    := 'D'; -- Dia normal
    p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(9);

    IF v_est_modulo IN (6) THEN
      -- En cierre.
      p_cod_error := 1070;
      p_men_error := 'Proceso en cierre';
    ELSIF v_est_modulo = 2 THEN
      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(9);
    ELSE
      p_horario := 'N'; -- Noche
      IF v_est_modulo <> 1 THEN
        p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1,
                                                 1,
                                                 p_cod_ofi_origen);
      END IF;
      p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
    END IF;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
  END PR_VER_HORARIO;
  PROCEDURE PR_GEN_GE_MOVIMIENTOS(p_fec_actual      in ge_calendarios.fec_actual%type,
                                  p_nro_secuencia   in ge_movimientos.nro_secuencia%type,
                                  p_hora            in ge_movimientos.hora%type,
                                  p_cod_tra_padre   in ge_transacciones.cod_transaccion%type,
                                  p_cod_modulo      ge_movimientos.cod_modulo%type,
                                  p_cod_modalidad   ge_movimientos.cod_modalidad%type,
                                  p_nro_cuenta      ge_movimientos.nro_cuenta%type,
                                  p_cod_moneda      ge_movimientos.cod_moneda%type,
                                  p_cod_oficina     ge_movimientos.cod_oficina%type,
                                  p_est_cuenta      ge_movimientos.est_cuenta%type,
                                  p_cod_transaccion in ge_transacciones.cod_transaccion%type,
                                  p_monto           in ge_movimientos.monto%type,
                                  p_nro_documento   in ge_movimientos.nro_documento%type,
                                  p_cod_causa       in ge_movimientos.cod_causa%type,
                                  p_emi_aviso       in ge_movimientos.emi_aviso%type,
                                  p_cod_tasa        in ge_movimientos.cod_tasa%type,
                                  p_val_tasa        in ge_movimientos.val_tasa%type,
                                  p_cod_error       out number,
                                  p_men_error       out varchar2,
                                  p_cod_usuario     varchar2 default null,
                                  p_concepto        varchar2 default null,
                                  p_es_nocturno     in varchar2 default 'N',
                                  p_fec_valor       in ge_movimientos.fec_valor%type) IS
    r_gmovi ge_movimientos%rowtype;

  BEGIN
    p_cod_error := 0;

    --- Cargar registro de movimiento
    r_gmovi.cod_usuario     := nvl(p_cod_usuario, user);
    r_gmovi.hora            := p_hora;
    r_gmovi.nro_secuencia   := nvl(p_nro_secuencia, 1);
    r_gmovi.cod_modulo      := p_cod_modulo;
    r_gmovi.cod_modalidad   := p_cod_modalidad;
    r_gmovi.cod_oficina     := p_COD_OFICINA;
    r_gmovi.nro_cuenta      := p_NRO_CUENTA;
    r_gmovi.cod_moneda      := p_COD_MONEDA;
    r_gmovi.fec_valor       := p_fec_valor;
    r_gmovi.fecha           := p_fec_actual;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := p_est_cuenta;
    r_gmovi.estado          := 'N'; --Si es cambio de estado debe ingresar como normal
    r_gmovi.cod_ofi_origen  := fug_obt_ofi_usuario(nvl(p_cod_usuario, user));
    r_gmovi.reversado       := 'N';
    r_gmovi.emi_aviso       := p_emi_aviso;
    r_gmovi.protegido       := 'N';
    r_gmovi.cod_mod_padre   := p_COD_MODULO;
    r_gmovi.cod_mad_padre   := p_COD_MODALIDAD;
    r_gmovi.monto           := p_monto;
    r_gmovi.nro_documento   := p_nro_documento;
    r_gmovi.cod_causa       := p_cod_causa;
    r_gmovi.cod_tasa        := p_cod_tasa;
    r_gmovi.val_tasa        := p_val_tasa;
    r_gmovi.concepto        := nvl(p_concepto, '');
    pag_gen.pr_ins_ge_movimiento(r_gmovi, p_es_nocturno);

  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := v_err_sql;
      p_men_error := 'No se puede ingresar el Movimiento ' || sqlerrm;
  END;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  v_secuencia := 0;
  v_hor_blo   := TO_CHAR(SYSDATE, 'HH24:MI:SS');

  --asignar secuencia al nro de documento
  if v_nrdocum is null then
    begin
      select s_nro_bloqueo.nextval into v_nrdocum from dual;
    exception
      when others then
        p_mensaje   := substr('Sec. Bloqueo ' || sqlerrm, 1, 4000);
        p_cod_error := 1;
    end;
  end if;

  pag_cta.PR_OBT_CUENTA(P_NRO_CUENTA);
 IF pag_cta.G_COD_ERROR != 12 THEN --12=Cuenta inexistente
  PR_VER_HORARIO(pag_cta.G_CTAS.COD_OFICINA,
                 v_horario,
                 v_es_mov_noc,
                 v_es_cta_noc,
                 v_fec_actual,
                 v_fec_valor,
                 p_cod_error,
                 p_mensaje);
  if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' and v_es_mov_noc = 'S' then
    p_cod_error := '1070';
    p_mensaje   := 'Modulo en proceso de cierre';
  elsif nvl(p_cod_error, 0) = 0 then
    v_hor_blo := fug_obt_hor_disponible(v_fec_actual,
                                        v_hor_blo,
                                        user,
                                        v_es_mov_noc);

    pag_cta.pr_set_variables(user,
                             v_fec_valor,
                             306,
                             'N',
                             'N',
                             v_secuencia,
                             'T',
                             fug_obt_ofi_usuario(user),
                             pag_cta.G_CTAS.COD_MODULO,
                             pag_cta.G_CTAS.COD_MODALIDAD);

    pag_cta.pr_act_estado(P_NRO_CUENTA,
                          'T',
                          v_fec_actual,
                          v_hor_blo,
                          v_nrdocum,
                          'S');
    v_secuencia := nvl(v_secuencia, 0) + 1;

    IF nvl(P_COB_CARGO, 'S') = 'S' and NVL(P_COD_ERROR, 0) = 0 THEN
      VALIDA_COBRO_CARGOS;
      IF NVL(P_COD_ERROR, 0) = 0 THEN
        IF NVL(V_MONTCAR, 0) > 0 THEN
          v_secuencia := nvl(v_secuencia, 0) + 1;
          PR_GEN_GE_MOVIMIENTOS(v_fec_actual,
                                v_secuencia,
                                v_hor_blo,
                                306,
                                pag_cta.G_CTAS.COD_MODULO,
                                pag_cta.G_CTAS.COD_MODALIDAD,
                                p_nro_cuenta,
                                pag_cta.G_CTAS.COD_MONEDA,
                                pag_cta.G_CTAS.COD_OFICINA,
                                NULL,
                                505,
                                V_MONTCAR,
                                v_nrdocum,
                                p_cod_causa,
                                'S',
                                V_CDTASCA,
                                V_VLTASCA,
                                p_cod_error,
                                p_mensaje,
                                user,
                                null,
                                v_es_mov_noc,
                                v_fec_valor);

        END IF;
        IF NVL(V_MONTIMP, 0) > 0 and NVL(P_COD_ERROR, 0) = 0 THEN
          v_secuencia := nvl(v_secuencia, 0) + 1;
          PR_GEN_GE_MOVIMIENTOS(v_fec_actual,
                                v_secuencia,
                                v_hor_blo,
                                306,
                                pag_cta.G_CTAS.COD_MODULO,
                                pag_cta.G_CTAS.COD_MODALIDAD,
                                p_nro_cuenta,
                                pag_cta.G_CTAS.COD_MONEDA,
                                pag_cta.G_CTAS.COD_OFICINA,
                                NULL,
                                506,
                                V_MONTIMP,
                                v_nrdocum,
                                p_cod_causa,
                                'S',
                                V_CDTASAS,
                                V_MONTIMP,
                                p_cod_error,
                                p_mensaje,
                                user,
                                null,
                                v_es_mov_noc,
                                v_fec_valor);

        END IF;
      end if;
    END IF;
          if NVL(P_COD_ERROR, 0) = 0 then
        BEGIN
          insert into ge_bloqueos
            (nro_cuenta,
             nro_documento,
             fec_inicio,
             hor_inicio,
             cod_causa,
             tipo,
             observacion)
          values
            (p_nro_cuenta,
             v_nrdocum,
             v_fec_actual,
             v_hor_blo,
             p_cod_causa,
             'T',
             p_observacion);
        EXCEPTION
          when others then
            p_mensaje   := substr('Error al insertar en GE_BLOQUEOS- ' ||
                                  sqlerrm,
                                  1,
                                  4000);
            p_cod_error := 7;
        END;
        If sql%notfound then
          p_mensaje   := 'No se puedo registrar registro en GE_BLOQUEOS';
          p_cod_error := 1;
        else
          p_mensaje := 'OK';
        End if;

      end if;
  END IF;
 END IF;
EXCEPTION
  WHEN OTHERS THEN
    p_mensaje   := substr('Error en el proceso de bloqueo de cuenta ' ||
                          sqlerrm,
                          1,
                          4000);
    p_cod_error := 3;
END;
/

