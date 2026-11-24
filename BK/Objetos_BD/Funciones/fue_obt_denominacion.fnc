CREATE OR REPLACE FUNCTION IT.FUE_OBT_DENOMINACION
 (P_NUMERO NUMBER
 )
 RETURN Varchar2
 IS

/* Pasar la denominación en palabras de los valores numéricos. */
FUNCTION LF_OBT_SUBDENOMINA
 (P_NUMERO IN VARCHAR2
 ,P_NUMINI IN NUMBER
 ,P_NUMDES IN NUMBER
 ,P_DECENA IN NUMBER
 )
 RETURN VARCHAR2;
type vector is table of varchar2(12) index by
                              binary_integer;
--- Vectores
unidad vector;
dieces vector;
decenas vector;
veintes vector;
especial vector;

 v_numero varchar2(15) := lpad(to_char(floor(p_numero)),15,'0');
 v_decimal varchar(4)  := rpad(substr(to_char(p_numero - floor(p_numero)),2,2),2, '00');
 v_numchar varchar2(3);
 v_numini number;
 v_numdes number := 5;
 v_decena number;
 v_texto varchar2(200);
 v_inicio number(2) := 1;
 v_bandera varchar2(2):='No';

/* Pasar la denominación en palabras de los valores numéricos. */
FUNCTION LF_OBT_SUBDENOMINA
 (P_NUMERO IN VARCHAR2
 ,P_NUMINI IN NUMBER
 ,P_NUMDES IN NUMBER
 ,P_DECENA IN NUMBER
 )
 RETURN VARCHAR2
 IS
v_valor number := P_DECENA;
v_chnum varchar2(20) := P_NUMERO;
v_denominacion varchar2(50);
v_deno1 varchar2(20);
Begin
----- Fin de Vectores ----
  IF v_valor > 10 AND v_valor < 20 THEN
     v_valor := v_valor - 10;
     v_denominacion := trim(dieces(v_valor));
  ELSIF v_valor >= 20 AND v_valor < 30 THEN
     v_valor := v_valor - 20;
     v_denominacion := trim(veintes(v_valor));
  ELSIF v_valor > 0 AND v_valor <= 10 THEN
     v_denominacion := trim(unidad(v_valor));
  ELSIF v_valor >= 30 AND v_valor < 100 THEN
     v_denominacion := trim(decenas(to_number(substr(v_chnum,2,1))));
     IF to_number(substr(v_chnum,3,1)) <> 0 then
        v_denominacion := trim(v_denominacion ||' y '||
                          unidad(to_number(substr(v_chnum,3,1))));
     END IF;
  END IF;

  IF P_NUMINI = 1 AND to_number(substr(P_NUMERO,2,2)) = 0 THEN
     v_deno1 := 'Cien';
  ELSIF P_NUMINI = 1 THEN
     v_deno1 := 'Ciento';
  ELSIF P_NUMINI > 1 THEN
     IF P_NUMINI = 5 THEN
         v_deno1 := trim(especial(6)); --quinientos
     ELSIF P_NUMINI = 7 THEN
         v_deno1 := trim(especial(7)); --setecientos
     ELSIF P_NUMINI = 9 THEN
         v_deno1 := trim(especial(8)); --novecientos
     ELSE
         v_deno1 := trim(unidad(P_NUMINI)||'cientos');
     END IF;
  END IF;

  IF P_NUMDES > 1 THEN
     IF P_NUMDES IN (3,5) THEN -- Para los Billones o Millones
        -- IF v_valor = 1 and p_decena != 11 AND P_NUMINI = 0 THEN     
        IF v_valor = 1 and p_decena = 1 AND P_NUMINI = 0 THEN
          v_denominacion := trim(v_deno1||' '||v_denominacion||' '||especial(P_NUMDES)||'on');
        ELSE
          v_denominacion := trim(v_deno1||' '||v_denominacion||' '||especial(P_NUMDES)||'ones');
        END IF;
     ELSE
        v_denominacion := trim(v_deno1||' '||v_denominacion||' '||especial(P_NUMDES));
     END IF ;
  ELSE
     v_denominacion := trim(v_deno1||' '||v_denominacion);
  END IF;
  RETURN v_denominacion;
