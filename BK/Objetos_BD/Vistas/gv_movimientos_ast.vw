create or replace force view it.gv_movimientos_ast as
select

              MOV.COD_MONEDA,
              MOV.MONTO,
              MOV.FECHA,
              MOV.NRO_CUENTA,
              TH.DESCRIPCION DES_TRANSACCION,
              MOV.COD_MODALIDAD,
              MOV.HORA,
              MOV.NRO_DOCUMENTO,
              MOV.COD_USUARIO,
              DECODE(MOV.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOVIMIENTO,
              MOV.COD_TRA_PADRE,
              MOV.COD_TRANSACCION,
              MOV.COD_BANCO,
	            MOV.CONCEPTO,
              MOV.COD_OFICINA,
              MOV.COD_MODULO,
              CU.DENOMINACION,
              MOV.REVERSADO,
              MOV.COD_MAD_PADRE,
              MOV.COD_MOD_PADRE

from (
     select   MO.COD_MONEDA,
              MO.MONTO,
              MO.FECHA,
              MO.NRO_CUENTA,
              MO.COD_MODALIDAD,
              MO.HORA,
              MO.NRO_DOCUMENTO,
              MO.COD_USUARIO,
              MO.COD_TRA_PADRE,
              MO.COD_TRANSACCION,
              MO.COD_BANCO,
	            MO.CONCEPTO,
              MO.COD_OFICINA,
              MO.COD_MODULO,
              MO.REVERSADO,
              MO.COD_MAD_PADRE,
              MO.COD_MOD_PADRE
     FROM AH_MOVIMIENTOS_HIS MO
     UNION ALL
     select  MO.COD_MONEDA,
              MO.MONTO,
              MO.FECHA,
              MO.NRO_CUENTA,
              MO.COD_MODALIDAD,
              MO.HORA,
              MO.NRO_DOCUMENTO,
              MO.COD_USUARIO,
              MO.COD_TRA_PADRE,
              MO.COD_TRANSACCION,
              MO.COD_BANCO,
	            MO.CONCEPTO,
              MO.COD_OFICINA,
              MO.COD_MODULO,
              MO.REVERSADO,
              MO.COD_MAD_PADRE,
              MO.COD_MOD_PADRE
     FROM CC_MOVIMIENTOS_HIS MO
     UNION ALL
     select   MO.COD_MONEDA,
              MO.MONTO,
              MO.FECHA,
              MO.NRO_CUENTA,
              MO.COD_MODALIDAD,
              MO.HORA,
              MO.NRO_DOCUMENTO,
              MO.COD_USUARIO,
              MO.COD_TRA_PADRE,
              MO.COD_TRANSACCION,
              MO.COD_BANCO,
	            MO.CONCEPTO,
              MO.COD_OFICINA,
              MO.COD_MODULO,
              MO.REVERSADO,
              MO.COD_MAD_PADRE,
              MO.COD_MOD_PADRE
     FROM PR_MOVIMIENTOS_HIS MO




     UNION ALL

     select   MO.COD_MONEDA,
              MO.MONTO,
              MO.FECHA,
              MO.NRO_CUENTA,

              MO.COD_MODALIDAD,
              MO.HORA,
              MO.NRO_DOCUMENTO,
              MO.COD_USUARIO,

              MO.COD_TRA_PADRE,
              MO.COD_TRANSACCION,
              MO.COD_BANCO,
	            MO.CONCEPTO,
              MO.COD_OFICINA,
              MO.COD_MODULO,

              MO.REVERSADO,
              MO.COD_MAD_PADRE,
              MO.COD_MOD_PADRE

     FROM GE_MOVIMIENTOS MO, BA_MODULOS MD
     WHERE MD.COD_MODULO = 3 --- Ahorros
     AND MD.ESTADO != 4 --Este no va traer nunca nada




) MOV, GE_TRANSACCIONES TH, GE_CUENTAS CU
WHERE MOV.COD_MODULO = TH.COD_MODULO(+)
AND MOV.COD_MODALIDAD = TH.COD_MODALIDAD(+)
AND MOV.COD_TRANSACCION = TH.COD_TRANSACCION(+)
AND MOV.NRO_CUENTA = CU.NRO_CUENTA(+)
;

