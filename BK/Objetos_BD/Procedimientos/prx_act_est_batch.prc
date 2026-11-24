CREATE OR REPLACE PROCEDURE IT.PRX_ACT_EST_BATCH
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE
 ,P_NRO_CUENTA IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE
 ,P_COD_MODALIDAD IN GE_MOVIMIENTOS.COD_MODALIDAD%TYPE
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_EST_CUENTA IN GE_MOVIMIENTOS.EST_CUENTA%TYPE
 ,P_REVERSADO IN GE_MOVIMIENTOS.REVERSADO%TYPE
 ,P_TIP_MOV_RUBRO IN GE_MOVIMIENTOS.TIP_MOV_RUBRO%TYPE
 ,P_AFECTA IN GE_TRANSACCIONES.AFECTA%TYPE
 )
 IS
BEGIN
   IF P_REVERSADO = 'N' THEN
      if p_cod_modalidad = 81 then   
        UPDATE CX_CTA_IMPORTACIONES
           SET EST_BATCH  = P_EST_CUENTA
         WHERE NRO_CUENTA = P_NRO_CUENTA;
          IF sql%notfound then
             RAISE_APPLICATION_ERROR(-20000,'No existe dato en Cta. Importaciones, # '||P_NRO_CUENTA);
          END IF;
      elsif p_cod_modalidad = 82 then
        UPDATE CX_CTA_EXPORTACIONES
           SET EST_BATCH  = P_EST_CUENTA
         WHERE NRO_CUENTA = P_NRO_CUENTA;
          IF sql%notfound then
             RAISE_APPLICATION_ERROR(-20000,'No existe dato en Cta. Exportaciones, # '||P_NRO_CUENTA);
          END IF;
      elsif p_cod_modalidad in (83, 84) then
        UPDATE CX_CTA_COBRANZAS
           SET EST_BATCH  = P_EST_CUENTA
         WHERE NRO_CUENTA = P_NRO_CUENTA;
          IF sql%notfound then
             RAISE_APPLICATION_ERROR(-20000,'No existe dato en Cta. Cobranzas, # '||P_NRO_CUENTA);
          END IF;
      elsif p_cod_modalidad in (88, 89) then
        UPDATE CX_FIANZAS
           SET EST_BATCH  = P_EST_CUENTA
         WHERE NRO_CUENTA = P_NRO_CUENTA;
          IF sql%notfound then
             RAISE_APPLICATION_ERROR(-20000,'No existe dato en Cta. Fianzas, # '||P_NRO_CUENTA);
          END IF;
      end if;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'ERROR.PRX_ACT_EST_BATCH'||sqlerrm
                               ||'-'||P_COD_MODALIDAD||'-'||P_COD_OFICINA
                               ||'-'||P_NRO_CUENTA||' ESTADO: '||P_EST_CUENTA);
END;
/

