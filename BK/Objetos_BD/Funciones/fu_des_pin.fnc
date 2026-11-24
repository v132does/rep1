CREATE OR REPLACE FUNCTION IT.FU_DES_PIN
 (P_CLAVE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
Cad      CHAR(15) := '39z06x8w74y25v1';
Sec      CHAR(10) := '2804697513';
Letra    char(01);
S_Letra  varchar2(02);
CadFinal varchar(10);
LCad     number(02);
I        number(02);
J        number(02);
V_Letra  number(2);
V_Secue  number(2);
Valor    number(2);
Lon      number(2):= 1;
A1       number(2);
VsLetra  number(2);
v_pos_ini number(2);
BEGIN
   CadFinal := null;
   LCad := LENGTH(Cad);
   I    := LENGTH(Sec);
   J    := LENGTH(p_clave);
   IF J < I + 1  THEN
      I := (i - j) + 1;
   ELSE
      A1 := MOD(J,I);
      I := (I - A1)+1;
      IF I > LENGTH(Sec) THEN
         I := 1;
      END IF;
   END IF;
   LOOP
      Letra := SUBSTR(p_clave,Lon,1);        -- Ubicar Letra
      V_Letra := INSTR(Cad,Letra);           -- Valor de la letra
      V_secue := TO_NUMBER(SUBSTR(Sec,i,1)); -- Numero en la secuencia
      IF Lon = j THEN
        VsLetra := 3;
      ELSE
        S_Letra := SUBSTR(p_clave, lon+1,1);  -- sgte. letra
        VsLetra := INSTR(Cad, S_Letra);       -- valor sgte. letra
      END IF;
      Valor := V_Letra - (VsLetra + V_Secue -1);  --obtener nuevo valor
      IF Valor = 0 THEN
        Valor := LCad;
      ELSE
         LOOP
            EXIT WHEN Valor >= 1;
            Valor := Valor + LCad;
        END LOOP;
      END IF;
      IF CadFinal IS NULL THEN
         CadFinal  := SUBSTR(Cad, Valor,1);
      ELSE
         CadFinal  := CadFinal||SUBSTR(Cad, Valor,1)  ;
      END IF;
      Lon := Lon + 1;
      I := I + 1;
      IF I > LENGTH(Sec) THEN
         I := 1;
      END IF;
      EXIT WHEN Lon >= J+1;
   END LOOP;
   v_pos_ini := substr(CadFinal,1,1);
   CadFinal := substr(CadFinal,v_pos_ini+2);
   RETURN CadFinal;
END;
/

