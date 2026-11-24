CREATE OR REPLACE FUNCTION IT.FUX_VER_TIP_PRESTAMO
 (p_nro_cuenta IN ge_cuentas.nro_cuenta%type)
 RETURN VARCHAR2
 IS
  --función que verifica de qué tipo de RRR puede crear la solicitud de préstamo
  --dependiendo de las condiciones de la cuenta de comex cci, cce o cobranzas

  --- Permite realizar las validaciones de la deuda a renovar, refinanciar o reestructurar
  --- en base a la definicion de la Resolución:
  --- RENOVACION (N): Renovar operación con ausencia de mora de capital e interés y por lo tanto
  --- no modifique la clasificación del crédito.
  --- REFINANCIACION (R) O RESTRUCTURACION (E): Podrán mejorar la clasificación del crédito, siempre
  --- que cumplan con el Art. 54 inc. d) de la Ley 861 de Bancos y Financieras del 24/06/1996
  --- y las condiciones siguientes:
  --- a) La refinanciación o reestructuración se realice como resultado de una nueva evaluación
  --- de crédito, considerando la viabilidad del negocio del prestatario y su capacidad de pago
  --- según el flujo operativo de la empresa.
  --- b) El valor presente estimado con la tasa de interés de la deuda refinanciada o reestructurada
  --- de los pagos futuros estipulados sea igual o superior al estimado de la deuda original;
  --- es decir, que exista alivio financiero para la entidad deudora mediante, o por lo menos, una
  --- significativa reducción de la tasa de interés que mejore las probabilidades de repago;
  --- c) Los planes de reestructuración de las operaciones del deudor aseguren prudentemente su
  --- viabilidad futura.
  v_sal_capital pr_cta_prestamos.sal_capital%type;
  v_dev_no_cobrado pr_cta_prestamos.dev_no_cobrado%type;
  v_mto_pagado pr_cobros.mto_capital%type;
  v_dia_atraso pr_cta_prestamos.dia_atraso%type;
  v_cod_modalidad cx_cta_importaciones.cod_modalidad%type;
  v_cod_moneda    cx_cta_importaciones.cod_moneda%type;
  v_cod_oficina   cx_cta_importaciones.cod_oficina%type;
  v_fec_vencimiento cx_cta_importaciones.fec_vencimiento%type;
  v_saldo           cx_cta_importaciones.saldo%type;
  v_monto           cx_cta_importaciones.monto%type;
  v_dia_par_atraso pr_cta_prestamos.dia_atraso%type :=0;
  v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(8);
  v_tip_renovacion varchar2(1) := 'N';
BEGIN

  select cod_modalidad, cod_moneda, cod_oficina, fec_vencimiento, saldo, monto
   into v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_fec_vencimiento, v_saldo, v_monto
   from cx_cta_importaciones
  where nro_cuenta = p_nro_cuenta;

  v_dia_par_atraso := fug_obt_pardinamico('DIA_MOR_RRR',8, v_cod_modalidad, v_cod_moneda, v_cod_oficina);
  if v_fecha > v_fec_vencimiento then
    v_dia_atraso :=  v_fecha - v_fec_vencimiento;
  end if;

  --verifica días de atraso
  if v_dia_atraso > v_dia_par_atraso then
   raise_application_error(-20000,'Solo puede renovar cuentas hasta con '||v_dia_par_atraso||' días de atraso');
  end if;

  /*if v_tip_renovacion = 'N' then
    --- Es una renovacion
    if nvl(:pr_cta_prestamos.mto_deuda,0) > nvl(:pr_cta_prestamos.sal_cap_ade,0)+nvl(:pr_cta_prestamos.sal_int_cob,0) then
     raise_application_error(-20000,'La cuenta posee cargos por mora, no puede renovarse');
    end if;
    if nvl(:pr_cta_prestamos.sal_int_cob,0) <> 0 then
      raise_application_error(-20000,'El interés devengado a la fecha debe ser pagado previamente');
    end if;
  elsif :ge_clientes.tip_renovacion ='R' then
    if nvl(:pr_cta_prestamos.sal_int_cob,0) <> 0 then
      raise_application_error(-20000,'El interés devengado a la fecha debe ser pagado previamente');
    end if;
   end if;*/

  --- Refinanciacion valida el 10% de pago previo
  If v_tip_renovacion = 'R' then -- Refinanciado si puede.
    if nvl(v_saldo,0) > (v_monto)*90/100 then
    	 raise_application_error(-20000,'No puede refinanciar deuda sin previo pago del 10% de la deuda');
    end if;
    /*if nvl(:pr_cta_prestamos.mto_deuda,0) > nvl(:pr_cta_prestamos.sal_cap_ade,0) then
       raise_application_error(-20000,'La cuenta posee cargos por mora e intereses no pagados, no puede refinanciar');
    end if;*/
  end if;

  return v_tip_renovacion;
exception
   when no_data_found then
      raise_application_error(-20000,'No existe la CCI '||p_nro_cuenta);
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Verif.Tipo RRR para CCI '||p_nro_cuenta||'.'||sqlerrm);
      end if;
END;
/

