create or replace function it.fuw_not_cli_tip_suscripcion(p_cod_persona in bw_not_cli_suscriptos.cod_persona%type)
  return varchar2 is

---  Función para obtener tipo de suscripcion de un cliente al servicio de notificaciones
---Declaración de Variables
v_cod_des_original    bw_not_cli_destino.cod_destino%type;
v_usu_insercion       bw_not_cli_destino.usu_insercion%type;
v_origen              varchar2(30);
v_tip_suscripcion     varchar2(30);
v_can_notificaciones  number;

begin
  
v_origen := fuw_not_cli_obt_origen (p_cod_persona);

begin
  select nvl(count(0), 0)
    into v_can_notificaciones
    from bw_not_suscripciones n
   where n.cod_persona = p_cod_persona;
exception
  when no_data_found then
    v_can_notificaciones := 0;
  when others then
    v_can_notificaciones := 0;
end;

  If v_origen = 'ITGF' and v_can_notificaciones = 0 then
      v_tip_suscripcion := 'COMPULSIVO';
  Else
      v_tip_suscripcion := 'ON-DEMAND';
  End if;

    return v_tip_suscripcion;
    
exception
  when others then
    v_tip_suscripcion := 'ON-DEMAND';
    return v_tip_suscripcion;
end fuw_not_cli_tip_suscripcion;
/

