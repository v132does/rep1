create or replace package body it.paa_cah is
  --creación de cuentas de ahorro desde app modulo 3 modalidad 31 con sub modalidades 1,26,27
  --creación de cuentas de ahorro desde app modulo 3 modalidad 334 con sub modalidades 1
   v_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%TYPE := fug_obt_pardinamico('COD_SUB_MAD_AHO_VISTA');

 procedure pr_ins_alt_producto( p_indicador     varchar2,
                                p_parametro     varchar2,
                                p_val_parametro varchar2,
                                p_cod_error     out number,
                                p_men_error     out varchar2) is
  begin
    p_cod_error := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
      insert into ge_cta_dat_adicionales
        (nro_cuenta, parametro, val_parametro)
      values
        (p_indicador, p_parametro, p_val_parametro);
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'No se puede insertar el parametro ' || p_parametro || ' ' ||
                     sqlerrm;
  end;

  function fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type)
    return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;
  
  begin
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;
  
    v_nro_sec  := fue_obt_sig_secuencia('S_SER_USER_ACCOUNTS');
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO',
                                              v_nro_user,
                                              p_tip_user);
    return v_user;
  end;

  function fu_obt_hora(p_cod_usuario varchar2) return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;
    
  begin
    if upper(substr(p_cod_usuario, -1)) = 'S' then
      v_ind_usuario := 0;
    else
      v_ind_usuario := substr(p_cod_usuario, -1);
    end if;
    
    if v_ind_usuario > 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movi' || v_ind_usuario);
    elsif v_ind_usuario = 0 then
      v_nro_sec := fue_obt_sig_secuencia('s_hor_movi');
    end if;
    
    v_nro_hor := mod(v_nro_sec, 86400);
    
    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');
    
    return v_hora;
  end fu_obt_hora;


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
    v_usuario ba_usuarios.cod_usuario%type;
    v_hora ge_movimientos.hora%type;
    v_es_nocturno char:='N';
  begin
    p_cod_error := 0;
    --- cargar registro de movimiento
    v_usuario:=fu_obt_mov_user('ACCOUNTS');
    v_hora:=fu_obt_hora(v_usuario);
    r_gmovi.cod_usuario     := nvl(v_usuario, user);--nvl(p_cod_usuario, user);
    r_gmovi.hora            := v_hora;
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
    
    if pae_cnf.fu_obt_est_modulo(p_cod_modulo) != 2 then
      v_es_nocturno:='S';
    else
      v_es_nocturno:='N';
    end if;
    
    pag_gen.pr_ins_ge_movimiento(r_gmovi,v_es_nocturno);
    
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'No se puede ingresar el Movimiento ' || SQLERRM||'-BACKTRACE:'||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
  end;

  -- creacion de una nueva caja de ahorro
  
     procedure pr_cre_cta_ahorro(p_cod_persona       ba_personas.cod_persona%type,
                              p_cod_moneda        ba_monedas.cod_moneda%type default v_cod_mon_local,
                              p_cod_modalidad     ge_tas_fechas.cod_modalidad%type,
                              p_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type,
                              p_cod_error         out number,
                              p_men_error         out varchar2,
                              p_nro_cta_ahorro    out ge_cuentas.nro_cuenta%type) is
    v_dig_verificador  ah_cta_vistas.dig_verificador%type;
    v_cod_oficina      ba_oficinas.cod_oficina%type := 61;
    v_cod_usu_promotor ah_cta_vistas.cod_usu_promotor%type := fug_obt_pardinamico('COD_USU_PROMOTOR');
    v_cod_error        number := v_pro_correcto;
    v_nro_cuenta       ah_cta_vistas.nro_cuenta%type;
    v_fec_actual       ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
    v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,
                                                                'HH24:MI:SS');
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_denominacion        ah_cta_vistas.denominacion%type;
    v_exi_moneda          varchar2(1);
    v_cod_tasa            ah_cta_vistas.cod_tasa%type;
    v_sal_min_pactado     ah_cta_vistas.sal_minimo%type;
    v_tip_capitalizacion  ah_cta_vistas.tip_capitalizacion%type;
    v_piz_tasa_min        ge_tas_fechas.val_minimo%type;
    v_piz_tasa_max        ge_tas_fechas.val_maximo%type;
    v_piz_tasa_actual     ge_tas_fechas.val_tasa%type;
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
    v_exi_cliente         varchar2(1);
    v_alta                varchar2(1) := 'S';
    v_nro_documento       ba_personas.nro_documento%type := fue_obt_nro_doc_persona(p_cod_persona);
    v_direccion           ba_per_dat_adicionales.val_parametro%type;
    v_tip_producto        it.ge_mai_onb_templates.tip_producto%type;
    v_error               number;
    v_mensaje             varchar2(4000);
    v_can_intentos        number(2) := fug_obt_pardinamico('CAN_INTENTOS');
    v_segundos            number(3, 1) := to_number(fug_obt_pardinamico('CAN_SEGUNDOS'),
                                                    '999.99');
    v_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type := fug_obt_pardinamico('COD_SUB_MAD_AHO_VISTA');
    v_lim_cta             ge_par_dinamicos.parametro%type;
    v_est_modulo         ba_modulos.estado%TYPE;
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 9;
    end;
   /* begin
      v_cod_oficina := fug_obt_ofi_cliente(p_cod_persona);
    exception
      when others then
        v_cod_oficina := fug_obt_pardinamico('COD_OFI_WEB');
    end;*/
    --solo modalidad caja de ahorro 3/31 o 3/334
    v_cod_modalidad := p_cod_modalidad;
    v_cod_modulo    := 3;
        --verificación de estado de módulo ahorros
    v_est_modulo := pae_cnf.fu_obt_est_modulo(v_cod_modulo);
    IF v_est_modulo IN (1,6) THEN
         raise_application_error(-20003, 'Modulo cerrado.No se puede operar.');
    END IF;
    
    --valida codigo de sub modalidad (1 GENERAL,26 CUENTA BASICA DE AHORRO ,27 MI CAJITA Y YO)
    if v_cod_modalidad in (31,334) and p_cod_sub_modalidad <> 1 then
        v_cod_sub_modalidad := p_cod_sub_modalidad;
    end if;
  
    if v_alta = 'S' then
      v_err_resultado := fug_ver_firmante(p_cod_persona,
                                          null,
                                          v_cod_modalidad,
                                          null,
                                          null,
                                          v_err_mensaje);
      if v_err_resultado != v_pro_correcto then
        v_cod_error := v_err_sql;
        p_men_error := v_err_mensaje;
      end if;
      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_tip_persona := 'J';
      end;
    
      begin
        select distinct 'S', m.cod_mon_bco_central
          into v_exi_moneda, v_cod_mon_bco_central
          from cr_piz_montos p, ba_monedas m
         where p.cod_moneda = p_cod_moneda
           and m.cod_moneda = p.cod_moneda
           and p.cod_modalidad = v_cod_modalidad;
      exception
        when others then
          v_exi_moneda := 'N';
      end;
    
      if (nvl(v_exi_moneda, 'N') = 'N') and
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
           and cod_modulo = v_cod_modulo
           and cod_modalidad = v_cod_modalidad
           and est_cuenta = 'P';
      exception
        when others then
          v_can_firmante := 0;
          v_can_pen      := 0;
      end;
    
      if v_can_firmante > 0 then
        v_tie_sol_firmantes := 'S';
      end if;
    
      if v_can_firmante > 0 and v_can_firmante = v_can_pen and
         v_cod_error = v_pro_correcto then
        --momento en el que realiza la solicitud
        begin
          update bw_sol_fir_cuentas
             set referencia = v_cod_mon_bco_central
           where cod_persona = p_cod_persona
             and cod_modulo = v_cod_modulo
             and cod_modalidad = v_cod_modalidad
             and est_firmante = 'P';
        exception
          when others then
            v_cod_error := v_err_sql;
            p_men_error := 'No se ha podido actualizar la Solicitud de Firmantes. ' ||
                           sqlerrm;
        end;
        v_ins_cta := 'N';
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
                                        v_cod_modulo,
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
        
          v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                                      v_cod_modulo,
                                                      v_cod_modalidad,
                                                      p_cod_moneda,
                                                      null);
        end if;
        if v_cod_error = v_pro_correcto then
          -- se prueba hasta 5 intentos 
          for can_intentos in 1 .. v_can_intentos loop
            begin
            
              v_nro_cuenta := fug_obt_sig_nro_cuenta(v_cod_modulo,
                                                     31,--se toma tambien para modalidad 334
                                                     v_cod_oficina,
                                                     v_cod_mon_local,
                                                     p_cod_persona);
            exception
              when others then
                if can_intentos = v_can_intentos then
                  if sqlcode = '-20054' then
                    v_cod_error := 54;
                    p_men_error := 'Error al obtener el numero de cuenta. ' ||
                                   sqlerrm;
                  else
                    v_cod_error := v_err_sql;
                    p_men_error := 'Error al obtener el numero de cuenta. ' ||
                                   sqlerrm;
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
                                                       v_cod_modulo,
                                                       v_cod_modalidad,
                                                       v_cod_oficina);
        
          -- obtener tasa
          begin
            pag_cta.pr_obt_tas_pizarra(v_cod_modulo,
                                       v_cod_modalidad,
                                       p_cod_moneda,
                                       v_tip_capitalizacion * 30,
                                       0,
                                       v_piz_tasa_min,
                                       v_piz_tasa_max,
                                       v_piz_tasa_actual,
                                       v_tip_capitalizacion,
                                       v_cod_sub_modalidad);
          
            pr_obt_tasa(v_cod_modulo,
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
                 v_cod_modulo,
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
            exception
              when others then
                v_cod_error := v_err_sql;
                p_men_error := 'Error al obtener el numero de cuenta. ' ||
                               sqlerrm;
            end;
         
            if v_est_modulo in (3,4) then
              begin
              insert into ah_cta_vistas_noc
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
                 v_cod_modulo,
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
            exception
              when others then
                v_cod_error := v_err_sql;
                p_men_error := 'Error al obtener el numero de cuenta. ' ||
                               sqlerrm;
            end;
            end if;
          end if;
        end if;
      
        if v_cod_error = v_pro_correcto then
          begin
            it.pag_fir.pr_ins_fir_cuentas(v_nro_cuenta,
                                          v_dig_verificador,
                                          v_cod_oficina,
                                          p_cod_persona,
                                          v_cod_modulo,
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
        
          it.paa_cah.pr_gen_movimientos(v_fec_actual,
                                        1,
                                        v_hora,
                                        401,
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        v_nro_cuenta,
                                        v_cod_mon_local,
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
        p_nro_cta_ahorro := v_nro_cuenta;
      end if;
      if p_cod_error is null then
        p_cod_error := nvl(v_cod_error, v_pro_correcto);
      end if;
      v_direccion := fue_tab_dat_adicional('BA_PERSONAS',
                                           'EMAIL_ONBOARDING',
                                           p_cod_persona);
      if p_cod_error=v_pro_correcto then
        v_lim_cta := fug_obt_pardinamico('ONB_LIM_INICIAL',
                                               3,
                                               v_cod_modalidad,
                                               p_cod_moneda);
        
         pr_ins_alt_producto(     v_nro_cuenta,
                                  'LIM_CRE_TRANSACCIONES',
                                  v_lim_cta,
                                  v_cod_error,
                                  p_men_error);
      
      end if;
        
      
      if nvl(v_direccion, 'X') != 'X' and nvl(v_tip_producto, 0) != 0 then
        pr_env_not_onb_productos(p_cod_persona,
                                 v_nro_documento,
                                 v_tip_producto,
                                 v_error,
                                 v_mensaje);
      end if;
    end if;
  end;
  --creacion de cajas de ahorro inclusive crear 'cuentas de desborde o cuentas tigo' segun parametro 
  procedure pr_cre_cta_ahorro2(p_cod_persona       ba_personas.cod_persona%type,
                               p_cod_moneda        ba_monedas.cod_moneda%type default v_cod_mon_local,
                               p_cod_modalidad     ge_tas_fechas.cod_modalidad%type,
                               p_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type,
                               p_cta_billetera     ge_cta_dat_adicionales.val_parametro%type default 'N',
                               p_cod_error         out number,
                               p_men_error         out varchar2,
                               p_nro_cta_ahorro    out ge_cuentas.nro_cuenta%type) is

    v_cta_billetera       ge_cta_dat_adicionales.parametro%type := 'CTA_BILLETERA';
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_error           number := v_pro_correcto;
    v_nro_cuenta          ah_cta_vistas.nro_cuenta%type;
  begin
    --solo modalidad caja de ahorro 3/31 o 3/334
    v_cod_modalidad := p_cod_modalidad;
    v_cod_modulo    := 3;
    --valida codigo de sub modalidad (1 GENERAL,26 CUENTA BASICA DE AHORRO ,27 MI CAJITA Y YO)
    if v_cod_modalidad = 31 and p_cod_sub_modalidad <> 1 then
      v_cod_sub_modalidad := p_cod_sub_modalidad;
    end if;
    if v_cod_modulo = 3 and v_cod_modalidad = 31 and v_cod_sub_modalidad = 26 and p_cta_billetera not in ('S', 'N') then
      v_cod_error := 1004;
      p_men_error := 'El valor del parametro CTA_BILLETERA = ' ||
                     p_cta_billetera || ' es invalido. ';
    else
      paa_cah.pr_cre_cta_ahorro(p_cod_persona,
                                p_cod_moneda,
                                p_cod_modalidad,
                                p_cod_sub_modalidad,
                                p_cod_error,
                                p_men_error,
                                p_nro_cta_ahorro);
    end if;

    --si la cuenta creada es de desborde o billetera de tigo ( mod 3/moda 31/sub 26) valida:
    if p_cod_error = v_pro_correcto then
      if v_cod_modulo = 3 and v_cod_modalidad = 31 and v_cod_sub_modalidad = 26 and p_cta_billetera = 'S' then
        begin
          insert into ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
          values
            (p_nro_cta_ahorro, v_cta_billetera, 'S');
        exception
          when others then
            p_cod_error  := v_err_sql;
            p_men_error := 'Error al insertar dato adicional de la cuenta. ' ||
                            v_nro_cuenta || ' - ' || sqlerrm;
        end;
      end if;
    end if;
    if p_cod_error is null then
       p_cod_error := nvl(v_cod_error, v_pro_correcto);
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error al insertar dato adicional de la cuenta. ' ||
                     v_nro_cuenta || ' - ' || sqlerrm;
  end;
  procedure pr_env_not_onb_productos(p_cod_persona   in ba_personas.cod_persona%type,
                                     p_nro_documento in ba_personas.nro_documento%type,
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

end paa_cah;
/
