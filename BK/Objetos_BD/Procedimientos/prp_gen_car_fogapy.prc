CREATE OR REPLACE PROCEDURE IT.PRP_GEN_CAR_FOGAPY(p_nro_solicitud in number default null) IS

  v_fec_actual    date := pae_cnf.fu_obt_fec_actual(6);
  v_nro_solicitud pr_solicitudes.nro_solicitud%type;
  v_sesion varchar2(2);

  -- Cursor de solicitudes desembolsadas en la fecha
  Cursor c_solicitudes is
    select s.*,
           car.cod_transaccion cod_tra_cargo,
           car.val_tasa        val_tar_cargo
      from pr_solicitudes s, pr_sol_cargos car
     where s.estado = 'A'
       and s.fec_aprobacion = v_fec_actual
       and car.nro_solicitud = s.nro_solicitud
       and s.nro_solicitud = nvl(p_nro_solicitud, s.nro_solicitud)
       and car.cod_transaccion = 703; -- TRANSACCION COMISION FOGAPY
  -- Cursor de cuotas
  Cursor c_cuotas is
    select cuo.nro_solicitud,
           cuo.nro_cuota,
           cuo.fec_vto_habil,
           cuo.sal_cap_anterior,
           cuo.dia_periodo
      from pr_sol_cuotas cuo
     where cuo.nro_solicitud = v_nro_solicitud
       and cuo.nro_cuota > 0;

  --
  v_cuenta    pr_cta_prestamos.nro_cuenta%type;
  v_imp_cuota pr_sol_cargos.monto%type;
  v_redondeo  number;
  -- Variables de registro
  r_pcpre      pr_cta_prestamos%rowtype;
  v_lugar      varchar2(100);
  v_fec_inicio date;
  -- Implementacion SET/2021 (ALVD / DYDMR-16211)
  v_car_sin_iva pr_sol_cargos.val_tasa%type;

  --------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------
  --  EMPIEZA EL PROCEDIMIENTO
  --------------------------------------------------------------------------------------------
BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 6;
  end;

  -- Recupera el valor de la sesión actual
  select value
  into v_sesion
  from nls_session_parameters
  where parameter = 'NLS_NUMERIC_CHARACTERS';

  pre_cam_for_numerico(',.');
  
  For sol in c_solicitudes loop
    v_nro_solicitud := sol.nro_solicitud;
    --Obtener nro. cuenta del prestamo
    v_lugar := 'Obt.Nro.Cuenta Prestamo';
    Begin
      Select nro_cuenta
        into v_cuenta
        from pr_cta_prestamos s
       where s.nro_solicitud = v_nro_solicitud;
    Exception
      When others then
        raise_application_error(-20000,
                                'Error al traer datos del prestamo. Solicitud ' ||
                                sol.nro_solicitud);
    End;
  
    --
    For c in c_cuotas loop
      -- obtener monto de comision para la cuota
      v_lugar := 'Obt.Mto Comision Cuota ' || c.nro_cuota;
      -- Obtener el valor del cargo sin iva para insertar en pr_cta_gastos, porque en el cobro de cuotas le agrega el IVA. (DYDMR-16211)
      v_car_sin_iva := sol.val_tar_cargo / 1.1;
      v_imp_cuota   := pap_fpy.fu_obt_mto_car_mensual(v_nro_solicitud,
                                                      c.nro_cuota,
                                                      v_car_sin_iva,
                                                      'PRO');
      --
    
      v_fec_inicio := c.fec_vto_habil - (c.dia_periodo - 1);
      --dbms_output.put_line('--------------------------------------------------------------------------------------------------');
      --dbms_output.put_line('Mto Comision Cuota '||v_imp_cuota||'-'||c.nro_cuota);
      --dbms_output.put_line('--------------------------------------------------------------------------------------------------');
      if nvl(v_imp_cuota, 0) > 0 then
        --
        v_lugar := 'Insert en Pr_Cta_gastos. Cuota ' || c.nro_cuota;
        if c.nro_cuota = 1 then
          begin
            Insert into Pr_cta_gastos
              (Nro_cuenta,
               Cod_transaccion,
               cod_moneda,
               Monto,
               Fec_ingreso,
               Fec_ini_vigencia,
               Fec_vencimiento,
               Cod_modalidad,
               cod_modulo,
               nro_solicitud)
            Values
              (v_cuenta,
               sol.cod_tra_cargo,
               sol.cod_moneda,
               v_imp_cuota,
               c.fec_vto_habil - 30,
               c.fec_vto_habil - 30,
               c.fec_vto_habil,
               sol.cod_modalidad,
               sol.cod_modulo,
               v_nro_solicitud);
            --dbms_output.put_line('Cuenta '||v_cuenta||'-Tra:'||sol.cod_tra_cargo||'-Mon:'||sol.cod_moneda||'-FI:'||to_date(v_fec_inicio,'dd/mm/yyyy')||'-FV:'||to_date(c.fec_vto_habil,'dd/mm/yyyy')||'-Mod:'||sol.cod_modulo||'-Sol:'||v_nro_solicitud);
          exception
            when others then
              raise_application_error(-20000,
                                      'Al ins. Gastos Adic.Fogapy.Error:' ||
                                      v_cuenta || ' ' || v_lugar || '-' ||
                                      sqlerrm);
          end;
        else
          begin
            Insert into Pr_cta_gastos
              (Nro_cuenta,
               Cod_transaccion,
               cod_moneda,
               Monto,
               Fec_ingreso,
               Fec_ini_vigencia,
               Fec_vencimiento,
               Cod_modalidad,
               cod_modulo,
               nro_solicitud)
            Values
              (v_cuenta,
               sol.cod_tra_cargo,
               sol.cod_moneda,
               v_imp_cuota,
               v_fec_inicio,
               v_fec_inicio,
               c.fec_vto_habil,
               sol.cod_modalidad,
               sol.cod_modulo,
               v_nro_solicitud);
            --dbms_output.put_line('Cuenta '||v_cuenta||'-Tra:'||sol.cod_tra_cargo||'-Mon:'||sol.cod_moneda||'-FI:'||to_date(v_fec_inicio,'dd/mm/yyyy')||'-FV:'||to_date(c.fec_vto_habil,'dd/mm/yyyy')||'-Mod:'||sol.cod_modulo||'-Sol:'||v_nro_solicitud);
          exception
            when others then
              raise_application_error(-20000,
                                      'Al ins. Gastos Adic.Fogapy.Error:' ||
                                      v_cuenta || ' ' || v_lugar || '-' ||
                                      sqlerrm);
          end;
        end if;
      end if;
      --
    END LOOP;
  end loop;
    pre_cam_for_numerico(v_sesion);
Exception
  WHEN OTHERS THEN
    pre_cam_for_numerico(v_sesion);
    raise_application_error(-20001,
                            'Al generar Gasto Adic.Fogapy.Error:' ||
                            v_cuenta || ' ' || v_lugar || '-' || sqlerrm);
END;
