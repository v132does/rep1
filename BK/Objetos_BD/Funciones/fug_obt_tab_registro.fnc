create or replace function it.fug_obt_tab_registro(p_cadena clob, p_separador VARCHAR2 := ',') RETURN tyg_tab_registro
PIPELINED IS
/*Devuelve un valor Tipo Tabla a partir de una cadena y caracter separador*/
   v_indice PLS_INTEGER;
   v_lista clob := p_cadena;
BEGIN
   LOOP
      v_indice := instr(v_lista, p_separador);
      IF v_indice > 0 THEN
         PIPE ROW(substr(v_lista, 1, v_indice - 1));
         v_lista := substr(v_lista, v_indice + length(p_separador));
      ELSE
         PIPE ROW(v_lista);
         EXIT;
      END IF;
   END LOOP;
   RETURN;
END fug_obt_tab_registro;
/

