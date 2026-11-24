CREATE OR REPLACE FUNCTION IT.FUG_REM_CAR_ESPECIALES(p_cadena VARCHAR2,
                                             p_car_remp varchar2,
                                             p_car varchar2)
 RETURN VARCHAR2 IS
/* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función reemplazar caracteres especiales de forma dinámica.
   Fecha:     31/08/2015*/ 
 
 v_cadena VARCHAR2(4000);
BEGIN
 IF p_cadena IS NOT NULL THEN
  v_cadena := translate(p_cadena,
                        'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                        'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
  v_cadena := translate(v_cadena,
                        'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                        'aeiouAEIOUAaDO     a  o  y yAa                           ');
  v_cadena := translate(v_cadena,
                        p_car_remp,
                        p_car);
  v_cadena := translate(v_cadena, '''', '  ');
 END IF;
 RETURN(v_cadena);
END FUG_REM_CAR_ESPECIALES;
/

