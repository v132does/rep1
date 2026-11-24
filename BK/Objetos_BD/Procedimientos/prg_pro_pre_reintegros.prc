create or replace procedure it.prg_pro_pre_reintegros (p_nro_cuenta        in varchar2,
                                                       p_operacion         in varchar2, -- Valores Posibles TD -> Tarjeta Debito, TC -> Tarjecta Credito y QR -> compra por medio de codigo QR
                                                       p_mon_moneda        in varchar2,
                                                       p_mon_valor         in number,
                                                       p_cod_tra_operacion in varchar2,
                                                       p_nro_documento3    in varchar2,
                                                       p_id_reintegro      in varchar2,
                                                       p_rei_descripcion   IN varchar2) is
                                                       
 v_fec_actual      date := pag_cal.fu_obt_fec_actual(3);
 v_fec_valor       date := trunc(sysdate);
 v_hora            varchar2(8) := to_char(sysdate,'hh24:mi:ss');
 v_horario         varchar2(1) := 'D';
 v_nocturno        varchar2(1) := 'N';
 v_nro_cuenta      ge_cuentas.nro_cuenta%type;
 v_cod_moneda      ba_monedas.cod_moneda%type;
 v_mto_reintegro   number; 
 v_cod_tra_padre   ge_transacciones.cod_transaccion%type;
 v_reversar        varchar2(1) := 'N';
 v_est_modulo      ba_modulos.estado%TYPE;
 v_cod_comercio    ge_com_adheridos.cod_comercio%type;
 v_error           exception;                  
 v_procesa         varchar2(1);
 v_cod_mod_padre   ge_movimientos.cod_mod_padre%type;
 v_cod_mad_padre   ge_movimientos.cod_mad_padre%type;
 v_nvo_estado      ah_cta_vistas.estado%type;
 v_sal_disponible  number;
 v_cod_transaccion ge_movimientos.cod_transaccion%type;
 v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := 0;
 v_operacion       varchar2(3);
 v_cod_persona     ba_personas.cod_persona%type;
 v_msg_error       varchar2(4000);
 v_cod_error       varchar2(4000);
 v_men_error       varchar2(4000);
 v_cod_modulo      ba_modulos.cod_modulo%type;
 v_usu_movimiento  ba_usuarios.cod_usuario%type;
 
  procedure pr_obt_usu_hor_tra_interna(p_usuario in varchar2,
                                       p_usu_mov out varchar2) is
    v_usu_movimiento   ba_cod_referencias.val_maximo%type;
    v_val_minimo       ge_par_dinamicos.val_parametro%type;
    v_val_maximo       ge_par_dinamicos.val_parametro%type;
    v_par_minimo       ge_parametros.parametro%type;
    v_par_maximo       ge_parametros.parametro%type;
    v_can_registro     number(5) := 0;
  
  begin
  
    v_usu_movimiento := FUE_OBT_VAL_MAX_REFERENCIA('USU_BEN_INTERNA', p_usuario);
    
    --se obtiene el nombre de los parametros de la cant. minima y maxima
    v_par_minimo := v_usu_movimiento || '_CAN_MIN_USU';
    v_par_maximo := v_usu_movimiento || '_CAN_MAX_USU';
    
    --se obtiene el valor minimo y maximo para la generacion de usuarios y secuencias
    v_val_minimo := nvl(fug_obt_pardinamico(v_par_minimo), 1);
    v_val_maximo := nvl(fug_obt_pardinamico(v_par_maximo), 20);
  
    ---se obtiene el usuario
    p_usu_mov := v_usu_movimiento || round(dbms_random.value(v_val_minimo, v_val_maximo));
    
    --se valida si el usuario esta registrado en ba_usuarios
    select count(*)
      into v_can_registro
      from ba_usuarios us
     where us.cod_usuario = p_usu_mov;
  
    if v_can_registro = 0 then
      p_usu_mov := p_usuario;
      return;
    end if;
  exception
    when others then
      p_usu_mov := p_usuario;
  end pr_obt_usu_hor_tra_interna;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  
  v_msg_error     := null;
  v_cod_error     := null;
  v_men_error     := null;
  v_nro_cuenta    := p_nro_cuenta;
  v_cod_moneda    := p_mon_moneda;
  v_mto_reintegro := p_mon_valor;
  v_cod_tra_padre := p_cod_tra_operacion;
  v_operacion     := upper(p_operacion);
  v_nro_secuencia := 0;
  v_horario       := 'D';
  v_est_modulo    := pae_cnf.fu_obt_est_modulo(3);
  
  if v_est_modulo != 2 then
    v_horario  := 'N';
    v_nocturno := 'S';
  else
    v_horario  := 'D';
    v_nocturno :='N';
  end if;
  
  pag_cta.g_horario := v_horario;
  if v_operacion = 'TC' then
    /**
      Obtenemos el cod_persona del cliente de la TC
    **/
    begin
      select a.cod_persona, a.cod_modulo
        into v_cod_persona, v_cod_modulo
        from ge_cta_clientes a, ba_personas b
       where a.cod_persona = b.cod_persona
         and a.nro_cuenta = p_nro_cuenta
         and a.relacion = 'P';
    exception 
      when others then
        v_msg_error := 'Error al buscar la persona de la cuenta '||p_nro_cuenta;
        raise v_error;
    end;
   
  /**
    buscamos la cuenta de configurada para realizar el reintegro
  **/
    v_nro_cuenta := p_nro_cuenta;
    if v_cod_modulo = 5 then
      begin
        select max(cli.nro_cuenta)
            into v_nro_cuenta
          from ge_cta_clientes cli, ah_cta_vistas a, ba_personas c
          where cli.cod_persona = v_cod_persona
            and cli.relacion = 'P'
            and a.nro_cuenta = cli.nro_cuenta
            and cli.cod_persona = c.cod_persona
            and a.estado in ('N','A','D','I')
            and a.cod_moneda = pag_gen.fu_obt_mon_local
            AND c.tipo != 'J'; -- Filtra cuentas de personas juridicas
      exception
        when others then
          v_msg_error := 'Error al buscar la cuenta '||p_nro_cuenta||' de acreditacion para la persona '||v_cod_persona;
          prg_ins_log_errores('prg_pro_pre_reintegros',v_msg_error,'NUMERO_CUENTA', p_nro_cuenta,'FEC_VALOR', v_fec_valor, 'COD_PERSONA', v_cod_persona);
          raise v_error;
      end;
    end if;
  end if;
  
  if nvl(v_reversar,'N') = 'N' then
  ------------- agregado el 30/07/2024 ---------------
    pag_cta.pr_obt_cuenta(v_nro_cuenta );
  ----------------------------------------------------------
    pr_obt_usu_hor_tra_interna(user,v_usu_movimiento);
    v_hora  := fug_obt_hor_disponible (v_fec_actual, v_hora, v_usu_movimiento, v_nocturno);
    pag_cta.PR_SET_VARIABLES(v_usu_movimiento,
                            v_fec_actual,
                            v_cod_tra_padre,
                            'N',
                            'N',
                            v_nro_secuencia);
    pag_cta.pr_set_nro_documento3(substr(p_nro_documento3,1,15));
    pag_cta.pr_act_operacion (v_nro_cuenta,
                              v_hora,
                              'C',
                              v_cod_moneda,
                              v_mto_reintegro,
                              v_cod_tra_padre,
                              v_cod_tra_padre,
                              v_cod_comercio,
                              null,
                              pag_cta.g_ctas.cod_oficina,
                              pag_cta.g_ctas.cod_modulo,
                              pag_cta.g_ctas.cod_modalidad,
                              null,
                              null,
                              'REINTEGRO PAGO '||p_rei_descripcion,
                              'S',
                              v_nro_secuencia,
                              v_fec_valor);
    if pag_cta.fu_obt_cod_error() <> 0 then
        v_cod_error := pag_cta.fu_obt_cod_error;
        v_men_error := pag_cta.fu_obt_msj_error;
        v_msg_error := 'Error al realizar el reintegro. Datos: '||'#'||v_fec_valor||'#'||v_hora||'#'||user||'#'||v_nro_cuenta||'#'||v_cod_persona||'Error codigo pag_cta: '||v_cod_error||'Error mensaje pag_cta: '||v_men_error;
        raise v_error;
    end if;
  else
    pag_cta.pr_ver_operacion (v_nro_cuenta,
                              v_cod_tra_padre,
                              v_cod_mod_padre,
                              v_cod_mad_padre,
                              'D',
                              v_cod_moneda,
                              v_mto_reintegro,
                              pag_cta.g_ctas.cod_oficina,
                              pag_cta.g_ctas.cod_modulo,
                              pag_cta.g_ctas.cod_modalidad,
                              v_nvo_estado,
                              v_sal_disponible,
                              v_procesa,
                              v_cod_transaccion);
    v_reversar := v_procesa;
    if nvl(v_reversar,'N') = 'S' then
      begin 
        prg_rev_operacion (v_fec_valor,
                           v_hora,
                           user,
                           v_cod_mod_padre, 
                           v_cod_mad_padre,
                           v_cod_tra_padre,
                           user, 
                           v_hora, 
                           'N', 
                           'Rev.Reintegro');
      exception
        when others then
          v_msg_error := 'Error al realizar la reversion. Datos: '||'#'||v_fec_valor||'#'||v_hora||'#'||user||'#'||v_cod_mod_padre||'#'||v_cod_mad_padre||'#'||v_cod_tra_padre||'#'||user||'#'||v_hora;
          prg_ins_log_errores('prg_pro_pre_reintegros',v_msg_error,'USER', user,'FEC_VALOR', v_fec_valor, 'OPERACION', v_operacion);
          raise v_error;
      end;      
    end if;
  end if;
  begin
    INSERT INTO IT.GE_REI_BENEFICIOS (ID_REINTEGRO, TIP_OPERACION) VALUES(p_id_reintegro, v_operacion);
  exception
    when others then
        v_msg_error := 'Error al realizar la ingesta en la tabla de reintegros. Datos: '||'#'||p_id_reintegro||'#'||v_operacion;
        prg_ins_log_errores('prg_pro_pre_reintegros',v_msg_error,'ID_REINTEGRO', p_id_reintegro, 'TIP_OPERACION', v_operacion, 'FEC_VALOR', v_fec_valor);
        raise v_error;
  end;  
 exception
   when v_error then
        raise_application_error(-20000,v_msg_error||' - '||sqlerrm);
   when others then
        raise_application_error(-20001,'Error desconocido. - '||sqlerrm);
end;
/