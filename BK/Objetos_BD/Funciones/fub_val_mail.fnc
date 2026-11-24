create or replace function it.fub_val_mail(p_mail        in varchar2,
                                          p_persona     in varchar2,
                                          p_nro_factura in varchar2) return varchar2 is

    -- Función creada para validación del correo electrónico del proceso: PRB_INS_FAC_ELECTRONICA

    v_mail varchar2(100);
    v_def_mail varchar2(100) := 'noposee@gmail.com';
begin
    --proposito: validar el correo electronico del cliente.
    --Autor: secoria
    --Fecha: 10/06/2025
    --obs: si el correo es nulo o vacio se devuelve un correo por defecto.
    if p_mail is null or p_mail = '' then
      v_mail := FUG_OBT_DIR_MAIL_PER(p_persona);
    else
      v_mail := p_mail;
    end if;
    
    --Quito espacios en blanco, saltos de linea.
    --chr(9) es tabulador.
    --chr(10) es salto de linea.
    --chr(12) es salto de pagina.
    --chr(13) es retorno de carro.
    --chr(32) es espacio en blanco.
    --chr(160) es espacio en blanco no rompible.
    
    v_mail := replace(replace(replace(replace(replace(replace(v_mail,chr(10),''),chr(12),''),chr(13),''),chr(9),''),chr(32),''),chr(160),'');
    
    --Quito caracteres especiales con tildes y acentos. (mas complicados de detectar con una expresion regular)
    v_mail := translate(v_mail,'àáâãäåèéêëìíîïòóôõöùúûüñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÑ','aaaaaaeeeeiiiiooooouuuunAAAAAAEEEEIIIIOOOOOUUUUN');
    
    --Quito '.' al inicio y al final del correo.
    v_mail := trim('.' FROM v_mail);
    
    if not REGEXP_LIKE(v_mail,'^[A-Za-z0-9._%+-]+@([A-Za-z0-9-]{2,}\.)+[A-Za-z]{2,}$') then
      --Si no es un correo valido, se devuelve el correo por defecto.
      v_mail := v_def_mail;
    end if;
    
    if p_mail <> v_mail then
      --Si el correo original es diferente al validado, se registra el cambio.
      PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Advertencia el correo del cliente: '||p_persona||' fue modificado de: '||p_mail||' a: '||v_mail,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
    end if;
    
    
    return v_mail;
exception
    when others then
      PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Error en el correo del cliente: '||p_persona||' se utilizará: '||v_def_mail||'. '||sqlerrm,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
      return v_def_mail;
end fub_val_mail;