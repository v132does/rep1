create or replace function it.fuw_not_cli_obt_usu_baja(p_cod_persona in bw_not_cli_suscriptos.cod_persona%type)
  return varchar2 is
---Función para obtener usuario que realiza la baja de un cliente del servicio de notificaciones
---Declaración de Variables
v_cod_ori_baja      bw_not_cli_destino.cod_destino%type;
v_usu_baja          bw_not_cli_destino.usu_insercion%type;
v_ori_baja          varchar2(30);

----Procedimiento Interno
procedure lp_obt_origen(p_cod_persona       in bw_not_cli_suscriptos.cod_persona%type,
                        p_cod_destino       in out bw_not_cli_destino.cod_destino%type,
                        p_cod_usu_insercion in out bw_not_cli_destino.usu_insercion%type)
                        is

  v_cod_destino         bw_not_cli_destino.cod_destino%type;
  v_usu_insercion   bw_not_cli_destino.usu_insercion%type;

begin
  --Obtiene el destino y usuario de baja
  begin
    select g.cod_destino_old, g.usu_insercion
      into v_cod_destino, v_usu_insercion
      from bw_not_cli_destino_his g
     where g.cod_persona_old = p_cod_persona
       and g.novedad = 'E'
       and (g.fec_insercion) =
           (select max(h.fec_insercion)
              from bw_not_cli_destino_his h
             where h.cod_persona_old = g.cod_persona_old
               and h.novedad = g.novedad);

  exception
    when others then
      Begin
        select g.cod_destino_old, g.usu_insercion
          into v_cod_destino, v_usu_insercion
          from bw_not_cli_destino_his g
         where g.cod_persona_old = p_cod_persona
           and g.novedad = 'M'
           and (g.fec_insercion) =
               (select max(h.fec_insercion)
                  from bw_not_cli_destino_his h
                 where h.cod_persona_old = g.cod_persona_old
                   and h.novedad = g.novedad)
            and rownum < 2;

      Exception
        when others then
            Begin
              select g.cod_destino, g.usu_modificacion
                into v_cod_destino, v_usu_insercion
                from bw_not_cli_destino g
               where g.cod_persona = p_cod_persona
                 and (g.usu_modificacion) =
                     (select max(h.usu_modificacion)
                        from bw_not_cli_destino h
                       where h.cod_persona = g.cod_persona)
                 and rownum < 2;
            Exception
              when others then
                null;
            End;
      End;
  end;
  p_cod_destino     := v_cod_destino;
  p_cod_usu_insercion := v_usu_insercion;

exception
  when others then
    null;
end ;

begin
    ---Obtengo destino original y usuario que lo insertó
    lp_obt_origen (p_cod_persona, v_cod_ori_baja, v_usu_baja);

    return v_usu_baja;

exception
  when others then
    return v_usu_baja;
end fuw_not_cli_obt_usu_baja;
/

