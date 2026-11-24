CREATE OR REPLACE FUNCTION IT.FUL_OBT_CUR_CUPONES(p_cod_moneda in varchar,
                                               p_dia_plazo in number,
                                               p_fecha in date) RETURN NUMBER is
  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para obtener la cotizacion de:--//
  --//--Curva de Rendimiento Cupón Cero - Subasta de distintas fechas--//
  
  --Variables--
  v_fecha date;
  v_val_tasa LC_FOR_CUR_CUPONES.Val_Tasa%type;
BEGIN
  --Carga de Fecha--
  if p_fecha is null then
     v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(7);
  else
     v_fecha := p_fecha;
  end if;
  
  --Obtencion de Cotizacion--
  select x.val_tasa
    into v_val_tasa
    from LC_FOR_CUR_CUPONES x
   where x.cod_moneda = p_cod_moneda
     and x.dia_plazo = p_dia_plazo
     and x.fec_subasta = (select max(y.fec_subasta)
                            from LC_FOR_CUR_CUPONES y
                           where y.cod_moneda = p_cod_moneda
                             and y.dia_plazo = p_dia_plazo
                             and y.fec_subasta <= v_fecha);
  return v_val_tasa;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
        v_val_tasa := NULL;
        Return v_val_tasa;
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error en FUL_OBT_CUR_CUPONES - '||SQLERRM);
END;
/

