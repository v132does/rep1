CREATE OR REPLACE FUNCTION IT.FUA_OBT_CTA_FICTICIA(p_nro_cuenta in varchar2, p_nro_bin in varchar2 )
RETURN varchar2 IS

/*Recibe como parametro el numero de cuenta real del cliente y 
el nro de bin de la solicitud de TDD
Verifica en la tabla de relacion ah_tar_cta_ficticias
Si existe retorna el numero de cuenta ficticia o cuenta alias
Si no existe retorna null
Proyecto: SDBIN8TDD-1
MTOP-2021*/

v_cta_ficticia ah_tar_cta_ficticias.nro_cuenta%type;

BEGIN
   SELECT nro_cuenta
     INTO v_cta_ficticia
   FROM ah_tar_cta_ficticias
   WHERE nro_cta_cliente = p_nro_cuenta
     and nro_bin         = p_nro_bin;

   return v_cta_ficticia;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
     RETURN NULL;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error en FUA_OBT_CTA_FICTICIA '||p_nro_cuenta||' : '||SQLERRM);
END FUA_OBT_CTA_FICTICIA;
/

