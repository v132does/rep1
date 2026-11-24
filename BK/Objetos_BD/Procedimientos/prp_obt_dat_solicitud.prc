create or replace procedure it.prp_obt_dat_solicitud(p_nro_cuenta         in pr_cta_prestamos.nro_cuenta%type,
                                                     p_mto_prestamo       out pr_cta_prestamos.monto%type,
                                                     p_can_cuotas         out pr_cta_prestamos.can_cuotas%type,
                                                     p_fec_pri_vto        out pr_solicitudes.fec_pri_vencimiento%type,
                                                     p_mto_cuota          out pr_cuotas.mto_capital%type,
                                                     p_des_prestamos      out varchar2,
                                                     p_gas_administrativo out pr_sol_cargos.monto%type,
                                                     p_gas_seguro         out pr_sol_cargos.monto%type,
                                                     p_tan                out pr_sol_tasas.val_tasa%type,
                                                     p_tae                out pr_sol_tasas.val_tasa%type,
                                                     p_nom_prestamo       out pr_cta_prestamos.descripcion%type,
                                                     p_cod_error          out number,
                                                     p_msj_error          out varchar2,
                                                     p_monto_total        out pr_cta_prestamos.monto%type,
                                                     p_destino            out ge_cta_dat_adicionales.val_parametro%type,
                                                     p_fec_desembolso     out pr_solicitudes.fec_pri_vencimiento%type) is

  v_mto_prestamos      number;
  v_can_cuota          number;
  v_fec_pri_vto        date;
  v_mto_cuota          number;
  v_gas_administrativo number;
  v_gas_seguro         number;
  v_tae                pr_sol_tasas.val_tasa%type;
  v_tan                pr_sol_tasas.val_tasa%type;
  v_nom_prestamos      pr_solicitudes.descripcion%type;
  v_nro_solicitud      pr_solicitudes.nro_solicitud%type;
  v_cod_rub_economico  pr_cta_prestamos.cod_rub_economico%type;

begin
  -- Validar que el número de solicitud no sea nulo
  if p_nro_cuenta is null then
    p_cod_error := 1;
    p_msj_error := 'Debe ingresar un número de solicitud.';
    return;
  end if;

  begin
    -- Buscar en `pr_solicitudes`
    select p.monto,
           p.nro_solicitud,
           p.cod_rub_economico,
           p.tot_prestamo + p.mto_interes
      into v_mto_prestamos,
           v_nro_solicitud,
           v_cod_rub_economico,
           p_monto_total
      from pr_solicitudes p
     where p.nro_solicitud = p_nro_cuenta;
    -- Cantidad de cuotas
    select count(*)
      into v_can_cuota
      from pr_sol_cuotas
     where nro_solicitud = p_nro_cuenta
       and nro_cuota > 0;
  exception
    when no_data_found then
      p_cod_error := 2;
      p_msj_error := 'Nro_solicitud: ' || p_nro_cuenta || ' no existe';
      return;
    when others then
      p_cod_error := 3;
      p_msj_error := 'Error al obtener datos del préstamo: ' || sqlerrm;
      return;
  end;

  -- Si `p_monto_total` no tiene valor, calcular desde `pr_cuotas`
  if p_monto_total is null then
    select coalesce(sum(cu.mto_capital + cu.mto_interes +
                        cu.mto_int_documentado),
                    v_mto_prestamos)
      into p_monto_total
      from pr_cuotas cu
     where cu.nro_cuenta = p_nro_cuenta;
  end if;

  -- Obtener datos de la solicitud
  begin
    select a.fec_pri_vencimiento, a.descripcion
      into v_fec_pri_vto, v_nom_prestamos
      from pr_solicitudes a
     where a.nro_solicitud = v_nro_solicitud;
  
  exception
    when others then
      p_cod_error := 4;
      p_msj_error := 'Error al obtener datos de la solicitud: ' || sqlerrm;
      return;
  end;

  -- Obtener monto de la cuota
  begin
    select nvl(sc.mto_capital,0) + nvl(sc.val_interes,0)
      into v_mto_cuota
      from pr_sol_cuotas sc
     where sc.nro_solicitud = v_nro_solicitud
       and sc.nro_cuota = 1;
  exception
    when others then
      p_cod_error := 5;
      p_msj_error := 'Error al obtener cuota de la solicitud: ' || sqlerrm;
      return;
  end;

  -- Obtener gastos administrativos y de seguro en una sola consulta
  begin
    select sum(case
                 when sc.cod_transaccion = 704 then
                  sc.monto
                 else
                  0
               end),
           sum(case
                 when sc.cod_ent_seguro is not null then
                  sc.monto
                 else
                  0
               end)
      into v_gas_administrativo, v_gas_seguro
      from pr_sol_cargos sc
     where sc.nro_solicitud = v_nro_solicitud;
  exception
    when others then
      p_cod_error := 6;
      p_msj_error := 'Error al obtener cargos de la solicitud: ' || sqlerrm;
      return;
  end;

  -- Obtener tasas
  pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);

  -- Asignar valores de salida
  p_mto_prestamo       := v_mto_prestamos;
  p_can_cuotas         := v_can_cuota;
  p_fec_pri_vto        := v_fec_pri_vto;
  p_mto_cuota          := v_mto_cuota;
  p_gas_administrativo := coalesce(v_gas_administrativo, 0);
  p_gas_seguro         := coalesce(v_gas_seguro, 0);
  p_des_prestamos      := fug_obt_des_actividad(v_cod_rub_economico, 'N');
  p_nom_prestamo       := v_nom_prestamos;
  p_tan                := round(v_tan, 2);
  p_tae                := round(v_tae, 2);
  p_cod_error          := 0;
  p_msj_error          := 'Datos obtenidos correctamente';
end;
/
