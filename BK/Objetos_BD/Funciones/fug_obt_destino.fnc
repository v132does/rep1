CREATE OR REPLACE FUNCTION IT.FUG_OBT_DESTINO (p_nro_solicitud in pr_solicitudes.nro_solicitud%type)
return varchar2 is

v_destino ba_cod_referencias.abreviatura%type;
begin
  select FUE_OBT_DES_REFCODES('TIP_DES_ESPECIFICO',tip_des_especifico)destino
         into v_destino
         from pr_sol_destinos
         where  nro_solicitud = p_nro_solicitud;
   return v_destino;
exception
   when no_data_found then
      v_destino := null;
      return v_destino;
   WHEN OTHERS THEN
                   RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Error al Cargar el destino de la operación planteada. ');
end FUG_OBT_DESTINO;
/

