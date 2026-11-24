CREATE OR REPLACE FUNCTION IT.FUA_OBT_CTA_CLIENTE(p_nro_cta_ficticia in varchar2, p_nro_bin in varchar2)
RETURN varchar2 IS

/*Recibe como parametro el numero de cuenta ficticia y el número de bin.
Verifica en la tabla de relacion ah_tar_cta_ficticias
Si existe retorna el numero de cuenta real del cliente.
Si no existe retorna null
Proyecto: SDBIN8TDD-1
MTOP ABR-2021*/

v_nro_cuenta ah_tar_cta_ficticias.nro_cta_cliente%type;

BEGIN
   SELECT nro_cta_cliente
     INTO v_nro_cuenta
   FROM ah_tar_cta_ficticias
   WHERE nro_cuenta = p_nro_cta_ficticia
    and nro_bin     = p_nro_bin;

   return v_nro_cuenta;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
     RETURN NULL;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error en FUA_OBT_CTA_CLIENTE '||p_nro_cta_ficticia||' : '||SQLERRM);
END FUA_OBT_CTA_CLIENTE;
/

