create or replace package body it.pag_app is
g_mod_estado    ba_modulos.estado%TYPE;--FSOP-20695
  
  procedure lp_ver_horario(p_cod_ofi_origen ba_oficinas.cod_oficina%type,
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
    elsif v_est_modulo in (1,6) then/*FSOP-20695*/
        p_cod_error := '1070';
        p_men_error := 'Modulo en proceso de cierre';
    elsif v_est_modulo = 2 then
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
    pag_cta.g_horario := p_horario;
    p_fec_valor       := trunc(sysdate);
    g_mod_estado      := v_est_modulo;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 99;
      p_men_error := 'Ocurrio un error en la verificacion de horario';
      PRG_INS_LOG_PROGRAMAS('PAG_APP.LP_VER_HORARIO',
                            substr(DBMS_UTILITY.format_error_backtrace || ' ' ||
                                   DBMS_UTILITY.format_error_stack,
                                   1,
                                   4000),
                            null,
                            null);

  END lp_ver_horario;

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

-- UPS-388 para comprobantes --
PROCEDURE lp_reg_operacion( p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
                            p_cod_moneda      IN VARCHAR2 DEFAULT NULL,
                            p_monto           IN NUMBER DEFAULT NULL,
                            p_nro_cta_contra  IN VARCHAR2 DEFAULT NULL,
                            p_cantidad        IN NUMBER DEFAULT NULL,
                            p_etiqueta        IN VARCHAR2 DEFAULT NULL,
                            p_dato            IN VARCHAR2 DEFAULT NULL,
                            p_etiqueta2       IN VARCHAR2 DEFAULT NULL,
                            p_dato2           IN VARCHAR2 DEFAULT NULL,
                            p_observacion     IN VARCHAR2 DEFAULT NULL,
                            p_dir_ip          IN VARCHAR2 DEFAULT NULL,
                            p_cod_respuesta   IN VARCHAR2 DEFAULT NULL,
                            p_cod_persona     IN VARCHAR2 DEFAULT NULL,
                            p_cod_operacion   IN VARCHAR2 DEFAULT NULL,
                            p_nro_operacion   IN VARCHAR2 DEFAULT NULL,
                            p_nro_terminal    IN VARCHAR2 DEFAULT NULL,
                            p_clave           IN VARCHAR2 DEFAULT NULL,
                            p_cod_per_empresa IN VARCHAR2 DEFAULT NULL,
                            p_parametros      IN VARCHAR2 DEFAULT NULL,
                            p_etiqueta3       IN VARCHAR2 DEFAULT NULL,
                            p_dato3           IN VARCHAR2 DEFAULT NULL,
                            p_nro_doc_pendiente IN NUMBER DEFAULT NULL,
                            p_nro_movimiento    IN NUMBER DEFAULT NULL,
                            p_canal             IN VARCHAR2 DEFAULT NULL
                            ) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_det_error         ge_log_errores.det_error%type:=null;
    v_cod_persona       ba_personas.cod_persona%type:=null;
  BEGIN
    if p_cod_persona is null or p_cod_per_empresa is null then
        begin
          select s.cod_persona
             into v_cod_persona
             from ge_cta_clientes s
             where s.nro_cuenta=p_nro_cuenta
             and s.relacion='P';
        exception
          when no_data_found then
            null;
        end;
    end if;

    INSERT INTO bw_movimientos
        (nro_documento, cod_per_principal, cod_per_ingreso, clave, fec_hora, nro_caja, cod_tip_mensaje, dir_ip, cod_respuesta, observacion, nro_cuenta, cod_moneda, monto, nro_cta_contra, cantidad, etiqueta, dato, etiqueta2, dato2, parametros, etiqueta3, dato3, nro_doc_pendiente, nro_movimiento, canal)
    VALUES
        (p_nro_operacion, nvl(nvl(p_cod_per_empresa, p_cod_persona),v_cod_persona), nvl(p_cod_persona,v_cod_persona), substr(p_clave, 1, 20), SYSDATE, p_nro_terminal, p_cod_operacion, p_dir_ip, p_cod_respuesta, p_observacion, substr(REPLACE(TRIM(p_nro_cuenta), chr(13), ''),0,15), p_cod_moneda, p_monto, substr(REPLACE(TRIM(p_nro_cta_contra), chr(13), ''),0,15), p_cantidad, p_etiqueta, p_dato, p_etiqueta2, p_dato2, substr(p_parametros, 1, 1000),p_etiqueta3, p_dato3, p_nro_doc_pendiente, p_nro_movimiento,upper(p_canal));

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('error bw_movimientos '||sqlerrm);
        v_det_error := 'error bw_movimientos '||sqlerrm
                       ||', p_nro_cuenta: '||p_nro_cuenta
                       ||', p_nro_operacion: '||p_nro_operacion; 
        PRG_INS_LOG_PROGRAMAS('PAG_APP.LP_REG_OPERACION',
                              v_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
  END lp_reg_operacion;
-- UPS-388 para comprobantes --

  procedure pr_gen_rev_operaciones(p_referencia in varchar2,
                                   p_cod_error  out number,
                                   p_msj_error  out varchar2) is
    v_fecha             ge_movimientos.fecha%type;
    v_hora              ge_movimientos.hora%type;
    v_usuario           ge_movimientos.cod_usuario%type;
    v_cod_mod_padre     ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre     ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
    v_existe            varchar2(1);
    v_det_error         ge_log_errores.det_error%type;
    v_nro_caja          ge_movimientos.nro_caja%type;
    v_nro_documento     ge_movimientos.nro_documento%type;
    v_concepto          ge_movimientos.concepto%type;
    v_respuesta         varchar2(300);
    v_cod_tra_padre_cja ge_movimientos.cod_tra_padre%type;
    v_hora_rev          ge_movimientos.hor_reversion%type;
    v_es_nocturno       varchar2(1) := 'N';
    v_usuario_dis           ge_movimientos.cod_usuario%type;
    
  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    begin
      select 'S',
             t.fecha,
             t.hora,
             t.cod_usuario,
             t.cod_mod_padre,
             t.cod_mad_padre,
             t.cod_tra_padre,
             t.nro_caja,
             t.nro_documento,
             t.concepto
        into v_existe,
             v_fecha,
             v_hora,
             v_usuario,
             v_cod_mod_padre,
             v_cod_mad_padre,
             v_cod_tra_padre,
             v_nro_caja,
             v_nro_documento,
             v_concepto
        from ge_movimientos t
       where t.reversado = 'N'
         and t.cod_usuario like ('SERVICEPA%') --usuario especifico de PDS
         and t.nro_documento = p_referencia --hace referencia al movimiento id
         and rownum = 1;
      v_es_nocturno := 'N';
    exception
      when no_data_found then
        BEGIN
          select 'S',
                 t.fecha,
                 t.hora,
                 t.cod_usuario,
                 t.cod_mod_padre,
                 t.cod_mad_padre,
                 t.cod_tra_padre,
                 t.nro_caja,
                 t.nro_documento,
                 t.concepto
            into v_existe,
                 v_fecha,
                 v_hora,
                 v_usuario,
                 v_cod_mod_padre,
                 v_cod_mad_padre,
                 v_cod_tra_padre,
                 v_nro_caja,
                 v_nro_documento,
                 v_concepto
            from ge_movimientos_noc t
           where t.reversado = 'N'
             and t.cod_usuario like ('SERVICEPA%') --usuario especifico de PDS
             and t.nro_documento = p_referencia --hace referencia al movimiento id
             and rownum = 1;
          v_es_nocturno := 'S';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_existe    := 'N';
            p_cod_error := 1;
            p_msj_error := 'Error al buscar el movimiento a reversar';
        END;
    end;

    --se llama al procedimiento para reversar las operaciones en el caso que exista el movimiento
    if v_existe = 'S' then
      
        
       

      begin
        savepoint reversion;                        
               v_usuario_dis := it.fug_obt_mov_user('SERVICEPAY','S_SER_USER_SERVICEPAY'); 
               v_hora_rev    := it.fug_obt_hora(v_usuario_dis,'s_hor_movim');
               
    

        it.prg_rev_operacion(p_fecha             => v_fecha,
                             p_hora              => v_hora,
                             p_cod_usuario       => v_usuario,
                             p_cod_mod_padre     => v_cod_mod_padre,
                             p_cod_mad_padre     => V_cod_mad_padre,
                             p_cod_tra_padre     => v_cod_tra_padre,
                             p_cod_usu_reversion => v_usuario_dis,--substr(user, 1, 10),
                             p_hor_reversion     => v_hora_rev,
                             p_es_nocturno       => v_es_nocturno,
                             p_concepto          => substr('Reversion ' ||
                                                           lower(substr(v_concepto,
                                                                        1,
                                                                        1)) ||
                                                           substr(v_concepto,
                                                                  2), 1,
                                                           100),
                             p_nro_ncredito      => null);

        if v_nro_caja is not null then
          --reversion de operaciones de caja
          begin
            select g.cod_tra_padre
              into v_cod_tra_padre_cja
              from cj_movimientos g
             where g.nro_documento = p_referencia
               and g.cod_mod_padre = 9
               and g.cod_mad_padre = 91
               and rownum = 1;
          exception
            when no_data_found then
              p_cod_error := 4;
              p_msj_error := 'Error al buscar el movimiento en caja a reversar';
              rollback to reversion;
            when others then
              p_cod_error := 5;
              p_msj_error := 'Error al buscar el movimiento en caja a reversar';
              rollback to reversion;
          end;

          if nvl(p_cod_error, 0) = 0 then
            begin
              /*v_respuesta := it.fuj_pro_transaccion_200(p_referencia,
                                                        v_nro_caja,
                                                        'T',
                                                        v_nro_caja,
                                                        v_cod_tra_padre_cja,
                                                        v_nro_documento,
                                                        v_hora,
                                                        'Reversion de ' ||
                                                        v_concepto);*/
              
              v_respuesta := it.fuj_pro_transaccion_200(p_referencia,
                                                        v_nro_caja,
                                                        v_cod_tra_padre_cja,
                                                        v_nro_documento,
                                                        v_hora,
                                                        'Reversion de ' ||
                                                        v_concepto);

              p_cod_error := 0;
              p_msj_error := v_respuesta;
            exception
              when others then
                p_cod_error := 3;
                p_msj_error := 'Error en el proceso de Reversas operaciones de caja';
                v_det_error := substr('Error en el proceso de Reversas operaciones de caja -' ||
                                      DBMS_UTILITY.format_error_stack ||
                                      ' - ' ||
                                      DBMS_UTILITY.format_error_backtrace,
                                      1,
                                      4000);
                rollback to reversion;
            end;
          end if;
        end if;

       update bw_pag_servicios b
        set reversado='S'
        where b.nro_transaccion=p_referencia
        and b.fecha=v_fecha
        and b.hora=v_hora
        and b.red_pago in (6,7); -- 6 Wepa / 7 Aduanas y Otros

        p_cod_error := 0;
        p_msj_error := 'Se ha generado los movimientos de reversas';
      exception
        when others then
          p_cod_error := 2;
          p_msj_error := 'Error en el proceso de Reversas';
          v_det_error := substr('Error en el proceso de Reversas ' ||
                                DBMS_UTILITY.format_error_stack || ' - ' ||
                                DBMS_UTILITY.format_error_backtrace,
                                1,
                                4000);
          rollback to reversion;
      end;
    end if;

    if nvl(p_cod_error, 0) != 0 then
      PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_REV_OPERACIONES',
                            substr('Referencia : ' || p_referencia ||
                                   nvl(v_det_error,
                                       p_cod_error || '-' || p_msj_error),
                                   1,
                                   4000),
                            null,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 3;
      p_msj_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                     DBMS_UTILITY.format_error_stack;
      v_det_error := 'Referencia : ' || p_referencia || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_REV_OPERACIONES',
                            v_det_error,
                            null,
                            null);
      rollback;
  end pr_gen_rev_operaciones;

  procedure pr_obt_dat_persona(p_cod_pais             in number,
                               p_tip_documento        in number,
                               p_nro_documento        in varchar2,
                               p_cod_persona          out varchar2,
                               p_pri_nombre           out varchar2,
                               p_seg_nombre           out varchar2,
                               p_pri_apellido         out varchar2,
                               p_seg_apellido         out varchar2,
                               p_cod_sexo             out varchar2,
                               p_cod_pai_nacionalidad out number,
                               p_fec_nacimiento       in out date,
                               p_fec_vto_documento    out date,
                               p_telefono             in out varchar2,
                               p_email                out varchar2,
                               p_direccion            out varchar2,
                               p_cod_profesion        out number,
                               p_desc_prof            out varchar2,
                               p_desc_prof_ing        out varchar2,
                               p_tip_operacion        in varchar2,
                               p_cod_error            out number,
                               p_msj_error            out varchar2) is
    v_tip_persona    varchar2(1);
    v_existe         number;
    v_fec_nacimiento ba_per_fisicas.fec_nacimiento%type;
    v_telefono       varchar2(20);
    v_det_error      ge_log_errores.det_error%type;

  begin
    if p_fec_nacimiento is null and nvl(p_tip_operacion, 'x') = 'E' then
      p_cod_error := 6;
      p_msj_error := 'La fecha de nacimiento no puede ser nulo ';
      return;
    end if;
    if nvl(p_telefono, 'x') = 'x' and nvl(p_tip_operacion, 'x') = 'E' then
      p_cod_error := 7;
      p_msj_error := 'El nro de celular no puede ser nulo ';
      return;
    end if;
    begin
      select p.tipo, p.cod_persona
        into v_tip_persona, p_cod_persona
        from ba_personas p
       where p.nro_documento = p_nro_documento
         and p.cod_tip_documento = p_tip_documento
         and p.cod_pais = p_cod_pais;
    exception
      when no_data_found then
        --no se encontro datos los parametros especificos, buscar solo por numero de documento
        begin
          select count(1)
            into v_existe
            from ba_personas p
           where p.nro_documento = trim(p_nro_documento);
          if nvl(v_existe, 0) >= 1 then
            p_cod_error := 2;
            p_msj_error := 'Error al recuperar datos de la persona. Existe mas de un registro.';
          elsif nvl(v_existe, 0) = 0 then
            p_cod_error := 1;
            p_msj_error := 'Persona no registrada en el sistema';
          end if;
        exception
          when no_data_found then
            p_cod_error := 1;
            p_msj_error := 'Persona no registrada en el sistema';
        end;
      when too_many_rows then
        p_cod_error := 2;
        p_msj_error := 'Error al recuperar datos de la persona. Existen datos similares.';
    end;
    if v_tip_persona = 'F' and nvl(p_cod_error, 0) = 0 then
      -- persona fisica
      begin

        select f.pri_nombre,
               f.seg_nombre,
               f.pri_apellido,
               f.seg_apellido,
               f.cod_sexo,
               f.cod_pai_nacionalidad,
               f.fec_nacimiento,
               p.fec_vto_documento,
               t.area || t.telefono telefono_principal,
               p.dir_correo email,
               d.direccion,
               f.cod_profesion,
               n.descripcion,
               n.deseng
          INTO p_pri_nombre,
               p_seg_nombre,
               p_pri_apellido,
               p_seg_apellido,
               p_cod_sexo,
               p_cod_pai_nacionalidad,
               v_fec_nacimiento,
               p_fec_vto_documento,
               v_telefono,
               p_email,
               p_direccion,
               p_cod_profesion,
               p_desc_prof,
               p_desc_prof_ing
          from ba_personas        p,
               ba_per_fisicas     f,
               ba_telefonos       t,
               ba_direcciones     d,
               ba_ser_profesiones m,
               ba_ser_profesiones n
         where p.cod_persona = f.cod_persona
           and p.cod_persona = t.cod_persona(+)
           and p.cod_persona = d.cod_persona(+)
           and t.principal(+) = 'S'
           and d.principal(+) = 'S'
           and f.cod_profesion = m.cod_profesion(+)
           and m.cod_map = n.cod_profesion(+)
           and p.cod_tip_documento = p_tip_documento
           and p.nro_documento = p_nro_documento
           and p.cod_pais = p_cod_pais;

        p_cod_error := 0;
      exception

        when too_many_rows then
          p_cod_error := 2;
          p_msj_error := 'Error al recuperar datos de la persona. Existe mas de un registro';
        when others then
          p_cod_error := 3;
          p_msj_error := 'Error al recuperar datos de la persona';
      end;
      --Valida que la fecha de nacimiento corresponda a la persona
      if p_tip_operacion = 'E' then
        if p_fec_nacimiento != v_fec_nacimiento then
          p_cod_error := 8;
          p_msj_error := 'Fecha de nacimiento : ' || p_fec_nacimiento ||
                         ' no corresponde a la persona';
          return;
        end if;
        --Valida numero de celular
        if p_telefono != v_telefono then
          p_cod_error := 9;
          p_msj_error := 'El numero ' || p_telefono ||
                         ' no corresponde a la persona';
          return;
        end if;
        if nvl(p_cod_error, 0) = 0 then
          p_cod_error := 0;
          p_msj_error := 'Los datos son correctos';
        end if;
      else
        p_fec_nacimiento := v_fec_nacimiento;
        p_telefono       := v_telefono;
      end if;

    elsif v_tip_persona = 'J' then
      if nvl(p_tip_operacion, 'x') = 'E' then
        -- Persona Juridica
        p_cod_error := 4;
        p_msj_error := 'Persona es del tipo Juridica';
      else
        begin
          select f.raz_social,
                 null seg_nombre,
                 null pri_apellido,
                 null seg_apellido,
                 null cod_sexo,
                 p.cod_pais,
                 f.fec_apertura,
                 null fec_vto_documento,
                 t.area || t.telefono telefono_principal,
                 p.dir_correo email,
                 d.direccion,
                 null cod_profesion,
                 null descripcion,
                 null deseng
            INTO p_pri_nombre,
                 p_seg_nombre,
                 p_pri_apellido,
                 p_seg_apellido,
                 p_cod_sexo,
                 p_cod_pai_nacionalidad,
                 v_fec_nacimiento,
                 p_fec_vto_documento,
                 v_telefono,
                 p_email,
                 p_direccion,
                 p_cod_profesion,
                 p_desc_prof,
                 p_desc_prof_ing
            from ba_personas      p,
                 ba_per_juridicas f,
                 ba_telefonos     t,
                 ba_direcciones   d
           where p.cod_persona = f.cod_persona
             and p.cod_persona = t.cod_persona(+)
             and p.cod_persona = d.cod_persona(+)
             and t.principal(+) = 'S'
             and d.principal(+) = 'S'
             and p.cod_tip_documento = p_tip_documento
             and p.nro_documento = p_nro_documento
             and p.cod_pais = p_cod_pais;
        exception
          when no_data_found then
            p_cod_error := 5;
            p_msj_error := 'No se encontraron datos';
          when others then
            p_cod_error := 6;
            p_msj_error := 'Error al consultar datos' || sqlerrm;
        end;
      end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      v_det_error := 'Documento : ' || p_nro_documento || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_OBT_DAT_PERSONA',
                            v_det_error,
                            p_cod_persona,
                            null);
    end if;
  exception
    when others then
      p_cod_error := 5;
      p_msj_error := DBMS_UTILITY.format_error_backtrace || ' ' ||
                     DBMS_UTILITY.format_error_stack;
      v_det_error := 'Documento : ' || p_nro_documento || ' Error: Cod. ' ||
                     p_cod_error || '-' || p_msj_error;
      PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_OBT_DAT_PERSONA',
                            v_det_error,
                            p_cod_persona,
                            null);
  end pr_obt_dat_persona;

  -- Procedimiento para pago se servicios por OTROS FACTURADORES 
