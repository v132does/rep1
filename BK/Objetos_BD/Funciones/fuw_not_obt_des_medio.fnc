create or replace function it.fuw_not_obt_des_medio(p_cod_medio in bw_not_destinos.cod_destino%type)
  return varchar2 is
----Funcion para obtener Descripcion medio configurado del cliente para al servicio de notificaciones
v_des_medio             bw_not_destinos.nombre%type;

begin

 --Obtiene descripcion del medio recibido en parámetro
  begin
    select g.nombre
      into v_des_medio
      from bw_not_destinos g
     where g.cod_destino = p_cod_medio;
  
  exception
    when no_data_found then
      v_des_medio := 'Medio no Configurado';
    when others then
      v_des_medio := 'Medio Incorrecto';
    
  end;

    return v_des_medio;

exception
  when others then
    v_des_medio := 'Medio Incorrecto';
    return v_des_medio;
end fuw_not_obt_des_medio;
/

