create or replace procedure it.prg_env_mai_can_producto(p_cod_persona in ba_personas.cod_persona%type,
                                                        p_cod_error   out number,
                                                        p_mensaje     out varchar2) is
  v_dir_mail_experiencia ge_par_dinamicos.val_parametro%type;
  v_nro_documento        ba_personas.nro_documento%type;
  v_nom_completo         ba_personas.nom_completo%type;
  v_dir_correo           ba_personas.dir_correo%type;
  v_log_error            varchar2(4000);
  v_telefono             varchar2(50);
  v_pen_can_producto     ba_per_dat_adicionales.val_parametro%type;
begin
  p_cod_error := 0;

  begin
    select p.nro_documento, p.nom_completo, p.dir_correo
      into v_nro_documento, v_nom_completo, v_dir_correo
      from ba_personas p
     where p.cod_persona = p_cod_persona;
  exception
    when no_data_found then
      p_cod_error := 1;
      p_mensaje   := 'La persona ' || p_cod_persona || ' no existe';
    when others then
      p_cod_error := 1;
      p_mensaje   := 'Error inesperado al buscar datos de la persona ' ||
                     p_cod_persona;
      v_log_error := substr(p_mensaje || ' Error: ' || sqlerrm, 1, 4000);
  end;
  if nvl(p_cod_error, 0) = 0 then
    begin
      select trim(t.area || t.telefono)
        into v_telefono
        from ba_telefonos t
       where t.cod_persona = p_cod_persona
         and t.principal = 'S'
         and t.tipo = 'P'
         and rownum = 1;
    exception
      when no_data_found then
        p_cod_error := 2;
        p_mensaje   := 'No existe telefono principal para la persona ' ||
                       p_cod_persona;
      when others then
        p_cod_error := 2;
        p_mensaje   := 'Error inesperado al buscar telefono de la persona ' ||
                       p_cod_persona;
        v_log_error := substr(p_mensaje || ' Error: ' || sqlerrm, 1, 4000);
    end;
  end if;

  if nvl(p_cod_error, 0) = 0 then
    v_dir_mail_experiencia := nvl(fug_obt_pardinamico('MAI_CAN_PROD'), 'X');
    if v_dir_mail_experiencia = 'X' then
      p_cod_error := 3;
      p_mensaje   := 'El parametro "MAI_CAN_PROD" no se encuentra configurado ';
    end if;
  end if;
  if nvl(p_cod_error, 0) = 0 then
  
    v_pen_can_producto := nvl(fue_per_dat_adicional(p_cod_persona,
                                                    'PEN_CAN_PRODUCTOS'),
                              'N');
  
    if v_pen_can_producto = 'N' then
      begin
        insert into ba_per_dat_adicionales
          (cod_persona, parametro, val_parametro)
        values
          (p_cod_persona, 'PEN_CAN_PRODUCTOS', 'S');
      exception
        when others then
          p_mensaje   := 'Error al insertar parametro adicional de la persona';
          p_cod_error := 4;
          v_log_error := substr('Error al insertar parametro adicional de la persona ' ||
                                sqlerrm,
                                1,
                                4000);
      end;
    
    else
      p_mensaje   := 'La solicitud ya se realizó previamente';
      p_cod_error := 999;
    end if;
  end if;
  if nvl(p_cod_error, 0) != 0 and
     nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
    prg_ins_log_programas('PRG_ENV_MAI_CAN_PRODUCTO',
                          substr(nvl(v_log_error, p_mensaje), 1, 4000),
                          p_cod_persona,
                          null);
  else
  
    it_mail.mail(fug_obt_dir_correo,
                 v_dir_mail_experiencia,
                 'Solicitud de cancelación de productos Super APP',
                 'Cliente ha solicitado cancelar sus productos desde la super APP ' ||
                 CHR(10) || CHR(10) || 'Sus datos son: ' || CHR(10) ||
                 'Nro. documento: ' || v_nro_documento || CHR(10) ||
                 'Nombre completo: ' || v_nom_completo || CHR(10) ||
                 'Telefono: ' || v_telefono || CHR(10) || 'Correo: ' ||
                 v_dir_correo || CHR(10) || CHR(10) ||
                 'Comunicarse con el cliente en la brevedad para seguimiento.');
  end if;
exception
  when others then
    p_mensaje   := 'Ocurrió un error inesperado en el proceso de envio de mail ' ||
                   DBMS_UTILITY.format_error_stack || ' - ' ||
                   DBMS_UTILITY.format_error_backtrace;
    p_cod_error := 5;
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      prg_ins_log_programas('PRG_ENV_MAI_CAN_PRODUCTO',
                            substr(nvl(v_log_error, p_mensaje), 1, 4000),
                            p_cod_persona,
                            null);
    end if;
end prg_env_mai_can_producto;
/