procedure pr_gen_pag_servicio(p_cod_persona     in varchar2/*Codigo Persona Fisica*/,
                              p_nro_cuenta      in varchar2,
                              p_cod_empresa     in number,/*Id Empresa del Servicio*/
                              p_cod_servicio    in number,
                              p_tip_operacion   in varchar2,
                              p_monto           in float,
                              p_moneda          in varchar2,
                              p_nom_comercial   in varchar2,
                              p_referencia      in varchar2,
                              p_nro_transaccion out varchar2,
                              p_fec_transaccion out date,
                              p_error           out number,
                              p_respuesta       out varchar2,
                              p_codigoCanal     in varchar2 default null,
                              p_canal           in varchar2 default null,
                              p_cod_per_empresa in varchar2 default null,/*Codigo Persona Empresa(Juridica)*/
                              p_cod_pag_servicio in varchar2 default null/*Codigo Pago Servicio Base Intermedia*/
                              ) is
    v_cod_transaccion_deb NUMBER(4);
    v_cod_transaccion_cre NUMBER(4);
    v_cod_tra_padre       NUMBER(4);
    v_numero_secuencia    NUMBER(3) := 0;
    --v_moneda              ba_monedas.cod_moneda%type;
    v_cod_moneda_facturador ba_monedas.cod_moneda%type;
    v_cod_moneda          ba_monedas.cod_moneda%type;
    v_mon_cre             ge_movimientos.monto%type;
    v_det_error           ge_log_errores.det_error%type;
    v_ofi_cta_debito      ah_cta_vistas.cod_oficina%type;
    v_mod_cta_facturador  ah_cta_vistas.cod_modulo%type;
    v_mad_cta_facturador  ah_cta_vistas.cod_modalidad%type;
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type;
    v_cod_mon_local       ba_monedas.cod_moneda%type;
    v_fec_actual          date;
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);
    v_hora_c              ge_movimientos.hora%TYPE;
    v_usuario             ge_movimientos.cod_usuario%type;
    v_est_inicial         ba_modulos.estado%type;
    v_est_actual          ba_modulos.estado%type;
    v_nro_movimiento      bw_movimientos.nro_movimiento%type; /*UPS-388*/
    v_nro_operacion       bw_movimientos.nro_documento%type;  /*UPS-388*/
    v_cod_operacion       VARCHAR2(3) := '089';               /*UPS-388*/
    v_cta_facturador      ge_movimientos.nro_cuenta%type;
    v_cod_ente            ge_par_entes.cod_ente%type := null;
    v_cod_ente_servicio   ba_cod_referencias.val_minimo%type := null;
    v_existe_e            varchar2(1):= 'N';

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    p_error := 0;
    savepoint pago_servicio;

    if nvl(p_cod_servicio, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de servicio ';
      return;
    end if;

    if nvl(p_monto, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Ingresar Monto operacion ';
      return;
    end if;

    if nvl(p_moneda, '0') = '0' then
      p_error     := 3;
      p_respuesta := 'Ingresar moneda de operacion ';
      return;
    end if;

    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'Ingresar numero de cuenta debito ';
      return;
    end if;

    if fu_es_conjunta(p_nro_cuenta) = 'S' and p_cod_per_empresa is null then--UPS-890 - No aplica para empresas
      p_error     := 5;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;

    v_cod_mon_local := pag_gen.fu_obt_mon_local();

    if v_cod_mon_local <> p_moneda then
      p_error     := 6;
      p_respuesta := 'Transaccion Invalida. Moneda no permitida para la operación';
    end if;

     begin --se toma cuenta 1
        select c.val_maximo
          into v_cod_ente
          from ba_cod_referencias c
         where c.dominio = 'COD_ENT_PAG_SERVICIO'
           and c.val_minimo = trim(p_cod_empresa);
     dbms_output.put_line('v_cod_ente: '||v_cod_ente); 
     exception
       when NO_DATA_FOUND then
         v_cod_ente := null;
     
       when others then
         v_cod_ente := null;
     end;
     begin --para tomar cuenta 2
        select c.val_maximo
          into v_cod_ente_servicio
          from ba_cod_referencias c
         where c.dominio = 'COD_ENT_PAG_SERVICIO'
           and c.val_minimo =  trim(p_cod_empresa||','||p_cod_servicio);
           dbms_output.put_line('v_cod_ente_servicio: '||v_cod_ente_servicio); 
     exception
        when NO_DATA_FOUND then
           v_cod_ente_servicio := null;
        when others then
           v_cod_ente_servicio := null;
     end;

    if nvl(nvl(v_cod_ente_servicio,v_cod_ente),-1) = -1 then
      p_error     := 8;
      p_respuesta := 'Empresa no registrada en ba_cod_referencias como Ente';
      return;
    end if; 

    begin
      Select 'S'
        into v_existe_e
        from ge_entes t
       where t.tipo = 'CN'
         and t.cod_ente = nvl(v_cod_ente_servicio,v_cod_ente);
    exception
      when no_data_found then
        v_existe_e := 'N';
      when others then
        v_existe_e := 'N';
    end;

    if nvl(v_existe_e, 'N') = 'N' then
      p_error     := 8;
      p_respuesta := 'Ente no registrado en Ge_entes ';
      return;
    end if;

    if nvl(p_error, 0) = 0 then
      pag_cta.PR_OBT_CUENTA(p_nro_cuenta);

      if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
        v_ofi_cta_debito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_moneda     := pag_cta.G_CTAS.cod_moneda;
        if v_cod_mon_local <> v_cod_moneda then
          p_error     := 9;
          p_respuesta := 'La cuenta en ' || v_cod_moneda ||
                         ' no está permitida para la operación';
        end if;
      else
        p_error     := 10;
        p_respuesta := 'Error al obtener cuenta debito ' || p_nro_cuenta;
        v_det_error := pag_cta.G_LUGAR || ' - ' || pag_cta.G_COD_ERROR ||
                       ' - ' || pag_cta.G_MSJ_ERROR;
      end if;

      --Recupera la cuenta del FACTURADOR de acuerdo ala Ente/Servicio que se recupera
      pag_cta.G_CTAS    := null;
      if v_cod_ente_servicio is not null then-- Si es similar a DVC tomar cta2
         v_cta_facturador := it.fug_obt_parentes(v_cod_ente_servicio, 'CTA_OP_PAG_SERVICIO2');   
      elsif v_cod_ente_servicio is null and v_cod_ente is not null then
         v_cta_facturador := it.fug_obt_parentes(v_cod_ente, 'CTA_OP_PAG_SERVICIO');
      else
         v_cta_facturador := null;
      end if;
      if nvl(v_cta_facturador, 'x') != 'x' then
        pag_cta.PR_OBT_CUENTA(v_cta_facturador);

        if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
          v_cod_moneda_facturador := pag_cta.G_CTAS.cod_moneda;
          v_mod_cta_facturador    := pag_cta.G_CTAS.COD_MODULO;
          v_mad_cta_facturador    := pag_cta.G_CTAS.COD_MODALIDAD;

        else
          p_error     := 11;
          p_respuesta := 'Ocurrió un error en el proceso de pago';
          v_det_error := 'Error al obtener cuenta operativa para wepa ' ||
                         v_cta_facturador || ' - ' || pag_cta.G_LUGAR ||
                         ' - ' || pag_cta.G_COD_ERROR || ' - ' ||
                         pag_cta.G_MSJ_ERROR;
        end if;
      else
        p_error     := 12;
        p_respuesta := 'Ocurrió un error en el proceso de pago';
        v_det_error := 'La cuenta operativa para el ente facturador no se encuentra configurada en el parametro "CTA_OP_PAG_SERVICIO"';

      end if;
    end if;
    /*******Pago de servicio VARIOS FACTURADORES *************/
    if nvl(p_error, 0) = 0 then
      lp_ver_horario(v_ofi_cta_debito,
                     '3',/*v_mod_cta_debito,*/ --FSOP-20695 siempre debe tomar el 3 para validar el horario, por ser el maestro de los módulos
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                     v_fec_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
      --recuperamos el estado inicial del modulo;
      v_est_inicial:=g_mod_estado;           

      if nvl(v_error, 0) != '0' then
        p_error     := 13;
        p_respuesta := 'Ocurrió un error en el proceso de pago';
        v_det_error := v_respuesta;
      else
        v_cod_tra_padre       := it.fug_obt_parentes(nvl(v_cod_ente_servicio,v_cod_ente), 'COD_TRA_PAD_PAG_SERVICIO');
        v_cod_transaccion_deb := it.fug_obt_parentes(nvl(v_cod_ente_servicio,v_cod_ente), 'COD_TRA_DEB_PAG_SERVICIO');
        v_cod_transaccion_cre := it.fug_obt_parentes(nvl(v_cod_ente_servicio,v_cod_ente), 'COD_TRA_CRE_PAG_SERVICIO');
        if nvl(v_cod_tra_padre, -1) = -1 then
          p_error     := 14;
          p_respuesta := 'Ocurrió un error en el proceso de pago';
          v_det_error := 'La trans. padre para el ente facturador no se encuentra configurada en el parametro "COD_TRA_PAD_PAG_SERVICIO"';
        elsif nvl(v_cod_transaccion_deb, -1) = -1  then
          p_error     := 15;
          p_respuesta := 'Ocurrió un error en el proceso de pago';
          v_det_error := 'La trans. debito para el ente facturador no se encuentra configurada en el parametro "COD_TRA_DEB_PAG_SERVICIO"';
        elsif nvl(v_cod_transaccion_cre, -1) = -1  then
          p_error     := 16;
          p_respuesta := 'Ocurrió un error en el proceso de pago';
          v_det_error := 'La trans. credito para el ente facturador no se encuentra configurada en el parametro "COD_TRA_CRE_PAG_SERVICIO"';
        else
          null;
        end if; 
        v_cod_ofi_origen      := fug_obt_ofi_usuario(user);
        p_nro_transaccion     := to_number(to_char((sysdate),
                                                   'rrmmddhh24') ||
                                           it.S_NRO_TRA_WEPA.nextval);
        p_fec_transaccion     := sysdate;
        
        v_usuario   := it.fug_obt_mov_user('SERVICEPAY','S_SER_USER_SERVICEPAY'); 


        v_hora_c    := it.fug_obt_hora(v_usuario,'s_hor_movim');
     
                       
        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_origen);
        
        --verificacion datos cuenta a Debitar
        pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
        pag_cta.pr_set_nro_documento3(p_cod_empresa);
        --Verificamos que el estado del modulo aún se encuentre disponible
        v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
        if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
             p_error     := 17;
             p_respuesta := 'Ocurrió un error en el proceso de pago';
             v_det_error := 'Entidad en proceso de cierre, vuelva a intentar';
             raise_application_error(-20000,v_det_error);
        end if;/*FSOP-20695*/

        pag_cta.pr_act_operacion(p_nro_cuenta      => p_nro_cuenta,
                                 p_hora            => v_hora_c,
                                 p_tip_movimiento  => 'D',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => p_monto,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_deb,
                                 p_nro_documento   => p_nro_transaccion,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => v_cod_ofi_origen,
                                 p_cod_mod_padre   => v_mod_cta_facturador,--v_mod_cta_debito,
                                 p_cod_mad_padre   => v_mad_cta_facturador,--v_mad_cta_debito,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => substr('Pago de servicio ' ||
                                                             p_nom_comercial,
                                                             1,
                                                             100),
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);

        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := 18;
          p_respuesta := pag_cta.g_msj_error;
          v_det_error := substr('Ocurrió el sgte. error en el proceso de debito: ' ||
                                ltrim(to_char(pag_cta.g_cod_error, '000')) || ' ' ||
                                pag_cta.g_msj_error,
                                1,
                                4000);
        else
          v_mon_cre := p_monto;
          pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_origen);

          -- Credito pago servicio
          pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
          pag_cta.pr_set_nro_documento3(p_cod_empresa);
          --Verificamos que el estado del modulo aún se encuentre disponible
          v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
          if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
               p_error     := 19;
               p_respuesta := 'Ocurrió un error en el proceso de pago';
               v_det_error := 'Entidad en proceso de cierre, vuelva a intentar';
               raise_application_error(-20001,v_det_error);
          end if;/*FSOP-20695*/

          pag_cta.pr_act_operacion(p_nro_cuenta      => v_cta_facturador,
                                   p_hora            => v_hora_c,
                                   p_tip_movimiento  => 'C',
                                   p_cod_moneda      => v_cod_moneda_facturador,
                                   p_monto           => v_mon_cre,
                                   p_cod_tra_padre   => v_cod_tra_padre,
                                   p_cod_transaccion => v_cod_transaccion_cre,
                                   p_nro_documento   => p_nro_transaccion,
                                   p_cotizacion      => null,
                                   p_cod_ofi_origen  => v_cod_ofi_origen,
                                   p_cod_mod_padre   => v_mod_cta_facturador,
                                   p_cod_mad_padre   => v_mad_cta_facturador,
                                   p_cod_tasa        => null,
                                   p_val_tasa        => null,
                                   p_concepto        => substr('Pago de servicio ' ||
                                                               p_nom_comercial,
                                                               1,
                                                               100),
                                   p_emi_aviso       => 'N',
                                   p_nro_secuencia   => v_numero_secuencia,
                                   p_fec_valor       => trunc(sysdate),
                                   p_cod_banco       => null,
                                   p_cod_causa       => null,
                                   p_mto_equ_local   => null);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            p_error     := 20;
            p_respuesta := 'Ocurrió un error en el proceso de pago';
            v_det_error := substr('Ocurrió el sgte. error en el proceso de debito ' ||
                                  ltrim(to_char(pag_cta.g_cod_error, '000')) ||
                                  pag_cta.g_msj_error,
                                  1,
                                  4000);

          else
            begin
             insert into bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 red_pago,
                 des_servicio,
                 par_enviados,
                 nro_caja,
                 canal,
                 cod_pag_servicio)
              VALUES
                (p_nro_cuenta,
                 p_cod_servicio,
                 v_fec_actual,
                 v_hora_c,
                 p_nro_transaccion,
                 0,
                 null,
                 null,
                 v_cod_moneda,
                 p_monto,
                 null,
                 null,
                 null,
                 'N',
                 p_monto,
                 null,
                 7, -- 6 Wepa / 7 Aduanas y Otros
                 substr(p_nom_comercial, 1, 250),
                 substr('Referencia:'||p_referencia||' Cod.Empresa:' || p_cod_empresa || ' Tip.operacion:' ||
                 p_tip_operacion,1,2000),
                 p_codigoCanal,
                 upper(p_canal),
                 p_cod_pag_servicio)
                 ;
            exception
              when others then
                p_error     := 21;
                p_respuesta := 'Error al procesar transaccion';
                v_det_error := 'Error al procesar transaccion' || sqlerrm;
            end;
            if p_error <> 0 then /*UPS-388*/
              null;
            else
              if nvl(p_codigoCanal,'998') <> '999' then--si es distinto a web que no inserte
                 null;
              else 
                SELECT s_nro_ope_homebanking.NEXTVAL
                  INTO v_nro_operacion
                  FROM dual;
            
               select s_nro_bw_movimiento.nextval
                 into v_nro_movimiento
                 from dual;
               -- registro del movimiento
               begin
               lp_reg_operacion(p_nro_cuenta,--v_cuenta          /*p_nro_cuenta*/,
                                v_cod_moneda,--v_cod_mon_debito  /*p_cod_moneda */,
                                p_monto,--v_mto_debito           /*p_monto*/,
                                NULL                             /*p_nro_cta_contra*/,
                                NULL                             /*p_cantidad*/,
                                NULL                             /*p_etiqueta*/,
                                p_cod_servicio,--p_proveedor     /*p_dato*/,
                                NULL,--'Cotizacion'              /*p_etiqueta2*/,
                                NULL,--v_cot_debito              /*p_dato2*/,
                                substr('Pago de servicios ' ||
                                                                 p_nom_comercial,
                                                                 1,
                                                                 100),--'Pago de servicios'||v_cot_credito /*observacion*/,
                                NULL                             /*direccion IP*/,
                                '000',
                                p_cod_persona,--userinfo.codigopersona,
                                v_cod_operacion,
                                v_nro_operacion,
                                p_codigoCanal,
                                'XXXX',--p_sesion,
                                p_cod_per_empresa,--userinfo.codigoempresa,
                                null,                
                                null,                            /*p_etiqueta3*/
                                p_nro_transaccion,               /*p_dato3*/
                                null,--v_nro_documento,
                                v_nro_movimiento,
                                upper(p_canal)--p_canal
                                );
               exception
                when others then
                  p_error     := 22;
                  p_respuesta := 'Error al procesar transaccion';
                  v_det_error := 'Error al procesar transaccion' || sqlerrm;
               end;
              end if;
            end if;/*UPS-388*/
          end if;
        end if;
      end if;
    end if;
    --Verificacion para Retorno
    if p_error <> 0 then
      v_det_error := substr('Empresa : ' || p_cod_empresa || ' Servicio: ' ||
                            p_cod_servicio || ' Ente: ' || nvl(v_cod_ente_servicio,v_cod_ente) || 
                            ' Moneda: ' || p_moneda ||
                            ' Monto' || p_monto || ' Tipo oper. ' ||
                            p_tip_operacion || ' Nom.comercial ' ||
                            p_nom_comercial || ' Error: ' || p_error ||
                            ' - ' || nvl(v_det_error, p_respuesta) ||
                            ' user ' || v_usuario,
                            1,
                            4000);

      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        --Registro log
        PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_PAG_SERVICIO',
                              v_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
      --Retorno caso de error
      p_nro_transaccion := null;
      p_fec_transaccion := null;
      rollback to pago_servicio;
    else
      --Retorno Operacion exitosa
      p_error     := 0;
      p_respuesta := 'Operacion Confirmada';
    end if;
  exception
    when others then
      --Retorno caso de error
      p_nro_transaccion := null;
      p_fec_transaccion := null;
      if p_respuesta is null then-- para tomar el error anterior
      p_respuesta := 'Ocurrió un error inesperado en el proceso de pago';
      p_error     := 99;
      v_det_error := substr('Empresa : ' || p_cod_empresa || ' Servicio: ' ||
                            p_cod_servicio || ' Ente: ' || nvl(v_cod_ente_servicio,v_cod_ente) || 
                            ' Moneda: ' || p_moneda ||
                            ' Monto' || p_monto || ' Tipo oper. ' ||
                            p_tip_operacion || ' Nom.comercial ' ||
                            p_nom_comercial || ' Error: ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace || ' user ' || v_usuario,
                            1,
                            4000);
      end if;

      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_PAG_SERVICIO',
                              v_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
      rollback;
  end pr_gen_pag_servicio;
  -- Procedimiento para pago se servicios por WEPA 
