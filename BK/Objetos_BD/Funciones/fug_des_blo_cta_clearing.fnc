create or replace function it.FUG_DES_BLO_CTA_CLEARING(p_nro_cuenta  in ah_cta_vistas.nro_cuenta%type,
                                                       p_tip_bloqueo in ge_est_cuentas.estado%type,
                                                       p_estado      in ge_est_cuentas.estado%type,
                                                       p_hora        in out varchar2)
  return varchar2 is
  v_respuesta     varchar2(4000) := 'OK';
  v_exi_bloqueo   varchar2(1) := 'N';
  v_fec_actual    ge_calendarios.fec_actual%type;
  v_hora          ge_movimientos.hora%type;
  v_cod_error     number := 0;
  v_horario       varchar2(1);
  v_es_mov_noc    varchar2(1);
  v_es_cta_noc    varchar2(1);
  v_fec_valor     ge_calendarios.fec_actual%type;
  v_nro_documento ge_bloqueos.nro_documento%type;
  v_secuencia     ge_movimientos.nro_secuencia%type := 0;
  v_cod_oficina   ge_cuentas.cod_oficina%type;
  v_cod_modulo    ge_cuentas.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_usu_cle       ba_usuarios.cod_usuario%type := fug_obt_pardinamico('USU_CLE_WEPA');
  r_gmovi         ge_movimientos%ROWTYPE;
  v_cod_moneda    ge_cuentas.cod_moneda%type;

  procedure lp_ver_horario(p_cod_ofi_origen in ba_oficinas.cod_oficina%type,
                           p_modulo         in ba_modulos.cod_modulo%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out number,
                           p_men_error      out varchar2) is
  
    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error  := 0;
    p_horario    := 'D'; -- dia normal
    p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(p_modulo);
  
    if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' then
      p_cod_error := '1070';
      p_men_error := 'Modulo en proceso de cierre';
    else
      if v_est_modulo = 2 then
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(p_modulo);
      else
        p_horario := 'N'; -- noche
        if v_est_modulo <> 1 then
          p_fec_actual := pag_cal.fu_obt_fec_habil(p_fec_actual + 1,
                                                   1,
                                                   p_cod_ofi_origen);
        end if;
        p_es_mov_noc := 'S'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'S'; -- solo para que llavee la cuenta nocturna
      end if;
    end if;
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_men_error := substr('lp_ver_horario' || ' ' ||
                            DBMS_UTILITY.format_error_backtrace || ' ' ||
                            DBMS_UTILITY.format_error_stack,
                            1,
                            4000);
    
  END lp_ver_horario;
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_hora       := nvl(p_hora,fug_ini_hora(SYSDATE, 'HH24:MI:SS'));
 begin
 select c.cod_oficina,c.cod_modulo,c.cod_modalidad, c.cod_moneda
  into v_cod_oficina,v_cod_modulo,v_cod_modalidad, v_cod_moneda
  from ge_cuentas c
  where nro_cuenta=p_nro_cuenta;
  exception
    when others then
       v_cod_error := 1;
       v_respuesta := substr(v_cod_error || ' Error al obtener datos de la cuenta ' || sqlerrm,
                              1,
                              4000);
 end;
  lp_ver_horario(v_cod_oficina,
                 v_cod_modulo,
                 v_horario,
                 v_es_mov_noc,
                 v_es_cta_noc,
                 v_fec_actual,
                 v_fec_valor,
                 v_cod_error,
                 v_respuesta);

  v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, v_usu_cle, v_es_mov_noc);
  pag_cta.pr_set_variables(v_usu_cle,
                           v_fec_valor,
                           306,
                           'N',
                           'N',
                           v_secuencia,
                           'T',
                           fug_obt_ofi_usuario(v_usu_cle),
                           v_cod_modulo,
                           v_cod_modalidad);

  if p_tip_bloqueo = 'B' then
    ---si es bloqueo
    --obtiene nro_documento para bloqueo
    begin
      select s_nro_bloqueo.nextval into v_nro_documento from dual;
    exception
      when others then
        v_cod_error := 2;
        v_respuesta := substr(v_cod_error || ' Sec. Bloqueo ' || sqlerrm,
                              1,
                              4000);
    end;
  end if;
  pag_cta.G_COD_ERROR:=null;
  pag_cta.G_MSJ_ERROR:=null;
  pag_cta.G_CTAS:=null;
  if nvl(v_cod_error, 0) = 0 then
    -- actualiza cuenta y genera los movimientos de cambio de estado
      if p_tip_bloqueo = 'B' then
          --Actualiza el estado de las Cuentas
        pag_cta.pr_act_est_cta(p_nro_cuenta,
                               v_cod_modalidad,
                               P_ESTADO,
                               v_fec_actual);

        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.cod_usuario     := v_usu_cle;
        -- aumento la secuencia
        v_secuencia             := v_secuencia + 1;
        r_gmovi.nro_secuencia   := v_secuencia;
        --
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := 306;
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.cod_transaccion := 410;
        r_gmovi.monto           := null;
        r_gmovi.nro_documento   := v_nro_documento;
        r_gmovi.cod_tasa        := null;
        r_gmovi.val_tasa        := null;
        r_gmovi.cotizacion      := null;
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Cambio de Estado';
        r_gmovi.est_cuenta      := p_estado;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        -- genero el movimiento por cambio de estado
        pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
          --inserta en ge_bloqueos
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
             v_nro_documento,
             v_fec_actual,
             v_hora,
             122,
             p_estado,
             'Bloqueo cuenta clearing wepa');
        EXCEPTION
          when others then
            v_respuesta := substr('Error al insertar en GE_BLOQUEOS- ' ||
                                  sqlerrm,
                                  1,
                                  4000);
            v_cod_error := 3;
        END;
      else
        PAG_CTA.PR_ACT_ESTADO(P_NRO_CUENTA,
                              P_ESTADO,
                              v_fec_actual,
                              v_hora,
                              v_nro_documento,
                              'S');
       if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
        --si es desbloqueo recupera el ultimo bloqueo tipo debito de la cuenta
        begin
          select 'S', s.nro_documento
            into v_exi_bloqueo, v_nro_documento
            from ge_bloqueos s
           where s.nro_cuenta = p_nro_cuenta
             and s.tipo = 'D'
             and s.fec_inicio = (select max(fec_inicio)
                                   from ge_bloqueos b
                                  where b.nro_cuenta = s.nro_cuenta
                                    and b.tipo = s.tipo);
        exception
          when no_data_found then
            v_exi_bloqueo := 'N';
          
          when others then
            v_exi_bloqueo := 'N';
            v_cod_error   := 4;
            v_respuesta   := substr(v_cod_error ||
                                    ' Error al verificar si la cuenta se encuentra bloqueada ' ||
                                    sqlerrm,
                                    1,
                                    4000);
        end;
      
        if nvl(v_exi_bloqueo, 'N') = 'S' then
          --borra registro en ge_bloqueo para la cuenta
          begin
            delete from ge_bloqueos s
             where s.nro_cuenta = p_nro_cuenta
               and s.nro_documento = v_nro_documento
               and s.tipo = 'D';
          exception
            when others then
              v_cod_error := 5;
              v_respuesta := substr(v_cod_error ||
                                    ' Error al intentar borrar bloqueo ' ||
                                    sqlerrm,
                                    1,
                                    4000);
          end;
        end if;
      
       else
        v_cod_error := 6;
        v_respuesta := substr(v_cod_error || ' ' || pag_cta.G_COD_ERROR || ' ' ||
                              pag_cta.G_MSJ_ERROR,
                              1,
                              4000);
       end if;
      end if;
  end if;
  if nvl(v_cod_error, 0) != 0 then
    it.prg_ins_log_programas('FUG_DES_BLO_CTA_CLEARING',
                             v_respuesta,
                             null,
                             p_nro_cuenta);
  else
    v_respuesta := 'OK';
    p_hora:=v_hora;
  end if;

  return(v_respuesta);
exception
  when others then
    v_cod_error := 99;
    v_respuesta := substr(v_cod_error ||
                          ' Error en el proceso de desbloqueo ' ||
                          DBMS_UTILITY.format_error_backtrace || ' ' ||
                          DBMS_UTILITY.format_error_stack,
                          1,
                          4000);
    it.prg_ins_log_programas('FUG_DES_BLO_CTA_CLEARING',
                             v_respuesta,
                             null,
                             p_nro_cuenta);
    return(v_respuesta);
end;
/

