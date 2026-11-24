CREATE OR REPLACE FUNCTION IT.fut_obt_cuota(p_monto IN NUMBER,
                                         p_plazo IN NUMBER) RETURN NUMBER IS
  /* Devuelve el importe de las cuotas para el monto y plazo ingresados  */
  v_tas_diaria       number;
  v_val_tasa         number;
  v_capital          number default p_monto;
  v_cuota            number;
  v_amortizacion     number default 0;
  v_interes          number;
  v_iva5             number;
  v_cuo_apagar       number default 0;
  v_promedio         number;
  v_plazo            number default p_plazo;
  v_por_financiacion number;

  v_cal_tas                 number default 0;
  v_val_tasa_1              number default 0;
  v_cal_tas_v_val_tasa_1    number default 0;
BEGIN
  BEGIN 
    select to_number(REPLACE(abreviatura,',','.'), '999D00', 'nls_numeric_characters=''. ''')-- DYDMR-3538
      into v_por_financiacion
      from ba_cod_referencias
     where dominio = 'POR_FIN_CRE_TARJETA'
       and p_plazo between val_minimo and val_maximo;
  EXCEPTION
    when no_data_found then
      raise_application_error(-20000,
                              'No fue registrado el Porcentaje de Financiación para el Plazo ingresado!');
  END;
  v_tas_diaria                := ((30 * v_por_financiacion) / 36500); 
  v_val_tasa                  := power(1 + v_tas_diaria, v_plazo);    
  v_cal_tas                   := v_tas_diaria * v_val_tasa;           
  v_val_tasa_1                := v_val_tasa -1;                       
  v_cal_tas_v_val_tasa_1      := v_cal_tas / v_val_tasa_1;            
  v_cuota                     := v_capital * v_cal_tas_v_val_tasa_1;  

  v_promedio := round(v_cuota);
  return(v_promedio);
END;
/

