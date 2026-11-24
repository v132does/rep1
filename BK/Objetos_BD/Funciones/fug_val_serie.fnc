create or replace function it.FUG_VAL_SERIE(p_ult_nro in out NUMBER,
                                            p_serie in cb_par_comprobantes.serie%TYPE,
                                            p_nro_hasta in cb_par_comprobantes.cantidad%type,
                                            p_tip_comprobante in cb_par_comprobantes.tipo%type,
                                            p_cod_oficina in cb_par_comprobantes.cod_oficina%type,
                                            p_fecha in date,
                                            p_nro_timbrado in cb_par_comprobantes.nro_timbrado%type) return varchar2 IS
--Proyecto: Facturación Electrónica
--Función que valida y devuelve la Serie del timbrado correspondiente al circuito de Facturación Electrónica
--dependiendo del último número de factura emitido
--Adaptada a la definición de la pagina 59 del Manual Técinco e-Kuatia v.150 del 10_09_2019
--por mmelgarejo 06/09/2022

v_serie1 varchar2(1);--Primera letra de la SERIE
v_serie2 varchar2(1);--Segunda letra de la SERIE
v_val_ascii_serie1 number(2);--Valor ASCII de la primera letra de la SERIE
v_val_ascii_serie2 number(2);--Valor ASCII de la segunda letra de la SERIE
v_val_maximo_serie number(2);--Valor máximo ASCII del abecedario
v_val_minimo_serie number(2);--Valor mínimo ASCII del abecedario
v_serie cb_par_comprobantes.serie%TYPE;
BEGIN
  v_serie := p_serie;
  v_serie1 := substr(p_serie,1,1);--Substraer la primera letra de la serie
  v_serie2 := substr(p_serie,2);--Substraer la segunda letra de la serie
  select ASCII(v_serie1) into v_val_ascii_serie1 from dual;--Valor ASCII de la primera letra de la serie
  select ASCII(v_serie2) into v_val_ascii_serie2 from dual;--Valor ASCII de la segunda letra de la serie
  select ASCII('Z') into v_val_maximo_serie from dual;--Con esto obtenemos el máximo valor ASCII posible del abecedario
  select ASCII('A') into v_val_minimo_serie from dual;--Con esto obtenemos el minimo valor ASCII posible del abecedario
  if p_ult_nro > p_nro_hasta then
    --Si el número actual es mayor o igual al número 'hasta', debemos validar la segunda letra de la serie
    if v_val_ascii_serie2 = v_val_maximo_serie then--Si la 2da letra es Z, entonces validar la 1ra letra
      if v_val_ascii_serie1 = v_val_maximo_serie then--Si la 1ra letra es Z, entonces la serie del timbrado terminó
        raise_application_error(-20000,
                                'Serie del timbrado ' || p_nro_timbrado ||
                                 ' finalizada. Comprobante ' || p_tip_comprobante ||
                                 ' Oficina ' || p_cod_oficina || ' Fecha ' ||
                                 to_char(p_fecha, 'DD/MM/YYYY'));
      else--Si la 1ra letra no es Z, entonces
        v_serie2 := 'A';--Asignar a la 2da letra A, para empezar el ciclo nuevamente
        select CHR(v_val_ascii_serie1 + 1) into v_serie1 from dual;--y a la 1ra letra, sumar 1 unidad a su valor ASCII para obtener la sgte letra del abecedario
        v_serie := v_serie1||v_serie2;
        p_ult_nro := 1;
      end if;
    else--Si la 2da letra no es Z, entonces
      select CHR(v_val_ascii_serie2 + 1) into v_serie2 from dual;--a la 2da letra, sumar 1 unidad a su valor ASCII para obtener la sgte letra del abecedario
      v_serie := v_serie1||v_serie2;
      p_ult_nro := 1;
    end if;
  end if;
  return v_serie;
END;
/

