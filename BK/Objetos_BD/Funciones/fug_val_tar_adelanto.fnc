create or replace function it.fug_val_tar_adelanto(p_nro_tarjeta ta_tarjetas.nro_tarjeta%type,
                                                p_monto       ge_movimientos.monto%type,
                                                p_plazo       NUMBER)
  return varchar2 is
  
  v_nom_embozar   ta_tarjetas.nom_embozar%type;
  v_nro_cuenta    ge_cuentas.nro_cuenta%type;
  v_cod_modalidad ta_cta_tarjetas.cod_modalidad%type;
  v_afinidad      ta_cta_tarjetas.afinidad%type;
  --v_sal_disponible   ta_cta_tarjetas.sal_facturado%type;
  v_lin_credito      ta_cta_tarjetas.lin_credito%type;
  v_tas_financiacion ta_cta_tarjetas.tas_financiacion%type;
  v_cod_moneda       ta_cta_tarjetas.cod_moneda%type;
  v_cod_oficina      ta_cta_tarjetas.cod_oficina%type;
  v_nro_tarjeta      ta_tarjetas.nro_tarjeta%type;
  v_max_plazo        number;
  v_error            varchar2(200) := 'N';
  v_salir exception;
  v_cod_modulo       ba_modulos.cod_modulo%type;
  v_por_adelanto     number(5,2);

  --Retorna el Monto Total Disponible para Adelanto.
  function lf_obt_lin_credito(p_nro_cuenta in ta_cta_tarjetas.nro_cuenta%type)
    return number is
    v_sal_disponible  ta_cta_tarjetas.lin_credito%type;
    v_lin_adelanto    ta_cta_tarjetas.lin_credito%type;
    v_deuda_adelanto  ta_cta_tarjetas.lin_credito%type;
    v_deuda_adelanto2 ta_cta_tarjetas.lin_credito%type;
    v_disp_adelanto   ta_cta_tarjetas.lin_credito%type;

  begin
  
    select   nvl(lin_credito, 0) -
             (nvl(t.sal_facturar, 0) + nvl(t.sal_financiado, 0) +
             nvl(t.sal_facturado, 0) + nvl(t.sal_cuo_pendientes, 0)), -- as sal_disponible,
           (t.lin_credito * /*0.3*/v_por_adelanto), -- lin_adelanto,
           nvl((select sum(nvl(a.monto, 0))  -- DYDMR-1585 - SC 13313 -- CN: 11/02/2015
                 from ta_movimientos_his a
                where a.cod_transaccion in (251, 1251, 5154)
                  and a.reversado = 'N'
                  and a.nro_secuencia = 1
                  and a.fecha between t.fec_ult_cierre and
                      t.fec_vct_ult_cierre
                  and a.nro_cuenta = t.nro_cuenta),
               0), -- deuda_adelanto,
           nvl((select sum(nvl(a.monto, 0)) -- DYDMR-1585 - SC 13313 -- CN: 11/02/2015
                 from ge_movimientos a
                where a.cod_transaccion in (251, 1251, 5154)
                  and a.reversado = 'N'
                  and a.nro_secuencia = 1
                  and a.nro_cuenta = t.nro_cuenta),
               0), -- deuda_adelanto2,
          nvl(((t.lin_credito * /*0.3*/ v_por_adelanto) -
             nvl((select sum(nvl(a.monto, 0))
                    from ta_movimientos_his a
                   where a.cod_transaccion in (251, 1251, 5154)
                     and a.nro_secuencia = 1
                     and a.fecha between t.fec_ult_cierre and
                         t.fec_vct_ult_cierre
                     and a.nro_cuenta = t.nro_cuenta),
                  0)) - nvl((select sum(nvl(a.monto, 0)) as monto_m
                              from ge_movimientos a
                             where a.cod_transaccion in (251, 1251, 5154)
                               and a.reversado = 'N'
                               and a.nro_secuencia = 1
                               and a.nro_cuenta = t.nro_cuenta),
                            0),
             0) - nvl((select sum(nvl(a.monto, 0)) as monto_m
                              from ge_movimientos_noc a
                             where a.cod_transaccion in (251, 1251, 5154)
                               and a.reversado = 'N'
                               and a.nro_secuencia = 1
                               and a.nro_cuenta = t.nro_cuenta),
                            0)  as disponible_adelanto --disponible_adelanto,
      into v_sal_disponible,
           v_lin_adelanto,
           v_deuda_adelanto,
           v_deuda_adelanto2,
           v_disp_adelanto
      from ta_cta_tarjetas t
     where t.nro_cuenta = p_nro_cuenta;

    return nvl(v_disp_adelanto, 0);

  end lf_obt_lin_credito;
  --
  -- Función para validar tarjetas para la acreditación de adelantos--
  --
