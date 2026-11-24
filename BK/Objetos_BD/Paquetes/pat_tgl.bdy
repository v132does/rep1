create or replace package body it.pat_tgl IS

PROCEDURE pr_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_fec_actual     OUT DATE,
                           p_fec_valor      OUT DATE,
                           p_cod_error      OUT number,
                           p_men_error      OUT varchar2) is

    v_est_modulo ba_modulos.estado%TYPE;
  BEGIN
    p_cod_error  := v_pro_correcto;
    p_horario    := 'D'; -- Dia normal
    p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

    IF v_est_modulo IN (6) THEN
      ------- En cierre.
      p_cod_error := 1070;
      p_men_error := 'Proceso en cierre';
    ELSIF v_est_modulo = 2 THEN
      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
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
  END pr_ver_horario;
  /* procedimiento que habilita la tarjeta credito global */
  procedure pr_hab_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_cod_error   out number,
                           p_men_error   out varchar2) is
    v_url        varchar2(4000) := fug_obt_pardinamico('WS_HAB_TAR_CRE_GLO'); --url habilitacion de tarjeta de credito global;
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6) := 0;
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_HAB_TAR_CRE';
    v_cant         number;
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;
    v_cod_estado   ta_tarjetas.cod_estado%type;
  begin
    v_lugar := '01';
    --verifica si es una modalidad de la procesadora GLOBAL
    select count(*)
      into v_cant
      from ge_cuentas t
     where t.nro_cuenta = p_nro_cta
       and fug_obt_pardinamico('COD_MAD_TAR_CRE_GLO',
                               t.cod_modulo,
                               t.cod_modalidad) is not null;

    BEGIN
      SELECT a.cod_estado
        INTO v_cod_estado
        FROM ta_tarjetas a
       WHERE a.nro_cuenta = p_nro_cta
         AND a.nro_tarjeta = p_nro_tarjeta
         AND a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_err_ws := 1;
        v_men_error  := 'Error al consultar estado de la tarjeta';
    END;

    IF v_cod_estado = 6 THEN
      ----ya esta activa
      v_cod_err_ws := 2;
      v_men_error  := 'La tarjeta ya se encuentra Activa';
    ELSE
      v_cod_err_ws := 0;
    END IF;

    p_cod_error := v_cod_err_ws;
    p_men_error := v_men_error;

    IF v_cod_err_ws = 0 THEN
      if v_cant != 0 then
        v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                                 'NRO_CTA_TDC_GLOBAL'),
                            p_nro_cta);
        v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
        v_url        := replace(v_url, '{cardNumber}', p_nro_tarjeta);
        -- se crea la estructura json para pasar al ws
        v_content := null; -- numero de estado para la tarjeta
        v_lugar   := '02';

        pat_tgl.pr_ws_conector(v_content,
                               v_url,
                               null,
                               p_cod_persona,
                               'M',
                               'PATCH',
                               v_cod_err_ws,
                               v_men_error); -- llama al web service

        if v_cod_err_ws != v_cod_msg_exito THEN
          -- COD_MSG_EXITO 200
          p_cod_error := v_cod_err_ws;
          p_men_error := v_men_error;
        ELSE
          -- UPDATE estado 6 Activa si esta ok
          BEGIN
            pre_ini_aplicacion;
            pae_cnf.G_COD_MODULO := 1;
            pae_cnf.g_programa := 'GPPROFIN';
          END;
          UPDATE ta_tarjetas a
             SET a.cod_estado = 6
           WHERE a.nro_cuenta = p_nro_cta
             AND a.nro_tarjeta = p_nro_tarjeta
             AND a.cod_persona = p_cod_persona;

          commit;
          p_cod_error := v_cod_msg_exito;
          p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                             'Transaccion Exitosa!');
        end if;
      else
        p_cod_error := 999;
        p_men_error := 'Verifique parametro dinamico COD_MAD_TAR_CRE_GLO';
      end if;

    END IF;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_HAB_TAR_CRE. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- actualiza estado de tarjeta de debito y prepaga
  procedure pr_act_cta_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_estado      in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_url        varchar2(4000) := fug_obt_pardinamico('WS_EST_CTA_CRE_GLO'); --url cambio estado de la cuenta de tarjeta de credito global;
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_CTA_CRE';
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;

  begin
    v_lugar      := '01';
    v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                             'NRO_CTA_TDC_GLOBAL'),
                        p_nro_cta);
    v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    -- se crea la estructura json para pasar al ws
    --\"state\":0}
    v_content := '{' || '"state": ' || p_estado || '}'; -- numero de estado para la tarjeta
    v_lugar   := '02';

    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           p_nro_cta,
                           p_cod_persona,
                           'M',
                           'PATCH',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_CTA_CRE. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- actualiza estado de tarjeta de credito global
  procedure pr_act_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_estado      in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_url        varchar2(4000) := fug_obt_pardinamico('WS_EST_TAR_CRE_GLO'); --url cambio estado de la cuenta de tarjeta de credito global;
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_TAR_DEBPRE';
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;
  begin
    v_lugar := '01';

    v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                             'NRO_CTA_TDC_GLOBAL'),
                        p_nro_cta);
    v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    v_url        := replace(v_url, '{cardNumber}', p_nro_tarjeta);
    -- se crea la estructura json para pasar al ws
    v_content := '{' || '"state": ' || p_estado || '}'; -- numero de estado para la tarjeta
    v_lugar   := '02';

    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           null,
                           p_cod_persona,
                           'M',
                           'PATCH',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_TAR_DEBPRE. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- actualiza pin de tarjeta de credito global
  procedure pr_act_pin_tar(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_pin         in varchar2,
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_url        varchar2(4000) := fug_obt_pardinamico('WS_PIN_TAR_CRE_GLO'); --url cambio estado de la cuenta de tarjeta de credito global;
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_PIN_TAR';
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;

  begin
    v_lugar := '01';

    v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                             'NRO_CTA_TDC_GLOBAL'),
                        p_nro_cta);
    v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    v_url        := replace(v_url, '{cardNumber}', p_nro_tarjeta);
    -- se crea la estructura json para pasar al ws
    v_content := '{' || '"pin": "' || p_pin || '" }'; -- numero de estado para la tarjeta
    v_lugar   := '02';

    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           null,
                           p_cod_persona,
                           'M',
                           'POST',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_PIN_TAR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;
  --actualiza limite de tarjeta de credito
