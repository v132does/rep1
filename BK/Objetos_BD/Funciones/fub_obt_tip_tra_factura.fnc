create or replace function it.fub_obt_tip_tra_factura(
    p_nro_factura     in varchar2,
    p_fecha           in date,
    p_nro_timbrado    in number,
    p_tip_comprobante in varchar2
) return number as
    v_cnt_cab       number;
    v_cod_modalidad number;
begin
    select count(*),
           max(case when b.cod_modulo = 7 then b.cod_modalidad end)
      into v_cnt_cab, v_cod_modalidad
      from cb_lib_ventas a
      left join cb_lib_ventas_det b
        on b.nro_factura     = a.nro_factura
       and b.fecha           = a.fecha
       and b.nro_timbrado    = a.nro_timbrado
       and b.tip_comprobante = a.tip_comprobante
       and b.cod_modulo      = 7
     where a.nro_factura     = p_nro_factura
       and a.fecha           = p_fecha
       and a.nro_timbrado    = p_nro_timbrado
       and a.tip_comprobante = p_tip_comprobante;

    if v_cnt_cab = 0 then
        PRG_INS_LOG_PROGRAMAS(
            p_cod_programa => 'FUB_OBT_TIP_TRA_FACTURA',
            p_det_error    => 'Factura inexistente',
            p_cod_persona  => null,
            p_nro_cuenta   => null
        );
        return null;
    end if;

    if v_cod_modalidad is null then
        return 2; -- Prestacion de servicios
    end if;

    case v_cod_modalidad
        when 71 then return 6; -- Compra de divisas
        when 72 then return 5; -- Venta de divisas
        else return 2;         -- Prestacion de servicios
    end case;
exception
    when others then
        PRG_INS_LOG_PROGRAMAS(
            p_cod_programa => 'FUB_OBT_TIP_TRA_FACTURA',
            p_det_error    => sqlerrm,
            p_cod_persona  => null,
            p_nro_cuenta   => null
        );
        return null;
end;