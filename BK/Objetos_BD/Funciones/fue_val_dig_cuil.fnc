CREATE OR REPLACE FUNCTION IT.FUE_VAL_DIG_CUIL
 (P_NRO_DOCUMENTO IN ba_personas.NRO_DOCUMENTO%TYPE
 )
 RETURN BOOLEAN
 IS
-- rutina del dígito verificador, para verificar si es correcto el nro.
type vector is table of number(1) index by binary_integer;
--- Vectores
digito vector;

v_valor number := 0;
v_numero number;
v_resto number := 0;
BEGIN
  --asignar valores al vector
  digito(1)  := 5;
  digito(2)  := 4;
  digito(3)  := 3;
  digito(4)  := 2;
  digito(5)  := 7;
  digito(6)  := 6;
  digito(7)  := 5;
  digito(8)  := 4;
  digito(9)  := 3;
  digito(10) := 2;

  if fue_val_es_numerico(p_nro_documento) = 'S' then
    v_numero := substr(p_nro_documento,1,10);
    for i in 1..10 loop
      v_valor := v_valor + (substr(v_numero,i,1) * digito(i));
    end loop;
    --resto de dividir por 11
    v_resto := mod(v_valor,11);
    --diferencia entre 11 y el valor
    v_valor := 11 - v_resto;
    --
    if v_valor = 11 then
      v_valor := 0;
    elsif v_valor = 10 then
      v_valor := 9;
    end if;
    if v_valor <> substr(P_NRO_DOCUMENTO,-1) then
      raise_application_error(-20000,'Número de CUIL/CUIT Incorrecto. Verifique.');
    end if;
  end if;
  return true;
END;
/

