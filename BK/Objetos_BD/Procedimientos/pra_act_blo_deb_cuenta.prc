create or replace procedure it.pra_act_blo_deb_cuenta is
  v_fec_actual    ge_calendarios.fec_actual%type;
  v_cod_mon_local ba_monedas.cod_moneda%type;
  v_hora          ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%type;
  r_gmovi         ge_movimientos%rowtype;
  v_nro_doc       ge_bloqueos.nro_documento%type;
  v_lugar         varchar2(1000);
  v_error         varchar2(4000);

  v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_COR_BLOQ_CUENTA');
  v_mto_limite number;
  --
  v_est_anterior    VARCHAR2(01) := NULL;
  v_est_actual      VARCHAR2(01) := NULL;
  v_fec_cam_est_ant DATE := NULL;

  --
  cursor transferencias is
    select distinct t.nro_cta_solicitante,
                    t.nro_cta_beneficiario,
                    c.cod_persona,
                    a.cod_modulo,
                    a.cod_modalidad,
                    a.cod_oficina,
                    a.cod_moneda,
                    t.nro_cta_pte_solicitante,
                    sum(t.monto) mto_transferido,
                    count(*) cantidad
      from ge_snp_transferencias t,
           ah_cta_vistas         a,
           ge_cta_clientes       c,
           ba_per_fisicas        p
     where t.fecha = pag_cal.fu_obt_fec_actual(1)
       and t.situacion = 'L'
       and t.estado = 'A'
       and t.fec_recepcion is not null
       and t.nro_cta_beneficiario = a.nro_cuenta
       and a.nro_cuenta = c.nro_cuenta
       and a.cod_modulo = c.cod_modulo
       and a.cod_modalidad = c.cod_modalidad
       and a.estado = 'N'
       and c.relacion = 'P'
       and c.cod_persona = p.cod_persona
       and t.nro_doc_solicitante != t.nro_doc_beneficiario
       and trunc(a.fec_insercion) > =
           to_date(fug_obt_pardinamico('FEC_APER_BLOQ_DEBITO'),
                   'dd/mm/yyyy')
     group by t.nro_cta_solicitante,
              t.nro_cta_beneficiario,
              a.cod_modulo,
              c.cod_persona,
              a.cod_modalidad,
              a.cod_oficina,
              a.cod_moneda,
              t.nro_cta_pte_solicitante
    having count(*) > 1;