END;

BEGIN
-----   Vectores     -----
unidad(1) := 'Un';
unidad(2) := 'Dos';
unidad(3) := 'Tres';
unidad(4) := 'Cuatro';
unidad(5) := 'Cinco';
unidad(6) := 'Seis';
unidad(7) := 'Siete';
unidad(8) := 'Ocho';
unidad(9) := 'Nueve';
unidad(10):= 'Diez';

dieces(01) := 'Once';
dieces(02) := 'Doce';
dieces(03) := 'Trece';
dieces(04) := 'Catorce';
dieces(05) := 'Quince';
dieces(06) := 'Dieciseis';
dieces(07) := 'Diecisiete';
dieces(08) := 'Dieciocho';
dieces(09) := 'Diecinueve';

decenas(01) := 'Diez';
decenas(02) := 'Veinte';
decenas(03) := 'Treinta';
decenas(04) := 'Cuarenta';
decenas(05) := 'Cincuenta';
decenas(06) := 'Sesenta';
decenas(07) := 'Setenta';
decenas(08) := 'Ochenta';
decenas(09) := 'Noventa';
decenas(10) := 'Cien';

veintes(00) := 'Veinte';
veintes(01) := 'Veintiun';
veintes(02) := 'Veintidos';
veintes(03) := 'Veintitres';
veintes(04) := 'Veinticuatro';
veintes(05) := 'Veinticinco';
veintes(06) := 'Veintiseis';
veintes(07) := 'Veintisiete';
veintes(08) := 'Veintiocho';
veintes(09) := 'Veintinueve';

especial(1):= 'cientos';
especial(2):= 'Mil';
especial(3):= 'Mill'; -- Millón o Millones
especial(4):= 'Mil';
especial(5):= 'Bill'; --Billón o Billones
especial(6):= 'Quinientos';
especial(7):= 'Setecientos';
especial(8):= 'Novecientos';
-- Fin Vectores



    WHILE (v_inicio <= 13) loop
      v_numchar := substr(v_numero,v_inicio,3);
      v_numini := to_number(substr(v_numero,v_inicio,1));
      v_decena := substr(v_numero,v_inicio+1,2);

      IF v_numchar <> '000' OR v_bandera = 'Ok' THEN
         IF v_numdes = 4 THEN
            v_bandera := 'Ok';
         ELSE
            v_bandera := 'No';
         END IF;
         v_texto := trim(v_texto ||' '||lf_obt_subdenomina(v_numchar,v_numini,v_numdes,v_decena));
      END IF;
      v_inicio:= v_inicio + 3;
      v_numdes := v_numdes - 1;
    END LOOP;
    IF substr(v_numchar,3,1) = '1' and substr(v_numchar,2,2) <> '11' then
       v_texto := v_texto||'o'; -- Verifica que termine con 1 para agregar la un"o".
    END IF;
    IF lpad(v_decimal,3,'0') <> '000' THEN --si hay decimales
       v_decimal := lpad(v_decimal,3,'0');
       if v_numero = 0 then
          v_texto := lf_obt_subdenomina(v_decimal,substr(v_decimal,1,1),1,to_number(substr(v_decimal,2,2)));
          IF substr(v_decimal,3,1) = '1' and substr(v_decimal,2,2) = '01' then
             v_texto := v_texto||' centavo'; -- Verifica que termine con 1 para agregar la un"o".
          ELSE
             v_texto := v_texto||' centavos'; -- Verifica que termine con 1 para agregar la un"o".
          END IF;
       else
           v_texto := v_texto ||' con '||
                      lf_obt_subdenomina(v_decimal,substr(v_decimal,1,1),1,to_number(substr(v_decimal,2,2)));
          IF substr(v_decimal,3,1) = '1' and substr(v_decimal,2,2) = '01' then
             v_texto := v_texto||' centavo'; -- Verifica que termine con 1 para agregar la un"o".
          ELSE
             v_texto := v_texto||' centavos'; -- Verifica que termine con 1 para agregar la un"o".
          END IF;
       end if;
    END IF;

    RETURN replace(upper(substr(v_texto, 1,1))||lower(substr(v_texto,2)), '  ', ' ');
 END;
/

