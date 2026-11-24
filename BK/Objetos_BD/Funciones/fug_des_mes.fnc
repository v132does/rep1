CREATE OR REPLACE FUNCTION IT.FUG_DES_MES
 (P_FECHA IN DATE
 )
 RETURN VARCHAR
 IS

V_MES VARCHAR(25);
V_DIA NUMBER(2);
V_ANO VARCHAR2(4);
V_NUM_MES NUMERIC(2);
V_DESCRIPCION VARCHAR2(60);
BEGIN
   IF P_FECHA IS NOT NULL THEN
      V_DIA := to_number(to_char(P_FECHA,'DD'));
      V_NUM_MES:= to_number(to_char(P_FECHA,'MM'));
      V_ANO := to_number(to_char(P_FECHA,'YYYY'));



        IF V_NUM_MES = 1 THEN V_MES := 'Enero';
        ELSIF V_NUM_MES = 2 THEN V_MES := 'Febrero';
        ELSIF V_NUM_MES = 3 THEN V_MES := 'Marzo';
        ELSIF V_NUM_MES = 4 THEN V_MES := 'Abril';
        ELSIF V_NUM_MES = 5 THEN V_MES := 'Mayo';
        ELSIF V_NUM_MES = 6 THEN V_MES := 'Junio';
        ELSIF V_NUM_MES = 7 THEN V_MES := 'Julio';
        ELSIF V_NUM_MES = 8 THEN V_MES := 'Agosto';
        ELSIF V_NUM_MES = 9 THEN V_MES := 'Septiembre';
        ELSIF V_NUM_MES = 10 THEN V_MES := 'Octubre';
        ELSIF V_NUM_MES = 11 THEN V_MES := 'Noviembre';
        ELSIF V_NUM_MES = 12 THEN V_MES := 'Diciembre';
        END IF;
      V_DESCRIPCION := V_MES;
      RETURN V_DESCRIPCION;
    END IF;
    return null;
END;
/

