CREATE OR REPLACE FUNCTION IT.FUL_OBT_CUR_FORWARD(p_cod_moneda in varchar,
                                               p_dia_plazo in number,
                                               p_fecha in date default null) RETURN NUMBER is
  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para obtener la cotizacion de:--//
  --//--CURVAS FORWARD SEMANALES PROVEÍDAS POR EL BANCO CENTRAL DEL PARAGUAY(ftT)--//
  
  --Variables--
  v_fecha date;
  v_val_cotizacion ge_cotizaciones.val_conversion%type;
BEGIN
  --Carga de Fecha--
  if p_fecha is null then
     v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(7);
  else
     v_fecha := p_fecha;
  end if;
  
  --Obtencion de Cotizacion--
  select x.val_cotizacion
    into v_val_cotizacion
    from LC_FOR_CUR_FORWARD x
   where x.cod_moneda = p_cod_moneda
     and x.dia_plazo = p_dia_plazo
     and x.fec_desde = (select max(y.fec_desde)
                          from LC_FOR_CUR_FORWARD y
                         where y.cod_moneda = p_cod_moneda
                           and y.dia_plazo = p_dia_plazo
                           and y.fec_desde <= v_fecha);
  return v_val_cotizacion;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
       v_val_cotizacion := NULL;
       Return v_val_cotizacion;  
  WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'Error en FUL_OBT_CUR_COTIZACIONES - '||SQLERRM);
END;
/

