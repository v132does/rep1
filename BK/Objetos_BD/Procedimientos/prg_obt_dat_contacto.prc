create or replace procedure it.prg_obt_dat_contacto(p_cod_persona      in ba_personas.cod_persona%type,
                                                    p_nro_cta_contacto out ah_cta_vistas.nro_cuenta%type,
                                                    p_nombre           out ba_personas.nom_completo%type,
                                                    p_apellido         out ba_personas.nom_completo%type,
                                                    p_tip_documento    out ba_tip_documentos.abreviatura%type,
                                                    p_nro_documento    out ba_personas.nro_documento%type,
                                                    p_nro_celular      out varchar2,
                                                    p_dir_correo       out ba_personas.dir_correo%type,
                                                    p_cod_ente         out ge_bancos.cod_swift%type,
                                                    p_cod_moneda       out ah_cta_vistas.cod_moneda%type,
                                                    p_cod_error        out number,
                                                    p_msj_error        out varchar2) is
  v_log_mensaje varchar2(4000);

begin
  p_cod_error := 0;

  begin
    select v.nro_cuenta,
           f.pri_nombre nombre,
           f.pri_apellido apellido,
           fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_documento,
           p.nro_documento,
           p.dir_correo,
           v.cod_moneda
      into p_nro_cta_contacto,
           p_nombre,
           p_apellido,
           p_tip_documento,
           p_nro_documento,
           p_dir_correo,
           p_cod_moneda
      from ge_cta_clientes        c,
           ah_cta_vistas          v,
           ba_per_fisicas         f,
           ba_personas            p,
           ge_cta_dat_adicionales a
     where relacion = 'P'
       and v.nro_cuenta = c.nro_cuenta
       and v.estado not in ('P', 'C')
       and a.parametro = 'LIM_CRE_TRANSACCIONES'
       and a.nro_cuenta = c.nro_cuenta
       and p.cod_persona = c.cod_persona
       and p.cod_persona = f.cod_persona
       and p.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      begin
        select v.nro_cuenta,
               f.pri_nombre nombre,
               f.pri_apellido apellido,
               fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_documento,
               p.nro_documento,
               p.dir_correo,
               v.cod_moneda
          into p_nro_cta_contacto,
               p_nombre,
               p_apellido,
               p_tip_documento,
               p_nro_documento,
               p_dir_correo,
               p_cod_moneda
          from ge_cta_clientes c,
               ah_cta_vistas   v,
               ba_per_fisicas  f,
               ba_personas     p
         where relacion = 'P'
           and v.nro_cuenta = c.nro_cuenta
           and v.estado not in ('P', 'C')
           and fue_obt_val_max_referencia('USU_ALT_PERSONA',
                                          v.usu_insercion) = 'ONB_USER'
           and p.cod_persona = c.cod_persona
           and p.cod_persona = f.cod_persona
           and p.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          begin
            select v.nro_cuenta,
                   f.pri_nombre nombre,
                   f.pri_apellido apellido,
                   fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_documento,
                   p.nro_documento,
                   p.dir_correo,
                   v.cod_moneda
              into p_nro_cta_contacto,
                   p_nombre,
                   p_apellido,
                   p_tip_documento,
                   p_nro_documento,
                   p_dir_correo,
                   p_cod_moneda
              from ge_cta_clientes c,
                   ah_cta_vistas   v,
                   ba_per_fisicas  f,
                   ba_personas     p
             where relacion = 'P'
               and v.nro_cuenta = C.nro_cuenta
               and v.estado not in ('P', 'C')
               and v.cod_modalidad = 334
               and p.cod_persona = c.cod_persona
               and p.cod_persona = f.cod_persona
               and p.cod_persona = p_cod_persona;
          exception
            when no_data_found then
              begin
                select v.nro_cuenta,
                       f.pri_nombre nombre,
                       f.pri_apellido apellido,
                       fue_obt_tip_doc_abreviatura(p.cod_tip_documento) tip_documento,
                       p.nro_documento,
                       p.dir_correo,
                       v.cod_moneda
                  into p_nro_cta_contacto,
                       p_nombre,
                       p_apellido,
                       p_tip_documento,
                       p_nro_documento,
                       p_dir_correo,
                       p_cod_moneda
                  from ge_cta_clientes c,
                       ah_cta_vistas   v,
                       ba_per_fisicas  f,
                       ba_personas     p
                 where relacion = 'P'
                   and v.nro_cuenta = C.nro_cuenta
                   and v.estado not in ('P', 'C')
                   and v.cod_modalidad = 31
                   and p.cod_persona = c.cod_persona
                   and p.cod_persona = f.cod_persona
                   and p.cod_persona = p_cod_persona
                   and c.fec_insercion =
                       (select max(cc.fec_insercion)
                          from ge_cta_clientes cc
                         where cc.cod_persona = p_cod_persona
                           and cc.relacion = 'P');
              exception
                when no_data_found then
                  p_cod_error := 1;
                  p_msj_error := 'La persona ' || p_cod_persona ||
                                 ' no tiene cuenta activa';
                when others then
                  p_cod_error        := 2;
                  p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
                  v_log_mensaje      := substr(sqlerrm, 1, 4000);
                  p_nro_cta_contacto := null;
                  p_nombre           := null;
                  p_apellido         := null;
                  p_tip_documento    := null;
                  p_nro_documento    := null;
                  p_nro_celular      := null;
                  p_dir_correo       := null;
                  p_cod_ente         := null;
                  p_cod_moneda       := null;
              end;
            when others then
              p_cod_error        := 3;
              p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
              v_log_mensaje      := substr(sqlerrm, 1, 4000);
              p_nro_cta_contacto := null;
              p_nombre           := null;
              p_apellido         := null;
              p_tip_documento    := null;
              p_nro_documento    := null;
              p_nro_celular      := null;
              p_dir_correo       := null;
              p_cod_ente         := null;
              p_cod_moneda       := null;
          end;
        when others then
          p_cod_error        := 4;
          p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
          v_log_mensaje      := substr(sqlerrm, 1, 4000);
          p_nro_cta_contacto := null;
          p_nombre           := null;
          p_apellido         := null;
          p_tip_documento    := null;
          p_nro_documento    := null;
          p_nro_celular      := null;
          p_dir_correo       := null;
          p_cod_ente         := null;
          p_cod_moneda       := null;
      end;
    when others then
      p_cod_error        := 5;
      p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
      v_log_mensaje      := substr(sqlerrm, 1, 4000);
      p_nro_cta_contacto := null;
      p_nombre           := null;
      p_apellido         := null;
      p_tip_documento    := null;
      p_nro_documento    := null;
      p_nro_celular      := null;
      p_dir_correo       := null;
      p_cod_ente         := null;
      p_cod_moneda       := null;
  end;

  /*Busca telefono*/
  if nvl(p_cod_error, 0) = 0 then
    begin
      select t.area || t.telefono
        into p_nro_celular
        from ba_telefonos t
       where t.principal = 'S'
         and t.tipo = 'P'
         and t.tip_linea = 'C'
         and t.cod_persona = p_cod_persona;
    exception
      when no_data_found then
        begin
          select a.val_parametro
            into p_nro_celular
            from ba_tab_dat_adicionales a
           where a.parametro = 'CELULAR_ONBOARDING'
             and a.tab_relacion = 'BA_PERSONAS'
             and referencia = p_cod_persona;
        exception
          when no_data_found then
            begin
              select t.area || t.telefono
                into p_nro_celular
                from ba_telefonos t
               where t.tip_linea = 'C'
                 and t.tipo = 'P'
                 and t.cod_persona = p_cod_persona
                 and t.fec_insercion =
                     (select max(t.fec_insercion)
                        from ba_telefonos t
                       where t.tip_linea = 'C'
                         and t.tipo = 'P'
                         and t.cod_persona = p_cod_persona);
            exception
              when no_data_found then
                p_cod_error        := 6;
                p_msj_error        := 'No se encontro ningun celular para la persona ' ||
                                      p_cod_persona;
                p_nro_cta_contacto := null;
                p_nombre           := null;
                p_apellido         := null;
                p_tip_documento    := null;
                p_nro_documento    := null;
                p_nro_celular      := null;
                p_dir_correo       := null;
                p_cod_ente         := null;
                p_cod_moneda       := null;
              when others then
                p_cod_error        := 7;
                p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
                v_log_mensaje      := substr(sqlerrm, 1, 4000);
                p_nro_cta_contacto := null;
                p_nombre           := null;
                p_apellido         := null;
                p_tip_documento    := null;
                p_nro_documento    := null;
                p_nro_celular      := null;
                p_dir_correo       := null;
                p_cod_ente         := null;
                p_cod_moneda       := null;
            end;
          when others then
            p_cod_error        := 8;
            p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
            v_log_mensaje      := substr(sqlerrm, 1, 4000);
            p_nro_cta_contacto := null;
            p_nombre           := null;
            p_apellido         := null;
            p_tip_documento    := null;
            p_nro_documento    := null;
            p_nro_celular      := null;
            p_dir_correo       := null;
            p_cod_ente         := null;
            p_cod_moneda       := null;
        end;
      when others then
        p_cod_error        := 8;
        p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
        v_log_mensaje      := substr(sqlerrm, 1, 4000);
        p_nro_cta_contacto := null;
        p_nombre           := null;
        p_apellido         := null;
        p_tip_documento    := null;
        p_nro_documento    := null;
        p_nro_celular      := null;
        p_dir_correo       := null;
        p_cod_ente         := null;
        p_cod_moneda       := null;
    end;
  end if;
  if p_dir_correo is null and nvl(p_cod_error, 0) = 0 then
    begin
      select a.val_parametro
        into p_dir_correo
        from ba_tab_dat_adicionales a
       where a.parametro = 'EMAIL_ONBOARDING'
         and a.tab_relacion = 'BA_PERSONAS'
         and referencia = p_cod_persona;
    exception
      when no_data_found then
        p_cod_error        := 9;
        p_msj_error        := 'No se encontro ningun correo para la persona ' ||
                              p_cod_persona;
        p_nro_cta_contacto := null;
        p_nombre           := null;
        p_apellido         := null;
        p_tip_documento    := null;
        p_nro_documento    := null;
        p_nro_celular      := null;
        p_dir_correo       := null;
        p_cod_ente         := null;
        p_cod_moneda       := null;
      when others then
        p_cod_error        := 10;
        p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
        v_log_mensaje      := substr(sqlerrm, 1, 4000);
        p_nro_cta_contacto := null;
        p_nombre           := null;
        p_apellido         := null;
        p_tip_documento    := null;
        p_nro_documento    := null;
        p_nro_celular      := null;
        p_dir_correo       := null;
        p_cod_ente         := null;
        p_cod_moneda       := null;
    end;
  end if;

  if nvl(p_cod_error, 0) = 0 then
    p_cod_ente := pas_snp.fu_obt_cod_swi_participante(FUG_OBT_PER_ENTIDAD);
  end if;

  if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
     nvl(p_cod_error, 0) != 0 then
    prg_ins_log_programas('PRG_OBT_DAT_CONTACTO',
                          substr(p_cod_error || ' ' ||
                                 nvl(v_log_mensaje, p_msj_error),
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
  end if;
exception
  when others then
    p_nro_cta_contacto := null;
    p_nombre           := null;
    p_apellido         := null;
    p_tip_documento    := null;
    p_nro_documento    := null;
    p_nro_celular      := null;
    p_dir_correo       := null;
    p_cod_ente         := null;
    p_cod_moneda       := null;
    p_cod_error        := 11;
    p_msj_error        := 'Ocurrio un error inesperado al recuperar los datos';
    v_log_mensaje      := substr(sqlerrm, 1, 4000);
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
       nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PRG_OBT_DAT_CONTACTO',
                            substr(p_cod_error || ' ' ||
                                   nvl(v_log_mensaje, p_msj_error),
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;
end prg_obt_dat_contacto;
/

