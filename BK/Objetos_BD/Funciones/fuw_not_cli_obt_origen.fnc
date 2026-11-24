create or replace function it.fuw_not_cli_obt_origen(p_cod_persona in bw_not_cli_suscriptos.cod_persona%type)
  return varchar2 is
----Funcion para obtener origen de suscripción del cliente al servicio de notificaciones
---Declaración de Variables
v_cod_des_original  bw_not_cli_destino.cod_destino%type;
v_usu_insercion     bw_not_cli_destino.usu_insercion%type;
v_origen            varchar2(30);

----Procedimiento Interno
procedure lp_obt_origen(p_cod_persona       in bw_not_cli_suscriptos.cod_persona%type,
                        p_cod_destino       in out bw_not_cli_destino.cod_destino%type,
                        p_cod_usu_insercion in out bw_not_cli_destino.usu_insercion%type)
                        is

  v_cod_destino         bw_not_cli_destino.cod_destino%type;
  v_usu_insercion   bw_not_cli_destino.usu_insercion%type;

begin  
  --Obtiene el primer destino configurado y el usuario que lo insertó
  begin
    select g.cod_destino_old, g.usu_insercion
      into v_cod_destino, v_usu_insercion
      from bw_not_cli_destino_his g
     where g.cod_persona_old = p_cod_persona
       and (g.fec_insercion) =
           (select min(h.fec_insercion)
              from bw_not_cli_destino_his h
             where h.cod_persona_old = g.cod_persona_old);
  
  exception
    when no_data_found then
      ----Si no se encontraron datos - buscar en tabla de destino actual y el usuario que lo insertó
      begin
        select e.cod_destino, e.usu_insercion
          into v_cod_destino, v_usu_insercion
          from bw_not_cli_destino e
         where e.cod_persona = p_cod_persona
           and (e.fec_insercion) =
               (select min(c.fec_insercion)
                  from bw_not_cli_destino c
                 where c.cod_persona = e.cod_persona);
      exception
        when no_data_found then
          v_cod_destino := 0;
        when others then
          v_cod_destino := 9;
      end;
    when others then
      v_cod_destino := 9;
  end;
  p_cod_destino     := v_cod_destino;
  p_cod_usu_insercion := v_usu_insercion;

exception
  when others then
    null;
end ;

begin
    ---Obtengo destino original y usuario que lo insertó
    lp_obt_origen (p_cod_persona, v_cod_des_original, v_usu_insercion);
    
    ---Si el destino original es 3 es movil, en caso contrario se considera el usuario de insercion 
    ---si es hbank es origen homebanking si el usuario es un xpy/xpg/py el origen es itgf
    If v_cod_des_original = 3 then
       v_origen := 'MOVIL';
    Else
       If v_cod_des_original != 3 and v_usu_insercion = 'HBANK' then
          v_origen := 'HOMEBANKING';
       Else
         v_origen := 'ITGF';
       End if;
    End if;
    
    return v_origen;
    
exception
  when others then
    v_origen := 'Origen Incorrecto';
    return v_origen;
end fuw_not_cli_obt_origen;
/

