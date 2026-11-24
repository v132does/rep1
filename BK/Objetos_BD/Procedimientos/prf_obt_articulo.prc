CREATE OR REPLACE PROCEDURE IT.PRF_OBT_ARTICULO
 (P_COD_ARTICULO IN AF_ARTICULOS.COD_ARTICULO%TYPE
 ,RP_AF_ARTICULOS IN OUT AF_ARTICULOS%ROWTYPE
 )
 IS
BEGIN
   SELECT *
   INTO   RP_AF_ARTICULOS
   FROM   af_articulos
   WHERE  cod_articulo = P_COD_ARTICULO;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000,
      'No existe Artículo '||to_char(P_COD_ARTICULO));
   WHEN OTHERS THEN
      raise_application_error(-20000,
      'Rec.Artículo '||to_char(P_COD_ARTICULO)||' '||sqlerrm);
END;
/

