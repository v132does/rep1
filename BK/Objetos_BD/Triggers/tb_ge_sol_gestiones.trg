CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_GESTIONES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_SOL_GESTIONES
 FOR EACH ROW

declare

FUNCTION FL_OBT_ANT_SEGUNDO
 (P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 )
 RETURN VARCHAR2
 IS

V_HORA VARCHAR2(2);
V_MINUTO VARCHAR2(2);
V_SEGUNDO VARCHAR2(2);
BEGIN
      V_HORA    := SUBSTR(P_HORA,1,2);
      V_MINUTO  := SUBSTR(P_HORA,4,2);
      V_SEGUNDO := SUBSTR(P_HORA,7,2);

      V_SEGUNDO := TO_NUMBER(V_SEGUNDO) - 1;
      IF TO_NUMBER(V_SEGUNDO) < 0 THEN
         V_SEGUNDO := 59;
         V_MINUTO := TO_NUMBER(V_MINUTO) - 1;
         IF TO_NUMBER(V_MINUTO) < 0 THEN
            V_MINUTO := 59;
            V_HORA := TO_NUMBER(V_HORA) - 1;
            IF TO_NUMBER(V_HORA) < 0 THEN
               V_HORA := 23;
            END IF;
         END IF;
      END IF;
     -- retorna el siguiente segundo a la hora dada ----------
     RETURN  LPAD(V_HORA,2,'0')||':'||LPAD(V_MINUTO,2,'0')||':'||LPAD(V_SEGUNDO,2,'0');
     ---------------------------------------------------------
END;

begin
   /*if inserting or updating then
      --- Modificado a pedido de Olga Gonzalez 2/01/2004
      --- porque la historia debe traer segun la fecha y hora
      --- de la base
      :new.fecha := sysdate;
   end if;*/
   if inserting then
      :new.fecha := sysdate;
   elsif updating then --para que no queden registrados 2estados en la misma hora
     --- :new.fecha := to_date(to_char(sysdate,'DDMMYYYY')||fl_obt_ant_segundo(to_char(sysdate, 'HH24:MI:SS')),'DDMMYYYY HH24:MI:SS');
     --- Cambiado a siguiente segundo por ICL 24/04/2008 porque los estados se graban en secuencia y para el segundo registro
     --- que graba si es la misma hora le pone el segundo anterior cuando deberia ser el siguiente en base a la secuencia de estados
     ---new.fecha := to_date(to_char(sysdate,'DDMMYYYY')||pag_gen.FU_OBT_SIG_SEGUNDO(to_char(sysdate, 'HH24:MI:SS')),'DDMMYYYY HH24:MI:SS');
     null; --- Finalmente anule porque arma desastre En Brios no tienen!!!
   end if;
end;
/

