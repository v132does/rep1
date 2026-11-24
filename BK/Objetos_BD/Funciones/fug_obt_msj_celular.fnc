create or replace function it.fug_obt_msj_celular (p_cod_persona in varchar2 default null)
return varchar2 is
v_mensaje varchar2(1000);
v_fila varchar2(200);
v_cod_persona varchar2(20);
v_celular varchar2(100);
v_automatico varchar2(1);
v_rec_sms varchar2(1);
v_cantidad number;
begin
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   -- tomo el primer mensaje pendiente via celular
   select translate(substr(a.detalle,1,160),'áéíóúñÑ'||chr(10),'aeiounN ') descripcion, rowid, cod_persona, automatico
     into v_mensaje, v_fila, v_cod_persona, v_automatico
     from it.cr_per_notas a
    where (a.cod_persona = p_cod_persona or p_cod_persona is null)
      and a.medio = 'T'
      and a.estado = 'P'
      and rownum = 1;
    -- busco el celular del cliente
    select count(*)
      into v_cantidad
      from it.cr_per_notas a
     where (a.cod_persona = p_cod_persona or p_cod_persona is null)
      and a.medio = 'T'
      and a.estado = 'P';
     if v_cantidad > 3 then      
       v_celular := '0991747173';  -- OJO!!! ESTO ES SOLO PARA PRUEBAS
     else 
       v_celular := '0991747173'; --'0971204023';
     end if;
    /* para pruebas se anulo y se puso fijo el celular de Ingrid 
    select trim(area||telefono)
      into v_celular
      from ba_telefonos x
     where x.cod_persona = v_cod_persona
       and x.tip_linea = 'C'
       and (principal = 'S' or
            cod_telefono = (select min(cod_telefono)
                              from ba_telefonos
                             where cod_persona = v_cod_persona
                               and tip_linea = 'C'))
       and rownum = 1;
    */
    
   begin
      select a.recibe_sms
        into v_rec_sms
        from ba_personas a
       where a.cod_persona = v_cod_persona;
      if v_rec_sms = 'N' then
         raise no_data_found;
      end if;   
   exception
     when others then
         raise no_data_found;
   end;
   if v_automatico = 'S' then
       -- si es automatico se borra
       delete from cr_per_notas where rowid = v_fila;
       -- Registrar auditoria de sms
       insert into ge_log_sms(
          cod_persona, fecha, telefono, tipo, mensaje)
       values
          (v_cod_persona, pag_cal.FU_OBT_FEC_ACTUAL(1),
           v_celular, 'E', v_mensaje);
   else
       -- actualizo el mensaje como enviado
       update cr_per_notas
          set estado = 'R'
        where rowid = v_fila;
   end if;
   return v_celular||'~'||v_mensaje;
exception
  when no_data_found then
    -- actualizo para que ya no intente enviar todo el tiempo si la persona no tiene celular
    update cr_per_notas
        set estado = 'R'
      where rowid = v_fila;
    return null;
  when others then
    raise_application_error(-20000,'Error al leer mensaje para el celular '||sqlerrm);
end;
/

