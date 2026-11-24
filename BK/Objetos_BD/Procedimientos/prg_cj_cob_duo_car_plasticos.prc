create or replace procedure it.prg_cj_cob_duo_car_plasticos(p_nro_telefono in ba_telefonos.telefono%type,
                                                              p_cod_persona  in ba_personas.cod_persona%type,
                                                              p_nro_cuenta   in ge_cta_clientes.nro_cuenta%type,
                                                              p_monto        in ge_movimientos.monto%type,
                                                              p_cobro        out varchar2,
                                                              p_motivo       out varchar2) is
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(3);
  v_hora               varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
  v_nro_secuencia      ge_movimientos.nro_secuencia%type := 0;
  v_cod_tra_padre      ge_transacciones.cod_transaccion%type;
  v_horario            varchar2(1) := 'D';
  v_est_modulo         ba_modulos.estado%type;
  v_es_nocturno        varchar2(1) := 'N';
  v_cod_mon_local      ba_monedas.cod_moneda%type;
  v_cod_moneda         ba_monedas.cod_moneda%type;
  r_gmovi              ge_movimientos%rowtype;
  v_cod_modulo         ah_cta_vistas.cod_modulo%type;
  v_cod_modalidad      ah_cta_vistas.cod_modalidad%type;
  v_cod_oficina        ah_cta_vistas.cod_oficina%type;
  v_estado             ah_cta_vistas.estado%type;
  v_est_batch          ah_cta_vistas.est_batch%type;
  v_tie_fondo          ah_cta_vistas.sal_total%type := 0;
  v_exi_persona        varchar2(1);
  v_exi_cuenta         varchar2(1);
  v_nro_cuenta         ge_cta_clientes.nro_cuenta%type;
  v_tip_capitalizacion ah_cta_vistas.tip_capitalizacion%type;
  v_cod_tasa           ah_cta_vistas.cod_tasa%type;
  v_val_tasa           ge_tas_fechas.val_tasa%type;
  v_piz_tasa_min       ge_tas_fechas.val_minimo%type;
  v_piz_tasa_max       ge_tas_fechas.val_maximo%type;
  v_piz_tasa_actual    ge_tas_fechas.val_tasa%type;
  v_cod_error          number(10);
  v_cobro              varchar2(1);
  v_motivo             varchar2(4000);
  v_rel_pers_cuenta    varchar2(1);
  v_fec_vigencia       ge_tas_fechas.fec_vigencia%type;
  v_tip_valor          ge_tasas.tip_valor%type;
  v_tip_tasa           ge_tasas.tipo%type;
  v_cod_mod_ahorros    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_MAD_COB_PLASTICOS');

begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  /***validaciones de parametros***/
  if p_nro_telefono is null then
    v_cod_error := 1;
    p_cobro     := 'N';
    p_motivo    := 'Numero de telefono no puede ser nulo';
    return;
  end if;
  if p_cod_persona is null then
    v_cod_error := 2;
    p_cobro     := 'N';
    p_motivo    := 'Codigo de persona no puede ser nulo';
    return;
  end if;
  if p_nro_cuenta is null then
    v_cod_error := 3;
    p_cobro     := 'N';
    p_motivo    := 'Numero de cuenta no puede ser nulo';
    return;
  end if;
  if p_monto is null then
    v_cod_error := 4;
    p_cobro     := 'N';
    p_motivo    := 'El monto a debitar no puede ser nulo';
    return;
  end if;
  /***validaciones de datos***/
  --verifica la persona
  begin
    select 'S'
      into v_exi_persona
      from ba_personas aa
     where aa.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      v_cod_error   := 5;
      v_exi_persona := 'N';
      v_cobro       := 'N';
      v_motivo      := 'Codigo de persona incorrecto';
    when others then
      v_cod_error   := 6;
      v_exi_persona := 'N';
      v_cobro       := 'N';
      v_motivo      := substr('Ocurrió un error durante el proceso de verificación de la persona ' ||
                              ' - ' || 'p_cod_persona ' || p_nro_cuenta ||
                              ' - ' || dbms_utility.format_error_stack ||
                              ' - ' || dbms_utility.format_error_backtrace,
                              1,
                              4000);
  end;
  if nvl(v_exi_persona, 'N') = 'S' then
    --verifica cuenta 
    begin
      select 'S'
        into v_exi_cuenta
        from ah_cta_vistas cc
       where cc.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        v_cod_error  := 7;
        v_exi_cuenta := 'N';
        v_cobro      := 'N';
        v_motivo     := 'Numero de cuenta incorrecta.';
      when others then
        v_cod_error  := 8;
        v_exi_cuenta := 'N';
        v_cobro      := 'N';
        v_motivo     := substr('Ocurrió un error durante el proceso de verificación de la cuenta ' ||
                               ' - ' || 'p_cod_persona ' || p_nro_cuenta ||
                               ' - ' || dbms_utility.format_error_stack ||
                               ' - ' || dbms_utility.format_error_backtrace,
                               1,
                               4000);
    end;
    if nvl(v_exi_cuenta, 'N') = 'S' then
      --verifica relacion persona - cuenta
      begin
        select 'S',
               ah.cod_modulo,
               ah.cod_modalidad,
               ah.cod_oficina,
               ah.estado,
               ah.est_batch,
               ah.cod_moneda,
               ah.nro_cuenta
          into v_rel_pers_cuenta,
               v_cod_modulo,
               v_cod_modalidad,
               v_cod_oficina,
               v_estado,
               v_est_batch,
               v_cod_moneda,
               v_nro_cuenta
          from ah_cta_vistas ah, ge_cta_clientes c
         where pae_uti.fu_obt_posicion(v_cod_mod_ahorros,ah.cod_modalidad) > 0 
               --instr(v_cod_mod_ahorros, ',' || ah.cod_modalidad || ',') > 0
           and ah.nro_cuenta = c.nro_cuenta
           and c.cod_persona = p_cod_persona
           and ah.nro_cuenta = p_nro_cuenta
           and c.relacion = 'P'
           and ah.estado in ('A', 'B', 'D', 'S', 'T', 'N');
      exception
        when no_data_found then
          v_cod_error       := 9;
          v_rel_pers_cuenta := 'N';
          v_cobro           := 'N';
          v_motivo          := 'Cuenta no corresponde a la persona ' ||
                               p_cod_persona ||
                               ' o verificar valor del parametro COD_MAD_COB_PLASTICOS - Modalidades Habilitadas para debito.';
        when too_many_rows then
          select 'S',
                 ah.cod_modulo,
                 ah.cod_modalidad,
                 ah.cod_oficina,
                 ah.estado,
                 ah.est_batch,
                 ah.cod_moneda,
                 ah.nro_cuenta
            into v_rel_pers_cuenta,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_estado,
                 v_est_batch,
                 v_cod_moneda,
                 v_nro_cuenta
            from ah_cta_vistas ah, ge_cta_clientes c
           where ah.cod_modalidad = 31 --si existe mas de 1 cuenta, se utiliza default caja ahorro vista
             and ah.nro_cuenta = c.nro_cuenta
             and c.cod_persona = p_cod_persona
             and ah.nro_cuenta = p_nro_cuenta
             and c.relacion = 'P'
             and ah.estado in ('A', 'B', 'D', 'S', 'T', 'N');
        when others then
          v_cod_error := 10;
          v_cobro     := 'N';
          v_motivo    := 'Error al obtener datos de la cuenta ' ||
                         p_nro_cuenta || ' ' || sqlerrm;
      end;
      if nvl(v_rel_pers_cuenta, 'N') = 'S' then
        --verifica disponible de la cuenta
        v_tie_fondo := it.fug_obt_sal_actual(p_cod_persona,
                                             v_cod_modulo,
                                             v_cod_modalidad,
                                             p_nro_cuenta);
      
        if v_tie_fondo > p_monto then
        
          if nvl(v_cod_error, 0) = 0 then
          
            v_cod_tra_padre := fug_obt_pardinamico('COD_TRA_COB_PLASTICOS');
            v_horario       := 'D';
            v_est_modulo    := pae_cnf.fu_obt_est_modulo(3);
          
            if v_est_modulo != 2 then
              v_horario     := 'N';
              v_es_nocturno := 'S';
            else
              v_horario     := 'D';
              v_es_nocturno := 'N';
            end if;
            if v_nro_secuencia + 2 > 999 then
              v_nro_secuencia := 0;
              v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
              r_gmovi.hora    := v_hora;
            end if;
          
            pag_cta.g_horario := v_horario;
            v_nro_secuencia   := 0;
            v_cod_mon_local   := pag_gen.fu_obt_mon_local;
          
            -- obtener tasa
            begin
              pag_cta.pr_obt_tas_pizarra(3,
                                         31,
                                         v_cod_moneda,
                                         v_tip_capitalizacion * 30,
                                         0,
                                         v_piz_tasa_min,
                                         v_piz_tasa_max,
                                         v_piz_tasa_actual,
                                         v_tip_capitalizacion);
            
              pag_gen.pr_obt_val_tasa(3,
                                      31,
                                      v_cod_oficina,
                                      p_nro_cuenta,
                                      v_cod_moneda,
                                      p_monto,
                                      'N', --p_tas_personalizada,
                                      v_cod_tasa,
                                      v_cod_tra_padre,
                                      null,
                                      v_val_tasa,
                                      v_fec_vigencia,
                                      v_tip_valor,
                                      v_tip_tasa);
            exception
              when others then
                p_cobro  := 'N';
                p_motivo := 'Error al obtener tasa.';
            end;
            --- inicializa datos del movimiento
            r_gmovi.cod_usuario     := user;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fec_actual;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_oficina;
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.cod_moneda      := v_cod_mon_local;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.protegido       := 'N';
            r_gmovi.nro_cuenta      := p_nro_cuenta;
            r_gmovi.est_cuenta      := v_estado;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_tra_padre   := v_cod_tra_padre;
            r_gmovi.cod_transaccion := v_cod_tra_padre;
            r_gmovi.concepto        := 'COBRO POR IMPRESION DE TARJETA';
            r_gmovi.monto           := p_monto;
            r_gmovi.est_cuenta      := v_est_batch;
            r_gmovi.cod_tasa        := v_cod_tasa;
            r_gmovi.val_tasa        := v_val_tasa;
            r_gmovi.nro_cuenta      := v_nro_cuenta;
            r_gmovi.cod_moneda      := v_cod_moneda;
            --inserta el movimiento
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
          
            --debita a la cuenta
            begin
              pag_cta.pr_act_sal_cta(p_nro_cuenta,
                                     v_cod_modalidad,
                                     'D', --_tip_movimiento,
                                     v_fec_actual,
                                     v_hora,
                                     p_monto,
                                     0, --p_sal_retenido,
                                     0, --p_sal_bloqueado,
                                     0); --,
              -- p_act_ult_movimiento);*/
            exception
              when others then
                raise_application_error(-20000,
                                        'Error nro_cuenta: ' ||
                                        p_nro_cuenta || ' - ' || sqlerrm);
                p_cobro  := 'N';
                p_motivo := 'Error al realizar el debito en la cuenta ' ||
                            p_nro_cuenta || ' ' || sqlerrm;
                rollback;
            end;
            -- retorno exitoso
            p_cobro  := 'S';
            p_motivo := 'Cobro exitoso.';
          end if;
        else
          p_cobro  := 'N';
          p_motivo := 'Cuenta con fondo insuficiente para la operacion.';
        end if;
      else
        p_cobro  := v_cobro;
        p_motivo := v_motivo;
      end if;
    else
      p_cobro  := v_cobro;
      p_motivo := v_motivo;
    end if;
  else
    p_cobro  := v_cobro;
    p_motivo := v_motivo;
  end if;
exception
  when others then
    raise_application_error(-20000,
                            'Error nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                            sqlerrm);
    p_cobro  := 'N';
    p_motivo := 'Error en la llamada al PRG_CJ_COBRO_DUO_CAR_PLASTICOS' ||
                p_nro_cuenta || sqlerrm;
end;
/

