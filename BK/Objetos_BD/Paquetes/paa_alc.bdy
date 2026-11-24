create or replace package body it.paa_alc is
  v_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%TYPE := fug_obt_pardinamico('COD_SUB_MAD_AHO_VISTA');
  -- creacion de alcancias
  procedure pr_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
                           p_horario        out varchar2,
                           p_es_mov_noc     out varchar2,
                           p_es_cta_noc     out varchar2,
                           p_fec_actual     out date,
                           p_fec_valor      out date,
                           p_cod_error      out number,
                           p_men_error      out varchar2) is
  
    v_est_modulo ba_modulos.estado%type;
  begin
    p_cod_error  := v_pro_correcto;
    p_horario    := 'D'; -- dia normal
    p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
    p_es_cta_noc := 'N';
    p_fec_actual := pag_cal.fu_obt_fec_actual(9);
    v_est_modulo := pae_cnf.fu_obt_est_modulo(9);
  
    if fug_obt_pardinamico('ACT_NOCTURNO') = 'N' then
      p_cod_error := '1070';
      p_men_error := 'Modulo en proceso de cierre';
    else
      if v_est_modulo = 2 then
        p_horario    := 'D'; -- dia normal
        p_es_mov_noc := 'N'; -- para grabar en las tablas nocturnas
        p_es_cta_noc := 'N';
        p_fec_actual := pag_cal.fu_obt_fec_actual(9);
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
  end pr_ver_horario;

  FUNCTION fu_obt_hora return varchar2 is
    v_hora    ge_movimientos.hora%type;
    v_nro_sec number;
    v_nro_hor number;
  BEGIN
  
    v_nro_sec := fue_obt_sig_secuencia('s_hor_alc');
  
    if v_nro_sec <= 86400 then
      v_nro_hor := v_nro_sec;
    else
      v_nro_hor := mod(v_nro_sec, 86400);
    end if;
  
    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');
  
    return v_hora;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000,
                              'No se puede obtener la hora del movimiento. ' ||
                              sqlerrm);
  END;

  function fu_es_conjunta(p_nro_cuenta in varchar2) return varchar2 is
    v_can_conjunta number;
  begin
  
    select count('S')
      into v_can_conjunta
      from ge_cta_clientes
     where nro_cuenta = p_nro_cuenta
       and relacion = 'Y'
       and rownum = 1;
  
    if nvl(v_can_conjunta, 0) > 0 then
      return 'S';
    else
      return 'N';
    end if;
  end;

  -- creacion de alcancias
  procedure pr_cre_cta_alcancia(p_nro_cta_relacion ge_cuentas.nro_cuenta%type,
                                p_nro_cta_alcancia out ge_cuentas.nro_cuenta%type,
                                p_cod_error        out number,
                                p_men_error        out varchar2) is
    v_dig_verificador    ah_cta_vistas.dig_verificador%type;
    v_cod_error          number := v_pro_correcto;
    v_nro_cuenta         ah_cta_vistas.nro_cuenta%type;
    v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
    v_can_alcancias      number;
    v_hora               ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                  'HH24:MI:SS');
    v_tip_persona        ba_personas.tipo%type;
    v_tip_capitalizacion ah_cta_vistas.tip_capitalizacion%type;
    v_cod_tasa           ah_cta_vistas.cod_tasa%type;
    v_piz_tasa_min       ge_tas_fechas.val_minimo%type;
    v_piz_tasa_max       ge_tas_fechas.val_maximo%type;
    v_piz_tasa_actual    ge_tas_fechas.val_tasa%type;
    v_sal_min_pactado    ah_cta_vistas.sal_minimo%type;
  
    cursor c_cta is
      select v.nro_cuenta,
             v.dig_verificador,
             v.cod_modulo,
             v.cod_modalidad,
             v.cod_oficina,
             v.cod_moneda,
             v.denominacion,
             v.fre_extracto,
             v.fec_ult_extracto,
             v.can_fir_requeridas,
             v.can_fir_registradas,
             v.fec_apertura,
             v.tas_personalizada,
             cod_tasa,
             v.ret_personalizada,
             v.est_batch,
             v.estado,
             v.nro_folio,
             v.tra_prohibida,
             v.cta_combinada,
             v.aut_pendiente,
             v.reg_firma,
             c.cod_persona,
             v.cod_usu_promotor
        from ah_cta_vistas v, ge_cta_clientes c
       where v.nro_cuenta = p_nro_cta_relacion
         and v.nro_cuenta = c.nro_cuenta
         and c.relacion = 'P';
  
  begin
    for c in c_cta loop
      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = c.cod_persona;
      exception
        when others then
          v_tip_persona := 'J';
      end;
    
      if v_tip_persona <> 'F' then
        v_cod_error := 1000;
        p_men_error := 'La persona debe ser Fisica.';
      end if;
    
      if c.cod_moneda <> v_cod_mon_local then
        v_cod_error := 1001;
        p_men_error := 'La Moneda debe ser en Moneda Local.';
      end if;
    
      v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                                  c.cod_modulo,
                                                  331,
                                                  c.cod_moneda,
                                                  null);
    
      v_sal_min_pactado := fug_obt_sal_min_pactado(c.cod_moneda,
                                                   c.cod_persona,
                                                   3,
                                                   331,
                                                   c.cod_oficina);
    
      -- obtener tasa
      begin
        pag_cta.pr_obt_tas_pizarra(3,
                                   331,
                                   c.cod_moneda,
                                   v_tip_capitalizacion * 30,
                                   0,
                                   v_piz_tasa_min,
                                   v_piz_tasa_max,
                                   v_piz_tasa_actual,
                                   v_tip_capitalizacion);
      
        pr_obt_tasa(3,
                    331,
                    c.cod_moneda,
                    c.cod_oficina,
                    v_fec_actual,
                    v_piz_tasa_actual,
                    v_cod_tasa);
      exception
        when others then
          v_cod_error := v_err_sql;
          p_men_error := 'Error al obtener la tasa. ' || sqlerrm;
      end;
    
      begin
        select count(*)
          into v_can_alcancias
          from ah_cta_vistas a, ge_cta_clientes cl
         where cl.cod_persona = c.cod_persona
           and a.nro_cuenta = cl.nro_cuenta
           and cl.relacion = 'P'
           and a.estado not in ('P', 'C')
           and a.cod_modalidad = 331;
      exception
        when others then
          v_can_alcancias := 0;
      end;
    
      if v_can_alcancias > 0 then
        v_cod_error := 1002;
        p_men_error := 'Solo puede tener una cuenta alcancia.';
      end if;
    
      if v_cod_error = v_pro_correcto then
        begin
          v_nro_cuenta := fug_obt_sig_nro_cuenta(c.cod_modulo,
                                                 c.cod_modalidad,
                                                 c.cod_oficina,
                                                 c.cod_moneda,
                                                 c.cod_persona);
        exception
          when others then
            v_cod_error := v_err_sql;
            p_men_error := 'Error al obtener el numero de cuenta. ' ||
                           sqlerrm;
        end;
      
        v_dig_verificador := pag_cta.fu_cal_dig_verifica(v_nro_cuenta);
        begin
        
          insert into ah_cta_vistas
            (nro_cuenta,
             dig_verificador,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             denominacion,
             cod_moneda,
             fre_extracto,
             can_fir_requeridas,
             can_fir_registradas,
             fec_apertura,
             tip_capitalizacion,
             tas_personalizada,
             cod_tasa,
             ret_personalizada,
             est_batch,
             estado,
             nro_folio,
             fec_cam_estado,
             sal_ult_capitalizacion,
             sal_ret_batch,
             sal_retenido,
             sal_blo_batch,
             sal_bloqueado,
             sal_tot_batch,
             sal_total,
             tra_prohibida,
             cta_combinada,
             aut_pendiente,
             mto_deb_pendientes,
             mto_cre_pendientes,
             mto_cre_a_confirmar,
             mto_apertura,
             reg_firma,
             cod_usu_promotor)
          values
            (v_nro_cuenta,
             v_dig_verificador,
             c.cod_modulo,
             331,
             c.cod_oficina,
             c.denominacion,
             c.cod_moneda,
             c.fre_extracto,
             1,
             1,
             v_fec_actual,
             v_tip_capitalizacion,
             'N',
             v_cod_tasa,
             'N',
             'A',
             'A',
             0,
             v_fec_actual,
             0,
             0,
             0,
             0,
             0,
             0,
             0,
             'N',
             'N',
             'N',
             0,
             0,
             0,
             0,
             c.reg_firma,
             c.cod_usu_promotor);
          p_nro_cta_alcancia := v_nro_cuenta;
        exception
          when others then
            v_cod_error := v_err_sql;
            p_men_error := 'Error al insertar la cuenta. ' || sqlerrm;
        end;
        if v_cod_error = v_pro_correcto then
          begin
            insert into ge_cta_clientes
              (cod_persona,
               nro_cuenta,
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               relacion)
            values
              (c.cod_persona,
               v_nro_cuenta,
               v_dig_verificador,
               c.cod_oficina,
               c.cod_modulo,
               331,
               'P');
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'No se puede ingresar la relacion Cuenta-Cliente. ' ||
                             sqlerrm;
          end;
        end if;
        if v_cod_error = v_pro_correcto then
          v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
          pr_gen_movimientos(v_fec_actual,
                             1,
                             v_hora,
                             401,
                             3,
                             331,
                             v_nro_cuenta,
                             c.cod_moneda,
                             c.cod_oficina,
                             'A',
                             401,
                             null,
                             null,
                             null,
                             'N',
                             null,
                             null,
                             v_cod_error,
                             p_men_error);
        end if;
      end if;
      if v_cod_error <> v_pro_correcto then
        prg_ins_log_programas('PAA_ALC.PR_CRE_CTA_ALCANCIA',
                              substr(v_cod_error || ' - ' || p_men_error,
                                     1,
                                     4000),
                              c.cod_persona,
                              p_nro_cta_relacion);
      end if;
    end loop;
  
    p_cod_error := nvl(v_cod_error, v_pro_correcto);
  
  end;

  procedure pr_obt_tasa(p_cod_modulo    ba_modulos.cod_modulo%type,
                        p_cod_modalidad ge_modalidades.cod_modalidad%type,
                        p_cod_moneda    ba_monedas.cod_moneda%type,
                        p_cod_oficina   ah_cta_vistas.cod_oficina%type,
                        p_fec_apertura  ah_cta_vistas.fec_apertura%type,
                        p_tasa_actual   number,
                        p_cod_tasa      out ah_cta_vistas.cod_tasa%type) is
    v_cod_tasa ah_cta_vistas.cod_tasa%type;
  begin
    begin
      select tf1.cod_tasa
        into v_cod_tasa
        from ge_tasas tf2, ge_tas_fechas tf1
       where tf2.cod_tasa = tf1.cod_tasa
         and nvl(tf1.cod_modulo, p_cod_modulo) = p_cod_modulo
         and tf1.cod_modalidad = p_cod_modalidad
         and tf1.cod_sub_modalidad = v_cod_sub_modalidad
         and nvl(tf1.cod_oficina, p_cod_oficina) = p_cod_oficina
         and nvl(tf1.cod_moneda, p_cod_moneda) = p_cod_moneda
         and tf1.nro_cuenta is null
         and tf1.val_tasa = p_tasa_actual
         and descripcion like '%TASA%'
         and rownum = 1
         and tf1.fec_vigencia =
             (select max(tf2.fec_vigencia)
                from ge_tas_fechas tf2
               where nvl(tf2.cod_modulo, p_cod_modulo) = p_cod_modulo
                 and tf2.cod_modalidad = p_cod_modalidad
                 and tf2.cod_sub_modalidad = v_cod_sub_modalidad
                 and nvl(tf2.cod_oficina, p_cod_oficina) = p_cod_oficina
                 and nvl(tf2.cod_moneda, p_cod_moneda) = p_cod_moneda
                 and tf2.nro_cuenta is null
                 and tf2.cod_tasa = tf1.cod_tasa
                 and fec_vigencia <= p_fec_apertura)
       order by tf1.cod_tasa;
    exception
      when no_data_found then
        begin
          declare
            cursor rango is
              select ra1.cod_tasa
                from ge_tasas ra2, ge_tas_rangos ra1
               where ra2.cod_tasa = ra1.cod_tasa
                 and nvl(ra1.cod_modulo, p_cod_modulo) = p_cod_modulo
                 and ra1.cod_modalidad = p_cod_modalidad
                 and ra1.cod_sub_modalidad = v_cod_sub_modalidad
                 and nvl(ra1.cod_oficina, p_cod_oficina) = p_cod_oficina
                 and nvl(ra1.cod_moneda, p_cod_moneda) = p_cod_moneda
                 and ra1.nro_cuenta is null
                 and ra1.val_tasa = p_tasa_actual
                 and descripcion like '%TASA%'
                 and ra1.fec_vigencia =
                     (select max(ra2.fec_vigencia)
                        from ge_tas_rangos ra2
                       where nvl(ra2.cod_modulo, p_cod_modulo) =
                             p_cod_modulo
                         and ra2.cod_modalidad = p_cod_modalidad
                         and ra2.cod_sub_modalidad = v_cod_sub_modalidad
                         and nvl(ra2.cod_oficina, p_cod_oficina) =
                             p_cod_oficina
                         and nvl(ra2.cod_moneda, p_cod_moneda) =
                             p_cod_moneda
                         and ra2.nro_cuenta is null
                         and ra2.cod_tasa = ra1.cod_tasa
                         and ra2.val_hasta > 0
                         and ra2.fec_vigencia <= p_fec_apertura);
          begin
            for tra in rango loop
              v_cod_tasa := tra.cod_tasa;
              exit;
            end loop;
          end;
        end;
      when too_many_rows then
        v_cod_tasa := null;
    end;
    p_cod_tasa := v_cod_tasa;
  exception
    when others then
      p_cod_tasa := null;
  end;

  procedure pr_gen_movimientos(p_fecha           in ge_calendarios.fec_actual%type,
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
                               p_concepto        varchar2 default null) is
    r_gmovi ge_movimientos%rowtype;
  begin
    p_cod_error := 0;
    --- cargar registro de movimiento
    r_gmovi.cod_usuario     := nvl(p_cod_usuario, user);
    r_gmovi.hora            := p_hora;
    r_gmovi.nro_secuencia   := nvl(p_nro_secuencia, 1);
    r_gmovi.cod_modulo      := p_cod_modulo;
    r_gmovi.cod_modalidad   := p_cod_modalidad;
    r_gmovi.cod_oficina     := p_cod_oficina;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.cod_moneda      := p_cod_moneda;
    r_gmovi.fec_valor       := trunc(sysdate);
    r_gmovi.fecha           := p_fecha;
    r_gmovi.cod_tra_padre   := p_cod_tra_padre;
    r_gmovi.cod_transaccion := p_cod_transaccion;
    r_gmovi.est_cuenta      := p_est_cuenta;
  
    if p_cod_tra_padre = 401 then
      r_gmovi.estado := 'N'; --si es cambio de estado debe ingresar como normal
    else
      r_gmovi.estado := 'X'; --se envia pendiente desde la implementacion de autorizaciones
    end if;
  
    r_gmovi.cod_ofi_origen := p_cod_oficina;
    r_gmovi.reversado      := 'N';
    r_gmovi.emi_aviso      := p_emi_aviso;
    r_gmovi.protegido      := 'N';
    r_gmovi.cod_mod_padre  := p_cod_modulo;
    r_gmovi.cod_mad_padre  := p_cod_modalidad;
    r_gmovi.monto          := p_monto;
    r_gmovi.nro_documento  := p_nro_documento;
    r_gmovi.cod_causa      := p_cod_causa;
    r_gmovi.cod_tasa       := p_cod_tasa;
    r_gmovi.val_tasa       := p_val_tasa;
    r_gmovi.concepto       := nvl(p_concepto, '');
    pag_gen.pr_ins_ge_movimiento(r_gmovi);
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'No se puede ingresar el Movimiento ' || sqlerrm;
  end;

  function fu_obt_alc_principal(p_cod_persona ba_personas.cod_persona%type)
    return varchar2 is
    v_nro_cuenta ah_cta_vistas.nro_cuenta%type;
  begin
    begin
      select c.nro_cuenta
        into v_nro_cuenta
        from ah_cta_vistas c, ge_cta_clientes p
       where p.cod_persona = p_cod_persona
         and p.nro_cuenta = c.nro_cuenta
         and c.cod_modalidad = 331
         and c.estado not in ('C', 'P')
         and p.relacion = 'P';
    exception
      when others then
        v_nro_cuenta := '0';
    end;
  
    return v_nro_cuenta;
  end;

  procedure pr_tra_pen_ahorro(p_cod_persona varchar2,
                              p_nva_cta     varchar2,
                              p_cod_error   out number,
                              p_men_error   out varchar2) is
  
    v_nro_secuencia  ge_movimientos.nro_secuencia%type;
    v_hora           varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
    v_nombre1        ba_per_fisicas.pri_nombre%type;
    v_nombre2        ba_per_fisicas.seg_nombre%type;
    v_apellido1      ba_per_fisicas.pri_apellido%type;
    v_apellido2      ba_per_fisicas.seg_apellido%type;
    v_fecha          date;
    v_nro_telef      ba_tab_dat_adicionales.val_parametro%type;
    v_existe         number;
    v_cod_causa      ge_causales.cod_causa%type := 219;
    v_cod_tra        ge_transacciones.cod_transaccion%type;
    v_concepto       ge_movimientos.concepto%type;
    v_transaccion    ge_movimientos.nro_documento%type;
    v_log_error      varchar2(4000);
    v_cta_operativa  ge_cuentas.nro_cuenta%type;
    v_fec_cal_actual ge_calendarios.fec_actual%type;
    cursor c_tra_pendientes is
      select st.*
        from ge_sol_tra_cuentas st
       where st.nro_telefono = v_nro_telef
         and st.estado = 'P'
         and st.fec_vencimiento >= v_fec_cal_actual
       order by st.fec_insercion;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
  
    v_fec_cal_actual := pag_cal.fu_obt_fec_actual(3);
    begin
      select trim(a.area || a.telefono)
        into v_nro_telef
        from ba_telefonos a
       where a.cod_persona = p_cod_persona
         and a.principal = 'S'
         and a.tipo = 'P'
         and a.tip_linea = 'C'
         and rownum = 1;
    exception
      when no_data_found then
        begin
          SELECT a.val_parametro
            INTO v_nro_telef
            FROM ba_tab_dat_adicionales a
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona;
        exception
          when no_data_found then
            p_cod_error := v_err_sql;
            p_men_error := 'No existe nro telefono  para cod.persona ' ||
                           p_cod_persona;
            v_log_error := p_men_error;
          when others then
            p_cod_error := v_err_sql;
            p_men_error := 'Ocurrio un error al buscar nro telefono para cod.persona ' ||
                           p_cod_persona;
            v_log_error := 'Ocurrio un error al buscar nro telefono para cod.persona ' ||
                           p_cod_persona || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace;
        end;
      when others then
        p_cod_error := v_err_sql;
        p_men_error := 'Error al obtener nro telefono de la persona ' ||
                       p_cod_persona;
        v_log_error := substr('Error al obtener nro telefono de la persona ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
    end;
  
    if nvl(p_cod_error, 0) = 0 then
      v_concepto := 'Transferencia por Onboarding';
      for r in c_tra_pendientes loop
        savepoint pendientes;
        --transfiere el saldo pendiente
        if nvl(p_cod_error, 0) = 0 then
          v_cta_operativa := fug_obt_pardinamico('CTA_OPE_TRA_CONTACTO');
          begin
            pr_gen_tra_cuentas(v_cta_operativa,
                               p_nva_cta,
                               r.monto,
                               'N',
                               'W',
                               'TC',
                               r.nro_transferencia,
                               v_transaccion,
                               v_hora,
                               v_fecha,
                               p_cod_error,
                               p_men_error);
          exception
            when others then
              p_cod_error := v_err_sql;
              p_men_error := 'Error al realizar transferencia ' ||
                             p_men_error;
              v_log_error := substr('Error al realizar transferencia ' ||
                                    p_men_error,
                                    1,
                                    4000);
          end;
        end if;
      
        if nvl(p_cod_error, 0) = 0 then
          begin
            update ge_sol_tra_cuentas s
               set s.nro_cta_credito = p_nva_cta,
                   s.fec_credito     = v_fecha,
                   s.hora_credito    = v_hora,
                   s.estado          = 'R'
             where s.nro_transferencia = r.nro_transferencia
               and s.fec_ingreso = r.fec_ingreso
               and s.nro_cta_debito = r.nro_cta_debito;
          exception
            when others then
              p_cod_error := v_err_sql;
              p_men_error := 'Error actualizando la cuenta ' ||
                             r.nro_cta_debito ||
                             ' en la tabla ge_sol_tra_cuentas ';
              v_log_error := substr('Error al actualizar registro en la tabla ge_sol_tra_cuentas, tranferencia nro: ' ||
                                    r.nro_transferencia || ' ' ||
                                    DBMS_UTILITY.format_error_stack ||
                                    ' - ' ||
                                    DBMS_UTILITY.format_error_backtrace,
                                    1,
                                    4000);
            
          end;
        end if;
        if nvl(p_cod_error, 0) != 0 then
          if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
            prg_ins_log_programas('PAA_ALC.PR_TRA_PEN_AHORRO',
                                  substr('Transferencia nro.: ' ||
                                         r.nro_transferencia || ' Monto: ' ||
                                         r.monto || ' Nro telefono ' ||
                                         r.nro_telefono || ' Error: ' ||
                                         nvl(v_log_error, p_men_error),
                                         1,
                                         4000),
                                  p_cod_persona,
                                  p_nva_cta);
          end if;
          rollback to pendientes;
        end if;
        p_cod_error   := 0;
        p_men_error   := null;
        v_log_error   := null;
        v_transaccion := null;
        v_hora        := null;
        v_fecha       := null;
      end loop;
    end if;
  
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error inesperado en el proceso de acreditacion de transferencias por contanto pendientes';
      v_log_error := substr('Error inesperado en el proceso de acreditacion de transferencias por contanto pendientes, ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAA_ALC.PR_TRA_PEN_AHORRO',
                              substr(' Error: ' ||
                                     nvl(v_log_error, p_men_error),
                                     1,
                                     4000),
                              p_cod_persona,
                              p_nva_cta);
      end if;
  end;
  -- transferencia entre cuentas  
  procedure pr_gen_tra_cuentas(p_nro_cta_remitente ge_cuentas.nro_cuenta%type,
                               p_nro_cta_destino   ge_cuentas.nro_cuenta%type,
                               p_monto             ge_movimientos.monto%type,
                               p_tip_proceso       varchar2 default 'N',
                               p_cod_canal         varchar2 default 'N',
                               p_tipo              varchar2 default null,
                               p_referencia        ge_movimientos.nro_documento%type default null,
                               p_nro_trans         out ge_movimientos.nro_documento%type,
                               p_hora              out ge_movimientos.hora%type,
                               p_fecha             out ge_movimientos.fecha%type,
                               p_cod_error         out number,
                               p_men_error         out varchar2) is
    v_cod_mon_des      ba_monedas.cod_moneda%type;
    v_mto_destino      ge_movimientos.monto%type;
    v_cod_mod_des      ge_cuentas.cod_modulo%type;
    v_cod_mad_des      ge_cuentas.cod_modalidad%type;
    v_cod_ofi_des      ge_movimientos.cod_oficina%type;
    v_cod_mod_rem      ge_cuentas.cod_modulo%type;
    v_cod_mad_rem      ge_cuentas.cod_modalidad%type;
    v_cod_mon_rem      ge_cuentas.cod_moneda%type;
    v_cod_ofi_rem      ge_movimientos.cod_oficina%type;
    v_nro_secuencia    ge_movimientos.nro_secuencia%type;
    v_concepto         ge_movimientos.concepto%type;
    v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                'HH24:MI:SS');
    v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
    v_estado           ge_cuentas.estado%type;
    v_procesa          varchar2(1);
    v_sal_disponible   ah_cta_vistas.sal_total%type;
    v_cod_tra_alcancia ge_transacciones.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_INT_ALCANCIA',
                                                                                    3,
                                                                                    31);
    v_cod_tra_padre    ge_transacciones.cod_transaccion%type;
    v_cod_per_alc      ba_personas.cod_persona%type;
    v_exi_per_alc      varchar2(1);
    v_nro_caja         ge_movimientos.nro_caja%type;
    v_cod_oficina      ge_movimientos.cod_oficina%type;
    v_cod_usuario      ge_movimientos.cod_usuario%type := USER;
    v_cod_error        number;
    v_cod_mod_padre    ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre    ge_movimientos.cod_mad_padre%type;
    v_horario          varchar2(1);
    v_es_mov_noc       varchar2(1);
    v_es_cta_noc       varchar2(1);
    v_fec_valor        ge_calendarios.fec_actual%type;
    v_est_modulo       ba_modulos.estado%type := pae_cnf.fu_obt_est_modulo(1);
    v_men_error        varchar2(4000);
    v_nro_documento    ge_movimientos.nro_documento%type;
    v_cod_per_des      ba_personas.cod_persona%type;
    v_cod_per_rem      ba_personas.cod_persona%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    p_cod_error := v_pro_correcto;
    --savepoint transferencia;
    if nvl(p_monto, 0) <= 0 then
      p_cod_error := 999;
      p_men_error := 'El monto debe ser mayor a cero ';
      v_men_error := 'El monto debe ser mayor a cero ' || p_monto;
      return;
    end if;
  
    if nvl(p_nro_cta_remitente, 'x') = 'x' then
      p_cod_error := 999;
      p_men_error := 'La cuenta debito no puede ser nulo ';
      v_men_error := p_men_error;
      return;
    end if;
  
    if nvl(p_nro_cta_destino, 'x') = 'x' then
      p_cod_error := 999;
      p_men_error := 'La cuenta credito no puede ser nulo ';
      v_men_error := p_men_error;
      return;
    end if;
  
    pag_cta.PR_OBT_CUENTA(p_nro_cta_destino);
  
    v_cod_mod_des := pag_cta.G_CTAS.COD_MODULO;
    v_cod_mad_des := pag_cta.G_CTAS.COD_MODALIDAD;
    v_cod_mon_des := pag_cta.G_CTAS.COD_MONEDA;
    v_cod_ofi_des := pag_cta.G_CTAS.COD_OFICINA;
    v_cod_per_des := pag_cta.G_CTAS.COD_CLIENTE;
  
    if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
      p_cod_error := pag_cta.g_cod_error;
      p_men_error := pag_cta.g_msj_error;
      v_men_error := substr(p_men_error || ' ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
    else
      pag_cta.G_CTAS := null;
      pag_cta.PR_OBT_CUENTA(p_nro_cta_remitente);
    
      v_cod_mod_rem := pag_cta.G_CTAS.COD_MODULO;
      v_cod_mad_rem := pag_cta.G_CTAS.COD_MODALIDAD;
      v_cod_mon_rem := pag_cta.G_CTAS.COD_MONEDA;
      v_cod_ofi_rem := pag_cta.G_CTAS.COD_OFICINA;
      v_cod_per_rem := pag_cta.G_CTAS.COD_CLIENTE;
    
      if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
        p_cod_error := pag_cta.g_cod_error;
        p_men_error := pag_cta.g_msj_error;
        v_men_error := substr(p_men_error || ' ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      end if;
    end if;
  
    if fu_es_conjunta(p_nro_cta_remitente) = 'S' then
      p_cod_error := v_err_sql;
      p_men_error := 'La cuenta ' || p_nro_cta_remitente || ' es conjunta ';
      v_men_error := p_men_error;
    end if;
    if nvl(p_cod_error, 0) = v_pro_correcto then
      if nvl(p_tip_proceso, 'N') = 'C' then
        v_cod_mod_padre := 3;
        v_cod_mad_padre := 31;
        v_cod_tra_padre := v_cod_tra_alcancia;
        v_concepto      := 'Transferencia Entre Alcancias';
      else
        v_cod_mod_padre := 9;
        v_cod_mad_padre := 91;
        v_cod_tra_padre := 388;
        v_concepto      := 'Transferencia Entre Cuentas';
      end if;
    end if;
  
    if nvl(p_cod_error, 0) = v_pro_correcto then
      pag_cta.pr_ver_operacion(p_nro_cta_destino,
                               v_cod_tra_padre, -- cod tra padre
                               v_cod_mod_padre, -- cod_mod_padre
                               v_cod_mad_padre, -- cod_mod_hijo
                               'C', -- tipo:credito
                               v_cod_mon_des,
                               v_mto_destino,
                               v_cod_oficina,
                               v_cod_mod_des,
                               v_cod_mad_des,
                               v_estado, --toma el estado de la cuenta
                               v_sal_disponible, -- sal_disponible
                               v_procesa, -- procesa (s/n)
                               602);
    
      if nvl(v_procesa, 'N') = 'N' then
        p_cod_error := v_err_sql;
        p_men_error := pag_cta.fu_obt_cod_error() || ' - ' ||
                       pag_cta.fu_obt_msj_error();
        v_men_error := substr(p_men_error || ' ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      else
        if p_cod_canal in ('W', 'M') and
           nvl(p_cod_error, 0) = v_pro_correcto then
          it.prw_obt_dat_caja(p_cod_canal,
                              v_nro_caja,
                              v_cod_oficina,
                              v_cod_usuario,
                              v_cod_error,
                              v_men_error);
          if v_cod_error = v_pro_correcto then
            v_nro_secuencia := 0;
            pag_cta.pr_nro_caja(v_nro_caja);
            pag_cta.pr_set_variables(v_cod_usuario,
                                     v_fec_actual,
                                     v_cod_tra_padre,
                                     'N',
                                     'N',
                                     v_nro_secuencia,
                                     null,
                                     v_cod_oficina,
                                     v_cod_mod_padre,
                                     v_cod_mad_padre);
          else
            p_cod_error := v_cod_error;
            p_men_error := v_men_error;
            v_men_error := substr(p_men_error || ' ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
          end if;
        end if;
      
        if nvl(p_tip_proceso, 'N') <> 'C' and
           nvl(p_cod_error, 0) = v_pro_correcto then
        
          if v_cod_oficina is null then
            v_cod_oficina := fug_obt_ofi_usuario(v_cod_usuario);
          end if;
        
          if p_referencia is not null then
            pag_cta.pr_set_nro_documento2(p_referencia);
          end if;
        
          pr_ver_horario(v_cod_oficina,
                         v_horario,
                         v_es_mov_noc,
                         v_es_cta_noc,
                         v_fec_actual,
                         v_fec_valor,
                         p_cod_error,
                         p_men_error);
        end if;
        if p_cod_error = v_pro_correcto then
          v_nro_secuencia := 0;
          v_hora          := fu_obt_hora; /*fug_obt_hor_disponible(v_fec_actual,
                                                                                                                                                                            v_hora,
                                                                                                                                                                            v_cod_usuario,
                                                                                                                                                                            'N');*/
          p_hora          := v_hora;
          p_fecha         := v_fec_actual;
          v_nro_documento := to_number(to_char(v_fec_actual, 'rrmmddhh24') ||
                                       to_char(it.s_nro_doc.nextval));
          p_nro_trans     := v_nro_documento;
          pag_cta.pr_act_operacion(p_nro_cta_destino,
                                   v_hora, -- hora
                                   'C',
                                   v_cod_mon_des, -- moneda de la operacion
                                   p_monto,
                                   v_cod_tra_padre,
                                   602,
                                   v_nro_documento, -- nro documento
                                   null, -- cotizacion
                                   v_cod_oficina, -- cod_ofi_origen
                                   v_cod_mod_padre, -- cod_mod_padre
                                   v_cod_mad_padre, -- cod_mad_padre
                                   null, -- cod_tasa
                                   null, -- val_tasa
                                   v_concepto,
                                   'N', -- emi_aviso
                                   v_nro_secuencia,
                                   v_fec_valor,
                                   null,
                                   null,
                                   null);
        
          if nvl(pag_cta.fu_obt_cod_error(), 0) <> 0 then
            p_cod_error := v_err_sql;
            p_men_error := pag_cta.fu_obt_cod_error() || ' - ' ||
                           pag_cta.fu_obt_msj_error();
            v_men_error := substr(p_men_error || ' ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
          else
            -- si pudo realizar el credito
          
            v_sal_disponible := 0;
            v_estado         := null;
            v_procesa        := null;
            pag_cta.pr_ver_operacion(p_nro_cta_remitente,
                                     v_cod_tra_padre, -- cod tra padre
                                     v_cod_mod_padre, -- cod_mod_padre
                                     v_cod_mad_padre, -- cod_mod_hijo
                                     'D', -- tipo: debito
                                     v_cod_mon_rem,
                                     p_monto,
                                     v_cod_oficina,
                                     v_cod_mod_rem,
                                     v_cod_mad_rem,
                                     v_estado, -- toma el estado de la cuenta
                                     v_sal_disponible, -- sal_disponible
                                     v_procesa, -- procesa (s/n)
                                     503);
            if nvl(pag_cta.fu_obt_cod_error(), 0) <> 0 then
              if nvl(v_sal_disponible, 0) < nvl(v_mto_destino, 0) then
                p_cod_error := 1062;
                p_men_error := 'Saldo de la cuenta insuficiente. Saldo ' ||
                               v_sal_disponible || ' Monto Transf. ' ||
                               v_mto_destino;
                v_men_error := p_men_error;
              else
                p_cod_error := v_err_sql;
                p_men_error := pag_cta.fu_obt_cod_error() || ' - ' ||
                               pag_cta.fu_obt_msj_error();
                v_men_error := p_men_error;
              end if;
            else
            
              pag_cta.pr_act_operacion(p_nro_cta_remitente,
                                       v_hora, -- hora
                                       'D',
                                       v_cod_mon_rem,
                                       p_monto,
                                       v_cod_tra_padre,
                                       503,
                                       v_nro_documento, -- nro documento
                                       null, -- cotizacion
                                       v_cod_oficina, -- cod_ofi_origen
                                       v_cod_mod_padre, -- cod_mod_padre
                                       v_cod_mad_padre, -- cod_mad_padre
                                       null, -- cod_tasa
                                       null, -- val_tasa
                                       v_concepto,
                                       'N', -- emi_aviso
                                       v_nro_secuencia,
                                       v_fec_valor,
                                       null,
                                       null,
                                       null);
              if pag_cta.fu_obt_cod_error() <> 0 then
                p_cod_error := v_err_sql;
                p_men_error := pag_cta.fu_obt_cod_error() || ' - ' ||
                               pag_cta.fu_obt_msj_error();
                v_men_error := substr(p_men_error || ' ' ||
                                      DBMS_UTILITY.format_error_stack ||
                                      ' - ' ||
                                      DBMS_UTILITY.format_error_backtrace,
                                      1,
                                      4000);
              elsif nvl(p_tip_proceso, 'N') <> 'C' and p_tipo is not null then
                --llamar al proceso de insercion tabla de comprobantes
                prg_gen_comprobantes(p_tipo,
                                     v_fec_actual,
                                     v_hora,
                                     v_nro_secuencia,
                                     user,
                                     v_concepto,
                                     v_nro_documento,
                                     v_cod_mon_des,
                                     p_monto,
                                     v_cod_per_alc,
                                     p_nro_cta_remitente,
                                     null,
                                     p_nro_cta_destino,
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
                                     null,
                                     null,
                                     null,
                                     null,
                                     null,
                                     null,
                                     null,
                                     null,
                                     null,
                                     null);
              
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  
    if nvl(p_cod_error, 0) != v_pro_correcto then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        p_nro_trans := null;
        prg_ins_log_programas('PAA_ALC.PR_GEN_TRA_CUENTAS',
                              substr('Referencia tra: ' || p_referencia ||
                                     ' Error: ' ||
                                     nvl(v_men_error, p_men_error) ||
                                     ' Monto: ' || p_monto,
                                     1,
                                     4000),
                              v_cod_per_des,
                              p_nro_cta_destino);
      
      end if;
      raise_application_error(-20000,
                              nvl(v_men_error,
                                  'Ocurrió un error al hacer la transferencia a la cuenta ' ||
                                  p_nro_cta_destino));
    end if;
  exception
    when others then
      p_nro_trans := null;
      p_cod_error := 999;
      p_men_error := 'Error inesperado procesando Transferencia entre cuentas';
      v_men_error := substr('Error inesperado procesando Transferencia  entre cuentas ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
    
      if nvl(p_cod_error, 0) = 0 then
        if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
          prg_ins_log_programas('PAA_ALC.PR_GEN_TRA_CUENTAS',
                                substr('Referencia tra: ' || p_referencia ||
                                       ' Error: ' ||
                                       nvl(v_men_error, p_men_error) ||
                                       ' Monto: ' || p_monto,
                                       1,
                                       4000),
                                v_cod_per_des,
                                p_nro_cta_destino);
        end if;
      end if;
    
      raise_application_error(-20000,
                              'Error inesperado procesando Transferencia entre cuentas ');
    
  end;

  -- creacion de una nueva caja de ahorro
  -- creacion de una nueva caja de ahorro
  procedure pr_cre_cta_ahorro(p_cod_persona      ba_personas.cod_persona%type,
                              p_cod_moneda       ba_monedas.cod_moneda%type default v_cod_mon_local,
                              p_tip_proceso      varchar2 default 'C', -- o: onbording, -- c: convencional --t: tarjeta debito
                              p_cod_error        out number,
                              p_men_error        out varchar2,
                              p_nro_cta_ahorro   out ge_cuentas.nro_cuenta%type,
                              p_nro_cta_alcancia out ge_cuentas.nro_cuenta%type,
                              p_nro_tarjeta      out ah_tar_debitos.nro_tarjeta%type) is
    v_dig_verificador  ah_cta_vistas.dig_verificador%type;
    v_cod_oficina      ba_oficinas.cod_oficina%type;
    v_cod_usu_promotor ah_cta_vistas.cod_usu_promotor%type := fug_obt_pardinamico('COD_USU_PROMOTOR');
    v_cod_error        number := v_pro_correcto;
    v_nro_cuenta       ah_cta_vistas.nro_cuenta%type;
    v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
    v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                'HH24:MI:SS');
    v_nro_cta_alcancia ge_cuentas.nro_cuenta%type;
    v_cod_modalidad    ge_cuentas.cod_modalidad%type;
    -- v_cod_sub_mod_rie_baj ge_cuentas.cod_sub_modalidad%type := fug_obt_pardinamico('AHO_SUB_MOD_RIE_BAJ',3 ,31);
    v_cod_mod_cta_aho     ge_cuentas.cod_modalidad%type := fug_obt_pardinamico('AHO_MOD_CTA_AUT');
    v_denominacion        ah_cta_vistas.denominacion%type;
    v_can_alc             number := 0;
    v_exi_moneda          varchar2(1);
    v_cod_tasa            ah_cta_vistas.cod_tasa%type;
    v_sal_min_pactado     ah_cta_vistas.sal_minimo%type;
    v_tip_capitalizacion  ah_cta_vistas.tip_capitalizacion%type; -- parametrizar
    v_piz_tasa_min        ge_tas_fechas.val_minimo%type;
    v_piz_tasa_max        ge_tas_fechas.val_maximo%type;
    v_piz_tasa_actual     ge_tas_fechas.val_tasa%type;
    v_can_cuentas         number;
    v_estado              ah_cta_vistas.estado%type;
    v_tip_persona         ba_personas.tipo%type;
    v_cod_mon_bco_central ba_monedas.cod_mon_bco_central%type;
    v_can_firmante        number := 0;
    v_can_pen             number;
    v_ins_cta             varchar2(1) := 'S';
    v_tie_sol_firmantes   varchar2(1) := 'N';
    v_val_firmante        varchar2(1);
    v_cod_err_fir         number;
    v_men_err_fir         varchar2(1000);
    v_can_conjunta        number;
    v_err_mensaje         varchar2(4000);
    v_err_resultado       varchar2(5);
    v_men_error           varchar2(4000);
    v_exi_cliente         varchar2(1);
    v_alta                varchar2(1) := 'S';
    v_can_nro_cuenta      ah_cta_vistas.nro_cuenta%type;
    v_aut_fondeo          varchar2(1) := 'N';
    v_lista               varchar2(1) := 'N';
    v_nro_documento       ba_personas.nro_documento%type := fue_obt_nro_doc_persona(p_cod_persona);
    v_est_persona         ba_personas.est_verificacion%type;
    v_pro_activo          varchar2(1);
    v_doc_existe          varchar2(1);
    v_lim_cta             ge_par_dinamicos.parametro%type;
    v_onb_cli             varchar2(1);
    v_asunto              varchar2(100);
    v_txt_mail            varchar2(1000);
    v_cod_err_aux         number;
    v_men_err_aux         varchar2(1000);
    v_direccion           ba_per_dat_adicionales.val_parametro%type;
    v_tip_producto        it.ge_mai_onb_templates.tip_producto%type;
    v_error               number;
    v_mensaje             varchar2(4000);
    v_can_intentos        number(2) := fug_obt_pardinamico('CAN_INTENTOS');
    v_segundos            number(3,1) := to_number(fug_obt_pardinamico('CAN_SEGUNDOS'),'999.99');
    v_es_jubilado         number:=0;
    -- inserta el cliente para control de Limite de Credito
    PROCEDURE pr_ins_lim_cliente(v_nro_cuenta ah_cta_vistas.nro_cuenta%type) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
    
      insert into ge_ing_clientes
        (cod_ing_cliente, cod_persona, nro_cuenta)
      values
        (IT.S_COD_ING_CLIENTE.NEXTVAL, p_cod_persona, v_nro_cuenta);
      commit;
    EXCEPTION
      When others then
        null;
    END;
  
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 9;
    end;
    begin
      v_cod_oficina := fug_obt_ofi_cliente(p_cod_persona);
    exception
      when others then
        v_cod_oficina := fug_obt_pardinamico('COD_OFI_WEB');
    end;
    --verifica si ya es tiempo de volver a consultar la matriz pld
    /* if fl_pld_procesar(p_cod_persona) = 'S' then
       --consultar la matriz pld
       prg_con_mat_pld(p_cod_persona, v_cod_error, v_men_error);
       if v_cod_error != v_pro_correcto then
          v_cod_error := v_err_sql;
          p_men_error := v_men_error;
       end if;
    end if;*/
    
    --Verifico si es jubilado IPS
      begin
        select count(*)
          into v_es_jubilado
          from ba_personas
         where cod_persona = p_cod_persona
         and upper(cod_usu_promotor)='IPS';
      exception
        when others then
          v_es_jubilado := 0;
      end;
    --si el tipo de proceso es t, valida que no posea una cuenta 334.-
    if p_tip_proceso = 'V' then
      
      if v_es_jubilado > 0 then
       v_cod_modalidad := 31;
          
      if p_cod_moneda <> 'GS' then
        v_alta      := 'N';
        v_cod_error := '332';
        p_men_error := 'Solo se permiten altas en Gs.';
      end if;      

      begin
        select est_verificacion
          into v_est_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_est_persona := 'X';
      end;
      if v_est_persona <> 'V' then
        v_alta      := 'N';
        v_cod_error := 331;
        p_men_error := 'La persona no se encuentra verificada.';
      else

        /*Verifico si es un cliente Fielco*/
        prg_cli_onboarding(v_nro_documento,
                           v_doc_existe,
                           v_pro_activo,
                           v_onb_cli);
        if v_pro_activo <> 'S' then
          v_cod_usu_promotor := null;
          v_cod_oficina      := fug_obt_pardinamico('COD_OFI_VIRTUAL');
        end if;

        begin
          select max(ah.nro_cuenta)
            into v_can_nro_cuenta
            from ah_cta_vistas ah, ge_cta_clientes cli
           where ah.nro_cuenta = cli.nro_cuenta
             and cli.relacion = 'P'
             and ah.estado <> 'C'
             and ah.cod_modalidad = v_cod_modalidad
             and cli.cod_persona = p_cod_persona;            
        exception
          when no_data_found then
            begin
              select max(ah.nro_cuenta)
                into v_can_nro_cuenta
                from ah_cta_vistas ah, ge_cta_clientes cli
               where ah.nro_cuenta = cli.nro_cuenta
                 and cli.relacion = 'P'
                 and ah.estado <> 'C'
                 and cli.cod_persona = p_cod_persona
                 and ah.cod_canal = 30
                 and ah.usu_insercion =
                     fue_obt_des_refcodes('USU_ALT_PERSONA',
                                          ah.usu_insercion);
            exception             
              when others then
                v_can_nro_cuenta := '0';
            end;
          when others then
            v_can_nro_cuenta := '0';
        end;

        if v_can_nro_cuenta != '0' then
          v_alta := 'N';
          --v_cod_error := 0;
          p_cod_error := 0;
          p_men_error := 'El Cliente ya posee una cuenta de ahorro BR.';
          begin
            select nro_tarjeta
              into p_nro_tarjeta
              from ah_tar_debitos
             where nro_cuenta = v_can_nro_cuenta
               and cod_persona = p_cod_persona;
          exception
            when others then
              p_nro_tarjeta := null;
          end;
          if p_nro_tarjeta is not null then
            p_nro_tarjeta := lpad(p_nro_tarjeta, 16, '*');
          end if;

          p_nro_cta_ahorro   := v_can_nro_cuenta;
          p_nro_cta_alcancia := null;
        end if;

      end if;
     
     end if;

     if v_es_jubilado = 0 then
       
      if p_cod_moneda <> 'GS' then
        v_alta      := 'N';
        v_cod_error := '332';
        p_men_error := 'Solo se permiten altas en Gs.';
      end if;
    
      v_cod_modalidad := 334;
    
      begin
        select est_verificacion
          into v_est_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_est_persona := 'X';
      end;
      if v_est_persona <> 'V' then
        v_alta      := 'N';
        v_cod_error := 331;
        p_men_error := 'La persona no se encuentra verificada.';
      else
      
        /*Verifico si es un cliente Fielco*/      
      
        prg_cli_onboarding(v_nro_documento,
                           v_doc_existe,
                           v_pro_activo,
                           v_onb_cli);
        if v_pro_activo <> 'S' then
          v_cod_usu_promotor := null;
          v_cod_oficina      := fug_obt_pardinamico('COD_OFI_VIRTUAL');
        end if;
      
        begin
          select ah.nro_cuenta
            into v_can_nro_cuenta
            from ah_cta_vistas ah, ge_cta_clientes cli
           where ah.nro_cuenta = cli.nro_cuenta
             and cli.relacion = 'P'
             and ah.estado <> 'C'
             and ah.cod_modalidad = v_cod_modalidad
             and cli.cod_persona = p_cod_persona
             order by ah.fec_insercion ASC;
        exception
          when too_many_rows then
              v_can_nro_cuenta := v_can_nro_cuenta;
          when no_data_found then
            begin
              select ah.nro_cuenta
                into v_can_nro_cuenta
                from ah_cta_vistas ah, ge_cta_clientes cli
               where ah.nro_cuenta = cli.nro_cuenta
                 and cli.relacion = 'P'
                 and ah.estado <> 'C'
                 and cli.cod_persona = p_cod_persona
                 and ah.cod_canal = 26
                 and ah.usu_insercion =
                     fue_obt_des_refcodes('USU_ALT_PERSONA',
                                          ah.usu_insercion)
                 order by ah.fec_insercion ASC;
            exception
              when too_many_rows then
                v_can_nro_cuenta := v_can_nro_cuenta;
              when others then
                v_can_nro_cuenta := '0';
            end;
          when others then
            v_can_nro_cuenta := '0';
        end;
      
        if v_can_nro_cuenta != '0' then
          v_alta := 'N';
          --v_cod_error := 0;
          p_cod_error := 0;
          p_men_error := 'El Cliente ya posee una cuenta de ahorro BR.';
          begin
            select nro_tarjeta
              into p_nro_tarjeta
              from ah_tar_debitos
             where nro_cuenta = v_can_nro_cuenta
               and cod_persona = p_cod_persona
               and nvl(tar_activa,'N') = 'S'; 
          exception
            when others then
              p_nro_tarjeta := null;
          end;
          if p_nro_tarjeta is not null then
            p_nro_tarjeta := lpad(p_nro_tarjeta, 16, '*');
          end if;
        
          p_nro_cta_ahorro   := v_can_nro_cuenta;
          p_nro_cta_alcancia := null;
        end if;
      end if;
     end if; 
    else
      v_cod_modalidad := 31;
    end if;
  
    if v_alta = 'S' then
      v_err_resultado := fug_ver_firmante(p_cod_persona,
                                          null,
                                          --31,
                                          v_cod_modalidad,
                                          null,
                                          null,
                                          v_err_mensaje);
      if v_err_resultado != v_pro_correcto then
        v_cod_error := v_err_sql;
        p_men_error := v_err_mensaje;
      end if;
    
      -- se valida si el riesgo de la persona esta configurado para aperturar la cuenta de ah/alcancia
      /*if fl_ver_riesgo(p_cod_persona, 31) = 'N' then
         v_cod_error := v_err_sql;
         p_men_error := 'Riesgo no permitido para aperturar cuenta Ahorro para el cliente '||p_cod_persona;
      end if;*/
    
      /*if p_tip_proceso <> 'O' and fu_tie_doc_requerida(p_cod_persona, 3, 31) = 'N' then
         v_cod_error := v_err_sql;
         p_men_error := 'No posee la documentacion necesaria para abrir una cuenta de ahorro Convencional';
      end if;*/
    
      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_tip_persona := 'J';
      end;
    
      /* if v_cod_error = v_pro_correcto and v_tip_persona = 'F' then
        pr_val_reg_negocios ( p_cod_persona, 3, 31, p_cod_moneda, 0, p_tip_proceso, v_cod_error, p_men_error);
      end if;*/
    
      begin
        select distinct 'S', m.cod_mon_bco_central
          into v_exi_moneda, v_cod_mon_bco_central
          from cr_piz_montos p, ba_monedas m
         where p.cod_moneda = p_cod_moneda
           and m.cod_moneda = p.cod_moneda
           and p.cod_modalidad = v_cod_modalidad; --31;
      exception
        when others then
          v_exi_moneda := 'N';
      end;
    
      if ((nvl(v_exi_moneda, 'N') = 'N') or
         (p_tip_proceso = 'O' and p_cod_moneda <> v_cod_mon_local)) and
         v_cod_error = v_pro_correcto then
        v_cod_error := 1003;
        p_men_error := 'Moneda no valida.';
      end if;
    
      begin
        select count(*),
               sum(decode(est_firmante, 'P', 1, 0)),
               sum(decode(relacion, 'Y', 1, 0))
          into v_can_firmante, v_can_pen, v_can_conjunta
          from bw_sol_fir_cuentas
         where cod_persona = p_cod_persona
           and cod_modulo = 3
           and cod_modalidad = v_cod_modalidad --31
           and est_cuenta = 'P';
      exception
        when others then
          v_can_firmante := 0;
          v_can_pen      := 0;
          v_can_conjunta := 0;
      end;
    
      if v_can_firmante > 0 then
        v_tie_sol_firmantes := 'S';
      end if;
    
      /*if v_can_conjunta = 1 and v_tip_persona = 'J' and v_cod_error = v_pro_correcto then
        v_cod_error := 1004;
        p_men_error := 'Debe existir al menos dos firmantes para una cuenta conjunta.';
      end if;*/
    
      if v_can_firmante > 0 and v_can_firmante = v_can_pen and
         v_cod_error = v_pro_correcto then
        --momento en el que realiza la solicitud
        begin
          update bw_sol_fir_cuentas
             set referencia = v_cod_mon_bco_central
           where cod_persona = p_cod_persona
             and cod_modulo = 3
             and cod_modalidad = v_cod_modalidad --31
             and est_firmante = 'P';
        exception
          when others then
            v_cod_error := v_err_sql;
            p_men_error := 'No se ha podido actualizar la Solicitud de Firmantes. ' ||
                           sqlerrm;
        end;
        v_ins_cta := 'N';
        /*elsif v_can_firmante = 0 and v_cod_error = v_pro_correcto and v_tip_persona = 'J' then
        v_cod_error := 1009;
        v_ins_cta := 'N';
        p_men_error := 'Debe ingresar al menos un Firmante.';*/
      end if;
      begin
        select 'S'
          into v_exi_cliente
          from ge_clientes
         where cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_exi_cliente := 'N';
        when others then
          v_cod_error := v_err_sql;
          p_men_error := 'Error al verificar cliente ' || p_cod_persona;
      end;
      if nvl(v_exi_cliente, 'N') = 'N' and
         nvl(v_cod_error, v_pro_correcto) = v_pro_correcto then
        if nvl(it.pag_pla.fu_ins_ge_clientes(p_cod_persona), 'N') <> 'S' then
          v_cod_error := v_err_sql;
          p_men_error := 'No se ha podido insertar cliente';
        end if;
      end if;
    
      if v_ins_cta = 'S' and v_cod_error = v_pro_correcto then
        if v_can_firmante > 0 then
          it.pag_fir.pr_val_sol_fir_cta(p_cod_persona,
                                        3,
                                        --31,
                                        v_cod_modalidad,
                                        v_val_firmante,
                                        v_cod_err_fir,
                                        v_men_err_fir);
          if v_val_firmante = 'N' then
            v_cod_error := v_cod_err_fir;
            p_men_error := v_men_err_fir;
          end if;
        end if;
      
        if v_cod_error = v_pro_correcto then
          if p_tip_proceso = 'O' then
            --v_cod_sub_modalidad := v_cod_sub_mod_rie_baj;
            v_cod_modalidad := v_cod_mod_alc;
          
            begin
              select count(*)
                into v_can_cuentas
                from ge_cta_clientes c, ge_cuentas x
               where c.cod_persona = p_cod_persona
                 and c.relacion = 'P'
                 and c.nro_cuenta = x.nro_cuenta
                 and x.estado not in ('P', 'C');
            exception
              when others then
                v_can_cuentas := 0;
            end;
            if v_can_cuentas > 0 then
              v_cod_error := 1005;
              p_men_error := 'El cliente ya posee cuentas Activas.';
            end if;
            --else
          
            ---v_cod_modalidad := v_cod_mod_alc;
          end if;
        
          v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                                      3,
                                                      v_cod_modalidad,
                                                      p_cod_moneda,
                                                      null);
        end if;
        if v_cod_error = v_pro_correcto then
          -- se prueba hasta 5 intentos -- DA-10146
          for can_intentos in 1..v_can_intentos loop 
             begin
             

                v_nro_cuenta := fug_obt_sig_nro_cuenta(3,
                                                       31,
                                                       v_cod_oficina,
                                                       v_cod_mon_local,
                                                       p_cod_persona);
              exception
                when others then              
                  if can_intentos = v_can_intentos then
                    if sqlcode = '-20054' then  --DA-7883  
                      v_cod_error := 54;
                      p_men_error := 'Error al obtener el numero de cuenta. ' ||sqlerrm;                
                    else                
                      v_cod_error := v_err_sql;
                      p_men_error := 'Error al obtener el numero de cuenta. ' ||sqlerrm;
                    end if;
                  else
                    -- Hacer una espera de N segundos para el reintento
                    sys.dbms_lock.sleep(v_segundos);
                  end if;                
              end;
              if v_nro_cuenta is not null then
                exit;
              end if;
          end loop;
          v_sal_min_pactado := fug_obt_sal_min_pactado(p_cod_moneda,
                                                       p_cod_persona,
                                                       3,
                                                       --31,
                                                       v_cod_modalidad,
                                                       v_cod_oficina);
        
          -- obtener tasa
          begin
            pag_cta.pr_obt_tas_pizarra(3,
                                       --31,
                                       v_cod_modalidad,
                                       p_cod_moneda,
                                       v_tip_capitalizacion * 30,
                                       0,
                                       v_piz_tasa_min,
                                       v_piz_tasa_max,
                                       v_piz_tasa_actual,
                                       v_tip_capitalizacion,
                                       v_cod_sub_modalidad);
          
            pr_obt_tasa(3,
                        --31,
                        v_cod_modalidad,
                        p_cod_moneda,
                        v_cod_oficina,
                        v_fec_actual,
                        v_piz_tasa_actual,
                        v_cod_tasa);
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'Error al obtener la tasa. ' || sqlerrm;
          end;
          if v_cod_error = v_pro_correcto then
            v_denominacion := substr(fue_obt_nom_persona(p_cod_persona),
                                     1,
                                     65);
          
            v_dig_verificador := pag_cta.fu_cal_dig_verifica(v_nro_cuenta);
          
            if v_tip_persona = 'F' then
              v_estado       := 'A'; --abierto
              v_can_firmante := v_can_firmante + 1;
            else
              v_estado := 'X'; --verificacion
            end if;
          
            begin
              insert into ah_cta_vistas
                (nro_cuenta,
                 dig_verificador,
                 cod_modulo,
                 cod_modalidad,
                 cod_oficina,
                 denominacion,
                 cod_moneda,
                 fre_extracto,
                 can_fir_requeridas,
                 can_fir_registradas,
                 fec_apertura,
                 tip_capitalizacion,
                 tas_personalizada,
                 cod_tasa,
                 ret_personalizada,
                 est_batch,
                 estado,
                 nro_folio,
                 fec_cam_estado,
                 sal_ult_capitalizacion,
                 sal_ret_batch,
                 sal_retenido,
                 sal_blo_batch,
                 sal_bloqueado,
                 sal_tot_batch,
                 sal_total,
                 tra_prohibida,
                 cta_combinada,
                 aut_pendiente,
                 mto_deb_pendientes,
                 mto_cre_pendientes,
                 mto_cre_a_confirmar,
                 mto_apertura,
                 cod_canal,
                 reg_firma,
                 cod_sub_modalidad,
                 sal_minimo,
                 cod_usu_promotor)
              values
                (v_nro_cuenta,
                 v_dig_verificador,
                 3,
                 --31,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_denominacion,
                 p_cod_moneda,
                 'M',
                 v_can_firmante,
                 v_can_firmante,
                 v_fec_actual,
                 v_tip_capitalizacion,
                 'N',
                 v_cod_tasa,
                 'N',
                 v_estado,
                 v_estado,
                 0,
                 v_fec_actual,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 'N',
                 'N',
                 'N',
                 0,
                 0,
                 0,
                 0,
                 26,
                 v_denominacion, 
                 v_cod_sub_modalidad,
                 v_sal_min_pactado,
                 v_cod_usu_promotor);
              --p_nro_cta_ahorro := v_nro_cuenta;
            exception
              when others then
                v_cod_error := v_err_sql;
                p_men_error := 'Error al obtener el numero de cuenta. ' ||
                               sqlerrm;
            end;
          
          end if;
        end if;
      
        if v_cod_error = v_pro_correcto then
          begin
            it.pag_fir.pr_ins_fir_cuentas(v_nro_cuenta,
                                          v_dig_verificador,
                                          v_cod_oficina,
                                          p_cod_persona,
                                          3,
                                          --31,
                                          v_cod_modalidad,
                                          v_tie_sol_firmantes,
                                          v_cod_error,
                                          p_men_error);
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'No se puede ingresar la relacion Cuenta-Cliente. ' ||
                             sqlerrm;
          end;
        end if;
      
        if v_cod_error = v_pro_correcto and v_estado = 'A' then
          v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
        
          it.paa_alc.pr_gen_movimientos(v_fec_actual,
                                        1,
                                        v_hora,
                                        401,
                                        3,
                                        --31,
                                        v_cod_modalidad,
                                        v_nro_cuenta,
                                        v_cod_mon_local,
                                        --1,
                                        v_cod_oficina,
                                        v_estado,
                                        401,
                                        null,
                                        null,
                                        null,
                                        'N',
                                        null,
                                        null,
                                        v_cod_error,
                                        p_men_error,
                                        null,
                                        null);
        end if;
        /*Solo crea Alcancia si el tip_proceso es 'O'*/
        if v_cod_error = v_pro_correcto and p_tip_proceso = 'O' then
          begin
            select count(*)
              into v_can_alc
              from ah_cta_vistas v, ge_cta_clientes c
             where c.cod_persona = p_cod_persona
               and v.nro_cuenta = c.nro_cuenta
               and c.relacion = 'P'
               and v.estado not in ('P', 'C')
               and v.cod_modalidad = v_cod_mod_alc;
          exception
            when others then
              v_can_alc := 0;
          end;
          if nvl(v_cod_error, 0) = v_pro_correcto and nvl(v_can_alc, 0) = 0 and
             p_cod_moneda = v_cod_mon_local and v_tip_persona = 'F' then
            pr_cre_cta_alcancia(v_nro_cuenta,
                                v_nro_cta_alcancia,
                                v_cod_error,
                                p_men_error);
            p_nro_cta_alcancia := v_nro_cta_alcancia;
            p_nro_cta_ahorro   := v_nro_cuenta;
          end if;
          if v_cod_error = v_pro_correcto and v_tip_persona = 'J' then
            v_cod_error := v_pro_cor_pen;
          end if;
        elsif nvl(v_ins_cta, 'N') = 'N' and v_cod_error = v_pro_correcto then
          v_cod_error := v_pro_cor_pen;
        end if;
      
        if v_cod_error not in (v_pro_correcto, v_pro_cor_pen) then
          --  rollback;
          prg_ins_log_programas('PAA_PRO.PR_CRE_CTA_ALCANCIA',
                                substr(v_cod_error || ' - ' || p_men_error,
                                       1,
                                       4000),
                                p_cod_persona,
                                v_nro_cuenta);
        else
          -- verificar si existen saldos pendientes a transferir
          it.paa_alc.pr_tra_pen_ahorro(p_cod_persona,
                                       v_nro_cuenta,
                                       v_cod_error,
                                       p_men_error);
        
          if v_cod_error != v_pro_correcto then
            /*por el momento no es un proceso obligatorio*/
            v_cod_error := v_pro_correcto;
            p_men_error := null;
          end if;
        end if;
        -- crear tarjeta de debito
        if p_tip_proceso = 'V' and nvl(v_cod_error, 0) = v_pro_correcto then
        
          -- se inserta el cliente para control del limite
          pr_ins_lim_cliente(v_nro_cuenta);
        
          commit; --guardo los registros de la cuenta creada para pasar como parametro al pat_tgl
          p_nro_cta_ahorro := v_nro_cuenta;
          pat_tgl.pr_cre_cta_global(v_nro_cuenta,
                                    p_cod_persona,
                                    v_cod_error,
                                    p_men_error);
          if nvl(v_cod_error, 0) = v_pro_correcto then
            v_tip_producto := 2;
            begin
              select nro_tarjeta
                into p_nro_tarjeta
                from ah_tar_debitos
               where nro_cuenta = v_nro_cuenta
                 and cod_persona = p_cod_persona
                 and cod_est_solicitud = 0;
            exception
              when others then
                p_nro_tarjeta := null;
            end;
            if p_nro_tarjeta is not null then
              p_nro_tarjeta := lpad(p_nro_tarjeta, 16, '*');
            end if;
            p_nro_cta_ahorro := v_nro_cuenta;
          else
            p_nro_tarjeta := null;
            v_cod_error   := v_err_sql;
            if p_nro_cta_ahorro is not null and p_nro_tarjeta is null then
              p_cod_error := 0;
              p_men_error := 'Cuenta BR creada, No se pudo crear la tarjeta virtual';
            else
              v_cod_error := v_err_sql;
              p_cod_error := v_cod_error;
              p_men_error := 'No se pudo crear la tarjeta virtual';
            end if;
            v_tip_producto := 2;
          end if;
          if v_cod_error = v_pro_correcto then
            begin
              v_lim_cta := fug_obt_pardinamico('ONB_LIM_INICIAL',
                                               3,
                                               v_cod_modalidad,
                                               p_cod_moneda);
            
              pr_ins_alt_producto('P',
                                  p_cod_persona,
                                  'ONB_ALT_PRODUCTOS',
                                  'PROCESADO',
                                  v_cod_error,
                                  v_men_error);
              pr_ins_alt_producto('C',
                                  v_nro_cuenta,
                                  'ONB_CTA_FONDEADA',
                                  'N',
                                  v_cod_error,
                                  v_men_error);
              pr_ins_alt_producto('C',
                                  v_nro_cuenta,
                                  'LIM_CRE_TRANSACCIONES',
                                  v_lim_cta,
                                  v_cod_error,
                                  v_men_error);
              commit;
            exception
              when others then
                v_cod_error := v_err_sql;
                p_men_error := 'Error en insercion de parametros del cliente ' ||
                               sqlerrm;
            end;
          elsif v_cod_error <> v_pro_correcto or p_cod_error is not null then
            if v_nro_cuenta is not null then
              begin
                pr_ins_alt_producto('P',
                                    p_cod_persona,
                                    'ONB_ALT_PRODUCTOS',
                                    'PROCESADO',
                                    v_cod_err_aux,
                                    v_men_err_aux);
              
                pr_ins_alt_producto('C',
                                    v_nro_cuenta,
                                    'ONB_CTA_FONDEADA',
                                    'N',
                                    v_cod_error,
                                    v_men_error);
                v_tip_producto := nvl(v_tip_producto, 1);
              
                v_lim_cta := fug_obt_pardinamico('ONB_LIM_INICIAL',
                                                 3,
                                                 v_cod_modalidad,
                                                 p_cod_moneda);
              
                pr_ins_alt_producto('C',
                                    v_nro_cuenta,
                                    'LIM_CRE_TRANSACCIONES',
                                    v_lim_cta,
                                    v_cod_error,
                                    v_men_error);
              exception
                when others then
                  v_cod_error := v_cod_err_aux;
                  p_men_error := v_men_err_aux;
              end;
            else
              begin
                pr_ins_alt_producto('P',
                                    p_cod_persona,
                                    'ONB_ALT_PRODUCTOS',
                                    'PENDIENTE',
                                    v_cod_err_aux,
                                    v_men_err_aux);
                v_tip_producto := nvl(v_tip_producto, 1);
              exception
                when others then
                  v_cod_error := v_cod_err_aux;
                  p_men_error := v_men_err_aux;
              end;
            end if;
          
            /*Se prepara envio de mail*/
            v_asunto   := 'Error en generacion de productos Global';
            v_txt_mail := 'Fecha/Hora: ' || v_fec_actual || ' ' || v_hora ||
                          chr(10) || 'Proceso: PR_CRE_CTA_AHORRO' ||
                          chr(10) || 'Cod. Persona: ' || p_cod_persona ||
                          chr(10) || 'Nro. Cuenta: ' || v_nro_cuenta ||
                          chr(10) || 'Error: ' || p_men_error || chr(10);
          
            begin
              pr_env_mai_error(v_asunto,
                               v_txt_mail,
                               v_cod_err_aux,
                               v_men_err_aux);
            exception
              when others then
                v_cod_error := v_cod_err_aux;
                p_men_error := v_men_err_aux;
            end;
          end if;
          --Si el cliente es Fielco, incluyo el circuito de cambio de modalidad
          if v_pro_activo = 'S' then
            if paw_cir.fu_ini_circuito(47, v_nro_cuenta, p_cod_persona) <> 0 then
              v_cod_error := v_err_sql;
              p_men_error := 'Error al iniciar el Circuito de Cambio de Modalidad';
            end if;
          end if;
        end if;
      end if;
      if p_cod_error is null then
        p_cod_error := nvl(v_cod_error, v_pro_correcto);
      end if;
      v_direccion := fue_tab_dat_adicional('BA_PERSONAS',
                                           'EMAIL_ONBOARDING',
                                           p_cod_persona);
    
      if nvl(v_direccion, 'X') != 'X' and nvl(v_tip_producto, 0) != 0 then
        pr_env_not_onb_productos(p_cod_persona,
                                 v_nro_documento,
                                 v_direccion,
                                 v_tip_producto,
                                 v_error,
                                 v_mensaje);
      end if;
    end if;
  end;
  --transferencia digital a no clientes-confirmar transferencia
  procedure pr_tra_no_clientes(p_nro_cuenta       ah_cta_vistas.nro_cuenta%type,
                               p_monto            ah_cta_vistas.sal_total%type,
                               p_nom_beneficiario varchar2,
                               p_nro_tel_benef    varchar2,
                               p_concepto         ge_sol_tra_cuentas.concepto%type,
                               p_nro_trans        out number,
                               p_cod_error        out number,
                               p_men_error        out varchar2) is
  
    r_sol_tra_cuentas     ge_sol_tra_cuentas%rowtype;
    v_desc_estado         ge_est_cuentas.descripcion%type;
    v_hora                varchar2(8) := to_char(sysdate, 'hh24:mi:ss');
    v_cod_causa           ge_causales.cod_causa%type := 219;
    v_cod_oficina         ge_movimientos.cod_oficina%type;
    v_nro_secuencia       ge_movimientos.nro_secuencia%type;
    v_cod_modulo          ah_cta_vistas.cod_modulo%type;
    v_cod_modalidad       ah_cta_vistas.cod_modalidad%type;
    v_cod_tra             ge_transacciones.cod_transaccion%type;
    v_nro_documento       ge_bloqueos.nro_documento%type;
    v_fec_fin             date;
    v_cant_dias           number;
    v_fecha               date;
    v_sal_ret             ah_cta_vistas.sal_retenido%type;
    v_sal_retenido        ah_cta_vistas.sal_retenido%type;
    v_mto_cre_pendientes  ah_cta_vistas.mto_cre_pendientes%type;
    v_saldo_disp          ah_cta_vistas.sal_retenido%type;
    v_sal_total           ah_cta_vistas.sal_total%type;
    v_sal_bloqueado       ah_cta_vistas.sal_bloqueado%type;
    v_mto_deb_pendientes  ah_cta_vistas.mto_deb_pendientes%type;
    v_concepto            ge_movimientos.concepto%type;
    v_cod_persona         ba_personas.cod_persona%type;
    v_cod_tra_deb         ge_transacciones.cod_transaccion%type := 503;
    v_cod_tra_cre         ge_transacciones.cod_transaccion%type := 602;
    v_men_error           varchar2(4000);
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type;
    v_est_cuenta          ge_cuentas.estado%type;
    v_sal_disponible      ge_movimientos.monto%type;
    v_procesa             varchar2(1) := 'N';
    v_cta_operativa       ge_cuentas.nro_cuenta%type;
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type := trunc(sysdate);
    v_tie_ctr_duplicacion ge_par_dinamicos.val_parametro%type;
    v_existe              number := 0;
    v_lim_mensual         ge_par_dinamicos.val_parametro%type;
    v_sum_transferencias  ge_movimientos.monto%type;
    v_mod_tra_padre       ge_movimientos.cod_mod_padre%type := 9;
    v_mad_tra_padre       ge_movimientos.cod_mad_padre%type := 91;
    v_inf_json            ba_env_correos.parametros%type;
    v_dir_mai_cliente     ba_tab_dat_adicionales.val_parametro%type;
    v_err_codigo          number;
    v_err_mensaje         varchar2(4000);
    v_nom_cliente         ba_personas.nom_completo%type;
    v_texto               ge_par_dinamicos.val_parametro%type;
    v_link                ge_par_dinamicos.val_parametro%type;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    savepoint transferencia;
    p_cod_error                   := 0;
    v_fecha                       := pag_cal.fu_obt_fec_actual(3);
    r_sol_tra_cuentas.fec_ingreso := v_fecha;
    /*validaciones*/
    v_texto := fug_obt_pardinamico('TXT_SMS_PEN_TRA_CONTACTO');
  
    if nvl(v_texto, '0') = '0' then
      p_cod_error := 1;
      p_men_error := 'No se encuentra configurado parametro "TXT_SMS_PEN_TRA_CONTACTO"';
      v_men_error := p_men_error;
    end if;
  
    v_link := fug_obt_pardinamico('URL_DES_APP');
  
    if nvl(v_link, '0') = '0' then
      p_cod_error := 2;
      p_men_error := 'No se encuentra configurado parametro "URL_DES_APP"';
      v_men_error := p_men_error;
    end if;
    if nvl(p_monto, 0) <= 0 then
      p_cod_error := 999;
      p_men_error := 'El monto debe ser mayor a cero ';
      v_men_error := 'El monto debe ser mayor a cero ' || p_monto;
      return;
    end if;
  
    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_cod_error := 999;
      p_men_error := 'La cuenta debito no puede ser nulo ';
      v_men_error := p_men_error;
      return;
    else
      r_sol_tra_cuentas.nro_cta_debito := p_nro_cuenta;
    end if;
  
    if nvl(p_nom_beneficiario, 'x') = 'x' then
      p_cod_error := 999;
      p_men_error := 'El nombre del beneficiario no puede ser nulo ';
      v_men_error := p_men_error;
      return;
    end if;
  
    if nvl(p_nro_tel_benef, 'x') = 'x' then
      p_cod_error := 999;
      p_men_error := 'El nro de telefono del beneficiario no puede ser nulo ';
      v_men_error := p_men_error;
      return;
    end if;
  
    if nvl(fug_obt_pardinamico('CTA_OPE_TRA_CONTACTO'), 'X') = 'X' then
      p_cod_error := 999;
      p_men_error := 'No se encuentra parametrizado la cuenta operativa en "CTA_OPE_TRA_CONTACTO"';
      v_men_error := p_men_error;
      return;
    else
      v_cta_operativa := fug_obt_pardinamico('CTA_OPE_TRA_CONTACTO');
    end if;
    if nvl(fu_es_conjunta(p_nro_cuenta), 'N') = 'S' then
      p_cod_error := 999;
      p_men_error := 'La cuenta ' || p_nro_cuenta || ' es conjunta';
      v_men_error := p_men_error;
      return;
    end if;
    begin
      select p.cod_persona
        into v_cod_persona
        from ba_personas p, ba_tab_dat_adicionales a
       where a.val_parametro = nvl(p_nro_tel_benef, 'X')
         and a.referencia = p.cod_persona
         and tab_relacion = 'BA_PERSONAS'
         and parametro = 'CELULAR_ONBOARDING';
    exception
      when no_data_found then
        v_cod_persona := 'X';
      when others then
        p_cod_error := 999;
        p_men_error := 'Ocurrio un error al verificar telefono ';
        v_men_error := substr('Ocurrio un error al verificar telefono ' ||
                              p_nro_tel_benef || ' ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
    end;
    if nvl(v_cod_persona, 'X') != 'X' and nvl(p_cod_error, 0) = 0 then
      p_cod_error := 999;
      p_men_error := 'La persona a quien desea transferir ya es un Cliente. ';
      v_men_error := 'La persona a quien desea transferir ya es un Cliente. ' ||
                     v_cod_persona;
    end if;
    v_tie_ctr_duplicacion := fug_obt_pardinamico('TRA_TIE_CTR_DUPLICACION');
    begin
      select count(*)
        into v_existe
        from ge_sol_tra_cuentas s
       where s.nro_telefono = p_nro_tel_benef
         and trunc(s.fec_insercion) = v_fec_valor
         and s.nro_cta_debito = p_nro_cuenta
         and (sysdate - fec_insercion) * 24 * 60 <= v_tie_ctr_duplicacion;
    exception
      when no_data_found then
        v_existe := 0;
      when others then
        p_cod_error := 999;
        p_men_error := 'Ocurrio al verificar si existe movimiento duplicado ';
        v_men_error := substr('Ocurrio al verificar si existe movimiento duplicado  ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
    end;
  
    if nvl(v_existe, 0) > 0 and nvl(p_cod_error, 0) = 0 then
      p_cod_error := 999;
      p_men_error := 'Existe movimiento duplicado ';
      v_men_error := 'Existe movimiento duplicado  ' ||
                     DBMS_UTILITY.format_error_stack || ' - ' ||
                     DBMS_UTILITY.format_error_backtrace;
    end if;
    v_lim_mensual := nvl(fug_obt_pardinamico('LIM_TRA_CONTACTO'), '0');
    if v_lim_mensual = '0' then
      p_cod_error := 999;
      p_men_error := 'No se encuentra parametrizado el monto limite mensual en "LIM_TRA_CONTACTO", verificar!! ';
      v_men_error := p_men_error;
    end if;
    begin
      select sum(s.monto)
        into v_sum_transferencias
        from ge_sol_tra_cuentas s
       where s.nro_telefono = p_nro_tel_benef
         and s.estado in ('P') --estado pendiente
         and trunc(s.fec_insercion) between TRUNC(sysdate, 'MM') and
             TRUNC(LAST_DAY(SYSDATE));
    exception
      when no_data_found then
        v_sum_transferencias := 0;
      when others then
        p_cod_error := 999;
        p_men_error := 'Ocurrio al verificar si existe movimiento duplicado ';
        v_men_error := substr('Ocurrio al verificar si existe movimiento duplicado  ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
    end;
  
    if nvl(v_sum_transferencias, 0) + nvl(p_monto, 0) > v_lim_mensual and
       nvl(p_cod_error, 0) = 0 then
      p_cod_error := 999;
      p_men_error := 'Excedio el limite mensual';
      v_men_error := 'Excedio el limite mensual de ' || v_lim_mensual ||
                     ' para el telefono ' || p_nro_tel_benef;
    
    end if;
  
    if nvl(p_cod_error, 0) = 0 then
    
      v_nro_documento := to_number(to_char(v_fecha, 'RRRRMMDD') ||
                                   it.s_nro_doc.nextval);
      p_nro_trans     := v_nro_documento;
    
    end if;
    pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
    if nvl(pag_cta.G_COD_ERROR, 0) != 0 then
      p_cod_error := pag_cta.g_cod_error;
      p_men_error := pag_cta.g_msj_error;
      v_men_error := p_men_error;
    else
      r_sol_tra_cuentas.cod_persona := pag_cta.G_CTAS.COD_CLIENTE;
      r_sol_tra_cuentas.cod_moneda  := pag_cta.G_CTAS.cod_moneda;
      v_cod_oficina                 := pag_cta.G_CTAS.cod_oficina;
      v_cod_modulo                  := pag_cta.G_CTAS.cod_modulo;
      v_cod_modalidad               := pag_cta.G_CTAS.cod_modalidad;
    end if;
    if pag_cta.G_CTAS.estado in ('T', 'D', 'C', 'P', 'A', 'X') and
       nvl(p_cod_error, 0) = 0 then
      p_cod_error := 999;
      p_men_error := 'La cuenta ' || p_nro_cuenta ||
                     ' se encuentra en el estado ' || pag_cta.G_CTAS.estado ||
                     ' - ' ||
                     fug_obt_des_est_cta(pag_cta.G_CTAS.cod_modulo,
                                         pag_cta.G_CTAS.cod_modalidad,
                                         pag_cta.G_CTAS.estado) ||
                     ', lo que no permite transferir saldo.';
      v_men_error := p_men_error;
    end if;
  
    if p_cod_error = 0 then
      v_cod_ofi_origen := fug_obt_ofi_usuario(USER);
      v_hora           := fu_obt_hora; /*fug_obt_hor_disponible(r_sol_tra_cuentas.fec_ingreso,
                                                                                                         v_hora,
                                                                                                         user,
                                                                                                         'N');*/
      v_concepto       := 'Transferencia Pend. de Onboarding';
      v_nro_secuencia  := 0;
      v_cod_ofi_origen := fug_obt_ofi_usuario(user);
    
      pag_cta.PR_VER_OPERACION(r_sol_tra_cuentas.nro_cta_debito,
                               388,
                               v_mod_tra_padre,
                               v_mad_tra_padre,
                               'D',
                               r_sol_tra_cuentas.cod_moneda,
                               p_monto,
                               v_cod_ofi_origen,
                               v_cod_modulo,
                               v_cod_modalidad,
                               v_est_cuenta,
                               v_sal_disponible,
                               v_procesa,
                               v_cod_tra_deb);
    
      if nvl(pag_cta.g_cod_error, 0) = 0 and nvl(v_procesa, 'N') = 'S' then
        
        pr_ver_horario(v_cod_ofi_origen,
                       v_horario,
                       v_es_mov_noc,
                       v_es_cta_noc,
                       v_fecha,
                       v_fec_valor,
                       p_cod_error,
                       p_men_error);
      
        pag_cta.pr_act_operacion(r_sol_tra_cuentas.nro_cta_debito,
                                 v_hora,
                                 'D',
                                 r_sol_tra_cuentas.cod_moneda,
                                 p_monto,
                                 388,
                                 v_cod_tra_deb,
                                 v_nro_documento,
                                 null,
                                 v_cod_ofi_origen,
                                 v_mod_tra_padre,
                                 v_mad_tra_padre,
                                 null,
                                 null,
                                 v_concepto,
                                 'N',
                                 v_nro_secuencia,
                                 v_fec_valor,
                                 null,
                                 null,
                                 null);
        if nvl(pag_cta.g_cod_error, 0) != 0 then
          p_cod_error := pag_cta.g_cod_error;
          p_men_error := pag_cta.g_msj_error;
          v_men_error := pag_cta.g_msj_error;
        else
          pag_cta.G_CTAS := null;
          pag_cta.PR_OBT_CUENTA(v_cta_operativa);
          pag_cta.pr_act_operacion(v_cta_operativa,
                                   v_hora,
                                   'C',
                                   r_sol_tra_cuentas.cod_moneda,
                                   p_monto,
                                   388,
                                   v_cod_tra_cre,
                                   v_nro_documento,
                                   null,
                                   v_cod_ofi_origen,
                                   v_mod_tra_padre,
                                   v_mad_tra_padre,
                                   null,
                                   null,
                                   v_concepto,
                                   'N',
                                   v_nro_secuencia,
                                   v_fec_valor,
                                   null,
                                   null,
                                   null);
          if nvl(pag_cta.g_cod_error, 0) != 0 then
            p_cod_error := pag_cta.g_cod_error;
            p_men_error := pag_cta.g_msj_error;
            v_men_error := pag_cta.g_msj_error;
          end if;
        end if;
      else
        p_cod_error := pag_cta.g_cod_error;
        p_men_error := pag_cta.g_msj_error;
        v_men_error := substr(pag_cta.g_msj_error ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      end if;
    end if;
  
    if nvl(p_cod_error, 0) = 0 then
      begin
        select t.val_parametro
          into v_cant_dias
          from ge_par_dinamicos t
         where t.parametro = 'GE_CAN_DIA_TRA';
      
      exception
        when no_data_found then
          p_cod_error := 999;
          p_men_error := 'No se encuentra parametrizado la cantidad de dias, verificar parametro "GE_CAN_DIA_TRA" ';
          v_men_error := p_men_error;
        when others then
          p_cod_error := v_err_sql;
          p_men_error := 'Error consultando dias en que quedara activa la transferencia pendiente ';
          v_men_error := substr('Error consultando dias en que quedara activa la transferencia pendiente ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
      v_fec_fin := pag_cal.fu_obt_fec_sig_hab(r_sol_tra_cuentas.fec_ingreso,
                                              1,
                                              v_cant_dias);
    
    end if;
  
    if nvl(p_cod_error, 0) = 0 then
      begin
        insert into ge_sol_tra_cuentas
          (nro_transferencia,
           fec_ingreso,
           monto,
           cod_moneda,
           nro_cta_debito,
           cod_persona,
           nom_beneficiario,
           nro_telefono,
           tipo_doc_benef,
           nro_doc_benef,
           fec_vencimiento,
           concepto)
        values
          (v_nro_documento,
           r_sol_tra_cuentas.fec_ingreso,
           p_monto,
           r_sol_tra_cuentas.cod_moneda,
           r_sol_tra_cuentas.nro_cta_debito,
           r_sol_tra_cuentas.cod_persona,
           upper(p_nom_beneficiario),
           p_nro_tel_benef,
           null,
           null,
           v_fec_fin,
           p_concepto);
      exception
        when others then
          p_cod_error := v_err_sql;
          p_men_error := 'Error insertando la cuenta ' ||
                         r_sol_tra_cuentas.nro_cta_debito ||
                         ' en la tabla ge_sol_tra_cuentas ';
          v_men_error := substr('Error insertando la cuenta ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
      end;
      if nvl(p_cod_error, 0) = 0 then
        begin
          select initcap(f.pri_nombre || ' ' || f.pri_apellido),
                 p.dir_correo
            into v_nom_cliente, v_dir_mai_cliente
            from ba_per_fisicas f, ba_personas p
           where f.cod_persona = r_sol_tra_cuentas.cod_persona
             and f.cod_persona = p.cod_persona;
        exception
          when no_data_found then
            v_men_error := 'No existe cliente cod.persona ' ||
                           r_sol_tra_cuentas.cod_persona;
          when others then
            v_men_error := substr('Ocurrio un error al buscar cliente cod.persona ' ||
                                  r_sol_tra_cuentas.cod_persona ||
                                  ' Error: ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
        end;
        v_inf_json := '{' || '"fec_realizado":' || '"' ||
                      to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') || '"' || ',' ||
                      '"fec_transferencia":' || '"' ||
                      to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') || '"' || ',' ||
                      '"monto":' || '"' ||
                      ltrim(rtrim(to_char(p_monto, '999,999,999,999,999.99'))) || '"' || ',' ||
                      '"nro_transaccion":' || '"' || v_nro_documento || '"' || ',' ||
                      '"nom_cue_debito":' || '"' || v_nom_cliente || '"' || ',' ||
                      '"num_cue_debito":' || '"' || p_nro_cuenta || '"' || ',' ||
                      '"nom_beneficiario":' || '"' || p_nom_beneficiario || '"' || ',' ||
                      '"num_telefono":' || '"' || p_nro_tel_benef || '"' || ',' ||
                      '"notas":' || '"' || p_concepto || '"' || '}';
        if v_inf_json is not null and v_dir_mai_cliente is not null then
          v_err_codigo  := null;
          v_err_mensaje := null;
          begin
          
            IT.PRG_ENV_NOT_SOL_TRA_CUENTA(r_sol_tra_cuentas.cod_persona,
                                          15,
                                          v_inf_json,
                                          v_dir_mai_cliente,
                                          v_err_codigo,
                                          v_err_mensaje);
          exception
            when others then
              v_men_error := substr('Insertar en ba_env_correos al correo ' ||
                                    v_dir_mai_cliente || ' Error: ' ||
                                    v_err_mensaje || ' ' ||
                                    DBMS_UTILITY.format_error_stack ||
                                    ' - ' ||
                                    DBMS_UTILITY.format_error_backtrace,
                                    1,
                                    4000);
          end;
        end if;
        v_texto := replace(replace(v_texto,
                                   '$NOMBRE_CLIENTE',
                                   v_nom_cliente),
                           '$LINK',
                           v_link);
      
        begin
        
          paa_alc.pr_env_not_sms(p_nro_tel_benef,
                                 v_texto,
                                 v_err_codigo,
                                 v_err_mensaje);
        exception
          when others then
            v_men_error := substr('Ocurrio un error al enviar sms al nro. ' ||
                                  p_nro_tel_benef || ' Error: ' ||
                                  v_err_mensaje || ' ' ||
                                  DBMS_UTILITY.format_error_stack || ' - ' ||
                                  DBMS_UTILITY.format_error_backtrace,
                                  1,
                                  4000);
        end;
      end if;
    end if;
  
    if nvl(p_cod_error, 0) != 0 and
       nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      p_nro_trans := null;
      prg_ins_log_programas('PAA_ALC.PR_TRA_NO_CLIENTES',
                            substr('Telefono beneficiario. ' ||
                                   p_nro_tel_benef || ' Error: ' ||
                                   nvl(v_men_error, p_men_error),
                                   1,
                                   4000),
                            r_sol_tra_cuentas.cod_persona,
                            p_nro_cuenta);
      rollback to transferencia;
    elsif v_men_error is not null then
      prg_ins_log_programas('PAA_ALC.PR_TRA_NO_CLIENTES',
                            substr('Telefono beneficiario. ' ||
                                   p_nro_tel_benef || ' Error: ' ||
                                   v_men_error,
                                   1,
                                   4000),
                            r_sol_tra_cuentas.cod_persona,
                            p_nro_cuenta);
    end if;
  exception
    when others then
      p_nro_trans := null;
      p_cod_error := 999;
      p_men_error := 'Error inesperado procesando Transferencia no Clientes ' ||
                     r_sol_tra_cuentas.nro_cta_debito;
      v_men_error := substr('Error inesperado procesando Transferencia no Clientes ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
    
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAA_ALC.PR_TRA_NO_CLIENTES',
                              substr('Telefono beneficiario. ' ||
                                     p_nro_tel_benef || ' Error: ' ||
                                     nvl(v_men_error, p_men_error),
                                     1,
                                     4000),
                              null,
                              p_nro_cuenta);
      end if;
    
  end;

  procedure pr_can_tra_no_cli(p_nro_transf number,
                              p_nro_cuenta varchar2,
                              p_fecha      date,
                              p_cod_canal  varchar2 default 'N',
                              p_cod_error  out number,
                              p_men_error  out varchar2) is
  
    v_cod_tra       ge_movimientos.cod_transaccion%type;
    v_vlbloqu       ge_bloqueos.monto%type;
    v_cod_tra_padre ge_movimientos.cod_transaccion%type;
    v_nro_sec       ge_movimientos.nro_secuencia%type;
    v_hora          ge_movimientos.hora%type;
    v_cdusuar       ge_movimientos.cod_usuario%type;
    v_fcdehoy       ge_movimientos.fecha%type;
    v_vloqueado     ge_bloqueos.monto%type;
    v_nro_caja      ge_movimientos.nro_caja%type;
    v_cod_oficina   ge_movimientos.cod_oficina%type;
  
  begin
    p_cod_error := 0;
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
  
    update ge_sol_tra_cuentas t
       set t.estado = 'C'
     where t.nro_transferencia = p_nro_transf
       and t.fec_ingreso = p_fecha
       and t.nro_cta_debito = p_nro_cuenta
       and t.estado = 'P';
  
    if sql%found then
      begin
        select b.monto
          into v_vlbloqu
          from ge_bloqueos b
         where b.nro_cuenta = p_nro_cuenta
           and b.fec_inicio = p_fecha
           and b.nro_documento = p_nro_transf;
      exception
        when others then
          p_cod_error := v_err_sql;
          p_men_error := 'Error verificando el monto bloqueado ' ||
                         p_nro_cuenta || ' - ' || p_fecha || ' - ' ||
                         p_nro_transf || ' ' || sqlerrm;
      end;
      ---desbloqueo de saldo
      if p_cod_error = 0 then
        /*update ah_cta_vistas
          set sal_bloqueado = nvl(sal_bloqueado, 0) - v_vlbloqu
        where nro_cuenta = p_nro_cuenta;*/
      
        begin
          select val_parametro
            into v_cod_tra
            from ge_par_causales
           where cod_causa = 219
             and parametro = 'COD_CAU_DES_TRANSACCION';
        exception
          when no_data_found then
            v_cod_tra := 507;
        end;
      
        --v_cod_tra_padre := fug_obt_pardinamico('COD_TRA_BLOQUE');
        -----------------------------------------------
        --  genera diario de movimientos             --
        -----------------------------------------------
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
      
        v_nro_sec := nvl(v_nro_sec, 0) + 1;
        v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');
        v_fcdehoy := pag_cal.fu_obt_fec_actual(3);
        v_hora    := fug_obt_hor_disponible(v_fcdehoy,
                                            v_hora,
                                            v_cdusuar,
                                            'N');
        pag_cta.pr_obt_cuenta(p_nro_cuenta);
        /*  insert into ge_movimientos
        (cod_usuario,
         hora,
         nro_secuencia,
         cod_modulo,
         cod_modalidad,
         cod_oficina,
         nro_cuenta,
         cod_moneda,
         fec_valor,
         fecha,
         cod_tra_padre,
         cod_transaccion,
         nro_documento,
         monto,
         estado,
         cod_causa,
         cod_ofi_origen,
         concepto,
         cod_tasa,
         val_tasa,
         reversado,
         cod_usu_reversion,
         hor_reversion,
         emi_aviso,
         protegido,
         cod_mod_padre,
         cod_mad_padre)
        select v_cdusuar,
               v_hora,
               v_nro_sec,
               cod_modulo,
               cod_modalidad,
               cod_oficina,
               p_nro_cuenta,
               cod_moneda,
               v_fcdehoy,
               v_fcdehoy,
               v_cod_tra_padre,
               v_cod_tra,
               p_nro_transf,
               v_vlbloqu,
               'N',
               219,
               cod_oficina,
               null,
               null,
               null,
               'N',
               null,
               null,
               'N',
               'N',
               cod_modulo,
               cod_modalidad
          from ah_cta_vistas
         where nro_cuenta = p_nro_cuenta;*/
        ---movimiento por desbloqueo
      
        pag_cta.pr_act_operacion(p_nro_cuenta,
                                 v_hora,
                                 'D',
                                 pag_cta.g_ctas.cod_moneda,
                                 v_vlbloqu,
                                 317,
                                 v_cod_tra,
                                 p_nro_transf,
                                 null,
                                 pag_cta.g_ctas.cod_oficina,
                                 pag_cta.g_ctas.cod_modulo,
                                 pag_cta.g_ctas.cod_modalidad,
                                 null,
                                 null,
                                 'Desbloqueo Transf. por Onboarding',
                                 'N',
                                 v_nro_sec,
                                 trunc(sysdate),
                                 null,
                                 219,
                                 null);
      
        if nvl(pag_cta.g_cod_error, 0) != 0 then
          p_cod_error := pag_cta.g_cod_error;
          p_men_error := pag_cta.g_msj_error;
        end if;
      
        if nvl(p_cod_error, 0) = 0 then
          pag_cta.pr_act_estado(p_nro_cuenta,
                                'N',
                                v_fcdehoy,
                                v_hora,
                                p_nro_transf,
                                'S');
        end if;
      
        if nvl(pag_cta.g_cod_error, 0) != 0 then
          p_cod_error := pag_cta.g_cod_error;
          p_men_error := pag_cta.g_msj_error;
        end if;
      
        if nvl(p_cod_error, 0) = 0 then
          delete ge_bloqueos b
           where b.nro_cuenta = p_nro_cuenta
             and b.fec_inicio = p_fecha
             and b.nro_documento = p_nro_transf;
        end if;
        /*select av.sal_bloqueado
         into v_vloqueado
         from ah_cta_vistas av
        where nro_cuenta = p_nro_cuenta
          and av.estado = 'S';*/
      
        /*  if nvl(v_vloqueado, 0) = 0 then
          -----------------------------------------------
          --  genera diario de movimientos             --
          -----------------------------------------------
          v_hora := fug_obt_hor_disponible(v_fcdehoy, v_hora, v_cdusuar, 'N');
        
          insert into ge_movimientos
            (cod_usuario,
             hora,
             nro_secuencia,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             nro_cuenta,
             cod_moneda,
             fec_valor,
             fecha,
             cod_tra_padre,
             cod_transaccion,
             est_cuenta,
             estado,
             cod_ofi_origen,
             reversado,
             emi_aviso,
             protegido,
             cod_mod_padre,
             cod_mad_padre)
            select v_cdusuar,
                   v_hora,
                   v_nro_sec + rownum,
                   cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   nro_cuenta,
                   cod_moneda,
                   v_fcdehoy,
                   v_fcdehoy,
                   v_cod_tra_padre,
                   425,-- transaccion por cambio de estado n
                   'N',
                   'N',
                   cod_oficina,
                   'N',
                   'N',
                   'N',
                   cod_modulo,
                   cod_modalidad
              from ah_cta_vistas
             where sal_bloqueado = 0
               and nro_cuenta = p_nro_cuenta
               and estado = 'S';
        
          update ah_cta_vistas
             set estado = 'N', fec_cam_estado = v_fcdehoy
           where sal_bloqueado = 0
             and estado = 'S'
             and nro_cuenta = p_nro_cuenta;
        
        end if;*/
      
      end if;
    end if;
    -------------------------------------------------------
  end;

  procedure pr_env_mai_error(p_asunto    varchar2,
                             p_texto     varchar2,
                             p_cod_error out number,
                             p_men_error out varchar2) is
    v_dir_mail  ge_par_dinamicos.parametro%type := fug_obt_pardinamico('MAI_TAR_SOPORTE');
    v_texto     varchar2(500);
    v_remitente ge_par_generales.dir_correo%type := fug_obt_dir_correo;
  begin
    p_cod_error := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
    if nvl(v_dir_mail, 'X') <> 'X' then
      it_mail.mail(v_remitente, -- quien envia
                   v_dir_mail, -- a quien
                   p_asunto, -- asunto
                   p_texto); -- detalle
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'No se puedo enviar el mail ' || sqlerrm;
  end;

  procedure pr_ins_alt_producto(p_tipo          varchar2,
                                p_indicador     varchar2,
                                p_parametro     varchar2,
                                p_val_parametro varchar2,
                                p_cod_error     out number,
                                p_men_error     out varchar2) is
  begin
    p_cod_error := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
    /*Inserta parametro a nivel persona*/
    if p_tipo = 'P' then
      insert into ba_per_dat_adicionales
        (cod_persona, parametro, val_parametro)
      values
        (p_indicador, p_parametro, p_val_parametro);
      /*Inserta parametro a nivel cuenta*/
    elsif p_tipo = 'C' then
      insert into ge_cta_dat_adicionales
        (nro_cuenta, parametro, val_parametro)
      values
        (p_indicador, p_parametro, p_val_parametro);
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'No se puede insertar el parametro ' || p_parametro || ' ' ||
                     sqlerrm;
  end;

  procedure pr_pro_fondeo(p_nro_documento in varchar2,
                          p_cod_error     out number,
                          p_men_error     out varchar2) is
  
    v_mto_fondeo    ge_par_dinamicos.val_parametro%type;
    v_tra_fondeo    ge_par_dinamicos.val_parametro%type;
    v_nro_secuencia ge_movimientos.nro_secuencia%type;
    v_hora          ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                             'HH24:MI:SS');
    v_fec_actual    ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(3);
    v_existe        varchar2(1);
    v_nro_cuenta    ah_cta_vistas.nro_cuenta%type;
    v_exi_lista     varchar2(1);
    v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
    v_cod_moneda    ba_monedas.cod_moneda%type;
    v_cod_persona   ba_personas.cod_persona%type;
    v_cod_oficina   ba_oficinas.cod_oficina%type;
    v_bloqueo       varchar2(1);
    v_cta_fondeada  varchar2(1);
    v_aut_fondeo    varchar2(1);
    v_lista         varchar2(1) := fug_obt_pardinamico('ONB_VER_WHITELIST');
    v_existe_param  varchar2(1);
    v_cod_error     number := 0;
  
    v_horario    varchar2(1);
    v_es_mov_noc varchar2(1);
    v_es_cta_noc varchar2(1);
    v_fec_valor  ge_calendarios.fec_actual%type;
    v_est_modulo ba_modulos.estado%type := pae_cnf.fu_obt_est_modulo(1);
  
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 3;
    end;
    /*Obtengo los datos de la cuenta*/
    begin
      select ah.nro_cuenta,
             ah.cod_moneda,
             ah.cod_modalidad,
             p.cod_persona,
             ah.cod_oficina
        into v_nro_cuenta,
             v_cod_moneda,
             v_cod_modalidad,
             v_cod_persona,
             v_cod_oficina
        from ge_cta_clientes gc, ah_cta_vistas ah, ba_personas p
       where gc.nro_cuenta = ah.nro_cuenta
         and p.cod_persona = gc.cod_persona
         and gc.relacion = 'P'
         and ah.estado not in ('C', 'F', 'P')
            --and ah.cod_modalidad = 334
         and FUG_OBT_PARADICIONAL(ah.nro_cuenta, 'ONB_CTA_FONDEADA') is not null
         and p.nro_documento = p_nro_documento
         and rownum = 1;
    exception
      when no_data_found then
        begin
          select ah.nro_cuenta,
                 ah.cod_moneda,
                 ah.cod_modalidad,
                 p.cod_persona,
                 ah.cod_oficina
            into v_nro_cuenta,
                 v_cod_moneda,
                 v_cod_modalidad,
                 v_cod_persona,
                 v_cod_oficina
            from ge_cta_clientes gc, ah_cta_vistas ah, ba_personas p
           where gc.nro_cuenta = ah.nro_cuenta
             and p.cod_persona = gc.cod_persona
             and gc.relacion = 'P'
             and ah.estado not in ('C', 'F', 'P')
             and p.nro_documento = p_nro_documento
             and rownum = 1
           order by ah.fec_insercion desc;
        exception
          when others then
            v_cod_error := v_err_sql;
            p_men_error := 'Error al obtener datos de la cuenta ' ||
                           sqlerrm;
        end;
      when others then
        v_cod_error := v_err_sql;
        p_men_error := 'Error al obtener datos de la cuenta ' || sqlerrm;
    end;
    if fug_obt_pardinamico('ONB_ACT_FONDEO', 3, v_cod_modalidad) = 'S' then
    
      /*Verifico que la cuenta no tenga un bloqueo*/
      begin
        Select val_parametro
          into v_bloqueo
          from ge_cta_dat_adicionales
         where parametro = 'BLO_CTA_BAJ_RIESGO'
           and nro_cuenta = v_nro_cuenta;
      exception
        when no_data_found then
          v_bloqueo := 'N';
      end;
    
      /*Verifico que la cuenta no haya tenido un fondeo anterior*/
      begin
        Select val_parametro, 'S'
          into v_cta_fondeada, v_existe_param
          from ge_cta_dat_adicionales
         where parametro = 'ONB_CTA_FONDEADA'
           and nro_cuenta = v_nro_cuenta;
      exception
        when no_data_found then
          v_cta_fondeada := 'N';
          v_existe_param := 'N';
      end;
    
      /*Si la cuenta no esta bloqueada y no tiene un fondeo anterior, se avanza*/
      if v_bloqueo = 'N' and v_cta_fondeada = 'N' then
        if v_lista = 'S' then
          /*Verificar la lista de personas, si esta en la lista v_aut_fondeo = 'S'*/
          begin
            select 'S'
              into v_exi_lista
              from tm_per_lis_blancas a
             where nro_documento = p_nro_documento;
          exception
            when no_data_found then
              v_exi_lista := 'N';
          end;
        
          if v_exi_lista = 'S' then
            v_aut_fondeo := 'S';
          else
            v_aut_fondeo := 'N';
            v_cod_error  := v_err_sql;
            p_men_error  := 'El cliente no se encuentra en la lista blanca.';
          end if;
        
        elsif v_lista = 'N' then
          v_aut_fondeo := 'S';
        end if;
        /*Si autoriza, se hace el fondeo*/
        if v_aut_fondeo = 'S' then
          v_nro_secuencia := '0';
          v_hora          := fug_obt_hor_disponible(v_fec_actual,
                                                    v_hora,
                                                    user,
                                                    'N');
          v_mto_fondeo    := fug_obt_pardinamico('ONB_MON_FONDEO',
                                                 3,
                                                 v_cod_modalidad,
                                                 v_cod_moneda);
          v_tra_fondeo    := fug_obt_pardinamico('ONB_COD_TRANSACCION');
          --verificacion para que realice operaciones nocturnas
          pr_ver_horario(v_cod_oficina,
                         v_horario,
                         v_es_mov_noc,
                         v_es_cta_noc,
                         v_fec_actual,
                         v_fec_valor,
                         p_cod_error,
                         p_men_error);
          --
          begin
            pag_cta.pr_act_operacion(v_nro_cuenta,
                                     v_hora,
                                     'C', --Tip_transaccion
                                     v_cod_moneda,
                                     v_mto_fondeo, --Monto
                                     v_tra_fondeo, --Cod_tra_padre
                                     v_tra_fondeo, --Cod_transaccion
                                     v_cod_persona, --Nro documento
                                     NULL, --Cotizacion
                                     v_cod_oficina, --Cod_oficina
                                     3, --Cod_modulo
                                     v_cod_modalidad, --Modalidad
                                     NULL, ---cod_tasa
                                     NULL, --Val_tasa
                                     'Fondeo Automatico de Cuenta', --Concepto
                                     'S', --Emi aviso
                                     v_nro_secuencia,
                                     v_fec_actual); --Fec_valor
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'Error al realizar fondeo: ' || sqlerrm;
          end;
        
          if v_cod_error = v_pro_correcto then
            begin
              /*Actualizo parametros de fondeo para que en un futuro
              no se fondee nuevamente la cta.*/
              if v_existe_param = 'S' then
                if pag_cta.G_COD_ERROR = 0 then
                  update ge_cta_dat_adicionales
                     set val_parametro = 'S'
                   where parametro = 'ONB_CTA_FONDEADA'
                     and nro_cuenta = v_nro_cuenta;
                else
                  v_cod_error := pag_cta.G_COD_ERROR;
                  p_men_error := pag_cta.G_MSJ_ERROR || ' ' ||
                                 'pag_cta.pr_act_operacion';
                end if;
              elsif v_existe_param = 'N' then
                insert into ge_cta_dat_adicionales
                  (nro_cuenta, parametro, val_parametro)
                values
                  (v_nro_cuenta, 'ONB_CTA_FONDEADA', 'S');
              end if;
            exception
              when others then
                v_cod_error := v_err_sql;
                p_men_error := 'Error al actualizar parametro de fondeo: ' ||
                               sqlerrm;
            end;
          end if;
          /*Si hubo algun error, se carga circuito de fondeo manual*/
          if v_cod_error <> v_pro_correcto then
            if paw_cir.fu_ini_circuito(46, v_cod_persona, v_cod_persona) <> 0 then
              p_men_error := 'Error al iniciar el Circuito de Fondeo Manual';
              v_cod_error := 99;
            end if;
          end if;
        end if;
      else
        v_cod_error := v_err_sql;
        p_men_error := 'El cliente no califica para el fondeo de cuenta.';
      end if;
    end if;
    p_cod_error := v_cod_error;
    if p_cod_error = v_pro_correcto then
      p_men_error := 'Fondeo realizado con exito.';
    end if;
  end;
  procedure pr_env_not_onb_productos(p_cod_persona   in ba_personas.cod_persona%type,
                                     p_nro_documento in ba_personas.nro_documento%type,
                                     p_correo        in ba_tab_dat_adicionales.val_parametro%type,
                                     p_tip_producto  in ba_tab_dat_adicionales.val_parametro%type,
                                     p_cod_error     out number,
                                     p_mensaje       out varchar2) is
    v_nro_documento ba_personas.nro_documento%type;
    v_apodo         tm_per_lis_blancas.apodo%type;
  begin
  
    if p_nro_documento is null then
      begin
        select p.nro_documento
          into v_nro_documento
          from ba_personas p
         where p.cod_persona = p_cod_persona
           and rownum = 1;
      exception
        when no_data_found then
          p_cod_error := 1;
          p_mensaje   := 'No se existe la persona: ' || p_cod_persona;
      end;
    else
      v_nro_documento := p_nro_documento;
    end if;
  
    if nvl(v_nro_documento, '0') != '0' then
      begin
        select l.apodo
          into v_apodo
          from tm_per_lis_blancas l
         where l.nro_documento = v_nro_documento
           and rownum = 1;
      exception
        when no_data_found then
          begin
            select p.pri_nombre
              into v_apodo
              from ba_per_fisicas p
             where p.cod_persona = p_cod_persona
               and rownum = 1;
          exception
            when no_data_found then
              p_cod_error := 1;
              p_mensaje   := 'No se existe la persona: ' || p_cod_persona;
            when others then
              p_cod_error := 2;
              p_mensaje   := 'No se pudo optener datos de la persona  ' ||
                             p_cod_persona;
          end;
      end;
    end if;
  
    if nvl(p_cod_error, 0) = 0 then
      begin
        insert into it.ba_onb_correos
          (cod_persona, apodo, tip_producto, estado, fec_registro)
        values
          (p_cod_persona, v_apodo, p_tip_producto, 'P', sysdate);
        p_cod_error := 0;
      exception
        when others then
          p_cod_error := 99;
          p_mensaje   := substr('Error al insertar correo onb: ' || sqlerrm,
                                1,
                                4000);
      end;
    end if;
  exception
    when others then
      p_cod_error := 99;
      p_mensaje   := substr('Error en el proceso de carga correo onb: ' ||
                            sqlerrm,
                            1,
                            4000);
  end pr_env_not_onb_productos;

  procedure pr_env_not_sms(p_nro_telefono in varchar2,
                           p_texto        in varchar2,
                           p_cod_error    out number,
                           p_men_error    out varchar2) is
    v_url           varchar2(4000);
    v_cod_err_ws    number;
    v_men_error     varchar2(4000);
    v_content       varchar2(4000);
    v_cod_msg_exito number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
    v_men_log       varchar2(4000);
  begin
    if nvl(p_nro_telefono, '0') = '0' then
      p_cod_error := 1;
      p_men_error := 'El nro de telefono no puede ser nulo';
      return;
    end if;
  
    if nvl(p_texto, 'x') = 'x' then
      p_cod_error := 2;
      p_men_error := 'El texto no puede ser nulo';
      return;
    end if;
  
    v_url := fug_obt_pardinamico('WS_URL_ENV_SMS');
    if v_url is not null then
      v_content := '{"phoneNumber": "' || p_nro_telefono || '",
                     "message": "' || p_texto || '"}';
    
      pat_tgl.pr_ws_conector(v_content,
                             v_url,
                             null,
                             null,
                             'M',
                             'POST',
                             v_cod_err_ws,
                             v_men_error); -- llama al web service
      if v_cod_err_ws != v_cod_msg_exito then
        p_cod_error := v_cod_err_ws;
        p_men_error := v_men_error;
        v_men_log   := substr(v_men_error ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      end if;
    
    else
      p_cod_error := 3;
      p_men_error := 'La url no se encuentra definida en el parametro "WS_URL_ENV_SMS"';
    end if;
  
    if nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PAA_ALC.PR_ENV_NOT_SMS',
                            substr('Telefono ' || p_nro_telefono ||
                                   ' Error: ' ||
                                   nvl(v_men_log, p_men_error),
                                   1,
                                   4000),
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 99;
      p_men_error := substr('Error en el proceso de envio sms ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            4000);
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAA_ALC.PR_ENV_NOT_SMS',
                              substr('Telefono ' || p_nro_telefono ||
                                     ' Error: ' ||
                                     nvl(v_men_log, p_men_error),
                                     1,
                                     4000),
                              null,
                              null);
      end if;
  end pr_env_not_sms;

 procedure pr_cre_cta_ah_juridica(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_cod_moneda     in ba_monedas.cod_moneda%type default v_cod_mon_local,
                                  p_cod_onboarding in ba_onb_empresas.cod_onb_emp%type,
                                  p_cod_error      out number,
                                  p_men_error      out varchar2,
                                  p_nro_cta_ahorro out ge_cuentas.nro_cuenta%type) is
 
   v_cod_causa          ge_bloqueos.cod_causa%type := 310;
   v_cod_modalidad      ge_modalidades.cod_modalidad%type := 31; --parametrizar
   v_cod_modulo         ba_modulos.cod_modulo%type:=3;
   v_err_resultado      varchar2(5);
   v_err_mensaje        varchar2(4000);
   v_existe             varchar2(1);
   v_tip_persona        ba_personas.tipo%type;
   v_exi_moneda         varchar(1);
   v_tip_capitalizacion ah_cta_vistas.tip_capitalizacion%type;
   v_nro_cuenta         ge_cuentas.nro_cuenta%type;
   v_cod_oficina        ba_oficinas.cod_oficina%type;
   v_piz_tasa_min       ge_tas_fechas.val_minimo%type;
   v_piz_tasa_max       ge_tas_fechas.val_maximo%type;
   v_piz_tasa_actual    ge_tas_fechas.val_tasa%type;
   v_cod_tasa           ah_cta_vistas.cod_tasa%type;
   v_cod_error          number;
   v_denominacion       ah_cta_vistas.denominacion%type;
   v_dig_verificador    ah_cta_vistas.dig_verificador%type;
   v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
   v_hora               ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                 'HH24:MI:SS');
   v_nrdocum            number; --ba_personas.nro_documento%type;
   v_estado             ah_cta_vistas.estado%type;
   v_sal_min_pactado    ah_cta_vistas.sal_minimo%type;
   v_monto              ah_cta_vistas.sal_minimo%type;
   v_exi_cliente         varchar2(1);
   v_cta_onboarding     ah_cta_vistas.nro_cuenta%type;
   v_est_cta_onb        ah_cta_vistas.estado%type;
   v_can_intentos       number(2) := fug_obt_pardinamico('CAN_INTENTOS');
   v_segundos           number(3,1) := to_number(fug_obt_pardinamico('CAN_SEGUNDOS'),'99.9');
   procedure pr_ver_cta_onboarding(p_cta_onboarding out varchar2, 
                                   p_estado out varchar2) is
     cursor c_ctas is
     select a.nro_cuenta, a.estado
       from ah_cta_vistas a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion = 'P'
        and b.cod_persona = p_cod_persona
        and a.cod_moneda = p_cod_moneda
        and a.estado != 'C'
     order by a.fec_insercion desc;
   begin
     for k in c_ctas loop
       begin
         select c.nro_cuenta 
           into p_cta_onboarding 
           from ge_cta_dat_adicionales c
          where c.nro_cuenta = k.nro_cuenta
            and c.parametro = 'CTA_ONB_EMPRESAS';
       exception
         when no_data_found then
           p_cta_onboarding := null;
       end;
       if p_cta_onboarding is not null then
         p_estado := k.estado;
         exit;
       end if;
     end loop;
   end;
 begin
   BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END; 
   if nvl(p_cod_persona, 'x') = 'x' then
     v_cod_error := 1;
     p_men_error := 'Codigo de Persona nulo';
     return;
   end if;
   if nvl(p_cod_moneda, 'x') = 'x' then
     v_cod_error := 2;
     p_men_error := 'Codigo de moneda nulo';
     return;
   end if;
   --verificar si existe la persona en la base
   begin
     select 'S', p.tipo --, p.nro_documento
       into v_existe, v_tip_persona --, v_nrdocum
       from ba_personas p
      where p.cod_persona = p_cod_persona;
   exception
     when no_data_found then
       v_existe    := 'N';
       v_cod_error := 3;
       p_men_error := 'No existe código de persona en el Sistema';
   end;
   if nvl(v_tip_persona, '') != 'J' then
     v_cod_error := 4;
     p_men_error := 'Tipo de Persona no es Jurídica';
   end if;
   if nvl(v_cod_error, 0) = v_pro_correcto then
     --verifica que la persona no este inhibida
     v_err_resultado := fug_ver_firmante(p_cod_persona,
                                         3,
                                         v_cod_modalidad,
                                         null,
                                         null,
                                         v_err_mensaje);
     if v_err_resultado != v_pro_correcto then
       v_cod_error := v_err_sql;
       p_men_error := v_err_mensaje;
     end if;
   end if;
   begin
     select distinct 'S'
       into v_exi_moneda
       from cr_piz_montos p, ba_monedas m
      where p.cod_moneda = p_cod_moneda
        and m.cod_moneda = p.cod_moneda
        and p.cod_modalidad = v_cod_modalidad;
   exception
     when others then
       v_exi_moneda := 'N';
   end;
 
   If nvl(v_exi_moneda, 'N') = 'N' then
     v_cod_error := 5;
     p_men_error := 'Moneda no configurada para la modalidad';
   end if;
   --
   begin
     select 'S'
       into v_exi_cliente
       from ge_clientes
      where cod_persona = p_cod_persona;
   exception
     when no_data_found then
       v_exi_cliente := 'N';
     when others then
       v_cod_error := v_err_sql;
       p_men_error := 'Error al verificar cliente ' || p_cod_persona;
   end;
   if nvl(v_exi_cliente, 'N') = 'N' and
      nvl(v_cod_error, 0) = v_pro_correcto then
     if nvl(it.pag_pla.fu_ins_ge_clientes(p_cod_persona), 'N') <> 'S' then
       v_cod_error := v_err_sql;
       p_men_error := 'No se ha podido insertar cliente';
     end if;
   end if;
   --   
   if nvl(v_cod_error, 0) = v_pro_correcto then
     v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                                 3,
                                                 v_cod_modalidad,
                                                 p_cod_moneda,
                                                 null);
     v_cod_oficina        := fug_obt_pardinamico('COD_OFI_VIRTUAL');
     pr_ver_cta_onboarding(v_cta_onboarding, v_est_cta_onb);
     if v_cta_onboarding is null then
       for can_intentos in 1..v_can_intentos loop
             begin
               v_nro_cuenta := fug_obt_sig_nro_cuenta(3,
                                                      v_cod_modalidad,
                                                      v_cod_oficina,
                                                      p_cod_moneda,
                                                      p_cod_persona);
             exception
               when others then
                  if can_intentos = v_can_intentos then
                     if sqlcode = '-20054' then 
                        v_cod_error := 54;
                        p_men_error := 'Error al obtener el numero de cuenta. ' ||sqlerrm;                
                     else                
                        v_cod_error := v_err_sql;
                        p_men_error := 'Error al obtener el numero de cuenta. ' ||sqlerrm;
                     end if;
                  else
                     -- Hacer una espera de N segundos para el reintento
                     sys.dbms_lock.sleep(v_segundos);
                  end if;
             end;
                  if v_nro_cuenta is not null then
                     exit;
                  end if;
       end loop;
     end if;
     -- obtener tasa
     v_sal_min_pactado := fug_obt_sal_min_pactado(p_cod_moneda,
                                                  p_cod_persona,
                                                  3,
                                                  v_cod_modalidad,
                                                  v_cod_oficina,
                                                  v_cod_sub_modalidad);
   
     -- obtener tasa
     begin
       if p_cod_moneda = v_cod_mon_local then 
         v_monto := 0;
       else
         v_monto := v_sal_min_pactado;
         v_tip_capitalizacion := 3; --capitalización USD
       end if;
       pag_cta.pr_obt_tas_pizarra(3,
                                  v_cod_modalidad,
                                  p_cod_moneda,
                                  v_tip_capitalizacion * 30,
                                  v_monto,
                                  v_piz_tasa_min,
                                  v_piz_tasa_max,
                                  v_piz_tasa_actual,
                                  v_tip_capitalizacion,
                                  v_cod_sub_modalidad);
     
       pr_obt_tasa(3,
                   v_cod_modalidad,
                   p_cod_moneda,
                   v_cod_oficina,
                   v_fec_actual,
                   v_piz_tasa_actual,
                   v_cod_tasa);
     exception
       when others then
         v_cod_error := v_err_sql;
         p_men_error := 'Error al obtener la tasa. ' || sqlerrm;
     end;
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
       v_denominacion    := substr(fue_obt_nom_persona(p_cod_persona),
                                   1,
                                   65);
       v_dig_verificador := pag_cta.fu_cal_dig_verifica(v_nro_cuenta);
       v_estado          := 'X'; --Verificación
       begin
         insert into ah_cta_vistas
           (nro_cuenta,
            dig_verificador,
            cod_modulo,
            cod_modalidad,
            cod_oficina,
            denominacion,
            cod_moneda,
            fre_extracto,
            fec_apertura,
            tip_capitalizacion,
            tas_personalizada,
            cod_tasa,
            ret_personalizada,
            est_batch,
            estado,
            nro_folio,
            fec_cam_estado,
            sal_ult_capitalizacion,
            sal_ret_batch,
            sal_retenido,
            sal_blo_batch,
            sal_bloqueado,
            sal_tot_batch,
            sal_total,
            tra_prohibida,
            cta_combinada,
            aut_pendiente,
            mto_deb_pendientes,
            mto_cre_pendientes,
            mto_cre_a_confirmar,
            mto_apertura,
            reg_firma)
         values
           (v_nro_cuenta,
            v_dig_verificador,
            3,
            v_cod_modalidad,
            v_cod_oficina,
            v_denominacion,
            p_cod_moneda,
            'M',
            v_fec_actual,
            v_tip_capitalizacion,
            'N',
            v_cod_tasa,
            'N',
            v_estado,
            v_estado,
            0,
            v_fec_actual,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            'N',
            'N',
            'N',
            0,
            0,
            0,
            0,
            v_denominacion);
       exception
         when others then
           v_cod_error := v_err_sql;
           p_men_error := 'Error al insertar la cuenta. ' || sqlerrm;
       end;
       --
       begin
         insert into ge_cta_dat_adicionales(nro_cuenta, parametro, val_parametro)
         values(v_nro_cuenta, 'CTA_ONB_EMPRESAS', 'S');
       exception
         when others then
           v_cod_error := v_err_sql;
           p_men_error := 'Error al insertar en ge_cta_dat_adicionales. ' || sqlerrm;
       end;
     end if;
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
          begin
            insert into ge_cta_clientes
              (cod_persona,
               nro_cuenta,
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               relacion)
            values
              (p_cod_persona,
               v_nro_cuenta,
               v_dig_verificador,
               v_cod_oficina,
               3,
               v_cod_modalidad,
               'P');
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'No se puede ingresar la relacion Cuenta-Cliente. ' ||
                             sqlerrm;
          end;
        end if;
     /*
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
       v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
     
       it.paa_alc.pr_gen_movimientos(v_fec_actual,
                                     1,
                                     v_hora,
                                     408,
                                     3,
                                     v_cod_modalidad,
                                     v_nro_cuenta,
                                     p_cod_moneda,
                                     v_cod_oficina,
                                     v_estado,
                                     408,
                                     null,
                                     null,
                                     null,
                                     'N',
                                     null,
                                     null,
                                     v_cod_error,
                                     p_men_error,
                                     null,
                                     null);
     
       BEGIN
         --asignar secuencia al nro de documento
         if v_nrdocum is null then
           begin
             select s_nro_bloqueo.nextval into v_nrdocum from dual;
           exception
             when others then
               p_men_error := substr('Sec. Bloqueo ' || sqlerrm, 1, 4000);
               v_cod_error := 8;
           end;
         end if;
         insert into ge_bloqueos
           (nro_cuenta,
            nro_documento,
            fec_inicio,
            hor_inicio,
            cod_causa,
            tipo,
            observacion)
         values
           (v_nro_cuenta,
            v_nrdocum,
            v_fec_actual,
            v_hora,
            v_cod_causa,
            'T',
            'BLOQ. ONB EMPRESA SIN VERIFICAR');
       EXCEPTION
         when others then
           p_men_error := substr('Error al insertar en GE_BLOQUEOS- ' ||
                                 sqlerrm,
                                 1,
                                 4000);
           v_cod_error := 7;
       END;
     end if;
     */
   end if;
   if v_cta_onboarding is not null then
     if v_est_cta_onb = 'C' then
       p_nro_cta_ahorro := null;
     /*DA-8902*/
       p_cod_error  := 99;
       p_men_error  := 'Cuenta Onboarding cancelada';
     else
       p_nro_cta_ahorro := v_cta_onboarding;
     end if;
     
      if p_cod_moneda = 'GS' then
        --Se actualiza la tabla ba_onb_empresas cuenta GS
       update ba_onb_empresas t
          set t.cta_guaranies = v_cta_onboarding
        where t.cod_onb_emp = p_cod_onboarding;
      else
        --Se actualiza la tabla ba_onb_empresas cuenta USD
        update ba_onb_empresas t
           set t.cta_dolares = v_cta_onboarding
         where t.cod_onb_emp = p_cod_onboarding;
      end if;
     
     p_cod_error      := 0;
     p_men_error      := p_men_error;
   elsif nvl(v_cod_error, 0) = v_pro_correcto then
      if p_cod_moneda = 'GS' then
        --Se actualiza la tabla ba_onb_empresas cuenta GS
       update ba_onb_empresas t
          set t.cta_creada = 'S', t.cta_guaranies = v_nro_cuenta
        where t.cod_onb_emp = p_cod_onboarding;
      else
        --Se actualiza la tabla ba_onb_empresas cuenta USD
        update ba_onb_empresas t
           set t.cta_creada = 'S', t.cta_dolares = v_nro_cuenta
         where t.cod_onb_emp = p_cod_onboarding;
      end if;
   
     p_nro_cta_ahorro := v_nro_cuenta;
     p_cod_error      := 0;
     p_men_error      := 'OK';
   else
     p_cod_error := v_cod_error;
   end if;
 end;
 
 procedure pr_cre_cta_ah_juridica_mipymes(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_cod_moneda     in ba_monedas.cod_moneda%type default v_cod_mon_local,
                                  p_cod_onboarding in ba_onb_empresas.cod_onb_emp%type,
                                  p_cod_error      out number,
                                  p_men_error      out varchar2,
                                  p_nro_cta_ahorro out ge_cuentas.nro_cuenta%type) is
 
   v_cod_causa          ge_bloqueos.cod_causa%type := 310;
   v_cod_modalidad      ge_modalidades.cod_modalidad%type := 334; --parametrizar
   v_cod_sub_modalidad  ge_modalidades.cod_modalidad%type := 2;   --parametrizar
   v_cod_modulo         ba_modulos.cod_modulo%type:=3;
   v_err_resultado      varchar2(5);
   v_err_mensaje        varchar2(4000);
   v_existe             varchar2(1);
   v_tip_persona        ba_personas.tipo%type;
   v_exi_moneda         varchar(1);
   v_tip_capitalizacion ah_cta_vistas.tip_capitalizacion%type;
   v_nro_cuenta         ge_cuentas.nro_cuenta%type;
   v_cod_oficina        ba_oficinas.cod_oficina%type;
   v_piz_tasa_min       ge_tas_fechas.val_minimo%type;
   v_piz_tasa_max       ge_tas_fechas.val_maximo%type;
   v_piz_tasa_actual    ge_tas_fechas.val_tasa%type;
   v_cod_tasa           ah_cta_vistas.cod_tasa%type;
   v_cod_error          number;
   v_denominacion       ah_cta_vistas.denominacion%type;
   v_dig_verificador    ah_cta_vistas.dig_verificador%type;
   v_fec_actual         ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
   v_hora               ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                 'HH24:MI:SS');
   v_nrdocum            number; --ba_personas.nro_documento%type;
   v_estado             ah_cta_vistas.estado%type;
   v_sal_min_pactado    ah_cta_vistas.sal_minimo%type;
   v_monto              ah_cta_vistas.sal_minimo%type;
   v_exi_cliente         varchar2(1);
   v_cta_onboarding     ah_cta_vistas.nro_cuenta%type;
   v_est_cta_onb        ah_cta_vistas.estado%type;
   v_can_intentos       number(2) := fug_obt_pardinamico('CAN_INTENTOS');
   v_segundos           number(3,1) := to_number(fug_obt_pardinamico('CAN_SEGUNDOS'),'99.9');
   procedure pr_ver_cta_onboarding(p_cta_onboarding out varchar2, 
                                   p_estado out varchar2) is
     cursor c_ctas is
     select a.nro_cuenta, a.estado
       from ah_cta_vistas a, ge_cta_clientes b
      where a.nro_cuenta = b.nro_cuenta
        and b.relacion = 'P'
        and b.cod_persona = p_cod_persona
        and a.cod_moneda = p_cod_moneda
        and a.estado != 'C'
     order by a.fec_insercion desc;
   begin
     for k in c_ctas loop
       begin
         select c.nro_cuenta 
           into p_cta_onboarding 
           from ge_cta_dat_adicionales c
          where c.nro_cuenta = k.nro_cuenta
            and c.parametro = 'CTA_ONB_EMPRESAS';
       exception
         when no_data_found then
           p_cta_onboarding := null;
       end;
       if p_cta_onboarding is not null then
         p_estado := k.estado;
         exit;
       end if;
     end loop;
   end;
 begin
   BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END; 
   if nvl(p_cod_persona, 'x') = 'x' then
     v_cod_error := 1;
     p_men_error := 'Codigo de Persona nulo';
     return;
   end if;
   if nvl(p_cod_moneda, 'x') = 'x' then
     v_cod_error := 2;
     p_men_error := 'Codigo de moneda nulo';
     return;
   end if;
   --verificar si existe la persona en la base
   begin
     select 'S', p.tipo --, p.nro_documento
       into v_existe, v_tip_persona --, v_nrdocum
       from ba_personas p
      where p.cod_persona = p_cod_persona;
   exception
     when no_data_found then
       v_existe    := 'N';
       v_cod_error := 3;
       p_men_error := 'No existe código de persona en el Sistema';
   end;
   if nvl(v_tip_persona, '') != 'J' then
     v_cod_error := 4;
     p_men_error := 'Tipo de Persona no es Jurídica';
   end if;
   if nvl(v_cod_error, 0) = v_pro_correcto then
     --verifica que la persona no este inhibida
     v_err_resultado := fug_ver_firmante(p_cod_persona,
                                         3,
                                         v_cod_modalidad,
                                         null,
                                         null,
                                         v_err_mensaje);
     if v_err_resultado != v_pro_correcto then
       v_cod_error := v_err_sql;
       p_men_error := v_err_mensaje;
     end if;
   end if;
   begin
     select distinct 'S'
       into v_exi_moneda
       from cr_piz_montos p, ba_monedas m
      where p.cod_moneda = p_cod_moneda
        and m.cod_moneda = p.cod_moneda
        and p.cod_modalidad = v_cod_modalidad;
   exception
     when others then
       v_exi_moneda := 'N';
   end;
 
   If nvl(v_exi_moneda, 'N') = 'N' then
     v_cod_error := 5;
     p_men_error := 'Moneda no configurada para la modalidad';
   end if;
   --
   begin
     select 'S'
       into v_exi_cliente
       from ge_clientes
      where cod_persona = p_cod_persona;
   exception
     when no_data_found then
       v_exi_cliente := 'N';
     when others then
       v_cod_error := v_err_sql;
       p_men_error := 'Error al verificar cliente ' || p_cod_persona;
   end;
   if nvl(v_exi_cliente, 'N') = 'N' and
      nvl(v_cod_error, 0) = v_pro_correcto then
     if nvl(it.pag_pla.fu_ins_ge_clientes(p_cod_persona), 'N') <> 'S' then
       v_cod_error := v_err_sql;
       p_men_error := 'No se ha podido insertar cliente';
     end if;
   end if;
   --   
   if nvl(v_cod_error, 0) = v_pro_correcto then
     v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                                 3,
                                                 v_cod_modalidad,
                                                 p_cod_moneda,
                                                 null);
     v_cod_oficina        := fug_obt_pardinamico('COD_OFI_VIRTUAL');
     pr_ver_cta_onboarding(v_cta_onboarding, v_est_cta_onb);
     if v_cta_onboarding is null then

        begin
          select 611||s_sig_nro_cta_mad_31.nextval into v_nro_cuenta from dual;
        exception
          when others then
            p_men_error := substr('Error al obtener el numero de cuenta. ' || sqlerrm, 1, 4000);
            v_cod_error := 8;
        end;
       
      
     end if;
     -- obtener tasa
     v_sal_min_pactado := fug_obt_sal_min_pactado(p_cod_moneda,
                                                  p_cod_persona,
                                                  3,
                                                  v_cod_modalidad,
                                                  v_cod_oficina,
                                                  v_cod_sub_modalidad);
   
     -- obtener tasa
     begin
       if p_cod_moneda = v_cod_mon_local then 
         v_monto := 0;
       else
         v_monto := v_sal_min_pactado;
         v_tip_capitalizacion := 3; --capitalización USD
       end if;
       pag_cta.pr_obt_tas_pizarra(3,
                                  v_cod_modalidad,
                                  p_cod_moneda,
                                  v_tip_capitalizacion * 30,
                                  v_monto,
                                  v_piz_tasa_min,
                                  v_piz_tasa_max,
                                  v_piz_tasa_actual,
                                  v_tip_capitalizacion,
                                  v_cod_sub_modalidad);
     
       pr_obt_tasa(3,
                   v_cod_modalidad,
                   p_cod_moneda,
                   v_cod_oficina,
                   v_fec_actual,
                   v_piz_tasa_actual,
                   v_cod_tasa);
     exception
       when others then
         v_cod_error := v_err_sql;
         p_men_error := 'Error al obtener la tasa. ' || sqlerrm;
     end;
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
       v_denominacion    := substr(fue_obt_nom_persona(p_cod_persona),
                                   1,
                                   65);
       v_dig_verificador := pag_cta.fu_cal_dig_verifica(v_nro_cuenta);
       v_estado          := 'X'; --Verificación
       begin
         insert into ah_cta_vistas
           (nro_cuenta,
            dig_verificador,
            cod_modulo,
            cod_modalidad,
            cod_oficina,
            denominacion,
            cod_moneda,
            fre_extracto,
            fec_apertura,
            tip_capitalizacion,
            tas_personalizada,
            cod_tasa,
            ret_personalizada,
            est_batch,
            estado,
            nro_folio,
            fec_cam_estado,
            sal_ult_capitalizacion,
            sal_ret_batch,
            sal_retenido,
            sal_blo_batch,
            sal_bloqueado,
            sal_tot_batch,
            sal_total,
            tra_prohibida,
            cta_combinada,
            aut_pendiente,
            mto_deb_pendientes,
            mto_cre_pendientes,
            mto_cre_a_confirmar,
            mto_apertura,
            reg_firma,
            cod_sub_modalidad)
         values
           (v_nro_cuenta,
            v_dig_verificador,
            3,
            v_cod_modalidad,
            v_cod_oficina,
            v_denominacion,
            p_cod_moneda,
            'M',
            v_fec_actual,
            v_tip_capitalizacion,
            'N',
            v_cod_tasa,
            'N',
            v_estado,
            v_estado,
            0,
            v_fec_actual,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            'N',
            'N',
            'N',
            0,
            0,
            0,
            0,
            v_denominacion,
            v_cod_sub_modalidad);
       exception
         when others then
           v_cod_error := v_err_sql;
           p_men_error := 'Error al insertar la cuenta. ' || sqlerrm;
       end;
       --
       begin
         insert into ge_cta_dat_adicionales(nro_cuenta, parametro, val_parametro)
         values(v_nro_cuenta, 'CTA_ONB_EMPRESAS', 'S');
       exception
         when others then
           v_cod_error := v_err_sql;
           p_men_error := 'Error al insertar en ge_cta_dat_adicionales. ' || sqlerrm;
       end;
       
       --lIMITE DE CREDITO
      begin
         insert into ge_cta_dat_adicionales(nro_cuenta, parametro, val_parametro)
         values(v_nro_cuenta, 'LIM_CRE_TRANSACCIONES', '57980960');
       exception
         when others then
           v_cod_error := v_err_sql;
           p_men_error := 'Error al insertar en ge_cta_dat_adicionales Limite de Credito. ' || sqlerrm;
       end;
       
     end if;
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
          begin
            insert into ge_cta_clientes
              (cod_persona,
               nro_cuenta,
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               relacion)
            values
              (p_cod_persona,
               v_nro_cuenta,
               v_dig_verificador,
               v_cod_oficina,
               3,
               v_cod_modalidad,
               'P');
          exception
            when others then
              v_cod_error := v_err_sql;
              p_men_error := 'No se puede ingresar la relacion Cuenta-Cliente. ' ||
                             sqlerrm;
          end;
        end if;
     /*
     if nvl(v_cod_error, 0) = v_pro_correcto and v_cta_onboarding is null then
       v_hora := fug_obt_hor_disponible(v_fec_actual, v_hora, user, 'N');
     
       it.paa_alc.pr_gen_movimientos(v_fec_actual,
                                     1,
                                     v_hora,
                                     408,
                                     3,
                                     v_cod_modalidad,
                                     v_nro_cuenta,
                                     p_cod_moneda,
                                     v_cod_oficina,
                                     v_estado,
                                     408,
                                     null,
                                     null,
                                     null,
                                     'N',
                                     null,
                                     null,
                                     v_cod_error,
                                     p_men_error,
                                     null,
                                     null);
     
       BEGIN
         --asignar secuencia al nro de documento
         if v_nrdocum is null then
           begin
             select s_nro_bloqueo.nextval into v_nrdocum from dual;
           exception
             when others then
               p_men_error := substr('Sec. Bloqueo ' || sqlerrm, 1, 4000);
               v_cod_error := 8;
           end;
         end if;
         insert into ge_bloqueos
           (nro_cuenta,
            nro_documento,
            fec_inicio,
            hor_inicio,
            cod_causa,
            tipo,
            observacion)
         values
           (v_nro_cuenta,
            v_nrdocum,
            v_fec_actual,
            v_hora,
            v_cod_causa,
            'T',
            'BLOQ. ONB EMPRESA SIN VERIFICAR');
       EXCEPTION
         when others then
           p_men_error := substr('Error al insertar en GE_BLOQUEOS- ' ||
                                 sqlerrm,
                                 1,
                                 4000);
           v_cod_error := 7;
       END;
     end if;
     */
   end if;
   if v_cta_onboarding is not null then
     if v_est_cta_onb = 'C' then
       p_nro_cta_ahorro := null;
     /*DA-8902*/
       p_cod_error  := 99;
       p_men_error  := 'Cuenta Onboarding cancelada';
     else
       p_nro_cta_ahorro := v_cta_onboarding;
     end if;
     
      if p_cod_moneda = 'GS' then
        --Se actualiza la tabla ba_onb_empresas cuenta GS
       update ba_onb_empresas t
          set t.cta_guaranies = v_cta_onboarding
        where t.cod_onb_emp = p_cod_onboarding;
      else
        --Se actualiza la tabla ba_onb_empresas cuenta USD
        update ba_onb_empresas t
           set t.cta_dolares = v_cta_onboarding
         where t.cod_onb_emp = p_cod_onboarding;
      end if;
     
     p_cod_error      := 0;
     p_men_error      := p_men_error;
   elsif nvl(v_cod_error, 0) = v_pro_correcto then
      if p_cod_moneda = 'GS' then
        --Se actualiza la tabla ba_onb_empresas cuenta GS
       update ba_onb_empresas t
          set t.cta_creada = 'S', t.cta_guaranies = v_nro_cuenta
        where t.cod_onb_emp = p_cod_onboarding;
      else
        --Se actualiza la tabla ba_onb_empresas cuenta USD
        update ba_onb_empresas t
           set t.cta_creada = 'S', t.cta_dolares = v_nro_cuenta
         where t.cod_onb_emp = p_cod_onboarding;
      end if;
   
     p_nro_cta_ahorro := v_nro_cuenta;
     p_cod_error      := 0;
     p_men_error      := 'OK';
   else
     p_cod_error := v_cod_error;
   end if;
 end;

 
end paa_alc;
/
