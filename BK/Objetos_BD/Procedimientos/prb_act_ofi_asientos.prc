create or replace procedure it.prb_act_ofi_asientos is
v_cod_ofi_asi_origen number(3);
v_cod_ofi_asi_destino number(3);
v_cantidad number(5);
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(2);
begin
  --Cargar oficina origen y destino--
  v_cod_ofi_asi_origen  := 5;  --Ag. Zona Baja-Ya cerrado--
  v_cod_ofi_asi_destino := 14; --Ag Superseis--
  --Ver si existen registros de la fecha--
  select nvl(count(*),0) 
    into v_cantidad
    from cb_asientos a
   where a.fecha = v_fecha
     and a.cod_oficina = v_cod_ofi_asi_origen;
  --Si existen registros modificar--
  if nvl(v_cantidad,0) > 0 then
     --Modificar registros con la nueva oficina--
     update cb_asientos_det a
        set a.cod_oficina = v_cod_ofi_asi_destino
      where a.fecha = v_fecha
        and a.cod_oficina = v_cod_ofi_asi_origen;     
     update cb_asientos a
        set a.cod_oficina = v_cod_ofi_asi_destino
     where a.fecha = v_fecha
       and a.cod_oficina = v_cod_ofi_asi_origen;   
  end if;
exception
 when others then
      raise_application_error(-20000,'Error en prb_act_ofi_asientos.'||sqlerrm);
end prb_act_ofi_asientos;
/

