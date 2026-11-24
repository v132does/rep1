CREATE OR REPLACE PROCEDURE IT.prp_obt_dat_cta_pre_apr(p_nro_cuenta         IN pr_cta_prestamos.nro_cuenta%TYPE,
                                                       p_mto_prestamo       OUT pr_cta_prestamos.monto%TYPE,
                                                       p_can_cuotas         OUT pr_cta_prestamos.can_cuotas%TYPE,
                                                       p_fec_pri_vto        OUT pr_solicitudes.fec_pri_vencimiento%TYPE,
                                                       p_mto_cuota          OUT pr_cuotas.mto_capital%TYPE,
                                                       p_des_prestamos      OUT VARCHAR2,
                                                       p_gas_administrativo OUT pr_sol_cargos.monto%TYPE,
                                                       p_gas_seguro         OUT pr_sol_cargos.monto%TYPE,
                                                       p_tan                OUT pr_sol_tasas.val_tasa%TYPE,
                                                       p_tae                OUT pr_sol_tasas.val_tasa%TYPE,
                                                       p_nom_prestamo       OUT pr_cta_prestamos.descripcion%TYPE,
                                                       p_cod_error          OUT NUMBER,
                                                       p_msj_error          OUT VARCHAR2,
                                                       p_monto_total        OUT pr_cta_prestamos.monto%TYPE,
                                                       p_destino            OUT ge_cta_dat_adicionales.val_parametro%TYPE,
                                                       p_fec_desembolso     OUT pr_solicitudes.fec_pri_vencimiento%TYPE) IS
  ---------------------------------------------------------------------------
  g_lugar     VARCHAR2(250);
  g_msj_error VARCHAR2(4000);
  g_cod_error NUMBER(3) DEFAULT 0;
  ---------------------------------------------------------------------------
  v_mto_prestamos      NUMBER;
  v_can_cuota          NUMBER;
  v_fec_pri_vto        DATE;
  v_mto_cuota          NUMBER;
  v_gas_administrativo NUMBER;
  v_gas_seguro         NUMBER;
  v_tae                pr_sol_tasas.val_tasa%TYPE;
  v_tan                pr_sol_tasas.val_tasa%TYPE;
  v_nom_prestamos      pr_solicitudes.descripcion%TYPE;
  v_nro_solicitud      Pr_Solicitudes.Nro_Solicitud%TYPE;
  v_cod_rub_economico  pr_cta_prestamos.cod_rub_economico%TYPE;
  v_msj_error          VARCHAR2(4000);
  v_cod_error          NUMBER(3) DEFAULT 0;
BEGIN
  g_msj_error := ' ';
  g_cod_error := 0;
  IF nvl(g_cod_error, '000') = '000' THEN
    IF p_nro_cuenta is null THEN
      g_lugar     := 'Validamos el nro. cuenta no sea nulo.';
      g_cod_error := '002';
      g_msj_error := 'Debe de ingresar un nro. de cuenta';
    END IF;
  END IF;
  --
  IF nvl(g_cod_error, '000') = '000' THEN
    BEGIN
      SELECT p.monto, p.can_cuotas, p.nro_solicitud, p.cod_rub_economico
        INTO v_mto_prestamos,
             v_can_cuota,
             v_nro_solicitud,
             v_cod_rub_economico
        FROM pr_cta_prestamos p
       WHERE p.nro_cuenta = p_nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        --DA-5357-22032022
        SELECT p.monto,
               p.nro_solicitud,
               p.cod_rub_economico,
               p.tot_prestamo + p.mto_interes
          INTO v_mto_prestamos,
               v_nro_solicitud,
               v_cod_rub_economico,
               p_monto_total
          FROM pr_solicitudes p
         WHERE p.nro_solicitud = p_nro_cuenta;

        select count(*)
          into v_can_cuota
          from pr_sol_cuotas t
         where t.nro_solicitud = p_nro_cuenta
           and t.nro_cuota > 0;

      WHEN OTHERS THEN
        g_lugar     := 'Obtenemos datos del prestamo';
        g_cod_error := '003';
        g_msj_error := 'Error. Al obtener datos del prestamo ' || SQLERRM;
    END;
    --DA-6436
    IF p_monto_total IS NULL THEN
      BEGIN
        SELECT sum(nvl(cu.mto_capital, 0) + nvl(cu.mto_interes, 0) +
                   nvl(cu.mto_int_documentado, 0))
          INTO p_monto_total
          FROM pr_cuotas cu
         WHERE cu.nro_cuenta = p_nro_cuenta;
        IF p_monto_total = 0 THEN
          p_monto_total := v_mto_prestamos;
        END IF;
      END;
    END IF;
  END IF;
  --
  IF nvl(g_cod_error, '000') = '000' THEN
    BEGIN
      SELECT a.fec_pri_vencimiento, a.descripcion
        INTO v_fec_pri_vto, v_nom_prestamos
        FROM pr_solicitudes a
       WHERE a.nro_solicitud = v_nro_solicitud;
    EXCEPTION
      WHEN OTHERS THEN
        g_lugar     := 'Obtenemos datos de la solicitud';
        g_cod_error := '004';
        g_msj_error := 'Error. Al obtener datos de la solicitud ' ||
                       SQLERRM;
    END;
  END IF;
  --
  IF nvl(g_cod_error, '000') = '000' THEN
    BEGIN
      SELECT (sc.mto_capital + sc.val_interes)
        INTO v_mto_cuota
        FROM pr_sol_cuotas sc
       WHERE sc.nro_solicitud = v_nro_solicitud
         AND sc.nro_cuota = 1;
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '005';
        g_lugar     := 'Obtiene Cuota ';
        g_msj_error := 'Error al buscar cuota de la solicitud ' || SQLERRM;
    END;
  END IF;
  --
  IF nvl(g_cod_error, '000') = '000' THEN
    BEGIN
      SELECT (sc.monto)
        INTO v_gas_administrativo
        FROM pr_sol_cargos sc
       WHERE sc.nro_solicitud = v_nro_solicitud
         AND sc.cod_transaccion = 704;
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '006';
        g_lugar     := 'Obtiene Gastos Administrativo ';
        g_msj_error := 'Error al buscar cargo de la solicitud ' || SQLERRM;
    END;
  END IF;
  --
  IF nvl(g_cod_error, '000') = '000' THEN
    BEGIN
      SELECT sum(sc.monto)
        INTO v_gas_seguro
        FROM pr_sol_cargos sc
       WHERE sc.nro_solicitud = v_nro_solicitud
         AND sc.cod_ent_seguro is not null;
    EXCEPTION
      WHEN OTHERS THEN
        g_cod_error := '006';
        g_lugar     := 'Obtiene Gastos Administrativo ';
        g_msj_error := 'Error al buscar cargo de la solicitud ' || SQLERRM;
    END;
  END IF;
  --
  PAS_BCP.PR_OBT_TAS_PRESTAMO(V_NRO_SOLICITUD, NULL, v_tae, v_tan);
  --
  IF nvl(g_cod_error, '000') = '000' THEN
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

    select min(m.FECHA)
      into p_fec_desembolso
      from gv_movimientos m
     where m.nro_cuenta = p_nro_cuenta;

    --DA-6436
    p_destino := fug_obt_paradicional(p_nro_cuenta, 'ALIAS_CTA');

  ELSE
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    g_lugar     := 'Proceso de obtencion datos del credito desembolsado.';
    g_cod_error := '001';
    g_msj_error := 'Error al obtener los datos del credito ' || SQLERRM;
    p_cod_error := g_cod_error;
    p_msj_error := g_msj_error;
END;
/