begin

  --Obtener las tarjetas de ta_tarjetas con las condiciones de vigente = 'S' y cod_estado = 6
  --El saldo disponible se calcula desde ta_cta_tarjetas
  begin
    select b.nom_embozar,
           a.nro_cuenta,
           a.cod_modalidad,
           a.afinidad,
           nvl(a.lin_credito, 0) /*-
          (nvl(a.sal_facturar, 0) + nvl(a.sal_financiado, 0) +
           nvl(a.sal_facturado, 0) + nvl(a.sal_cuo_pendientes, 0))*/, --12/08/2014
           tas_financiacion,
           a.cod_moneda,
           a.cod_oficina,
           a.cod_modulo,
           a.cod_modalidad
      into v_nom_embozar,
           v_nro_cuenta,
           v_cod_modalidad,
           v_afinidad,
           v_lin_credito, --v_sal_disponible, 12/08/2014
           v_tas_financiacion,
           v_cod_moneda,
           v_cod_oficina,
           v_cod_modulo,
           v_cod_modalidad
      from ta_cta_tarjetas a, ta_tarjetas b
     where a.nro_cuenta = b.nro_cuenta
       and b.nro_tarjeta = p_nro_tarjeta
       and b.vigente = 'S'
       and b.cod_estado = 6; --sólo activas
  exception
    when no_data_found then
      -- 1
      v_error := 'S-Tarjeta Inexistente o con Estado Inválido';
      raise v_salir;
    when others then
      -- 2  || sqlerrm.
      v_error := 'S-Número de Tarjeta Inexistente.';
      raise v_salir;
  end;

  /*Las modalidades activas para el producto: 51,52,53,54,56,57,59*/
  -- Verificar parámetro para la Modalidad.
  if nvl(fug_obt_pardinamico('TCR_MAD_ADE_EFECTIVO', 5, v_cod_modalidad),
         'N') != 'S' then
    -- 3
    v_error := 'S-Modalidad de la Tarjeta no permite esta Operación.';
    raise v_salir;
  end if;

  --Validar que la moneda sea siempre local, la operacion es solo para GS
  If v_cod_moneda <> pag_gen.fu_obt_mon_local then
    -- 4
    v_error := 'S-Operación no permitida. La moneda debe ser GS.';
    raise v_salir;
  End if;

  begin
    --  Solo puede realizar la operacion el titular de la tarjeta (PRINCIPAL)
    select tar.nro_tarjeta
      into v_nro_tarjeta
      from ge_cta_clientes cli, ta_tarjetas tar
     where cli.nro_cuenta = tar.nro_cuenta
       and relacion = 'P'
       and tar.vigente = 'S'
       and tar.cod_estado = 6 --sólo activas
       and tar.nro_cuenta = v_nro_cuenta
       and rownum = 1;
  exception
    when no_data_found then
      -- 5
      v_error := 'S-Sólo el titutar de la cuenta puede realizar esta operación.';
      raise v_salir;
  end;

  /*El Monto debe ser Mayor 0.
  El saldo disponible para adelandos es Sal disponible * 1.1*/
  if p_monto <= 0 then
    -- 6
    v_error := 'S-El Monto debe ser Mayor que 0.';
    raise v_salir;
  end if;

  --if p_monto > (v_lin_credito * 1.1) then
  -- saldo disponible mas 10%  --SALDO DISPONIBLE PARA ADELANTOS -- HASTA 12/08/2014 EGC.
  -- DEBE SER EL 30% DE LA LINEA DE CREDITO. --DESDE 12/08/2014 EGC
  -- Obtenemos el porcentaje acorde a la parametrización del nuevo parámetro dinámico POR_ADE_TARJETA
  --15/07/2015 WA ajuste para que sea parametrizable
  v_por_adelanto:= 0;
  v_por_adelanto:= nvl(fug_obt_pardinamico('POR_ADE_TARJETA',
                                     5,
                                     v_cod_modalidad),0); 
  if v_por_adelanto <> 0 then
     --Convertimos a porcentaje
     v_por_adelanto:= v_por_adelanto /100;
  end if;

  v_lin_credito := lf_obt_lin_credito(v_nro_cuenta);
--  if p_monto > (v_lin_credito * 0.3) then
  if p_monto > v_lin_credito then
    -- 7
    v_error := 'S-Monto supera al Saldo Disponible.';
    raise v_salir;
  end if;

  --Los plazos estan limitados por modalidad
  if p_plazo is null or p_plazo <= 0 then
    -- 8
    v_error := 'S-Plazo debe ser mayor que 0.';
    raise v_salir;
  end if;
  v_max_plazo := fug_obt_pardinamico('TCR_PLA_MAX_ADELANTO',
                                     5,
                                     v_cod_modalidad);
  if p_plazo > v_max_plazo then
    -- 9
    v_error := 'S-Plazo supera el máximo permitido para esta Modalidad.';
    raise v_salir;
  end if;

  return v_error;

exception
  when v_salir then
    return v_error;
end;
/