BEGIN

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  for a in transferencias loop
    --Controla que la modalidad este habilitado para bloqueos de Debito por repetición de transacciones.
    IF nvl(fug_obt_pardinamico('IND_HAB_CON_TRANSFERENCIA',
                               a.cod_modulo,
                               a.cod_modalidad),
           'N') = 'S' THEN
      --Controla que no se repitan las transferencias con el mismo monto a una misma entidad y de iguales cuentras.
      if a.cantidad > fug_obt_pardinamico('CAN_TRA_BLOQ_CUENTA') then
        --Controla que no tenga contrato unico firmado para realizar el bloqueo.
        IF fug_val_con_uni_per(a.cod_persona) = 'N' THEN
          --Controla que desde la fecha de cambio de estado de Abierta a Normal no supere la cantidad de dia parametrizada.
          IF (pag_cal.FU_OBT_FEC_ACTUAL(a.cod_modulo) -
             fua_obt_fec_cam_est(a.nro_cta_beneficiario, 'A', 'N')) <=
             fug_obt_pardinamico('CON_CAN_DIA_POS_APE',
                                 a.cod_modulo,
                                 a.cod_modalidad) THEN
            --Controla si no tuvo desbloqueo de debito anteriormente
            IF fua_obt_fec_cam_est(a.nro_cta_beneficiario, 'N', 'D') is null THEN
              --Controla el limite parametrizado para el bloqueo.
              v_mto_limite := fug_obt_pardinamico('MTO_MAX_LIM_DIA_TRANSFE',
                                                  a.cod_modulo,
                                                  a.cod_modalidad);

              IF a.mto_transferido > v_mto_limite THEN
                --
                pag_cta.PR_OBT_CUENTA(a.nro_cta_beneficiario);
                v_est_anterior    := pag_cta.G_CTAS.estado;
                v_fec_cam_est_ant := pag_cta.g_ctas.fec_cam_estado;
                v_est_actual      := 'D';
                --
                v_fec_actual    := pag_cal.fu_obt_fec_actual(1);
                v_cod_mon_local := pag_gen.fu_obt_mon_local;
                v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,'HBANKF','N');
                v_nro_secuencia := 0;

                begin
                  select s_nro_bloqueo.nextval into v_nro_doc from dual;
                exception
                  when others then
                    v_nro_doc := null;
                end;
                --- Insertar movimiento de Cambio estado ( CAMBIO DE ESTADO-BLOQUEO DE SALDO (S))

                v_nro_secuencia := v_nro_secuencia + 1;
                v_lugar         := 'Genera_ge_movimientos CAMBIO DE ESTADO-BLOQUEO DE SALDO';

                r_gmovi.cod_usuario     := 'HBANKF';
                r_gmovi.hora            := v_hora;
                r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
                r_gmovi.cod_modulo      := a.cod_modulo;
                r_gmovi.cod_modalidad   := a.cod_modalidad;
                r_gmovi.cod_oficina     := a.cod_oficina;
                r_gmovi.nro_cuenta      := a.nro_cta_beneficiario;
                r_gmovi.cod_moneda      := a.cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.cod_tra_padre   := 307;
                r_gmovi.cod_transaccion := 409;
                r_gmovi.est_cuenta      := 'D';
                r_gmovi.estado          := 'N';
                r_gmovi.cod_ofi_origen  := a.cod_oficina;
                r_gmovi.reversado       := 'N';
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.protegido       := 'N';
                r_gmovi.cod_mod_padre   := a.cod_modulo;
                r_gmovi.cod_mad_padre   := a.cod_modalidad;
                r_gmovi.monto           := 0;
                r_gmovi.nro_documento   := v_nro_doc;
                r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO');
                r_gmovi.cod_tasa        := null;
                r_gmovi.val_tasa        := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi);

                v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,'HBANKF','N');
                v_nro_secuencia := v_nro_secuencia + 1;
                --- Insertar movimiento de Cambio estado ( CAMBIO DE ESTADO-BLOQUEO DE DEBITO(D))
                v_lugar                 := 'Genera_ge_movimientos CAMBIO DE ESTADO-BLOQUEO DE DEBITO';
                r_gmovi.cod_usuario     := 'HBANKF';
                r_gmovi.hora            := v_hora;
                r_gmovi.nro_secuencia   := nvl(v_nro_secuencia, 1);
                r_gmovi.cod_modulo      := a.cod_modulo;
                r_gmovi.cod_modalidad   := a.cod_modalidad;
                r_gmovi.cod_oficina     := a.cod_oficina;
                r_gmovi.nro_cuenta      := a.nro_cta_beneficiario;
                r_gmovi.cod_moneda      := a.cod_moneda;
                r_gmovi.fec_valor       := v_fec_actual;
                r_gmovi.fecha           := v_fec_actual;
                r_gmovi.cod_tra_padre   := 308;
                r_gmovi.cod_transaccion := 410;
                r_gmovi.est_cuenta      := 'D';
                r_gmovi.estado          := 'N';
                r_gmovi.cod_ofi_origen  := a.cod_oficina;
                r_gmovi.reversado       := 'N';
                r_gmovi.emi_aviso       := 'N';
                r_gmovi.protegido       := 'N';
                r_gmovi.cod_mod_padre   := a.cod_modulo;
                r_gmovi.cod_mad_padre   := a.cod_modalidad;
                r_gmovi.monto           := NULL;
                r_gmovi.nro_documento   := v_nro_doc;
                r_gmovi.cod_causa       := fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO');
                r_gmovi.cod_tasa        := null;
                r_gmovi.val_tasa        := null;
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
                v_lugar := 'Insercion de bloqueos';
                insert into ge_bloqueos
                  (nro_cuenta,
                   nro_documento,
                   fec_inicio,
                   hor_inicio,
                   cod_causa,
                   tipo,
                   observacion)
                values
                  (a.nro_cta_beneficiario,
                   v_nro_doc,
                   trunc(sysdate),
                   to_char(sysdate, 'HH24:MI:SS'),
                   fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO'),
                   'D',
                   'Bloqueo por exceso de transferencia');
                If sql%notfound then
                  raise_application_error(-20000,
                                          'Act estado cuenta,.bloqueos debitos' ||
                                          sqlerrm);

                End if;
                v_lugar := 'Actualiza el estado de la cuenta';
                --Actualiza el estado de la cuenta
                UPDATE ah_cta_vistas
                   SET estado         = 'D', --bloqueo debito
                       fec_cam_estado = trunc(sysdate)
                 WHERE nro_cuenta = a.nro_cta_beneficiario;
                if sql%found then
                  v_lugar := 'Notificacion de bloqueo de debito';
                  --Notificacion de bloqueo de debito
                  begin
                    if v_dir_correo is not null then
                      it_mail.mail(fug_obt_dir_correo,
                                   v_dir_correo,
                                   'Bloqueo por exceso de transferencia',
                                   'Se ha realizado un bloqueo por exceso de transferencia' ||
                                   chr(10) ||
                                   'Nro. de cuenta Beneficiario: ' ||
                                   a.nro_cta_beneficiario || chr(10) ||
                                   'Nro. de cuenta Solicitante: ' ||
                                   a.nro_cta_solicitante || chr(10) ||
                                   'Pte. Solicitante: ' ||
                                   a.nro_cta_pte_solicitante || chr(10) ||
                                   'Fecha: ' || sysdate);
                    end if;
                  exception
                    when others then
                      v_error := 'Error al momento de enviar correo.';
                  end;
                end if;
                --Actualiza la novedad
                v_lugar := 'Genera Novedad por cambio de Estado';
                BEGIN
                  UPDATE ge_cuentas_nov
                     SET est_anterior    = nvl(v_est_anterior,
                                               pag_cta.G_CTAS.estado),
                         est_actual      = nvl(v_est_actual,
                                               pag_cta.G_CTAS.estado),
                         fec_cam_est_ant = nvl(v_fec_cam_est_ant,
                                               pag_cta.g_ctas.fec_cam_estado)
                   WHERE cod_usuario = 'HBANKF'
                     AND fecha = v_fec_actual
                     AND hora = v_hora
                     AND nro_cuenta = a.nro_cta_beneficiario;
                  IF SQL%NOTFOUND THEN
                    INSERT INTO ge_cuentas_nov
                      (fecha,
                       hora,
                       cod_usuario,
                       nro_cuenta,
                       nro_detalle,
                       cod_modulo,
                       cod_modalidad,
                       est_anterior,
                       est_actual,
                       fec_cam_est_ant)
                    VALUES
                      (v_fec_actual,
                       v_hora,
                       'HBANKF',
                       a.nro_cta_beneficiario,
                       fug_obt_pardinamico('COD_CAUSA_BLOQ_DEBITO'),
                       a.cod_modulo,
                       a.cod_modalidad,
                       v_est_anterior,
                       v_est_actual,
                       v_fec_cam_est_ant);
                  END IF;
                EXCEPTION
                  WHEN no_data_found THEN
                    v_error := 'Error al momento de insertar novedades.';
                END;
              END IF;
            END IF;
          END IF;
        END IF;
      end if;
    END IF;
    commit;
  end loop;
exception
  when others then
    it.PRG_INS_LOG_PROGRAMAS('PRA_ACT_BLO_DEB_CUENTA',
                             v_error || ' ' || v_lugar || ' ' || SQLERRM,
                             null,
                             null);

END;
/

