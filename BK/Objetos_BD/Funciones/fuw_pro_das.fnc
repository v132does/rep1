create or replace function it.fuw_pro_das(p_cod_per_empresa ba_personas.cod_persona%type,
                                          p_nro_cta_empresa ge_cuentas.nro_cuenta%type,
                                          p_tip_documento   Ba_Personas.Cod_Tip_Documento%type,
                                          p_nro_documento   ba_personas.nro_documento%type,
                                          p_nro_cta_cliente ge_cuentas.nro_cuenta%type,
                                          p_monto           number,
                                          p_nro_cuota       number,
                                          p_desc_plan       varchar2,
                                          p_id_plan         ge_movimientos.nro_documento2%type,
                                          p_id_cobro        ge_movimientos.nro_documento3%type)
  return CLOB IS

  v_cod_per_cliente ge_cta_clientes.cod_persona%type;
  r_cue_emp         ge_cuentas%rowtype;
  r_cue_cli         ge_cuentas%rowtype;
  r_mov_cre         ge_movimientos%rowtype;
  r_mov_com         ge_movimientos%rowtype;
  --Para los errores
  v_error         VARCHAR2(1) := 'N';
  v_cod_respuesta VARCHAR2(50) := 'OK';
  v_des_respuesta VARCHAR2(1000) := 'Operacion realizada con exito';
  --Variables para setear var glo de pag_cta y para act operacion
  v_cod_usuario    ge_movimientos.cod_usuario%TYPE;
  v_cod_ofi_origen ge_movimientos.cod_ofi_origen%type ;
  v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE;
  v_fec_valor      DATE := trunc(sysdate);
  v_fec_proceso    date;
  v_hor_actual     VARCHAR2(08) := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
  v_mto_debcom     NUMBER(18, 2);
  --Para la verificacion del debito
  v_procesa        VARCHAR2(1) := 'N';
  v_sal_disponible NUMBER(18, 2);
  -- Transacciones a ser utilizadas
  v_cod_ente             ge_entes.cod_ente%type;
  V_COD_MAD_PADRE_DAS    ge_par_dinamicos.val_parametro%type;
  V_COD_MOD_PADRE_DAS    ge_par_dinamicos.val_parametro%type;
  V_COD_TRA_PADRE_DAS    ge_par_dinamicos.val_parametro%type;
  V_COD_TRA_DEB_DAS      ge_par_dinamicos.val_parametro%type;
  V_COD_TRA_CRE_DAS      ge_par_dinamicos.val_parametro%type;
  V_COD_TRA_DEBCOM_DAS   ge_par_dinamicos.val_parametro%type;
  V_VAL_TASA             number(18,6);
  V_COD_TASA             ge_tasas.cod_tasa%type;
  v_ci                   varchar2(15);
  v_nombre               varchar2(70);
  v_cuota                varchar2(10);

  FUNCTION fu_obt_men_response(p_error         varchar2,
                               p_cod_respuesta varchar2,
                               p_des_respuesta varchar2,
                               rv_mov_cre      ge_movimientos%rowtype default null,
                               rv_mov_com      ge_movimientos%rowtype default null,
                               p_comision      ge_movimientos.monto%type default null) RETURN CLOB IS
    v_respon json_object_t := JSON_OBJECT_T();
  BEGIN
    v_respon.put('error', p_error);
    v_respon.put('nombreRespuesta', p_cod_respuesta);
    v_respon.put('descripcionRespuesta', p_des_respuesta);
    --en el caso que no le pasemos los datos a la funcion, el mismo registra null para los campos
    v_respon.put('fechaMovCre',  to_char(rv_mov_cre.fecha, 'dd/mm/yyyy'));
    v_respon.put('horaMovCre',   rv_mov_cre.hora);
    v_respon.put('codUsuMovCre', rv_mov_cre.cod_usuario);
    v_respon.put('nroSecMovCre', rv_mov_cre.nro_secuencia);

    v_respon.put('fechaMovCom',  to_char(rv_mov_com.fecha, 'dd/mm/yyyy'));
    v_respon.put('horaMovCom',   rv_mov_com.hora);
    v_respon.put('codUsuMovCom', rv_mov_com.cod_usuario);
    v_respon.put('nroSecMovCom', rv_mov_com.nro_secuencia);
    v_respon.put('mtoComision', p_comision);
    
    if nvl(p_error, 'N') = 'S' then
      rollback;
    end if;
    
    RETURN v_respon.To_Clob;
  END;

  procedure lp_val_cta_cli(p_cod_per  ge_cta_clientes.cod_persona%type,
                           pv_nro_cta ge_cuentas.nro_cuenta%type,
                           p_dato     varchar2,
                           p_error    in out varchar2) is
    v_existe varchar2(1);
  begin
    --Buscamos si el cod. cli tiene alguna relacion con el número de cuenta
    select 'S'
      into v_existe
      from ge_cta_clientes c
     where
    --filtramos por la pk
     c.cod_persona = p_cod_per
     and c.nro_cuenta = pv_nro_cta;
    p_error := 'N';
  exception
    when no_data_found then
      v_error         := 'S';
      v_cod_respuesta := 'NRO_CTA_NO_REL';
      v_des_respuesta := p_dato || ' - ' || 'El nro. de cuenta ' ||
                         pv_nro_cta ||
                         ' no tiene ninguna relación con el código ' ||
                         p_cod_per;
      p_error         := 'S';
    
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_BUS_REL';
      v_des_respuesta := p_dato || ' - ' || 'Error al validar la cuenta ' ||
                         pv_nro_cta || ' ' || sqlerrm;
      p_error         := 'S';
    
  end;

  function lf_obt_dat_cue(pv_nro_cue ge_cuentas.nro_cuenta%type,
                          p_dato     varchar2,
                          p_error    in out varchar2)
    return ge_cuentas%rowtype is
    vr_cue ge_cuentas%rowtype;
  begin
    select c.*
      into vr_cue
      from ge_cuentas c
     where c.nro_cuenta = pv_nro_cue;
    p_error := 'N';
    return vr_cue;
  exception
    when no_data_found then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_NO_FOUND_DAR_CUE';
      v_des_respuesta := p_dato || ' - ' ||
                         'No se encontró datos de la cuenta ' || pv_nro_cue || ' ' ||
                         sqlerrm;
      p_error         := 'S';
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OBT_DAT_CUE';
      v_des_respuesta := p_dato || ' - ' ||
                         'Error al obtener los datos de la cueta ' ||
                         pv_nro_cue || ' ' || sqlerrm;
      p_error         := 'S';
  end;
  
  FUNCTION fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia('S_SER_AISEDAS');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
    return v_user;
  EXCEPTION
    WHEN OTHERS THEN
      null;
  END;
  
  FUNCTION fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    if instr(p_cod_usuario, '_', 1) = 0 then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, instr(p_cod_usuario, '_', 1) + 1, 1);
    end if;

    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_mov' /*||'_'*/|| v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_mov');
    end if;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'No se puede obtener la hora del movimiento. ' || sqlerrm);
  END;
  
  FUNCTION lf_es_conjunta(p_numeroCuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_can_conjunta NUMBER;

   BEGIN
      -- veo si la cuenta no es conjunta
      SELECT COUNT(*)
        INTO v_can_conjunta
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_numeroCuenta
         AND relacion = 'Y'
             AND rownum = 1;
      IF v_can_conjunta > 0  THEN
         /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;
   
begin
  begin
    --buscamos el cod ente
    select c.cod_ente
      into v_cod_ente
      from ge_entes c
     where c.cod_persona = p_cod_per_empresa
       and c.tipo = 'DA'
       and rownum = 1;
       
       --Verificamos si el esta activo
       if nvl(fug_obt_parentes(P_COD_ENTE => v_cod_ente, P_CAMPO => 'SER_ACTIVO_DAS' ), 'N') != 'S' then
         v_error         := 'S';
         v_cod_respuesta := 'ENT_NO_ACT';
         v_des_respuesta := 'El ente no se encuentra activo para este servicio';
         return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
       end if;
       
       if nvl(fug_obt_parentes(P_COD_ENTE => v_cod_ente, P_CAMPO => 'TIENE_CON_DAS' ), 'N') != 'S' then
         v_error         := 'S';
         v_cod_respuesta := 'ENT_NO_TIE_CON';
         v_des_respuesta := 'El ente no cuenta con contrato';
         return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
       end if;
  
  exception
    when no_data_found then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_NO_FOUND_ENTE';
      v_des_respuesta := 'No se encontró ente para ' || p_cod_per_empresa || ' ' ||
                         sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OBT_ENTE';
      v_des_respuesta := 'Error al obtener el ente ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;


  begin
    --buscamos el codigo de persona del cliente
    v_cod_per_cliente := FUE_OBT_COD_PERSONA_DOC(P_COD_TIP_DOCUMENTO => p_tip_documento,
                                                 P_NRO_DOCUMENTO     => p_nro_documento);
    if v_cod_per_cliente is null then
      v_error         := 'S';
      v_cod_respuesta := 'NRO_DOC_INVALIDO';
      v_des_respuesta := 'Número de documento invalido';
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_BUS_COD_CLI';
      v_des_respuesta := 'Error al buscar el cod. cli ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;

  declare
    v_er varchar2(1);
  begin
    --Buscamos relación entre la cuenta cliente y cod_cliente
    lp_val_cta_cli(v_cod_per_cliente, p_nro_cta_cliente, 'CLIENTE', v_er);
    if nvl(v_er, 'N') = 'S' then
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  end;

  declare
    v_er varchar2(1);
  begin
    --Buscamos relación entre la cuenta empresa y el cod_per_juridica
    lp_val_cta_cli(p_cod_per_empresa, p_nro_cta_empresa, 'EMPRESA', v_er);
    if nvl(v_er, 'N') = 'S' then
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  end;
  
  begin
    if nvl(lf_es_conjunta(p_nro_cta_cliente), 'N') = 'S' then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_CTA_CONJUNTA';
      v_des_respuesta := 'Servicio no disponible para cuentas conjuntas';
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  end;

  declare
    v_er varchar2(1);
  begin
    --Buscamos los datos de la cuenta del cliente
    r_cue_cli := lf_obt_dat_cue(p_nro_cta_cliente, 'CLIENTE', v_er);
    if nvl(v_er, 'N') = 'S' then
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  end;

  declare
    v_er varchar2(1);
  begin
    --Buscamos los datos de la cuenta de la empresa
    r_cue_emp := lf_obt_dat_cue(p_nro_cta_empresa, 'EMPRESA', v_er);
    if nvl(v_er, 'N') = 'S' then
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    end if;
  end;

    begin
      select trim(regexp_substr(p_desc_plan, '[^|]+', 1, 1)) as,
             trim(regexp_substr(p_desc_plan, '[^|]+', 1, 2)) as,
             trim(regexp_substr(p_desc_plan, '[^|]+', 1, 3)) as
        into v_ci, v_nombre, v_cuota
        from dual;
    end;

  begin
    --inicializamos par
    V_COD_MAD_PADRE_DAS    := fug_obt_pardinamico('COD_MAD_PADRE_DAS' );
    V_COD_MOD_PADRE_DAS    := fug_obt_pardinamico('COD_MOD_PADRE_DAS');
    V_COD_TRA_PADRE_DAS    := fug_obt_pardinamico('COD_TRA_PADRE_DAS');
    V_COD_TRA_DEB_DAS      := fug_obt_pardinamico('COD_TRA_DEB_DAS',r_cue_cli.cod_modulo, r_cue_cli.cod_modalidad);
    V_COD_TRA_CRE_DAS      := fug_obt_pardinamico('COD_TRA_CRE_DAS',r_cue_emp.cod_modulo, r_cue_emp.cod_modalidad);
    V_COD_TRA_DEBCOM_DAS   := fug_obt_pardinamico('COD_TRA_DEBCOM_DAS',r_cue_emp.cod_modulo, r_cue_emp.cod_modalidad);
    v_fec_proceso          := pag_cal.FU_OBT_FEC_ACTUAL(V_COD_MOD_PADRE_DAS);
    V_COD_TASA             := nvl(fug_obt_parentes(P_COD_ENTE => v_cod_ente , P_CAMPO => 'TASA_DEBCOM_DAS' ), '404');
    V_VAL_TASA             := fug_obt_val_tasa(P_COD_MODULO        => null,
                                               P_COD_MODALIDAD     => null,
                                               P_COD_OFICINA       => null,
                                               P_NRO_CUENTA        => null,
                                               P_COD_MONEDA        => null,
                                               P_MTO_TRANSACCION   => null,
                                               P_TAS_PERSONALIZADA => null,
                                               P_COD_TASA          => V_COD_TASA,
                                               P_COD_TRANSACCION   => null,
                                               P_FEC_FINAL         => v_fec_proceso);
    
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OBT_PARDINAMICO';
      v_des_respuesta := 'Error al buscar par dinamicos ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  
  begin
    --inicializamos usuario y hora
    v_cod_usuario := fu_obt_mov_user('AISEDAS');
    v_hor_actual  := fu_obt_hora(v_cod_usuario);
    v_cod_ofi_origen := fug_obt_ofi_usuario(v_cod_usuario);
  end;

  declare
    v_cod_mod    ge_cuentas.cod_modulo%type;
    v_cod_mad    ge_cuentas.cod_modalidad%type;
    v_nvo_estado VARCHAR2(1) := NULL;
  begin
    -- verificacion operacion debito
    pag_cta.pr_ver_operacion(r_cue_cli.nro_cuenta,
                             V_COD_TRA_PADRE_DAS,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS,
                             'D',
                             r_cue_cli.cod_moneda,
                             p_monto,
                             v_cod_ofi_origen,
                             v_cod_mod, --se completa dentro del procedure
                             v_cod_mad, --se completa dentro del procedure
                             v_nvo_estado,
                             v_sal_disponible,
                             v_procesa,
                             V_COD_TRA_DEB_DAS);
    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
      v_error         := 'S';
      v_cod_respuesta := 'ERR_VER_OPE_DEB';
      v_des_respuesta := 'No se puede debitar ' || p_monto || ' de ' ||
                         r_cue_cli.nro_cuenta || '. ' ||
                         pag_cta.g_msj_error;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    END IF;
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_VERIFICAR_DEB';
      v_des_respuesta := 'Erro al validar operación de debito ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  


  begin
    --Seteamos antes de llamar a actualiza operacion
    pag_cta.pr_set_variables(v_cod_usuario,
                             v_fec_valor,
                             V_COD_TRA_PADRE_DAS,
                             'N',
                             'N',
                             v_nro_secuencia,
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS);
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_SET_VAR_1';
      v_des_respuesta := 'Error al setear la variables globales ' ||
                         sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  

  begin
    v_nro_secuencia := 0;
    pag_cta.pr_set_nro_documento2(p_id_plan);
    pag_cta.pr_set_nro_documento3(p_id_cobro);
    -- procesar debito
    pag_cta.pr_act_operacion(r_cue_cli.nro_cuenta,
                             v_hor_actual,
                             'D',
                             r_cue_cli.cod_moneda,
                             p_monto,
                             V_COD_TRA_PADRE_DAS,
                             V_COD_TRA_DEB_DAS,
                             r_cue_emp.nro_cuenta, --numero de documento
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS,
                             NULL,
                             NULL,
                             SUBSTR('Deb. Automatico-Cobro-CI ' || v_ci ||' - '|| v_cuota, 1,100),
                             'N',
                             v_nro_secuencia,
                             v_fec_valor);
  
    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPE_DEB';
      v_des_respuesta := 'No se puede debitar ' || p_monto || ' de ' ||
                         r_cue_cli.nro_cuenta || '. ' ||
                         pag_cta.g_msj_error;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    END IF;
  
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPERACION_DEB';
      v_des_respuesta := 'Erro inesperado en el deb. ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;

  begin
    --Seteamos antes de llamar a actualiza operacion
    pag_cta.pr_set_variables(v_cod_usuario,
                             v_fec_valor,
                             V_COD_TRA_PADRE_DAS,
                             'N',
                             'N',
                             v_nro_secuencia,
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS);
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_SET_VAR_2';
      v_des_respuesta := 'Error al setear la variables globales ' ||
                         sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;

  begin
    pag_cta.pr_set_nro_documento2(p_id_plan);
    pag_cta.pr_set_nro_documento3(p_id_cobro);
    --Bloque Credito
    pag_cta.pr_act_operacion(r_cue_emp.nro_cuenta,
                             v_hor_actual,
                             'C',
                             r_cue_emp.cod_moneda,
                             p_monto,
                             V_COD_TRA_PADRE_DAS,
                             V_COD_TRA_CRE_DAS,
                             r_cue_emp.nro_cuenta,
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS,
                             NULL,
                             NULL,
                             SUBSTR('Deb. Automatico-' || v_nombre ||'-'|| v_cuota, 1,100),
                             'N',
                             v_nro_secuencia,
                             v_fec_valor);
    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPE_CRE';
      v_des_respuesta := 'No se puede acreditar ' || p_monto || ' a la  ' ||
                         r_cue_emp.nro_cuenta || '. ' ||
                         pag_cta.g_msj_error;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    END IF;
    --Si no salto error
    select c.* 
    into r_mov_cre
    from ge_movimientos c 
    where c.fecha = v_fec_proceso 
    and c.hora = v_hor_actual 
    and c.cod_usuario   = v_cod_usuario
    and c.nro_secuencia = v_nro_secuencia;
  exception
    when others then
      r_mov_cre       := null;
      r_mov_com       := null;
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPERACION_CRE';
      v_des_respuesta := 'Erro inesperado en el cre. ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  
  begin
    --Seteamos antes de llamar a actualiza operacion
    pag_cta.pr_set_variables(v_cod_usuario,
                             v_fec_valor,
                             V_COD_TRA_PADRE_DAS,
                             'N',
                             'N',
                             v_nro_secuencia,
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS);
  exception
    when others then
      v_error         := 'S';
      v_cod_respuesta := 'ERR_SET_VAR_2';
      v_des_respuesta := 'Error al setear la variables globales ' ||
                         sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  
  declare
    v_por_impuesto             NUMBER;
    v_redondeo                 NUMBER;
  begin
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cue_emp.cod_modulo,r_cue_emp.cod_modalidad,r_cue_emp.cod_moneda);
    --primero debemos de buscar el porcentaje iva  
    v_por_impuesto := fug_obt_val_tasa(null,null,
                                       null,null,r_cue_emp.cod_moneda,null,
                                       'N',323,null,v_fec_proceso);
    --Calculos para hallar el monto de la comision
    v_mto_debcom := round(p_monto *(V_VAL_TASA/100), v_redondeo);
    --tiene que ser la comisionmás iva
    v_mto_debcom := v_mto_debcom + Round(((v_mto_debcom*v_por_impuesto)/100),v_redondeo);
  end;
  
  begin
    pag_cta.pr_set_nro_documento2(p_id_plan);
    pag_cta.pr_set_nro_documento3(p_id_cobro);
    --Bloque Comision
    pag_cta.pr_act_operacion(r_cue_emp.nro_cuenta,
                             v_hor_actual,
                             'D',
                             r_cue_emp.cod_moneda,
                             v_mto_debcom,
                             V_COD_TRA_PADRE_DAS,
                             V_COD_TRA_DEBCOM_DAS, -- Mientras que nos crean la tansaccion por comision
                             r_cue_emp.nro_cuenta,
                             NULL,
                             v_cod_ofi_origen,
                             V_COD_MOD_PADRE_DAS,
                             V_COD_MAD_PADRE_DAS,
                             NULL,
                             NULL,
                             SUBSTR('Deb. Automatico-Comision-CI ' || v_ci ||' - '|| v_cuota, 1,100),
                             'N',
                             v_nro_secuencia,
                             v_fec_valor);
    IF pag_cta.g_cod_error <> 0 OR v_procesa = 'N' THEN
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPE_CRE';
      v_des_respuesta := 'No se puede deb por comision ' || p_monto || ' a la  ' ||
                         r_cue_emp.nro_cuenta || '. ' ||
                         pag_cta.g_msj_error;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
    END IF;
    --Si no salto error
    select c.* 
    into r_mov_com
    from ge_movimientos c 
    where c.fecha = v_fec_proceso 
    and c.hora = v_hor_actual 
    and c.cod_usuario   = v_cod_usuario
    and c.nro_secuencia = v_nro_secuencia;
  exception
    when others then
      r_mov_cre       := null;
      r_mov_com       := null;
      v_error         := 'S';
      v_cod_respuesta := 'ERR_OPERACION_COM';
      v_des_respuesta := 'Erro inesperado en el deb. por comisión ' || sqlerrm;
      return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  end;
  
  
  begin
    v_error         := 'N';
    v_cod_respuesta := 'OK';
    v_des_respuesta := 'Operacion realizada con exito';
    return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta, r_mov_cre, r_mov_com, v_mto_debcom);
  end;

exception
  when others then
    v_error         := 'S';
    v_cod_respuesta := 'ERR_INESPERADO';
    v_des_respuesta := 'Erro inesperado ' || sqlerrm;
    return fu_obt_men_response(v_error, v_cod_respuesta, v_des_respuesta);
  
end;
/
