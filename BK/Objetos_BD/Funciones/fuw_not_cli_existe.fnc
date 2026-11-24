create or replace function it.fuw_not_cli_existe(p_cod_persona in bw_not_cli_suscriptos.cod_persona%type)
  return varchar2 is
  ---Funcion para verificar si el cliente existe en tabla de notificaciones
  v_existe varchar2(1);

begin

  begin
    select distinct 'S'
      into v_existe
      from bw_not_mensajes g
     where g.cod_persona = p_cod_persona
       and g.fec_envio is not null;
  
  exception
    when no_data_found then
      begin
        select distinct 'S'
          into v_existe
          from bw_not_mensajes_his h
         where h.cod_persona = p_cod_persona
           and h.fec_envio is not null;
      
      exception
        when no_data_found then
          v_existe := 'N';
        when others then
          v_existe := 'N';
      end;
    when others then
      v_existe := 'N';
  end;

  return v_existe;

exception
  when others then
    v_existe := 'N';
    return v_existe;
end fuw_not_cli_existe;
/