procedure pr_act_lim_tar(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                           p_cod_persona in ba_personas.cod_persona%type,
                           p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                           p_lim         in number,
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_url        varchar2(4000) := fug_obt_pardinamico('WS_LIM_TARJETA_CRE'); --url cambio estado de la cuenta de tarjeta de credito global;
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_LIM_TAR';
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;
    v_est_cliente varchar(2):=IT.FUG_OBT_PARENTES(it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL'),'GLP_EST_CLIENTE');
    v_cod_limite varchar(2):=IT.FUG_OBT_PARENTES(it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL'),'GLP_COD_LIMITE');
    v_cartera varchar(5):=IT.FUG_OBT_PARENTES(it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL'),'GLP_CARTERA_TC');
    v_limite number(20):=p_lim*100;
 begin
    v_lugar := '01';

    v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    -- se crea la estructura json para pasar al ws
    v_content :='{"status":"'||v_est_cliente||'",'||
    '"limitCode":"'||v_cod_limite||'",'||
    '"cartera":'||v_cartera||','||
    '"limits": [
    {
           "limitType":'||0||','||
           '"ammount":'||v_limite||'},'||
           '{"limitType":'||1||','||
           '"ammount":'||v_limite||'},'||
           '{"limitType":'||2||','||
           '"ammount":'||v_limite||--'},'||
           '}]}';
    v_lugar   := '02';
    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           null,
                           p_cod_persona,
                           'M',
                           'PUT',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_PIN_TAR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- actualiza pago de tarjeta de credito global
  procedure pr_act_pag_tar(p_nro_cta   in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto     in ta_cobros.monto%type,
                           p_fecha     in ta_cobros.fec_proceso%type,
                           p_hora      in ge_movimientos.hora%type,
                           p_usuario   in ge_movimientos.cod_usuario%type,
                           p_cod_error out number,
                           p_men_error out varchar2,
                           p_nro_cupon out number) is

    v_url varchar2(4000) := fug_obt_pardinamico('WS_PAG_TAR_CRE_GLO'); --url habilitacion de tarjeta de credito global;
    --http://fo-sandbox01-srv.lnx.elcomercio.local:4101/ms-credit-cards/accounts/123456/transactions/payment
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa    varchar2(50) := 'PAT_TGL.PR_ACT_PAG_TAR';
    v_cod_moneda      ge_cuentas.cod_moneda%type;
    v_fecha           varchar2(20);
    v_cod_modulo      ge_movimientos.cod_modulo%type;
    v_cod_modalidad   ge_movimientos.cod_modalidad%type;
    v_nro_documento   ge_movimientos.nro_documento%type;
    v_cod_oficina     ge_movimientos.cod_oficina%type;
    v_cod_transaccion ge_movimientos.cod_transaccion%type;
    v_tipo_pago       varchar2(100);
    v_movement        varchar2(5);
    v_cta_global      ge_cta_dat_adicionales.val_parametro%type;
  begin
    v_lugar := '01';

    begin
      select t.nro_documento,
             t.cod_oficina,
             t.cod_transaccion,
             t.cod_moneda,
             t.COD_MODULO,
             t.cod_modalidad
        into v_nro_documento,
             v_cod_oficina,
             v_cod_transaccion,
             v_cod_moneda,
             v_cod_modulo,
             v_cod_modalidad
        from gv_movimientos t
       where t.nro_cuenta = p_nro_cta
         and t.cod_usuario = p_usuario
         and t.hora = p_hora
         and t.fecha = p_fecha;
    exception
      when others then
        v_tipo_pago       := 'NO_INFORMADA';
        v_cod_moneda      := v_cod_mon_local;
        v_cod_oficina     := 1;
        v_nro_documento   := 1;
        v_cod_transaccion := 601;
    end;

    if v_cod_transaccion = 690 then
      v_tipo_pago := 'EFECTIVO';
    elsif v_cod_transaccion = 607 then
      v_tipo_pago := 'CHEQUE_AL_DIA';
    else
      v_tipo_pago := 'NO_INFORMADA';
    end if;

    v_movement := nvl(fug_obt_pardinamico('COD_MAD_TAR_CRE_GLO',
                                          v_cod_modulo,
                                          v_cod_modalidad),
                      '601');

    v_fecha      := to_char(to_date(to_char(p_fecha, 'YYYY-MM-DD')||' '||p_hora,'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS');--to_char(p_fecha, 'yyyy-mm-dd');
    v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                             'NRO_CTA_TDC_GLOBAL'),
                        p_nro_cta);
    v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    -- se crea la estructura json para pasar al ws
    v_content := '{
                     "amount": {
                        "currency": "' || v_cod_moneda || '",
                        "quantity": ' || p_monto || ' ' || '},
                     "paymentReceipt": "' ||
                 v_nro_documento || '",
                     "formOfPayment": "' || v_tipo_pago || '",
                     "branchCode": ' || v_cod_oficina || ',
                     "observation": "Pago Tarjeta ' ||
                 p_nro_cta || '",
                     "movement": ' || v_movement || ' ,
                     "paymentDate": "' || v_fecha || '"
                     }';
    v_lugar   := '02';

    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           p_nro_cta,
                           p_hora,
                           'M',
                           'POST',
                           v_cod_err_ws,
                           v_men_error,
                           p_nro_cupon); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_PAG_TAR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_nro_cta,
                            p_nro_cta);
  end;
  -- Generacion JSON p/ llamada a pagos de TC GP
  procedure pr_jsn_pag_tar(p_nro_cta   in ta_cta_tarjetas.nro_cuenta%type,
                           p_monto     in ta_cobros.monto%type,
                           p_fecha     in ta_cobros.fec_proceso%type,
                           p_hora      in ge_movimientos.hora%type,
                           p_usuario   in ge_movimientos.cod_usuario%type,
                           p_cod_error out number,
                           p_men_error out varchar2,
                           p_nro_cupon out number) is

   -- v_url varchar2(4000) := fug_obt_pardinamico('WS_PAG_TAR_CRE_GLO'); --url habilitacion de tarjeta de credito global;
    --http://fo-sandbox01-srv.lnx.elcomercio.local:4101/ms-credit-cards/accounts/123456/transactions/payment
    v_content    varchar2(4000);
    v_lugar      varchar2(10);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_nom_programa    varchar2(50) := 'PAT_TGL.PR_JSN_PAG_TAR';
    v_cod_moneda      ge_cuentas.cod_moneda%type;
    v_fecha           varchar2(20);
    v_cod_modulo      ge_movimientos.cod_modulo%type;
    v_cod_modalidad   ge_movimientos.cod_modalidad%type;
    v_nro_documento   ge_movimientos.nro_documento%type;
    v_cod_oficina     ge_movimientos.cod_oficina%type;
    v_cod_transaccion ge_movimientos.cod_transaccion%type;
    v_tipo_pago       varchar2(100);
    v_movement        varchar2(5);
    v_cta_global      ge_cta_dat_adicionales.val_parametro%type;
  begin
    v_lugar := '01';

    begin
      select t.nro_documento,
             t.cod_oficina,
             t.cod_transaccion,
             t.cod_moneda,
             t.COD_MODULO,
             t.cod_modalidad
        into v_nro_documento,
             v_cod_oficina,
             v_cod_transaccion,
             v_cod_moneda,
             v_cod_modulo,
             v_cod_modalidad
        from gv_movimientos t
       where t.nro_cuenta = p_nro_cta
         and t.cod_usuario = p_usuario
         and t.hora = p_hora
         and t.fecha = p_fecha;
    exception
      when others then
        v_tipo_pago       := 'NO_INFORMADA';
        v_cod_moneda      := v_cod_mon_local;
        v_cod_oficina     := 1;
        v_nro_documento   := 1;
        v_cod_transaccion := 601;
    end;

    if v_cod_transaccion = 690 then
      v_tipo_pago := 'EFECTIVO';
    elsif v_cod_transaccion = 607 then
      v_tipo_pago := 'CHEQUE_AL_DIA';
    else
      v_tipo_pago := 'NO_INFORMADA';
    end if;

    v_movement := nvl(fug_obt_pardinamico('COD_MAD_TAR_CRE_GLO',
                                          v_cod_modulo,
                                          v_cod_modalidad),
                      '601');

    v_fecha      := to_char(to_date(to_char(p_fecha, 'YYYY-MM-DD')||' '||p_hora,'YYYY-MM-DD HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS');--to_char(p_fecha, 'yyyy-mm-dd');
    v_cta_global := nvl(FUG_OBT_PARADICIONAL(p_nro_cta,
                                             'NRO_CTA_TDC_GLOBAL'),
                        p_nro_cta);
    --v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
    -- se crea la estructura json para pasar al ws
    v_content := '{
                     "amount": {
                        "currency": "' || v_cod_moneda || '",
                        "quantity": ' || p_monto || ' ' || '},
                     "paymentReceipt": "' ||
                 v_nro_documento || '",
                     "formOfPayment": "' || v_tipo_pago || '",
                     "branchCode": ' || v_cod_oficina || ',
                     "observation": "Pago Tarjeta ' ||
                 p_nro_cta || '",
                     "movement": ' || v_movement || ' ,
                     "paymentDate": "' || v_fecha || '"
                     }';
    v_lugar   := '02';

    /*pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           p_nro_cta,
                           p_hora,
                           'M',
                           'POST',
                           v_cod_err_ws,
                           v_men_error,
                           p_nro_cupon); -- llama al web service*/
    if v_content is null then
      v_cod_err_ws:='999';
      p_men_error:='Error al generar JSON';
    end if;

    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := v_content;/*nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');*/
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_JSN_PAG_TAR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_nro_cta,
                            p_nro_cta);
  end;
  -- llama al web service de acuerdo a la accion solicitada
  procedure pr_ws_conector(p_content     in varchar2, -- estructura jason
                           p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                           p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                           p_cod_persona in varchar2, -- cod persona del cliente
                           p_accion      in varchar2, -- si es cambio de estado o alta
                           p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_req        utl_http.req;
    v_res        utl_http.resp;
    v_buffer     varchar2(4000);
    v_lugar      varchar2(10) default '00';
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
    v_nom_programa   varchar2(50) := 'PAT_TGL.PR_WS_CONECTOR';
    v_content    VARCHAR2(4000);
    v_file       VARCHAR2(200):= fug_obt_pardinamico('WS_URL_TAR_WALLET');

  BEGIN
    UTL_HTTP.set_wallet(v_file,null);
    --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 60seg.
    UTL_HTTP.SET_TRANSFER_TIMEOUT(to_number(v_can_max_espera));
    p_cod_error := v_pro_correcto;

    --solicitud ws
    if p_accion = 'M' then
      --modificacion de estado 'PUT'
      v_lugar := '01';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');

    elsif p_accion = 'A' then
      --alta de cuenta en global y alta de tarjeta 'POST'
      v_lugar := '02';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');

    end if;

    v_lugar := '03';

    if p_content is not null THEN
      --Se eliminan espacios de mas y saltos de linea
      v_content:= TRIM(REPLACE(REPLACE(REPLACE(REPLACE(p_content,CHR(10),' ') ,CHR(13),' '),CHR(9),' ') ,'  ',' '));
      UTL_HTTP.SET_BODY_CHARSET(v_req, 'UTF-8');
      utl_http.set_header(v_req, 'Content-Type', 'application/json');
      utl_http.set_header(v_req, 'Content-Length', LENGTHB(CONVERT(v_content, 'UTF8')));
      utl_http.write_text(v_req, v_content);
    end if;

    --respuesta ws
    v_lugar := '04';
    v_res   := utl_http.get_response(v_req);
    ---obtiene el codigo de respuesta
    v_lugar      := '05';
    v_cod_err_ws := v_res.status_code;

    --obtiene los datos del WS
    v_lugar := '06';
    utl_http.read_line(v_res, v_buffer);

    --se guarda la repuesta obtenida
    v_lugar     := '07';
    v_men_error := v_buffer;
    v_lugar     := '08';
    utl_http.end_response(v_res);
    v_lugar     := '09';
    p_men_error := v_men_error;

    if v_cod_err_ws != v_cod_msg_exito then
      /*      v_lugar     := '10';*/
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            substr('1) Lugar: ' || v_lugar || ' - ' ||
                                   v_cod_err_ws || ' - ' || p_men_error,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
    else
      v_lugar     := '11';
      p_cod_error := v_cod_err_ws;
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || ' - Url: ' || p_url ||
                            ' - WS_Err_Desc : ' ||
                            utl_http.get_detailed_sqlerrm ||
                            ' - Error en PR_WS_CONECTOR: ' || sqlerrm,
                            1,
                            4000);

      utl_http.end_response(v_res);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            p_cod_persona,
                            p_nro_cta);
  end;
  procedure pr_ws_conector(p_content     in varchar2, -- estructura jason
                           p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                           p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                           p_cod_persona in varchar2, -- cod persona del cliente
                           p_accion      in varchar2, -- si es cambio de estado o alta
                           p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                           p_cod_error   out number,
                           p_men_error   out varchar2,
                           p_nro_cupon   out number) is

    v_req        utl_http.req;
    v_res        utl_http.resp;
    v_buffer     varchar2(4000);
    v_lugar      varchar2(10) default '00';
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
    v_nom_programa   varchar2(50) := 'PAT_TGL.PR_WS_CONECTOR';
    l_json_response JSON_OBJECT_T;
    v_content VARCHAR2(4000);
    v_file            VARCHAR2(200):= fug_obt_pardinamico('WS_URL_TAR_WALLET');
  begin
    UTL_HTTP.set_wallet(v_file,null);
    --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 60seg.
    UTL_HTTP.SET_TRANSFER_TIMEOUT(to_number(v_can_max_espera));
    p_cod_error := v_pro_correcto;

    --solicitud ws
    if p_accion = 'M' then
      --modificacion de estado 'PUT'
      v_lugar := '01';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');

    elsif p_accion = 'A' then
      --alta de cuenta en global y alta de tarjeta 'POST'
      v_lugar := '02';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');

    end if;

    v_lugar := '03';

    if p_content is not null THEN
      --Se eliminan espacios de mas y saltos de linea
      v_content:= TRIM(REPLACE(REPLACE(REPLACE(REPLACE(p_content,CHR(10),' ') ,CHR(13),' '),CHR(9),' ') ,'  ',' '));
      UTL_HTTP.SET_BODY_CHARSET(v_req, 'UTF-8');
      utl_http.set_header(v_req, 'Content-Type', 'application/json');
      utl_http.set_header(v_req, 'Content-Length', length(v_content));
      utl_http.write_text(v_req, v_content);
    end if;

    --respuesta ws
    v_lugar := '04';
    v_res   := utl_http.get_response(v_req);

    ---obtiene el codigo de respuesta
    v_lugar      := '05';
    v_cod_err_ws := v_res.status_code;

    --obtiene los datos del WS
    v_lugar := '06';
    utl_http.read_line(v_res, v_buffer);

    --se guarda la repuesta obtenida
    v_lugar     := '07';
    v_men_error := v_buffer;
    v_lugar     := '08';
    utl_http.end_response(v_res);
    v_lugar     := '09';
    p_men_error := v_men_error;

    if v_cod_err_ws != v_cod_msg_exito then
      /*      v_lugar     := '10';*/
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            substr('1) Lugar: ' || v_lugar || ' - ' ||
                                   v_cod_err_ws || ' - ' || p_men_error,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
    else
      v_lugar:='10';
      l_json_response := json_object_t.Parse(v_buffer);
      p_nro_cupon     := l_json_response.get_Number('confirmationCode');
      v_lugar     := '11';
      p_cod_error := v_cod_err_ws;
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || ' - Url: ' || p_url ||
                            ' - WS_Err_Desc : ' ||
                            utl_http.get_detailed_sqlerrm ||
                            ' - Error en PR_WS_CONECTOR: ' || sqlerrm,
                            1,
                            4000);

      utl_http.end_response(v_res);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- genera el pin de 4 digitos para la tarjeta
  procedure pr_gen_pin(p_cod_persona in varchar2, -- cod persona del cliente
                       p_nro_pin     out varchar2, -- pin generado para el cliente
                       p_cod_error   out number,
                       p_men_error   out varchar2) is
    v_nro_pin     varchar2(4) := '';
    v_pin         number := 0;
    v_cod_persona number := 1000;
  begin
    p_cod_error := 0;
    --1er digito
    v_pin     := round(dbms_random.value(0, 10));
    v_nro_pin := v_nro_pin || substr(to_char(v_pin), 1, 1);
    --2do digito
    v_pin := floor(dbms_random.value(0, 10));
    if v_pin != 0 then
      v_pin := round(to_number(to_char(sysdate, 'j')) / v_pin);
    end if;
    v_nro_pin := v_nro_pin || substr(to_char(v_pin), 1, 1);
    --3er digito
    if v_cod_persona > p_cod_persona then
      v_cod_persona := round(dbms_random.value(1000, 9999));
    else
      v_cod_persona := p_cod_persona;
    end if;
    v_pin     := MOD(Round(DBMS_RANDOM.Value(0, 10)), v_cod_persona);
    v_nro_pin := v_nro_pin || substr(to_char(v_pin), 1, 1);
    --4to digito
    v_pin     := round(v_cod_persona /
                       (floor(dbms_random.value(0, 10)) + 1));
    v_pin     := v_pin / (round(dbms_random.value(0, 10)) + 1);
    v_pin     := round(dbms_random.value(0, v_pin));
    v_nro_pin := v_nro_pin || substr(to_char(v_pin), 1, 1);
    ----
    p_nro_pin := v_nro_pin;
  exception
    when others then
      p_cod_error := SQLCODE;
      p_men_error := 'Error - ' || sqlerrm;
  end;
  -- realiza el debito de la cuenta ahorro/cte para realizar el pago de la tarjeta de credito
  -- este pr se llama del servicio http://fo-sandbox01-srv.lnx.elcomercio.local:4101/ms-credit-cards/9876/accounts/123456/payment

  FUNCTION fu_obt_hora(p_ind_usuario number) return varchar2 is
    v_hora ge_movimientos.hora%type;
    v_nro_sec number;
    v_nro_hor number;
  BEGIN

    v_nro_sec := fue_obt_sig_secuencia('s_nro_hora'||p_ind_usuario);

    if v_nro_sec <= 86400 then
      v_nro_hor := v_nro_sec;
    else
      v_nro_hor := mod(v_nro_sec, 86400);
    end if;

    v_hora := TO_CHAR(trunc(v_nro_hor/3600), 'FM9900')|| ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor,3600)/60),'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor,60),'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;

  procedure pr_act_usu_actual(p_cod_usuario ba_usuarios.cod_usuario%type) is
    pragma AUTONOMOUS_TRANSACTION;
  begin
    update ge_par_dinamicos
       set val_parametro = p_cod_usuario
     where parametro = 'USU_PAG_ACTUAL';
     commit;
  exception
    when others then
      raise_application_error(-20000, 'No se puede actualizar el usuario actual. ' || sqlerrm);
  end;

   procedure pr_pag_tar_cre(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                             p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                             p_nro_cta_deb in ta_cta_tarjetas.nro_cuenta%type,
                             p_monto       in ta_cobros.monto%type,
                             p_cod_canal   in varchar2 default 'N',
                             p_cod_error   out number,
                             p_men_error   out varchar2) is

      v_cod_modalidad  ge_cta_clientes.cod_modalidad%type;
      v_cta_tarjeta    ta_tarjetas.nro_cuenta%type;
      v_nro_tarjeta    ta_tarjetas.nro_tarjeta%type;
      v_nro_caja       cj_cajas.nro_caja%type;
      v_cdusuar        ge_movimientos.cod_usuario%type;
      v_cod_ofi_origen ge_movimientos.cod_oficina%type := fug_obt_pardinamico('COD_OFI_WEB');
      v_cod_oficina    ge_movimientos.cod_oficina%type;
      v_fec_actual     ge_movimientos.fecha%type;
      v_dia_mora       ta_cta_tarjetas.dia_mora%type;
      v_hora           ge_movimientos.hora%type := to_char(sysdate,
                                                           'HH24:MI:SS');
      r_gmovi          ge_movimientos%rowtype;
      v_nro_secuencia  ge_movimientos.nro_secuencia%type := 0;
      v_cod_modulo     ge_movimientos.cod_modulo%type;
      v_cod_moneda     ge_movimientos.cod_moneda%type;
      v_impuesto       ge_movimientos.monto%type;
      v_mon_deb        ge_movimientos.cod_moneda%type;
      v_cod_persona    ba_personas.cod_persona%type;
      v_lugar          varchar2(10);
      v_existe         number;
      v_horario        varchar2(1);
      v_es_mov_noc     varchar2(1) := 'N';
      v_es_cta_noc     varchar2(1);
      v_fec_valor      ge_calendarios.fec_actual%type;
      v_nro_documento  ge_movimientos.nro_documento%TYPE;
      v_existe_conj    number;
      v_nom_programa   VARCHAR2(50):= 'PAT_TGL.PR_PAG_TAR_CRE';

    begin
      p_cod_error := 0;
      p_men_error := 'Operacion Exitosa';
      begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
      end;
      -- Obtiene datos de la tarjeta
      v_lugar := '1 - ';
      begin
        select cta.cod_modalidad,
               tar.nro_cuenta,
               tar.nro_tarjeta,
               cta.dia_mora,
               cta.cod_modulo,
               cta.cod_moneda,
               cli.cod_persona,
               cta.cod_oficina
          into v_cod_modalidad,
               v_cta_tarjeta,
               v_nro_tarjeta,
               v_dia_mora,
               v_cod_modulo,
               v_cod_moneda,
               v_cod_persona,
               v_cod_oficina
          from ge_cta_clientes cli, ta_tarjetas tar, ta_cta_tarjetas cta
         where cli.nro_cuenta = tar.nro_cuenta
           and relacion = 'P'
           and vigente = 'S'
           and tar.nro_cuenta = p_nro_cta
           and tar.nro_tarjeta = p_nro_tarjeta
           and tar.cod_estado <> 10
           and tar.nro_cuenta = cta.nro_cuenta;
      exception
        when others then
          p_cod_error := SQLCODE;
          p_men_error := v_lugar || substr(SQLERRM, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                substr(v_lugar || p_nro_cta || ' ' || SQLERRM,
                                       1,
                                       4000),
                                null,
                                p_nro_cta);
      end;
      select count(*)
        into v_existe
        from ge_cta_clientes t
       where t.cod_persona = v_cod_persona
         and t.nro_cuenta = p_nro_cta_deb
         and t.relacion IN ('P','O');
      if v_existe = 0 then
        p_cod_error := 999;
        p_men_error := 'La cuenta debito debe ser del cliente';
      end if;
      select count(*)
        into v_existe_conj
        from ge_cta_clientes t
       where t.nro_cuenta = p_nro_cta_deb
         and t.relacion = 'Y';
      if nvl(v_existe_conj,0) > 0 then
        p_cod_error := 1000;
        p_men_error := 'La cuenta seleccionada se encuentra inhabilitada para pagos';
      end if;
      if p_cod_error = 0 then
        -- verifica el usuario de plataforma
        v_lugar := '2 - ';
        if p_cod_canal in ('W', 'M') then
          prw_obt_dat_caja(p_cod_canal,
                           v_nro_caja,
                           v_cod_oficina,
                           v_cdusuar,
                           p_cod_error,
                           p_men_error);
        else
          v_cdusuar := substr(user, 1, 10);
        end if;

        PR_VER_HORARIO(v_cod_oficina,
                       v_horario,
                       v_es_mov_noc,
                       v_es_cta_noc,
                       v_fec_actual,
                       v_fec_valor,
                       p_cod_error,
                       p_men_error);

        if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' and v_es_mov_noc = 'S' then
          p_cod_error := '1070';
          p_men_error := 'Modulo en proceso de cierre';
        end if;

        v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');

        if p_cod_error != 0 then
          prg_ins_log_programas(v_nom_programa,
                                substr(v_lugar || p_nro_cta || ' ' ||
                                       p_men_error,
                                       1,
                                       4000),
                                null,
                                p_nro_cta);
        else
          --obtiene la fecha para el cobro y movimiento
          --v_fec_actual := pae_cnf.fu_obt_fec_actual(5);--(v_cod_modalidad)

         /* v_lugar := '3 - ';
          begin
            --inserta el registro de cobro
            insert into ta_cobros
              (nro_cuenta,
               nro_tarjeta,
               monto,
               estado,
               observacion,
               fec_proceso,
               fec_valor,
               dia_mora,
               hora,
               cod_usuario)
            values
              (v_cta_tarjeta,
               v_nro_tarjeta,
               p_monto,
               'P',
               'Procesado desde Plataforma',
               v_fec_valor,
               v_fec_actual,
               v_dia_mora,
               v_hora,
               user);
          exception
            when others then
              p_cod_error := SQLCODE;
              p_men_error := substr(SQLERRM, 1, 4000);
              prg_ins_log_programas('PAT_TGL.PR_PAG_TAR_CRE',
                                    substr(v_lugar || p_nro_cta || ' ' ||
                                           SQLERRM,
                                           1,
                                           4000),
                                    null,
                                    p_nro_cta);
          end;*/
          if p_cod_error = 0 then
            v_lugar := '4 - ';
            --Busco el nro_documento para asignar al movimiento
            SELECT to_number(s_nro_ref_documento.nextval)
            --to_number(to_char(v_fec_actual,'RRMMDD') || s_nro_ref_documento.nextval)
              INTO v_nro_documento
              FROM dual;

            SAVEPOINT pago;

            BEGIN
              --Generar el movimiento por el credito
              r_gmovi.cod_usuario := user;
              r_gmovi.hora        := v_hora;
              r_gmovi.fecha       := v_fec_actual;
              -- Aumento la secuencia
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_valor;
              r_gmovi.cod_tra_padre   := 250;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := 978;
              r_gmovi.monto           := p_monto;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.nro_cuenta      := v_cta_tarjeta;
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Credito de tarjetas';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';

              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            exception
              when others then
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      null,
                                      p_nro_cta);
            end;
          end if;
          pag_cta.pr_set_est_movimiento('N'); -- movimiento confirmado normal
          --calcula impuesto si corresponde y genera movimiento
          select t.cod_moneda
            into v_mon_deb
            from ge_cuentas t
           where t.nro_cuenta = p_nro_cta_deb;
          if p_cod_error = 0 then
            begin
              v_lugar := '5 - ';
              prg_ver_cob_cargos(p_nro_cta_deb,
                                 v_cta_tarjeta,
                                 v_cod_modulo, --cod_mod_padre
                                 v_cod_modalidad, --o abmc.modalidad       --cod_mad_padre
                                 v_cod_oficina,
                                 v_mon_deb,
                                 p_monto,
                                 'Cobro de Tarjeta ' || v_cta_tarjeta,
                                 v_nro_documento,
                                 v_fec_actual,
                                 v_hora,
                                 v_impuesto,
                                 v_nro_secuencia,
                                 'S'); --procesar
            exception
              when others then
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      null,
                                      p_nro_cta);
            end;
          end if;
          if nvl(v_impuesto, 0) > 0 then
            --aumentar la secuencia
            v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
          end if;
          if p_cod_error = 0 then
            begin
              v_lugar := '6 - ';
                -- Actualiza la Cuenta Debito / Destino
              pag_cta.pr_act_operacion(p_nro_cta_deb,
                                       v_hora, --HORA
                                       'D',
                                       v_mon_deb, --Moneda de la Operacion
                                       p_monto + nvl(v_impuesto, 0),
                                       250, -- COD_TRA_PADRE
                                       503, -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                                       v_nro_documento, --nro_documento --antes era en nro_documento2
                                       null, --COTIZACION, los pagos son en moneda local
                                       v_cod_ofi_origen, --cod_ofi_origen
                                       v_cod_modulo, --cod_mod_padre
                                       v_cod_modalidad, --o abmc.modalidad       --cod_mad_padre
                                       null, --cod_tasa
                                       null, --val_tasa
                                       'Cobro de Tarjetas ' || v_cta_tarjeta,
                                       'S', --emi_aviso
                                       v_nro_secuencia,
                                       v_fec_valor);

              if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
                p_cod_error := pag_cta.G_COD_ERROR;
                p_men_error := substr(pag_cta.G_MSJ_ERROR, 1, 4000);
                ROLLBACK TO pago;
              end if;
            exception
              when others then
                ROLLBACK TO pago;
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      null,
                                      p_nro_cta);
            end;
          end if;

          /*Una vez que se registra el debito e insertan los movimientos, se inserta en TA_COBROS*/
          if p_cod_error = 0 then
            v_lugar := '3 - ';
            if fut_obt_procesadora(v_cta_tarjeta) = fug_obt_pardinamico('COD_ENT_GLOBAL') then
              begin
              --inserta el registro de cobro
                insert into ta_cobros_gp
                       (nro_cuenta,
                       nro_tarjeta,
                       nro_cta_debito,
                       monto,
                       estado,
                       observacion,
                       fec_proceso,
                       fec_valor,
                       dia_mora,
                       hora,
                       cod_usuario,
                       canal)
                values
                       (v_cta_tarjeta,
                       v_nro_tarjeta,
                       p_nro_cta_deb,
                       p_monto,
                       'P',
                       'Procesado desde Plataforma',
                       v_fec_actual,
                       v_fec_valor,
                       v_dia_mora,
                       v_hora,
                       user,
                       p_cod_canal);
              exception
                when others then
                  p_cod_error := SQLCODE;
                  p_men_error := substr(SQLERRM, 1, 4000);
                  prg_ins_log_programas(v_nom_programa,
                                        substr(v_lugar || p_nro_cta || ' ' ||
                                        SQLERRM,
                                        1,
                                        4000),
                                        null,
                                        p_nro_cta);
              end;
            else
              begin
              --inserta el registro de cobro
                insert into ta_cobros
                       (nro_cuenta,
                       nro_tarjeta,
                       nro_cta_debito,
                       monto,
                       estado,
                       observacion,
                       fec_proceso,
                       fec_valor,
                       dia_mora,
                       hora,
                       cod_usuario)
                values
                       (v_cta_tarjeta,
                       v_nro_tarjeta,
                       p_nro_cta_deb,
                       p_monto,
                       'P',
                       'Procesado desde Plataforma',
                       v_fec_actual,
                       v_fec_valor,
                       v_dia_mora,
                       v_hora,
                       user);
              exception
                when others then
                  p_cod_error := SQLCODE;
                  p_men_error := substr(SQLERRM, 1, 4000);
                  prg_ins_log_programas(v_nom_programa,
                                        substr(v_lugar || p_nro_cta || ' ' ||
                                        SQLERRM,
                                        1,
                                        4000),
                                        null,
                                        p_nro_cta);
              end;
            end if;
          end if;

          if p_cod_error = 0 then
            v_lugar := '7 - ';
            begin
              prg_gen_comprobantes('PT',
                                   v_fec_actual,
                                   v_hora,
                                   v_nro_secuencia,
                                   user,
                                   'Pago de tarjeta ' || v_cta_tarjeta,
                                   null,
                                   v_cod_moneda,
                                   p_monto + nvl(v_impuesto, 0),
                                   v_cod_persona,
                                   p_nro_cta_deb,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   v_cta_tarjeta,
                                   null,
                                   v_nro_tarjeta,
                                   null,
                                   null,
                                   v_cdusuar,
                                   'Debito en cta. ' || p_nro_cta_deb ||
                                   ' por pago de tarjeta ' || v_nro_tarjeta,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null);
            exception
              when others then
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      null,
                                      p_nro_cta);
            end;
          end if;
        end if;
      end if;
    end;
  -- realiza el debito de la cuenta ahorro/cte para realizar el pago de la tarjeta de credito,retorna doc y fecha para servicio
  -- este pr se llama del servicio http://fo-sandbox01-srv.lnx.elcomercio.local:4101/ms-credit-cards/9876/accounts/123456/payment
   procedure pr_pag_tar_cre_doc(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                             p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                             p_nro_cta_deb in ta_cta_tarjetas.nro_cuenta%type,
                             p_monto       in ta_cobros.monto%type,
                             p_cod_canal   in varchar2 default 'N',
                             p_cod_error   out number,
                             p_men_error   out varchar2,
                             p_nro_documento out varchar2,
                             p_fec_mov      out varchar2) is

      v_cod_modalidad  ge_cta_clientes.cod_modalidad%type;
      v_cta_tarjeta    ta_tarjetas.nro_cuenta%type;
      v_nro_tarjeta    ta_tarjetas.nro_tarjeta%type;
      v_nro_caja       cj_cajas.nro_caja%type;
      v_cdusuar        ge_movimientos.cod_usuario%type;
      v_cod_ofi_origen ge_movimientos.cod_oficina%type := fug_obt_pardinamico('COD_OFI_WEB');
      v_cod_oficina    ge_movimientos.cod_oficina%type;
      v_fec_actual     ge_movimientos.fecha%type;
      v_dia_mora       ta_cta_tarjetas.dia_mora%type;
      v_hora           ge_movimientos.hora%type := to_char(sysdate,
                                                           'HH24:MI:SS');
      r_gmovi          ge_movimientos%rowtype;
      v_nro_secuencia  ge_movimientos.nro_secuencia%type := 0;
      v_cod_modulo     ge_movimientos.cod_modulo%type;
      v_cod_moneda     ge_movimientos.cod_moneda%type;
      v_impuesto       ge_movimientos.monto%type;
      v_mon_deb        ge_movimientos.cod_moneda%type;
      v_cod_persona    ba_personas.cod_persona%type;
      v_lugar          varchar2(10);
      v_existe         number;
      v_horario        varchar2(1);
      v_es_mov_noc     varchar2(1) := 'N';
      v_es_cta_noc     varchar2(1);
      v_fec_valor      ge_calendarios.fec_actual%type;
      v_nro_documento  ge_movimientos.nro_documento%TYPE;
      v_existe_conj    number;
      v_nom_programa   VARCHAR2(50):= 'PAT_TGL.PR_PAG_TAR_CRE_DOC';
      v_cod_usuario    ba_usuarios.cod_usuario%type;
      v_ind_usuario    number;

    begin
      p_cod_error := 0;
      p_men_error := 'Operacion Exitosa';
      begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
      end;
      -- Obtiene datos de la tarjeta
      v_lugar := '1 - ';
      begin
        select cta.cod_modalidad,
               tar.nro_cuenta,
               tar.nro_tarjeta,
               cta.dia_mora,
               cta.cod_modulo,
               cta.cod_moneda,
               cli.cod_persona,
               cta.cod_oficina
          into v_cod_modalidad,
               v_cta_tarjeta,
               v_nro_tarjeta,
               v_dia_mora,
               v_cod_modulo,
               v_cod_moneda,
               v_cod_persona,
               v_cod_oficina
          from ge_cta_clientes cli, ta_tarjetas tar, ta_cta_tarjetas cta
         where cli.nro_cuenta = tar.nro_cuenta
           and relacion = 'P'
           and tar.nro_cuenta = p_nro_cta
           and tar.nro_tarjeta = p_nro_tarjeta
           and tar.nro_cuenta = cta.nro_cuenta
           AND cta.estado != 'C'
           AND EXISTS (SELECT 1 FROM ta_tipos tip
                        WHERE tip.cod_modulo = cta.cod_modulo
                          AND tip.cod_modalidad = cta.cod_modalidad
                          AND tip.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL'));
      exception
        when others then
          p_cod_error := SQLCODE;
          p_men_error := v_lugar || substr(SQLERRM, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                substr(v_lugar || p_nro_cta || ' ' || SQLERRM,
                                       1,
                                       4000),
                                v_cod_persona,
                                p_nro_cta);
      end;
      select count(*)
        into v_existe
        from ge_cta_clientes t
       where t.cod_persona = v_cod_persona
         and t.nro_cuenta = p_nro_cta_deb
         and t.relacion IN ('P','O');
      if v_existe = 0 then
        p_cod_error := 999;
        p_men_error := 'La cuenta debito debe ser del cliente';
      end if;
      select count(*)
        into v_existe_conj
        from ge_cta_clientes t
       where t.nro_cuenta = p_nro_cta_deb
         and t.relacion = 'Y';
      if nvl(v_existe_conj,0) > 0 then
        p_cod_error := 1000;
        p_men_error := 'La cuenta seleccionada se encuentra inhabilitada para pagos';
      end if;
      if p_cod_error = 0 then
        -- verifica el usuario de plataforma
        v_lugar := '2 - ';
        if p_cod_canal in ('W', 'M') then
          prw_obt_dat_caja(p_cod_canal,
                           v_nro_caja,
                           v_cod_oficina,
                           v_cdusuar,
                           p_cod_error,
                           p_men_error);
        else
          v_cdusuar := substr(user, 1, 10);
        end if;

        PR_VER_HORARIO(v_cod_oficina,
                       v_horario,
                       v_es_mov_noc,
                       v_es_cta_noc,
                       v_fec_actual,
                       v_fec_valor,
                       p_cod_error,
                       p_men_error);

        if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' and v_es_mov_noc = 'S' then
          p_cod_error := '1070';
          p_men_error := 'Modulo en proceso de cierre';
        end if;


        v_cod_usuario   := it.fug_obt_mov_user('CREDCARDMS','S_SER_USER_CREDCARDMS');
        v_ind_usuario   := to_number(substr(v_cod_usuario,10,2));
        v_hora          := fu_obt_hora(v_ind_usuario);

        if p_cod_error != 0 then
          prg_ins_log_programas(v_nom_programa,
                                substr(v_lugar || p_nro_cta || ' ' ||
                                       p_men_error,
                                       1,
                                       4000),
                                v_cod_persona,
                                p_nro_cta);
        else
          --obtiene la fecha para el cobro y movimiento
          --v_fec_actual := pae_cnf.fu_obt_fec_actual(5);--(v_cod_modalidad)

         /* v_lugar := '3 - ';
          begin
            --inserta el registro de cobro
            insert into ta_cobros
              (nro_cuenta,
               nro_tarjeta,
               monto,
               estado,
               observacion,
               fec_proceso,
               fec_valor,
               dia_mora,
               hora,
               cod_usuario)
            values
              (v_cta_tarjeta,
               v_nro_tarjeta,
               p_monto,
               'P',
               'Procesado desde Plataforma',
               v_fec_valor,
               v_fec_actual,
               v_dia_mora,
               v_hora,
               user);
          exception
            when others then
              p_cod_error := SQLCODE;
              p_men_error := substr(SQLERRM, 1, 4000);
              prg_ins_log_programas('PAT_TGL.PR_PAG_TAR_CRE',
                                    substr(v_lugar || p_nro_cta || ' ' ||
                                           SQLERRM,
                                           1,
                                           4000),
                                    null,
                                    p_nro_cta);
          end;*/
          if p_cod_error = 0 then
            v_lugar := '4 - ';
            --Busco el nro_documento para asignar al movimiento
            SELECT to_number(s_nro_ref_documento.nextval)
            --to_number(to_char(v_fec_actual,'RRMMDD') || s_nro_ref_documento.nextval)
              INTO v_nro_documento
              FROM dual;

            SAVEPOINT pago;

            BEGIN
              --Generar el movimiento por el credito
              r_gmovi.cod_usuario := v_cod_usuario;
              r_gmovi.hora        := v_hora;
              r_gmovi.fecha       := v_fec_actual;
              -- Aumento la secuencia
              v_nro_secuencia         := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia   := v_nro_secuencia;
              r_gmovi.cod_modulo      := v_cod_modulo;
              r_gmovi.cod_modalidad   := v_cod_modalidad;
              r_gmovi.cod_oficina     := v_cod_oficina;
              r_gmovi.cod_moneda      := v_cod_moneda;
              r_gmovi.fec_valor       := v_fec_valor;
              r_gmovi.cod_tra_padre   := 250;
              r_gmovi.cod_mod_padre   := v_cod_modulo;
              r_gmovi.cod_mad_padre   := v_cod_modalidad;
              r_gmovi.cod_transaccion := 978;
              r_gmovi.monto           := p_monto;
              r_gmovi.nro_documento   := v_nro_documento;
              r_gmovi.nro_cuenta      := v_cta_tarjeta;
              r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
              r_gmovi.emi_aviso       := 'N';
              r_gmovi.concepto        := 'Credito de tarjetas';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';

              PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
            exception
              when others then
                begin
                  SELECT to_number(s_nro_ref_documento.nextval)
                  INTO v_nro_documento
                  FROM dual;
                  r_gmovi.nro_documento   := v_nro_documento;
                  v_cod_usuario   := it.fug_obt_mov_user('CREDCARDMS','S_SER_USER_CREDCARDMS');
                  v_ind_usuario   := to_number(substr(v_cod_usuario,10,2));
                  r_gmovi.cod_usuario := v_cod_usuario;
                  v_hora := fu_obt_hora(v_ind_usuario);
                  r_gmovi.hora        := v_hora;
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
                exception
                  when others then
                    begin
                      SELECT to_number(s_nro_ref_documento.nextval)
                      INTO v_nro_documento
                      FROM dual;
                      r_gmovi.nro_documento   := v_nro_documento;
                      v_cod_usuario   := it.fug_obt_mov_user('CREDCARDMS','S_SER_USER_CREDCARDMS');
                      v_ind_usuario   := to_number(substr(v_cod_usuario,10,2));
                      r_gmovi.cod_usuario := v_cod_usuario;
                      v_hora := fu_obt_hora(v_ind_usuario);
                      r_gmovi.hora        := v_hora;
                      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
                    exception
                      when others then
                        begin
                          SELECT to_number(s_nro_ref_documento.nextval)
                          INTO v_nro_documento
                          FROM dual;
                          r_gmovi.nro_documento   := v_nro_documento;
                          v_cod_usuario   := it.fug_obt_mov_user('CREDCARDMS','S_SER_USER_CREDCARDMS');
                          v_ind_usuario   := to_number(substr(v_cod_usuario,10,2));
                          r_gmovi.cod_usuario := v_cod_usuario;
                          v_hora := fu_obt_hora(v_ind_usuario);
                          r_gmovi.hora        := v_hora;
                          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
                        exception
                          when others then
                             begin
                             if sqlerrm like ('%No existe segundo disponible%')
                               or sqlerrm like ('%ORA-00001%') then
                                 SELECT to_number(s_nro_ref_documento.nextval)
                                  INTO v_nro_documento
                                  FROM dual;
                                 r_gmovi.nro_documento   := v_nro_documento;
                                 v_cod_usuario   := it.fug_obt_mov_user('CREDCARDMS','S_SER_USER_CREDCARDMS');
                                 v_ind_usuario   := to_number(substr(v_cod_usuario,10,2));
                                 r_gmovi.cod_usuario := v_cod_usuario;
                                 v_hora := fu_obt_hora(v_ind_usuario);
                                 r_gmovi.hora := v_hora;
                                 pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_mov_noc);
                             else
                                p_cod_error := 999;
                                p_men_error:='Error al insertar mov. credito del nro de cuenta: '||p_nro_cta;
                                prg_ins_log_programas(v_nom_programa,substr(
                                                  'Error al insertar mov. credito del nro de cuenta: ' ||
                                                  p_nro_cta || '.MsgErr: ' || sqlerrm,1,4000));
                             end if;
                           exception
                             when others then
                              p_cod_error := SQLCODE;
                              p_men_error := substr(SQLERRM, 1, 4000);
                              prg_ins_log_programas(v_nom_programa,
                                                    substr(v_lugar || p_nro_cta || ' ' ||
                                                           SQLERRM,
                                                           1,
                                                           4000),
                                                    v_cod_persona,
                                                    p_nro_cta);
                           end;
                        end;
                    end;
                end;
            end;
          end if;
          pag_cta.pr_set_est_movimiento('N'); -- movimiento confirmado normal
          --calcula impuesto si corresponde y genera movimiento
          select t.cod_moneda
            into v_mon_deb
            from ge_cuentas t
           where t.nro_cuenta = p_nro_cta_deb;
          if p_cod_error = 0 then
            begin
              v_lugar := '5 - ';
              prg_ver_cob_cargos(p_nro_cta_deb,
                                 v_cta_tarjeta,
                                 v_cod_modulo, --cod_mod_padre
                                 v_cod_modalidad, --o abmc.modalidad       --cod_mad_padre
                                 v_cod_oficina,
                                 v_mon_deb,
                                 p_monto,
                                 'Cobro de Tarjeta ' || v_cta_tarjeta,
                                 v_nro_documento,
                                 v_fec_actual,
                                 v_hora,
                                 v_impuesto,
                                 v_nro_secuencia,
                                 'S'); --procesar
            exception
              when others then
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      v_cod_persona,
                                      p_nro_cta);
            end;
          end if;
          if nvl(v_impuesto, 0) > 0 then
            --aumentar la secuencia
            v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
          end if;
          if p_cod_error = 0 then
            begin
              v_lugar := '6 - ';
            -- Seteo de variables solo por cod_usuario
              pag_cta.pr_set_variables(p_cod_usuario => v_cod_usuario,
                                       p_fec_valor => v_fec_valor,
                                       p_cod_tra_padre => 250,
                                       p_estado => 'N',
                                       p_reversado => 'N',
                                       p_nro_secuencia => v_nro_secuencia,
                                       p_est_cuenta => null,
                                       p_cod_ofi_origen => v_cod_ofi_origen);
              -- Actualiza la Cuenta Debito / Destino
              pag_cta.pr_act_operacion(p_nro_cta_deb,
                                       v_hora, --HORA
                                       'D',
                                       v_mon_deb, --Moneda de la Operacion
                                       p_monto + nvl(v_impuesto, 0),
                                       250, -- COD_TRA_PADRE
                                       503, -- COD_TRA_HIJO CREDITO CUENTA CLIENTE
                                       v_nro_documento, --nro_documento --antes era en nro_documento2
                                       null, --COTIZACION, los pagos son en moneda local
                                       v_cod_ofi_origen, --cod_ofi_origen
                                       v_cod_modulo, --cod_mod_padre
                                       v_cod_modalidad, --o abmc.modalidad       --cod_mad_padre
                                       null, --cod_tasa
                                       null, --val_tasa
                                       'Cobro de Tarjetas ' || v_cta_tarjeta,
                                       'S', --emi_aviso
                                       v_nro_secuencia,
                                       v_fec_valor);

              if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
                p_cod_error := pag_cta.G_COD_ERROR;
                p_men_error := substr(pag_cta.G_MSJ_ERROR, 1, 4000);
                p_nro_documento:=null;
                p_fec_mov:=null;
                ROLLBACK TO pago;
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             p_cod_error || ' ' || p_men_error,
                                             1,
                                             4000),
                                      v_cod_persona,
                                      p_nro_cta);
              else
                 p_nro_documento:=v_nro_documento;
                 p_fec_mov:= to_char(sysdate, 'DD/MM/YYYY HH24:MI');
              end if;
            exception
              when others then
                ROLLBACK TO pago;
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      v_cod_persona,
                                      p_nro_cta);
            end;
          end if;

          /*Una vez que se registra el debito e insertan los movimientos, se inserta en TA_COBROS*/
          if p_cod_error = 0 then
            v_lugar := '3 - ';
            if fut_obt_procesadora(v_cta_tarjeta) = fug_obt_pardinamico('COD_ENT_GLOBAL') then
              begin
              --inserta el registro de cobro
                insert into ta_cobros_gp
                       (nro_cuenta,
                       nro_tarjeta,
                       nro_cta_debito,
                       monto,
                       estado,
                       observacion,
                       fec_proceso,
                       fec_valor,
                       dia_mora,
                       hora,
                       cod_usuario,
                       canal)
                values
                       (v_cta_tarjeta,
                       v_nro_tarjeta,
                       p_nro_cta_deb,
                       p_monto,
                       'P',
                       'Procesado desde Plataforma',
                       v_fec_actual,
                       v_fec_valor,
                       v_dia_mora,
                       v_hora,
                       v_cod_usuario,
                       p_cod_canal);
              exception
                when others then
                  p_cod_error := SQLCODE;
                  p_men_error := substr(SQLERRM, 1, 4000);
                  prg_ins_log_programas(v_nom_programa,
                                        substr(v_lugar || p_nro_cta || ' ' ||
                                        SQLERRM,
                                        1,
                                        4000),
                                        v_cod_persona,
                                        p_nro_cta);
              end;
            else
              begin
              --inserta el registro de cobro
                insert into ta_cobros
                       (nro_cuenta,
                       nro_tarjeta,
                       nro_cta_debito,
                       monto,
                       estado,
                       observacion,
                       fec_proceso,
                       fec_valor,
                       dia_mora,
                       hora,
                       cod_usuario)
                values
                       (v_cta_tarjeta,
                       v_nro_tarjeta,
                       p_nro_cta_deb,
                       p_monto,
                       'P',
                       'Procesado desde Plataforma',
                       v_fec_actual,
                       v_fec_valor,
                       v_dia_mora,
                       v_hora,
                       v_cod_usuario);
              exception
                when others then
                  p_cod_error := SQLCODE;
                  p_men_error := substr(SQLERRM, 1, 4000);
                  prg_ins_log_programas(v_nom_programa,
                                        substr(v_lugar || p_nro_cta || ' ' ||
                                        SQLERRM,
                                        1,
                                        4000),
                                        v_cod_persona,
                                        p_nro_cta);
              end;
            end if;
          end if;

          if p_cod_error = 0 then
            v_lugar := '7 - ';
            begin
              prg_gen_comprobantes('PT',
                                   v_fec_actual,
                                   v_hora,
                                   v_nro_secuencia,
                                   user,
                                   'Pago de tarjeta ' || v_cta_tarjeta,
                                   null,
                                   v_cod_moneda,
                                   p_monto + nvl(v_impuesto, 0),
                                   v_cod_persona,
                                   p_nro_cta_deb,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null,
                                   v_cta_tarjeta,
                                   null,
                                   v_nro_tarjeta,
                                   null,
                                   null,
                                   v_cdusuar,
                                   'Debito en cta. ' || p_nro_cta_deb ||
                                   ' por pago de tarjeta ' || v_nro_tarjeta,
                                   null,
                                   null,
                                   null,
                                   null,
                                   null);
            exception
              when others then
                p_cod_error := SQLCODE;
                p_men_error := substr(SQLERRM, 1, 4000);
                prg_ins_log_programas(v_nom_programa,
                                      substr(v_lugar || p_nro_cta || ' ' ||
                                             SQLERRM,
                                             1,
                                             4000),
                                      v_cod_persona,
                                      p_nro_cta);
            end;
          end if;
        end if;
      end if;
    end;

  -- genera la solicitud de tarjeta
  procedure pr_gen_sol_tarjeta(p_cod_persona     in varchar2,
                               p_cod_moneda      in varchar2,
                               p_monto           in number,
                               p_cod_tip_tarjeta in varchar2,
                               p_nro_cta_debito  in varchar2 default null,
                               p_cod_error       out number,
                               p_men_error       out varchar2,
                               p_nro_solicitud   out number) is
    v_num_solicitud     pr_solicitudes.nro_solicitud%type := 0;
    v_fec_solicitud     ge_solicitudes.fec_solicitud%type;
    v_cod_moneda        pr_solicitudes.cod_moneda%type := p_cod_moneda;
    v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_cod_modulo        ta_solicitudes.cod_modulo%type;
    v_cod_modalidad     ta_solicitudes.cod_modalidad%type;
    v_cod_oficina       ta_solicitudes.cod_oficina%type := fug_obt_pardinamico('COD_OFI_WERKING');
    v_cod_usuario       ta_solicitudes.cod_usu_promotor%type := user;
    v_deb_automatico    ge_solicitudes.deb_automatico%type;
    v_tip_cobro         ge_solicitudes.tip_cobro%type;
    v_nom_embozado      ge_solicitudes.nom_embozado%type;
    v_monto             pr_solicitudes.monto%type := p_monto;
    v_referencia        ta_solicitudes.referencia%type;
    v_cod_rub_economico ta_solicitudes.cod_rub_economico%type;
    v_nro_bin           ta_tipos.nro_bin%type;
    v_cod_afinidad      ge_solicitudes.cod_afinidad%type;
    v_mto_minimo        number;
  begin
    p_cod_error := 0;
    p_men_error := '';
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
      execute immediate 'ALTER SESSION SET NLS_DATE_FORMAT = ''DD/MM/RRRR HH24:MI:SS''';
    end;
    begin
      select t.cod_modulo,
             t.cod_modalidad,
             t.nro_bin,
             t.afinidad,
             t.tip_cobro,
             t.min_linea
        into v_cod_modulo,
             v_cod_modalidad,
             v_nro_bin,
             v_cod_afinidad,
             v_tip_cobro,
             v_mto_minimo
        from ta_tipos t
       where t.cod_tip_tarjeta = p_cod_tip_tarjeta
       and rownum=1;
    exception
      when no_data_found then
        p_cod_error := 1;
        p_men_error := 'Tipo de Tarjeta no definido. Tipo: ' ||
                       p_cod_tip_tarjeta;
    end;
    if nvl(p_cod_error, 0) = 0 then
      v_cod_rub_economico := fug_obt_pardinamico('COD_RUB_ECONOMICO',
                                                 v_cod_modulo); --'970107'
      if p_monto < v_mto_minimo then
        p_cod_error := 2;
        p_men_error := 'Monto Solicitado inferior al minimo. Monto Minimo: ' ||
                       v_mto_minimo;
      end if;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      -- Se busca la secuencia
      select s_nro_solicitud.nextval INTO v_num_solicitud FROM dual;
      v_fec_solicitud := v_fec_actual;
      if p_nro_cta_debito is null then
        v_deb_automatico := 'N';
      else
        v_deb_automatico := 'S';
      end if;
      --nombre de embozado para la tc
      begin
        select substr(nvl(f.pri_nombre, f.seg_nombre) || ' ' ||
                      nvl(f.pri_apellido, f.seg_apellido),
                      1,
                      26)
          into v_nom_embozado
          from ba_per_fisicas f
         where f.cod_persona = p_cod_persona;
      exception
        when others then
          v_nom_embozado := substr(fue_obt_nom_persona(p_cod_persona),
                                   1,
                                   26);
      end;
      v_referencia := v_cod_oficina;
      insert into ta_solicitudes
        (nro_solicitud,
         cod_persona,
         cod_oficina,
         cod_modulo,
         cod_modalidad,
         fec_solicitud,
         cod_moneda,
         cod_rub_economico,
         deb_automatico,
         cod_usu_promotor,
         cod_usu_oficial,
         fec_aprobacion,
         nom_embozado,
         cod_estado,
         tip_envio,
         referencia,
         afinidad,
         monto,
         nro_cta_debito)
      values
        (v_num_solicitud,
         p_cod_persona,
         v_cod_oficina,
         v_cod_modulo,
         v_cod_modalidad,
         v_fec_solicitud,
         v_cod_moneda,
         v_cod_rub_economico,
         v_deb_automatico,
         v_cod_usuario,
         v_cod_usuario,
         v_fec_actual,
         v_nom_embozado,
         'PAN',
         'R',
         v_referencia,
         v_cod_afinidad,
         v_monto,
         p_nro_cta_debito);
      p_nro_solicitud := v_num_solicitud;
    end if;
  exception
    when others then
      p_cod_error := 3;
      p_men_error := 'Error al insertar solicitud. ' || sqlerrm;
  end;
  procedure pr_obt_montos_tar(p_tip_tarjeta in varchar2,
                              p_mto_minimo  out number,
                              p_mto_maximo  out number,
                              p_cod_error   out number,
                              p_men_error   out varchar2) is
    v_mto_minimo ta_tipos.min_linea%TYPE;
    v_mto_maximo ta_tipos.max_linea%TYPE;
  begin
    p_cod_error := 0;
    p_men_error := '';
    begin
      select min_linea, max_linea
        into v_mto_minimo, v_mto_maximo
        from ta_tipos t
       where t.cod_tip_tarjeta = p_tip_tarjeta
       and rownum=1;
    exception
      when no_data_found then
        v_mto_minimo := fug_obt_pardinamico('LIN_MIN_TARJETA', 5);
        v_mto_maximo := fug_obt_pardinamico('LIN_MAX_TARJETA', 5);
    end;
    if nvl(v_mto_minimo, 0) = 0 then
      p_cod_error  := 3;
      p_mto_minimo := 0;
      p_men_error  := 'Monto minimo no definido para el tipo de tarjeta.';
    end if;
    if nvl(v_mto_maximo, 0) = 0 then
      p_cod_error  := 3;
      p_mto_maximo := 0;
      p_men_error  := 'Monto maximo no definido para el tipo de tarjeta.';
    end if;
    if nvl(p_cod_error, 0) = 0 then
      p_mto_minimo := v_mto_minimo;
      p_mto_maximo := v_mto_maximo;
    end if;
  end;

  /**
  * Procedimiento para verificar si posee una cuenta credito global
  **/
  procedure pr_ver_cta_credito(p_cod_persona in varchar2,
                               p_existe      out varchar2,
                               p_cod_error   out number,
                               p_men_error   out varchar2) is
    v_existe_tarjeta  varchar2(1);
    v_existe_embozado varchar2(1);
  begin
    v_existe_tarjeta  := 'N';
    v_existe_embozado := 'N';
    p_existe          := 'N';
    p_cod_error       := 0;
    p_men_error       := 'Operacion Exitosa';
    begin
      --hay gente que todavia no realizo el reemplazo,esta como virtual
      select 'S'
        into v_existe_embozado
        from ta_imp_dat_embozados s
       where cod_persona = p_cod_persona
         and nvl(estado, 'C') <> 'C'; --distinto de cancelado
    exception
      when no_Data_found then
        --poner too many rows calcular adelante
        v_existe_embozado := 'N';
      when others then
        v_existe_embozado := 'N';
    end;

    begin
      select 'S'
        into v_existe_tarjeta
        from ta_tar_global_tmp a
       where cod_persona = p_cod_persona;
      -- and nvl(cod_Estado, '1') = '0'; --comparar con si hay una activo? recordar que estan los bloqueados etc
    exception
      when no_Data_found then
        v_existe_tarjeta := 'N';
      when others then
        v_existe_tarjeta := 'N';
    end;

    if v_existe_embozado = 'S' and v_existe_tarjeta = 'S' then
      p_existe := 'S';
    end if;
  end;

  -- cargar y parsear los datos json de la tabla temporal
  procedure pr_par_json(p_dato            in varchar2,
                        p_cod_persona     in varchar2,
                        p_nro_cuenta      in varchar2,
                        p_nro_cta_global  out varchar2,
                        p_id_producto     out varchar2,
                        p_nro_cta         out varchar2,
                        p_nro_bin         out varchar2,
                        p_nro_tarjeta     out varchar2,
                        p_fec_vencimiento out varchar2,
                        p_tipo_tarjeta    out varchar2) is

    v_sql   varchar2(4000);
    v_lugar varchar2(10);
    v_error exception;
    v_men_error    varchar2(4000);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_PAR_JSON';

    pragma autonomous_transaction;

  begin
    v_lugar := '01';
    begin
      -- se carga la tabla temporal ah_json_tmp
      v_lugar := '02';
      v_sql   := 'INSERT INTO ah_json_tmp(dato, cod_persona, nro_cta) VALUES(' || '''' ||
                 p_dato || '''' || ',' || '''' || p_cod_persona || '''' || ',' || '''' ||
                 p_nro_cuenta || '''' || ');';
      v_lugar := '03';
      execute immediate 'begin ' || v_sql || 'end;';
      commit;
    exception
      when others then
        v_men_error := substr('Error al cargar la tabla ah_json_tmp: ' ||
                              p_dato || ' # ' || sqlerrm,
                              1,
                              4000);
        raise v_error;
    end;

    begin
      v_lugar := '04';
      -- parseamos los campos y obtenemos los datos
      select a.accountId,
             b.productId,
             a.idExternalAccount,
             substr(c.cardNumber, 1, 6),
             substr(c.cardNumber, -4),
             substr(c.expired, 1, 10),
             c.cardType
        into p_nro_cta_global,
             p_id_producto,
             p_nro_cta,
             p_nro_bin,
             p_nro_tarjeta,
             p_fec_vencimiento,
             p_tipo_tarjeta
        from ah_json_tmp j,
             json_table(dato
                        columns(accountId varchar2(20) path '$.accountId',
                                idExternalAccount varchar2(20) path
                                '$.idExternalAccount')) as a,
             json_table(dato,
                        '$.product[*]'
                        columns(productId varchar2(20) path '$.productId')) as b,
             json_table(dato,
                        '$.cards[*]'
                        columns(cardNumber varchar2(20) path '$.cardNumber',
                                expired varchar2(20) path '$.expired',
                                cardType varchar2(10) path '$.cardType')) as c
       where j.nro_cta = p_nro_cuenta;
    exception
      when no_data_found then
        v_men_error := 'Sin registro en tabla AH_JSON_TMP. Json -> : ' ||
                       p_dato;
        raise v_error;
      when too_many_rows then
        v_men_error := 'Demasiados registros recuperados en tabla AH_JSON_TMP. Json -> : ' ||
                       p_dato;
        raise v_error;
      when others then
        p_nro_cta_global := 'err';
        prg_ins_log_programas(v_nom_programa,
                              substr('Lugar: ' || v_lugar ||
                                     ' - Error al obtener datos de json:' ||
                                     p_dato || ' # ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nro_cuenta);
        v_men_error := substr('Error al obtener datos de json:' || p_dato ||
                              ' # ' || sqlerrm,
                              1,
                              4000);
        raise v_error;
    end;

  exception
    when v_error then
      p_nro_cta_global := 'err';
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' ' ||
                                   v_men_error,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cuenta);
    when others then
      p_nro_cta_global := 'err';
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - Error:' ||
                                   p_dato || ' # ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cuenta);
  end;

-- creacion de una cuenta credito de tarjeta en global por tipo de producto --
procedure pr_cre_cta_cre_gp(p_nro_doc   in ba_personas.nro_documento%TYPE,
                                  p_tip_producto in varchar2,
                                  p_cod_error out number,
                                  p_men_error out varchar2) IS

    v_url_cre           varchar2(4000) := fug_obt_pardinamico('WS_ALT_TARJETA_CRE');
    v_url               varchar2(4000);
    v_content           varchar2(4000);
    v_lugar             varchar2(10);
    v_nom_programa      varchar2(50) := 'PAT_TGL.PR_CRE_CTA_CRE_GP';
    v_cod_modalidad     ah_cta_vistas.cod_modalidad%type;
    v_cod_sub_modalidad ah_cta_vistas.cod_sub_modalidad%TYPE;
    v_cod_modulo        ah_cta_vistas.cod_modulo%type;
    v_contrato          varchar2(1) := 'N';
    v_nro_cuenta        ah_cta_vistas.nro_cuenta%type;
    v_exi_tc            number := 0;
    v_con_unico         varchar2(1) := fug_obt_pardinamico('IND_ENC_CONUNICO');
    v_direccion         ba_direcciones.direccion%TYPE;
    v_numero            ba_direcciones.numero%TYPE;
    v_piso              ba_direcciones.piso%TYPE;
    v_departamento      ba_direcciones.departamento%TYPE;
    v_cod_postal        ba_direcciones.cod_postal%TYPE;
    v_barrio            ba_barrios.descripcion%TYPE;
    v_tel_particular    ba_telefonos.telefono%TYPE;
    v_tel_celular       ba_telefonos.telefono%TYPE;
    v_email             ba_personas.dir_correo%TYPE;
    v_ciudad            ba_ciudades.descripcion%TYPE := fue_obt_des_ciudad (1,1);
    v_pais              ba_paises.descripcion%TYPE := 600;
    v_provincia         NUMBER := 1;
    v_exi_producto      varchar2(1):='N';
    v_cod_moneda        ah_cta_vistas.cod_moneda%type;

    ---
    cursor c_cli is
      select fug_eli_car_invalidos(f.pri_nombre) /*|| ' ' ||
                                                                                                                                                                                                                                                                                                                                                                         fug_eli_car_invalidos(f.seg_nombre) */ nombre,
             fug_eli_car_invalidos(f.pri_apellido) /*|| ' ' ||
                                                                                                                                                                                                                                                                                                                                                                         fug_eli_car_invalidos(f.seg_apellido)*/ apellido,
             p.nro_documento,
             f.cod_sexo,
             to_char(f.fec_nacimiento, 'yyyy-mm-dd') fec_nacimiento,
             p.cod_persona,
             fue_obt_des_refcodes('TIP_DOCUMENTO_GP', p.cod_tip_documento) tip_documento
        from ba_per_fisicas f, ba_personas p
       where p.nro_documento = p_nro_doc
         and p.cod_persona = f.cod_persona;

    v_men_error  varchar2(4000);
    v_cod_err_ws varchar2(10);
    v_error exception;
    v_entro        varchar2(1);
    v_cod_producto varchar2(10);
    -----------
    v_cod_persona varchar2(10);
    v_existe_tc varchar2(1):='N';
    v_existe_ta varchar2(1):='N';

    pragma autonomous_transaction;

begin
    v_lugar     := '01';
    p_cod_error := v_cod_msg_exito;
    p_men_error := 'Operacion Exitosa';
    v_entro     := 'N';
   ----
   Begin pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;
   pae_cnf.g_programa := 'GPPROFIN';
   end;

   begin
        select cod_persona
        into v_cod_persona
        from ba_personas s
        where s.nro_documento=p_nro_doc;
        --and s.est_verificacion like 'V';
    exception
          when others then
            v_cod_persona:=null;
    end;

    begin
      select distinct 'S'--si existe implica que ya dio de alta un TC por solicitud de credito
      into v_existe_tc
      from ta_tarjetas a
      where a.cod_estado<>'10'
      and it.fut_obt_procesadora(a.nro_cuenta)=it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
      and a.cod_persona=v_cod_persona;
      exception
        when others then
          v_existe_tc:='N';
          null;
      end;
      begin
      select distinct 'S'--si existe en estado 15 implica que ya se dio de alta mediante un reemplazo
      into v_existe_ta
      from ta_tar_global_tmp a
      where a.cod_persona=v_cod_persona;
      exception
        when others then
          v_existe_ta:='N';
      end;

if v_existe_tc='N' and v_existe_ta='N'  then--ya que no existe en ambos casos ingresa para el alta de cuenta de TC

   for c in c_cli loop

      --Validamos que el cliente tenga firmado el Contrato Unico
      IF v_con_unico = 'S' THEN
        -- Si es S se debe controlar
        v_entro := 'S';
        begin
          select 'S'
            into v_contrato
            from ba_per_ima_documentos
           where cod_tip_documento = 64
             and est_doc in ('A', 'N')
             and cod_persona = c.cod_persona;
        exception
          when no_data_found then
            p_cod_error := 33;
            p_men_error := 'No tiene verificado la firma de contrato Unico';
            v_contrato  := 'N';
          WHEN too_many_rows THEN
            v_contrato := 'S';
          WHEN OTHERS THEN
            p_cod_error := 34;
            p_men_error := 'Verificar el procedimiento pr_cre_cta_cre_gp';
            v_contrato  := 'N';
        end;
      ELSE
        -- no se controla contrato
        v_contrato := 'S';
      END IF;

      if v_contrato = 'S' then

        --Valido que el cliente ya cuente con una TD virtual activa
        begin
          select td.nro_cuenta
            into v_nro_cuenta
            from ah_tar_debitos td, ge_cta_clientes gct, ba_personas p
           where td.nro_cuenta = gct.nro_cuenta
             and gct.relacion = 'P'
             AND td.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
             --and td.tip_tar_debito = 'MV'
             and td.tar_activa = 'S'
             and gct.cod_persona = c.cod_persona
             AND td.cod_persona = gct.cod_persona
             AND gct.cod_persona = p.cod_persona
             and td.id_producto=(select val_minimo from ba_cod_referencias e
                                 where e.dominio= 'GLP_TIP_PRO_RELACION'
                                 and val_maximo=p_tip_producto)--poner aca lo de ba_cod_referencias
             and rownum = 1;--como validar su producto relacionado
        exception
          when no_data_found then
            v_nro_cuenta := null;
            p_cod_error  := 34;
            p_men_error  := 'Cliente no posee una TD activa para este producto';
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         p_men_error,
                                         1,
                                         4000),
                                  c.cod_persona,
                                  v_nro_cuenta);
          WHEN others THEN
            v_nro_cuenta := null;
            p_cod_error  := 34;
            p_men_error  := 'Error al buscar tarjeta virtual';
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         p_men_error,
                                         1,
                                         4000),
                                  c.cod_persona,
                                  v_nro_cuenta);
        end;

        if v_nro_cuenta is not null then
          v_entro := 'S';
          begin
            v_lugar := '02';

            -- Obtenemos el modulo y modalidad de la caja de ahorro
            select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad,a.cod_moneda
              into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,v_cod_moneda
              from ah_cta_vistas a
             where a.nro_cuenta = v_nro_cuenta;

            if fug_obt_pardinamico(fue_obt_val_max_referencia('GLP_TIP_PRO_MODAL',
                                                       p_tip_producto),
                               v_cod_modulo,
                               v_cod_modalidad,
                               v_cod_moneda,
                               NULL,
                               v_cod_sub_modalidad) = 'S' then
              -- Para obtener el codigo de producto GP, se debe pasar por parametro en la url
              begin
                select 'S'
                into v_exi_producto
                from ba_cod_referencias s
                where s.dominio='GLP_TIP_PRODUCTOS'
                and s.val_maximo=p_tip_producto;
                if v_exi_producto='S' then
                    v_url:= v_url_cre || p_tip_producto;
                end if;
              exception
                when others then
                p_cod_error:=v_err_sql;
                p_men_error:='Error,Producto no identificado'||'/'||p_tip_producto ||'-'||sqlerrm;
                prg_ins_log_programas(v_nom_programa,
                                      'Error,Producto no identificado'||'/'||p_tip_producto ||'-'||sqlerrm);
                raise v_error;
              end;
        else
           p_cod_error:=v_err_sql;
           v_men_error:='Caja de ahorro '||v_nro_cuenta||' no valida.Verifique modalidad-moneda-submodalidad.';
           p_men_error:=v_men_error;
        end if;

        if p_cod_error = v_cod_msg_exito then

            select count(*)
              into v_exi_tc
              from ta_tar_global_tmp g, ba_personas p
             where g.cod_persona = p.cod_persona
               and p.nro_documento = p_nro_doc
               and g.cod_estado <>'1';--todo estado que no sea baja

            if v_exi_tc != 0 then
              p_cod_error := 35;
              p_men_error := 'La persona ' || p_nro_doc ||
                             ' ya posee cuenta de credito virtual';
              prg_ins_log_programas(v_nom_programa,
                                    substr('Lugar: ' || v_lugar || ' - ' ||
                                           p_cod_error || ' - ' ||
                                           p_men_error,
                                           1,
                                           4000),
                                    c.cod_persona,
                                    v_nro_cuenta);
            ELSE
              --Se buscan los datos del cliente para enviar desde el json
              pr_obt_dat_clientes (c.cod_persona,
                                   v_direccion,
                                   v_numero,
                                   v_piso,
                                   v_departamento,
                                   v_cod_postal,
                                   v_barrio,
                                   v_tel_particular,
                                   v_tel_celular,
                                   v_email);

              -- se crea la estructura json para pasar al WS
              v_content := '{' || '"name":' || '"' || c.nombre || '"' || ',' || --nombres del cliente
                           '"lastName":' || '"' || c.apellido || '"' || ',' || --apelllidos del cliente
                           '"documentNumber":' || '"' || c.nro_documento || '"' || ',' || --nro documento del cliente (ci/pas/dni...etc)
                           '"gender":' || '"' || c.cod_sexo || '"' || ',' || --genero del cliente - M(masculino) o F(femenino)
                           '"birthday":' || '"' || c.fec_nacimiento || '"' || ',' || --fecha nacimiento del cliente
                           '"personCode":' || '"' || c.cod_persona || '"' || ',' || --cod persona del cliente itgf
                           '"cardType":' || '"' || '1' || '"' || ',' || --tipo de tarjeta
                           '"documentType":' || '"' || c.tip_documento || '"' || ',' ||
                           '"domicile": {' || '"street":' || '"' || v_direccion || '"' || ',' ||
                           '"number":' || '"' || v_numero || '"' || ',' ||
                           '"floor":' || '"' || v_piso || '"' || ',' ||
                           '"apartment":' || '"' || v_departamento || '"' || ',' ||
                           '"postalCode":' || '"' || v_cod_postal  || '"' || ',' ||
                           '"city":' || '"' || v_ciudad || '"' || ',' ||
                           '"province":' || '"' || v_provincia || '"' || ',' ||
                           '"country":' || '"' || v_pais || '"' ||
                           '},' ||
                           '"phone":{' || '"particular":' || '"' || v_tel_particular || '"' || ',' ||
                           '"cellPhone":' || '"' || v_tel_celular || '"' ||
                           '},' ||
                           '"email":' || '"' || v_email || '"' ||
                            '}';
             v_lugar   := '03';

              --solicitud ws
              pat_tgl.pr_ws_conector(v_content,
                                     nvl(v_url,v_url_cre),
                                     v_nro_cuenta,
                                     c.cod_persona,
                                     'A',
                                     'POST',
                                     v_cod_err_ws,
                                     v_men_error); -- llama al web Service

              -- el cod_error 200 = Exitoso, distinto a 200 es un error.
              if v_cod_err_ws != v_cod_msg_exito THEN
                v_lugar     := '09';
                p_cod_error := v_cod_err_ws;
                p_men_error := v_men_error;
                prg_ins_log_programas(v_nom_programa,
                                      substr('Lugar: ' || v_lugar ||
                                             ' - IP: ' || v_url || ' - ' ||
                                             p_cod_error || ' - ' ||
                                             v_men_error,
                                             1,
                                             4000),
                                      c.cod_persona,
                                      v_nro_cuenta);
              end if;
            end if;
         end if;

          exception
            when v_error then
              p_cod_error := v_err_sql;
              p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                    ' Error de datos del pr_par_json: ' ||
                                    p_men_error || ' - ' || sqlerrm,
                                    1,
                                    4000);
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    c.cod_persona,
                                    v_nro_cuenta);
            when others then
              p_cod_error := v_err_sql;
              p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                    ' Error en programa ' || v_nom_programa || ': ' ||
                                    p_men_error || ' - ' || sqlerrm,
                                    1,
                                    4000);
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    c.cod_persona,
                                    v_nro_cuenta);
          end;
        end if;
      end if;
    end loop;
    if v_entro = 'N' then
      p_cod_error := v_err_sql;
      p_men_error := 'Lugar: ' || v_lugar || '. ' ||
                     'No realizo el alta de Cuenta en Global';
    end if;
