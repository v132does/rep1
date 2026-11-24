CREATE OR REPLACE PROCEDURE IT.PRF_OBT_BIEN
 (P_COD_BIEN  IN AF_BIENES.COD_BIEN%TYPE
 ,RP_AF_BIEN  IN OUT AF_BIENES%ROWTYPE
 )
 IS
BEGIN
   SELECT *
   INTO   RP_AF_BIEN
   FROM   AF_BIENES
   WHERE  COD_BIEN = P_COD_BIEN;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000,
      'No existe Bien '||to_char(P_COD_BIEN));
   WHEN OTHERS THEN
      raise_application_error(-20000,
      'Rec.Bien '||to_char(P_COD_BIEN)||' '||sqlerrm);
END;
/

