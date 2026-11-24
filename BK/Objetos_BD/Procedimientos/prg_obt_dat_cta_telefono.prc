create or replace procedure it.prg_obt_dat_cta_telefono(p_nro_telefono    ba_tab_dat_adicionales.val_parametro%type,
                                                        p_nro_cuenta      out ge_cta_clientes.nro_cuenta%type,
                                                        p_nro_documento   out ba_personas.nro_documento%type,
                                                        p_cod_moneda      out ba_monedas.cod_moneda%type,
                                                        p_moneda          out ba_monedas.descripcion%type,
                                                        p_denominacion    out ah_cta_vistas.denominacion%type,
                                                        p_sal_disponible  out ah_cta_vistas.sal_total%type,
                                                        p_estado          out ah_cta_vistas.estado%type,
                                                        p_relacion_cta    out ba_cod_referencias.significado%type,
                                                        p_alias           out ge_cta_dat_adicionales.val_parametro%type,
                                                        p_tar_alias       out ge_cta_dat_adicionales.val_parametro%type,
                                                        p_ent_procesadora out ah_tar_debitos.cod_ent_procesadora%type,
                                                        p_cod_error       out number,
                                                        p_men_error       out varchar2) is

  v_pro_correcto number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_cod_persona  ah_tar_debitos.cod_persona%type;
begin
  p_cod_error := v_pro_correcto;
  p_men_error := 'Operacion Exitosa';

  begin
    select referencia
      into v_cod_persona
      from ba_tab_dat_adicionales
     where tab_relacion = 'BA_PERSONAS'
       and parametro = 'CELULAR_ONBOARDING'
       and (val_parametro = p_nro_telefono or
           '+595' || substr(val_parametro, 2) = p_nro_telefono or
           val_parametro = '0' || substr(p_nro_telefono, 2));
  exception
    when no_data_found then
      p_cod_error := 1;
      p_men_error := 'No existe telefono asociado a onboarding ';
    when others then
      p_cod_error := 2;
      p_men_error := substr('Error ' || sqlerrm, 1, 1000);
  end;

  if p_cod_error = v_pro_correcto then
    begin
      select a.nro_cuenta,
             c.nro_documento,
             b.cod_moneda,
             d.descripcion,
             b.denominacion,
             nvl(b.sal_total, 0) - nvl(b.sal_retenido, 0) -
             nvl(b.sal_bloqueado, 0) - nvl(b.mto_deb_pendientes, 0) +
             nvl(b.mto_cre_pendientes, 0) sal_actual,
             b.estado,
             fue_obt_des_refcodes('RELACION', a.relacion) RELACION,
             fug_obt_paradicional(b.nro_cuenta, 'ALIAS_CTA') alias,
             fug_obt_paradicional(b.nro_cuenta, 'ALIAS_TARJETA') tar_alias,
             e.cod_ent_procesadora
        into p_nro_cuenta,
             p_nro_documento,
             p_cod_moneda,
             p_moneda,
             p_denominacion,
             p_sal_disponible,
             p_estado,
             p_relacion_cta,
             p_alias,
             p_tar_alias,
             p_ent_procesadora
        from ge_cta_clientes a,
             ah_cta_vistas   b,
             ba_personas     c,
             ba_monedas      d,
             ah_tar_debitos  e
       where a.cod_persona = v_cod_persona
         and a.nro_cuenta = b.nro_cuenta
         and b.cod_modalidad = 334
         and a.relacion = 'P'
         and a.cod_persona = c.cod_persona
            --and a.estado in ('A', 'B', 'D', 'I', 'N', 'S', 'T')
         and b.cod_moneda = d.cod_moneda
         and b.nro_cuenta = e.nro_cuenta(+)
         and a.cod_persona = e.cod_persona(+)
         and e.tar_activa(+) = 'S';
    exception
      when no_data_Found then
        begin
          select a.nro_cuenta,
                 c.nro_documento,
                 b.cod_moneda,
                 d.descripcion,
                 b.denominacion,
                 nvl(b.sal_total, 0) - nvl(b.sal_retenido, 0) -
                 nvl(b.sal_bloqueado, 0) - nvl(b.mto_deb_pendientes, 0) +
                 nvl(b.mto_cre_pendientes, 0) sal_actual,
                 b.estado,
                 fue_obt_des_refcodes('RELACION', a.relacion) RELACION,
                 fug_obt_paradicional(b.nro_cuenta, 'ALIAS_CTA') alias,
                 fug_obt_paradicional(b.nro_cuenta, 'ALIAS_TARJETA') tar_alias,
                 e.cod_ent_procesadora
            into p_nro_cuenta,
                 p_nro_documento,
                 p_cod_moneda,
                 p_moneda,
                 p_denominacion,
                 p_sal_disponible,
                 p_estado,
                 p_relacion_cta,
                 p_alias,
                 p_tar_alias,
                 p_ent_procesadora
            from ge_cta_clientes a,
                 ah_cta_vistas   b,
                 ba_personas     c,
                 ba_monedas      d,
                 ah_tar_debitos  e
           where a.cod_persona = v_cod_persona
             and a.nro_cuenta = b.nro_cuenta
             and a.cod_modalidad = 31
             and b.cod_canal = 26
             and a.relacion = 'P'
             and a.cod_persona = c.cod_persona
             and b.cod_moneda = d.cod_moneda
             and b.nro_cuenta = e.nro_cuenta(+)
             and a.cod_persona = e.cod_persona(+)
             and e.tar_activa(+) = 'S';
        exception
          when no_data_found then
            begin
              select a.nro_cuenta,
                     c.nro_documento,
                     b.cod_moneda,
                     d.descripcion,
                     b.denominacion,
                     nvl(b.sal_total, 0) - nvl(b.sal_retenido, 0) -
                     nvl(b.sal_bloqueado, 0) - nvl(b.mto_deb_pendientes, 0) +
                     nvl(b.mto_cre_pendientes, 0) sal_actual,
                     b.estado,
                     fue_obt_des_refcodes('RELACION', a.relacion) RELACION,
                     fug_obt_paradicional(b.nro_cuenta, 'ALIAS_CTA') alias,
                     fug_obt_paradicional(b.nro_cuenta, 'ALIAS_TARJETA') tar_alias,
                     e.cod_ent_procesadora
                into p_nro_cuenta,
                     p_nro_documento,
                     p_cod_moneda,
                     p_moneda,
                     p_denominacion,
                     p_sal_disponible,
                     p_estado,
                     p_relacion_cta,
                     p_alias,
                     p_tar_alias,
                     p_ent_procesadora
                from ge_cta_clientes a,
                     ah_cta_vistas   b,
                     ba_personas     c,
                     ba_monedas      d,
                     ah_tar_debitos  e
               where a.cod_persona = v_cod_persona
                 and a.nro_cuenta = b.nro_cuenta
                 and a.cod_modalidad = 31
                 and a.relacion = 'P'
                 and a.cod_persona = c.cod_persona
                 and b.cod_moneda = d.cod_moneda
                 and b.nro_cuenta = e.nro_cuenta(+)
                 and a.cod_persona = e.cod_persona(+)
                 and e.tar_activa(+) = 'S'
                 and rownum = 1;
            exception
              when others then
                p_cod_error := 3;
                p_men_error := 'Error recuperando datos. Persona ' ||
                               v_cod_persona || ' ' || sqlerrm;
            end;
        end;
      when others then
        p_cod_error := 4;
        p_men_error := 'Error al buscar la cuenta. ' || sqlerrm;
    end;
  end if;
exception
  when others then
    null;
end prg_obt_dat_cta_telefono;
/