else
    if v_cod_persona is not null then--como la cuenta ya existe,entra al flujo de reemplazo
      begin--se cancelan todos los plasticos que tenga la persona previo a las nuevas vinculaciones
        update ta_imp_dat_embozados s
        set s.estado='C'
        where s.cod_persona=v_cod_persona;
        commit;
       exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                      substr('Error al actualizar embozados,nro. de cedula ' || p_nro_doc || ' - ' ||
                                             p_men_error,
                                             1,
                                             4000));
      end;
    end if;
end if;--aca terminaria if de verificacion de existencia de tarjetas
exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Alta de Cta Global' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa, p_men_error, null, p_nro_doc);
  end;

  -- creacion de una cuenta de tarjeta en global clasica debito
  procedure pr_cre_cta_global(p_nro_cta     in ge_cta_clientes.nro_cuenta%type,
                              p_cod_persona in ge_cta_clientes.cod_persona%TYPE DEFAULT NULL,
                              p_cod_error   out number,
                              p_men_error   out varchar2) IS

    v_url_deb           varchar2(4000) := fug_obt_pardinamico('WS_ALT_TARJETA_DEB');
    v_url               varchar2(4000);
    v_content           varchar2(4000);
    v_lugar             varchar2(10);
    v_sql               VARCHAR2(4000);
    v_nom_programa      varchar2(50) := 'PAT_TGL.PR_CRE_CTA_GLOBAL';
    v_cod_modalidad     ah_cta_vistas.cod_modalidad%type;
    v_cod_sub_modalidad ah_cta_vistas.cod_sub_modalidad%TYPE;
    v_cod_modulo        ah_cta_vistas.cod_modulo%type;
    v_cod_moneda        ah_cta_vistas.cod_moneda%type;
    --- variables para parsear json ---
    v_nro_cta_global    varchar2(16);
    v_id_producto       varchar2(6);
    v_nro_cta           ah_tar_debitos.nro_cuenta%type;
    v_nro_bin           ah_tar_debitos.nro_bin%type;
    v_nro_tarjeta       ah_tar_debitos.nro_tarjeta%type;
    v_fec_vencimiento   varchar2(10);
    v_tip_tarjeta       varchar2(10);
    v_direccion         ba_direcciones.direccion%TYPE;
    v_numero            ba_direcciones.numero%TYPE;
    v_piso              ba_direcciones.piso%TYPE;
    v_departamento      ba_direcciones.departamento%TYPE;
    v_cod_postal        ba_direcciones.cod_postal%TYPE;
    v_barrio            ba_barrios.descripcion%TYPE;
    v_tel_particular    ba_telefonos.telefono%TYPE;
    v_tel_celular       ba_telefonos.telefono%TYPE;
    v_email             ba_personas.dir_correo%TYPE;
    v_ciudad            ba_ciudades.descripcion%TYPE := fue_obt_des_ciudad(1,1);
    v_pais              ba_paises.cod_pais%TYPE := 600;
    v_provincia         NUMBER := 1;
    ---
    cursor c_cli is
      select fug_eli_car_invalidos(f.pri_nombre) || ' ' ||
             fug_eli_car_invalidos(f.seg_nombre) nombre,
             fug_eli_car_invalidos(f.pri_apellido) || ' ' ||
             fug_eli_car_invalidos(f.seg_apellido) apellido,
             p.nro_documento,
             f.cod_sexo,
             to_char(f.fec_nacimiento, 'yyyy-mm-dd') fec_nacimiento,
             fue_obt_des_refcodes('TIP_DOCUMENTO_GP', p.cod_tip_documento) tip_documento
        from ba_per_fisicas f, ba_personas p, ge_cta_clientes c
       where c.nro_cuenta = p_nro_cta
         and f.cod_persona = p_cod_persona
         and c.cod_persona = f.cod_persona
         and p.cod_persona = f.cod_persona
         and c.relacion='P';

    v_men_error    varchar2(4000);
    v_cod_err_ws   varchar2(10);
    v_cod_error    varchar2(10);
    v_error        exception;
    v_entro        varchar2(1);
    v_cod_producto varchar2(10);
    v_Existe       number;

    pragma autonomous_transaction;

  begin

     Begin pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
     pae_cnf.g_programa := 'GPPROFIN';
     end;
    v_lugar     := '01';
    p_cod_error := v_pro_correcto;
    v_entro     := 'N';
    IF nvl(fug_obt_pardinamico('IND_DEB_VAL_PER_GP'),'N') = 'S' THEN
      BEGIN
        select count(*)
          into v_Existe
          from  ah_tar_debitos s
         where s.cod_persona   = p_cod_persona
           and cod_ent_procesadora=it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
            and s.tar_activa='S';
         If v_existe > 0 then
           p_cod_error:=v_err_sql;
           p_men_error:='La persona : '||p_cod_persona||' ya posee TD GP activa.';
           prg_ins_log_programas(v_nom_programa,
                                 substr('Lugar: ' || v_lugar || ' - ' ||
                                        p_cod_error || ' - ' || p_men_error,
                                        1,
                                        4000),
                                        p_cod_persona,
                                        p_nro_cta);
         End if;
      end;
    end if;
    if p_cod_error = v_pro_correcto then
      for c in c_cli loop
        v_entro := 'S';
        begin
          v_lugar := '02';

          -- Obtenemos el modulo y modalidad de la caja de ahorro
          select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad,a.cod_moneda
            into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,v_cod_moneda
            from ah_cta_vistas a
           where a.nro_cuenta = p_nro_cta;

          if fug_obt_pardinamico('COD_MAD_DEB_COMBO2',
                                 v_cod_modulo,
                                 v_cod_modalidad,
                                 v_cod_moneda,
                                 NULL,
                                 v_cod_sub_modalidad) = 'S' then
            -- Para obtener el codigo de producto GP, se debe pasar por parametro en la url
            v_cod_producto := fue_obt_val_max_referencia('GLP_TIP_PRODUCTOS',
                                                         'GP_DEB_COMBO2');
            v_url          := v_url_deb || v_cod_producto;
          else
           p_cod_error:=v_err_sql;
           v_cod_err_ws:=v_err_sql;
           v_men_error:='Caja de ahorro '||p_nro_cta||' no admitida.Verifique modalidad-moneda-submodalidad.';
          end if;
          if p_cod_error = v_pro_correcto then
           --Se buscan los datos del cliente para enviar desde el json
            pr_obt_dat_clientes (p_cod_persona,
                                 v_direccion,
                                 v_numero,
                                 v_piso,
                                 v_departamento,
                                 v_cod_postal,
                                 v_barrio,
                                 v_tel_particular,
                                 v_tel_celular,
                                 v_email);

            -- se crea la estructura json para pasar al WS
            v_content := '{' || '"name":' || '"' || c.nombre || '"' || ',' || --nombres del cliente
                         '"lastName":' || '"' || c.apellido || '"' || ',' || --apelllidos del cliente
                         '"documentNumber":' || '"' || c.nro_documento || '"' || ',' || --nro documento del cliente (ci/pas/dni...etc)
                         '"gender":' || '"' || c.cod_sexo || '"' || ',' || --genero del cliente - M(masculino) o F(femenino)
                         '"birthday":' || '"' || c.fec_nacimiento || '"' || ',' || --fecha nacimiento del cliente
                         '"accountNumber":' || '"' || p_nro_cta || '"' || ',' || --nro cuenta del cliente itgf
                         '"personCode":' || '"' || p_cod_persona || '"' || ',' || --cod persona del cliente itgf
                         '"documentType":' || '"' || c.tip_documento || '"' || ',' ||  --tipo de documento del cliente
                         '"domicile": {' || '"street":' || '"' || v_direccion || '"' || ',' ||
                         '"number":' || '"' || v_numero || '"' || ',' ||
                         '"floor":' || '"' || v_piso || '"' || ',' ||
                         '"apartment":' || '"' || v_departamento || '"' || ',' ||
                         '"postalCode":' || '"' || v_cod_postal  || '"' || ',' ||
                         '"city":' || '"' || v_ciudad || '"' || ',' ||
                         '"province":' || '"' || v_provincia || '"' || ',' ||
                         '"country":' || '"' || v_pais || '"' ||
                         '},' ||
                         '"phone":{' || '"particular":' || '"' || v_tel_particular || '"' || ',' ||
                         '"cellPhone":' || '"' || v_tel_celular || '"' ||
                         '},' ||
                         '"email":' || '"' || v_email || '"' ||
                          '}';
            v_lugar   := '03';

            --solicitud ws
            pat_tgl.pr_ws_conector(v_content,
                                   v_url,
                                   p_nro_cta,
                                   p_cod_persona,
                                   'A',
                                   'POST',
                                   v_cod_err_ws,
                                   v_men_error); -- llama al web Service
            -- el cod_error 200 = Exitoso, distinto a 200 es un error.
          end if;


          if v_cod_err_ws != v_cod_msg_exito THEN
            v_lugar     := '09';
            p_cod_error := v_cod_err_ws;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         v_cod_err_ws || ' - ' || v_men_error,
                                         1,
                                         4000),
                                  p_cod_persona,
                                  p_nro_cta);
          else
            v_lugar     := '10';
            p_cod_error := v_cod_err_ws;
            p_men_error := v_men_error;

            -- se inserta los datos en una tabla temporal
            v_lugar := '11';
            pat_tgl.pr_par_json(p_men_error,
                                p_cod_persona,
                                p_nro_cta,
                                v_nro_cta_global,
                                v_id_producto,
                                v_nro_cta,
                                v_nro_bin,
                                v_nro_tarjeta,
                                v_fec_vencimiento,
                                v_tip_tarjeta);
            -- si no hubo error de parseo de json
            if v_nro_cta_global != 'err' then
              v_lugar := '12';
              -- se da de alta la tarjeta en ah_tar_debitos
              pat_tgl.pr_alt_tar_debpre(v_nro_cta_global,
                                        v_id_producto,
                                        v_nro_cta,
                                        v_nro_bin,
                                        v_nro_tarjeta,
                                        to_date(v_fec_vencimiento,
                                                'yyyy-mm-dd'),
                                        v_tip_tarjeta,
                                        v_cod_error,
                                        v_men_error);

              if v_cod_error = v_pro_correcto then
                p_cod_error := v_pro_correcto;
                p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                   'Transaccion Exitosa!');
                v_lugar     := '13';
                -- borra el registro de la tabla temporal ah_json_tmp
                v_sql := 'delete ah_json_tmp a where a.nro_cta = ' || '''' ||
                         p_nro_cta || '''';
                execute immediate v_sql;
                commit;
              else
                v_lugar     := '14';
                p_cod_error := v_cod_error;
                p_men_error := v_men_error;
                prg_ins_log_programas(v_nom_programa,
                                      substr('Lugar: ' || v_lugar || ' - ' ||
                                             v_cod_error || ' - ' ||
                                             p_men_error,
                                             1,
                                             4000),
                                      p_cod_persona,
                                      p_nro_cta);
              end if;
            else
              v_lugar     := '15';
              p_men_error := 'Error al crear la cuenta en global.';
              p_cod_error := v_err_sql;
              raise v_error;
            end if;
          end if;

        exception
          when v_error then
            p_cod_error := v_err_sql;
            p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  ' Error de datos del pr_par_json: ' ||
                                  p_men_error || ' - ' || sqlerrm,
                                  1,
                                  4000);
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  p_cod_persona,
                                  p_nro_cta);
          when others then
            p_cod_error := v_err_sql;
            p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  ' Error en programa ' || v_nom_programa || ': ' ||
                                  p_men_error || ' - ' || sqlerrm,
                                  1,
                                  4000);
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  p_cod_persona,
                                  p_nro_cta);
        end;
      end loop;
    end if;
    if v_entro = 'N' then
      p_cod_error := v_err_sql;
      p_men_error := 'Lugar: ' || v_lugar || '. ' ||
                     'No realizo el alta de Cuenta en Global';
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Alta de Cta Global' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            p_cod_persona,
                            p_nro_cta);
  end;
  -- creacion de una cuenta debito de tarjeta en global por tipo de producto
  procedure pr_cre_cta_deb_gp(p_nro_cta     in ge_cta_clientes.nro_cuenta%type,
                              p_cod_persona in ge_cta_clientes.cod_persona%TYPE DEFAULT NULL,
                              p_tip_producto in varchar2,
                              p_cod_error   out number,
                              p_men_error   out varchar2) IS

    v_url_deb           varchar2(4000) := fug_obt_pardinamico('WS_ALT_TARJETA_DEB');
    v_url               varchar2(4000);
    v_content           varchar2(4000);
    v_lugar             varchar2(10);
    v_sql               VARCHAR2(4000);
    v_nom_programa      varchar2(50) := 'PAT_TGL.PR_CRE_CTA_DEB_GP';
    v_cod_modalidad     ah_cta_vistas.cod_modalidad%type;
    v_cod_sub_modalidad ah_cta_vistas.cod_sub_modalidad%TYPE;
    v_cod_modulo        ah_cta_vistas.cod_modulo%type;
    v_exi_producto      varchar2(1):='N';
    v_cod_moneda        ah_cta_vistas.cod_moneda%type;
    --- variables para parsear json ---
    v_nro_cta_global    varchar2(16);
    v_id_producto       varchar2(6);
    v_nro_cta           ah_tar_debitos.nro_cuenta%type;
    v_nro_bin           ah_tar_debitos.nro_bin%type;
    v_nro_tarjeta       ah_tar_debitos.nro_tarjeta%type;
    v_fec_vencimiento   varchar2(10);
    v_tip_tarjeta       varchar2(10);
    v_direccion         ba_direcciones.direccion%TYPE;
    v_numero            ba_direcciones.numero%TYPE;
    v_piso              ba_direcciones.piso%TYPE;
    v_departamento      ba_direcciones.departamento%TYPE;
    v_cod_postal        ba_direcciones.cod_postal%TYPE;
    v_barrio            ba_barrios.descripcion%TYPE;
    v_tel_particular    ba_telefonos.telefono%TYPE;
    v_tel_celular       ba_telefonos.telefono%TYPE;
    v_email             ba_personas.dir_correo%TYPE;
    v_ciudad            ba_ciudades.descripcion%TYPE := fue_obt_des_ciudad(1,1);
    v_pais              ba_paises.cod_pais%TYPE := 600;
    v_provincia         NUMBER := 1;
    ---
    cursor c_cli is
      select fug_eli_car_invalidos(f.pri_nombre) || ' ' ||
             fug_eli_car_invalidos(f.seg_nombre) nombre,
             fug_eli_car_invalidos(f.pri_apellido) || ' ' ||
             fug_eli_car_invalidos(f.seg_apellido) apellido,
             p.nro_documento,
             f.cod_sexo,
             to_char(f.fec_nacimiento, 'yyyy-mm-dd') fec_nacimiento,
             fue_obt_des_refcodes('TIP_DOCUMENTO_GP', p.cod_tip_documento) tip_documento
        from ba_per_fisicas f, ba_personas p, ge_cta_clientes c
       where c.nro_cuenta = p_nro_cta
         and f.cod_persona = p_cod_persona
         and c.cod_persona = f.cod_persona
         and p.cod_persona = f.cod_persona
         and c.relacion='P';

    v_men_error    varchar2(4000);
    v_cod_err_ws   varchar2(10);
    v_cod_error    varchar2(10);
    v_error        exception;
    v_entro        varchar2(1);
    v_cod_producto varchar2(10);

    pragma autonomous_transaction;

  begin
     Begin pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
     pae_cnf.g_programa := 'GPPROFIN';
     end;
    v_lugar     := '01';
    p_cod_error := v_pro_correcto;
    v_entro     := 'N';
    for c in c_cli loop
      v_entro := 'S';
      begin
        v_lugar := '02';

        -- Obtenemos el modulo y modalidad de la caja de ahorro
        begin
        select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad,a.cod_moneda
          into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,v_cod_moneda
          from ah_cta_vistas a
         where a.nro_cuenta = p_nro_cta;
         exception
           when others then
            prg_ins_log_programas(v_nom_programa,
                                  'Error al recuperar modulo/modalidad'||'/'||p_nro_cta ||'-'||sqlerrm);
            raise v_error;
        end;

        if fug_obt_pardinamico(fue_obt_val_max_referencia('GLP_TIP_PRO_MODAL',
                                                       p_tip_producto),
                               v_cod_modulo,
                               v_cod_modalidad,
                               v_cod_moneda,
                               NULL,
                               v_cod_sub_modalidad) = 'S' then
          -- Para obtener el codigo de producto GP, se debe pasar por parametro en la url
          begin
            select 'S'
            into v_exi_producto
            from ba_cod_referencias s
            where s.dominio='GLP_TIP_PRODUCTOS'
            and s.val_maximo=p_tip_producto;
            if v_exi_producto='S' then
                v_url:= v_url_deb || p_tip_producto;
            end if;
          exception
            when others then
            prg_ins_log_programas(v_nom_programa,
                                  'Error,Producto no identificado'||'/'||p_nro_cta ||'-'||sqlerrm);
            raise v_error;
          end;
        else
           p_cod_error:=v_err_sql;
           v_cod_err_ws:=v_err_sql;
           v_men_error:='Caja de ahorro '||p_nro_cta||' no admitida.Verifique modalidad-moneda-submodalidad.';
        end if;

       if p_cod_error = v_pro_correcto then
       --Se buscan los datos del cliente para enviar desde el json
       begin
        pr_obt_dat_clientes (p_cod_persona,
                             v_direccion,
                             v_numero,
                             v_piso,
                             v_departamento,
                             v_cod_postal,
                             v_barrio,
                             v_tel_particular,
                             v_tel_celular,
                             v_email);
       exception
         when others then
                       prg_ins_log_programas(v_nom_programa,
                                  'Error al recuperar datos del cliente'||'/'||p_nro_cta ||'-'||sqlerrm);
            raise v_error;
         end;


        -- se crea la estructura json para pasar al WS
        v_content := '{' || '"name":' || '"' || c.nombre || '"' || ',' || --nombres del cliente
                     '"lastName":' || '"' || c.apellido || '"' || ',' || --apellidos del cliente
                     '"documentNumber":' || '"' || c.nro_documento || '"' || ',' || --nro documento del cliente (ci/pas/dni...etc)
                     '"gender":' || '"' || c.cod_sexo || '"' || ',' || --genero del cliente - M(masculino) o F(femenino)
                     '"birthday":' || '"' || c.fec_nacimiento || '"' || ',' || --fecha nacimiento del cliente
                     '"accountNumber":' || '"' || p_nro_cta || '"' || ',' || --nro cuenta del cliente itgf
                     '"personCode":' || '"' || p_cod_persona || '"' || ',' || --cod persona del cliente itgf
                     '"documentType":' || '"' || c.tip_documento || '"' || ',' ||  --tipo de documento del cliente
                     '"domicile": {' || '"street":' || '"' || v_direccion || '"' || ',' ||
                     '"number":' || '"' || v_numero || '"' || ',' ||
                     '"floor":' || '"' || v_piso || '"' || ',' ||
                     '"apartment":' || '"' || v_departamento || '"' || ',' ||
                     '"postalCode":' || '"' || v_cod_postal  || '"' || ',' ||
                     '"city":' || '"' || v_ciudad || '"' || ',' ||
                     '"province":' || '"' || v_provincia || '"' || ',' ||
                     '"country":' || '"' || v_pais || '"' ||
                     '},' ||
                     '"phone":{' || '"particular":' || '"' || v_tel_particular || '"' || ',' ||
                     '"cellPhone":' || '"' || v_tel_celular || '"' ||
                     '},' ||
                     '"email":' || '"' || v_email || '"' ||
                      '}';
        v_lugar   := '03';

        --solicitud ws
        pat_tgl.pr_ws_conector(v_content,
                               nvl(v_url,v_url_deb),
                               p_nro_cta,
                               p_cod_persona,
                               'A',
                               'POST',
                               v_cod_err_ws,
                               v_men_error); -- llama al web Service

        end if;
        -- el cod_error 200 = Exitoso, distinto a 200 es un error.
        if v_cod_err_ws != v_cod_msg_exito THEN
          v_lugar     := '09';
          p_cod_error := v_cod_err_ws;
          p_men_error := v_men_error;
          prg_ins_log_programas(v_nom_programa,
                                substr('Lugar: ' || v_lugar || ' - ' ||
                                       v_cod_err_ws || ' - ' || v_men_error,
                                       1,
                                       4000),
                                p_cod_persona,
                                p_nro_cta);
        else
          v_lugar     := '10';
          p_cod_error := v_cod_err_ws;
          p_men_error := v_men_error;

          -- se inserta los datos en una tabla temporal
          v_lugar := '11';
          pat_tgl.pr_par_json(p_men_error,
                              p_cod_persona,
                              p_nro_cta,
                              v_nro_cta_global,
                              v_id_producto,
                              v_nro_cta,
                              v_nro_bin,
                              v_nro_tarjeta,
                              v_fec_vencimiento,
                              v_tip_tarjeta);
          -- si no hubo error de parseo de json
          if v_nro_cta_global != 'err' then
            v_lugar := '12';
            -- se da de alta la tarjeta en ah_tar_debitos
            pat_tgl.pr_alt_tar_debpre(v_nro_cta_global,
                                      v_id_producto,
                                      v_nro_cta,
                                      v_nro_bin,
                                      v_nro_tarjeta,
                                      to_date(v_fec_vencimiento,
                                              'yyyy-mm-dd'),
                                      v_tip_tarjeta,
                                      v_cod_error,
                                      v_men_error);

            if v_cod_error = v_pro_correcto then
              p_cod_error := v_pro_correcto;
              p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                 'Transaccion Exitosa!');
              v_lugar     := '13';
              -- borra el registro de la tabla temporal ah_json_tmp
              v_sql := 'delete ah_json_tmp a where a.nro_cta = ' || '''' ||
                       p_nro_cta || '''';
              execute immediate v_sql;
              commit;
            else
              v_lugar     := '14';
              p_cod_error := v_cod_error;
              p_men_error := v_men_error;
              prg_ins_log_programas(v_nom_programa,
                                    substr('Lugar: ' || v_lugar || ' - ' ||
                                           v_cod_error || ' - ' ||
                                           p_men_error,
                                           1,
                                           4000),
                                    p_cod_persona,
                                    p_nro_cta);
            end if;
          else
            v_lugar     := '15';
            p_men_error := 'Error al crear la cuenta en global.';
            p_cod_error := v_err_sql;
            raise v_error;
          end if;
        end if;

      exception
        when v_error then
          p_cod_error := v_err_sql;
          p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                ' Error de datos del pr_par_json: ' ||
                                p_men_error || ' - ' || sqlerrm,
                                1,
                                4000);
          prg_ins_log_programas(v_nom_programa,
                                p_men_error,
                                p_cod_persona,
                                p_nro_cta);
        when others then
          p_cod_error := v_err_sql;
          p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                ' Error en programa ' || v_nom_programa || ': ' ||
                                p_men_error || ' - ' || sqlerrm,
                                1,
                                4000);
          prg_ins_log_programas(v_nom_programa,
                                p_men_error,
                                p_cod_persona,
                                p_nro_cta);
      end;
    end loop;
    if v_entro = 'N' then
      p_cod_error := v_err_sql;
      p_men_error := 'Lugar: ' || v_lugar || '. ' ||
                     'No realizo el alta de Cuenta en Global';
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Alta de Cta Global/Producto:' ||p_tip_producto||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            p_cod_persona,
                            p_nro_cta);
  end;

  --funcion que verifica si existe una tarjeta debito activa para una cuenta. Retorna S(si existe) o N(no existe)
  function fu_exi_tar_debpre(p_nro_cuenta  ah_tar_debitos.nro_cuenta%type,
                             p_cod_persona ah_tar_debitos.cod_persona%type default null)
    return varchar2 is

    v_existe       varchar2(10) DEFAULT 'N';
    v_nom_programa varchar2(50) := 'PAT_TGL.FU_EXI_TAR_DEBPRE';
  begin
    select 'S'
      into v_existe
      from ah_tar_debitos a, ah_cta_vistas b
     where a.nro_cuenta = b.nro_cuenta
       and a.nro_cuenta = p_nro_cuenta
       and a.cod_persona = nvl(p_cod_persona, a.cod_persona)
       and a.nro_tarjeta is not null
       and nvl(a.tar_activa, 'S') = 'S'
       and a.cod_est_solicitud = 0; -- estado Normal

    return v_existe;

  exception
    when no_data_found then
      return 'N';
    when too_many_rows then
      return 'S';
    when others then
      prg_ins_log_programas(v_nom_programa,
                            substr(sqlerrm, 1, 4000),
                            p_cod_persona,
                            p_nro_cuenta);
      return 'N';
  end;

  -- alta de tarjeta debito/credito
  procedure pr_alt_tar_debpre(p_nro_cta_global  in ah_tar_debitos.nro_cta_global%type,
                              p_id_producto     in ah_tar_debitos.id_producto%type,
                              p_nro_cta         in ah_tar_debitos.nro_cuenta%type,
                              p_nro_bin         in ah_tar_debitos.nro_bin%type,
                              p_nro_tarjeta     in ah_tar_debitos.nro_tarjeta%type,
                              p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                              p_tip_tarjeta     in varchar2,
                              p_cod_error       out number,
                              p_men_error       out varchar2) is

    v_cod_persona    ba_personas.cod_persona%TYPE;
    v_embozado       ah_tar_debitos.embozado%type;
    v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type;
    v_adherente      ah_tar_debitos.adherente%type := '00';
    v_nro_emision    ah_tar_debitos.nro_emision%type;
    v_men_error      varchar2(4000);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ALT_TAR_DEBPRE';
    pragma autonomous_transaction;

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    p_cod_error := v_pro_correcto;
    begin
      select c.cod_persona,
             substr(nvl(f.pri_nombre, f.seg_nombre) || ' ' ||
                    nvl(f.pri_apellido, f.seg_apellido),
                    1,
                    26)
        into v_cod_persona, v_embozado
        from ah_cta_vistas v, ge_cta_clientes c, ba_per_fisicas f
       where c.nro_cuenta = p_nro_cta
         and c.cod_persona = f.cod_persona
         and c.cod_modulo = v.cod_modulo
         and c.cod_modalidad = v.cod_modalidad
         and c.nro_cuenta = v.nro_cuenta
         and c.relacion = 'P'; ---solo busca del principal de la cuenta
    exception
      when others then
        v_cod_persona := '0';
        v_men_error   := substr('Error Obt. Cod_Persona: ' || sqlerrm,
                                1,
                                4000);
        raise v_error;
    end;

    if UPPER(TRIM(p_tip_tarjeta)) = v_cod_tar_deb_virtual then
      v_tip_tar_debito := 'MV';
    elsif UPPER(TRIM(p_tip_tarjeta)) = v_cod_tar_deb_fisica then
      v_tip_tar_debito := 'MF';
    else
      prg_ins_log_programas(v_nom_programa,
                            'Tipo de tarjeta no se encuentra: ' ||
                              v_tip_tar_debito || ' - ' ||'p_tip_tarjeta: '||p_tip_tarjeta||' - ' ||
                            substr(sqlerrm, 1, 4000),
                            v_cod_persona,
                            p_nro_cta);
      v_tip_tar_debito := UPPER(TRIM(p_tip_tarjeta));
    end if;

    -- se verfica si ya tiene tarjetas
    begin
      select nvl(max(a.nro_emision), '00')
        into v_nro_emision
        from ah_tar_debitos a
       where a.nro_cuenta = p_nro_cta
         and a.nro_cta_global = p_nro_cta_global;

      --se genera una nueva emision si es una reimpresion
      v_nro_emision := lpad(to_char(to_number(v_nro_emision) + 1), 2, '0');

    exception
      when others then
        -- si da algun error asignamos el 01
        v_nro_emision := '01';
    end;

    begin
      insert into ah_tar_debitos
        (nro_cuenta,
         cod_ent_procesadora,
         cod_persona,
         adherente,
         nro_emision,
         cod_usuario,
         cod_ofi_origen,
         Tip_Envio,
         referencia,
         tar_activa,
         cod_est_solicitud,
         fec_activacion,
         embozado,
         fec_vencimiento,
         nro_bin,
         tip_tar_debito,
         nro_tarjeta,
         nro_cta_global,
         id_producto)
      values
        (p_nro_cta,
         v_ent_global,
         v_cod_persona,
         v_adherente,
         v_nro_emision,
         substr(user, 1, 10),
         '1',
         'R',
         '1',
         'S',
         '0',
         sysdate,
         v_embozado,
         p_fec_vencimiento,
         p_nro_bin,
         v_tip_tar_debito,
         p_nro_tarjeta,
         p_nro_cta_global,
         p_id_producto);

      p_men_error := 'Transaccion Exitosa!';
      commit;
    exception
      when others then
        v_men_error := substr('Error Insert ah_tar_debitos: ' || sqlerrm,
                              1,
                              4000);
         begin
           insert into it.ah_tar_deb_log_gp s
            (nro_cuenta,
             cod_ent_procesadora,
             cod_persona,
             adherente,
             nro_emision,
             cod_usuario,
             cod_ofi_origen,
             Tip_Envio,
             referencia,
             tar_activa,
             cod_est_solicitud,
             fec_activacion,
             embozado,
             fec_vencimiento,
             nro_bin,
             tip_tar_debito,
             nro_tarjeta,
             nro_cta_global,
             id_producto,
             men_error)
          values
            (p_nro_cta,
             v_ent_global,
             v_cod_persona,
             v_adherente,
             v_nro_emision,
             substr(user, 1, 10),
             '1',
             'R',
             '1',
             'S',
             '0',
             sysdate,
             v_embozado,
             p_fec_vencimiento,
             p_nro_bin,
             v_tip_tar_debito,
             p_nro_tarjeta,
             p_nro_cta_global,
             p_id_producto,
             substr(v_men_error,1,2000));
             commit;
         exception
           when others then
             prg_ins_log_programas(v_nom_programa,substr(
                            'No se pudo insertar log - tip:' ||
                              v_tip_tar_debito||'-nro_cuenta_gp:'||p_nro_cta_global||'-p_nro_tarjeta:'||p_nro_tarjeta
                              ||'-p_id_producto:'||p_id_producto||'-'||
                            substr(sqlerrm, 1,200),1,1000),
                            v_cod_persona,
                            p_nro_cta);
         end;
        raise v_error;
    end;

  exception
    when v_error then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            v_cod_persona,
                            p_nro_cta);
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 400);
      prg_ins_log_programas(v_nom_programa,
                            substr(sqlerrm, 1, 4000),
                            v_cod_persona,
                            p_nro_cta);
  end;

  --ALTA DE REGISTRO TA_TARJETAS CREDITO
    procedure pr_alt_tar_cre(p_nro_cuenta  in ta_tarjetas.nro_cuenta%type,
                              p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                              p_cod_persona in ta_tarjetas.cod_persona%type,
                              p_fec_vencimiento in ta_tarjetas.fec_vencimiento%type,
                              p_nom_embozar in ta_tarjetas.nom_embozar%type,
                              p_id_producto in ta_tarjetas.id_producto%type,
                              p_cod_error       out number,
                              p_men_error       out varchar2) is

    v_cod_persona    ba_personas.cod_persona%TYPE;
    v_embozado       ta_tarjetas.nom_embozar%type;
    v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type;
    v_adherente      ah_tar_debitos.adherente%type := '00';
    v_nro_emision    ah_tar_debitos.nro_emision%type;
    v_men_error      varchar2(4000);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ALT_TAR_CRE';
    pragma autonomous_transaction;

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    p_cod_error := v_pro_correcto;
    begin
      insert into it.ta_tarjetas
        (nro_cuenta,
         nro_tarjeta,
         cod_persona,
         cod_estado,
         fec_vencimiento,
         cod_causa,
         nom_embozar,
         nom_enviar,
         vigente,
         fec_emision,
         fec_solicitud,
         tip_envio,
         referencia,
         nro_planilla,
         tip_planilla,
         nro_pla_anterior,
         fec_entrega,
         fec_activacion,
         observacion,
         pre_embozada,
         rel_tarjeta,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion,
         motivo,
         tip_embozado,
         id_producto)
      values
        (p_nro_cuenta,
         p_nro_tarjeta,
         p_cod_persona,
         '6',
         p_fec_vencimiento,
         '',
         p_nom_embozar,
         '',
         'S',
         sysdate,
         sysdate,
         '',
         '',
         '',
         '',
         '',
         sysdate,
         sysdate,
         'TC con reemplazo realizado',
         '',
         0,
         user,
         sysdate,
         user,
         sysdate,
         '',
         'MF',
         p_id_producto);
    p_men_error := 'Transaccion Exitosa!';
    commit;
    exception
      when others then
        v_men_error := substr('Error Insert ta_tarjetas: ' || sqlerrm,
                              1,
                              4000);
        raise v_error;
    end;

  exception
    when v_error then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 400);
      prg_ins_log_programas(v_nom_programa,
                            substr(sqlerrm, 1, 4000),
                            v_cod_persona,
                            p_nro_cuenta);
  end;

  -- actualiza estado de tarjeta de debito
  procedure pr_act_tar_debpre(p_nro_cta     in ah_tar_debitos.nro_cuenta%type,
                              p_cod_persona in ah_tar_debitos.cod_persona%type,
                              p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                              p_estado      in ah_tar_debitos.cod_est_solicitud%type,
                              p_cod_error   out number,
                              p_men_error   out varchar2) is

    v_url_est_deb varchar2(4000) := fug_obt_pardinamico('WS_EST_TARJETA_DEB'); --url cambio estado tarjeta para tarjeta debito
    v_url         varchar2(4000);
    v_content     varchar2(4000);
    v_lugar       varchar2(10);
    v_men_error   varchar2(4000);
    v_cod_err_ws  number(6);
    v_error exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_TAR_DEBPRE';

  begin
    v_lugar := '01';
    v_url   := v_url_est_deb;
    v_url   := replace(v_url, '{alfaAccountNumber}', p_nro_cta);

    -- se crea la estructura json para pasar al WS
    v_lugar   := '02';
    v_content := '{' || '"state":' || '"' ||
                 fue_obt_des_refcodes('EST_TAR_DEBITO', p_estado, 'S') || '"' || ',' || -- estado a cambiar en global
                 '"cardNumber":' || '"' || substr(p_nro_tarjeta, -4) || '"' || '}'; -- nro de la tarjeta debito/prepaga
    v_lugar   := '03';
    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           p_nro_cta,
                           p_cod_persona,
                           'M',
                           'PUT',
                           v_cod_err_ws,
                           v_men_error); -- llama al web Service
    if v_cod_err_ws != v_cod_msg_exito /*v_pro_correcto */
     then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
    else
      p_cod_error := v_pro_correcto;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_ACT_TAR_DEBPRE. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
  end;

  -- llama al proc. de cambio de estado para realizar el bloqueo
  procedure pr_blo_tar_debpre(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                              p_ind_estado  in varchar2, -- S(bloqueo) N(Desbloqueo)
                              p_cod_error   out number,
                              p_men_error   out varchar2) is
    v_lugar     varchar2(10);
    v_men_error varchar2(4000);
    v_cod_error number(6);
    v_error exception;
    v_val_estado   varchar2(50);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_BLO_TAR_DEBPRE';

  begin
    v_lugar := '01';
    if p_ind_estado = 'N' then
      v_lugar      := '02';
      v_val_estado := fue_obt_des_refcodes('EST_TAR_DEBITO', '0', 'S');
    elsif p_ind_estado = 'S' then
      v_lugar      := '03';
      v_val_estado := fue_obt_des_refcodes('EST_TAR_DEBITO', '14', 'S');
    else
      v_lugar     := '04';
      v_men_error := 'Error: Indicador de Estado ' || p_ind_estado ||
                     ' no valido!';
      raise v_error;
    end if;
    v_lugar := '05';
    if upper(trim(v_val_estado)) !=
       upper('Referencia  no registrada en el Sistema') then
      -- actualiza el estado a bloqueado/desbloqueado
      v_lugar := '06';
      pat_tgl.pr_act_est_tarjeta(p_nro_cuenta,
                                 p_nro_tarjeta,
                                 v_val_estado,
                                 v_cod_error,
                                 v_men_error);
      p_cod_error := v_cod_error;
      p_men_error := v_men_error;
    else
      v_lugar     := '07';
      v_men_error := 'Error: Estado para Bloqueo no configurado!';
      raise v_error;
    end if;

  exception
    when v_error then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            null,
                            p_nro_cuenta);
    when others then
      v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                            'Error al obtener Codigo de Estado para bloqueo/desbloqueo' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            null,
                            p_nro_cuenta);
  end;

  -- actualiza el estado de la tarjeta al ser invocado desde la plataforma(web, mobile,...)
  procedure pr_act_est_tarjeta(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                               p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                               p_estado      in varchar2,
                               p_cod_error   out number,
                               p_men_error   out varchar2) is
    v_estado          ah_tar_debitos.cod_est_solicitud%type;
    v_tip_tar_debito  ah_tar_debitos.tip_tar_debito%TYPE;
    v_nro_cta_global  ah_tar_debitos.nro_cta_global%TYPE;
    v_men_error       varchar2(4000);
    v_lugar           varchar2(10);
    v_nom_programa    varchar2(50) := 'PAT_TGL.PR_ACT_EST_TARJETA';

  begin
    begin
      v_lugar := '01';
      select a.val_minimo
        into v_estado
        from ba_cod_referencias a
       where a.dominio = 'EST_TAR_DEBITO'
         and upper(a.significado) = upper(p_estado);
    exception
      when no_data_found then
        v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                              'Codigo de Estado a Actualizar incorrecto' ||
                              ' - ' || sqlerrm,
                              1,
                              4000);
        p_cod_error := v_err_sql;
        p_men_error := v_men_error;
        prg_ins_log_programas(v_nom_programa,
                              p_men_error,
                              null,
                              p_nro_cuenta);
      when others then
        v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                              'Error al obtener Codigo de Estado' || ' - ' ||
                              sqlerrm,
                              1,
                              4000);
        p_cod_error := v_err_sql;
        p_men_error := v_men_error;
        prg_ins_log_programas(v_nom_programa,
                              p_men_error,
                              null,
                              p_nro_cuenta);
    end;

    v_lugar := '02';
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;

    if p_estado NOT IN (fue_obt_des_refcodes('EST_TAR_DEBITO', '1', 'S'),
                        fue_obt_des_refcodes('EST_TAR_DEBITO', '25', 'S'),
                        fue_obt_des_refcodes('EST_TAR_DEBITO', '26', 'S')) THEN

      update ah_tar_debitos a
         set a.cod_est_solicitud = v_estado, a.tar_activa = 'S'
       where a.nro_cuenta = p_nro_cuenta
         and a.nro_tarjeta = p_nro_tarjeta;

    else
      update ah_tar_debitos a
         set a.cod_est_solicitud = v_estado, a.tar_activa = 'N'
       where a.nro_cuenta = p_nro_cuenta
         and a.nro_tarjeta = p_nro_tarjeta;

    end if;

    if SQL%NOTFOUND then
      v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                            'No se encuenta Nro. de Tarjeta a Actualizar.' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            NULL,
                            p_nro_cuenta);
    else
      v_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
      p_cod_error := v_pro_correcto;
      p_men_error := v_men_error;
    end if;

  end;

  --actualiza estado en ta_tarjetas al darse de baja
  procedure pr_act_est_tar_cre(p_nro_cuenta  in ah_tar_debitos.nro_cuenta%type,
                               p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                               p_estado      in number,
                               p_cod_error   out number,
                               p_men_error   out varchar2) is
    v_men_error    varchar2(4000);
    v_lugar        varchar2(10);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_ACT_EST_TAR_CRE';
    v_estado       ta_tarjetas.cod_estado%type;
    v_existe       varchar2(1):='N';
    v_cod_persona  ta_tarjetas.cod_persona%type;
    v_tip_embozado ta_tarjetas.tip_embozado%type;

  begin
    v_estado:=IT.fue_obt_val_max_referencia('EST_TAR_CREDITO',p_estado);
    v_cod_persona:=IT.fut_obt_cta_tokenizacion_gp(p_nro_cuenta);

    begin
      select distinct 'S'
        into v_existe
        from ta_tarjetas a
       where it.fut_obt_procesadora(a.nro_cuenta) =
             it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
             and vigente='S'
             and a.cod_estado not in ('10','25','26')
         and a.cod_persona = v_cod_persona;
    exception
      when no_data_found then
        v_existe := 'N';
      when others then
        v_existe := 'N';
        prg_ins_log_programas(v_nom_programa,
                              'Error!No se encontro TC para la persona/cuenta '||v_cod_persona||'/'||p_nro_cuenta || ' - ' || ' # ' ||
                              sqlerrm);
    end;
 --gp 0 --itgf--6
 --gp 1 --itgf--10
 --gp 14 --itgf--14

    v_lugar := '01';
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;


    if v_estado IN ('10','25','26') THEN
      if v_existe='S'then
         update ta_tarjetas a
         set a.cod_estado = v_estado,
         a.vigente = 'N'
         where a.nro_cuenta = p_nro_cuenta
         and a.nro_tarjeta = p_nro_tarjeta;
      end if;

      IF (v_existe = 'S' AND v_estado IN ('25','26') OR v_estado = '10') THEN
        update ta_tar_global_tmp a
        set a.cod_estado=p_estado--En ta_Tar_global_tmp queda con cod de GP
        where a.nro_cuenta = p_nro_cuenta
        and a.nro_tarjeta = p_nro_tarjeta;
        if sql%notfound then
            v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  'No se encuenta TC en TMP a Actualizar.' ||
                                  ' - ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := v_err_sql;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  NULL,
                                  p_nro_cuenta);

        end if;
      END IF;

      begin
        select tip_embozado
        into v_tip_embozado
        from ta_tarjetas a
        where a.nro_cuenta=p_nro_cuenta
        and a.nro_tarjeta=p_nro_tarjeta;
      exception
        when others then
          v_tip_embozado:=null;
      end;

      if v_tip_embozado<>'MV' then
          update ta_imp_dat_embozados s
          set s.estado='C'
          where s.nro_cuenta=p_nro_cuenta
          and substr(s.nro_pan_pro_principal, 13, 16)=p_nro_tarjeta;
          if sql%notfound then
            v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  'No se encuenta Nro. de sobre a Actualizar.' ||
                                  ' - ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := v_err_sql;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  NULL,
                                  p_nro_cuenta);
          else
            v_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                   'Transaccion Exitosa!');
            p_cod_error := v_pro_correcto;
            p_men_error := v_men_error;
          end if;
        else
            v_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                   'Transaccion Exitosa!');
            p_cod_error := v_pro_correcto;
            p_men_error := v_men_error;
        end if;

    else--caso generico
      if v_existe='S'then
        update ta_tar_global_tmp a
           set a.cod_estado=p_estado--codigo de GP
         where a.nro_cuenta = p_nro_cuenta
           and a.nro_tarjeta = p_nro_tarjeta;


         update ta_tarjetas a
            set a.cod_estado = v_estado, a.vigente = 'S'
          where a.nro_cuenta = p_nro_cuenta
           and a.nro_tarjeta = p_nro_tarjeta;
         if sql%notfound then
            v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  'No se encuenta Nro. de TC a Actualizar.' ||
                                  ' - ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := v_err_sql;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  NULL,
                                  p_nro_cuenta);


         else
            v_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                               'Transaccion Exitosa!');
            p_cod_error := v_pro_correcto;
            p_men_error := v_men_error;
            --commit;
         end if;
       else--no tiene ta_tarjetas
          update ta_tar_global_tmp a
          set a.cod_estado=p_estado--cod de GP
          where a.nro_cuenta = p_nro_cuenta
          and a.nro_tarjeta = p_nro_tarjeta;
         if sql%notfound then
            v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                  'No se encuenta Nro. de TC tmp a Actualizar.' ||
                                  ' - ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := v_err_sql;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  p_men_error,
                                  NULL,
                                  p_nro_cuenta);
         else
            v_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                               'Transaccion Exitosa!');
            p_cod_error := v_pro_correcto;
            p_men_error := v_men_error;
            --commit;
         end if;
       END IF;
     END IF;
