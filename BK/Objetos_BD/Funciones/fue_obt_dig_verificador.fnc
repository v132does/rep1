CREATE OR REPLACE FUNCTION IT.fue_obt_dig_verificador(p_nro IN VARCHAR2)
  RETURN NUMBER IS
  v_lon NUMBER(5)  := length(p_nro);
  v_sec NUMBER(5)  := 2;
  v_sum NUMBER(10) := 0;
  v_dv  NUMBER(2);
BEGIN
   /*
   || Cálculo para obener el Dígito Verificar a partir del nro. de cédula
   || ===================================================================
   || El que utiliza hacienda, es el algoritmo del "Modulo 11"
   || ========================================================
   || Conforme al esquema de abajo, cada dígito del número, comenzando de la derecha para la izquierda
   || (menos significativo para el más significativo) es multiplicado, en orden,
   || por 2, después 3, después 4 y así sucesivamente, hasta el límite de multiplicación escogido.
   || Entonces nuevamente se multiplica el número por 2, 3, etc.
   || Número ejemplo: 261533-9
   ||   +---+---+---+---+---+---+   +---+
   ||   | 2 | 6 | 1 | 5 | 3 | 3 | - | 9 |
   ||   +---+---+---+---+---+---+   +---+
   ||     |   |   |   |   |   |
   ||    x7  x6  x5  x4  x3  x2
   ||     |   |   |   |   |   |
   ||   =14 =36  =5 =20  =9  =6
   ||     +---+---+---+---+---+-> = (90 x 10) / 11 = 81, resto 9 => DV = 9
   || La sumatória de esas multiplicaciones es multiplicada por 10 y dividida por 11.
   || El resto de esta división (módulo 11) es el dígito verificador.
   || En la rutina patrón, sólo el dígito menos significativo es utilizado.
   || */
  FOR i IN REVERSE 1..v_lon LOOP
    v_sum := v_sum + (to_number(substr(p_nro, i, 1)) * v_sec);
    v_sec := v_sec + 1;
  END LOOP;

  v_dv := 11 - MOD(v_sum, 11);
  IF v_dv >= 10 THEN
    v_dv := 0;
  END IF;

  RETURN(v_dv);
EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;
/

