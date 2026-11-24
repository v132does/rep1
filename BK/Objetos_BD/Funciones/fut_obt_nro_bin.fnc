CREATE OR REPLACE FUNCTION IT.fut_obt_nro_bin
(
   p_cod_modalidad IN ta_tipos.cod_modalidad%TYPE,
   p_cod_modulo    IN ta_tipos.cod_modulo%TYPE,
   p_afinidad      IN ta_tipos.afinidad%TYPE,
   p_sub_afinidad  IN ta_tipos.sub_afinidad%TYPE,
   p_nro_tarjeta   in ta_tarjetas.nro_tarjeta%type default null

) RETURN VARCHAR2 IS
 
   v_nro_bin varchar2(10);
   v_tp varchar2(10) := 'J2';
BEGIN
   BEGIN
     select substr(a.nro_bin, 0, 6) as nro_bin
       into v_nro_bin
        from ta_tipos a
       where a.cod_modalidad = p_cod_modalidad
         and a.cod_modulo = p_cod_modulo
         and a.afinidad = p_afinidad
         and a.sub_afinidad = p_sub_afinidad
         and rownum = 1; 
   EXCEPTION
      WHEN no_data_found THEN
       return(substr(p_nro_tarjeta,0,6)||'J2');          
   END;
   
   select a.val_maximo
     into v_tp  
   from ba_cod_referencias a 
   where a.dominio = 'BINTP' 
   and a.val_minimo = v_nro_bin;
   
   RETURN(v_nro_bin||v_tp);
END fut_obt_nro_bin;
/