end;
--------------------------------------------
  procedure pr_baj_tr_causa(p_nro_tarjeta         in ah_tar_debitos.nro_tarjeta%type,
                          p_nro_cuenta          in ah_tar_debitos.nro_cuenta%type,
                          p_motivo              in varchar2,
                          p_tip_tarjeta         in ah_tar_debitos.tip_tar_debito%type,
                          p_nro_tar_deb_virtual out varchar2,
                          p_cod_transaccion     out varchar2,
                          p_fec_transaccion     out varchar2,
                          p_cod_error           out number,
                          p_men_error           out varchar2) is
  v_lugar           varchar2(100);
  v_nom_programa    varchar2(50) := 'PAT_TGL.PR_BAJ_TR_CAUSA';
  v_nro_tarjeta     varchar2(10);
  v_motivo          varchar2(20);
  v_cod_causa       varchar2(3);
  v_nro_bin         ah_tar_debitos.nro_bin%type;
  v_fec_vencimiento ah_tar_debitos.fec_vencimiento%type;
  v_tip_tarjeta     ah_tar_debitos.tip_tar_debito%type;
  v_cod_persona     ah_tar_debitos.cod_persona%type;
  p_est_anterior    varchar2(20);
  v_tipo            varchar(1);
  v_error           EXCEPTION;
  v_men_error       varchar2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                          'Transaccion Exitosa!');
  v_cta_global      ah_tar_debitos.nro_cta_global%type;
  v_nro_cuenta      ta_tarjetas.nro_cuenta%type;
  v_actualiza       varchar(1):= 'S';
  v_procesar        varchar(1):= 'N';
begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
  p_cod_error  := v_pro_correcto;
  p_men_error  := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
  if upper(trim(p_motivo)) = 'ROBO' or upper(trim(p_motivo)) = 'EXTRAVIO' then
    v_motivo := upper(trim(p_motivo));
  else
    p_cod_error := '01';
    p_men_error := 'Favor ingresar motivo correcto: ROBO o EXTRAVIO';
  end if;
  --Reimpresion tarjeta debito
  v_lugar := '01 - Consulta TD';
  begin
    Select t.nro_tarjeta,
           t.nro_bin,
           t.fec_vencimiento,
           t.tip_tar_debito,
           t.cod_persona,
           'D',
           t.nro_cta_global
      into v_nro_tarjeta,
           v_nro_bin,
           v_fec_vencimiento,
           v_tip_tarjeta,
           v_cod_persona,
           v_tipo,
           v_cta_global
      from ah_tar_debitos t
     where t.nro_tarjeta is not NULL
       AND t.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
       and t.tar_activa = 'S'
       and t.nro_cuenta = p_nro_cuenta
       and t.nro_tarjeta = p_nro_tarjeta;
  exception
    when no_data_found then
      null;
  end;
  if v_nro_tarjeta is null then
    p_cod_error := '02';
    p_men_error := 'No se encuentra Nro. de Tarjeta para la cuenda proveida';
  end if;
  begin
    Select t.cod_causa
      into v_cod_causa
      from ge_causales t
     where t.tipo = 'T'
       and t.descripcion = trim(v_motivo);
  exception
    when no_data_found then
      v_cod_causa := null;
  end;
  if v_cod_causa is null then
    p_cod_error := '03';
    p_men_error := 'No se encuentra el codigo Causal.';
  end if;
  v_lugar := '02 - Llamada pr_ser_reimprimir';
  begin
    --Llamada procedimiento pr_tar_reimprimir
    pr_ser_reimprimir(p_nro_cuenta,
                      v_nro_tarjeta,
                      p_tip_tarjeta,
                      p_cod_error,
                      p_men_error);
    if p_cod_error = 200 then
       p_cod_error := 0;
    else
      prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - '  ||p_cod_error|| ' - '  ||p_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
end if;
  exception
    when others then
      v_men_error := 'Error al reimprimir TDV.';
      prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - '  ||p_cod_error|| ' - '  ||p_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
  end;

   v_lugar := '03 - Update Motivo Debito';
   begin
     pr_act_motivo(v_cod_persona,
                               p_nro_cuenta,
                               v_nro_tarjeta,
                               p_motivo,
                               v_cod_causa,
                               'D',
                               p_cod_error,
                               p_men_error);
   exception
    when others then
      v_men_error := 'Error Update Motivo';
      prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - '  ||p_cod_error|| ' - '  ||p_men_error,
                            v_cod_persona, p_nro_cuenta);
  end;
  if p_cod_error = 0 then
    v_procesar := 'S';
  end if;
  --Baja de Tarjeta de credito
v_lugar := '04 - Baja TC';
  v_nro_tarjeta     := null;
  v_nro_cuenta      := null;
  v_nro_bin         := null;
  v_tip_tarjeta     := null;
  v_fec_vencimiento := null;
  v_tipo            := null;
  begin
    Select SUBSTR(t.nro_pan_pro_principal, -4, 4),
           a.nro_cuenta,
           p.nro_bin,
           p.cod_tip_tarjeta,
           a.fec_vencimiento,
           t.cod_persona,
           'C'
      into v_nro_tarjeta,
           v_nro_cuenta,
           v_nro_bin,
           v_tip_tarjeta,
           v_fec_vencimiento,
           v_cod_persona,
           v_tipo
      from TA_IMP_DAT_EMBOZADOS t,
           ta_tarjetas          a,
           ta_cta_tarjetas      b,
           ta_tipos             p
     where t.nro_cuenta = a.nro_cuenta
       and SUBSTR(t.nro_pan_pro_principal, -4, 4) = a.nro_tarjeta
       and t.nro_cuenta = b.nro_cuenta
       and b.cod_modulo = p.cod_modulo
       and b.cod_modalidad = p.cod_modalidad
       and t.nro_cuenta is not null
       and a.vigente = 'S'
       and t.nro_cta_deb_global = v_cta_global
       and rownum=1;
  exception
    when no_data_found then
         begin
           v_actualiza := 'N';
           Select SUBSTR(t.nro_pan_pro_principal, -4, 4),
                  a.nro_cuenta,
                  a.fec_vencimiento,
                  t.cod_persona,
                  'C'
             into v_nro_tarjeta,
                  v_nro_cuenta,
                  v_fec_vencimiento,
                  v_cod_persona,
                  v_tipo
             from TA_IMP_DAT_EMBOZADOS t, ta_tar_global_tmp a
            where t.nro_cuenta = a.nro_cuenta
              and t.cod_persona = a.cod_persona
              and SUBSTR(t.nro_pan_pro_principal, -4, 4) = a.nro_tarjeta
              and t.nro_cta_deb_global = v_cta_global
              and a.cod_persona = v_cod_persona;
         exception
           when no_data_found then
             v_nro_tarjeta := null;
             v_men_error := 'No se encuentra TC.';
             prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - '  ||v_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
            when others then
              prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - ' ||sqlerrm,
                            v_cod_persona,
                            p_nro_cuenta);
         end;
    when others then
      prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - ' ||sqlerrm,
                            v_cod_persona,
                            p_nro_cuenta);
  end;
v_lugar := '05 - Llamada pr_act_tar_cre';
    if v_nro_tarjeta is not null then
      begin
        --Llamada procedimiento pr_act_tar_cre
        pr_act_tar_cre(v_nro_cuenta,
                       v_cod_persona,
                       v_nro_tarjeta,
                       1, --estado global dado de baja
                       p_cod_error,
                       p_men_error);
        if p_cod_error = 200 then
           p_cod_error := 0;
        else
          prg_ins_log_programas(v_nom_programa,
                                v_lugar || ' - '  ||p_cod_error|| ' - '  ||p_men_error,
                                v_cod_persona,
                                p_nro_cuenta);
        end if;
      exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                v_lugar|| ' - '  || p_cod_error || ' - '  ||p_men_error,
                                v_cod_persona,
                                p_nro_cuenta);
      end;
    end if;
  if v_actualiza = 'S' then
            v_lugar := '06 - Update Motivo Credito';
         begin
           pat_tgl.pr_act_motivo(v_cod_persona,
                                     v_nro_cuenta,
                                     v_nro_tarjeta,
                                     p_motivo,
                                     v_cod_causa,
                                     'C',
                                     p_cod_error,
                                     p_men_error);
         exception
          when others then
            v_men_error := 'Error Update Motivo Credito';
            prg_ins_log_programas(v_nom_programa,
                                  v_lugar || ' - '  ||p_cod_error|| ' - '  ||p_men_error || ' - '  || v_men_error,
                                  v_cod_persona, p_nro_cuenta);
        end;
   end if;
v_lugar := '07 - Obtener Tarjeta Virtual';
     begin
        select to_char(d.nro_tarjeta)
          into v_nro_tarjeta
          from ah_tar_debitos d
         where d.nro_cuenta = p_nro_cuenta
           and d.nro_cta_global = v_cta_global
           and d.tar_activa = 'S'
           and d.cod_est_solicitud != 1
           and to_number(d.nro_emision) =
             (select max(to_number(b.nro_emision))
                from ah_tar_debitos b
               where b.nro_cuenta = d.nro_cuenta
                 and b.cod_ent_procesadora = d.cod_ent_procesadora
                 and b.cod_persona = d.cod_persona
                 and b.adherente = d.adherente
                 and b.cod_est_solicitud = d.cod_est_solicitud);
     exception
    when others then
      v_men_error := 'Error al Obtener Nro. Tarjeta Virtual';
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            v_lugar || ' - '  ||p_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
  end;
if v_procesar = 'S' then
    p_cod_transaccion     := to_char(sysdate, 'DDMMYY') || v_nro_tarjeta;
    p_fec_transaccion     := sysdate;
    p_nro_tar_deb_virtual := v_nro_tarjeta;
    p_cod_error           := p_cod_error;
    p_men_error           := p_men_error;
