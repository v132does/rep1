CREATE OR REPLACE FUNCTION IT.fua_obt_cta_bin8
(
   p_val_parametro IN VARCHAR2
)

 RETURN VARCHAR2 IS
   v_nro_cuenta    ge_cta_dat_adicionales.nro_cuenta%TYPE;
BEGIN

         SELECT f.nro_cta_cliente
           INTO v_nro_cuenta
           FROM ah_tar_cta_ficticias f
          WHERE nro_cuenta = to_number(p_val_parametro);
  
   RETURN v_nro_cuenta;
EXCEPTION
   WHEN OTHERS THEN
     RETURN NULL;

END;
/

