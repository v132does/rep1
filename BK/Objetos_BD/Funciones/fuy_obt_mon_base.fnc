CREATE OR REPLACE FUNCTION IT.FUY_OBT_MON_BASE
 RETURN VARCHAR2
 IS

V_MON_BASE BA_MONEDAS.COD_MONEDA%TYPE;
BEGIN
   -- Obtiene el codigo de la moneda base
   -- utilizada en las transacciones
   Select val_char
   into v_mon_base
   from ap_parametros
   where cod_parametro like 'MONBASE%';

   return v_mon_base;

   exception
       when no_data_found then
          raise_application_error(-20000,
          'No existe moneda base definida');

END ;
/

