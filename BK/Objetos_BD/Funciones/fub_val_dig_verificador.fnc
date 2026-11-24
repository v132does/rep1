create or replace function it.fub_val_dig_verificador(
    p_nro_documento     in varchar2,
    p_dig_verificador   in number,
    p_cod_persona       in varchar2
) return number is
    v_dig_verificador number := fue_obt_ruc_dig_verificador(p_nro_documento);
begin
    if v_dig_verificador = -1 then
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Advertencia el digito verificador del cliente: '||p_cod_persona||' no se puede calcular en base a su documento: ' || p_nro_documento,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
        v_dig_verificador := p_dig_verificador;
    end if;
    if nvl(p_dig_verificador, -1) != v_dig_verificador then
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Advertencia el digito verificador del cliente: '||p_cod_persona||' fue modificado de: '||p_dig_verificador||' a: '||v_dig_verificador,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
    end if;
    return v_dig_verificador;
exception
    when others then
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Error al validar el digito verificador del cliente: '||p_cod_persona||'. Se utilizara el valor original: '||p_dig_verificador||'. '||sqlerrm,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
end fub_val_dig_verificador;