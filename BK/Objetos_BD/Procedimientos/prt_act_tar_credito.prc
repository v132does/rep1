CREATE OR REPLACE procedure IT.prt_act_tar_credito(p_cod_persona      in ba_personas.cod_persona%type,
                                                   p_mto_pre_aprobado in ta_lin_pre_aprobado.mon_lin_pre_aprobado%type,
                                                   p_cod_error        out varchar2,
                                                   p_men_error        out varchar2,
                                                   p_nro_cuenta       out ta_cta_tarjetas.nro_cuenta%type) is
  v_det_error           ge_log_errores.det_error%type;
  v_rub_economico       ta_lin_pre_aprobado.cod_rub_economico%type;
  v_cod_modalidad       ta_lin_pre_aprobado.cod_modalidad%type;
  v_cod_sub_modalidad   ge_sub_modalidades.cod_sub_modalidad%type;
  v_afinidad            ta_tipos.afinidad%type;
  v_sub_afinidad        ta_tipos.sub_afinidad%type;
  v_cod_tip_cierre      ta_tipos.cod_tip_cierre%type;
  v_nro_bin             ta_tipos.nro_bin%type;
  v_referencia          ge_dir_envios.referencia%type;
  v_nro_solicitud       ta_solicitudes.nro_solicitud%type;
  v_cod_oficina         ta_solicitudes.cod_oficina%type;
  v_ent_procesadora     ta_solicitudes.cod_ent_procesadora%type;
  v_usu_promotor        ta_solicitudes.cod_usu_promotor%type;
  v_nom_embozado        ta_solicitudes.nom_embozado%type;
  v_moneda              ta_lin_pre_aprobado.cod_moneda%type;
  v_cod_error           varchar2(60);
  v_cod_error_num       number;
  v_mensaje             varchar2(4000);
  v_existe              varchar2(1);
  v_exi_tarjeta         varchar2(1);
  v_tip_envio           ge_dir_envios.tip_envio%type;
  v_cod_pre_aprobado    ta_lin_pre_aprobado.cod_pre_aprobado%type;
  v_lugar               varchar2(10);
  v_exi_pr_pre_aprobado varchar2(1);
  v_cta_debito          ah_cta_vistas.nro_cuenta%type;
  v_nro_cta_global      ta_imp_dat_embozados.nro_cta_deb_global%type;
  v_nro_tarjeta         ta_tarjetas.nro_tarjeta%type;
  v_dir                 varchar(1);
  v_separador           NUMBER;
  v_suf_hijo            VARCHAR2(50);
  v_desc_hijo           VARCHAR2(4000);
