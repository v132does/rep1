CREATE OR REPLACE PROCEDURE IT.PRL_GEN_PLA_OPERACIONES
 IS
--- OBS: Tercer Proceso del cierre de Cambios
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_error          varchar2(250);
   w_const1    number(03) := -1;
   w_const2    number(03) := -1;   
BEGIN
   --- Recuperar fecha del modulo
   v_fec_actual := pag_cal.fu_obt_fec_actual(7);
   --- Eliminar tabla de saldos de posiciones
   sql_util.ejecute_dml('truncate table LC_PLA_OPERACIONES', v_error);
   if v_error is not null then
      raise_application_error(-20000,
      'Elimina LC_PLA_OPERACIONES '||v_error);
   end if;
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   --- Generar Particular
   INSERT INTO LC_PLA_OPERACIONES(COD_OFI_CAMBIO,COD_MONEDA,COD_BCP_CLIENTE,
                           COD_ACTIVIDAD,COD_MAD_PADRE,COD_MODALIDAD,
                           MTO_COMPRA,COT_COMPRA,TOT_COMPRA,MTO_VENTA,
                           COT_VENTA,TOT_VENTA,COD_USUARIO,HORA,
                           FECHA,NRO_CUENTA)
   SELECT pal_cam.fu_obt_ofi_cambio(a.cod_ofi_origen),A.COD_MONEDA,W_CONST1,W_CONST2,A.COD_MAD_PADRE,
          DECODE(A.TIP_MOV_RUBRO,'C',72,'D',71,COD_MAD_HIJO),
          NVL(A.MONTO,0),A.COTIZACION,
          NVL(A.MTO_EQU_LOCAL,0),
          NVL(A.MONTO,0),A.COTIZACION,
          NVL(A.MTO_EQU_LOCAL,0),A.COD_USUARIO,A.HORA,A.FECHA,
          A.NRO_CUENTA
     FROM LC_TIP_OPERACIONES,GE_MOVIMIENTOS A
    WHERE A.COD_MONEDA <> v_cod_mon_local
      AND A.COD_TIP_OPE_CAMBIO > 9
      AND A.COD_OFI_ORIGEN = COD_OFICINA
      AND (A.NRO_CUENTA IS NULL OR (A.NRO_CUENTA IS NOT NULL AND
                                    A.COD_MODULO <> 7))
      AND A.ESTADO IN ('H','N')
      AND A.REVERSADO = 'N'
      AND A.COD_MOD_PADRE = 7
      AND A.COD_TIP_OPE_CAMBIO = COD_TIP_OPERACION
      AND AFE_POSICION IN ('E','O')
   UNION
   SELECT pal_cam.fu_obt_ofi_cambio(a.cod_ofi_origen),A.COD_MONEDA,-1,-1 /*COD_TIP_CLIENTE */,A.COD_MAD_PADRE,
          DECODE(A.TIP_MOV_RUBRO,'C',72,'D',71,COD_MAD_HIJO),
          NVL(A.MONTO,0),A.COTIZACION,
          NVL(A.MTO_EQU_LOCAL,0),
          NVL(A.MONTO,0),A.COTIZACION,
          NVL(A.MTO_EQU_LOCAL,0),A.COD_USUARIO,A.HORA,A.FECHA,
          A.NRO_CUENTA
     FROM LC_TIP_OPERACIONES, LC_CTA_CAMBIOS , GE_MOVIMIENTOS A, GE_MOVIMIENTOS B
    WHERE A.COD_MOD_PADRE = 7
      AND A.ESTADO  IN ('H','N')
      AND A.REVERSADO = 'N'
      AND A.COD_TIP_OPE_CAMBIO > 9
      AND A.HORA = B.HORA
      AND A.COD_USUARIO = B.COD_USUARIO
      AND A.FECHA = B.FECHA
      AND B.NRO_CUENTA = LC_CTA_CAMBIOS.NRO_CUENTA
      AND A.COD_MONEDA <> v_cod_mon_local
      AND A.COD_TIP_OPE_CAMBIO = COD_TIP_OPERACION
      AND AFE_POSICION IN ('E','O');
   --- Modificar Compra y Venta
   UPDATE LC_PLA_OPERACIONES
      SET TOT_COMPRA = NULL,
          COT_COMPRA = NULL,
          MTO_COMPRA = NULL
    WHERE COD_MODALIDAD = 72;
   UPDATE LC_PLA_OPERACIONES
      SET TOT_VENTA = NULL,
          COT_VENTA = NULL,
          MTO_VENTA = NULL
    WHERE COD_MODALIDAD = 71;
   --- Borrar particular
   DELETE LC_PLA_OPERACIONES E
    WHERE E.COD_ACTIVIDAD = -1
      AND E.COD_BCP_CLIENTE = -1
      AND (E.COD_USUARIO,E.HORA,E.FECHA) IN
                 (SELECT COD_USUARIO,HORA,FECHA
                    FROM LC_PLA_OPERACIONES
                   WHERE COD_ACTIVIDAD IN (7,12)
                      OR (COD_MAD_PADRE in (73,74)
                     AND nvl(COD_ACTIVIDAD,-5) <> -1
                     AND NVL(COD_BCP_CLIENTE,-5) <> -1));
END;
/