end if;
end;
--------------------------------------------

  -- llama al proc. de cambio de estado para realizar la cancelacion
  procedure pr_can_tar_debpre(p_nro_cuenta   in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta  in ah_tar_debitos.nro_tarjeta%type,
                              p_motivo       in ah_tar_debitos.motivo%type,
                              p_cod_error    out number,
                              p_men_error    out varchar2,
                              p_est_anterior out varchar2) is
    v_lugar     varchar2(10);
    v_men_error varchar2(4000);
    v_cod_error number(6);
    v_error exception;
    v_val_estado   varchar2(50);
    v_cod_estado   ah_tar_debitos.cod_est_solicitud%type;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_CAN_TAR_DEBPRE';

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    v_lugar := '01';
    -- obtener codigo de estado baja
    v_val_estado := fue_obt_des_refcodes('EST_TAR_DEBITO', '1', 'S');
    v_lugar      := '02';
    if upper(trim(v_val_estado)) !=
       upper('Referencia  no registrada en el Sistema') then
      -- guardamos estado anterior
      v_lugar := '03';
      begin
        select a.cod_est_solicitud
          into v_cod_estado
          from ah_tar_debitos a
         where a.nro_cuenta = p_nro_cuenta
           and a.nro_tarjeta = p_nro_tarjeta;
        p_est_anterior := fue_obt_des_refcodes('EST_TAR_DEBITO',
                                               v_cod_estado,
                                               'S');
      exception
        when no_data_found then
          v_men_error := 'No se encuentra Estado Anterior de la TD.';
          p_cod_error := v_err_sql;
          p_men_error := v_men_error;
          prg_ins_log_programas(v_nom_programa,
                                p_men_error,
                                null,
                                p_nro_cuenta);
        when others then
          v_men_error := 'Error al obtener Estado Anterior de la TD.';
          p_cod_error := v_err_sql;
          p_men_error := v_men_error;
          prg_ins_log_programas(v_nom_programa,
                                p_men_error,
                                null,
                                p_nro_cuenta);
      end;
      -- actualiza el estado a Baja
      v_lugar := '04';
      pat_tgl.pr_act_est_tarjeta(p_nro_cuenta,
                                 p_nro_tarjeta,
                                 v_val_estado,
                                 v_cod_error,
                                 v_men_error);
      p_cod_error := v_cod_error;
      p_men_error := v_men_error;

      --Si el motivo de cancelacion no es nulo, se actualiza
      if p_cod_error = v_pro_correcto and p_motivo is not null then
        begin
          update ah_tar_debitos a
             set a.motivo = p_motivo
           where a.nro_cuenta = p_nro_cuenta
             and a.nro_tarjeta = p_nro_tarjeta;
        exception
          when others then
            v_men_error := 'Error al actualizar motivo de cancelacion!';
            p_cod_error := v_err_sql;
            p_men_error := v_men_error;
        end;
        if p_cod_error = v_pro_correcto then
          commit;
        end if;
      end if;
    else
      v_lugar     := '05';
      v_men_error := 'Error: Estado para Bloqueo no configurado!';
      raise v_error;
    end if;
  exception
    when v_error then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            null,
                            p_nro_cuenta);
    when others then
      v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                            'Error al cancelar TD' || ' - ' || sqlerrm,
                            1,
                            4000);
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            null,
                            p_nro_cuenta);
  end;

  /**
  * Programa para bloqueo automatico de tarjetas de debito en el proceso de cierre
  ---------------------------------------------------------------------------------
  * Se bloquean las tarjetas de debito/prepaga si reunen cualquiera de las siguientes condiciones:
  * si el cliente tiene al menos un tdc con mora >= 5 dias
  * si el cliente se encuentra Inhibido: Cliente incluido en la lista de impedidos para operar (clientes bloqueados por matriz PLD u otros)
  **/
  procedure pr_blo_aut_tar_debpre is

    v_min_can_dia_mora ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('TAR_INI_DIA_MORA');
    v_des_mail         ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('PRO_BLO_DES_MAIL');
    v_nom_programa     varchar2(50) := 'PAT_TGL.PR_BLO_AUT_TAR_DEBPRE';

    cursor cur_bloqueos is
      select a.cod_persona,
             a.nro_cuenta,
             a.nro_cta_global,
             a.nro_tarjeta,
             'S' ind_bloqueo
        from ah_tar_debitos a
       where a.cod_est_solicitud = '0'
         and a.cod_ent_procesadora = v_ent_global
         and (exists
              (select 'S'
                 from ta_cta_tarjetas b, ge_cta_clientes c, ba_personas d
                where b.nro_cuenta = c.nro_cuenta
                  and c.cod_persona = d.cod_persona
                  and d.cod_persona = a.cod_persona
                  and b.dia_mora >= TO_NUMBER(v_min_can_dia_mora)) or exists
              (select 'S'
                 from ge_per_inhibidas e
                where e.cod_persona = a.cod_persona
                  and e.estado = 'I'));

    v_men_error      varchar2(4000);
    v_cod_error      number(6);
    v_lugar          varchar2(10) := '00';
    v_cod_persona    ba_personas.cod_persona%type;
    v_nro_tarjeta    ah_tar_debitos.nro_tarjeta%type;
    v_nro_cuenta     ge_cuentas.nro_cuenta%type;
    v_nro_cta_global ah_tar_debitos.nro_cta_global%type;
    v_hay_error      boolean;
    v_estado         varchar2(6) := fug_obt_pardinamico('COD_BLO_TAR_DEBPRE');
    v_est_global     varchar2(60);

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    v_lugar     := '01';
    v_hay_error := false;
    for reg in cur_bloqueos loop
      begin
        v_cod_persona := reg.cod_persona;
        v_nro_cuenta  := reg.nro_cuenta;
        v_nro_tarjeta := reg.nro_tarjeta;
        v_est_global  := fue_obt_des_refcodes('EST_TAR_DEBITO',
                                              v_estado,
                                              'S');
        --Obtener el nro. cuenta global
        v_nro_cta_global := reg.nro_cta_global;

        v_lugar := '02';
        -- se inserta en la tabla ah_sol_upd_tar_debito la solicitud de cambio de estado de Tarjeta de Debito en Global
        begin
          v_lugar := '03';
          insert into ah_sol_upd_tar_debitos
            (fec_sistema,
             descripcion,
             usu_solicitud,
             nro_cta_global,
             est_global,
             nro_tar_debito,
             estado)
          values
            (trunc(sysdate),
             'Solicitud de Cambio a estado ' || v_est_global ||
             'para la Tarjeta: ' || v_nro_tarjeta || ' Cta: ' ||
             v_nro_cuenta || ' en el proceso de cierre.',
             'IT',
             v_nro_cta_global,
             v_est_global,
             v_nro_tarjeta,
             'S');

          if sql%notfound then
            prg_ins_log_programas(v_nom_programa,
                                  '1)Error al insertar en ah_sol_upd_tar_debito. Lugar: ' ||
                                  v_lugar || ' - ' ||
                                  substr(sqlerrm, 1, 4000),
                                  v_cod_persona,
                                  v_nro_cuenta);
          end if;

        exception
          when others then
            prg_ins_log_programas(v_nom_programa,
                                  '2)Error al insertar en ah_sol_upd_tar_debito. Lugar: ' ||
                                  v_lugar || ' - ' ||
                                  substr(sqlerrm, 1, 4000),
                                  v_cod_persona,
                                  v_nro_cuenta);
        end;

        v_lugar := '04';
        -- se bloquea la tarjeta en itgf
        pat_tgl.pr_blo_tar_debpre(reg.nro_cuenta,
                                  reg.nro_tarjeta,
                                  'S',
                                  v_cod_error,
                                  v_men_error);
        if v_cod_error != v_pro_correcto then
          prg_ins_log_programas(v_nom_programa,
                                'Error al bloquear en ITGf. Lugar: ' ||
                                v_lugar || ' - ' || v_cod_error || '-' ||
                                v_men_error,
                                reg.cod_persona,
                                reg.nro_cuenta);
          v_hay_error := true;
        end if;

        if v_hay_error then
          begin
            v_lugar := '05';
            it_mail.mail(fug_obt_dir_correo, --mail remitente
                         v_des_mail, --mail destinatarios
                         'Error de Cierre en Proceso Bloqueo Automatico', --asunto
                         -- body --
                         'ERROR EN PROCESO BLOQUEO AUTOMATICO.(' ||
                         v_nom_programa || ')' || chr(10) ||
                         'Favor verificar en la consulta dinamica Bloqueo de Tarjetas Debito-Prepaga(CD_BLOTAR).' ||
                         chr(10) || chr(10) || 'Atentamente.');
          exception
            when others then
              prg_ins_log_programas(v_nom_programa,
                                    'Error al enviar el mail. Lugar: ' ||
                                    v_lugar || ' - ' ||
                                    substr(sqlerrm, 1, 4000),
                                    'S/D',
                                    'S/D');
          end;
        end if;
      exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                '1) Lugar: ' || v_lugar || 'Nro.Tarjeta: ' ||
                                v_nro_tarjeta || ' - ' ||
                                substr(sqlerrm, 1, 4000),
                                v_cod_persona,
                                v_nro_cuenta);
      end;

    end loop;

  exception
    when others then
      prg_ins_log_programas(v_nom_programa,
                            '2) Lugar: ' || v_lugar || ' - ' ||
                            substr(sqlerrm, 1, 4000),
                            'S/D',
                            'S/D');
  end;

  /**
  * Procedimiento para reemplazar/reimprimir tarjeta de debito.
  **/
  procedure pr_tar_reimprimir(p_nro_cuenta      in ah_tar_debitos.nro_cuenta%type,
                              p_nro_tarjeta     in ah_tar_debitos.nro_tarjeta%type,
                              p_nro_bin         in ah_tar_debitos.nro_bin%type,
                              p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                              p_tip_tarjeta     in ah_tar_debitos.tip_tar_debito%type,
                              p_cod_error       out number,
                              p_men_error       out varchar2) is

    v_lugar          varchar2(10) := '00';
    v_cod_error      varchar2(10);
    v_men_error      varchar2(4000);
    v_cod_persona    ah_tar_debitos.cod_persona%type;
    v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type;
    v_nro_tarjeta    ah_tar_debitos.nro_tarjeta%type;
    v_nro_cta_global ah_tar_debitos.nro_cta_global%type;
    v_id_producto    ah_tar_debitos.id_producto%type;
    v_nom_programa   varchar2(50) := 'PAT_TLG.PR_TAR_REIMPRIMIR';

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    v_lugar     := '01';
    v_cod_error := v_pro_correcto;

    -- buscamos la tajeta actual para dar de baja
    begin
      select a.cod_persona, a.nro_tarjeta, a.nro_cta_global, a.id_producto
        into v_cod_persona, v_nro_tarjeta, v_nro_cta_global, v_id_producto
        from ah_tar_debitos a, ba_cod_referencias b
       where a.nro_cuenta = p_nro_cuenta
         and a.cod_ent_procesadora = v_ent_global
         and a.cod_est_solicitud = b.val_minimo
         and b.dominio = 'EST_TAR_DEB_EXT'
         and to_number(a.nro_emision) =
             (select max(to_number(b.nro_emision))
                from ah_tar_debitos b
               where b.nro_cuenta = a.nro_cuenta
                 and b.cod_ent_procesadora = a.cod_ent_procesadora
                 and b.cod_persona = a.cod_persona
                 and b.adherente = a.adherente
                 and b.cod_est_solicitud = a.cod_est_solicitud);
    exception
      when others then
        v_cod_error   := v_err_sql;
        v_men_error   := 'Error al buscar datos de la cuenta ' ||
                         p_nro_cuenta || '. ' || sqlerrm;
        v_cod_persona := 's/d';
        v_nro_tarjeta := 's/d';
    end;

    -- validacion para datos requeridos en baja y alta de tarjeta debito reimpresa
    if v_cod_error = v_pro_correcto then

      v_lugar := '02';
      if UPPER(TRIM(p_tip_tarjeta)) = v_cod_tar_deb_virtual then
        v_tip_tar_debito := 'MV';
      elsif UPPER(TRIM(p_tip_tarjeta)) = v_cod_tar_deb_fisica then
        v_tip_tar_debito := 'MF';
      else
        prg_ins_log_programas(v_nom_programa,
                              '1) Tipo de tarjeta no se encuentra: ' ||
                              v_tip_tar_debito || ' - ' ||p_tip_tarjeta || ' - ' ||
                              substr(sqlerrm, 1, 4000),
                              v_cod_persona,
                              p_nro_cuenta);
        v_tip_tar_debito := UPPER(TRIM(p_tip_tarjeta));
      end if;

      -- baja de tarjeta debito en itgf
      begin
        v_lugar := '03';
        pat_tgl.pr_act_est_tarjeta(p_nro_cuenta,
                                   v_nro_tarjeta,
                                   'Baja',
                                   v_cod_error,
                                   v_men_error);

        if v_cod_error != v_pro_correcto then
          p_cod_error := v_cod_error;
          p_men_error := 'Error al actualizar(baja) la tarjeta ' ||
                         v_nro_tarjeta || '. Descripcion:' || v_men_error;
        else
          p_cod_error := v_pro_correcto;
          p_men_error := 'Tarjeta ' || v_nro_tarjeta ||
                         ' dado de Baja con Exito!';
        end if;

      exception
        when others then
          p_cod_error := v_cod_error;
          p_men_error := 'Error update estado tarjeta ' || v_nro_tarjeta ||
                         '. Descripcion:' || substr(sqlerrm, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                '2) Error al actualizar la tarjeta ' ||
                                v_nro_tarjeta || '. Lugar: ' || v_lugar ||
                                'Nro.Cuenta: ' || NVL(p_nro_cuenta, 'S/D') ||
                                ' - ' || p_cod_error || '-' || p_men_error,
                                nvl(v_cod_persona, 'S/D'),
                                nvl(p_nro_cuenta, 'S/D'));
      end;

      -- alta de tarjeta debito en itgf
      begin
        v_lugar := '04';
        pat_tgl.pr_alt_tar_debpre(v_nro_cta_global,
                                  v_id_producto,
                                  p_nro_cuenta,
                                  p_nro_bin,
                                  p_nro_tarjeta,
                                  p_fec_vencimiento,
                                  p_tip_tarjeta,--v_tip_tar_debito,
                                  v_cod_error,
                                  v_men_error);

        if v_cod_error != v_pro_correcto then
          p_cod_error := v_cod_error;
          p_men_error := 'Error al insertar(alta)la tarjeta ' ||
                         p_nro_tarjeta || '. Descripcion:' || v_men_error;
        else
          p_cod_error := v_pro_correcto;
          p_men_error := 'Tarjeta ' || p_nro_tarjeta ||
                         ' dado de Alta con Exito!';
        end if;

      exception
        when others then
          p_cod_error := v_cod_error;
          p_men_error := 'Error al dar de alta la tarjeta ' ||
                         p_nro_tarjeta || '. Descripcion:' ||
                         substr(sqlerrm, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                '3) Lugar: ' || v_lugar || ' - ' ||
                                p_cod_error || '-' || p_men_error,
                                nvl(v_cod_persona, 'S/D'),
                                nvl(p_nro_cuenta, 'S/D'));
      end;

    else
      p_cod_error := v_cod_error;
      p_men_error := v_men_error ||
                     '. No se puede realizar las operaciones de BAJA y ALTA de la tarjeta ' ||
                     p_nro_tarjeta;
      prg_ins_log_programas(v_nom_programa,
                            '4) Lugar: ' || v_lugar || 'Nro.Cuenta: ' ||
                            NVL(p_nro_cuenta, 'S/D') || ' - ' ||
                            p_cod_error || '-' || p_men_error,
                            nvl(v_cod_persona, 'S/D'),
                            nvl(p_nro_cuenta, 'S/D'));
    end if;

  exception
    when others then
      p_cod_error := v_cod_error;
      p_men_error := 'Error en ' || v_nom_programa || '. Descripcion:' ||
                     v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            '5) Lugar: ' || v_lugar || 'Nro.Cuenta: ' ||
                            NVL(p_nro_cuenta, 'S/D') || ' - ' ||
                            p_cod_error || '-' || p_men_error,
                            nvl(v_cod_persona, 'S/D'),
                            nvl(p_nro_cuenta, 'S/D'));
  end;

  /*Reimpresion de TD*/
  procedure pr_ser_reimprimir(p_nro_cta     in ta_cta_tarjetas.nro_cuenta%type,
                               p_nro_tarjeta in ah_tar_debitos.nro_tarjeta%type,
                               p_tip_tarjeta in ah_tar_debitos.tip_tar_debito%type,
                               p_cod_error   out number,
                               p_men_error   out varchar2) is
    v_url          varchar2(4000) := fug_obt_pardinamico('WS_REI_TAR_GLO');
    v_content      varchar2(4000);
    v_lugar        varchar2(10);
    v_men_error    varchar2(4000);
    v_cod_err_ws   number(6);
    v_error        exception;
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_SERV_REIMPRIMIR';
    v_cta_global   ge_cta_dat_adicionales.val_parametro%type;
    v_cod_persona  ah_tar_debitos.cod_persona%type;
    v_estado       number;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;
    begin
      select a.cod_persona
        into v_cod_persona
        from ah_tar_debitos a
       where a.nro_cuenta = p_nro_cta
         and a.cod_ent_procesadora = v_ent_global
         and a.tar_activa = 'S';
    exception
      when others then
        p_cod_error := v_err_sql;
        p_men_error := 'Error al buscar datos de la cuenta ' || p_nro_cta || '. ' ||
                       sqlerrm;
    end;
    if UPPER(TRIM(p_tip_tarjeta)) = 'MV' then
      v_estado := v_cod_tar_deb_virtual;
    elsif UPPER(TRIM(p_tip_tarjeta)) = 'MF' then
      v_estado := v_cod_tar_deb_fisica;
    end if;
    v_lugar      := '01';
    -- se crea la estructura json para pasar al ws
    v_content := '{' || '"accountNumber": "' || p_nro_cta ||'",'
                     || '"cardNumber": "' || p_nro_tarjeta ||'",'
                     || '"cardType": "' || v_estado || '"}';
    v_lugar   := '02';
    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           p_nro_cta,
                           v_cod_persona,
                           'M',
                           'PUT',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service
    if v_cod_err_ws != v_cod_msg_exito then
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
    else
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'), 'Transaccion Exitosa!');
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_SERV_REIMPRIMIR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            v_cod_persona,
                            p_nro_cta);
  end;
  /**
  * Procedimiento para alta de tarjeta de credito.
  **/

  procedure pr_alt_tar_credito(p_nro_cuenta      in ta_tar_global_tmp.nro_cuenta%type,
                               p_cod_persona     in ta_tar_global_tmp.cod_persona%type,
                               p_nro_tarjeta     in ta_tar_global_tmp.nro_tarjeta%type,
                               p_fec_vencimiento in ta_tar_global_tmp.fec_vencimiento%type,
                               p_tip_tarjeta     in ta_tar_global_tmp.tip_tarjeta%type,
                               p_cod_producto    in ta_tar_global_tmp.cod_producto%type,
                               p_cod_error       out number,
                               p_men_error       out varchar2) is
    v_cod_error    varchar2(6) := v_pro_correcto;
    v_men_error    varchar2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                         'Transaccion Exitosa!');
    v_cod_programa varchar2(30) := 'PAT_TGL.PR_ALT_TAR_CREDITO';
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;


    -- insertamos los datos(tc) del sw en la tabla temporal
    insert into ta_tar_global_tmp
      (nro_cuenta,
       cod_persona,
       nro_tarjeta,
       fec_vencimiento,
       tip_tarjeta,
       cod_producto,
       cod_estado)
    values
      (p_nro_cuenta,
       p_cod_persona,
       p_nro_tarjeta,
       p_fec_vencimiento,
       p_tip_tarjeta,
       p_cod_producto,
       '0'); --estado inicial normal
    -- si no hubo error

    p_cod_error := v_cod_error;
    p_men_error := v_men_error;

    commit;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr(sqlerrm, 1, 4000);
      prg_ins_log_programas(v_cod_programa,
                            p_cod_error || ' - ' || p_men_error);
  end;
  /**
  * Procedimiento para alta de tarjeta de credito desde solicitud.
  **/

  procedure pr_alt_tar_sol_credito(p_cod_persona   in ta_tar_global_tmp.cod_persona%type, --no
                                   p_nro_solicitud in ta_solicitudes.nro_solicitud%type,
                                   p_cod_error     out number,
                                   p_men_error     out varchar2) is
    v_cod_error       varchar2(6) := v_pro_correcto;
    v_men_error       varchar2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                            'Transaccion Exitosa!');
    v_nom_programa    varchar2(30) := 'PAT_TGL.PR_ALT_TAR_SOL_CREDITO';
    v_error           exception;
    v_lugar           varchar2(200) := '000';
    v_existe          varchar(2) := 'N';
    v_nro_cuenta      varchar2(15);
    v_cod_persona     varchar2(15);
    v_nro_tarjeta     varchar2(15);
    v_fec_vencimiento date;
    v_cod_estado      varchar2(2);
    ----
    v_tip_embozado      ta_solicitudes.tip_embozado%type;
    v_nom_embozado      ta_solicitudes.nom_embozado%type;
    v_cod_modulo        ta_solicitudes.cod_modulo%type;
    v_cod_modalidad     ta_solicitudes.cod_modalidad%type;
    v_cod_oficina       ta_solicitudes.cod_oficina%type;
    v_fec_solicitud     ta_solicitudes.fec_solicitud%type;
    v_afinidad          ta_solicitudes.afinidad%type;
    v_sub_afinidad      ta_solicitudes.sub_afinidad%type;
    v_cod_rub_economico ta_solicitudes.cod_rub_economico%type;
    v_cod_tip_cierre    ta_solicitudes.cod_tip_cierre%TYPE;
    v_tip_envio         ta_solicitudes.tip_envio%TYPE;
    v_referencia        ta_solicitudes.referencia%TYPE;
    v_nro_documento     ba_personas.nro_documento%type;
    v_lin_credito       ta_solicitudes.monto%type;
    v_tip_cobro         ta_solicitudes.tip_cobro%type;
    v_tip_cierre        ta_tipos.tip_cierre%type;
    v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(5);
    v_fec_vto_cierre    ta_cal_cierres.fec_vencimiento%TYPE;
    v_fec_cierre        ta_cal_cierres.fec_cierre%TYPE;
    v_ret_extracto      ba_tab_dat_adicionales.val_parametro%TYPE;
    v_mot_ret_extracto  ba_tab_dat_adicionales.val_parametro%TYPE;
    v_tip_plastico      ta_solicitudes.tip_plastico%TYPE;
    v_deb_automatico    ta_solicitudes.deb_automatico%TYPE;
    v_nro_cta_debito    ta_solicitudes.nro_cta_debito%TYPE;

  CURSOR c_garantias IS
    SELECT nro_solicitud,
           nro_garantia,
           cod_garantia,
           mto_aplicado
      FROM ta_sol_garantias
     WHERE nro_solicitud = p_nro_solicitud;

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
      execute immediate 'ALTER SESSION SET NLS_DATE_FORMAT = ''DD/MM/RRRR HH24:MI:SS''';
    end;

    --procedimiento que verifica la existencia de un registro asociado al cliente.
    pr_ver_cta_credito(p_cod_persona, v_existe, v_cod_error, v_men_error);
    if v_cod_error<>0 then
      v_lugar     := 'ERR_SP_VER_CTA';
      v_cod_error := v_err_sql;
      v_men_error := SUBSTR(v_lugar || '|Error al verificar existencia de registros asociados al cliente ' || p_cod_persona || '. ' || SQLERRM, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                            ' # '|| v_men_error);
      raise v_error;
    end if;
    v_lugar := '002';
    --
    if v_existe = 'S' then
      --en el caso de que ya exista
      begin
        select s.nro_cuenta,
               s.cod_persona,
               substr(s.nro_pan_pro_principal, 13, 16) nro_tarjeta
          into v_nro_cuenta, v_cod_persona, v_nro_tarjeta
          from ta_imp_dat_embozados s
         where s.cod_persona= p_cod_persona
           and estado like 'E';
      exception
        when others then
          v_lugar     := 'ERR_GET_ENVELOPE';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|No se encontraron sobres en estado Entregado vinculados al cliente ' || p_cod_persona || '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
       end;

      begin
          select a.fec_vencimiento, cod_estado
            into v_fec_vencimiento, v_cod_estado
            from Ta_Tar_Global_Tmp a
           where a.cod_persona = p_cod_persona
             and nvl(cod_estado, '15') in (/*'0',*/ '15');--consultar en principio estaria en 15
        exception
        when no_data_found then
           begin
              select a.cod_estado
                into v_cod_estado
                FROM Ta_Tar_Global_Tmp a
               where a.cod_persona = p_cod_persona;

              v_lugar     := 'ERR_GET_TMP_NOT_ENABLED_CARD';
              v_cod_error := v_err_sql; 

              v_men_error := substr(v_lugar || '|No se encontró TC en estado 15. El cliente ' || p_cod_persona || ' posee una TC en estado: ' || v_cod_estado, 1, 4000);
              
              prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || ' # ' || v_men_error);
              RAISE v_error;
      
           exception
              when no_data_found then
                 v_lugar     := 'TMP_CARD_NOT_FOUND';
                 v_cod_error := v_err_sql;
                 v_men_error := substr(v_lugar || '|El cliente ' || p_cod_persona || ' no posee ninguna TC en TA_TAR_GLOBAL_TMP.', 1, 4000);
                 
                 prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || ' # ' || v_men_error);
                 RAISE v_error;
           END;
      
        when others then
           v_lugar     := 'ERR_TMP';
           v_cod_error := v_err_sql;
           v_men_error := substr(v_lugar || '|Error al consultar TC de cliente ' || p_cod_persona || '.' || SQLERRM, 1, 4000);
           
           prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || '- ' || v_cod_error || ' # ' || v_men_error);       
            raise v_error;
      end;
      pr_act_tar_cre(v_nro_cuenta,
                     v_cod_persona,
                     v_nro_tarjeta,
                     '0', --estado normal
                     p_cod_error,
                     p_men_error);--exito retorna 200
      if p_cod_error = 200 then
          begin
            update ta_tar_global_tmp s
               set s.cod_estado = '0'
             where s.cod_persona = v_cod_persona
               and s.nro_cuenta = v_nro_cuenta
               and s.nro_tarjeta = v_nro_tarjeta;
            commit;
          exception
            when others then
            v_lugar     := 'ERR_UPD_GLB_TMP';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al cambiar el estado de la tarjeta en la tabla TA_TAR_GLOBAL_TMP vinculada al cliente' || p_cod_persona || ' y la cuenta ' || v_nro_cuenta ||
                           '.'||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            raise v_error;
        end;        
        --pudo cambiar exitosamente de estado
        --se debe recuperar los datos e ingresar a ta_tarjetas
        --Recuperamos datos para las inserciones
        begin
          select s.nom_embozado,
                 s.tip_embozado,
                 s.cod_modulo,
                 s.cod_modalidad,
                 s.cod_oficina,
                 s.fec_solicitud,
                 s.afinidad,
                 s.sub_afinidad,
                 s.cod_rub_economico,
                 s.monto,
                 s.deb_automatico,
                 s.nro_cta_debito,
                 s.tip_cobro,
                 s.cod_tip_cierre,
                 s.tip_envio,
                 s.referencia,
                 s.tip_plastico
            into v_nom_embozado,
                 v_tip_embozado,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_fec_solicitud,
                 v_afinidad,
                 v_sub_afinidad,
                 v_cod_rub_economico,
                 v_lin_credito,
                 v_deb_automatico,
                 v_nro_cta_debito,
                 v_tip_cobro,
                 v_cod_tip_cierre,
                 v_tip_envio,
                 v_referencia,
                 v_tip_plastico
            from ta_solicitudes s
           where s.nro_solicitud = p_nro_solicitud;
        exception
          when others then
          v_lugar     := 'ERR_GET_REQUEST';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al recuperar datos de la solicitud ' || p_nro_solicitud || 
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;

        begin
          /*select tip_cierre
            into v_tip_cierre
            from ta_tipos a
           where a.afinidad = v_afinidad;*/
           select nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP',fug_obt_parentes(fug_obt_pardinamico('COD_ENT_GLOBAL'),'GLP_CIERRE')),'4')
           into v_tip_cierre
           from dual;
        exception
          when others then
          v_lugar     := 'ERR_GET_CLOSE_CODE';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al recuperar tipo de cierre.' ||
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        begin
          SELECT c.fec_cierre, c.fec_vencimiento
            INTO v_fec_cierre, v_fec_vto_cierre
            FROM ta_cal_cierres c
           WHERE c.ano = to_char(v_fec_actual, 'YYYY')
             AND c.mes = to_char(v_fec_actual, 'MM')
             AND c.cod_ent_procesadora =
                 fug_obt_pardinamico('COD_ENT_GLOBAL')
             AND c.cod_modalidad = fug_obt_pardinamico('TA_COD_MOD_PREAPROBADO')
             and c.cod_tip_cierre=nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP',fug_obt_parentes(fug_obt_pardinamico('COD_ENT_GLOBAL'),'GLP_CIERRE')),4);
        exception
          when others then
            v_fec_cierre     := null;
            v_fec_vto_cierre := null;
        end;

        IF v_fec_cierre < v_fec_actual THEN
          begin
          SELECT c.fec_cierre, c.fec_vencimiento
          INTO v_fec_cierre, v_fec_vto_cierre
          FROM ta_cal_cierres c
         WHERE c.ano = to_char(add_months(v_fec_actual,1), 'YYYY')
           AND c.mes = to_char(add_months(v_fec_actual,1), 'MM')
           AND c.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
           AND c.cod_modalidad = fug_obt_pardinamico('TA_COD_MOD_PREAPROBADO')
           and c.cod_tip_cierre=nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP',fug_obt_parentes(fug_obt_pardinamico('COD_ENT_GLOBAL'),'GLP_CIERRE')),4);
          exception
            when others then
              v_fec_cierre:=null;
              v_fec_vto_cierre:=null;
          end;
        END IF;

        begin
          insert into it.ta_cta_tarjetas
            (nro_cuenta,
             denominacion,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_moneda,
             lin_credito,
             lin_cuotas,
             sal_facturar,
             sal_facturado,
             sal_financiado,
             sal_ult_extracto,
             sal_cuo_pendientes,
             mto_pag_minimo,
             sal_pag_minimo,
             mto_mora,
             dia_mora,
             mto_autorizaciones,
             mto_int_compras,
             mto_pag_mes,
             mto_gas_mora,
             estado,
             est_administradora,
             fec_solicitud,
             fec_apertura,
             fec_ult_pago,
             fec_ult_compra,
             fec_ult_operacion,
             fec_ult_extracto,
             fec_ult_cierre,
             fec_vct_ult_cierre,
             tip_cierre,
             cob_gas_financiero,
             tip_tas_financiacion,
             tip_com_emision,
             tas_financiacion,
             tas_adelanto,
             tas_mora,
             tas_cuotas,
             deb_automatico,
             tip_cobro,
             nro_cta_debito,
             mto_min_pago,
             por_pag_minimo,
             cod_usu_promotor,
             mar_mora,
             mar_excedido,
             mar_recuperado,
             mar_bloqueo,
             con_costo,
             nro_solicitud,
             cod_causa,
             cod_canal,
             cod_campana,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             cat_automatica,
             fec_juicio,
             cod_ent_juicio,
             max_atraso,
             pro_atraso,
             nro_linea,
             en_juicio,
             cat_aut_anterior,
             fec_activacion,
             fec_cancelacion,
             tas_efectiva,
             mto_aut_cuotas,
             afinidad,
             sub_afinidad,
             sal_procesadora,
             cod_rub_economico,
             cod_tip_cierre,
             franqueo,
             ind_seg_vida,
             cod_exc_cargo,
             lin_especial,
             tas_especial,
             mto_car_suspendido,
             mto_car_sus_aplicado,
             tip_plastico)
          values
            (v_nro_cuenta,
             v_nom_embozado,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             'GS', --v_cod_moneda,
             v_lin_credito,
             0, --v_lin_cuotas,
             0, --v_sal_facturar,
             0, --v_sal_facturado,
             0, --v_sal_financiado,
             0, --v_sal_ult_extracto,
             0, --v_sal_cuo_pendientes,
             0, --v_mto_pag_minimo,
             0, --v_sal_pag_minimo,
             0, --v_mto_mora,
             0, --v_dia_mora,
             0, --v_mto_autorizaciones,
             0, --v_mto_int_compras,
             0, --v_mto_pag_mes,
             0, --v_mto_gas_mora,
             'N', --v_estado,
             null, --v_est_administradora,
             v_fec_solicitud,
             v_fec_actual, --v_fec_apertura,
             null, --v_fec_ult_pago,
             null, --v_fec_ult_compra,
             null, --v_fec_ult_operacion,
             null, --v_fec_ult_extracto,
             v_fec_cierre,--null, --v_fec_ult_cierre,
             v_fec_vto_cierre,--null, --v_fec_vct_ult_cierre,
             v_tip_cierre, --v_tip_cierre,--traer de ta_tipos
             null, --v_cob_gas_financiero,
             null, -- v_tip_tas_financiacion,
             0, --v_tip_com_emision,
             0, --v_tas_financiacion,
             0, --v_tas_adelanto,
             0, --v_tas_mora,
             0, --v_tas_cuotas,
             v_deb_automatico,
             v_tip_cobro,
             v_nro_cta_debito,
             null, --v_mto_min_pago,
             null, --v_por_pag_minimo,
             null, --v_cod_usu_promotor,
             null, --v_mar_mora,
             null, --v_mar_excedido,
             null, --v_mar_recuperado,
             null, --v_mar_bloqueo,
             null, --v_con_costo,
             p_nro_solicitud,
             null, --v_cod_causa,
             null, --v_cod_canal,
             null, --v_cod_campana,
             user,
             sysdate,
             user,
             sysdate,
             1, --v_cat_automatica,
             null, --v_fec_juicio,
             null, --v_cod_ent_juicio,
             null, --v_max_atraso,
             null, --v_pro_atraso,
             null, --v_nro_linea,
             null, --v_en_juicio,
             null, --v_cat_aut_anterior,
             v_fec_actual, --v_fec_activacion,
             null, --v_fec_cancelacion,
             null, --v_tas_efectiva,
             null, --v_mto_aut_cuotas,
             v_afinidad,
             v_sub_afinidad,
             null, --v_sal_procesadora,
             v_cod_rub_economico,
             v_cod_tip_cierre, --v_cod_tip_cierre,
             null, --v_franqueo,
             null, --v_ind_seg_vida,
             null, --v_cod_exc_cargo,
             0, --v_lin_especial,
             0, --v_tas_especial,
             0, --v_mto_car_suspendido,
             0, --v_mto_car_sus_aplicado
             v_tip_plastico);
        exception
          when others then
          v_lugar     := 'ERR_INS_ACCOUNT';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar en ta_cta_tarjetas. Cuenta Nro ' || v_nro_cuenta || 
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;

        begin
          insert into it.ta_tarjetas
            (nro_cuenta,
             nro_tarjeta,
             cod_persona,
             cod_estado,
             fec_vencimiento,
             cod_causa,
             nom_embozar,
             nom_enviar,
             vigente,
             fec_emision,
             fec_solicitud,
             tip_envio,
             referencia,
             nro_planilla,
             tip_planilla,
             nro_pla_anterior,
             fec_entrega,
             fec_activacion,
             observacion,
             pre_embozada,
             rel_tarjeta,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             motivo,
             tip_embozado,
             id_producto)
          values
            (v_nro_cuenta,
             v_nro_tarjeta,
             v_cod_persona,
             /*nvl(v_cod_estado, '0')*/'6',--estado normal
             v_fec_vencimiento,
             null,
             v_nom_embozado,--ver
             null,
             'S', --v_vigente 'S',al realizar los pagos verifica la vigencia
             sysdate,
             v_fec_solicitud, --v_fec_solicitud,
             v_tip_envio, --_tip_envio,
             v_referencia, --v_referencia,
             null, --v_nro_planilla,
             null, --v_tip_planilla,
             null, --v_nro_pla_anterior,
             null, --v_fec_entrega,
             v_fec_actual, --v_fec_activacion,
             null, --v_observacion,
             null, --v_pre_embozada,
             '0', --relacion tarjeta ver que poner
             user,
             sysdate,
             user,
             sysdate,
             null, --v_motivo,
             'MF',
             '38');--si ya posee esta cuenta implica que ya fue reemplazada

        exception
          when others then
          v_lugar     := 'ERR_INS_CARD';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar en ta_tarjetas. Cuenta Nro ' || v_nro_cuenta || 
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        begin
          insert into it.ge_cta_clientes
            (cod_persona,
             nro_cuenta,
             dig_verificador,
             cod_oficina,
             cod_modulo,
             cod_modalidad,
             relacion,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             est_relacion)
          values
            (v_cod_persona,
             v_nro_cuenta,
             0,
             v_cod_oficina,
             v_cod_modulo,
             v_cod_modalidad,
             'P',
             user,
             sysdate,
             user,
             sysdate,
             'A');

        exception
          when others then
          v_lugar     := 'ERR_INS_REL_CTA_CLI';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar en ge_cta_clientes. Cuenta Nro ' || v_nro_cuenta || 
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;

        FOR c IN c_garantias LOOP
          BEGIN
            INSERT INTO ta_cta_garantias
              (nro_cuenta,
               nro_garantia,
               cod_garantia,
               mto_aplicado,
               mto_apl_computable)
            VALUES
              (v_nro_cuenta,
               c.nro_garantia,
               c.cod_garantia,
               c.mto_aplicado,
               0);
          EXCEPTION
              WHEN OTHERS THEN
                v_lugar     := 'ERR_INS_WAR_REQ';
                v_cod_error := v_err_sql;
                v_men_error := substr(v_lugar || '|Error al insertar garantia de la solicitud. Cuenta Nro ' || v_nro_cuenta || 
                                      '.'||sqlerrm,1,4000);
                                      prg_ins_log_programas(v_nom_programa,
                                      'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                      ' # '|| v_men_error);
                RAISE v_error;
          END;
        END LOOP;

       begin
        insert into it.ge_cta_dat_adicionales
        (nro_cuenta,
         parametro,
         val_parametro,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion)
        values
        (v_nro_cuenta,
         'COD_PRO_TDC_GLOBAL',
         '38',
         user,
         sysdate,
         user,
         sysdate);
      exception
        when others then
          v_lugar     := 'ERR_INS_PROD_ACCOUNT';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar información del parámetro COD_PRO_TDC_GLOBAL en ge_cta_dat_adicionales' ||
                                '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
      end;

        BEGIN
          SELECT nvl(val_parametro,'N')
            INTO v_ret_extracto
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'TA_SOLICITUDES'
             AND parametro    = 'RET_EXTRACTO'
             AND referencia   = p_nro_solicitud;
        EXCEPTION
          WHEN no_data_found THEN
            v_ret_extracto := 'N';
        END;

        BEGIN
          INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          VALUES
            (v_nro_cuenta,
             'RET_EXTRACTO',
             v_ret_extracto);
        EXCEPTION
          WHEN OTHERS THEN
            v_lugar     := 'ERR_INS_EXTRACT';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al insertar parametro de retencion de extracto en ge_cta_dat_adicionales' ||
                           '.'||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            RAISE v_error;
        END;

        BEGIN
          SELECT nvl(val_parametro,5)
            INTO v_mot_ret_extracto
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'TA_SOLICITUDES'
             AND parametro = 'MOT_RET_EXTRACTO'
             AND referencia = p_nro_solicitud;
        EXCEPTION
          WHEN no_data_found THEN
            v_mot_ret_extracto := 5;
        END;
        BEGIN
          INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          VALUES
            (v_nro_cuenta, 'MOT_RET_EXTRACTO', v_mot_ret_extracto);
        EXCEPTION
          WHEN OTHERS THEN
            v_lugar     := 'ERR_INS_REAS_EXT';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al insertar parametro de motivo de ret. de extracto en ge_cta_dat_adicionales' ||
                           '.'||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            RAISE v_error;
        END;

        --llamamos al servicio para cambio de limite
        v_lugar     := '022';
        pr_act_lim_tar(v_nro_cuenta,
        v_cod_persona,
        v_nro_tarjeta,
        v_lin_credito,
        p_cod_error,p_men_error);--retorna 200 caso exitoso
        
        if p_cod_error<>200 then

            v_lugar     := 'ERR_SP_UPD_LIM';
            v_cod_error := p_cod_error;
            v_men_error := substr(v_lugar || '|No fue posible cambiarle el limite a la Cuenta Nro: '||v_nro_cuenta||
                             '.'||sqlerrm,1,4000);

            prg_ins_log_programas(v_nom_programa,'No fue posible cambiarle el limite a la Cuenta Nro: '||v_nro_cuenta||
                                  ' -Lugar: ' || v_lugar || '- ' || p_cod_error ||
                                  ' # '|| p_men_error);
          end if;
          --agregar validacion de exito y si falla mandar un correo de aviso
        else--si hubo error
            v_lugar     := 'ERR_UPD_GP_CARD_STATUS';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al cambiar a normal el estado de la tarjeta en GP. Procedure PAT_TGL.pr_act_tar_cre.' ||
                           sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            raise v_error;
        end if; --termina if v_cod_correcto

  -- no existe la cta en GP
else
      -- se debe crear de cero
      -- 1 creamos la cuenta_tarjeta
      begin
        select p.nro_documento
          into v_nro_documento
          from ba_personas p
         where p.cod_persona = p_cod_persona;
      exception
        when others then
          v_lugar     := 'ERR_PERSON_NOT_FOUND';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al recuperar datos del cliente ' || p_cod_persona || 
                         ' en BA_PERSONAS.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
      end;
      pr_cre_tar_vir_global(v_nro_documento, p_cod_error, p_men_error); --el servicio ya inserta en ta_Tar_global_tmp
      v_men_error:=p_men_error;
      if p_cod_error = 200 then
        --si fue exitoso
        begin
          select s.nom_embozado,
                 s.tip_embozado,
                 s.cod_modulo,
                 s.cod_modalidad,
                 s.cod_oficina,
                 s.fec_solicitud,
                 s.afinidad,
                 s.sub_afinidad,
                 s.cod_rub_economico,
                 s.monto,
                 s.deb_automatico,
                 s.nro_cta_debito,
                 s.tip_cobro,
                 s.cod_tip_cierre,
                 s.tip_envio,
                 s.referencia,
                 s.tip_plastico
            into v_nom_embozado,
                 v_tip_embozado,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_fec_solicitud,
                 v_afinidad,
                 v_sub_afinidad,
                 v_cod_rub_economico,
                 v_lin_credito,
                 v_deb_automatico,
                 v_nro_cta_debito,
                 v_tip_cobro,
                 v_cod_tip_cierre,
                 v_tip_envio,
                 v_referencia,
                 v_tip_plastico
            from ta_solicitudes s
           where s.nro_solicitud = p_nro_solicitud;
        exception
          when others then
          v_lugar     := 'GET_REQUEST-FAILED';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al recuperar datos de la solicitud ' || p_nro_solicitud || 
                         ' en TA_SOLICITUDES.' ||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        --no hay reemplazo para este caso
       /* begin
        select s.nro_cuenta,
               s.cod_persona,
               substr(s.nro_pan_pro_principal, 13, 16) nro_tarjeta
          into v_nro_cuenta, v_cod_persona, v_nro_tarjeta
          from ta_imp_dat_embozados s
         where s.cod_persona=p_cod_persona
           and estado like 'E';
      exception
        when others then
          v_lugar     := '014';
          v_cod_error := v_err_sql;
          v_men_error := substr('Error al recuperar datos!' ||
                         'Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
      end;*/

      begin
          select a.fec_vencimiento, cod_estado,a.nro_cuenta,a.cod_persona,a.nro_tarjeta
            into v_fec_vencimiento, v_cod_estado,v_nro_cuenta, v_cod_persona, v_nro_tarjeta
            from Ta_Tar_Global_Tmp a
           where a.cod_persona = p_cod_persona
             and nvl(cod_estado, '15') in ('0', '15');
        exception
        when no_data_found then
           begin
              select a.cod_estado
                into v_cod_estado
                FROM Ta_Tar_Global_Tmp a
               where a.cod_persona = p_cod_persona;

              v_lugar     := 'ERR_GET_TMP_CARD';
              v_cod_error := v_err_sql; 
              v_men_error := substr(v_lugar || '|No se encontró TC en estado 15. El cliente ' || p_cod_persona || ' posee una TC en estado: ' || v_cod_estado, 1, 4000);
              
              prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || ' # ' || v_men_error);
              RAISE v_error;
      
           exception
              when no_data_found then
                 v_lugar     := 'TMP_CARD_NOT_FOUND';
                 v_cod_error := v_err_sql;
                 v_men_error := substr(v_lugar || '|El cliente ' || p_cod_persona || ' no posee ninguna TC en TA_TAR_GLOBAL_TMP.', 1, 4000);
                 
                 prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || ' # ' || v_men_error);
                 RAISE v_error;
           END;
      
        when others then
           v_lugar     := 'ERR_TMP';
           v_cod_error := v_err_sql;
           v_men_error := substr(v_lugar || '|Error al consultar TC de cliente ' || p_cod_persona || '.' || SQLERRM, 1, 4000);
           
           prg_ins_log_programas(v_nom_programa, 'Lugar: ' || v_lugar || '- ' || v_cod_error || ' # ' || v_men_error);       
            raise v_error;
        end;

        begin
          select tip_cierre
            into v_tip_cierre
            from ta_tipos a
           where a.afinidad = v_afinidad
           and rownum=1;
        exception
          when others then
          v_lugar     := 'ERR_GET_CLOSE_CODE';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al recuperar tipo de cierre vinculado a la afinidad' || v_afinidad ||
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        begin
         SELECT c.fec_cierre, c.fec_vencimiento
          INTO v_fec_cierre, v_fec_vto_cierre
          FROM ta_cal_cierres c
         WHERE c.ano = to_char(v_fec_actual, 'YYYY')
           AND c.mes = to_char(v_fec_actual, 'MM')
           AND c.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
           AND c.cod_modalidad = 53;
         exception
            when others then
              v_fec_cierre:=null;
              v_fec_vto_cierre:=null;
          end;

        IF v_fec_cierre < v_fec_actual THEN
         begin
          SELECT c.fec_cierre, c.fec_vencimiento
          INTO v_fec_cierre, v_fec_vto_cierre
          FROM ta_cal_cierres c
         WHERE c.ano = to_char(add_months(v_fec_actual,1), 'YYYY')
           AND c.mes = to_char(add_months(v_fec_actual,1), 'MM')
           AND c.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
           AND c.cod_modalidad = 53;
          exception
            when others then
              v_fec_cierre:=null;
              v_fec_vto_cierre:=null;
          end;
        END IF;


        --  recuperar datos e ingresar a ta_cta_tarjetas
          begin
          insert into it.ta_cta_tarjetas
            (nro_cuenta,
             denominacion,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_moneda,
             lin_credito,
             lin_cuotas,
             sal_facturar,
             sal_facturado,
             sal_financiado,
             sal_ult_extracto,
             sal_cuo_pendientes,
             mto_pag_minimo,
             sal_pag_minimo,
             mto_mora,
             dia_mora,
             mto_autorizaciones,
             mto_int_compras,
             mto_pag_mes,
             mto_gas_mora,
             estado,
             est_administradora,
             fec_solicitud,
             fec_apertura,
             fec_ult_pago,
             fec_ult_compra,
             fec_ult_operacion,
             fec_ult_extracto,
             fec_ult_cierre,
             fec_vct_ult_cierre,
             tip_cierre,
             cob_gas_financiero,
             tip_tas_financiacion,
             tip_com_emision,
             tas_financiacion,
             tas_adelanto,
             tas_mora,
             tas_cuotas,
             deb_automatico,
             tip_cobro,
             nro_cta_debito,
             mto_min_pago,
             por_pag_minimo,
             cod_usu_promotor,
             mar_mora,
             mar_excedido,
             mar_recuperado,
             mar_bloqueo,
             con_costo,
             nro_solicitud,
             cod_causa,
             cod_canal,
             cod_campana,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             cat_automatica,
             fec_juicio,
             cod_ent_juicio,
             max_atraso,
             pro_atraso,
             nro_linea,
             en_juicio,
             cat_aut_anterior,
             fec_activacion,
             fec_cancelacion,
             tas_efectiva,
             mto_aut_cuotas,
             afinidad,
             sub_afinidad,
             sal_procesadora,
             cod_rub_economico,
             cod_tip_cierre,
             franqueo,
             ind_seg_vida,
             cod_exc_cargo,
             lin_especial,
             tas_especial,
             mto_car_suspendido,
             mto_car_sus_aplicado,
             tip_plastico)
          values
            (v_nro_cuenta,
             v_nom_embozado,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             'GS', --v_cod_moneda,
             v_lin_credito,
             0, --v_lin_cuotas,
             0, --v_sal_facturar,
             0, --v_sal_facturado,
             0, --v_sal_financiado,
             0, --v_sal_ult_extracto,
             0, --v_sal_cuo_pendientes,
             0, --v_mto_pag_minimo,
             0, --v_sal_pag_minimo,
             0, --v_mto_mora,
             0, --v_dia_mora,
             0, --v_mto_autorizaciones,
             0, --v_mto_int_compras,
             0, --v_mto_pag_mes,
             0, --v_mto_gas_mora,
             'N', --v_estado,
             null, --v_est_administradora,
             v_fec_solicitud,
             v_fec_actual, --v_fec_apertura,
             null, --v_fec_ult_pago,
             null, --v_fec_ult_compra,
             null, --v_fec_ult_operacion,
             null, --v_fec_ult_extracto,
             v_fec_cierre,--null, --v_fec_ult_cierre,
             v_fec_vto_cierre,--null, --v_fec_vct_ult_cierre,
             v_tip_cierre, --v_tip_cierre,--traer de ta_tipos
             null, --v_cob_gas_financiero,
             null, -- v_tip_tas_financiacion,
             0, --v_tip_com_emision,
             0, --v_tas_financiacion,
             0, --v_tas_adelanto,
             0, --v_tas_mora,
             0, --v_tas_cuotas,
             v_deb_automatico,
             v_tip_cobro,
             v_nro_cta_debito,
             null, --v_mto_min_pago,
             null, --v_por_pag_minimo,
             null, --v_cod_usu_promotor,
             null, --v_mar_mora,
             null, --v_mar_excedido,
             null, --v_mar_recuperado,
             null, --v_mar_bloqueo,
             null, --v_con_costo,
             p_nro_solicitud,
             null, --v_cod_causa,
             null, --v_cod_canal,
             null, --v_cod_campana,
             user,
             sysdate,
             user,
             sysdate,
             1, --v_cat_automatica,
             null, --v_fec_juicio,
             null, --v_cod_ent_juicio,
             null, --v_max_atraso,
             null, --v_pro_atraso,
             null, --v_nro_linea,
             null, --v_en_juicio,
             null, --v_cat_aut_anterior,
             v_fec_actual, --v_fec_activacion,
             null, --v_fec_cancelacion,
             null, --v_tas_efectiva,
             null, --v_mto_aut_cuotas,
             v_afinidad,
             v_sub_afinidad,
             null, --v_sal_procesadora,
             v_cod_rub_economico,
             v_cod_tip_cierre,
             null, --v_franqueo,
             null, --v_ind_seg_vida,
             null, --v_cod_exc_cargo,
             0, --v_lin_especial,
             0, --v_tas_especial,
             0, --v_mto_car_suspendido,
             0, --v_mto_car_sus_aplicado
             v_tip_plastico);

        exception
          when others then
          v_lugar     := 'ERR_INS_ACCOUNT';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar en ta_cta_tarjetas. Cuenta Nro ' || v_nro_cuenta ||  '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        begin
          insert into it.ta_tarjetas
            (nro_cuenta,
             nro_tarjeta,
             cod_persona,
             cod_estado,
             fec_vencimiento,
             cod_causa,
             nom_embozar,
             nom_enviar,
             vigente,
             fec_emision,
             fec_solicitud,
             tip_envio,
             referencia,
             nro_planilla,
             tip_planilla,
             nro_pla_anterior,
             fec_entrega,
             fec_activacion,
             observacion,
             pre_embozada,
             rel_tarjeta,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             motivo,
             tip_embozado,
             id_producto)
          values
            (v_nro_cuenta,
             v_nro_tarjeta,
             v_cod_persona,
             '6',
             v_fec_vencimiento,
             null,
             v_nom_embozado, --ver
             null,
             'S', --v_vigente ver que poner
             sysdate,
             v_fec_solicitud,--v_fec_solicitud,
             v_tip_envio,
             v_referencia,
             null, --v_nro_planilla,
             null, --v_tip_planilla,
             null, --v_nro_pla_anterior,
             null, --v_fec_entrega,
             v_fec_actual, --v_fec_activacion,
             null, --v_observacion,
             null, --v_pre_embozada,
             '0',
             user,
             sysdate,
             user,
             sysdate,
             null, --v_motivo,
             'MV',
       '38');--Virtual ya que en este punto no hubo reemplazo

        exception
          when others then
          v_lugar     := 'ERR_INS_CARD';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar en ta_tarjetas. Cuenta Nro ' || v_nro_cuenta ||   '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;
        begin
          insert into it.ge_cta_clientes
            (cod_persona,
             nro_cuenta,
             dig_verificador,
             cod_oficina,
             cod_modulo,
             cod_modalidad,
             relacion,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             est_relacion)
          values
            (v_cod_persona,
             v_nro_cuenta,
             0,
             v_cod_oficina,
             v_cod_modulo,
             v_cod_modalidad,
             'P',
             user,
             sysdate,
             user,
             sysdate,
             'A');

        exception
          when others then
          v_lugar     := 'ERR_INS_REL_CTA_CLI';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar registro en ge_cta_clientes. Cod_persona: ' || v_cod_persona || '. Nro Cuenta: ' || v_nro_cuenta ||
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;

        FOR c IN c_garantias LOOP
          BEGIN
            INSERT INTO ta_cta_garantias
              (nro_cuenta,
               nro_garantia,
               cod_garantia,
               mto_aplicado,
               mto_apl_computable)
            VALUES
              (v_nro_cuenta,
               c.nro_garantia,
               c.cod_garantia,
               c.mto_aplicado,
               0);
            EXCEPTION
              WHEN OTHERS THEN
                v_lugar     := 'ERR_INS_WAR_REQ';
                v_cod_error := v_err_sql;
                v_men_error := substr(v_lugar || '|Error al insertar garantia de la solicitud. Cuenta Nro ' || v_nro_cuenta ||  '.'||sqlerrm,1,4000);
                                      prg_ins_log_programas(v_nom_programa,
                                      'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                      ' # '|| v_men_error);
                RAISE v_error;
           END;
         END LOOP;

        begin
          insert into it.ge_cta_dat_adicionales
          (nro_cuenta,
           parametro,
           val_parametro,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion)
        values
          (v_nro_cuenta,
           'COD_PRO_TDC_GLOBAL',
           '38',
           user,
           sysdate,
           user,
           sysdate);
        exception
          when others then
          v_lugar     := 'ERR_INS_PROD_ACCOUNT';
          v_cod_error := v_err_sql;
          v_men_error := substr(v_lugar || '|Error al insertar parámetro COD_PRO_TDC_GLOBAL en ge_cta_dat_adicionales!' ||
                         '.'||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
        end;

        BEGIN
          SELECT nvl(val_parametro,'N')
            INTO v_ret_extracto
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'TA_SOLICITUDES'
             AND parametro    = 'RET_EXTRACTO'
             AND referencia   = p_nro_solicitud;
        EXCEPTION
          WHEN no_data_found THEN
            v_ret_extracto := 'N';
        END;

        BEGIN
          INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          VALUES
            (v_nro_cuenta,
             'RET_EXTRACTO',
             v_ret_extracto);
        EXCEPTION
          WHEN OTHERS THEN
            v_lugar     := 'ERR_INS_EXTRACT';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al insertar parametro de retencion de extracto en ge_cta_dat_adicionales ' ||
                           '.'||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            RAISE v_error;
        END;

        BEGIN
          SELECT nvl(val_parametro,5)
            INTO v_mot_ret_extracto
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'TA_SOLICITUDES'
             AND parametro = 'MOT_RET_EXTRACTO'
             AND referencia = p_nro_solicitud;
        EXCEPTION
          WHEN no_data_found THEN
            v_mot_ret_extracto := 5;
        END;
        BEGIN
          INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          VALUES
            (v_nro_cuenta, 'MOT_RET_EXTRACTO', v_mot_ret_extracto);
        EXCEPTION
          WHEN OTHERS THEN
            v_lugar     := 'ERR_INS_REAS_EXT';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '|Error al insertar parametro de motivo de ret. de extracto en ge_cta_dat_adicionales' ||
                           '.'||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
            RAISE v_error;
        END;

        v_lugar     := '023';
        --llamamos al servicio para cambio de limite

        begin
            SYS.DBMS_LOCK.SLEEP(0.7);

            pr_act_lim_tar(v_nro_cuenta,
                v_cod_persona,
                v_nro_tarjeta,
                v_lin_credito,
                p_cod_error,p_men_error);

        exception
            when others then
            v_lugar     := 'ERR_SP_UPD_LIM';
            v_cod_error := v_err_sql;
            v_men_error := substr(v_lugar || '| No fue posible cambiarle el liminte a la Cuenta Nro: '||v_nro_cuenta||
                           '.' ||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                  ' # '|| v_men_error);
        end;
        --agregar validacion de exito y si falla mandar un correo de aviso
        if p_cod_error<>200 then
          prg_ins_log_programas(v_nom_programa,'Cuenta Nro: '||v_nro_cuenta||
                                ' -Lugar: ' || v_lugar || '- ' || p_cod_error ||
                                ' # '|| p_men_error);
        end if;
      else--si no se ejecuto correctamente el servicio
          v_lugar     := 'ERR_UPD_GP_CARD_STATUS';
          v_cod_error := v_err_sql;
          v_men_error := substr( v_lugar|| '| ' || v_men_error || ' - Error al ejecutar el alta de tarjeta - Procedure PAT_TGL.pr_cre_tar_vir_global.' 
                         ||sqlerrm,1,4000);
          prg_ins_log_programas(v_nom_programa,
                                'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                                ' # '|| v_men_error);
          raise v_error;
      end if;

      --prg_ins_log_programas(v_cod_programa,'no posee registro de tarjeta activa');
    end if;
    p_cod_error := v_cod_error;
    p_men_error := v_men_error;
    commit;
  EXCEPTION
  
    WHEN v_error THEN
        p_cod_error := v_cod_error;
        p_men_error := v_men_error;
    WHEN OTHERS THEN
          v_lugar     := 'ERR_GEN'; 
          v_cod_error := v_err_sql;
    
          v_men_error := substr(v_lugar || '|Error al ejecutar la aprobación de la solicitud. ' || sqlerrm, 1, 4000);
          
          p_cod_error :=v_cod_error;
          p_men_error := v_men_error;
          
          prg_ins_log_programas(v_nom_programa,'Lugar: ' || v_lugar || 'Nro_cuenta - '||v_nro_cuenta||' .Cod_persona: '||
          v_cod_persona||' Error: '|| v_cod_error ||
                                ' # '|| v_men_error);
  end;
  /**
   * Procedimiento para remplazo de tarjetas (debito/credito).
  **/
  procedure pr_tar_reemplazo(p_nro_cuenta      in ah_tar_debitos.nro_cta_global%type, --cta glp
                             p_cod_persona     in ah_tar_debitos.cod_persona%type,
                             p_nro_tarjeta     in ta_tar_global_tmp.nro_tarjeta%type,
                             p_fec_vencimiento in ah_tar_debitos.fec_vencimiento%type,
                             p_nro_sobre       in varchar2,
                             p_principal       in varchar2, ---si es TC o TD
                             p_tip_tarjeta     in ta_tar_global_tmp.tip_tarjeta%type, --fisica/virtual
                             p_cod_error       out number,
                             p_men_error       out varchar2) is

    v_cod_error       varchar2(6) := v_pro_correcto;
    v_men_error       varchar2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                                            'Transaccion Exitosa!');
    v_cod_programa    varchar2(30) := 'PAT_TGL.PR_TAR_REEMPLAZO';
    v_id_producto     ah_tar_debitos.id_producto%type;
    v_nro_tarjeta     ah_tar_debitos.nro_tarjeta%type;
    v_nro_tarjeta_cre ah_tar_debitos.nro_tarjeta%type;
    v_nro_bin         ah_tar_debitos.nro_bin%type;
    v_nro_cta         ah_tar_debitos.nro_cuenta%type;
    v_nom_programa    varchar2(100) := 'PAT_TGL.PR_TAR_REEMPLAZO';
    v_lugar           varchar2(3) := '000';
    v_existe_tc       varchar(2) := 'N';
    v_existe_tc_can       varchar(2) := 'N';--para validar que la ultima tarjeta sea cancelada
    v_existe_tc_blo       varchar(2) := 'N';--para validar tarjetas con estado distinto a normal
    v_estado_tc       varchar(2) := 'N';--para validar estado tarjetas
    v_fec_vencimiento        ta_tarjetas.fec_vencimiento%type;
    ---------
    v_nro_tarjeta_ant            ta_Tarjetas.Nro_Tarjeta%type;
    v_fec_vencimiento_ant        ta_tarjetas.fec_vencimiento%type;
    v_nom_embozado               ta_tarjetas.nom_embozar%type;
    ---------
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;

if p_principal = 'S' then

      --recuperamos tipo de producto
        begin
            select val_parametro
            into v_id_producto
            from ge_cta_dat_adicionales s
            where parametro='COD_PRO_TDC_GLOBAL'
            and nro_cuenta=p_nro_cuenta;
            exception
              when no_data_found then
                begin
                 select cod_producto
                 into v_id_producto
                 from ta_tar_global_tmp
                 where nro_cuenta=p_nro_cuenta
                 and cod_persona= p_cod_persona;
                 exception
                   when others then
                              prg_ins_log_programas(v_nom_programa,
                              'No se encontro tipo de producto asignado para el nro de cuenta en la tmp.'
                              ,p_cod_persona,p_nro_cuenta);
                   end;
              when others then
                              prg_ins_log_programas(v_nom_programa,
                              'No se encontro tipo de producto asignado para el nro de cuenta.'
                              ,p_cod_persona,p_nro_cuenta);
          end;

      -- tarjetas de credito
      v_lugar := '001';
      update ta_imp_dat_embozados a
         set a.cod_persona = p_cod_persona,
             a.nro_cuenta  = p_nro_cuenta, --cta glp
             a.estado      = 'E' --Se actualiza el estado  E (Entregado)
       where a.nro_sob_pro_principal = p_nro_sobre;
      if sql%notfound then
        v_lugar     := '002';
        v_cod_error := v_err_sql;
        v_men_error := 'No se encuentra el registro para actualizar';
        prg_ins_log_programas(v_nom_programa,
                              v_lugar || '- ' || v_cod_error || ' # ' ||
                              v_men_error);

      else
        --se actualiza el nro tarjeta en tabla auxiliar
        begin --obs:para de virtual a fisica esto estaba en un principio
          --recupera nro de tarjeta asociada al nro del sobre
          select substr(nro_pan_pro_principal, 13, 16)
            into v_nro_tarjeta_cre
            from ta_imp_dat_embozados s
           where s.nro_sob_pro_principal = p_nro_sobre;
        exception
          when others then
            v_lugar     := '003';
            v_cod_error := v_err_sql;
            v_men_error := 'No se encuentra el nro sobre';
            prg_ins_log_programas(v_nom_programa,
                                  v_lugar || '- ' || v_cod_error || ' # ' ||
                                  v_men_error);

        end;
        --validar si ya existe en ta_tarjetas para poner en cod estado 15 o dejar en 0
        begin
          select 'S'
            into v_existe_tc
            from ta_tarjetas a
           where a.cod_estado='6'
             and it.fut_obt_procesadora(a.nro_cuenta) =
                 it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
             and a.cod_persona = p_cod_persona;
        exception
          when no_data_found then
            v_existe_tc := 'N';
          when others then
            v_existe_tc := 'N';
            prg_ins_log_programas(v_nom_programa,
                                  'Error!No se encontro TC para la persona/cuenta '||p_cod_persona||'/'||p_nro_cuenta || ' - ' || ' # ' ||
                                  sqlerrm);
        end;
        if v_existe_tc = 'S' then
            --aca poner baja de ta_Actual e alta de la nueva
            begin
            update ta_tar_global_tmp s
               set nro_tarjeta = v_nro_tarjeta_cre,
                   tip_tarjeta = 0,
                   cod_estado  = 0
             where cod_persona = p_cod_persona
               and s.nro_cuenta = p_nro_cuenta;
          exception
            when others then
              p_cod_error := 5;
              p_men_error := '5-Error: ' || sqlerrm;
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    null,
                                    null);
          end;
          begin
            select a.nro_tarjeta,a.fec_vencimiento,a.nom_embozar
            into v_nro_tarjeta_ant,v_fec_vencimiento_ant,v_nom_embozado
            from it.ta_tarjetas a
            where a.nro_cuenta=p_nro_cuenta
            and a.vigente='S'
            and a.cod_estado='6';
          exception
          when others then
              p_cod_error := 56;
              p_men_error := '56-Error: ' || sqlerrm;
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    null,
                                    null);
          end;
          --se da de baja nro de tarjeta anterior
          pr_act_est_tar_cre(p_nro_cuenta,v_nro_tarjeta_ant,1,p_cod_error,p_men_error);
          COMMIT;
          if v_cod_error != v_pro_correcto then
          prg_ins_log_programas(v_nom_programa,
                            'Procedimiento: pr_act_est_tar_cre '|| '- ' || v_cod_error ||
                            ' # ' || v_men_error);
          end if;
          --se da de alta el nuevo registro con nuevo nro de tarjeta
          pr_alt_tar_cre(p_nro_cuenta,v_nro_tarjeta_cre,p_cod_persona,v_fec_vencimiento_ant,v_nom_embozado,v_id_producto,p_cod_error,p_men_error);
          if v_cod_error != v_pro_correcto then
          prg_ins_log_programas(v_nom_programa,
                            'Procedimiento: pr_alt_tar_cre '|| '- ' || v_cod_error ||
                            ' # ' || v_men_error);
          end if;
   else--ta_tar_global_tmp se actualiza al final del bloque segun el caso que se haya dado
         v_estado_tc:='6';--se inicializa con estado 6 porque posee tarjeta con linea

        --alta del registro que tiene cancelacion ,se pone con estado 14 bloqueo usuario(no habilitado en GP)
          begin
          select 'S',a.nom_embozar,a.fec_vencimiento
            into v_existe_tc_can,v_nom_embozado,v_fec_vencimiento
            from ta_tarjetas a
           where a.cod_persona = p_cod_persona
             and a.nro_cuenta = p_nro_cuenta
             --and cod_causa in ('148', '72')
             and it.fut_obt_procesadora(a.nro_cuenta) =
                 it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
             and a.cod_estado <> '6' --que no sea normal
             and a.vigente='N'
             and a.fec_emision =
                 (select max(a.fec_emision)
                    from ta_tarjetas a
                   where a.cod_persona = p_cod_persona
                     and a.nro_cuenta = p_nro_cuenta);
        exception
          when no_data_found then
            v_existe_tc_can := 'N';
          when others then
            v_existe_tc_can := 'N';
            prg_ins_log_programas(v_nom_programa,
                                  'Error!No se encontro TC para la persona/cuenta '||p_cod_persona||'/'||p_nro_cuenta || ' - ' || ' # ' ||
                                  sqlerrm);
        end;
          if v_existe_tc_can='S' then

                begin
                  insert into it.ta_tarjetas
                    (nro_cuenta,
                     nro_tarjeta,
                     cod_persona,
                     cod_estado,
                     fec_vencimiento,
                     cod_causa,
                     nom_embozar,
                     nom_enviar,
                     vigente,
                     fec_emision,
                     fec_solicitud,
                     tip_envio,
                     referencia,
                     nro_planilla,
                     tip_planilla,
                     nro_pla_anterior,
                     fec_entrega,
                     fec_activacion,
                     observacion,
                     pre_embozada,
                     rel_tarjeta,
                     usu_insercion,
                     fec_insercion,
                     usu_modificacion,
                     fec_modificacion,
                     motivo,
                     tip_embozado,
                     id_producto)
                  values
                    (p_nro_cuenta,
                     v_nro_tarjeta_cre,
                     p_cod_persona,
                     v_estado_tc,
                     v_fec_vencimiento,
                     null,
                     v_nom_embozado,
                     '',
                     'S',
                     sysdate,
                     sysdate,
                     '',
                     '',
                     '',
                     '',
                     '',
                     sysdate,
                     sysdate,
                     '',
                     '',
                     0,
                     user,
                     sysdate,
                     user,
                     sysdate,
                     '',
                     'MF',
                     v_id_producto);
                  commit;
                exception
                  when others then
                    prg_ins_log_programas(v_nom_programa,
                            'Error al insertar Ta_tarjetas,Cancelado a no Habilitado '|| '- ' ||p_nro_cuenta||
                            ' # ' || sqlerrm);
                end;

          end if;
        ----------termina de cancelado a fisica en estado no habilitado

        ----------inicia cualquier estado de GP y  vigencia S a reemplazo normal a fisica
         begin
          select 'S',a.nom_embozar,a.fec_vencimiento,a.nro_tarjeta
            into v_existe_tc_blo,v_nom_embozado,v_fec_vencimiento,v_nro_tarjeta_ant
            from ta_tarjetas a
           where a.cod_persona = p_cod_persona
             and a.nro_cuenta = p_nro_cuenta
             and it.fut_obt_procesadora(a.nro_cuenta)=it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
             and a.cod_estado not in ('6')
             and a.vigente='S'
             and a.fec_emision =
                 (select max(a.fec_emision)
                  from ta_tarjetas a
                  where a.cod_persona = p_cod_persona
                  and a.nro_cuenta = p_nro_cuenta);
        exception
          when no_data_found then
            v_existe_tc_blo := 'N';
          when others then
            v_existe_tc_blo := 'N';
            prg_ins_log_programas(v_nom_programa,
                                  'Error!No se encontro TC para la persona/cuenta '||p_cod_persona||'/'||p_nro_cuenta || ' - ' || ' # ' ||
                                  sqlerrm);
        end;
          if v_existe_tc_blo='S' then
                begin
                --se da de baja nro de tarjeta anterior
                 pr_act_est_tar_cre(p_nro_cuenta,v_nro_tarjeta_ant,1,p_cod_error,p_men_error);
                  --se da de alta nuevo registro
                  insert into it.ta_tarjetas
                    (nro_cuenta,
                     nro_tarjeta,
                     cod_persona,
                     cod_estado,
                     fec_vencimiento,
                     cod_causa,
                     nom_embozar,
                     nom_enviar,
                     vigente,
                     fec_emision,
                     fec_solicitud,
                     tip_envio,
                     referencia,
                     nro_planilla,
                     tip_planilla,
                     nro_pla_anterior,
                     fec_entrega,
                     fec_activacion,
                     observacion,
                     pre_embozada,
                     rel_tarjeta,
                     usu_insercion,
                     fec_insercion,
                     usu_modificacion,
                     fec_modificacion,
                     motivo,
                     tip_embozado,
                     id_producto)
                  values
                    (p_nro_cuenta,
                     v_nro_tarjeta_cre,
                     p_cod_persona,
                     v_estado_tc,
                     v_fec_vencimiento,
                     '',
                     v_nom_embozado,
                     '',
                     'S',
                     sysdate,
                     sysdate,
                     '',
                     '',
                     '',
                     '',
                     '',
                     sysdate,
                     sysdate,
                     '',
                     '',
                     0,
                     user,
                     sysdate,
                     user,
                     sysdate,
                     '',
                     'MF',
                     v_id_producto);
                  commit;
                exception
                  when others then
                    prg_ins_log_programas(v_nom_programa,
                            'Error al insertar Ta_tarjetas,Cancelado a no Habilitado '|| '- ' ||p_nro_cuenta||
                            ' # ' || sqlerrm);
                end;

          end if;
        ----------termina de bloqueado con estado S a reemplazo normal a fisica

        --persistimos ta_tar_global_tmp segun el caso que se haya dado
          begin
            update ta_tar_global_tmp s
               set nro_tarjeta = v_nro_tarjeta_cre,
                   tip_tarjeta = 0,
                   cod_estado  = 0--estado normal ver reunion xxx
             where cod_persona = p_cod_persona
               and s.nro_cuenta = p_nro_cuenta;
          exception
            when others then
              p_cod_error := 6;
              p_men_error := '6-Error: ' || sqlerrm;
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    null,
                                    null);
          end;
        ---termina persistencia de ta_Tar_global_tmp-------------------
        end if;
        ---------------
        ---
        /* delete ta_tar_global_tmp a
        where a.nro_cuenta = p_nro_cuenta
          and a.cod_persona = p_cod_persona
          and a.nro_tarjeta = p_nro_sobre;*/
        --Se comenta esta seccion del Delete ya que actualmente los
        -- datos de tarjetas solo se consumen de la tabla mencionada
        --y de esta manera evitar perder datos.
      end if;