begin
  savepoint activar;
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
    pae_cnf.g_programa := 'GPPROFIN';
  end;
  v_ent_procesadora  := fug_obt_pardinamico('COD_ENT_GLOBAL');
  if v_ent_procesadora is null then
    p_cod_error := 'ACT_TC_NULL_PROCESSOR_PARAM';
    v_det_error := 'El valor del ente de la procesadora no puede ser nulo ';
  end if;

  /*Verificamos si tiene tarjeta de debito fisica*/
  begin
    v_existe := null;
    select 'S'
      into v_existe
      from ah_tar_debitos d
     where d.cod_persona = p_cod_persona
       --and d.tip_tar_debito = 'MF'
       and d.cod_ent_procesadora = v_ent_procesadora
       and d.cod_est_solicitud = 0
       and d.id_producto = 20
       and d.nro_emision =
           (select max(nro_emision)
              from ah_tar_debitos a
             where a.cod_persona = d.cod_persona
             and a.nro_cuenta=d.nro_cuenta
             and a.cod_ent_procesadora=v_ent_procesadora);
  exception
    when no_data_found then
      p_cod_error := 'ACT_TC_NOT_BOUNDED_TD';
      v_det_error := 'El cliente cod_persona = '|| p_cod_persona || ' no tiene vinculada una tarjeta de débito física.';
    when others then
      p_cod_error := 'ACT_TC_NOT_BOUNDED_TD';
      v_det_error := substr('Error al obtener datos de la tarjeta de debito vinculado al cliente ' || p_cod_persona || '. Error: ' ||
                            sqlerrm,
                            1,
                            4000);
  end;

  if nvl(p_cod_error, '0') = '0' then
    /*Buscamos linea de credito pre aprobada para la persona*/
    begin
      select l.cod_rub_economico,
             '53' cod_modalidad,
             l.cod_moneda,
             l.cod_pre_aprobado
        into v_rub_economico, v_cod_modalidad, v_moneda, v_cod_pre_aprobado
        from ta_lin_pre_aprobado l
       where trunc(sysdate) >= fec_ini_oferta
         and (trunc(sysdate) <= fec_fin_oferta or fec_fin_oferta is null)
         and cod_persona = p_cod_persona
         and l.mon_lin_pre_aprobado >= p_mto_pre_aprobado
         and estado in ('C', 'G')
         and cod_pre_aprobado =
             (select max(cod_pre_aprobado)
                from ta_lin_pre_aprobado m
               where m.cod_persona = l.cod_persona
                 and m.estado in ('C', 'G'));
    exception
      when no_data_found then
        p_cod_error := 'ACT_TC_OFFER_NOT_EXISTS';
        v_det_error := 'El cliente cod_persona = '|| p_cod_persona || ' no tiene una línea de crédito pre aprobada - Tabla TA_LIN_PRE_APROBADO.';
      when others then
        p_cod_error := 'ACT_TC_OFFER_NOT_EXISTS';
        v_det_error := substr('Error al obtener datos de la linea pre aprobada vinculado al cliente ' || p_cod_persona || '.Tabla TA_LIN_PRE_APROBADO.  Error: ' ||
                              sqlerrm,
                              1,
                              4000);
    end;
  end if;

  /*Verifico que no tenga alguna tarjeta ya creada*/
  Begin
    v_existe := null;
    v_exi_tarjeta := null;
    select distinct 'S'
      into v_exi_tarjeta
      from ta_tarjetas tar, ta_cta_tarjetas t, ta_solicitudes s
     where tar.nro_cuenta = t.nro_cuenta
       and tar.cod_estado = 6
       and s.cod_persona = tar.cod_persona
       and s.afinidad = t.afinidad
       and s.cod_modalidad = t.cod_modalidad
       and s.cod_modulo = t.cod_modulo
       and s.cod_rub_economico = t.cod_rub_economico
       and t.estado != 'C'
       and t.nro_solicitud = s.nro_solicitud
       and t.cod_modalidad = nvl(v_cod_modalidad, 53)
       and (t.cod_rub_economico = v_rub_economico or v_rub_economico is null)
       and t.cod_moneda = nvl(v_moneda, pag_gen.FU_OBT_MON_LOCAL)
       and tar.cod_persona = p_cod_persona;
    if nvl(v_exi_tarjeta, 'N') = 'S' then
      p_cod_error := 'ACT_TC_ALREADY_EXISTS_TC';
      v_det_error := 'El cliente cod_persona = ' || p_cod_persona || ' ya tiene una tarjeta activa vinculada a la modalidad ' ||
                     nvl(v_cod_modalidad, 53) ||' .Verificar el estado de la solicitud en ta_solicitudes y en ta_lin_pre_aprobados';
    end if;
  exception
    when no_data_found then
      v_exi_tarjeta := 'N';
    when too_many_rows then
      p_cod_error := 'ACT_TC_ALREADY_EXISTS_TC';
      v_det_error := 'El cliente cod_persona = ' || p_cod_persona || ' ya tiene una tarjeta activa vinculada a la modalidad ' ||
                     nvl(v_cod_modalidad, 53) ;
    when others then
      p_cod_error := 'ACT_TC_ALREADY_EXISTS_TC';
      v_det_error := substr('Error al verificar si el cliente ya tiene activa tarjeta modalidad ' ||
                            nvl(v_cod_modalidad, 53) || ' ' || sqlerrm,
                            1,
                            4000);
  end;

  /*if nvl(p_cod_error, 0) = 0 then
    begin
      select 'S'
        into v_exi_pr_pre_aprobado
        from pr_pre_aprobados p
       where p.cod_persona = p_cod_persona
         and p.estado = 'D';

      if nvl(v_existe, 'N') = 'S' then
        p_cod_error := 1;
        v_det_error := 'Persona ya cuenta con prestamo pre aprobado desembolsado';

        update ta_lin_pre_aprobado t
           set t.estado = 'V', t.fec_fin_oferta = trunc(sysdate)
         where t.cod_pre_aprobado = v_cod_pre_aprobado
           and t.cod_persona = p_cod_persona;

        if sql%rowcount = 0 then
          v_det_error := v_det_error || ' - ' ||
                         ' No se pudo actualizar cod.pre aprobado ' ||
                         v_cod_pre_aprobado;
        end if;
      end if;

    exception
      when no_data_found then
        v_existe := 'N';
      when others then
        p_cod_error := 1;
        v_det_error := substr('Error verificar oferta de prestamo pre aprobado' ||
                              sqlerrm,
                              1,
                              4000);
    end;
  end if;*/
  if nvl(p_cod_error, '0') = '0' then
    /*Buscamos datos de la afinidad y nro bin para tipo de tarjeta*/
    begin
      select t.afinidad, t.nro_bin, t.sub_afinidad, nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP',fug_obt_parentes(fug_obt_pardinamico('COD_ENT_GLOBAL'),'GLP_CIERRE')),'4')--t.cod_tip_cierre
        into v_afinidad, v_nro_bin, v_sub_afinidad, v_cod_tip_cierre
        from ta_tipos t
       where t.cod_ent_procesadora = v_ent_procesadora
         and t.cod_modalidad = v_cod_modalidad;
    exception
      when no_data_found then
        p_cod_error := 'ACT_TC_ERROR_TATIPOS';
        v_det_error := 'No existe un tipo de tarjeta para la modalidad  ' ||
                       v_cod_modalidad || ' en TA_TIPOS';
      when too_many_rows then
        p_cod_error := 'ACT_TC_ERROR_TATIPOS';
        v_det_error := 'Existen mas de un tipo de tarjeta para la modalidad ' ||
                       v_cod_modalidad || ' en TA_TIPOS';
      when others then
        p_cod_error := 'ACT_TC_ERROR_TATIPOS';
        v_det_error := substr('Error al obtener datos del tipo de tarjeta para la modalidad ' ||
                              v_cod_modalidad || ' en TA_TIPOS. Error: ' || sqlerrm,
                              1,
                              4000);
    end;
  end if;
  if nvl(p_cod_error, '0') = '0'then
    /*Buscamos sub-modalidad */
    begin
      select g.cod_sub_modalidad
        into v_cod_sub_modalidad
        from ge_sub_modalidades g
       where g.cod_modulo    = 5
         and g.cod_modalidad = v_cod_modalidad;
    exception
      when no_data_found then
        p_cod_error := 'ACT_TC_ERROR_SUBMODALITY';
        v_det_error := 'No existe sub-modalidad para modalidad ' || v_cod_modalidad || ' tabla GE_SUB_MODALIDADES ';
      when too_many_rows then
        p_cod_error := 'ACT_TC_ERROR_SUBMODALITY';
        v_det_error := 'Existen mas de un tipo de sub-modalidad para modalidad ' || v_cod_modalidad|| ' tabla GE_SUB_MODALIDADES ';
      when others then
        p_cod_error := 'ACT_TC_ERROR_SUBMODALITY';
        v_det_error := substr('Error al obtener sub-modalidad para modalidad ' || v_cod_modalidad || ' ' || SQLERRM,1,4000);
    end;
  end if;  

  if nvl(p_cod_error, '0') = '0' then
    /*Insertamos la solicitud*/
    v_referencia := 1; -- ge_dir_retenciones- CASA MATRIZ por defecto
    v_tip_envio  := 'R';
    Begin
      Select trim(pri_nombre) || ' ' || trim(pri_apellido)
        into v_nom_embozado
        from ba_per_fisicas
       where cod_persona = p_cod_persona;
    Exception
      When NO_DATA_FOUND then
        p_cod_error := 'ACT_TC_PERSON_NOT_FOUND';
        v_det_error := 'No se encontro nombre embozado de la persona cod_persona = ' || p_cod_persona || ' en la tabla BA_PER_FISICAS' ;
      when others then
        p_cod_error := 'ACT_TC_PERSON_NOT_FOUND';
        v_det_error := substr('Error al recuperar nombre embozado para la persona cod_persona = ' || p_cod_persona || ' en la tabla BA_PER_FISICAS. Error: '  ||
                              sqlerrm,
                              1,
                              4000);
    End;

    v_cod_oficina := fug_obt_ofi_matriz;

    if v_cod_oficina is null then
      p_cod_error := 'ACT_TC_NULL_OFFICE_PARAM';
      v_det_error := 'El valor de la oficina no puede ser nulo ';
    end if;

    if nvl(p_cod_error, '0') = '0' then
      begin
        select u.cod_usuario
          into v_usu_promotor
          from ge_ent_usuarios u
         WHERE u.cod_ente = v_ent_procesadora
           and u.cod_usu_ente = '01';
      exception
        when no_data_found then
          p_cod_error := 'ACT_TC_PROMOTER_USER_NOT_FOUND';
          v_det_error := 'No se encontro usuario promotor en la tabla GE_ENT_USUARIOS para entidadad procesadora ' ||
                         v_ent_procesadora;
        when others then
          p_cod_error := 'ACT_TC_PROMOTER_USER_NOT_FOUND';
          v_det_error := substr('Error al recuperar usuario promotor en la tabla GE_ENT_USUARIOS para entidadad procesadora ' ||
                                v_ent_procesadora || sqlerrm,
                                1,
                                4000);
      end;
    end if;
    if nvl(p_cod_error, '0') = '0' then
      begin
        v_existe := null;
        Select 'S'
          into v_existe
          from ta_sucursales e, ta_tipos t
         where e.cod_ent_procesadora = t.cod_ent_procesadora
           and e.cod_oficina = v_cod_oficina
           and e.activo = 'S'
           and t.cod_modulo = 5
           and t.cod_modalidad = v_cod_modalidad
           and t.afinidad = v_afinidad
           and t.nro_bin = nvl(v_nro_bin, t.nro_bin)
           and t.cod_campana is null
           and (t.cod_oficina = v_cod_oficina or t.cod_oficina is null);
      exception
        when no_data_found then
          p_cod_error := 'ACT_TC_BRANCH_NOT_FOUND';
          v_det_error := 'Oficina: ' || v_cod_oficina || ' no definida en Sucursales por Procesadora para la modalidad: '|| v_cod_modalidad || ' y afinidad: ' || v_afinidad ; 
        when others then
          p_cod_error := 'ACT_TC_BRANCH_NOT_FOUND';
          v_det_error := substr('Error al verificar oficina: ' || v_cod_oficina || ' por sucursal. Error: ' || sqlerrm,
                                1,
                                4000);
      end;
    end if;

    if nvl(p_cod_error, '0') = '0' then

      SELECT S_NRO_SOLICITUD.NEXTVAL into v_nro_solicitud FROM SYS.DUAL;

      if v_nro_solicitud is null then
        p_cod_error := 'ACT_TC_BRANCH_NULL';
        v_det_error := 'El nro de solicitud no puede ser nulo ';
      end if;
    end if;
  end if;

 -- direccion de envio
  begin 
  select distinct 'S'
  into v_dir
  from  ge_dir_envios a 
  where a.cod_persona=p_cod_persona;
  exception
    when no_data_found THEN
      BEGIN
        insert into ge_dir_envios a (cod_persona, tip_envio, referencia)
        values (p_cod_persona,'R','1');
        EXCEPTION
          WHEN OTHERS THEN
            p_cod_error := 'ACT_TC_ADDRESS_INSERT_FAILED';
          v_det_error := 'No fue posible insertar dirección de envio del cliente cod_persona = '|| p_cod_persona || ' en la tabla GE_DIR_ENVIOS';
        prg_ins_log_programas('PRT_ACT_TAR_CREDITO',
                              substr(' Error: ' || p_cod_error || ' ' ||
                                     v_det_error,
                                     1,
                                     4000),
                              p_cod_persona,
                              null);
         END;
    when others THEN
        p_cod_error := 'ACT_TC_ADDRESS_INSERT_FAILED';
        v_det_error := 'No fue posible insertar dirección de envio del cliente cod_persona = '|| p_cod_persona || ' en la tabla GE_DIR_ENVIOS';
      prg_ins_log_programas('PRT_ACT_TAR_CREDITO',
                            substr(' Error: ' || p_cod_error || ' ' ||
                                   v_det_error,
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
  end;
  if nvl(p_cod_error, '0') = '0' then
    begin
      insert into ta_solicitudes
        (nro_solicitud,
         cod_persona,
         cod_oficina,
         cod_modulo,
         cod_modalidad,
         cod_usu_promotor,
         fec_solicitud,
         deb_automatico, --N
         tip_cobro, --M
         nom_embozado,
         monto,
         cod_estado, --PAN
         tip_envio, --R
         referencia,
         cod_moneda,
         afinidad,
         cod_rub_economico,
         nro_bin,
         cod_ent_procesadora,
         sub_afinidad,
         cod_tip_cierre,
         cod_sub_modalidad)
      values
        (v_nro_solicitud,
         p_cod_persona,
         v_cod_oficina,
         5,
         v_cod_modalidad,
         v_usu_promotor,
         trunc(sysdate),
         'N',
         'M',
         v_nom_embozado,
         p_mto_pre_aprobado,
         'PAN',
         v_tip_envio,
         v_referencia,
         v_moneda,
         v_afinidad,
         v_rub_economico,
         v_nro_bin,
         v_ent_procesadora,
         v_sub_afinidad,
         v_cod_tip_cierre,
         v_cod_sub_modalidad);
    exception
      when others then
        p_cod_error := 'ACT_TC_REQUEST_INSERT_FAILED';
        v_det_error := substr('Error al insertar solicitud ' ||
                              ' Cod persona ' || p_cod_persona ||     
                              ' Nro.solicitud ' || v_nro_solicitud ||
                              ' Oficina ' || v_cod_oficina ||
                              ' Modalidad: ' || v_cod_modalidad ||
                              ' Promotor: ' || v_usu_promotor ||
                              ' Embozado: ' || v_nom_embozado || ' Monto: ' ||
                              p_mto_pre_aprobado || ' Referencia: ' ||
                              v_referencia || ' Moneda ' || v_moneda ||
                              ' Afinidad ' || v_afinidad ||
                              ' Rub economico ' || v_rub_economico ||
                              ' Nro bin: ' || v_nro_bin || ' Procesadora: ' ||
                              v_ent_procesadora || ' Error: ' || sqlerrm,
                              1,
                              4000);
    end;
  end if;

  if nvl(p_cod_error, '0') != '0' and nvl(v_exi_pr_pre_aprobado, 'N') = 'N' then
    rollback to activar; --si ocurrio un error hasta este punto se hace rollback
  elsif nvl(p_cod_error, '0') = '0' then
    --Llamamos proceso de activacion de tarjeta

    pat_tgl.pr_alt_tar_sol_credito(p_cod_persona   => p_cod_persona,
                                   P_nro_solicitud => v_nro_solicitud,
                                   p_cod_error     => v_cod_error_num,
                                   p_men_error     => v_mensaje);
    v_lugar := 'WS';
    if v_cod_error_num != nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0) 
    THEN 
    
      v_separador := INSTR(v_mensaje, '|');
      
      IF v_separador > 0 THEN
          v_suf_hijo := SUBSTR(v_mensaje, 1, v_separador - 1);
          v_desc_hijo   := SUBSTR(v_mensaje, v_separador + 1);
      ELSE        
          v_suf_hijo := 'UNMAPPED_ERR';
          v_desc_hijo   := v_mensaje;
      END IF;
      
    
    p_cod_error := 'ACT_TC_SP_ALT_SOL_' || v_suf_hijo;

      v_det_error := SUBSTR('Error en el alta por solicitud del cliente ' || 
                            p_cod_persona || ' . Error: ' || v_desc_hijo || 
                            ' al intentar ejecutar ', 1, 4000);
                            
      v_cod_error := TO_CHAR(v_cod_error_num);
      rollback to activar;
    else

      /*Actualizamos estado de la solicitud*/
      update ta_solicitudes s
         set s.cod_estado = 'APR'
       where s.nro_solicitud = v_nro_solicitud
         and s.cod_persona = p_cod_persona;
      if sql%rowcount = 0 then
        v_det_error := substr('No se pudo actualizar estado de la solicitud' ||
                              sqlerrm,
                              1,
                              4000);
      end if;
      /*Actualizamos estado de la linea pre aprobada*/
      update ta_lin_pre_aprobado l
         set l.nro_solicitud  = v_nro_solicitud,
             l.estado         = 'A',
             l.fec_fin_oferta = trunc(sysdate)
       where l.cod_persona = p_cod_persona
         and l.cod_pre_aprobado = v_cod_pre_aprobado;
      if sql%rowcount = 0 then
        v_det_error := substr('No se pudo actualizar registro de linea pre aporbado codigo: ' ||
                              v_cod_pre_aprobado || ' Error: ' || sqlerrm,
                              1,
                              4000);
      end if;
      /*Se da de baja prestamo pre aprobado vigente*/
      /*update pr_pre_aprobados p
         set p.fec_fin_oferta = trunc(sysdate),
             p.estado         = 'V',
             p.mot_estado     = 'Baja de solicitud de préstamo por aceptación de oferta de línea de crédito.'
       where p.cod_persona = p_cod_persona
         and nvl(p.estado, 'C') in ('C', 'G');
      --actualiza cod_seg_cliente de ge_clientes 
        BEGIN
          update ge_clientes a
             set a.cod_seg_cliente = fug_obt_pardinamico('PRE_APR_ONB_SEGMENTO')
           where a.cod_persona = p_cod_persona;
        EXCEPTION
          WHEN OTHERS THEN
            p_cod_error := 7;
            v_det_error := substr('No se pudo actualizar segmento de cliente en la tabla ge_clientes, codigo de persona: ' ||
                                  p_cod_persona || ' ' || sqlerrm,
                                  1,
                                  4000);
        END;*/
      /*Obtengo nro de cuenta creada*/
      begin
        select c.nro_cuenta, substr(t.nro_tarjeta, -4)
          into p_nro_cuenta, v_nro_tarjeta
          from ta_cta_tarjetas c, ta_tarjetas t
         where t.nro_cuenta = c.nro_cuenta
           and t.cod_persona = p_cod_persona
           and c.nro_solicitud = v_nro_solicitud
           and t.cod_estado = 6
           and c.estado != 'C';
      exception
        when no_data_found then
          p_nro_cuenta := null;
        when others then
          v_det_error := substr('Error al obtener datos de la cuenta creada ' ||
                                sqlerrm,
                                1,
                                4000);
      end;
      if nvl(v_nro_tarjeta, '0') != '0' and nvl(p_nro_cuenta, '0') != '0' then
        /*Obtengo nro de cuenta global realacionado a la tarjeta*/
        begin
          select t.nro_cta_deb_global
            into v_nro_cta_global
            from ta_imp_dat_embozados t
           where t.cod_persona = p_cod_persona
             and substr(t.nro_pan_pro_principal, -4) = v_nro_tarjeta
             and t.nro_cuenta = p_nro_cuenta
             and t.estado = 'E';
        exception
          when no_data_found then
            v_nro_cta_global := null;
          when others then
            v_det_error := substr('Error al obtener la cuenta global ' ||
                                  sqlerrm,
                                  1,
                                  4000);
        end;
       /*Se obtiene nro de cuenta debito relacionada a la tarjeta de debito*/
        begin
          select t.nro_cuenta
            into v_cta_debito
            from ah_tar_debitos t
           where t.nro_cta_global = nvl(v_nro_cta_global, 'x')
             and t.cod_persona = p_cod_persona
             and t.nro_emision =
                 (select max(nro_emision)
                    from ah_tar_debitos d
                   where d.nro_cta_global = t.nro_cta_global
                     and d.cod_persona = t.cod_persona);
        exception
          when no_data_found then
            /*Si no encuentra busca la cta ahorro que se dio de alta en el onb*/
            begin
              select v.nro_cuenta
                into v_cta_debito
                from ah_cta_vistas v, ge_cta_clientes c
               where v.nro_cuenta = c.nro_cuenta
                 and c.cod_persona = p_cod_persona
                 and v.estado != 'C'
                 and v.cod_canal = 26
                 and c.relacion = 'P'
                 and rownum = 1;
            exception
              when no_data_found then
                v_cta_debito := null;
              when others then
                v_det_error := substr('Error al obtener la cuenta de ahorro vista ' ||
                                      sqlerrm,
                                      1,
                                      4000);
            end;
          when others then
            v_cta_debito := null;
        end;
      end if;
      if nvl(v_cta_debito, '0') != '0' and nvl(fug_obt_pardinamico('ACT_DEB_AUT_TARJETAS'),'S')='S' then
        /*Marcamos como debito automatico*/
        update ta_cta_tarjetas t
           set t.deb_automatico = 'S',
               t.nro_cta_debito = v_cta_debito,
               t.tip_cobro      = 'M'
         where t.nro_cuenta = p_nro_cuenta;
        if sql%rowcount = 0 then
          v_det_error := substr('No se pudo marcar como debito automatico ' ||
                                ' Nro. Cuenta: ' || v_cta_debito ||
                                ' Error: ' || sqlerrm,
                                1,
                                4000);
        end if;
      end if;
      
      p_cod_error := '0';
      p_men_error := 'La tarjeta de crédito finalizada en ' || SUBSTR(v_nro_tarjeta,-4) || ' ya se encuentra activa.';

    end if;
  end if;

  if nvl(p_cod_error, '0') != '0' or v_det_error is not null then
    prg_ins_log_programas('PRT_ACT_TAR_CREDITO',
                          substr(' Error: ' || p_cod_error || ' ' ||
                                 v_det_error,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);


    if v_exi_tarjeta = 'S' then 

      -- p_cod_error := 'ACT_TC_EXISTS_TC';
      p_men_error := 'El cliente cod_persona = ' || p_cod_persona || ' ya tiene una tarjeta activa vinculada a la modalidad ' ||
                     nvl(v_cod_modalidad, 53)  ;

    else

      p_men_error := v_det_error ;
    
    end if;

  end if;
exception
  when others then
    p_cod_error := 'ACT_TC_ACTIVATION_FAILED';
    v_det_error := 'Ocurrio un error inesperado en el proceso de activacion de tarjeta de credito pre aprobado ' ||
                   DBMS_UTILITY.format_error_stack || ' - ' ||
                   DBMS_UTILITY.format_error_backtrace;
    p_men_error := 'La tarjeta de crédito vinculada al cliente COD_PERSONA = '  || p_cod_persona || ' no pudo ser activada debido a que '|| v_det_error ;

    prg_ins_log_programas('PRT_ACT_TAR_CREDITO',
                          substr(' Error: ' || p_cod_error || ' ' ||
                                 v_det_error || ' Lugar' || v_lugar ||
                                 ' User ' || USER,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
    if nvl(v_lugar, 'X') != 'WS' then
      rollback to activar; --solo si aun no llego a llamar al WS
    end if;
end prt_act_tar_credito;
/