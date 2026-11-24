create or replace function it.fuw_not_cli_obt_medio(p_cod_persona in bw_not_cli_suscriptos.cod_persona%type)
  return number is
----Funcion para obtener medio configurado del cliente para al servicio de notificaciones
---Declaración de Variables

v_medio             bw_not_cli_destino.cod_destino%type;

begin

 --Obtiene el primer destino configurado y el usuario que lo insertó
  begin
    select g.cod_destino
      into v_medio
      from bw_not_cli_destino g
     where g.cod_persona = p_cod_persona
       and g.activo = 'S';
  exception
    when no_data_found then
      ----Si no se encontraron datos - buscar en tabla de destino actual
      begin
        select distinct g.cod_destino
          into v_medio
          from bw_not_cli_destino g
         where g.cod_persona = p_cod_persona
           and g.activo = 'N'
           and trunc(g.fec_modificacion) = 
           ( select max(trunc(c.fec_modificacion))
            from bw_not_cli_destino c
           where c.cod_persona = g.cod_persona)
           and rownum < 2;
      exception
        when no_data_found then
              begin
                select distinct g.cod_destino_old
                  into v_medio
                  from bw_not_cli_destino_his g
                 where g.cod_persona_old = p_cod_persona
                   and trunc(g.fec_modificacion) =
                       (select max(trunc(c.fec_modificacion))
                          from bw_not_cli_destino_his c
                         where c.cod_persona_old = g.cod_persona_old)
                   and rownum < 2;
              exception
                when no_data_found then
                  v_medio := 0;
                when others then
                  v_medio := 9;
              end;
        when others then
          v_medio := 9;
      end;
    when too_many_rows then
      begin
        select l.cod_destino
          into v_medio
          from bw_not_cli_destino l
         where l.cod_persona = p_cod_persona
           and l.activo = 'S'
           and trunc(l.fec_modificacion) =
                       (select max(trunc(c.fec_modificacion))
                          from bw_not_cli_destino c
                         where c.cod_persona = l.cod_persona
                           and c.activo = 'S')
           and rownum < 2;           
      exception
        when others then
          v_medio := 9;                 
      end;
    when others then
      v_medio := 9;
  end;



    return v_medio;

exception
  when others then
    v_medio := 9;
    return v_medio;
end fuw_not_cli_obt_medio;
/

