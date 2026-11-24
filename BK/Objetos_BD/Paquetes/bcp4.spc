CREATE OR REPLACE PACKAGE IT.bcp4 IS

   -- declaración de variables globales
   fechaini DATE;

   FUNCTION f_periodo RETURN VARCHAR2;
   FUNCTION isfecha(cadena IN VARCHAR2) RETURN NUMBER;

   FUNCTION buscar_deptos
   (
      pi_cddpto IN NUMBER,
      sec_proc  IN NUMBER
   ) RETURN BOOLEAN;
   /* procedure insertar_errores(p_iderror in number,
   p_modulo in varchar2,
   p_fuente in varchar2,
   p_mensaje in varchar2,
     p_informado in number,
   p_calculado in varchar2,
   p_identificador in varchar2,
   p_numreg in number,
   p_cdent in varchar2);*/

   FUNCTION lineas(numlineas NUMBER) RETURN NUMBER;
   FUNCTION cantidad_archivos
   (
      cdent    IN VARCHAR2,
      sec_proc IN NUMBER
   ) RETURN NUMBER;

   PROCEDURE ins_debug
   (
      p_lugar   IN VARCHAR2,
      p_mensaje IN VARCHAR2
   );
   PROCEDURE err_nombres
   (
      p_cdent  IN VARCHAR2,
      sec_proc IN NUMBER
   );
   PROCEDURE registros_duplicados
   (
      v_cdent  IN VARCHAR2,
      sec_proc IN NUMBER
   );
   PROCEDURE mensaje
   (
      p_numbanco IN VARCHAR2,
      mens1      IN VARCHAR2,
      sec_proc   IN NUMBER
   );
   FUNCTION isnumeric
   (
      cadena   IN VARCHAR2,
      sec_proc IN NUMBER
   ) RETURN NUMBER;

   --procedure raw_to_archivos (
   --  p_cdent in varchar2, sec_proc in number);
   PROCEDURE montatablas
   (
      numbanco VARCHAR2,
      sec_proc IN NUMBER
   );

   PROCEDURE validacion
   (
      numbanco  VARCHAR2,
      numlineas NUMBER,
      periodo   DATE,
      sec_proc  NUMBER
   );
   PROCEDURE err_integridad
   (
      numlineas IN NUMBER,
      v_cdent   IN VARCHAR2,
      sec_proc  IN NUMBER
   );
   PROCEDURE initperiodo(p_anomes IN NUMBER);

   PROCEDURE initablas(numbanco VARCHAR2);
   PROCEDURE raw_to_archivos
   (
      p_cdent   IN VARCHAR2,
      p_archivo IN VARCHAR2
   );
END bcp4;
/

