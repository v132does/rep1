CREATE OR REPLACE FUNCTION IT.fuh_obt_sal_minimo
   RETURN NUMBER IS

   v_mto_sal_minimo NUMBER(18,2);
BEGIN
   BEGIN
     SELECT m.monto
       INTO v_mto_sal_minimo
       FROM rh_sal_minimos m;
   EXCEPTION
    WHEN NO_DATA_FOUND then
     raise_application_error(-20001,
                              'No se encuentra el monto de Sal. Minimo - ' ||
                              sqlerrm);
    WHEN OTHERS then
      raise_application_error(-20001,
                              'Error Obteniendo Sal. Minimo - ' || sqlerrm);
   END;
   RETURN(v_mto_sal_minimo);
END fuh_obt_sal_minimo;
/