else--DEBITO
      -- tarjetas de debito
      v_lugar := '100';
      ------se igualan cod_persona y nro_cuenta para vinculacion a ta_imp_dat_embozados
      update ta_imp_dat_embozados a
         set a.cod_persona        = p_cod_persona,
             a.nro_cta_deb_global = p_nro_cuenta
       where a.nro_sob_pro_secundario = p_nro_sobre;
      -------
      v_lugar := '101';
      -- obtiene el nro de bin de referencia
          begin
            select val_minimo
              into v_nro_bin
              from it.ta_imp_dat_embozados s
              left join (select val_minimo
                         from ba_cod_referencias s
                         where dominio = 'NRO_BIN_TAR_GP'
                         and activo = 'S') z
                on (instr(s.nro_pan_pro_secundario, z.val_minimo) > 0
                   )
              where nro_sob_pro_principal = p_nro_sobre;
          exception
            when others then
              v_nro_bin := 0;
          end;

      v_lugar := '102';
      -- obtiene el nro de tarjeta, id_producto
      begin
        select a.nro_tarjeta,
               a.id_producto,
               decode(v_nro_bin, 0, a.nro_bin, v_nro_bin),
               a.nro_cuenta
          into v_nro_tarjeta, v_id_producto, v_nro_bin, v_nro_cta
          from ah_tar_debitos a
         where a.nro_cta_global = p_nro_cuenta -- cta glp
           and to_number(a.nro_emision) =
               (select max(to_number(b.nro_emision))
                  from ah_tar_debitos b
                 where b.nro_cuenta = a.nro_cuenta);
      exception
        when others then
          v_cod_error := v_err_sql;
          v_men_error := substr(sqlerrm, 1, 4000);
      end;
      v_lugar := '103';
      if v_cod_error = v_pro_correcto then
        -- baja de la td actual
        v_lugar := '104';
        pr_act_est_tarjeta(v_nro_cta,
                           v_nro_tarjeta,
                           'Baja',
                           v_cod_error,
                           v_men_error);

        if v_cod_error = v_pro_correcto then
          v_lugar := '105';
          --alta de nueva emision
          pr_alt_tar_debpre(p_nro_cuenta,
                            v_id_producto,
                            v_nro_cta,
                            v_nro_bin,
                            p_nro_tarjeta,
                            p_fec_vencimiento,
                            p_tip_tarjeta, --fisica
                            v_cod_error,
                            v_men_error);
        end if;
      end if;
    end if;

    if v_cod_error != v_pro_correcto then
      prg_ins_log_programas(v_nom_programa,
                            'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                            ' # ' || v_men_error);
    end if;
    p_cod_error := v_cod_error;
    p_men_error := v_men_error;
    commit;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := v_men_error;
      prg_ins_log_programas(v_nom_programa,
                            'Lugar: ' || v_lugar || '- ' || v_cod_error || '. ' ||
                            v_men_error);
  end;

  /*
  ** Procedimiento que realiza las operaciones abm de estado p/ viajes al exterior
  */
  procedure pr_tar_avi_exterior(p_cod_viaje       in ta_avi_via_exterior.cod_viaje%type,
                                p_tip_adicional   in ta_avi_via_exterior.tip_adicional%type default null,
                                p_nro_cuenta      in ta_avi_via_exterior.nro_cuenta%type default null,
                                p_fec_vig_inicial in ta_avi_via_exterior.fec_vig_inicial%type default null,
                                p_fec_vig_final   in ta_avi_via_exterior.fec_vig_final%type default null,
                                p_nro_tarjeta     in ta_avi_via_exterior.nro_tarjeta%type default null,
                                p_lis_cod_pais    in ta_avi_via_exterior.lis_cod_pais%type default null,
                                p_accion          in varchar2,
                                p_cod_error       out number,
                                p_men_error       out varchar2) is

    v_cod_error    number;
    v_men_error    varchar2(4000);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_TAR_AVI_EXTERIOR';
    v_lugar        varchar2(10);
    v_estado       varchar2(2);
    v_men_err_sql  varchar2(4000);

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;

    v_estado := 'A';
    v_lugar  := '01';
    case
      when upper(p_accion) = 'INS' then
        begin
          --Insertamos el nuevo id de viaje recibido.
          insert into ta_avi_via_exterior
            (cod_viaje,
             tip_adicional,
             nro_cuenta,
             fec_vig_inicial,
             fec_vig_final,
             nro_tarjeta,
             lis_cod_pais,
             estado)
          values
            (p_cod_viaje,
             p_tip_adicional,
             p_nro_cuenta,
             p_fec_vig_inicial,
             p_fec_vig_final,
             p_nro_tarjeta,
             p_lis_cod_pais,
             v_estado);

          v_cod_error := 0;
          v_men_error := 'operacion exitosa';
          commit;
        exception
          when others then
            v_lugar     := '02';
            v_cod_error := 999;
            v_men_error := 'El registro ya existe: ' || 'Cod.Viaje: ' ||
                           p_cod_viaje;
            prg_ins_log_programas(v_nom_programa,
                                  substr('Error Insert TA_AVI_VIA_EXTERIOR: ' ||
                                         'Lugar: ' || v_lugar ||
                                         ' Cod.Viaje: ' || p_cod_viaje || '  ' ||
                                         sqlerrm,
                                         1,
                                         4000),
                                  null,
                                  p_nro_cuenta);

        end;

      when upper(p_accion) in ('UPD', 'DEL') then
        begin
          if upper(p_accion) = 'UPD' then
            --Actualizamos los datos
            update ta_avi_via_exterior
               set tip_adicional   = p_tip_adicional,
                   nro_cuenta      = p_nro_cuenta,
                   fec_vig_inicial = p_fec_vig_inicial,
                   fec_vig_final   = p_fec_vig_final,
                   nro_tarjeta     = p_nro_tarjeta,
                   lis_cod_pais    = p_lis_cod_pais,
                   estado          = v_estado
             where cod_viaje = p_cod_viaje;

          else
            -- seteo el estado en caso de no existir registro a actualizar.
            v_estado := 'I';
            update ta_avi_via_exterior
               set estado = 'I'
             where cod_viaje = p_cod_viaje;
          end if;

          v_cod_error := 0;
          v_men_error := 'operacion exitosa';

          IF SQL%NOTFOUND then
            --Seteo como activo al nuevo registro.
            v_estado := 'A';
            if upper(p_accion) = 'DEL' then
              --Insertamos el nuevo id de viaje recibido.
              insert into ta_avi_via_exterior
                (cod_viaje,
                 tip_adicional,
                 nro_cuenta,
                 fec_vig_inicial,
                 fec_vig_final,
                 nro_tarjeta,
                 lis_cod_pais,
                 estado)
              values
                (p_cod_viaje,
                 p_tip_adicional,
                 p_nro_cuenta,
                 p_fec_vig_inicial,
                 p_fec_vig_final,
                 p_nro_tarjeta,
                 p_lis_cod_pais,
                 v_estado);

              v_cod_error := 0;
              v_men_error := 'operacion exitosa';

            else
              v_lugar     := '03';
              v_cod_error := 999;
              v_men_error := 'Sin registros para actualizar';
            end if;
          end if;

          commit;

        exception
          when others then
            v_lugar       := '04';
            v_men_err_sql := substr('Error al realizar update/del TA_AVI_VIA_EXTERIOR: ' ||
                                    'Lugar: ' || v_lugar || ' ' ||
                                    'Cod.Viaje: ' || p_cod_viaje || ' ' ||
                                    sqlerrm,
                                    1,
                                    4000);
            prg_ins_log_programas(v_nom_programa,
                                  v_men_err_sql,
                                  null,
                                  p_nro_cuenta);
        end;

      else
        v_lugar     := '05';
        v_cod_error := 999;
        v_men_error := 'opcion invalida';
        prg_ins_log_programas(v_nom_programa,
                              (v_men_error || ' - ' || 'Lugar: ' || v_lugar ||
                              'Error: ' || ' - ' || v_cod_error),
                              null,
                              p_nro_cuenta);
    end case;

    -- Retornamos el mensaje de la operacion realizada.
    p_cod_error := v_cod_error;
    p_men_error := v_men_error;

  exception
    when others then
      v_lugar     := '06';
      p_cod_error := SQLCODE;
      p_men_error := 'Error en proceso PAT_TGL.PR_TAR_AVI_EXTERIOR. ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            null,
                            p_nro_cuenta);
  end;
  -- Baja de cuenta de ta_tarjetas y ta_tar_global_tmp --
procedure pr_baj_tar_tmp(p_cod_persona   in ta_tarjetas.cod_persona%TYPE) IS
  v_nom_programa varchar2(40):='PAT_TGL.PR_BAJ_TAR_TMP';
  pragma autonomous_transaction;
begin
    begin
        delete ta_tar_global_tmp a
        where a.cod_persona=p_cod_persona
        and exists(select 1 from ta_cta_tarjetas s
        where s.nro_cuenta=a.nro_cuenta
        and s.estado='C');
        if SQL%ROWCOUNT>0 then
          commit;
         end if;
    exception
    when others then
      prg_ins_log_programas(v_nom_programa,
                                  substr('Error al eliminar cuentas canceladas de tmp,cp ' || p_cod_persona ,
                                         1,
                                         4000));
    end;

     begin
        update ta_tarjetas a
        set vigente='N',cod_estado='10'
        where a.cod_persona=p_cod_persona
        and vigente='S'
        and cod_estado<>'10'
        and tip_embozado is not null
        and exists (select 1 from ta_cta_tarjetas s
        where s.nro_cuenta=a.nro_cuenta
        and s.estado='C');
        if SQL%ROWCOUNT>0 then
          commit;
         end if;
    exception
    when others then
      prg_ins_log_programas(v_nom_programa,
                                  substr('Error al actualizar cuentas canceladas ,nro. de cedula ' || p_cod_persona,
                                         1,
                                         4000));
    end;

end;

  -- creacion de una cuenta de tarjeta en global clasica credito --
procedure pr_cre_tar_vir_global(p_nro_doc   in ba_personas.nro_documento%TYPE,
                                  p_cod_error out number,
                                  p_men_error out varchar2) IS

    v_url_deb           varchar2(4000) := fug_obt_pardinamico('WS_ALT_TARJETA_CRE');
    v_url               varchar2(4000);
    v_content           varchar2(4000);
    v_lugar             varchar2(10);
    v_nom_programa      varchar2(50) := 'PAT_TGL.PR_CRE_TAR_VIR_GLOBAL';
    v_cod_modalidad     ah_cta_vistas.cod_modalidad%type;
    v_cod_sub_modalidad ah_cta_vistas.cod_sub_modalidad%TYPE;
    v_cod_modulo        ah_cta_vistas.cod_modulo%type;
    v_contrato          varchar2(1) := 'N';
    v_nro_cuenta        ah_cta_vistas.nro_cuenta%type;
    v_exi_can_tc varchar2(1):='N';
    v_exi_can_tmp varchar2(1):='N';
    v_exi_tc            number := 0;
    v_con_unico         varchar2(1) := fug_obt_pardinamico('IND_ENC_CONUNICO');
    v_direccion         ba_direcciones.direccion%TYPE;
    v_numero            ba_direcciones.numero%TYPE;
    v_piso              ba_direcciones.piso%TYPE;
    v_departamento      ba_direcciones.departamento%TYPE;
    v_cod_postal        ba_direcciones.cod_postal%TYPE;
    v_barrio            ba_barrios.descripcion%TYPE;
    v_tel_particular    ba_telefonos.telefono%TYPE;
    v_tel_celular       ba_telefonos.telefono%TYPE;
    v_email             ba_personas.dir_correo%TYPE;
    v_ciudad            ba_ciudades.descripcion%TYPE := fue_obt_des_ciudad (1,1);
    v_pais              ba_paises.descripcion%TYPE := 600;
    v_provincia         NUMBER := 1;
    v_cod_moneda        ah_cta_vistas.cod_moneda%type;

    ---
    cursor c_cli is
      select fug_eli_car_invalidos(f.pri_nombre) /*|| ' ' ||                                                                                                                                                                                                                                                                                                                                                                       fug_eli_car_invalidos(f.seg_nombre) */ nombre,
             fug_eli_car_invalidos(f.pri_apellido) /*|| ' ' ||                                                                                                                                                                                                                                                                                                                                                                      fug_eli_car_invalidos(f.seg_apellido)*/ apellido,
             p.nro_documento,
             f.cod_sexo,
             to_char(f.fec_nacimiento, 'yyyy-mm-dd') fec_nacimiento,
             p.cod_persona,
             fue_obt_des_refcodes('TIP_DOCUMENTO_GP', p.cod_tip_documento) tip_documento
        from ba_per_fisicas f, ba_personas p
       where p.nro_documento = p_nro_doc
         and p.cod_persona = f.cod_persona;

    v_men_error  varchar2(4000);
    v_cod_err_ws varchar2(10);
    v_error exception;
    v_entro        varchar2(1);
    v_cod_producto varchar2(10);
    -----------
    v_cod_persona varchar2(10);

    v_existe_tc varchar2(1):='N';
    v_existe_ta varchar2(1):='N';

    pragma autonomous_transaction;

