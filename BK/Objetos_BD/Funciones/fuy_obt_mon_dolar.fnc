CREATE OR REPLACE FUNCTION IT.FUY_OBT_MON_DOLAR
 RETURN VARCHAR2
 IS

V_MON_DOLAR BA_MONEDAS.COD_MONEDA%TYPE;
BEGIN
   --Obtiene el codigo de la moneda dolar
   --utilizada en las transacciones.
   Select val_char
   into v_mon_dolar
   from ap_parametros
   where cod_parametro like 'MONDOLAR%';

   return v_mon_dolar;

   exception
       when no_data_found then
          raise_application_error(-20000,
          'No existe moneda dólar definida');
END;
/

