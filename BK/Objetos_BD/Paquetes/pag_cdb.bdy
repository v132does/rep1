CREATE OR REPLACE PACKAGE BODY IT.PAG_CDB IS

  procedure pr_val_par_cdb(p_nro_documento ba_personas.nro_documento%type,
                           p_tip_documento ba_personas.cod_tip_documento%type,
                           p_cod_persona   out ba_personas.cod_persona%type,
                           p_parametro     out varchar,
                           p_correo        out varchar,
                           p_rubro         out varchar,
                           p_cod_error     out number,
                           p_men_error     out varchar) is
  
    v_cod_persona  ba_personas.cod_persona%type;
    v_parametro    varchar2(1);
    v_existe       varchar2(1);
    v_correo       ba_personas.dir_correo%type;
    v_rub_primario ba_personas.cod_rub_primario%type;
  begin
    ---parametros de entrada no pueden ser nulos---
    if p_nro_documento is null then
      p_men_error := 'Numero de documento no puede ser nulo.';
      p_cod_error := 1;
      return;
    end if;
    if p_tip_documento is null then
      p_men_error := 'Tipo de documento no puede ser nulo.';
      p_cod_error := 2;
      return;
    end if;
  
    begin
      select s.cod_persona, s.dir_correo, s.cod_rub_primario
        into v_cod_persona, v_correo, v_rub_primario
        from ba_personas s
       where s.cod_tip_documento = p_tip_documento
         and s.nro_documento = p_nro_documento;
    exception
      when no_data_found then
        p_cod_error := 4;
        p_men_error := 'No se encontro la persona.';
      when too_many_rows then
        select s.cod_persona, s.dir_correo, s.cod_rub_primario
          into v_cod_persona, v_correo, v_rub_primario
          from ba_personas s
         where s.cod_tip_documento = p_tip_documento
           and s.nro_documento = p_nro_documento
           and rownum = 1;
      when others then
        raise_application_error(-20001,
                                'Error al buscar a la persona.' || sqlerrm);
    end;
    p_cod_persona := v_cod_persona;
    if v_cod_persona is not null then
      begin
        select 'S'
          into v_existe
          from ba_per_fisicas
         where cod_persona = v_cod_persona;
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          select 'S'
            into v_existe
            from ba_per_fisicas
           where cod_persona = v_cod_persona
             and rownum = 1;
        when others then
          raise_application_error(-20002,
                                  'Error al buscar a la persona fisica.' ||
                                  sqlerrm);
      end;
      if v_existe = 'N' then
        p_cod_error := 6;
        p_men_error := 'Los datos de consultas no corresponden a una persona fisica.';
        return;
      end if;
    end if;
    if v_cod_persona is not null then
      v_parametro := it.fue_per_dat_adicional(v_cod_persona,
                                              'HAB_CAS_BOLSA');
      p_parametro := v_parametro;
      if nvl(v_parametro, 'N') = 'N' then
        p_cod_error := 7;
        p_men_error := 'La persona no esta habilitada para ser cliente.';
      end if;
    end if;
    p_correo := v_correo;
    p_rubro  := v_rub_primario;
  end;
  procedure pr_obt_sal_cta(p_nro_documento ba_personas.nro_documento%type,
                           p_tip_documento ba_personas.cod_tip_documento%type,
                           p_nro_cuenta    in out ah_cta_vistas.nro_cuenta%type,
                           p_moneda        out ah_cta_vistas.cod_moneda%type,
                           p_saldo         out number,
                           p_cod_error     out number,
                           p_men_error     out varchar) is
  
    v_cod_persona    ba_personas.cod_persona%type;
    v_cta_vista      ah_cta_vistas.nro_cuenta%type;
    v_cod_moneda     ah_cta_vistas.cod_moneda%type;
    v_sal_disponible number(18, 2);
    v_estado         varchar2(1);
    v_relacion       varchar2(1);
    v_parametro      varchar2(1);
    v_correo         ba_personas.dir_correo%type;
    v_rub_primario   ba_personas.cod_rub_primario%type;
  begin
    ---valida parametros de entrada---
    pr_val_par_cdb(p_nro_documento,
                   p_tip_documento,
                   v_cod_persona,
                   v_parametro,
                   v_correo,
                   v_rub_primario,
                   p_cod_error,
                   p_men_error);
  
    if p_nro_cuenta is null then
      p_men_error := 'La cuenta no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;
    ---valida que la cuenta pertenezca al nro de doc ingresado---
    if v_cod_persona is not null then
      begin
        select vis.nro_cuenta, vis.cod_moneda, vis.estado, cta.relacion
          into v_cta_vista, v_cod_moneda, v_estado, v_relacion
          from ah_cta_vistas vis, ge_cta_clientes cta
         where cta.nro_cuenta = vis.nro_cuenta
           and vis.nro_cuenta = p_nro_cuenta
           and cta.cod_persona = v_cod_persona;
      exception
        when no_data_found then
          p_cod_error := 5;
          p_men_error := 'No se encontro la caja de ahorro.';
        when too_many_rows then
          select vis.nro_cuenta, vis.cod_moneda, vis.estado, cta.relacion
            into v_cta_vista, v_cod_moneda, v_estado, v_relacion
            from ah_cta_vistas vis, ge_cta_clientes cta
           where cta.nro_cuenta = vis.nro_cuenta
             and vis.nro_cuenta = p_nro_cuenta
             and cta.cod_persona = v_cod_persona
             and rownum = 1;
        when others then
          raise_application_error(-20003,
                                  'Error al buscar cuenta de la persona.' ||
                                  sqlerrm);
      end;
    end if;
  
    if v_estado in ('C', 'T', 'P', 'I') or v_relacion <> 'P' then
      p_cod_error := 8;
      p_men_error := 'La caja de ahorro no se encuentra activa.';
      return;
    end if;
  
    if v_cod_persona is not null then
      pag_cta.pr_obt_cuenta(p_nro_cuenta);
      v_sal_disponible := pag_cta.fu_sal_disponible;
    end if;
  
    if nvl(p_cod_error, '000') = '000' then
      p_moneda    := v_cod_moneda;
      p_saldo     := v_sal_disponible;
      p_cod_error := 0;
      p_men_error := null;
    end if;
  end;
  procedure pr_obt_dat_clientes(p_nro_documento  ba_personas.nro_documento%type,
                                p_tip_documento  ba_personas.cod_tip_documento%type,
                                p_cli_habilitado out varchar,
                                p_pri_nombre     out ba_per_fisicas.pri_nombre%type,
                                p_seg_nombre     out ba_per_fisicas.seg_nombre%type,
                                p_pri_apellido   out ba_per_fisicas.pri_apellido%type,
                                p_seg_apellido   out ba_per_fisicas.seg_apellido%type,
                                p_nro_doc        out ba_personas.nro_documento%type,
                                p_tip_doc        out ba_personas.cod_tip_documento%type,
                                p_fec_nacimiento out ba_per_fisicas.fec_nacimiento%type,
                                p_nacionalidad   out ba_paises.nacionalidad%type,
                                p_direccion      out ba_direcciones.direccion%type,
                                p_barrio         out ba_barrios.descripcion%type,
                                p_ciudad         out ba_ciudades.descripcion%type,
                                p_departamento   out ba_departamentos.descripcion%type,
                                p_num_telefono   out varchar,
                                p_correo         out ba_personas.dir_correo%type,
                                p_act_economica  out ge_actividades.descripcion%type,
                                p_profesion      out ba_profesiones.descripcion%type,
                                p_lug_trabajo    out cr_inf_laborales.lug_trabajo%type,
                                p_cod_error      out number,
                                p_men_error      out varchar) is
  
    v_parametro            varchar2(1);
    v_cod_persona          ba_personas.cod_persona%type;
    v_pri_nombre           ba_per_fisicas.pri_nombre%type;
    v_pri_apellido         ba_per_fisicas.pri_apellido%type;
    v_seg_nombre           ba_per_fisicas.seg_nombre%type;
    v_seg_apellido         ba_per_fisicas.seg_apellido%type;
    v_fec_nacimiento       ba_per_fisicas.fec_nacimiento%type;
    v_cod_pai_nacionalidad ba_per_fisicas.cod_pai_nacionalidad%type;
    v_nacionalidad         ba_paises.nacionalidad%type;
    v_direccion            ba_direcciones.direccion%type;
    v_barrio               ba_barrios.descripcion%type;
    v_ciudad               ba_ciudades.descripcion%type;
    v_departamento         ba_departamentos.descripcion%type;
    v_cod_ciudad           ba_direcciones.cod_ciudad%type;
    v_cod_barrio           ba_direcciones.cod_barrio%type;
    v_cod_departamento     ba_direcciones.cod_departamento%type;
    v_telefono             varchar2(15);
    v_correo               ba_personas.dir_correo%type;
    v_act_economica        ge_rub_economicos.descripcion%type;
    v_profesion            ba_profesiones.descripcion%type;
    v_lug_trabajo          cr_inf_laborales.lug_trabajo%type;
    v_cod_profesion        ba_per_fisicas.cod_profesion%type;
    v_rub_primario         ba_personas.cod_rub_primario%type;
  
  begin
    ---valida parametros de entrada---
    pr_val_par_cdb(p_nro_documento,
                   p_tip_documento,
                   v_cod_persona,
                   v_parametro,
                   v_correo,
                   v_rub_primario,
                   p_cod_error,
                   p_men_error);
  
    if p_nro_documento is not null and p_tip_documento is not null and
       v_cod_persona is not null then
      begin
        select p.pri_nombre,
               p.pri_apellido,
               p.seg_nombre,
               p.seg_apellido,
               p.fec_nacimiento,
               p.cod_pai_nacionalidad,
               p.cod_profesion
          into v_pri_nombre,
               v_pri_apellido,
               v_seg_nombre,
               v_seg_apellido,
               v_fec_nacimiento,
               v_cod_pai_nacionalidad,
               v_cod_profesion
          from ba_per_fisicas p
         where cod_persona = v_cod_persona;
      exception
        when no_data_found then
          v_pri_nombre           := null;
          v_pri_apellido         := null;
          v_seg_nombre           := null;
          v_seg_apellido         := null;
          v_fec_nacimiento       := null;
          v_cod_pai_nacionalidad := null;
          v_cod_profesion        := null;
        when too_many_rows then
          select p.pri_nombre,
                 p.pri_apellido,
                 p.seg_nombre,
                 p.seg_apellido,
                 p.fec_nacimiento,
                 p.cod_pai_nacionalidad,
                 p.cod_profesion
            into v_pri_nombre,
                 v_pri_apellido,
                 v_seg_nombre,
                 v_seg_apellido,
                 v_fec_nacimiento,
                 v_cod_pai_nacionalidad,
                 v_cod_profesion
            from ba_per_fisicas p
           where cod_persona = v_cod_persona
             and rownum = 1;
        when others then
          raise_application_error(-20004,
                                  'Error al buscar ba_per_fisicas.' ||
                                  sqlerrm);
      end;
      begin
        select a.nacionalidad
          into v_nacionalidad
          from ba_paises a
         where a.cod_pais = v_cod_pai_nacionalidad;
      exception
        when no_data_found then
          v_direccion        := null;
          v_cod_ciudad       := null;
          v_cod_barrio       := null;
          v_cod_departamento := null;
        when too_many_rows then
          select a.nacionalidad
            into v_nacionalidad
            from ba_paises a
           where a.cod_pais = v_cod_pai_nacionalidad
             and rownum = 1;
        when others then
          raise_application_error(-20005,
                                  'Error al buscar direccion.' || sqlerrm);
      end;
      begin
        select b.direccion, b.cod_ciudad, b.cod_barrio, b.cod_departamento
          into v_direccion, v_cod_ciudad, v_cod_barrio, v_cod_departamento
          from ba_direcciones b
         where b.cod_persona = v_cod_persona
           and b.tipo = 'P'
           and b.principal = 'S';
      exception
        when no_data_found then
          v_direccion        := null;
          v_cod_ciudad       := null;
          v_cod_barrio       := null;
          v_cod_departamento := null;
        when too_many_rows then
          select b.direccion,
                 b.cod_ciudad,
                 b.cod_barrio,
                 b.cod_departamento
            into v_direccion,
                 v_cod_ciudad,
                 v_cod_barrio,
                 v_cod_departamento
            from ba_direcciones b
           where b.cod_persona = v_cod_persona
             and b.tipo = 'P'
             and b.principal = 'S'
             and rownum = 1;
        when others then
          raise_application_error(-20006,
                                  'Error al buscar direccion.' || sqlerrm);
      end;
      v_barrio       := fue_obt_des_barrio(v_cod_pai_nacionalidad,
                                           v_cod_ciudad,
                                           v_cod_barrio);
      v_ciudad       := fue_obt_des_ciudad(v_cod_pai_nacionalidad,
                                           v_cod_ciudad);
      v_departamento := fue_obt_des_departamento(v_cod_departamento);
      begin
        select t.area || t.telefono
          into v_telefono
          from ba_telefonos t
         where t.cod_persona = v_cod_persona
           and t.principal = 'S';
      exception
        when no_data_found then
          v_telefono := null;
        when too_many_rows then
          select t.area || t.telefono
            into v_telefono
            from ba_telefonos t
           where t.cod_persona = v_cod_persona
             and t.principal = 'S'
             and rownum = 1;
        when others then
          raise_application_error(-20007,
                                  'Error al buscar telefono.' || sqlerrm);
      end;
      begin
        select c.descripcion
          into v_act_economica
          from ge_rub_economicos c
         where c.cod_rub_economico = v_rub_primario;
      exception
        when no_data_found then
          v_act_economica := null;
        when too_many_rows then
          select c.descripcion
            into v_act_economica
            from ge_rub_economicos c
           where c.cod_rub_economico = v_rub_primario
             and rownum = 1;
        when others then
          raise_application_error(-20008,
                                  'Error al buscar act_economica.' ||
                                  sqlerrm);
      end;
      begin
        select d.descripcion
          into v_profesion
          from ba_profesiones d
         where d.cod_profesion = v_cod_profesion;
      exception
        when no_data_found then
          v_profesion := null;
        when too_many_rows then
          select d.descripcion
            into v_profesion
            from ba_profesiones d
           where d.cod_profesion = v_cod_profesion
             and rownum = 1;
        when others then
          raise_application_error(-20009,
                                  'Error al buscar profesion.' || sqlerrm);
      end;
      begin
        select l.lug_trabajo
          into v_lug_trabajo
          from cr_inf_laborales l
         where l.cod_persona = v_cod_persona
           and l.nro_secuencia =
               (select max(z.nro_secuencia)
                  from cr_inf_laborales z
                 where z.cod_persona = l.cod_persona);
      exception
        when no_data_found then
          v_lug_trabajo := null;
        when too_many_rows then
          select l.lug_trabajo
            into v_lug_trabajo
            from cr_inf_laborales l
           where l.cod_persona = v_cod_persona
             and l.nro_secuencia =
                 (select max(z.nro_secuencia)
                    from cr_inf_laborales z
                   where z.cod_persona = l.cod_persona)
             and rownum = 1;
        when others then
          raise_application_error(-20010,
                                  'Error al buscar lug_trabajo.' || sqlerrm);
      end;
    end if;
    if nvl(p_cod_error, '000') = '000' then
      p_cli_habilitado := v_parametro;
      p_pri_nombre     := v_pri_nombre;
      p_pri_apellido   := v_pri_apellido;
      p_seg_nombre     := v_seg_nombre;
      p_seg_apellido   := v_seg_apellido;
      p_nro_doc        := p_nro_documento;
      p_tip_doc        := p_tip_documento;
      p_fec_nacimiento := v_fec_nacimiento;
      p_nacionalidad   := v_nacionalidad;
      p_direccion      := v_direccion;
      p_barrio         := v_barrio;
      p_ciudad         := v_ciudad;
      p_departamento   := v_departamento;
      p_num_telefono   := v_telefono;
      p_correo         := v_correo;
      p_act_economica  := v_act_economica;
      p_profesion      := v_profesion;
      p_lug_trabajo    := v_lug_trabajo;
      p_cod_error      := 0;
      p_men_error      := null;
    end if;
  end;
  procedure pr_cursor(p_nro_documento ba_personas.nro_documento%type,
                      p_cod_persona   ba_personas.cod_persona%type,
                      p_modalidad     ge_par_dinamicos.val_parametro%type,
                      p_cta_lista     OUT SYS_REFCURSOR) as
  begin
    open p_cta_lista for
      select vis.nro_cuenta, vis.cod_moneda
        from ah_cta_vistas vis, ge_cta_clientes cta, ba_personas per
       where cta.nro_cuenta = vis.nro_cuenta
         and per.cod_persona = cta.cod_persona
         and per.nro_documento = p_nro_documento
         and vis.estado not in ('C', 'T', 'P', 'I')
         and cta.relacion = 'P'
         and pae_uti.fu_obt_posicion(p_modalidad, vis.cod_modalidad) > 0
         and vis.can_fir_registradas = 1
         and per.cod_persona = p_cod_persona;
  
  end;
  procedure pr_obt_cta_ahorros(p_nro_documento ba_personas.nro_documento%type,
                               p_tip_documento ba_personas.cod_tip_documento%type,
                               p_cta_lista     OUT SYS_REFCURSOR,
                               p_cod_error     out number,
                               p_men_error     out varchar) is
  
    v_cod_persona  ba_personas.cod_persona%type;
    v_modalidad    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CDB_CTA_AHORRO');
    v_parametro    varchar2(1);
    v_correo       ba_personas.dir_correo%type;
    v_rub_primario ba_personas.cod_rub_primario%type;
    v_cta_lista    SYS_REFCURSOR;
    v_nro_cuenta   ah_cta_vistas.nro_cuenta%type;
    v_cod_moneda   ah_cta_vistas.cod_moneda%type;
    v_contador     number(10) := 0;
  begin
  
    ---valida parametros de entrada---
    pr_val_par_cdb(p_nro_documento,
                   p_tip_documento,
                   v_cod_persona,
                   v_parametro,
                   v_correo,
                   v_rub_primario,
                   p_cod_error,
                   p_men_error);
  
    if p_nro_documento is not null and v_cod_persona is not null then
      pr_cursor(p_nro_documento, v_cod_persona, v_modalidad, v_cta_lista);
      loop
        fetch v_cta_lista
          into v_nro_cuenta, v_cod_moneda;
        exit when v_cta_lista%notfound;
        v_contador := v_contador + 1;
      end loop;
      close v_cta_lista;
      if v_contador = 0 then
        p_cod_error := 8;
        p_men_error := 'La caja de ahorro no se encuentra activa.';
      else
        pr_cursor(p_nro_documento, v_cod_persona, v_modalidad, p_cta_lista);
      end if;
    
    end if;
    if nvl(p_cod_error, '000') = '000' then
      p_cod_error := 0;
      p_men_error := null;
    end if;
  end;
end PAG_CDB;
/

