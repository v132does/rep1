CREATE OR REPLACE PROCEDURE IT.PRE_INI_APLICACION
 IS
BEGIN
   -- Inicializamos la variable global de control de aplicación
   -- en los triggers de auditoria.
   pae_cnf.g_aplicacion := 'S';
   pae_cnf.g_cod_modulo := 5;
END;
/