begin
    v_lugar     := '01';
    p_cod_error := v_cod_msg_exito;
    p_men_error := 'Operacion Exitosa';
    v_entro     := 'N';
   ----
   Begin pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;
   pae_cnf.g_programa := 'GPPROFIN';
   end;

   begin
        select cod_persona
        into v_cod_persona
        from ba_personas s
        where s.nro_documento=p_nro_doc;
        --and s.est_verificacion like 'V';
    exception
          when others then
            v_cod_persona:=null;
    end;


    if v_cod_persona is not null then
      begin
        update ta_imp_dat_embozados s
        set s.estado='C'
        where s.cod_persona=v_cod_persona;
        commit;
       exception
        when others then
          prg_ins_log_programas(v_nom_programa,
                                      substr('Error al actualizar embozados,nro. de cedula ' || p_nro_doc || ' - ' ||
                                             p_men_error,
                                             1,
                                             4000));
      end;

      --Eliminamos cuentas canceladas de tabla de reservas y actualizamos ta_tarjetas a vigente N
      begin
        begin
              select distinct 'S'
              into v_exi_can_tc
              from ta_cta_tarjetas ta,ta_tarjetas t
              where t.nro_cuenta=ta.nro_cuenta
              and t.cod_persona=v_cod_persona
              and t.vigente='S'
              and estado='C';
          exception
            when others then
              v_exi_can_tc:='N';
           end;

           begin
              select distinct 'S'
              into v_exi_can_tmp
              from ta_cta_tarjetas ta,ta_tar_global_tmp t
              where t.nro_cuenta=ta.nro_cuenta
              and t.cod_persona=v_cod_persona
              and estado='C';
          exception
            when others then
              v_exi_can_tmp:='N';
           end;
           if v_exi_can_tc='S' or v_exi_can_tmp='S' then
             begin
              pr_baj_tar_tmp(v_cod_persona);
             exception
               when others then
                      prg_ins_log_programas(v_nom_programa,
                      'Error al dar de baja registros de cuenta cancelada',
                      v_cod_persona,
                      null);
             end;
           end if;

      end;


    end if;

    begin
      select distinct 'S'--si existe implica que ya dio de alta un TC por solicitud de credito
      into v_existe_tc
      from ta_tarjetas a
      where a.cod_estado <>'10'
      and it.fut_obt_procesadora(a.nro_cuenta)=it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
      and a.cod_persona=v_cod_persona;
      exception
        when others then
          v_existe_tc:='N';
          null;
      end;
      begin
      select distinct 'S'--si existe en estado 15 implica que ya se dio de alta mediante un reemplazo
      into v_existe_ta
      from ta_tar_global_tmp a
      where /*a.cod_estado=15
      and*/ a.cod_persona=v_cod_persona;
      exception
        when others then
          v_existe_ta:='N';
      end;

if v_existe_tc='N' and v_existe_ta='N'  then--ya que no existe en ambos casos ingresa para el alta de cuenta de TC

   for c in c_cli loop

      --Validamos que el cliente tenga firmado el Contrato Unico
      IF v_con_unico = 'S' THEN
        -- Si es S se debe controlar
        v_entro := 'S';
        begin
          select 'S'
            into v_contrato
            from ba_per_ima_documentos
           where cod_tip_documento = 64
             and est_doc in ('A', 'N')
             and cod_persona = c.cod_persona;
        exception
          when no_data_found then
            p_cod_error := 33;
            p_men_error := 'No tiene verificado la firma de contrato Unico';
            v_contrato  := 'N';
          WHEN too_many_rows THEN
            v_contrato := 'S';
          WHEN OTHERS THEN
            p_cod_error := 34;
            p_men_error := 'Verificar el procedimiento pr_cre_tar_vir_global';
            v_contrato  := 'N';
        end;
      ELSE
        -- no se controla contrato
        v_contrato := 'S';
      END IF;

      if v_contrato = 'S' then

        --Valido que el cliente ya cuente con una TD virtual activa
        begin
          select td.nro_cuenta
            into v_nro_cuenta
            from ah_tar_debitos td, ge_cta_clientes gct, ba_personas p
           where td.nro_cuenta = gct.nro_cuenta
             and gct.relacion = 'P'
             AND td.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
             --and td.tip_tar_debito = 'MV'
             and td.tar_activa = 'S'
             and gct.cod_persona = c.cod_persona
             AND td.cod_persona = gct.cod_persona
             AND gct.cod_persona = p.cod_persona
             and rownum = 1;
        exception
          when no_data_found then
            v_nro_cuenta := null;
            p_cod_error  := 34;
            p_men_error  := 'Cliente no posee una TD virtual activa';
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         p_men_error,
                                         1,
                                         4000),
                                  c.cod_persona,
                                  v_nro_cuenta);
          WHEN others THEN
            v_nro_cuenta := null;
            p_cod_error  := 34;
            p_men_error  := 'Error al buscar tarjeta virtual';
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         p_men_error,
                                         1,
                                         4000),
                                  c.cod_persona,
                                  v_nro_cuenta);
        end;

        if v_nro_cuenta is not null then
          v_entro := 'S';
          begin
            v_lugar := '02';

            -- Obtenemos el modulo y modalidad de la caja de ahorro
            select a.cod_modulo, a.cod_modalidad, a.cod_sub_modalidad,a.cod_moneda
              into v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,v_cod_moneda
              from ah_cta_vistas a
             where a.nro_cuenta = v_nro_cuenta;

            IF fug_obt_pardinamico('COD_MAD_DEB_COMBO2',
                                   v_cod_modulo,
                                   v_cod_modalidad,
                                   v_cod_moneda,
                                   NULL,
                                   v_cod_sub_modalidad) = 'S' THEN
              -- Para obtener el codigo de producto GP, se debe pasar por parametro en la url
              v_cod_producto := fue_obt_val_max_referencia('GLP_TIP_PRODUCTOS',
                                                           'GP_CRE_COMBO2');
              v_url          := v_url_deb || v_cod_producto;
            else
               p_cod_error:=v_err_sql;
               v_men_error:='Caja de ahorro '||v_nro_cuenta||' no valida.Verifique modalidad-moneda-submodalidad.';
               p_men_error:=v_men_error;

            END IF;

          if p_cod_error = v_cod_msg_exito then
            select count(*)
              into v_exi_tc
              from ta_tar_global_tmp g, ba_personas p
             where g.cod_persona = p.cod_persona
               and p.nro_documento = p_nro_doc
               and g.cod_estado in ('0','15');--normales y no habilitados

            if v_exi_tc != 0 then
              p_cod_error := 35;
              p_men_error := 'La persona ' || p_nro_doc ||
                             ' ya posee cuenta de credito virtual';
              prg_ins_log_programas(v_nom_programa,
                                    substr('Lugar: ' || v_lugar || ' - ' ||
                                           p_cod_error || ' - ' ||
                                           p_men_error,
                                           1,
                                           4000),
                                    c.cod_persona,
                                    v_nro_cuenta);
            ELSE
              --Se buscan los datos del cliente para enviar desde el json
              pr_obt_dat_clientes (c.cod_persona,
                                   v_direccion,
                                   v_numero,
                                   v_piso,
                                   v_departamento,
                                   v_cod_postal,
                                   v_barrio,
                                   v_tel_particular,
                                   v_tel_celular,
                                   v_email);

              -- se crea la estructura json para pasar al WS
              v_content := '{' || '"name":' || '"' || c.nombre || '"' || ',' || --nombres del cliente
                           '"lastName":' || '"' || c.apellido || '"' || ',' || --apelllidos del cliente
                           '"documentNumber":' || '"' || c.nro_documento || '"' || ',' || --nro documento del cliente (ci/pas/dni...etc)
                           '"gender":' || '"' || c.cod_sexo || '"' || ',' || --genero del cliente - M(masculino) o F(femenino)
                           '"birthday":' || '"' || c.fec_nacimiento || '"' || ',' || --fecha nacimiento del cliente
                           '"personCode":' || '"' || c.cod_persona || '"' || ',' || --cod persona del cliente itgf
                           '"cardType":' || '"' || '1' || '"' || ',' || --tipo de tarjeta
                           '"documentType":' || '"' || c.tip_documento || '"' || ',' ||
                           '"domicile": {' || '"street":' || '"' || v_direccion || '"' || ',' ||
                           '"number":' || '"' || v_numero || '"' || ',' ||
                           '"floor":' || '"' || v_piso || '"' || ',' ||
                           '"apartment":' || '"' || v_departamento || '"' || ',' ||
                           '"postalCode":' || '"' || v_cod_postal  || '"' || ',' ||
                           '"city":' || '"' || v_ciudad || '"' || ',' ||
                           '"province":' || '"' || v_provincia || '"' || ',' ||
                           '"country":' || '"' || v_pais || '"' ||
                           '},' ||
                           '"phone":{' || '"particular":' || '"' || v_tel_particular || '"' || ',' ||
                           '"cellPhone":' || '"' || v_tel_celular || '"' ||
                           '},' ||
                           '"email":' || '"' || v_email || '"' ||
                            '}';
             v_lugar   := '03';

              --solicitud ws
              pat_tgl.pr_ws_conector(v_content,
                                     v_url,
                                     v_nro_cuenta,
                                     c.cod_persona,
                                     'A',
                                     'POST',
                                     v_cod_err_ws,
                                     v_men_error); -- llama al web Service
              -- el cod_error 200 = Exitoso, distinto a 200 es un error.
              if v_cod_err_ws != v_cod_msg_exito THEN
                v_lugar     := '09';
                p_cod_error := v_cod_err_ws;
                p_men_error := v_men_error;
                prg_ins_log_programas(v_nom_programa,
                                      substr('Lugar: ' || v_lugar ||
                                             ' - IP: ' || v_url || ' - ' ||
                                             p_cod_error || ' - ' ||
                                             v_men_error,
                                             1,
                                             4000),
                                      c.cod_persona,
                                      v_nro_cuenta);
              end if;
            end if;
          end if;

          exception
            when v_error then
              p_cod_error := v_err_sql;
              p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                    ' Error de datos del pr_par_json: ' ||
                                    p_men_error || ' - ' || sqlerrm,
                                    1,
                                    4000);
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    c.cod_persona,
                                    v_nro_cuenta);
            when others then
              p_cod_error := v_err_sql;
              p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                    ' Error en programa ' || v_nom_programa || ': ' ||
                                    p_men_error || ' - ' || sqlerrm,
                                    1,
                                    4000);
              prg_ins_log_programas(v_nom_programa,
                                    p_men_error,
                                    c.cod_persona,
                                    v_nro_cuenta);
          end;
        end if;
      end if;
    end loop;
    if v_entro = 'N' then
      p_cod_error := v_err_sql;
      p_men_error := 'Lugar: ' || v_lugar || '. ' ||
                     'No realizo el alta de Cuenta en Global';
    end if;
else
  null;
end if;--aca terminaria if de verificacion de existencia de tarjetas
exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Alta de Cta Global' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa, p_men_error, null, p_nro_doc);
  end;

  /*Vinculacion tarjeta de debito fisica*/
  procedure pr_vin_tar_deb_fisica(p_nro_cedula        in ba_personas.nro_documento%type,
                                  p_nro_sob_principal in VARCHAR2,
                                  p_cod_error         out number,
                                  p_men_error         out varchar2) IS

    v_url_deb      varchar2(4000) := fug_obt_pardinamico('WS_ACT_TAR_DEB_VIR_FIS');
    v_url          varchar2(4000);
    v_content      varchar2(4000);
    v_lugar        varchar2(10);
    v_sql          varchar2(4000);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_VIN_TAR_DEB_FISICA';
    v_cod_persona  ba_personas.cod_persona%type;
    --- variables para parsear json ---
    v_id_producto        varchar2(6);
    v_nro_cta            ah_tar_debitos.nro_cuenta%type;
    v_tip_tarjeta        varchar2(10);
    v_nro_sob_secundario ta_imp_dat_embozados.nro_sob_pro_secundario%type;
    v_fec_vencimiento    ah_tar_debitos.fec_vencimiento%type;
    v_cadena             ge_par_dinamicos.val_parametro%type;
    v_nro_cta_global     ah_tar_debitos.nro_cta_global%type;
    v_nro_tarjeta        ah_tar_debitos.nro_tarjeta%type;
    v_men_error          varchar2(4000);
    v_cod_err_ws         varchar2(10);
    v_cod_error          varchar2(10);
    v_error exception;
    v_cod_producto varchar2(10);
    v_men_log      varchar2(4000);
    v_origin       ge_par_dinamicos.val_parametro%type;
    v_nro_cta_tc   ta_tar_global_tmp.nro_cuenta%type;
    v_nro_tar_tc   ta_tar_global_tmp.nro_tarjeta%type;
    pragma autonomous_transaction;

  begin
   Begin pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;
   pae_cnf.g_programa := 'GPPROFIN';
   end;
    v_lugar     := '01';
    p_cod_error := v_pro_correcto;
    begin
      select g.nro_cuenta, g.nro_tarjeta
        into v_nro_cta_tc, v_nro_tar_tc
        from ta_tar_global_tmp g, ba_personas p
       where g.cod_persona = p.cod_persona
         and p.nro_documento = p_nro_cedula;
    exception
      when no_data_found then
        p_cod_error := 1;
        p_men_error := 'No se encontro tarjeta de credito virtual para el nro.cedula ' ||
                       p_nro_cedula;
        v_men_log   := p_men_error;
      when others then
        p_cod_error := 1;
        p_men_error := 'Ocurrio un error al recuperar tarjeta de credito virtual para el nro.cedula ' ||
                       p_nro_cedula;
        v_men_log   := substr('Ocurrio un error al recuperar tarjeta de credito virtual para el nro.cedula ' ||
                              p_nro_cedula || ' ' || sqlerrm,
                              1,
                              4000);

    end;
    begin
      /*Busco el nro de cuenta que corresponde al nro de cedula*/
      select c.nro_cuenta, c.cod_persona, c.nro_cta_global, c.nro_tarjeta
        into v_nro_cta, v_cod_persona, v_nro_cta_global, v_nro_tarjeta
        from ba_personas p, ah_tar_debitos c, ah_cta_vistas v
       where p.nro_documento = p_nro_cedula
         and p.cod_persona = c.cod_persona
         and v.nro_cuenta = c.nro_cuenta
         and v.estado != 'C'
         and c.nro_tarjeta is not null
         and c.nro_cta_global is not null
         --and c.cod_est_solicitud = 0 ---se comenta esta linea para poder realizar el reemplazo
         and c.adherente = 00          --desde un estado que no sea el normal
         and nvl(c.tar_activa, 'N') = 'S'
         --and c.tip_tar_debito = 'MV'
         and c.nro_emision =
             (select max(nro_emision)
                from ah_tar_debitos d
               where d.cod_persona = c.cod_persona
                 and d.nro_cuenta = c.nro_cuenta
                 and d.adherente = c.adherente);

    exception
      when no_data_found then
        p_cod_error := 1;
        p_men_error := nvl(p_men_error,
                           'No se encontro tarjeta de debito virtual para el nro.cedula ' ||
                           p_nro_cedula);
        v_men_log   := p_men_error;

      when others then
        p_cod_error := 1;
        p_men_error := nvl(p_men_error,
                           'Ocurrio un error al recuperar tarjeta de debito virtual para el nro.cedula ' ||
                           p_nro_cedula);
        v_men_log   := nvl(v_men_log,
                           substr('Ocurrio un error al recuperar tarjeta de debito virtual para el nro.cedula ' ||
                                  p_nro_cedula || ' ' || sqlerrm,
                                  1,
                                  4000));
    end;
    /*Busco el nro de sobre secundario que corresponde al nro de sobre principal*/
    begin
      v_lugar := '02';
      select t.nro_sob_pro_secundario
        into v_nro_sob_secundario
        from ta_imp_dat_embozados t
       where t.nro_sob_pro_principal = p_nro_sob_principal
         and t.cod_persona is null;
    exception
      when no_data_found then
        p_cod_error := 1;
        p_men_error := nvl(p_men_error,
                           'No se encontro sobre secundario para sobre principal nro: ' ||
                           p_nro_sob_principal);
        v_men_log   := p_men_error;
      when others then
        p_cod_error := 1;
        p_men_error := nvl(p_men_error,
                           'Error al obtener sobre secundario del sobre principal nro: ' ||
                           p_nro_sob_principal);
        v_men_log   := nvl(v_men_log,
                           substr('Error al obtener sobre secundario del sobre principal nro: ' ||
                                  p_nro_sob_principal || ' ' || sqlerrm,
                                  1,
                                  4000));
    end;

    v_origin := nvl(fug_obt_pardinamico('IND_PRO_ORIGIN'), 'X'); --Indicador del tipo de proceso 5=reemplazo
    If nvl(v_origin, 'X') = 'X' then
      v_lugar     := '03';
      p_cod_error := 1;
      p_men_error := 'No se encuentra parametrizado el parametro dinamico "IND_PRO_ORIGIN"';
      v_men_log   := p_men_error;
    end if;

    if nvl(p_cod_error, v_pro_correcto) = v_pro_correcto then
      begin
        v_lugar  := '4';
        v_cadena := substr(v_url_deb,
                           instr(v_url_deb, '{', 1),
                           instr(v_url_deb, '}', 1) -
                           instr(v_url_deb, '{', 1) + 1);
        v_url    := replace(v_url_deb, v_cadena, v_nro_cta) ||
                    v_cod_producto;

        -- se crea la estructura json para pasar al WS
        v_content := '{' || '"envelope":' || '"' || v_nro_sob_secundario || '"' || ',' || --nombres del cliente
                     '"origin":' || '"' || v_origin || '"' || '}'; --cod persona del cliente itgf*/

        --solicitud ws
        pat_tgl.pr_ws_conector(v_content,
                               v_url,
                               v_nro_cta,
                               v_cod_persona,
                               'M',
                               'PUT',
                               v_cod_err_ws,
                               v_men_error); -- llama al web Service
        -- el cod_error 200 = Exitoso, distinto a 200 es un error.
        if v_cod_err_ws != v_cod_msg_exito THEN
          v_lugar     := '05';
          p_cod_error := v_cod_err_ws;
          p_men_error := v_men_error;
          prg_ins_log_programas(v_nom_programa,
                                substr('Lugar: ' || v_lugar || ' - ' ||
                                       'Response; ' || v_cod_err_ws ||
                                       ' - ' || v_men_error || ' Request: ' ||
                                       v_content,
                                       1,
                                       4000),
                                v_cod_persona,
                                v_nro_cta);
        else
          p_cod_error := v_cod_msg_exito;
          p_men_error := 'Operacion Exitosa';
        end if;

      exception
        when others then
          v_lugar     := '7';
          p_cod_error := v_err_sql;
          p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                                ' Error en programa ' || v_nom_programa || ': ' ||
                                p_men_error || ' - ' || sqlerrm,
                                1,
                                4000);
          prg_ins_log_programas(v_nom_programa,
                                p_men_error,
                                v_cod_persona,
                                v_nro_cta);
      end;
    else
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            v_cod_persona,
                            v_nro_cta);

    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Alta de Cta Global' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            v_cod_persona,
                            v_nro_cta);
  end;
  ---vinculacion de tarjeta de credito virtual a fisica
  procedure pr_vin_tar_credito(p_nro_doc           in ba_personas.nro_documento%type,
                               p_nro_sob_principal in ta_imp_dat_embozados.nro_sob_pro_principal%type,
                               p_cod_error         out number,
                               p_men_error         out varchar2) IS

    v_url_cre       varchar2(4000) := fug_obt_pardinamico('WS_VIN_TARJETA_CRE');
    v_url           varchar2(4000);
    v_content       varchar2(4000);
    v_lugar         varchar2(10);
    v_nom_programa  varchar2(50) := 'PAT_TGL.PR_VIN_TAR_CREDITO';
    v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
    v_cod_modulo    ah_cta_vistas.cod_modulo%type;
    --- variables para parsear json ---
    v_men_error  varchar2(4000);
    v_cod_err_ws varchar2(10);
    v_cod_error  varchar2(10);
    v_error exception;
    v_sob_pro_pinc ta_imp_dat_embozados.nro_sob_pro_principal%type;
    v_cod_persona  ba_personas.cod_persona%type;
    v_nro_cta      ge_cta_clientes.nro_cuenta%type;
    v_nro_tarjeta  ta_tar_global_tmp.nro_tarjeta%type;
    v_existe_tc    varchar2(1):='N';

    pragma autonomous_transaction;

  begin
     Begin pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
     pae_cnf.g_programa := 'GPPROFIN';
     end;
    v_lugar     := '01';
    p_cod_error := v_cod_msg_exito;
    p_men_error := 'Operacion Exitosa';
    begin

      begin
        Select t.cod_persona
          into v_cod_persona
          from ba_personas t
         where t.nro_documento = p_nro_doc;
      exception
        when no_data_found then
          p_cod_error := 1;
          p_men_error := 'No Existe la Persona con el Documento: ' ||
                         p_nro_doc;
          prg_ins_log_programas(v_nom_programa, p_men_error, null, null);
        when others then
          p_cod_error := 1;
          p_men_error := '1-Error: ' || sqlerrm;
          prg_ins_log_programas(v_nom_programa, p_men_error, null, null);

      end;
      if p_cod_error = v_cod_msg_exito then
        begin
          Select nro_sob_pro_principal,
                 substr(nro_pan_pro_principal, 13, 16) --, t.nro_cuenta
            into v_sob_pro_pinc, v_nro_tarjeta --, v_nro_cta
            from ta_imp_dat_embozados t
           where t.cod_persona = v_cod_persona
             and t.nro_sob_pro_principal = p_nro_sob_principal
             and t.estado = 'A';
        exception
          when no_data_found then
            p_cod_error := 2;
            p_men_error := 'No Existe nro_sob_pro_principal Activo para el Sobre: ' ||
                           p_nro_sob_principal || ' Para el Documento: ' ||
                           p_nro_doc;
            prg_ins_log_programas(v_nom_programa, p_men_error, null, null);

          when others then
            p_cod_error := 2;
            p_men_error := '2-Error: ' || sqlerrm;
            prg_ins_log_programas(v_nom_programa, p_men_error, null, null);

        end;

        begin
          Select t.nro_cuenta
            into v_nro_cta
            from ta_tar_global_tmp t
           where t.cod_persona = v_cod_persona;
        exception
          when no_data_found then
            p_cod_error := 3;
            p_men_error := 'No Existe nro_sob_pro_principal Activo para el Sobre: ' ||
                           p_nro_sob_principal || ' Para el Documento: ' ||
                           p_nro_doc;
            prg_ins_log_programas(v_nom_programa, p_men_error, null, null);

          when others then
            p_cod_error := 3;
            p_men_error := '3-Error: ' || sqlerrm;
            prg_ins_log_programas(v_nom_programa, p_men_error, null, null);

        end;

        if p_cod_error = v_cod_msg_exito then

          v_url := REPLACE(v_url_cre, '<NRO_CUENTA>', v_nro_cta);

          -- se crea la estructura json para pasar al WS
          v_content := '{' || '"envelope":' || '"' || v_sob_pro_pinc || '"' || ',' ||
                       '"origin": "' ||
                       fug_obt_pardinamico('COD_ORI_VIN_TC') || '"}';

          v_lugar := '03';

          --solicitud ws
          pat_tgl.pr_ws_conector(v_content,
                                 v_url,
                                 v_nro_cta,
                                 v_cod_persona,
                                 'M',
                                 'POST',
                                 v_cod_err_ws,
                                 v_men_error); -- llama al web Service
          --   commit;--agregado
          -- el cod_error 200 = Exitoso, distinto a 200 es un error.
          if v_cod_err_ws != v_cod_msg_exito THEN
            v_lugar     := '04';
            p_cod_error := v_cod_err_ws;
            p_men_error := v_men_error;
            prg_ins_log_programas(v_nom_programa,
                                  substr('Lugar: ' || v_lugar || ' - ' ||
                                         v_cod_err_ws || ' - ' ||
                                         v_men_error,
                                         1,
                                         4000),
                                  v_cod_persona,
                                  v_nro_cta);

          else
            --Cambiar de estado la TC reemplazada a NoHabilitada-15
            --agregar que si ya existe en ta_tarjetas no haga esta actualizacion
            --cod estado 6
            begin
              select 'S'
              into v_existe_tc
              from ta_tarjetas a
	      where a.cod_estado not in ('10','25','26')--que no este dada de baja
              and it.fut_obt_procesadora(a.nro_cuenta)=it.FUG_OBT_PARDINAMICO('COD_ENT_GLOBAL')
              and a.cod_persona=v_cod_persona;
              exception
                when others then
                  v_existe_tc:='N';
                  null;
              end;

              if v_existe_tc<>'S' then --si no existe registro en ta_Tarjetas
                                        --implica que es un credito accesorio del combo y si debe estar como estado 15
                  pr_act_tar_cre(v_nro_cta,
                                 v_cod_persona,
                                 v_nro_tarjeta,
                                 15,
                                 p_cod_error,
                                 p_men_error);
               end if;
          end if;
        end if;
      end if;
    exception
      when others then
        p_cod_error := v_err_sql;
        p_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                              ' Error en programa ' || v_nom_programa || ': ' ||
                              p_men_error || ' - ' || sqlerrm,
                              1,
                              4000);
        prg_ins_log_programas(v_nom_programa,
                              p_men_error,
                              v_cod_persona,
                              v_nro_cta);

    end;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || '. ' ||
                            'Error Inesperado en Vinculacion de Tarjeta Credito' ||
                            ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            v_cod_persona,
                            v_nro_cta);

  end;

  /**
    * Procedimiento insertar solicitud de tarjetas global
  **/



   procedure pr_act_sol_tarjeta(p_tip_solicitud in ta_sol_global.tipo_solicitud%type,
                               p_nro_tarjeta   in ta_imp_dat_embozados.nro_sob_pro_principal%type,
                               p_nro_cuenta    in ta_imp_dat_embozados.nro_cuenta%type,
                               p_motivo        in ta_sol_global.motivo%type,
                               p_est_pin       in ta_sol_global.est_pin%type default null,
                               p_causa         in ta_sol_global.cod_causa%type default null,
                               p_cod_solicitud out varchar2,
                               p_cod_error     out number,
                               p_men_error     out varchar2) IS
    v_cod_solicitud ta_sol_global.cod_solicitud%type;
    v_fecha         ta_sol_global.fecha%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    end;



    p_cod_error :=  /*v_pro_correcto;--*/
     v_cod_msg_exito;
    p_men_error := 'Transaccion Exitosa';

    select nvl(max(cod_solicitud), 0) + 1
      into v_cod_solicitud
      from ta_sol_global t
     where t.nro_tarjeta = p_nro_tarjeta
     and t.nro_cuenta = p_nro_cuenta;

    begin
      insert into ta_sol_global
        (cod_solicitud,
         tipo_solicitud,
         nro_tarjeta,
         motivo,
         est_pin,
         nro_cuenta,
         cod_causa)
      values
        (v_cod_solicitud,
         p_tip_solicitud,
         p_nro_tarjeta,
         p_motivo,
         nvl(p_est_pin, 'I'),
         p_nro_cuenta,
         p_causa);
    exception
      when others then
        p_cod_error := 1;
        p_men_error := substr('Error Insertando ta_sol_global, nro_tarjeta: ' ||
                              p_nro_tarjeta || ' ' || sqlerrm,
                              1,
                              2000);
    end;

    select to_char(max(fecha),'DDMMYY')||t.nro_tarjeta
      into v_cod_solicitud
      from ta_sol_global t
     where t.nro_tarjeta = p_nro_tarjeta
     and t.nro_cuenta = p_nro_cuenta
     group by t.nro_tarjeta;

     p_cod_solicitud := v_cod_solicitud;

  end;

  procedure pr_can_tar_avi_exterior(p_cod_viaje  ta_avi_via_exterior.cod_viaje%type,
                                    p_nro_cuenta ta_avi_via_exterior.nro_cuenta%type,
                                    p_cod_error  out number,
                                    p_men_error  out varchar2) is
    v_cod_error    number;
    v_men_error    varchar2(4000);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_CAN_TAR_AVI_EXTERIOR';
    v_lugar        varchar2(10);

  begin
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    End;

    update ta_avi_via_exterior
       set estado = 'C'
     where cod_viaje = p_cod_viaje
       and nro_cuenta = p_nro_cuenta
       and estado <> 'C';
    if sql%notfound then
      v_lugar     := '01';
      v_cod_error := 999;
      v_men_error := 'Sin registros para actualizar';
    else
      v_lugar     := '02';
      v_cod_error := 0;
      v_men_error := 'Operacion Exitosa';
    end if;

    commit;
    p_cod_error := v_cod_error;
    p_men_error := v_men_error;

  exception
    when others then
      v_lugar     := '03';
      p_cod_error := SQLCODE;
      p_men_error := 'Error en proceso PAT_TGL.PR_CAN_TAR_AVI_EXTERIOR ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas(v_nom_programa, p_men_error, null, p_cod_viaje);
  end;

  --Alta viaje exterior tarjeta credito
  procedure pr_alt_via_ext_cre(p_nro_cta  ta_cta_tarjetas.nro_cuenta%type,
                             p_cod_persona  ba_personas.cod_persona%type,
                             p_lis_cod_pais ta_avi_via_exterior.lis_cod_pais%type,
                             p_fec_vig_inicial ta_avi_via_exterior.fec_vig_inicial%type,
                             p_fec_vig_final ta_avi_via_exterior.fec_vig_final%type,
                             p_cod_viaje ta_avi_via_exterior.cod_viaje%type,
                             p_cod_error   out number,
                             p_men_error   out varchar2) is

      v_url        varchar2(4000) := fug_obt_pardinamico('WS_ALT_VIA_EXT_CRE'); --url aviso al exterior debito;
      v_content    varchar2(4000);
      v_lugar      varchar2(10);
      v_men_error  varchar2(4000);
      v_cod_err_ws number(6);
      v_error exception;
      v_nom_programa varchar2(50) := 'PAT_TGL.PR_ALT_VIA_EXT_CRE';
    begin
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    End;
      v_lugar      := '01';
      v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
      -- se crea la estructura json para pasar al ws
      v_content := '{' ||
      '"Adicional":' ||0||','||
      '"Paises":["'||p_lis_cod_pais||'"],'||
      '"VigenciaDesde":'||'"'||to_char(p_fec_vig_inicial,'yyyy-mm-dd')||'",'||
      '"VigenciaHasta":'||'"'||to_char(p_fec_vig_final,'yyyy-mm-dd')||'"'||
     -- '"AvisoViajeId":'||p_cod_viaje||
      '}';

     v_lugar   := '02';
    if p_fec_vig_inicial<trunc(sysdate) or p_fec_vig_final<trunc(sysdate) or p_fec_vig_final<p_fec_vig_inicial then
       v_cod_err_ws:=999;
       v_men_error:='Error en las fechas ingresadas';
       prg_ins_log_programas(v_nom_programa,
                              substr(v_men_error||' . Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nro_cta);
    else
       pat_tgl.pr_ws_conector(v_content,
                             v_url,
                             p_nro_cta,
                             p_cod_persona,
                             'A',
                            'POST',
                             v_cod_err_ws,
                             v_men_error); -- llama al web service
     end if;

      if v_cod_err_ws != v_cod_msg_exito then
        p_cod_error := v_cod_err_ws;
        p_men_error := v_men_error;
      else
        p_cod_error := v_cod_msg_exito;
        p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                           'Transaccion Exitosa!');
      end if;

    exception
      when others then
        p_cod_error := v_err_sql;
        p_men_error := 'Error en proceso PAT_TGL.PR_ALT_VIA_EXT_CRE. ' ||
                       substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                              1,
                              4000);
        prg_ins_log_programas(v_nom_programa,
                              substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nro_cta);
    end;

    --Alta viaje exterior tarjeta debito
  procedure pr_alt_via_ext_deb(p_nro_cta  ta_cta_tarjetas.nro_cuenta%type,
                             p_cod_persona  ba_personas.cod_persona%type,
                             p_lis_cod_pais ta_avi_via_exterior.lis_cod_pais%type,
                             p_fec_vig_inicial ta_avi_via_exterior.fec_vig_inicial%type,
                             p_fec_vig_final ta_avi_via_exterior.fec_vig_final%type,
                             p_cod_viaje ta_avi_via_exterior.cod_viaje%type,
                             p_cod_error   out number,
                             p_men_error   out varchar2) is

      v_url        varchar2(4000) := fug_obt_pardinamico('WS_ALT_VIA_EXT_DEB'); --url aviso al exterior debito;
      v_content    varchar2(4000);
      v_lugar      varchar2(10);
      v_men_error  varchar2(4000);
      v_cod_err_ws number(6);
      v_error exception;
      v_nom_programa varchar2(50) := 'PAT_TGL.PR_ALT_VIA_EXT_DEB';
    begin
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    End;
      v_lugar      := '01';
      v_url        := replace(v_url, '{alfaAccountNumber}', p_nro_cta);
      -- se crea la estructura json para pasar al ws
      v_content := '{' ||
      '"Adicional":' ||0||','||
      '"Paises":["'||p_lis_cod_pais||'"],'||
      '"VigenciaDesde":'||'"'||to_char(p_fec_vig_inicial,'yyyy-mm-dd')||'",'||
      '"VigenciaHasta":'||'"'||to_char(p_fec_vig_final,'yyyy-mm-dd')||'",'||
      '"AvisoViajeId":'||p_cod_viaje||
      '}';

     v_lugar   := '02';

    if p_fec_vig_inicial<trunc(sysdate) or p_fec_vig_final<trunc(sysdate) or p_fec_vig_final<p_fec_vig_inicial then
       v_cod_err_ws:=999;
       v_men_error:='Error en las fechas ingresadas';
       prg_ins_log_programas(v_nom_programa,
                              substr(v_men_error||' . Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nro_cta);
    else
     pat_tgl.pr_ws_conector(v_content,
                             v_url,
                             p_nro_cta,
                             p_cod_persona,
                             'A',
                            'POST',
                             v_cod_err_ws,
                             v_men_error); -- llama al web service
      end if;

      if v_cod_err_ws != v_cod_msg_exito then
        p_cod_error := v_cod_err_ws;
        p_men_error := v_men_error;
      else
        p_cod_error := v_cod_msg_exito;
        p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                           'Transaccion Exitosa!');
      end if;

    exception
      when others then
        p_cod_error := v_err_sql;
        p_men_error := 'Error en proceso PAT_TGL.PR_ALT_VIA_EXT_DEB. ' ||
                       substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                              1,
                              4000);
        prg_ins_log_programas(v_nom_programa,
                              substr('Lugar: ' || v_lugar || ' - ' || sqlerrm,
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nro_cta);
  end;

  procedure prt_act_pag_gp(p_nro_cuenta   ta_cobros_gp.nro_cuenta%type,
                           p_fecha        ta_cobros_gp.fec_proceso%type,
                           p_hora         ta_cobros_gp.hora%type,
                           p_usuario      ta_cobros_gp.cod_usuario%type,
                           p_estado       ta_cobros_gp.est_envio%type,
                           p_cod_error    out number,
                           p_men_error    out varchar2,
                           p_nro_documento in ta_cobros_gp.nro_documento%type default null) is
  v_cod_error       number := 0;
  v_men_error       varchar2(4000);
  v_pro_correcto    number := 0;
  v_ent_procesadora ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_ENT_GLOBAL');
  v_cod_oficina     ge_par_generales.cod_ofi_matriz%type;
  v_cod_sucursal    ta_sucursales.cod_sucursal%type;
  v_nom_programa    varchar(50) := 'PRT_ACT_PAG_GP';
  begin
    Begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 5;
        --pae_cnf.g_programa := 'GPPROFIN';
     End;

     begin
       update ta_cobros_gp
         set est_envio = p_estado,
         nro_documento = p_nro_documento
       where nro_cuenta = p_nro_cuenta
         and fec_proceso = p_fecha
         and hora = p_hora
         and cod_usuario = p_usuario;
       If sql%notfound then
         v_cod_error := '999';
         p_men_error := 'Registro no encontrado';
       End if;
     exception
       when others then
         v_cod_error:= SQLCODE;
         p_men_error:= 'Error al actualizar estado';
                       prg_ins_log_programas(v_nom_programa,
                                            substr(p_men_error||sqlerrm,
                                            1,
                                            4000),
                                            p_fecha,
                                            p_nro_cuenta);
     end;

     if v_cod_error = v_pro_correcto then

       select cod_ofi_matriz into v_cod_oficina from ge_par_generales;

       select cod_sucursal
        into v_cod_sucursal
        from ta_sucursales
       where cod_ent_procesadora = v_ent_procesadora
         and cod_oficina = v_cod_oficina
         and rownum = 1;

       begin
         insert into ta_env_cobros_his
           (cod_ent_procesadora,
            cod_sucursal,
            nro_cuenta,
            nro_tarjeta,
            monto,
            fec_valor,
            fec_envio,
            hor_envio,
            tip_pago,
            estado)
           select v_ent_procesadora,
                  v_cod_sucursal,
                  cob.nro_cuenta,
                  cob.nro_tarjeta,
                  cob.monto,
                  cob.fec_valor,
                  cob.fec_proceso,
                  cob.hora,
                  'N',
                  cob.estado
             from ta_cobros_gp cob
            where cob.nro_cuenta = p_nro_cuenta
              and cob.fec_proceso = p_fecha
              and cob.hora = p_hora
              and cob.cod_usuario = p_usuario
              and cob.est_envio = p_estado;
       exception
         when others then
           v_cod_error:= SQLCODE;
           p_men_error:= 'Error al insertar historico';
                       prg_ins_log_programas(v_nom_programa,
                                            substr(p_men_error,
                                            1,
                                            4000),
                                            p_fecha,
                                            p_nro_cuenta);
       end;
     end if;
     p_cod_error := v_cod_error;
  end;
  procedure pr_act_motivo(p_cod_persona in ba_personas.cod_persona%type,
                              p_nro_cuenta  in ta_cta_tarjetas.nro_cuenta%type,
                              p_nro_tarjeta in ta_tarjetas.nro_tarjeta%type,
                              p_motivo      in ta_sol_global.motivo%type,
                              p_cod_causa   in ta_sol_global.cod_causa%type,
                              p_tip_tarjeta in varchar2,
                              p_cod_error   out number,
                              p_men_error   out varchar2) is
    v_lugar        varchar2(10);
    v_men_error    varchar2(4000);
    v_nom_programa varchar2(50) := 'PAT_TGL.PR_HAB_TAB_MOTIVO';
  begin
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
      pae_cnf.g_programa := 'GPPROFIN';
    End;
    p_cod_error := v_pro_correcto;
    p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'), 'Transaccion Exitosa!');
    v_lugar := '01';
    if p_tip_tarjeta = 'C' then
      update ta_tarjetas t
         set t.motivo = p_motivo, t.cod_causa = p_cod_causa
       where t.nro_cuenta = p_nro_cuenta
         and SUBSTR(t.nro_tarjeta, -4, 4) = p_nro_tarjeta;
      if sql%notfound then
        v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                              'No se encuenta Nro. de TC a Actualizar.' || ' - ' || sqlerrm,
                              1, 4000);
        p_cod_error := v_err_sql;
        p_men_error := v_men_error;
        prg_ins_log_programas(v_nom_programa,
                              p_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
    end if;
    v_lugar := '02';
    if p_tip_tarjeta = 'D' then
      update ah_tar_debitos t
         set t.motivo = p_motivo, t.cod_causa = p_cod_causa
       where t.nro_tarjeta = p_nro_tarjeta
         and t.nro_cuenta = p_nro_cuenta;
      if sql%notfound then
        v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                              'No se encuenta Nro. de TD a Actualizar.' || ' - ' || sqlerrm,
                              1, 4000);
        p_cod_error := v_err_sql;
        p_men_error := v_men_error;
        prg_ins_log_programas(v_nom_programa,
                              p_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PAT_TGL.PR_HAB_TAB_MOTIVO ' ||
                     substr('Lugar: ' || v_lugar || ' - ' || sqlerrm, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            substr('Lugar: ' || v_lugar || ' - ' || sqlerrm, 1, 4000),
                            p_cod_persona,
                            p_nro_cuenta);
  end;

  PROCEDURE pr_obt_dat_clientes (p_cod_persona IN ba_personas.cod_persona%TYPE,
                                 p_direccion OUT ba_direcciones.direccion%TYPE,
                                 p_numero OUT ba_direcciones.numero%TYPE,
                                 p_piso OUT ba_direcciones.piso%TYPE,
                                 p_departamento OUT ba_direcciones.departamento%TYPE,
                                 p_cod_postal OUT ba_direcciones.cod_postal%TYPE,
                                 p_barrio OUT ba_barrios.descripcion%TYPE,
                                 p_tel_particular OUT ba_telefonos.telefono%TYPE,
                                 p_tel_celular OUT ba_telefonos.telefono%TYPE,
                                 p_email OUT ba_personas.dir_correo%TYPE
                                 ) IS
  v_dir_defecto  ba_direcciones.direccion%TYPE := 'Sta Teresa';
  v_pis_defecto  ba_direcciones.piso%TYPE := 5;
  v_post_defecto ba_direcciones.cod_postal%TYPE := 1209;
  v_tel_defecto  ba_telefonos.telefono%TYPE := '4168000';
  v_mail_defecto ba_personas.dir_correo%TYPE := 'something@itti.digital';

  BEGIN
    /*Busco los datos de las direcciones del cliente*/
    BEGIN
      SELECT fug_eli_car_invalidos(nvl(substr(direccion,1,35),v_dir_defecto)),
             numero,
             fug_eli_car_invalidos(nvl(substr(piso,1,2),v_pis_defecto)),
             fug_eli_car_invalidos(departamento),
             fug_eli_car_invalidos(nvl(substr(cod_postal,1,8),v_post_defecto)),
             fug_eli_car_invalidos(fue_obt_des_barrio(cod_pais, cod_ciudad, cod_barrio))
        INTO p_direccion,
             p_numero,
             p_piso,
             p_departamento,
             p_cod_postal,
             p_barrio
        FROM ba_direcciones
       WHERE cod_persona = p_cod_persona
         AND principal = 'S'
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        p_direccion := v_dir_defecto;
        p_numero := NULL;
        p_piso := v_pis_defecto;
        p_departamento := NULL;
        p_cod_postal := v_post_defecto;
        p_barrio := NULL;
    END;
    BEGIN
      --Telefono particular
      SELECT nvl(substr(a.area,1,4) || substr(a.telefono,1,14),v_tel_defecto)
        INTO p_tel_particular
        FROM ba_telefonos a
       WHERE a.cod_persona = p_cod_persona
         AND a.principal = 'S'
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        p_tel_particular := v_tel_defecto;
    END;

    BEGIN
      --Celular particular
      SELECT substr(a.area,1,4) || substr(a.telefono,1,14)
        INTO p_tel_celular
        FROM ba_telefonos a
       WHERE a.cod_persona = p_cod_persona
         AND a.cod_telefono = (SELECT MAX(x.cod_telefono)
                                 FROM ba_telefonos x
                                WHERE x.tipo = 'P'
                                  AND x.tip_linea = 'C'
                                  AND x.cod_persona = a.cod_persona)
         AND rownum = 1;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
      --Email
      SELECT pat_val.fu_eli_acentos(nvl(a.dir_correo,v_mail_defecto),'S')
        INTO p_email
        FROM ba_personas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN OTHERS THEN
        p_email := v_mail_defecto;
    END;
  END;

  /**
   * Procedimiento para realizar upgrade de TD clasica a black
  **/
  PROCEDURE pr_upg_deb_blk_gp(p_nro_cuenta     IN ah_tar_debitos.nro_cta_global%TYPE,--Cta GP
                              p_id_producto     IN ah_tar_debitos.id_producto%TYPE,
                              p_nro_cta         IN ah_tar_debitos.nro_cuenta%TYPE,--Cta Ueno
                              p_nro_tarjeta     IN ah_tar_debitos.nro_tarjeta%TYPE,
                              p_fec_vencimiento IN ah_tar_debitos.fec_vencimiento%TYPE,
                              p_tip_tarjeta     IN ah_tar_debitos.tip_tar_debito%TYPE,
                              p_nro_sobre       IN VARCHAR2,
                              p_cod_error       OUT NUMBER,
                              p_men_error       OUT VARCHAR2)IS
    v_pro_correcto    VARCHAR2(6)    := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
    v_cod_error       VARCHAR2(6)    := v_pro_correcto;
    v_men_error       VARCHAR2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');
    v_nom_programa    VARCHAR2(30)   := 'PAT_TGL.PR_UPG_DEB_BLK_GP';
    v_lugar           VARCHAR2(3)    := '000';
    v_nro_cta         ah_tar_debitos.nro_cuenta%TYPE;
    v_nro_tarjeta     ah_tar_debitos.nro_tarjeta%TYPE;
    v_cod_persona     ah_tar_debitos.cod_persona%TYPE;
    v_nro_bin         ah_tar_debitos.nro_bin%TYPE;
    v_est_modulo      ba_modulos.cod_modulo%TYPE;

BEGIN
  BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

   --Verificamos el estado del modulo.
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(5);
    IF v_est_modulo in (6) THEN
      -- Se esta corriendo el proceso de cierre
      v_cod_error     := v_err_sql;
      v_men_error     := 'Modulo en proceso de cierre';
    END IF;

  --Validaciones previas
  -- obtiene el nro de tarjeta
    IF v_cod_error = v_pro_correcto THEN
      v_lugar := 100;
      BEGIN
        SELECT a.nro_tarjeta,cod_persona
          INTO v_nro_tarjeta,v_cod_persona
          FROM ah_tar_debitos a
         WHERE a.nro_cta_global = p_nro_cuenta -- cta glp
           AND to_number(a.nro_emision) =
             (SELECT MAX(to_number(b.nro_emision))
                    FROM ah_tar_debitos b
                   WHERE b.nro_cuenta = a.nro_cuenta)
                     AND a.tar_activa='S';
      EXCEPTION
        WHEN OTHERS THEN
          v_cod_error := v_err_sql;
          v_men_error := substr('Lugar: ' || v_lugar ||
                                 ' - Error al recuperar nro_tarjeta. - '||sqlerrm, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                v_men_error,
                                NULL,
                                p_nro_cuenta);
      END;
    END IF;

    IF v_cod_error = v_pro_correcto THEN
      v_lugar := 101;
    --Se igualan cod_persona y nro_cuenta para vinculacion a ta_imp_dat_embozados
      BEGIN
        UPDATE ta_imp_dat_embozados a
           SET a.nro_cta_deb_global = p_nro_cuenta,
               a.cod_persona=v_cod_persona
         WHERE a.nro_sob_pro_secundario = p_nro_sobre
           AND a.estado='A'
           AND cod_persona IS NULL;
            IF SQL%NOTFOUND THEN
              v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                             'No se encuenta sobre ' || p_nro_sobre || ' a actualizar.' ||
                             ' - ' || sqlerrm,
                             1,
                             4000);
              v_cod_error := v_err_sql;
              prg_ins_log_programas(v_nom_programa,
                                    v_men_error,
                                    v_cod_persona,
                                    p_nro_cuenta);
            ELSE
              SAVEPOINT inicio;
            END IF;
      EXCEPTION
        WHEN OTHERS THEN
          v_cod_error := v_err_sql;
          v_men_error := substr('Lugar: ' || v_lugar || ' - Error al actualizar el sobre ' || p_nro_sobre || ' - ' ||SQLERRM, 1, 4000);
          prg_ins_log_programas(v_nom_programa,
                                v_men_error,
                                v_cod_persona,
                                p_nro_cuenta);
      END;
    END IF;


    IF v_cod_error = v_pro_correcto THEN
    -- baja de la td actual
      v_lugar := '104';
      BEGIN
        pr_act_est_tarjeta(p_nro_cta,
                           v_nro_tarjeta,
                           'Baja',
                           v_cod_error,
                           v_men_error);
      EXCEPTION
        WHEN OTHERS THEN
            v_cod_error := v_err_sql;
            v_men_error := substr('Lugar: ' || v_lugar ||
                                   ' - Error al dar de baja TD '|| SQLERRM, 1, 4000);
            prg_ins_log_programas(v_nom_programa,
                                  v_men_error,
                                  v_cod_persona,
                                  p_nro_cuenta);
      END;

      IF v_cod_error = v_pro_correcto THEN
        v_lugar := '105';
        BEGIN
          begin
            select val_minimo
              into v_nro_bin
              from it.ta_imp_dat_embozados s
              left join (select val_minimo
                         from ba_cod_referencias s
                         where dominio = 'NRO_BIN_TAR_GP'
                         and activo = 'S') z
                on (instr(s.nro_pan_pro_secundario, z.val_minimo) > 0
                   )
              where nro_sob_pro_principal = p_nro_sobre;
          exception
            when others then
              v_nro_bin := nvl(fug_obt_pardinamico('NRO_BIN_TAR_DEB_BLACK'),
                               '529278');
          end;



          --alta de nueva emision
          pr_alt_tar_debpre(p_nro_cuenta,
                            p_id_producto,
                            p_nro_cta,
                            v_nro_bin,
                            p_nro_tarjeta,
                            p_fec_vencimiento,
                            p_tip_tarjeta,
                            v_cod_error,
                            v_men_error);
        EXCEPTION
          WHEN OTHERS THEN
            v_cod_error := v_err_sql;
            v_men_error := substr('Error al insertar TD '||SQLERRM, 1, 4000);
            prg_ins_log_programas(v_nom_programa,
                                  v_men_error,
                                  v_cod_persona,
                                  p_nro_cuenta);
        END;
      END IF;
    END IF;

    IF v_cod_error != v_pro_correcto THEN
      prg_ins_log_programas(v_nom_programa,
                            'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                            ' # ' || v_men_error,
                            v_cod_persona,
                            p_nro_cuenta);
      ROLLBACK TO inicio;
    ELSE
      COMMIT;
    END IF;
    p_cod_error := v_cod_error;
    p_men_error := v_men_error;