procedure pr_gen_pag_servicio_canal(p_cod_persona     in varchar2/*Codigo Persona Fisica*/,
                                    p_nro_cuenta      in varchar2,
                                    p_cod_empresa     in number,/*Id Empresa del Servicio*/
                                    p_cod_servicio    in number,
                                    p_tip_operacion   in varchar2,
                                    p_monto           in float,
                                    p_moneda          in varchar2,
                                    p_nom_comercial   in varchar2,
                                    p_referencia      in varchar2,
                                    p_nro_transaccion out varchar2,
                                    p_fec_transaccion out date,
                                    p_error           out number,
                                    p_respuesta       out varchar2,
                                    p_codigoCanal     in varchar2 default null,
                                    p_canal           in varchar2 default null,
                                    p_cod_per_empresa in varchar2 default null,/*Codigo Persona Empresa(Juridica)*/
                                    p_cod_pag_servicio in varchar2 default null/*Codigo Pago Servicio Base Intermedia*/
                                    ) is
    v_nro_cuenta_wepa     ge_movimientos.nro_cuenta%type;
    v_cod_transaccion_deb NUMBER(4);
    v_cod_transaccion_cre NUMBER(4);
    v_cod_tra_padre       NUMBER(4);
    v_numero_secuencia    NUMBER(3) := 0;
    v_moneda              ba_monedas.cod_moneda%type;
    v_cod_moneda_wepa     ba_monedas.cod_moneda%type;
    v_cod_moneda          ba_monedas.cod_moneda%type;
    v_mon_cre             ge_movimientos.monto%type;
    v_det_error           ge_log_errores.det_error%type;
    v_ofi_cta_debito      ah_cta_vistas.cod_oficina%type;
    v_mod_cta_wepa        ah_cta_vistas.cod_modulo%type;
    v_mad_cta_wepa        ah_cta_vistas.cod_modalidad%type;
    v_cod_ofi_origen      ba_oficinas.cod_oficina%type;
    --v_mod_cta_debito      ah_cta_vistas.cod_modulo%type;
    --v_mad_cta_debito      ah_cta_vistas.cod_modalidad%type;
    v_cod_mon_local       ba_monedas.cod_moneda%type;
    v_fec_actual          date;
    v_horario             varchar2(1);
    v_es_mov_noc          varchar2(1);
    v_es_cta_noc          varchar2(1);
    v_fec_valor           ge_calendarios.fec_actual%type;
    v_error               number;
    v_respuesta           varchar(4000);
    v_hora_c              ge_movimientos.hora%TYPE;
    v_usuario             ge_movimientos.cod_usuario%type;
    v_est_inicial         ba_modulos.estado%type;
    v_est_actual          ba_modulos.estado%type;
    v_nro_movimiento      bw_movimientos.nro_movimiento%type; /*UPS-388*/
    v_nro_operacion       bw_movimientos.nro_documento%type;  /*UPS-388*/
    v_cod_operacion       VARCHAR2(3) := '089';               /*UPS-388*/

  begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    p_error := 0;
    savepoint pago_servicio;

    if nvl(p_cod_servicio, 0) = 0 then
      p_error     := 1;
      p_respuesta := 'Ingresar codigo de servicio ';
      return;
    end if;

    if nvl(p_monto, 0) = 0 then
      p_error     := 2;
      p_respuesta := 'Ingresar Monto operacion ';
      return;
    end if;

    if nvl(p_moneda, '0') = '0' then
      p_error     := 3;
      p_respuesta := 'Ingresar moneda de operacion ';
      return;
    else
      v_moneda := p_moneda;
    end if;

    if nvl(p_nro_cuenta, 'x') = 'x' then
      p_error     := 4;
      p_respuesta := 'Ingresar numero de cuenta debito ';
      return;
    end if;

    if fu_es_conjunta(p_nro_cuenta) = 'S' and p_cod_per_empresa is null then--UPS-890 - No aplica para empresas
      p_error     := 5;
      p_respuesta := 'La cuenta es conjunta ';
      return;
    end if;

    v_cod_mon_local := pag_gen.fu_obt_mon_local();

    if v_cod_mon_local <> p_moneda then
      p_error     := 6;
      p_respuesta := 'Transaccion Invalida. Moneda no permitida para la operación';
    end if;

    if nvl(p_error, 0) = 0 then
      pag_cta.PR_OBT_CUENTA(p_nro_cuenta);

      if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
        v_ofi_cta_debito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_moneda     := pag_cta.G_CTAS.cod_moneda;
        --v_mod_cta_debito  := pag_cta.G_CTAS.COD_MODULO;
        --v_mad_cta_debito  := pag_cta.G_CTAS.COD_MODALIDAD;
        if v_cod_mon_local <> v_cod_moneda then
          p_error     := 7;
          p_respuesta := 'La cuenta en ' || v_cod_moneda ||
                         ' no está permitida para la operación';
        end if;
      else
        p_error     := 8;
        p_respuesta := 'Error al obtener cuenta debito ' || p_nro_cuenta;
        v_det_error := pag_cta.G_LUGAR || ' - ' || pag_cta.G_COD_ERROR ||
                       ' - ' || pag_cta.G_MSJ_ERROR;
      end if;

      --Recupera la cuenta del WEPA de acuerdo a la moneda que se recibe
      pag_cta.G_CTAS    := null;
      v_nro_cuenta_wepa := fug_obt_pardinamico(p_parametro     => 'CTA_OP_WEPA',
                                               p_cod_modulo    => null,
                                               p_cod_modalidad => null,
                                               p_cod_moneda    => 'GS',
                                               p_cod_oficina   => null);

      if nvl(v_nro_cuenta_wepa, 'x') != 'x' then
        pag_cta.PR_OBT_CUENTA(v_nro_cuenta_wepa);

        if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
          --v_ofi_cta_wepa    := pag_cta.G_CTAS.COD_OFICINA;
          v_cod_moneda_wepa := pag_cta.G_CTAS.cod_moneda;
          v_mod_cta_wepa    := pag_cta.G_CTAS.COD_MODULO;
          v_mad_cta_wepa    := pag_cta.G_CTAS.COD_MODALIDAD;

        else
          p_error     := 9;
          p_respuesta := 'Ocurrió un error en el proceso de pago';
          v_det_error := 'Error al obtener cuenta operativa para wepa ' ||
                         v_nro_cuenta_wepa || ' - ' || pag_cta.G_LUGAR ||
                         ' - ' || pag_cta.G_COD_ERROR || ' - ' ||
                         pag_cta.G_MSJ_ERROR;
        end if;
      else
        p_error     := 10;
        p_respuesta := 'Ocurrió un error en el proceso de pago';
        v_det_error := 'La cuenta operativa para Wepa no se encuentra configurada en el parametro "CTA_OP_WEPA"';

      end if;
    end if;
    /*******Pago de servicio POR WEPA *************/
    if nvl(p_error, 0) = 0 then
      lp_ver_horario(v_ofi_cta_debito,
                     '3',/*v_mod_cta_debito,*/ --FSOP-20695 siempre debe tomar el 3 para validar el horario, por ser el maestro de los módulos
                     v_horario,
                     v_es_mov_noc,
                     v_es_cta_noc,
                     v_fec_actual,
                     v_fec_valor,
                     v_error,
                     v_respuesta);
      --recuperamos el estado inicial del modulo;
      v_est_inicial:=g_mod_estado;           
      --v_fec_actual := PAG_APP.v_fec_sistema;

      if nvl(v_error, 0) != '0' then
        p_error     := 11;
        p_respuesta := 'Ocurrió un error en el proceso de pago';
        v_det_error := v_respuesta;
      else
        

        v_cod_tra_padre       := it.fug_obt_pardinamico(p_parametro  => 'COD_TRA_PADRE_WEPA',
                                                        p_cod_moneda => v_moneda);
        v_cod_transaccion_deb := it.fug_obt_pardinamico(p_parametro  => 'COD_TRA_DEB_WEPA',
                                                        p_cod_moneda => v_moneda);
        v_cod_transaccion_cre := it.fug_obt_pardinamico(p_parametro  => 'COD_TRA_CRE_WEPA',
                                                        p_cod_moneda => v_moneda);
        v_cod_ofi_origen      := fug_obt_ofi_usuario(user);
        p_nro_transaccion     := to_number(to_char((sysdate),
                                                   'rrmmddhh24') ||
                                           it.S_NRO_TRA_WEPA.nextval);
        p_fec_transaccion     := sysdate;
        
        v_usuario   := it.fug_obt_mov_user('SERVICEPAY','S_SER_USER_SERVICEPAY'); 


        v_hora_c    := it.fug_obt_hora(v_usuario,'s_hor_movim');
     
                       
        pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_origen);

        
        --verificacion datos cuenta a Debitar
        pag_cta.PR_OBT_CUENTA(p_nro_cuenta);
        pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
        pag_cta.pr_set_nro_documento3(p_cod_empresa);
        --Verificamos que el estado del modulo aún se encuentre disponible
        v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
        if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
             p_error     := 12;
             p_respuesta := 'Ocurrió un error en el proceso de pago';
             v_det_error := 'Entidad en proceso de cierre, vuelva a intentar';
             raise_application_error(-20002,v_det_error);
        end if;/*FSOP-20695*/
      
        pag_cta.pr_act_operacion(p_nro_cuenta      => p_nro_cuenta,
                                 p_hora            => v_hora_c,
                                 p_tip_movimiento  => 'D',
                                 p_cod_moneda      => v_cod_moneda,
                                 p_monto           => p_monto,
                                 p_cod_tra_padre   => v_cod_tra_padre,
                                 p_cod_transaccion => v_cod_transaccion_deb,
                                 p_nro_documento   => p_nro_transaccion,
                                 p_cotizacion      => null,
                                 p_cod_ofi_origen  => v_cod_ofi_origen,
                                 p_cod_mod_padre   => v_mod_cta_wepa,--v_mod_cta_debito,
                                 p_cod_mad_padre   => v_mad_cta_wepa,--v_mad_cta_debito,
                                 p_cod_tasa        => null,
                                 p_val_tasa        => null,
                                 p_concepto        => substr('Pago de servicio ' ||
                                                             p_nom_comercial,
                                                             1,
                                                             100),
                                 p_emi_aviso       => 'N',
                                 p_nro_secuencia   => v_numero_secuencia,
                                 p_fec_valor       => trunc(sysdate),
                                 p_cod_banco       => null,
                                 p_cod_causa       => null,
                                 p_mto_equ_local   => null);

        if pag_cta.g_cod_error <> 0 then
          -- actualizacion con problemas
          p_error     := 13;
          p_respuesta := pag_cta.g_msj_error;
          v_det_error := substr('Ocurrió el sgte. error en el proceso de debito: ' ||
                                ltrim(to_char(pag_cta.g_cod_error, '000')) || ' ' ||
                                pag_cta.g_msj_error,
                                1,
                                4000);
        else
          v_mon_cre := p_monto;
          pag_cta.pr_set_variables(p_cod_usuario => v_usuario,
                                 p_fec_valor => trunc(sysdate),
                                 p_cod_tra_padre => v_cod_tra_padre,
                                 p_estado => 'N',
                                 p_reversado => 'N',
                                 p_nro_secuencia => v_numero_secuencia,
                                 p_est_cuenta => null,
                                 p_cod_ofi_origen => v_cod_ofi_origen);

          -- Credito pago servicio
          pag_cta.pr_set_nro_documento2(p_nro_documento2 => p_cod_servicio);
          pag_cta.pr_set_nro_documento3(p_cod_empresa);
          --Verificamos que el estado del modulo aún se encuentre disponible
          v_est_actual:=pae_cnf.fu_obt_est_modulo(3);/*FSOP-20695*/
          if (v_est_inicial!=v_est_actual or v_est_actual in (1,6)) then
               p_error     := 14;
               p_respuesta := 'Ocurrió un error en el proceso de pago';
               v_det_error := 'Entidad en proceso de cierre, vuelva a intentar';
               raise_application_error(-20003,v_det_error);
          end if;/*FSOP-20695*/

          pag_cta.pr_act_operacion(p_nro_cuenta      => v_nro_cuenta_wepa,
                                   p_hora            => v_hora_c,
                                   p_tip_movimiento  => 'C',
                                   p_cod_moneda      => v_cod_moneda_wepa,
                                   p_monto           => v_mon_cre,
                                   p_cod_tra_padre   => v_cod_tra_padre,
                                   p_cod_transaccion => v_cod_transaccion_cre,
                                   p_nro_documento   => p_nro_transaccion,
                                   p_cotizacion      => null,
                                   p_cod_ofi_origen  => v_cod_ofi_origen,
                                   p_cod_mod_padre   => v_mod_cta_wepa,
                                   p_cod_mad_padre   => v_mad_cta_wepa,
                                   p_cod_tasa        => null,
                                   p_val_tasa        => null,
                                   p_concepto        => substr('Pago de servicio ' ||
                                                               p_nom_comercial,
                                                               1,
                                                               100),
                                   p_emi_aviso       => 'N',
                                   p_nro_secuencia   => v_numero_secuencia,
                                   p_fec_valor       => trunc(sysdate),
                                   p_cod_banco       => null,
                                   p_cod_causa       => null,
                                   p_mto_equ_local   => null);
          if pag_cta.g_cod_error <> 0 then
            -- actualizacion con problemas
            p_error     := 15;
            p_respuesta := 'Ocurrió un error en el proceso de pago';
            v_det_error := substr('Ocurrió el sgte. error en el proceso de debito ' ||
                                  ltrim(to_char(pag_cta.g_cod_error, '000')) ||
                                  pag_cta.g_msj_error,
                                  1,
                                  4000);

          else
            begin
             insert into bw_pag_servicios
                (nro_cuenta,
                 cod_servicio,
                 fecha,
                 hora,
                 nro_transaccion,
                 nro_lote,
                 ip_usuario,
                 terminal,
                 cod_moneda,
                 mto_transaccion,
                 mto_comision,
                 mto_mora,
                 mto_interes,
                 reversado,
                 mto_debito,
                 cod_mon_servicio,
                 red_pago,
                 des_servicio,
                 par_enviados,
                 nro_caja,
                 canal,
                 cod_pag_servicio)
              VALUES
                (p_nro_cuenta,
                 p_cod_servicio,
                 v_fec_actual,
                 v_hora_c,
                 p_nro_transaccion,
                 0,
                 null,
                 null,
                 v_cod_moneda,
                 p_monto,
                 null,
                 null,
                 null,
                 'N',
                 p_monto,
                 null,
                 6, -- Wepa
                 substr(p_nom_comercial, 1, 250),
                 substr('Referencia:'||p_referencia||' Cod.Empresa:' || p_cod_empresa || ' Tip.operacion:' ||
                 p_tip_operacion,1,2000),
                 p_codigoCanal,
                 upper(p_canal),
                 p_cod_pag_servicio)
                 ;
            exception
              when others then
                p_error     := 16;
                p_respuesta := 'Error al procesar transaccion';
                v_det_error := 'Error al procesar transaccion' || sqlerrm;
            end;
            if p_error <> 0 then /*UPS-388*/
              null;
            else
              if nvl(p_codigoCanal,'998') <> '999' then--si es distinto a web que no inserte
                 null;
              else 
                SELECT s_nro_ope_homebanking.NEXTVAL
                  INTO v_nro_operacion
                  FROM dual;
            
               select s_nro_bw_movimiento.nextval
                 into v_nro_movimiento
                 from dual;
               -- registro del movimiento
               begin
               lp_reg_operacion(p_nro_cuenta,--v_cuenta          /*p_nro_cuenta*/,
                                v_cod_moneda,--v_cod_mon_debito  /*p_cod_moneda */,
                                p_monto,--v_mto_debito           /*p_monto*/,
                                NULL                             /*p_nro_cta_contra*/,
                                NULL                             /*p_cantidad*/,
                                NULL                             /*p_etiqueta*/,
                                p_cod_servicio,--p_proveedor     /*p_dato*/,
                                NULL,--'Cotizacion'              /*p_etiqueta2*/,
                                NULL,--v_cot_debito              /*p_dato2*/,
                                substr('Pago de servicios ' ||
                                                                 p_nom_comercial,
                                                                 1,
                                                                 100),--'Pago de servicios'||v_cot_credito /*observacion*/,
                                NULL                             /*direccion IP*/,
                                '000',
                                p_cod_persona,--userinfo.codigopersona,
                                v_cod_operacion,
                                v_nro_operacion,
                                p_codigoCanal,
                                'XXXX',--p_sesion,
                                p_cod_per_empresa,--userinfo.codigoempresa,
                                null,                
                                null,                            /*p_etiqueta3*/
                                p_nro_transaccion,               /*p_dato3*/
                                null,--v_nro_documento,
                                v_nro_movimiento,
                                upper(p_canal)--p_canal
                                );
               exception
                when others then
                  p_error     := 17;
                  p_respuesta := 'Error al procesar transaccion';
                  v_det_error := 'Error al procesar transaccion' || sqlerrm;
               end;
              end if;
            end if;/*UPS-388*/
          end if;
        end if;
      end if;
    end if;
    --Verificacion para Retorno
    if p_error <> 0 then
      v_det_error := substr('Empresa : ' || p_cod_empresa || ' Servicio: ' ||
                            p_cod_servicio || ' Moneda: ' || p_moneda ||
                            ' Monto' || p_monto || ' Tipo oper. ' ||
                            p_tip_operacion || ' Nom.comercial ' ||
                            p_nom_comercial || ' Error: ' || p_error ||
                            ' - ' || nvl(v_det_error, p_respuesta) ||
                            ' user ' || v_usuario,
                            1,
                            4000);

      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        --Registro log
        PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_PAG_SERVICIO_CANAL',
                              v_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
      --Retorno caso de error
      p_nro_transaccion := null;
      p_fec_transaccion := null;
      rollback to pago_servicio;
    else
      --Retorno Operacion exitosa
      p_error     := 0;
      p_respuesta := 'Operacion Confirmada';
    end if;
  exception
    when others then
      if p_respuesta is null then-- para tomar el error anterior
      p_respuesta := 'Ocurrió un error inesperado en el proceso de pago';
      p_error     := 99;
      v_det_error := substr('Empresa : ' || p_cod_empresa || ' Servicio: ' ||
                            p_cod_servicio || ' Moneda: ' || p_moneda ||
                            ' Monto' || p_monto || ' Tipo oper. ' ||
                            p_tip_operacion || ' Nom.comercial ' ||
                            p_nom_comercial || ' Error: ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace || ' user ' || v_usuario,
                            1,
                            4000);
      end if;

      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        PRG_INS_LOG_PROGRAMAS('PAG_APP.PR_GEN_PAG_SERVICIO_CANAL',
                              v_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
      end if;
      rollback;
  end pr_gen_pag_servicio_canal;



FUNCTION fu_obt_movimientos(p_nro_cuenta IN VARCHAR2,
                            p_fecha IN DATE DEFAULT NULL)
            RETURN typ_datosCuenta IS
      v_retorno            typ_datosCuenta := typ_datosCuenta;
      v_cod_persona        ba_personas.cod_persona%type:=null;
      v_cod_empresa        ba_personas.cod_persona%type:=null;
      v_nro_cta_especifica VARCHAR2(16);
      v_can_movimientos    NUMBER(8);
      v_can_detalles       NUMBER(3); -- cantidad de cuentas
      v_fec_actual         DATE := trunc(sysdate); -- fecha de hoy
      v_det_error          ge_log_errores.det_error%type; 
      v_fecha              DATE := p_fecha;
      v_existe_e           VARCHAR2(1):= 'N';
      -- cursor de cuentas pasivas del cliente
      CURSOR cuentas IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,
                fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion IN ('P')
            AND b.cod_persona = nvl(v_cod_empresa, v_cod_persona)
            AND a.cod_modulo = c.cod_modulo
            AND a.cod_modalidad = c.cod_modalidad
            AND a.estado = c.estado
            AND c.activo = 'S' -- solo cuentas activas
            AND a.estado <> 'X' -- pendiente de verificacion
            AND (b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
      -- movimientos por cuenta 
      CURSOR movimientos(p_nro_cuenta IN VARCHAR2) IS
         SELECT trunc(a.fec_insercion) fecha,a.hora,a.nro_documento,a.monto,a.tipo,
               fug_obt_tra_tip_aduana(b.cod_transaccion, b.cod_modulo, b.cod_modalidad)tipo_trans
           FROM ge_transacciones b, gv_movimientos a
          WHERE nro_cuenta = p_nro_cuenta
            AND trunc(a.fec_insercion) = nvl(v_fecha,v_fec_actual - 1)
            AND estado = 'N'
            AND a.reversado = 'N' --SOLO NO REVERSADOS
            AND monto <> 0
            AND cod_tip_movimiento IN ('D', 'C')
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
            AND (NVL(b.AFECTA,'XX') = 'B'
                AND a.COD_CAUSA IN
                    (select cod_causa
                       from ge_par_causales
                     where parametro = 'COD_CAU_BLO_EXT'
                       and val_parametro = 'S' )
                OR NVL(b.AFECTA,'XX') != 'B' ) --DDSI-306 No se muestran los levantamientos de embargos movimientos
          ORDER BY a.fecha DESC, a.fec_insercion DESC;
      -- transferencias de la cuenta
     CURSOR transferencias(p_nro_cuenta IN VARCHAR2) IS
     SELECT trunc(a.fec_insercion) fecha,a.hora,a.nro_documento,a.monto,
            decode(c.cod_swi_pte_beneficiario,'MIHAPYPA','001',nvl(lpad(d.cod_banco, 3, 0),'0')) cod_banco,--MIHAPYPA MINISTERIO DE HACIENDA
            decode(c.cod_swi_pte_beneficiario,'MIHAPYPA',nvl(nvl(replace(c.imp_inf_hacienda,'/',''),e.cod_impuesto),'0'),c.nro_cta_beneficiario) nro_cuenta--MIHAPYPA MINISTERIO DE HACIENDA
           FROM ge_transacciones b, gv_movimientos a, ge_snp_transferencias c, gv_snp_participantes d, ge_snp_imp_hacienda e
          WHERE a.nro_cuenta = p_nro_cuenta
            AND trunc(a.fec_insercion) = nvl(v_fecha,v_fec_actual - 1)
            AND a.estado = 'N'
            AND a.reversado = 'N' --SOLO NO REVERSADOS
            AND a.monto <> 0
            AND cod_tip_movimiento IN ('D', 'C')
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
            AND (NVL(b.AFECTA,'XX') = 'B'
                AND a.COD_CAUSA IN
                    (select cod_causa
                       from ge_par_causales
                     where parametro = 'COD_CAU_BLO_EXT'
                       and val_parametro = 'S' )
                OR NVL(b.AFECTA,'XX') != 'B' ) --DDSI-306 No se muestran los levantamientos de embargos movimientos
            AND a.cod_tra_padre = '303'--Transferencias interbancarias
            AND a.nro_documento=c.nro_referencia
            AND c.cod_swi_pte_beneficiario = d.cod_swift(+)
            AND d.tipo(+) = 'BA' --solo bancos
            AND c.situacion = 'L'--solo liquidado
            AND c.nro_cta_beneficiario = e.nro_cta_int_bcp(+)
          ORDER BY a.fecha DESC, a.fec_insercion DESC;
   BEGIN
    declare-- problemas de formato recibio en dd/mon/yyyy
       v_error varchar2(100);
    begin
       sql_util.ejecute_dml('alter session set nls_date_format = ''dd/mm/yyyy''', v_error);
      if v_error is not null then
        dbms_output.put_line(v_error);
      end if;
    end;
      v_retorno.error := 'N';--inicia en OK
      v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nro_cuenta, 16);
      
      -- 1.1. Armo el nro de cuenta
      IF v_nro_cta_especifica IS NULL THEN
         v_retorno.error := 'S';
         v_retorno.descripcionRespuesta := 'No se ingreso cuenta';
         RETURN v_retorno;
      ELSE --Se recupera el cod_persona Principal
         begin 
             select s.cod_persona
               into v_cod_persona
               from ge_cta_clientes s
               where s.nro_cuenta = v_nro_cta_especifica
               and s.relacion = 'P';
          exception
            when no_data_found then
              v_cod_persona := null;
            when others then
              v_cod_persona := null;
          end;
          begin --verificamos que corresponda a un ente tipo CN
            Select distinct 'S'
              into v_existe_e
              from ge_entes t,ge_par_entes t2
             where t.tipo = 'CN'
               and t.cod_ente = t2.cod_ente
               and t2.val_parametro = v_nro_cta_especifica;   
          exception
            when no_data_found then
              v_existe_e := 'N';
            when others then
              v_existe_e := 'N';
          end;        
          if nvl(v_existe_e, 'N') = 'N' then
            v_retorno.error := 'S';
            v_retorno.descripcionRespuesta := 'Cuenta no corresponde a un ente de tipo CN';
            RETURN v_retorno;
          end if;
      END IF;
      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;
         FOR ct IN cuentas LOOP
            DECLARE
               detalleMovimiento TYP_MOVIMIENTOSCUENTA := TYP_MOVIMIENTOSCUENTA;
               listaMovimientos  TYP_LISTAMOVIMIENTOSCUENTA;
               detalletransferencias TYP_TRANSFERENCIASCUENTA := TYP_TRANSFERENCIASCUENTA;
               listatransferencias  TYP_LISTATRANSFERENCIASCUENTA;
            BEGIN
               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF PAW_UTI.fu_es_juridica(ct.nro_cuenta, v_cod_empresa, v_cod_persona) = 'N' THEN
                  v_can_detalles := v_can_detalles + 1;
                  -- busco los demas datos de las cuentas
                     pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                  if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
                      begin
                        it.prg_obt_sal_ant_aduana(ct.nro_cuenta,
                                                  nvl(v_fecha,v_fec_actual - 1),
                                                  v_retorno.saldoActual,
                                                  v_retorno.saldoAnterior);
                      exception
                        when no_data_found then
                          v_retorno.saldoActual := 0;
                          v_retorno.saldoAnterior := 0;
                        when others then
                          v_retorno.saldoActual := 0;
                          v_retorno.saldoAnterior := 0;
                      end;
                    v_retorno.nroCuenta := ct.nro_cuenta;
                  else
                    v_retorno.error     := 'S';
                    v_retorno.descripcionRespuesta := 'Error al obtener cuenta ' || ct.nro_cuenta;
                    v_det_error := pag_cta.G_LUGAR || ' - ' || pag_cta.G_COD_ERROR ||
                                   ' - ' || pag_cta.G_MSJ_ERROR;
                  end if;

                  listaMovimientos := TYP_LISTAMOVIMIENTOSCUENTA();
                  listatransferencias := TYP_LISTATRANSFERENCIASCUENTA();

                  END IF;
                  v_can_movimientos := 0;
                  -- primer ciclo solo para obtener el monto 1
                  FOR mv IN movimientos(ct.nro_cuenta) LOOP
                        v_can_movimientos := v_can_movimientos + 1;

                           detalleMovimiento.fecha                       := PAW_UTI.lf_for_date(mv.fecha);
                           detalleMovimiento.hora                        := mv.hora;
                           detalleMovimiento.numeroDocumento             := substr(mv.nro_documento,0, 15);
                           detalleMovimiento.monto                       := PAW_UTI.lf_for_money(mv.monto);
                           detalleMovimiento.tipoMovimientos             := mv.tipo_trans;--substr(mv.tipo,0, 1);

                           listaMovimientos.extend;
                           listaMovimientos(listaMovimientos.count) := detalleMovimiento;
                  END LOOP; --end loop movimientos

                  IF v_retorno.error = 'N' THEN
                     v_retorno.detallesMovimiento := listaMovimientos;
                  END IF;
                     v_can_movimientos := 0;
                     FOR tr IN transferencias(ct.nro_cuenta) LOOP
                           v_can_movimientos := v_can_movimientos + 1;

                           detalletransferencias.fecha                      := PAW_UTI.lf_for_date(tr.fecha);
                           detalletransferencias.hora                       := tr.hora;
                           detalletransferencias.numeroDocumento            := substr(tr.nro_documento,0, 15);
                           detalletransferencias.monto                      := PAW_UTI.lf_for_money(tr.monto);
                           detalletransferencias.codigoBanco                := tr.cod_banco;
                           detalletransferencias.nroCuenta                  := tr.nro_cuenta;
                           
                           listatransferencias.extend;
                           listatransferencias(listatransferencias.count) := detalletransferencias;
                   END LOOP;
                    IF v_retorno.error = 'N' THEN
                     v_retorno.detallesTransferencia := listatransferencias;
                  END IF;
            END;
         END LOOP; --end loop cuentas
      END IF;
      -- registro del movimiento
        IF v_can_detalles = 0 THEN
            -- no tiene detalles
           v_retorno.error := 'S';
           v_retorno.descripcionRespuesta := 'Cuenta Inexistente.';
           v_retorno.saldoActual := 0;
           v_retorno.saldoAnterior := 0;
           RETURN v_retorno;    
        ELSE
           v_retorno.error := 'N';
           v_retorno.descripcionRespuesta := 'Operacion realizada con exito.';
           RETURN v_retorno;    
        END IF;
      
   EXCEPTION
      WHEN OTHERS THEN
          if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
            --Registro log
            PRG_INS_LOG_PROGRAMAS('PAG_APP.FU_OBT_MOVIMIENTOS',
                                  v_det_error||'p_fecha: '||p_fecha||' p_nro_cta_especifica: '||v_nro_cta_especifica,
                                  V_cod_persona,
                                  v_nro_cta_especifica);
          end if;
         v_retorno.error := 'S';
         v_retorno.descripcionRespuesta := 'Error al recuperar Datos: '||sqlerrm;
         v_retorno.saldoActual := 0;
         v_retorno.saldoAnterior := 0;
         RETURN v_retorno;
   END fu_obt_movimientos;

FUNCTION fu_obt_mov_hora(p_nro_cuenta IN VARCHAR2,
                         p_fec_inicial IN DATE DEFAULT NULL,
                         p_fec_final IN DATE DEFAULT NULL,
                         p_ini_hora IN VARCHAR2,
                         p_fin_hora IN VARCHAR2,
                         p_nro_pagina IN NUMBER DEFAULT NULL,
                         p_can_reg_pagina IN NUMBER DEFAULT NULL)
            RETURN typ_datosCuenta IS
      v_retorno            typ_datosCuenta := typ_datosCuenta;
      v_cod_persona        ba_personas.cod_persona%type:=null;
      v_cod_empresa        ba_personas.cod_persona%type:=null;
      v_nro_cta_especifica VARCHAR2(16);
      v_can_movimientos    NUMBER(8);
      v_can_detalles       NUMBER(3); -- cantidad de cuentas
      v_fec_actual         DATE := trunc(sysdate); -- fecha de hoy
      v_det_error          ge_log_errores.det_error%type; 
      v_fecha              DATE := p_fec_inicial;
      v_fecha2             DATE := p_fec_final;
      v_existe_e           VARCHAR2(1):= 'N';
      v_nro_pagina         NUMBER(3); -- nro de pagina
      v_can_pagina         NUMBER(5); -- movimientos por pagina
      v_reg_inicial        NUMBER(10);
      v_reg_final          NUMBER(10);
     
      -- cursor de cuentas pasivas del cliente
      CURSOR cuentas IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,
                fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion IN ('P')
            AND b.cod_persona = nvl(v_cod_empresa, v_cod_persona)
            AND a.cod_modulo = c.cod_modulo
            AND a.cod_modalidad = c.cod_modalidad
            AND a.estado = c.estado
            AND c.activo = 'S' -- solo cuentas activas
            AND a.estado <> 'X' -- pendiente de verificacion
            AND (b.nro_cuenta = v_nro_cta_especifica); -- solo ve la cuenta recibida o todas
      -- movimientos por cuenta 
      CURSOR movimientos(p_nro_cuenta IN VARCHAR2) IS
         SELECT trunc(a.fec_insercion) fecha,a.hora,a.nro_documento,a.monto,a.tipo,
               fug_obt_tra_tip_aduana(b.cod_transaccion, b.cod_modulo, b.cod_modalidad)tipo_trans
           FROM ge_transacciones b, gv_movimientos a
          WHERE nro_cuenta = p_nro_cuenta
            AND (a.fec_insercion BETWEEN to_date(to_char(nvl(v_fecha,v_fec_actual),'dd/mm/yyyy') || ' ' || nvl(p_ini_hora,'13:00:00'),'dd/mm/yyyy HH24:mi:ss')
            AND to_date(to_char(nvl(v_fecha2,v_fec_actual+1),'dd/mm/yyyy') || ' ' || nvl(p_fin_hora,'12:59:59'),'dd/mm/yyyy HH24:mi:ss'))
            AND estado = 'N'
            AND a.reversado = 'N' --SOLO NO REVERSADOS
            AND monto <> 0
            AND cod_tip_movimiento IN ('D', 'C')
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
            AND (NVL(b.AFECTA,'XX') = 'B'
                AND a.COD_CAUSA IN
                    (select cod_causa
                       from ge_par_causales
                     where parametro = 'COD_CAU_BLO_EXT'
                       and val_parametro = 'S' )
                OR NVL(b.AFECTA,'XX') != 'B' ) --DDSI-306 No se muestran los levantamientos de embargos movimientos
          ORDER BY a.fecha DESC, a.fec_insercion DESC;
   BEGIN
   v_nro_pagina  := p_nro_pagina;
   v_can_pagina  := p_can_reg_pagina;
   v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
   v_reg_final   := (v_nro_pagina * v_can_pagina);
    declare-- problemas de formato recibio en dd/mon/yyyy
       v_error varchar2(100);
    begin
       sql_util.ejecute_dml('alter session set nls_date_format = ''dd/mm/yyyy''', v_error);
      if v_error is not null then
        dbms_output.put_line(v_error);
      end if;
    end;
      v_retorno.error := 'N';--inicia en OK
      v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nro_cuenta, 16);
      
      -- 1.1. Armo el nro de cuenta
      IF v_nro_cta_especifica IS NULL THEN
         v_retorno.error := 'S';
         v_retorno.descripcionRespuesta := 'No se ingreso cuenta';
         RETURN v_retorno;
      ELSE --Se recupera el cod_persona Principal
         begin 
             select s.cod_persona
               into v_cod_persona
               from ge_cta_clientes s
               where s.nro_cuenta = v_nro_cta_especifica
               and s.relacion = 'P';
          exception
            when no_data_found then
              v_cod_persona := null;
            when others then
              v_cod_persona := null;
          end;
          begin --verificamos que corresponda a un ente tipo CN
            Select distinct 'S'
              into v_existe_e
              from ge_entes t,ge_par_entes t2
             where t.tipo = 'CN'
               and t.cod_ente = t2.cod_ente
               and t2.val_parametro = v_nro_cta_especifica;   
          exception
            when no_data_found then
              v_existe_e := 'N';
            when others then
              v_existe_e := 'N';
          end;        
          if nvl(v_existe_e, 'N') = 'N' then
            v_retorno.error := 'S';
            v_retorno.descripcionRespuesta := 'Cuenta no corresponde a un ente de tipo CN';
            RETURN v_retorno;
          end if;
      END IF;
      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;
         FOR ct IN cuentas LOOP
            DECLARE
               detalleMovimiento TYP_MOVIMIENTOSCUENTA := TYP_MOVIMIENTOSCUENTA;
               listaMovimientos  TYP_LISTAMOVIMIENTOSCUENTA;
            BEGIN
               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF PAW_UTI.fu_es_juridica(ct.nro_cuenta, v_cod_empresa, v_cod_persona) = 'N' THEN
                  v_can_detalles := v_can_detalles + 1;
                  -- busco los demas datos de las cuentas
                     pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                  if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
                    v_retorno.saldoActual := 0;
                    v_retorno.saldoAnterior := 0;  
                    v_retorno.nroCuenta := ct.nro_cuenta;
                  else
                    v_retorno.error     := 'S';
                    v_retorno.descripcionRespuesta := 'Error al obtener cuenta ' || ct.nro_cuenta;
                    v_det_error := pag_cta.G_LUGAR || ' - ' || pag_cta.G_COD_ERROR ||
                                   ' - ' || pag_cta.G_MSJ_ERROR;
                  end if;

                  listaMovimientos := TYP_LISTAMOVIMIENTOSCUENTA();

                  END IF;
                  v_can_movimientos := 0;
                  -- primer ciclo solo para obtener el monto 1
                  FOR mv IN movimientos(ct.nro_cuenta) LOOP
                        v_can_movimientos := v_can_movimientos + 1;
                        dbms_output.put_line('v_can_movimientos: '||v_can_movimientos);
                        IF (v_reg_inicial IS NULL) OR (v_can_movimientos >= v_reg_inicial) THEN
                        dbms_output.put_line('v_reg_inicial: '||v_reg_inicial);
                           detalleMovimiento.fecha                       := PAW_UTI.lf_for_date(mv.fecha);
                           detalleMovimiento.hora                        := mv.hora;
                           detalleMovimiento.numeroDocumento             := substr(mv.nro_documento,0, 15);
                           detalleMovimiento.monto                       := PAW_UTI.lf_for_money(mv.monto);
                           detalleMovimiento.tipoMovimientos             := mv.tipo_trans;--substr(mv.tipo,0, 1);

                           listaMovimientos.extend;
                           listaMovimientos(listaMovimientos.count) := detalleMovimiento;
                           
                        END IF;
                         IF (v_reg_final IS NOT NULL) AND (v_can_movimientos >= v_reg_final) THEN
                           EXIT;
                         END IF;
                  END LOOP; --end loop movimientos

                  IF v_retorno.error = 'N' THEN
                     v_retorno.detallesMovimiento := listaMovimientos;
                  END IF;
            END;
         END LOOP; --end loop cuentas
      END IF;
      -- registro del movimiento
        IF v_can_detalles = 0 THEN
            -- no tiene detalles
           v_retorno.error := 'S';
           v_retorno.descripcionRespuesta := 'Cuenta Inexistente.';
           v_retorno.saldoActual := 0;
           v_retorno.saldoAnterior := 0;
           RETURN v_retorno;    
        ELSE
           v_retorno.error := 'N';
           v_retorno.descripcionRespuesta := 'Operacion realizada con exito.';
           RETURN v_retorno;    
        END IF;
      
   EXCEPTION
      WHEN OTHERS THEN
          if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
            --Registro log
            PRG_INS_LOG_PROGRAMAS('PAG_APP.FU_OBT_MOV_HORA',
                                  v_det_error||' p_fec_inicial: '||p_fec_inicial||' p_fec_final: '||p_fec_final||' p_ini_hora: '||p_ini_hora||' p_fin_hora: '||p_fin_hora||' p_nro_cta_especifica: '||v_nro_cta_especifica,
                                  V_cod_persona,
                                  v_nro_cta_especifica);
          end if;
         v_retorno.error := 'S';
         v_retorno.descripcionRespuesta := 'Error al recuperar Datos: '||sqlerrm;
         v_retorno.saldoActual := 0;
         v_retorno.saldoAnterior := 0;
         RETURN v_retorno;
   END fu_obt_mov_hora;
end pag_app;
/
