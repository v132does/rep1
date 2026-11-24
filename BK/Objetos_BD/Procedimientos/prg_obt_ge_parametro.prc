CREATE OR REPLACE PROCEDURE IT.PRG_OBT_GE_PARAMETRO
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 ,RP_GPARAM IN OUT GE_PARAMETROS%ROWTYPE
 )
 IS
BEGIN
   select *
   into rp_gparam
   from ge_parametros
   where parametro = p_parametro;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Parámetro '||p_parametro||' no registrado');
END;
/

