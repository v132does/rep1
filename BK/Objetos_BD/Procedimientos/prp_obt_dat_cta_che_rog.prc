create or replace procedure it.prp_obt_dat_cta_che_rog(p_nro_cuenta         in pr_cta_prestamos.nro_cuenta%type,
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
                                                       p_fec_desembolso     out pr_solicitudes.fec_pri_vencimiento%type,
                                                       p_cuotas_apx         out number) is
  ---------------------------------------------------------------------------
  g_lugar     varchar2(250);
  g_msj_error varchar2(4000);
  g_cod_error number(3) default 0;
  ---------------------------------------------------------------------------
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
  v_msj_error          varchar2(4000);
  v_cod_error          number(3) default 0;
  function fu_obt_mto_cuota_apx(v_nro_solicitud in pr_solicitudes.nro_solicitud%type)
    return number is
    v_cuo_sol number;
  begin
    select max(nvl(sc.mto_capital, 0) + nvl(sc.val_interes, 0))
      into v_cuo_sol
      from pr_sol_cuotas sc
     where sc.nro_solicitud = v_nro_solicitud
       and sc.nro_cuota <> 1;
    return v_cuo_sol;
  exception
    when others then
      g_cod_error := '033';
      g_lugar     := 'Obtiene Cuota ';
      g_msj_error := 'Error al buscar cuota de la solicitud ' || sqlerrm;
  end;
begin
  g_msj_error := ' ';
  g_cod_error := 0;
  if nvl(g_cod_error, '000') = '000' then
    if p_nro_cuenta is null then
      g_lugar     := 'Validamos el nro. cuenta no sea nulo.';
      g_cod_error := '002';
      g_msj_error := 'Debe de ingresar un nro. de cuenta';
    end if;
  end if;
  --
  if nvl(g_cod_error, '000') = '000' then
    begin
      select p.monto, p.can_cuotas, p.nro_solicitud, p.cod_rub_economico
        into v_mto_prestamos,
             v_can_cuota,
             v_nro_solicitud,
             v_cod_rub_economico
        from pr_cta_prestamos p
       where p.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        --da-5357-22032022
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
      
        select count(*)
          into v_can_cuota
          from pr_sol_cuotas t
         where t.nro_solicitud = p_nro_cuenta
           and t.nro_cuota > 0;
      
      when others then
        g_lugar     := 'Obtenemos datos del prestamo';
        g_cod_error := '003';
        g_msj_error := 'Error. Al obtener datos del prestamo ' || sqlerrm;
    end;
    --da-6436
    if p_monto_total is null then
      begin
        select sum(nvl(cu.mto_capital, 0) + nvl(cu.mto_interes, 0) +
                   nvl(cu.mto_int_documentado, 0))
          into p_monto_total
          from pr_cuotas cu
         where cu.nro_cuenta = p_nro_cuenta;
        if p_monto_total = 0 then
          p_monto_total := v_mto_prestamos;
        end if;
      end;
    end if;
  end if;
  --
  if nvl(g_cod_error, '000') = '000' then
    begin
      select a.fec_pri_vencimiento, a.descripcion
        into v_fec_pri_vto, v_nom_prestamos
        from pr_solicitudes a
       where a.nro_solicitud = v_nro_solicitud;
    exception
      when others then
        g_lugar     := 'Obtenemos datos de la solicitud';
        g_cod_error := '004';
        g_msj_error := 'Error. Al obtener datos de la solicitud ' ||
                       sqlerrm;
    end;
  end if;
  --
  if nvl(g_cod_error, '000') = '000' then
    begin
      select (sc.mto_capital + sc.val_interes)
        into v_mto_cuota
        from pr_sol_cuotas sc
       where sc.nro_solicitud = v_nro_solicitud
         and sc.nro_cuota = 1;
    exception
      when others then
        g_cod_error := '005';
        g_lugar     := 'Obtiene Cuota ';
        g_msj_error := 'Error al buscar cuota de la solicitud ' || sqlerrm;
    end;
  end if;
  --
  if nvl(g_cod_error, '000') = '000' then
    begin
      select (sc.monto)
        into v_gas_administrativo
        from pr_sol_cargos sc
       where sc.nro_solicitud = v_nro_solicitud
         and sc.cod_transaccion = 704;
    exception
      when others then
        g_cod_error := '006';
        g_lugar     := 'Obtiene Gastos Administrativo ';
        g_msj_error := 'Error al buscar cargo de la solicitud ' || sqlerrm;
    end;
  end if;
  --
  if nvl(g_cod_error, '000') = '000' then
    begin
      select sum(sc.monto)
        into v_gas_seguro
        from pr_sol_cargos sc
       where sc.nro_solicitud = v_nro_solicitud
         and sc.cod_ent_seguro is not null;
    exception
      when others then
        g_cod_error := '006';
        g_lugar     := 'Obtiene Gastos Administrativo ';
        g_msj_error := 'Error al buscar cargo de la solicitud ' || sqlerrm;
    end;
  end if;
  --
  pas_bcp.pr_obt_tas_prestamo(v_nro_solicitud, null, v_tae, v_tan);
  --
  if nvl(g_cod_error, '000') = '000' then
    p_mto_prestamo       := v_mto_prestamos;
    p_can_cuotas         := v_can_cuota;
    p_fec_pri_vto        := v_fec_pri_vto;
    p_mto_cuota          := v_mto_cuota;
    p_gas_administrativo := nvl(v_gas_administrativo, 0);
    p_gas_seguro         := nvl(v_gas_seguro, 0);
    p_nom_prestamo       := v_nom_prestamos;
    p_des_prestamos      := fug_obt_des_actividad(v_cod_rub_economico, 'N');
    p_tan                := round(v_tan, 2);
    p_tae                := round(v_tae, 2);
    p_cod_error          := g_cod_error;
    p_msj_error          := 'DATOS OBTENIDOS CORRECTAMENTE';
    p_cuotas_apx         := fu_obt_mto_cuota_apx(v_nro_solicitud);
  
    select min(m.fecha)
      into p_fec_desembolso
      from gv_movimientos m
     where m.nro_cuenta = p_nro_cuenta;
  
    --da-6436
    p_destino := fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA');
  
  else
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  end if;
exception
  when others then
    g_lugar     := 'Proceso de obtencion datos del credito desembolsado.';
    g_cod_error := '001';
    g_msj_error := 'Error al obtener los datos del credito ' || sqlerrm;
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
end;
/
