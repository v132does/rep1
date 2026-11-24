CREATE OR REPLACE PROCEDURE IT.PRA_ACT_EST_CUPONES
 (P_NRO_CUENTA IN AH_CUPONES.NRO_CUENTA%TYPE default null
 ,P_NRO_CUPON IN AH_CUPONES.NRO_CUPON%TYPE default null
 )
 IS
BEGIN
      UPDATE AH_CUPONES
         SET EST_BATCH = ESTADO
       WHERE NRO_CUPON   = NVL(P_NRO_CUPON,NRO_CUPON)
         AND NRO_CUENTA  = NVL(P_NRO_CUENTA,NRO_CUENTA)
         AND NVL(EST_BATCH, 'x') != nvl(ESTADO, 'x');
     /* Esto se anula, porque puede darse que no exista nada que actualizar 
      IF sql%notfound then
         RAISE_APPLICATION_ERROR(-20000,'No existe dato en AH_CUPONES');
      END IF;*/
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR.PRA_ACT_EST_CUPONES'||sqlerrm);
END;
/

