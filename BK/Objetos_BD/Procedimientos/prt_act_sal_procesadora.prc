CREATE OR REPLACE PROCEDURE IT.prt_act_sal_procesadora IS

   v_monto ge_movimientos.monto%TYPE;
   v_lugar VARCHAR2(100);
   --movimientos especiales de tarjetas
   CURSOR mov IS
      SELECT a.monto, a.nro_cuenta, b.tipo, a.reversado
        FROM ge_transacciones b, ge_movimientos a
       WHERE a.monto <> 0
         AND a.reversado = 'N'
         AND a.nro_cuenta IS NOT NULL
         AND a.cod_modulo = 5
         AND b.afecta = 'J' --afecta saldo de tarJeta
         AND a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.cod_transaccion = b.cod_transaccion
      
      UNION ALL
      
      SELECT a.monto, a.nro_cuenta, b.tipo, a.reversado
        FROM ge_transacciones b, ge_movimientos a
       WHERE a.monto <> 0
         AND a.reversado = 'S'
         AND a.nro_cuenta IS NOT NULL
         AND a.cod_modulo = 5
         AND b.afecta = 'J' --afecta saldo de tarJeta
         AND a.cod_modulo = b.cod_modulo
         AND a.cod_modalidad = b.cod_modalidad
         AND a.cod_transaccion = b.cod_transaccion
         AND a.fec_valor <> a.fecha;

BEGIN
   FOR reg IN mov LOOP
      --limpiar variables
      v_monto := 0;
   
      v_monto := reg.monto;
   
      --RI: 01/10/2010: En Tarjetas los Creditos restan(-) y los Debitos suman (+)        
      IF reg.tipo = 'C' THEN
         v_monto := v_monto * -1;
      ELSIF reg.tipo = 'D' AND reg.reversado = 'S' AND reg.monto > 0 THEN
         v_monto := v_monto * -1;
      END IF;
   
      v_lugar := 'Cta. ' || reg.nro_cuenta || ' Mto. ' || reg.monto;
   
      UPDATE ta_cta_tarjetas
         SET sal_procesadora = nvl(sal_procesadora, 0) + nvl(v_monto, 0)
       WHERE nro_cuenta = reg.nro_cuenta;
   
      IF SQL%NOTFOUND THEN
         raise_application_error(-20000, 'No existe Tarjeta # ' || reg.nro_cuenta);
      END IF;
   
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20002, v_lugar || ' PRP_ACT_SAL_PROCESADORA. ' || SQLERRM);
END;
/

