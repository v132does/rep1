CREATE OR REPLACE PROCEDURE IT.prb_lib_reproceso is

  v_periodo_fiscal_ini ge_calendarios.fec_actual%type;
  v_periodo_fiscal_fin ge_calendarios.fec_actual%type;

BEGIN
  BEGIN
    SELECT g.pri_dia_mes, g.ult_dia_mes
      INTO v_periodo_fiscal_ini, v_periodo_fiscal_fin
      FROM ge_calendarios g
     WHERE g.cod_modulo = 1; -- general
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al buscar fecha' || SQLERRM);
  END;

  -- seteo al mes anterior, se procesa por mes cerrado
  v_periodo_fiscal_ini := add_months(v_periodo_fiscal_ini, -1); --OJO le deje del mes
  v_periodo_fiscal_fin := add_months(v_periodo_fiscal_fin, -1); --OJO le deje del mes
  BEGIN
    UPDATE cb_lib_compras cc
       SET cc.procesado = 'N'
     WHERE cc.fec_pago BETWEEN v_periodo_fiscal_ini AND
           v_periodo_fiscal_fin
       AND cc.procesado <> 'N';
  
    UPDATE cb_lib_ventas cv
       SET cv.procesado = 'N'
     WHERE cv.fecha BETWEEN v_periodo_fiscal_ini AND v_periodo_fiscal_fin
       AND cv.procesado <> 'N';
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al cambiar estado' || SQLERRM);
  END;

EXCEPTION
  when others then
    raise_application_error(-20000, 'Error ' || SQLERRM);
  
END;
/

