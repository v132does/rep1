create or replace function it.fug_obt_datos_clientes(p_cod_persona in varchar2,
                                                  p_tipo_dato   in char)
  return varchar2 is
  v_return varchar2(3500);
  cursor vinc(p_cod_persona in ba_personas.cod_persona%type) is
    Select (cod_per_vinculo || ' ' || fue_obt_nom_persona(cod_per_vinculo)) vin
      from BA_VINCULOS
     where cod_persona = p_cod_persona;

  cursor ctas(p_cod_persona in ba_personas.cod_persona%type) is
    SELECT substr(fug_obt_des_modalidad(a.cod_modalidad), 1, 20) || ' - ' ||
           a.nro_cuenta || ' (' || a.cod_moneda || ') ' as cta
      from ge_cuentas a, ge_cta_clientes b
     WHERE a.nro_cuenta = b.nro_cuenta
       and b.relacion in ('O', 'P', 'Y')
       and b.cod_persona = p_cod_persona
       and fug_obt_ctas_activas(b.nro_cuenta) > 0
       and exists (Select 0
              from ge_est_cuentas c
             where c.cod_modulo = b.cod_modulo
               and c.cod_modalidad = b.cod_modalidad
               and c.estado = a.estado
               and c.activo = 'S')
     order by b.cod_modulo;
begin
  if p_tipo_dato = 'C' then
    --'C' hace el Select para obtener las cuentas de la persona
    for x in ctas(p_cod_persona) loop
      v_return := substr(v_return || x.cta, 1, 3500);
    end loop;
    v_return := substr(v_return, 1, 300);
  elsif p_tipo_dato = 'O' then
    --'O' hace el Select para obtener profesión
    select b.descripcion
      into v_return
      from ba_per_fisicas t, ba_profesiones b
     where t.cod_persona = p_cod_persona
       and t.cod_profesion = b.cod_profesion;
  elsif p_tipo_dato = 'A' then
    --'A' hace el Select para obtener actividad
    select descripcion
      into v_return
      from ba_personas t, ge_actividades g
     where t.cod_persona = p_cod_persona
       and t.cod_actividad = g.cod_actividad;
  elsif p_tipo_dato = 'D' then
    --'D' hace el Select para obtener tipo de documento
    select d.descripcion
      into v_return
      from ba_personas t, ba_tip_documentos d
     where t.cod_persona = p_cod_persona
       and t.cod_tip_documento = d.cod_tip_documento;
  elsif p_tipo_dato = 'N' then
    --'N' hace el Select para obtener la nacionalidad de la persona
    select p.descripcion
      into v_return
      from ba_per_fisicas t, ba_paises p
     where t.cod_persona = p_cod_persona
       and t.cod_pai_nacionalidad = p.cod_pais;
  elsif p_tipo_dato = 'S' then
    --'S' hace el Select para obtener la sucursal de la persona/cliente
    select o.descripcion
      into v_return
      from ge_clientes t, ba_oficinas o
     where t.cod_persona = p_cod_persona
       and t.cod_oficina = o.cod_oficina;
  elsif p_tipo_dato = 'G' then
    --'G' hace el Select para obtener el gestor de la persona/cliente
    select b.nombre
      into v_return
      from ge_clientes t, ba_usuarios b
     where t.cod_persona = p_cod_persona
       and t.cod_usu_oficial = b.cod_usuario;
  elsif p_tipo_dato = 'P' then
    --'P' hace el Select para obtener la dirección de la persona/cliente
    Select d.direccion
      into v_return
      from ba_direcciones d
     where d.cod_persona = p_cod_persona
       and d.principal = 'S';
  elsif p_tipo_dato = 'L' then
    --'L' hace el Select para obtener la dirección de la persona/cliente
    Select d.direccion
      into v_return
      from ba_direcciones d
     where d.cod_persona = p_cod_persona
       and d.tipo = 'L'
       and d.principal = 'S';
  elsif p_tipo_dato = 'K' then
    --'K' Actividad económica según Datamart
    select r.significado
      into v_return
      from ba_personas b, ba_per_dat_adicionales da, ba_cod_referencias r
     where b.cod_persona = da.cod_persona
       and da.parametro = r.dominio
       and r.dominio = 'DTM_RIESGO'
       and da.val_parametro = r.val_minimo
       and b.cod_persona = p_cod_persona;
  elsif p_tipo_dato = 'Q' then
    --'Q' Código de Actividad económica según Datamart
    select da.val_parametro
      into v_return
      from ba_personas b, ba_per_dat_adicionales da, ba_cod_referencias r
     where b.cod_persona = da.cod_persona
       and da.parametro = r.dominio
       and r.dominio = 'DTM_RIESGO'
       and da.val_parametro = r.val_minimo
       and b.cod_persona = p_cod_persona;
  elsif p_tipo_dato = 'V' then
    --'V' hace el Select para obtener las personas vinculadas
    for x in vinc(p_cod_persona) loop
      v_return := substr(v_return || x.vin, 1, 3500);
    end loop;
    v_return := substr(v_return, 1, 300);
  end if;
  return(v_return);
Exception
  When NO_DATA_FOUND Then
    return null;
end fug_obt_datos_clientes;
/