EXCEPTION
  WHEN OTHERS THEN
    p_cod_error := v_err_sql;
    p_men_error := v_men_error;
    prg_ins_log_programas(v_nom_programa,
                          'Lugar: ' || v_lugar || '- ' || v_cod_error || '. ' ||
                          v_men_error,
                          v_cod_persona,
                          p_nro_cuenta);
END;
  /**
   * Procedimiento para realizar upgrade de TC clasica a black
  **/
  PROCEDURE pr_upg_cre_blk_gp(p_nro_cuenta      IN ta_tarjetas.nro_cuenta%TYPE, --Cta GP
                              p_nro_tarjeta     IN ta_tarjetas.nro_tarjeta%TYPE,
                              p_fec_vencimiento IN ta_tarjetas.fec_vencimiento%TYPE,
                              p_nro_sobre       IN VARCHAR2,
                              p_cod_error       OUT NUMBER,
                              p_men_error       OUT VARCHAR2)IS
  v_pro_correcto          VARCHAR2(6) := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
  v_cod_error             VARCHAR2(6) := v_pro_correcto;
  v_men_error             VARCHAR2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');
  v_lugar                 VARCHAR2(3) := '000';
  v_nom_programa          VARCHAR2(30) := 'PAT_TGL.PR_UPG_CRE_BLK_GP';
  v_nro_tarjeta_ant       ta_Tarjetas.Nro_Tarjeta%TYPE;
  v_fec_vencimiento_ant   ta_tarjetas.fec_vencimiento%TYPE;
  v_nom_embozado          ta_tarjetas.nom_embozar%TYPE;
  v_nro_bin               ah_tar_debitos.nro_bin%TYPE:= nvl(fug_obt_pardinamico('NRO_BIN_TAR_CRE_BLACK'),'536090');
  v_cod_persona           ta_tarjetas.cod_persona%TYPE;
  v_est_modulo            ba_modulos.cod_modulo%TYPE;
  v_cod_modalidad_ant     ta_tipos.cod_modalidad%type;
  v_cod_modalidad         ta_tipos.cod_modalidad%type;
  v_afinidad              ta_tipos.afinidad%type;
  v_sub_afinidad          ta_tipos.sub_afinidad%type;
  v_cod_producto          ba_cod_referencias.val_maximo%type;

  BEGIN
     BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  END;

  --Verificamos el estado del modulo.
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(5);
  IF v_est_modulo in (6) THEN
  -- Se esta corriendo el proceso de cierre
    v_cod_error     := v_err_sql;
    v_men_error     := 'Modulo en proceso de cierre';
  END IF;

  IF v_cod_error = v_pro_correcto THEN
    BEGIN
      SELECT a.nro_tarjeta,a.fec_vencimiento,a.nom_embozar,a.cod_persona,g.cod_modalidad
        INTO v_nro_tarjeta_ant,v_fec_vencimiento_ant,v_nom_embozado,v_cod_persona,v_cod_modalidad_ant
        FROM ta_tarjetas a,ge_cta_clientes g
       WHERE a.nro_cuenta = p_nro_cuenta --Cta GP
         AND a.vigente = 'S'
         AND a.cod_estado <> '10'
         and g.nro_cuenta=a.nro_cuenta
         and g.relacion='P';
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_error := v_err_sql;
        v_men_error := substr('Error al recuperar nro_tarjeta '||SQLERRM, 1, 4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
    END;
  END IF;

  IF v_cod_error = v_pro_correcto THEN
       BEGIN
         select cod_modalidad,afinidad,sub_afinidad,val_maximo cod_producto
         into v_cod_modalidad,v_afinidad,v_sub_afinidad,v_cod_producto
        from it.ta_imp_dat_embozados s,
        (select cod_modalidad,nro_bin,afinidad,sub_afinidad from ta_tipos where cod_ent_procesadora=it.fug_obt_pardinamico('COD_ENT_GLOBAL')) z,
        (select val_minimo,val_maximo from ba_cod_referencias s where dominio= 'NRO_BIN_TAR_GP')b
        where (instr(s.nro_pan_pro_principal,z.nro_bin)>0)
        and z.nro_bin=b.val_minimo
        and nro_sob_pro_principal=p_nro_sobre;
        EXCEPTION
      WHEN OTHERS THEN
        v_cod_error := v_err_sql;
        v_men_error := substr('Error al recuperar datos del producto '||SQLERRM, 1, 4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
     end;
  END IF;

  IF v_cod_error = v_pro_correcto THEN
    BEGIN
      UPDATE ta_imp_dat_embozados a
         SET a.nro_cuenta  = p_nro_cuenta, --Cta GP
             a.estado = 'E'
       WHERE a.nro_sob_pro_principal = p_nro_sobre
         AND a.cod_persona = v_cod_persona;
          IF  SQL%NOTFOUND THEN
            v_men_error := substr('Lugar: ' || v_lugar || ' - ' ||
                           'No se encuenta sobre a actualizar.' ||
                           ' - ' || SQLERRM,
                           1,
                           4000);
            v_cod_error := v_err_sql;
            prg_ins_log_programas(v_nom_programa,
                                  v_men_error,
                                  v_cod_persona,
                                  p_nro_cuenta);
          ELSE
            SAVEPOINT inicio;
          END IF;
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_error := v_err_sql;
        v_men_error := substr(sqlerrm, 1, 4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
    END;
  END IF;

  v_lugar := '100';
  IF v_cod_error = v_pro_correcto THEN
    BEGIN--recuperar datos de parametria
      UPDATE ta_cta_tarjetas  s
         SET s.cod_modalidad = v_cod_modalidad,
             s.afinidad = v_afinidad,
             s.sub_afinidad = v_sub_afinidad
       WHERE s.nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_error := v_err_sql;
        v_men_error := substr('Error al actualizar ta_cta_tarjetas - '||sqlerrm, 1, 4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
    END;
  END IF;

  IF v_cod_error = v_pro_correcto THEN
  --se da de baja nro de tarjeta anterior
    BEGIN
      pr_act_est_tar_cre(p_nro_cuenta,
                         v_nro_tarjeta_ant,
                         1,
                         v_cod_error,
                         v_men_error);
      IF v_cod_error != v_pro_correcto THEN
        prg_ins_log_programas(v_nom_programa,
                              'Procedimiento: pr_act_est_tar_cre '|| ' - ' || v_cod_error ||
                              ' - ' || v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        v_cod_error := v_err_sql;
        v_men_error := substr('Error al actualizar tc anterior-'||SQLERRM, 1, 4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              v_cod_persona,
                              p_nro_cuenta);
    END;
   END IF;

   IF v_cod_error = v_pro_correcto THEN
   --se da de alta el nuevo registro con nuevo nro de tarjeta
     BEGIN
       pr_alt_tar_cre(p_nro_cuenta,
                      p_nro_tarjeta,
                      v_cod_persona,
                      p_fec_vencimiento,
                      v_nom_embozado,
                      v_cod_producto,
                      v_cod_error,
                      v_men_error);
       IF v_cod_error != v_pro_correcto THEN
         prg_ins_log_programas(v_nom_programa,
                               'Procedimiento: pr_alt_tar_cre '|| '- ' || v_cod_error ||
                               ' - ' || v_men_error,
                               v_cod_persona,
                               p_nro_cuenta);
       END IF;
     EXCEPTION
       WHEN OTHERS THEN
         v_cod_error := v_err_sql;
         v_men_error := substr('Error al actualizar TC anterior-'||SQLERRM, 1, 4000);
         prg_ins_log_programas(v_nom_programa,
                               v_men_error,
                               v_cod_persona,
                               p_nro_cuenta);
     END;
   END IF;

   IF v_cod_error = v_pro_correcto THEN
     BEGIN
       UPDATE ta_tar_global_tmp s
          SET s.nro_tarjeta  = p_nro_tarjeta,
              s.tip_tarjeta  = 0,
              s.cod_estado   = 0,
              s.cod_producto = v_cod_producto,
              s.fec_vencimiento = p_fec_vencimiento
        WHERE cod_persona = v_cod_persona
          AND s.nro_cuenta = p_nro_cuenta;
       EXCEPTION
         WHEN OTHERS THEN
           v_cod_error := v_err_sql;
           v_men_error := substr('Error al actualizar ta_tar_global_tmp - '||SQLERRM, 1, 4000);
           prg_ins_log_programas(v_nom_programa,
                                 v_men_error,
                                 v_cod_persona,
                                 p_nro_cuenta);
       END;
   END IF;

  IF v_cod_error = v_pro_correcto THEN
    BEGIN
      UPDATE it.ge_cta_dat_adicionales
         SET val_parametro = v_cod_producto
       WHERE nro_cuenta = p_nro_cuenta
         AND parametro = 'COD_PRO_TDC_GLOBAL';
     EXCEPTION
       WHEN no_data_found THEN
         INSERT INTO ge_cta_dat_adicionales (nro_cuenta, parametro, val_parametro)
         VALUES (p_nro_cuenta, 'COD_PRO_TDC_GLOBAL', v_cod_producto);
       WHEN OTHERS THEN
         v_cod_error := v_err_sql;
         v_men_error := substr('Error al actualizar ge_cta_dat_adicionales - '||SQLERRM, 1, 4000);
         prg_ins_log_programas(v_nom_programa,
                               v_men_error,
                               v_cod_persona,
                               p_nro_cuenta);
     END;
  END IF;
  --Si el upgrade termino Ok, se realiza la actualizacion de movs.
   IF v_cod_error = v_pro_correcto THEN
    commit;
    pr_act_mov_upgrade(p_nro_cuenta,
                      v_cod_persona,
                      v_cod_modalidad_ant,
                      v_cod_modalidad);
    else
     prg_ins_log_programas(v_nom_programa,
                           'Lugar: ' || v_lugar || '- ' || v_cod_error || '. ' ||
                           v_men_error);
     ROLLBACK TO inicio;
   END IF;
   p_cod_error:=v_cod_error;
   p_men_error:=v_men_error;
 EXCEPTION
   WHEN OTHERS THEN
     p_cod_error := v_err_sql;
     p_men_error := v_men_error;
     prg_ins_log_programas(v_nom_programa,
                           'Lugar: ' || v_lugar || '- ' || v_cod_error || '. ' ||
                           v_men_error,
                           v_cod_persona,
                           p_nro_cuenta);
 END;

PROCEDURE pr_act_mov_upgrade(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                             p_cod_persona IN ba_personas.cod_persona%TYPE,
                             p_cod_mad_anterior IN ge_cuentas.cod_modalidad%TYPE,
                             p_cod_mad_actual IN ge_cuentas.cod_modalidad%TYPE) IS
v_pro_correcto          VARCHAR2(6) := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
v_cod_error             VARCHAR2(6) := v_pro_correcto;
v_men_error             VARCHAR2(4000) := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),'Transaccion Exitosa!');
v_lugar                 VARCHAR2(3) := '000';
v_nom_programa          VARCHAR2(30) := 'PAT_TGL.PR_ACT_MOV_UPGRADE';
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  BEGIN
    UPDATE ge_cta_clientes s
       SET s.cod_modalidad = p_cod_mad_actual
     WHERE s.nro_cuenta= p_nro_cuenta
       AND s.cod_modalidad = p_cod_mad_anterior;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_error := v_err_sql;
      v_men_error := substr('Error al actualizar ge_cta_clientes - '||SQLERRM, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            v_men_error,
                            p_cod_persona,
                            p_nro_cuenta);
  END;

  BEGIN
    UPDATE ge_movimientos s
       SET cod_modalidad = p_cod_mad_actual
     WHERE s.nro_cuenta = p_nro_cuenta
       AND s.cod_modalidad = p_cod_mad_anterior;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_error := v_err_sql;
      v_men_error := substr('Error al actualizar ge_movimientos - '||SQLERRM, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            v_men_error,
                            p_cod_persona,
                            p_nro_cuenta);
  END;

  BEGIN --Si tiene registros nocturnos
    UPDATE ge_movimientos_noc s
       SET cod_modalidad = p_cod_mad_actual
     WHERE s.nro_cuenta = p_nro_cuenta
       AND s.cod_modalidad = p_cod_mad_anterior;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_error := v_err_sql;
      v_men_error := substr('Error al actualizar ge_movimientos_noc - '||SQLERRM, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                            v_men_error,
                            p_cod_persona,
                            p_nro_cuenta);
  END;

  BEGIN
    UPDATE ta_movimientos_his t
       SET cod_modalidad = p_cod_mad_actual
     WHERE t.nro_cuenta = p_nro_cuenta
       AND t.fecha >= it.PAG_CAL.FU_OBT_FEC_PRI_DIA_MES_HABIL(5)
       AND t.cod_modalidad = p_cod_mad_anterior;
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_error := v_err_sql;
      v_men_error := substr('Error al actualizar ta_movimientos_his - '||SQLERRM, 1, 4000);
      prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
  END;
  COMMIT;
END;

procedure pr_ins_dat_tarjetas_gp(p_cod_persona     in ba_personas.cod_persona%type,
                                 p_nro_cuenta      in ta_tarjetas.nro_cuenta%type,
                                 p_nro_tarjeta     in ta_tarjetas.nro_tarjeta%type,
                                 p_fec_vencimiento in ta_tarjetas.fec_vencimiento%type,
                                 p_tip_embozado    in ta_tarjetas.tip_embozado%type,
                                 p_tip_producto    in varchar2,
                                 p_lin_credito     in ta_cta_tarjetas.lin_credito%type,
                                 p_embozado        in ta_tarjetas.nom_embozar%type,
                                 p_cod_moneda      in ta_cta_tarjetas.cod_moneda%type,
                                 p_nro_cta_ahorro  in ah_tar_debitos.nro_cuenta%type,
                                 p_plan_u           in varchar2,
                                 p_cod_error       out number,
                                 p_men_error       out varchar2) is

  v_cod_modulo      ta_cta_tarjetas.cod_modulo%type;
  v_cod_modalidad   ta_cta_tarjetas.cod_modalidad%type;
  v_cod_oficina     ta_cta_tarjetas.cod_oficina%type := fug_obt_ofi_matriz;
  v_afinidad        ta_cta_tarjetas.afinidad%type;
  v_sub_afinidad    ta_cta_tarjetas.sub_afinidad %type;
  v_tip_cierre      ta_cta_tarjetas.tip_cierre%type;
  v_fec_cierre      ta_cta_tarjetas.fec_ult_cierre%type;
  v_fec_vto_cierre  ta_cta_tarjetas.fec_vct_ult_cierre%type;
  v_fec_actual      ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(5);
  v_lugar           varchar2(40);
  v_nom_programa    varchar2(30):='PAT_TGL.PR_INS_DAT_TARJETAS';
  v_men_error       varchar2(4000):=nvl('Transaccion Exitosa!',fug_obt_pardinamico('DES_MSG_EXITO'));
  v_cod_error       number:=v_pro_correcto;

begin
  Begin 
    pre_ini_aplicacion; 
    pae_cnf.g_cod_modulo := 1; 
    execute immediate 'ALTER SESSION SET NLS_DATE_FORMAT = ''DD/MM/RRRR HH24:MI:SS''';
  end;
  savepoint inicio;
  --recuperamos datos del producto

  begin
  select ti.cod_modulo,
         ti.cod_modalidad,
         ti.afinidad,
         ti.sub_afinidad,
         ti.tip_cierre,
         cal.fec_cierre,
         cal.fec_vencimiento
    into
    v_cod_modulo,
    v_cod_modalidad,
    v_afinidad,
    v_sub_afinidad,
    v_tip_cierre,
    v_fec_cierre,
    v_fec_vto_cierre
    from (select distinct cod_modulo,
                               cod_modalidad,
                               afinidad,
                               sub_Afinidad,
                               tip_cierre,
                               ref_externa
                 from ta_tipos s
                where cod_ent_procesadora =
                      fug_obt_pardinamico('COD_ENT_GLOBAL')) ti,
              (SELECT c.fec_cierre,
                      c.fec_vencimiento,
                      cod_modalidad,
                      cod_tip_cierre
                 FROM ta_cal_cierres c
                WHERE c.cod_ent_procesadora =
                      fug_obt_pardinamico('COD_ENT_GLOBAL')
                  and fec_cierre >= sysdate
                  and fec_cierre <=
                      (select min(fec_cierre)
                         from ta_cal_cierres ta
                        where ta.cod_ent_procesadora =
                              fug_obt_pardinamico('COD_ENT_GLOBAL')
                          and ta.cod_modalidad = c.cod_modalidad
                          and ta.cod_tip_cierre = c.cod_tip_cierre
                          and fec_cierre >= sysdate)) cal
   where ti.cod_modalidad = cal.cod_modalidad
     and ti.tip_cierre = cal.cod_tip_cierre
     and ref_Externa = p_tip_producto;
     exception
       when others then
        v_lugar:='001';
        v_cod_error:=100;
        v_men_error := substr('Error al recuperar parametria del producto.'||
                       'Lugar:'||v_lugar||'-'||sqlerrm,1,4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
       end;

    if v_cod_error=v_pro_correcto then
         begin
          insert into ta_tar_global_tmp
            (nro_cuenta,
             cod_persona,
             nro_tarjeta,
             fec_vencimiento,
             tip_tarjeta,
             cod_producto,
             cod_estado)
          values
            (p_nro_cuenta,
             p_cod_persona,
             p_nro_tarjeta,
             p_fec_vencimiento,
             decode(p_tip_embozado,'MV',1,0),
             p_tip_producto,
             '0');
             exception
              when others then
              v_lugar     := '001';
              v_cod_error := 100;
              v_men_error := substr('Error al insertar en ta_tar_global_tmp.'||'Lugar:'||v_lugar||'-'||sqlerrm,1,4000);
              prg_ins_log_programas(v_nom_programa,
                                    v_men_error,
                                    p_cod_persona,
                                    p_nro_cuenta);
            end;
     end if;




      if v_cod_error=v_pro_correcto then
       begin
        insert into it.ta_cta_tarjetas
          (nro_cuenta,
           denominacion,
           cod_modulo,
           cod_modalidad,
           cod_oficina,
           cod_moneda,
           lin_credito,
           lin_cuotas,
           sal_facturar,
           sal_facturado,
           sal_financiado,
           sal_ult_extracto,
           sal_cuo_pendientes,
           mto_pag_minimo,
           sal_pag_minimo,
           mto_mora,
           dia_mora,
           mto_autorizaciones,
           mto_int_compras,
           mto_pag_mes,
           mto_gas_mora,
           estado,
           fec_solicitud,
           fec_apertura,
           fec_ult_cierre,
           fec_vct_ult_cierre,
           tip_cierre,
           tip_com_emision,
           tas_financiacion,
           tas_adelanto,
           tas_mora,
           tas_cuotas,
           deb_automatico,
           tip_cobro,
           nro_cta_debito,
           cat_automatica,
           fec_activacion,
           afinidad,
           sub_afinidad,
           cod_rub_economico,
           cod_tip_cierre,
           lin_especial,
           tas_especial,
           mto_car_suspendido,
           mto_car_sus_aplicado)
        values
          (p_nro_cuenta,
           p_embozado,
           v_cod_modulo,
           v_cod_modalidad,
           v_cod_oficina,
           p_cod_moneda,
           p_lin_credito,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           0,
           'N',
           v_fec_actual,
           v_fec_actual,
           v_fec_cierre,
           v_fec_vto_cierre,
           v_tip_cierre,
           0,
           0,
           0,
           0,
           0,
           'S',
           'M',
           p_nro_cta_ahorro,
           1,
           v_fec_actual,
           v_afinidad,
           v_sub_afinidad,
           '970107',
           v_tip_cierre,
           0,
           0,
           0,
           0
           );
      exception
        when others then
        v_lugar     := '003';
        v_cod_error := 102;
        v_men_error := substr('Error al insertar en ta_cta_tarjetas.'||'Lugar:'||v_lugar||'-'||sqlerrm,1,4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end;

      end if;

      if v_cod_error=v_pro_correcto then

      begin
        insert into it.ta_tarjetas
          (nro_cuenta,
           nro_tarjeta,
           cod_persona,
           cod_estado,
           fec_vencimiento,
           nom_embozar,
           vigente,
           fec_emision,
           fec_solicitud,
           tip_envio,
           referencia,
           fec_activacion,
           rel_tarjeta,
           tip_embozado,
           id_producto)
        values
          (p_nro_cuenta,
           p_nro_tarjeta,
           p_cod_persona,
           '6',
           p_fec_vencimiento,
           p_embozado,
           'S',
           sysdate,
           v_fec_actual,
           'R',
           '1',
           v_fec_actual,
           '0',
           p_tip_embozado,
     p_tip_producto);
      exception
        when others then
        v_lugar     := '004';
        v_cod_error := 103;
        v_men_error := substr('Error al insertar en ta_tarjetas.'||'Lugar:'||v_lugar||'-'||sqlerrm,1,4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end;
      end if;

        if v_cod_error=v_pro_correcto then
      begin
        insert into it.ge_cta_clientes
          (cod_persona,
           nro_cuenta,
           dig_verificador,
           cod_oficina,
           cod_modulo,
           cod_modalidad,
           relacion,
           est_relacion)
        values
          (p_cod_persona,
           p_nro_cuenta,
           0,
           v_cod_oficina,
           v_cod_modulo,
           v_cod_modalidad,
           'P',
           'A');

      exception
        when others then
        v_lugar     := '005';
        v_cod_error := 104;
        v_men_error := substr('Error al insertar en ge_cta_clientes!' ||
                       'Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end;
  end if;

   if v_cod_error=v_pro_correcto then
          BEGIN
            INSERT INTO ta_cta_garantias
              (nro_cuenta,
               nro_garantia,
               cod_garantia,
               mto_aplicado,
               mto_apl_computable)
            VALUES
              (p_nro_cuenta,
               null,
               1,
               p_lin_credito,
               0);
          EXCEPTION
            WHEN OTHERS THEN
              v_lugar     := '006';
              v_cod_error := 105;
              v_men_error := substr('Error al insertar garantias.' ||
                             'Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
              prg_ins_log_programas(v_nom_programa,
                                    v_men_error,
                                    p_cod_persona,
                                    p_nro_cuenta);
         END;
     end if;

  if v_cod_error=v_pro_correcto then
     begin
      insert into it.ge_cta_dat_adicionales
      (nro_cuenta,
       parametro,
       val_parametro)
      values
      (p_nro_cuenta,
       'COD_PRO_TDC_GLOBAL',
       p_tip_producto);
     exception
       when others then
         v_lugar     := '007';
         v_cod_error := 106;
         v_men_error := substr('Error al insertar COD_PRO_TDC_GLOBAL en ge_cta_dat_adicionales.' ||
                               'Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
        prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
     end;
     end if;

      if v_cod_error=v_pro_correcto and p_plan_u='S' then
         begin
            insert into it.ge_cta_dat_adicionales
                          (nro_cuenta,
                           parametro,
                           val_parametro)
                        values
                          (p_nro_cuenta, 'EST_CTA_GARANTIZADA', 'A');
         exception
           when others then
             v_lugar     := '008';
             v_cod_error := 107;
             v_men_error := substr('Error al insertar EST_CTA_GARANTIZADA en ge_cta_dat_adicionales.' ||
                                   'Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
            prg_ins_log_programas(v_nom_programa,
                                  v_men_error,
                                  p_cod_persona,
                                  p_nro_cuenta);
         end;
     end if;


    if v_cod_error != v_pro_correcto then
      prg_ins_log_programas(v_nom_programa,
                              'Lugar: ' || v_lugar || '- ' || v_cod_error ||
                             '#' || v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);
      rollback to inicio;
    else
      commit;
    end if;


p_cod_error:=v_cod_error;
p_men_error:=v_men_error;
exception
  when others then
          v_lugar     := '100';
          v_cod_error := v_err_sql;
          v_men_error := substr('Error en la insercion de datos de la tarjeta. ' ||v_men_error||
                         ' Lugar:'||v_lugar|| ' '||sqlerrm,1,4000);
          p_cod_error :=v_cod_error;
          p_men_error := v_men_error;
          prg_ins_log_programas(v_nom_programa,
                              v_men_error,
                              p_cod_persona,
                              p_nro_cuenta);

end;

END pat_tgl;
/
