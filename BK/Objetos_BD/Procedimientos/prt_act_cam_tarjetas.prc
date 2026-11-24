create or replace procedure it.PRT_ACT_CAM_TARJETAS is

  v_nro_tarjeta   ta_tarjetas.nro_tarjeta%type;
  v_cod_campana   cr_campanas.cod_campana%type;
  v_nro_cuenta    ta_cta_tarjetas.nro_cuenta%type;
  v_nro_solicitud ta_solicitudes.nro_solicitud%type;
  cursor c_cambios is
    select * from ta_act_campanas_tmp;

begin

  for val in c_cambios loop
    --- Valida tarjeta
    Begin
      select e.nro_tarjeta
        into v_nro_tarjeta
        from ta_tarjetas e
       where e.nro_tarjeta = val.nro_tarjeta;
    exception
      when others then
        raise_application_error(-20000,
                                'Tarjeta : ' || val.nro_tarjeta ||
                                ' no existe en el sistema, verifique planilla');
    end;
  
    --- Valida campana
    Begin
      select e.cod_campana
        into v_cod_campana
        from cr_campanas e
       where e.cod_campana = val.cod_campana;
    exception
      when others then
        raise_application_error(-20000,
                                'Campana : ' || val.cod_campana ||
                                ' no existe en el sistema, verifique planilla');
    end;
  end loop;

  --- Proceso principal
  for reg in c_cambios loop
    begin
      begin
        select a.nro_cuenta
          into v_nro_cuenta
          from ta_tarjetas a
         where a.nro_tarjeta = reg.nro_tarjeta;
      exception
        when others then
          v_nro_cuenta := 0;
      end;
    
      Begin
        select a.nro_solicitud
          into v_nro_solicitud
          from ta_cta_tarjetas a  --DYDMR-1696 Ajuste de la tabla a obtener el dato, anteriormente traia de ta_solicitudes
         where a.nro_cuenta = v_nro_cuenta;
      exception
        when others then
          v_nro_solicitud := 0;
      end;
    
      if v_nro_cuenta <> 0 then
        update ta_cta_tarjetas a
           set a.cod_campana = reg.cod_campana
         where a.nro_cuenta = v_nro_cuenta;
      end if;
    
      if v_nro_solicitud <> 0 then
        update ta_solicitudes a
           set a.cod_campana = reg.cod_campana
         where a.nro_solicitud = v_nro_solicitud;
      end if;
    exception
      when no_data_found then
        raise_application_error(-20000,
                                'Tarjeta ' || reg.nro_tarjeta ||
                                ' no registrado');
    end;
  end loop;
end prt_act_cam_tarjetas;
/

