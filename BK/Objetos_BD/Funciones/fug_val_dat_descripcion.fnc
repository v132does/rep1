CREATE OR REPLACE FUNCTION IT.fug_val_dat_descripcion(p_cadena IN VARCHAR2)
   RETURN VARCHAR2 IS
   v_lon_cadena NUMBER(8);
   v_car        VARCHAR2(1);
   v_rep        VARCHAR2(1);
   v_cuenta     NUMBER(8) := 0;
   v_busqueda   NUMBER(8) := 0;
   v_cadena     ba_programas.des_detallada%TYPE := p_cadena;
   v_cont         NUMBER(8) := 0;
   v_ant_car      VARCHAR2(1);
BEGIN
   v_lon_cadena := length(v_cadena);
   IF v_lon_cadena < 10 THEN
      RAISE_APPLICATION_ERROR(-20000,
                              'Cadena introducida no alcanza los diez caracteres.');
   RETURN 'N';
   ELSIF instr(v_cadena, ' ', 1) = 0 THEN
      RAISE_APPLICATION_ERROR(-20001,
                              'Cadena introducida tiene una sola palabra, no es valida.');
      RETURN 'N';
   ELSE
      FOR i IN 1 .. v_lon_cadena LOOP
        -- v_cuenta := v_cuenta +1;
         v_car := substr(v_cadena, i, 1);
      
         IF v_car = v_ant_car THEN
           v_cont := v_cont + 1;
            IF v_cont >= 4 THEN
                RAISE_APPLICATION_ERROR(-20002,
                              'Cadena introducida no es válida por tener demasiados caracteres semejantes.');
                  RETURN 'N';
            END IF;
          ELSE
            v_cont := 0;
          END IF;
             v_ant_car := v_car;  
         
         /*v_busqueda := i + 1;
         IF v_car <> ' ' THEN
            FOR j IN v_busqueda..v_lon_cadena LOOP
               v_rep := substr(v_cadena, j, 1);
               IF v_car = v_rep THEN
                  v_cuenta := v_cuenta + 1;
               END IF;
               IF v_cuenta > 4 THEN
                  RAISE_APPLICATION_ERROR(-20002,
                              'Cadena introducida no es válida por tener demasiados caracteres semejantes.');
                  RETURN 'N';
               END IF;
            END LOOP;
            v_cadena := REPLACE(v_cadena, v_car, ' ');
            v_cuenta := 0;*/
        
      END LOOP;
   END IF;
   RETURN 'S';
exception
  when others then
     RAISE_APPLICATION_ERROR(-20100,sqlerrm);
     RETURN 'N';
END;
/

