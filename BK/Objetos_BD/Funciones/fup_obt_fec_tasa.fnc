CREATE OR REPLACE FUNCTION IT.FUP_OBT_FEC_TASA (P_COD_TRA_PADRE IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                             P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                             P_FEC_INICIO PR_CTA_PRESTAMOS.FEC_INICIO%TYPE,
                                             P_FECHA DATE,
                                             P_NRO_SOLICITUD PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE,
                                             P_MTO_INT_DESCONTADO PR_CUOTAS.SAL_INTERES%TYPE DEFAULT NULL)
  return date is
  v_iva_desglose varchar2(1);
  v_fec_tasa date;
begin

  v_fec_tasa := p_fecha;

  if (p_cod_tra_padre in (359, 362) or
      p_cod_tra_padre = 360 and nvl(p_mto_int_descontado,0) > 0) and --DYDMR-944
     (p_cod_transaccion in (709, 1708) and
      p_fec_inicio < to_date('01/05/2014', 'dd/mm/yyyy')) then

       select decode(nvl(count(*),0),0,'N','S')
         into v_iva_desglose
         from pr_solicitudes x
        where nro_solicitud = p_nro_solicitud
          and x.iva_desglose = 'S';
          
      --Control cuando no tiene la Transaccion de Impuesto--
      if nvl(v_iva_desglose,'N') = 'N' then
           select decode(nvl(count(*),0),0,'S','N')  -- la variable iva desglose indica que el iva es cuotizado
             into v_iva_desglose
             from pr_sol_cargos x
            where nro_solicitud = p_nro_solicitud
              and x.cod_transaccion = 709;     
      end if;     

      if nvl(v_iva_desglose,'N') = 'N' then
         v_fec_tasa := p_fec_inicio;
      else
         v_fec_tasa := p_fecha;
      end if;
  end if;

  return v_fec_tasa;

exception
  when no_data_found then
    return null;
  when others then
    return null;
end FUP_OBT_FEC_TASA;
/

