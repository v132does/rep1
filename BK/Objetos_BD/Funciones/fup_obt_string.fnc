CREATE OR REPLACE FUNCTION IT.FUP_OBT_STRING ( P_TABLA     VARCHAR2,
                                            P_CAMPO1    VARCHAR2 DEFAULT 0,
                                            P_CAMPO2    VARCHAR2 DEFAULT 0,
                                            P_CAMPO3    VARCHAR2 DEFAULT 0,
                                            P_VALOR1    VARCHAR2 DEFAULT 0,
                                            P_VALOR2    VARCHAR2 DEFAULT 0,
                                            P_VALOR3    VARCHAR2 DEFAULT 0,
                                            P_CADENA    NUMBER   DEFAULT 0,
                                            P_POSICION  NUMBER   DEFAULT 0 )
RETURN VARCHAR2 IS
    i number := 1;
    v_pos number;
    v_ref_cursor sql_util.T_cursor_tab;
    v_filas number;
    v_error varchar2(4000);
 ------------------------ Función que devuelve la posición de asteriscos --------------------------
    FUNCTION FU_OBT_POS_AST ( P_NOM_TABLA          VARCHAR2,
                              P_NOM_CAMPO1         VARCHAR2 DEFAULT 0,
                              P_NOM_CAMPO2         VARCHAR2 DEFAULT 0,
                              P_NOM_CAMPO3         VARCHAR2 DEFAULT 0,
                              P_DATO1              VARCHAR2 DEFAULT 0,
                              P_DATO2              VARCHAR2 DEFAULT 0,
                              P_DATO3              VARCHAR2 DEFAULT 0,
                              A                    NUMBER )
    RETURN NUMBER IS
      v_ref_cursor sql_util.T_cursor_tab;
      v_filas number;
      v_error varchar2(4000);
    BEGIN
      sql_util.ejecute_consulta('select nvl( instr(observacion, '||chr(39)||'*'||chr(39)||', 1, '||a||' ), 0 )
                                   from '||p_nom_tabla||
                                ' where '||p_nom_campo1||' = '||p_dato1||
                                  ' and '||P_NOM_CAMPO2||' = '||P_DATO2||
                                  ' and '||P_NOM_CAMPO3||' = '||P_DATO3,
                                  1,
                                  v_filas,
                                  v_ref_cursor,
                                  v_error );
      if v_error is null then
         return (v_ref_cursor(1).columna1);
      else
         raise_application_error(-20000,'Error al buscar los caracteres - '||v_error);
      end if;
    END;
 ------------------- Función que devuelve la última línea del campo observación -------------------
BEGIN
  WHILE fu_obt_pos_ast(p_tabla,p_campo1,p_campo2,p_campo3,p_valor1,p_valor2,p_valor3,i) <> 0 LOOP
        v_pos := fu_obt_pos_ast(p_tabla,p_campo1,p_campo2,p_campo3,p_valor1,p_valor2,p_valor3,i);
        i := i + 1;
  END LOOP;

  sql_util.ejecute_consulta('select substr( observacion, '||v_pos||',length( observacion ) )
                               from '||p_tabla||
                            ' where '||p_campo1||' = '||p_valor1||
                              ' and '||P_CAMPO2||' = '||P_valor2||
                              ' and '||P_CAMPO3||' = '||P_valor3,
                              1,
                              v_filas,
                              v_ref_cursor,
                              v_error );
  IF p_cadena = 1 THEN
      if v_error is null then
         return (v_ref_cursor(1).columna1);
      else
         raise_application_error(-20000,'Error al buscar la última línea de la observación - '||sqlerrm);
      end if;
  ELSIF p_posicion = 1 THEN
      return v_pos;
  ELSE
      return null;
  END IF;

END;
/

