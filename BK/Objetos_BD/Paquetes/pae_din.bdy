CREATE OR REPLACE PACKAGE BODY IT.PAE_DIN IS

/* Abrir cursor dinamico. */
PROCEDURE PR_ABR_CURDINAM
 (P_CURSOR IN OUT INTEGER
 )
 IS
BEGIN
   p_cursor := dbms_sql.open_cursor;
exception
   when others then
      raise_application_error(-20000,
      'Abrir cursor dinamico '||sqlerrm);
END;
/* Cerrar cursor dinamico. */
PROCEDURE PR_CER_CURDINAM
 (P_CURSOR IN OUT VARCHAR2
 )
 IS
BEGIN
   dbms_sql.close_cursor(p_cursor);
exception
   when others then
      raise_application_error(-20000,
      'Cerrar cursor dinamico '||sqlerrm);
END;
/* Ejecutar cursor dinamico */
PROCEDURE PR_EJE_CURDINAM
 (P_SENTENCIA IN VARCHAR2
 )
 IS
v_cursor         INTEGER;
   v_procesado      BINARY_INTEGER;
BEGIN
   -- Abrir cursor
   pr_abr_curdinam(v_cursor);
   -- Parse
   pr_par_curdinam(v_cursor, p_sentencia);
   -- Ejecutar sentencia
   v_procesado := dbms_sql.execute(v_cursor);
   pr_cer_curdinam(v_cursor);
exception
   when others then
      pr_cer_curdinam(v_cursor);
      raise_application_error(-20000,
      'Ejecutar sentencia dinamica '||sqlerrm);
END;
/* Realiza el parce de la sentencia dinamica. */
PROCEDURE PR_PAR_CURDINAM
 (P_CURSOR IN INTEGER
 ,P_SENTENCIA IN VARCHAR2
 )
 IS
BEGIN
   dbms_sql.parse(p_cursor, p_sentencia, dbms_sql.native);
exception
   when others then
      raise_application_error(-20000,
      'Parse sentencia dinamica '||sqlerrm);
END;

END PAE_DIN;
/

