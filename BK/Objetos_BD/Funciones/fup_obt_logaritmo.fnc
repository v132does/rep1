CREATE OR REPLACE FUNCTION IT.FUP_OBT_LOGARITMO
 (NUMERO NUMBER
 )
 RETURN INTEGER
 IS
ww_log number;
BEGIN
   select log(10,numero) into ww_log from dual;
   RETURN ww_log;
EXCEPTION
--
   when others then
        raise_application_error(-20000,'problema al ver el LOGARITMO');
END ;
/

