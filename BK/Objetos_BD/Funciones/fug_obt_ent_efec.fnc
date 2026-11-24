CREATE OR REPLACE FUNCTION IT.FUG_OBT_ENT_EFEC (P_ANO      IN VARCHAR2,
                                            P_MES      IN VARCHAR2,
                                            P_MONEDA   IN BA_MONEDAS.COD_MONEDA%TYPE,
                                            P_CONSULTA VARCHAR2)
  RETURN NUMBER IS
  V_MONTO LC_OPE_EFECTIVOS.MONTO%TYPE;
BEGIN

  -----------------------------
  ---------ENTRADAS-----------
  -----------------------------

  --ENTRADAS EN CUENTA DEL CLIENTE
  IF P_CONSULTA = 'ECC' THEN
    BEGIN
          SELECT NVL(SUM(A.MONTO), 0) mto
          INTO V_MONTO
          FROM LC_OPE_EFECTIVOS A
          WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
          AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
          AND A.COD_MONEDA = P_MONEDA
          AND A.COD_TIP_OPE_EFE = 1;
         
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;
  
  --ENTRADAS POR VENTANILLA NO EN CUENTA DE CLIENTES
  IF P_CONSULTA = 'EPV' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 2
         and a.cod_persona is not null
         AND A.COD_PERSONA not in (SELECT distinct (GBANC.cod_persona)
                                 FROM GE_BANCOS GBANC, cc_cta_bancarias b
                                where gbanc.cod_banco = b.cod_banco
                                  and ((b.cod_modalidad = 43 and
                                      pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                      (b.cod_modalidad = 45 and
                                      pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                  and b.estado = 'N'
                                  and gbanc.estado = 'A');
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  --ENTRADAS EN EFECTIVO OTROS (MODULO DE CAMBIOS)
  IF P_CONSULTA = 'EEO' THEN
    BEGIN
    
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 3;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  --ENTRADAS EN EFECTIVO CORRESPONSAL
  IF P_CONSULTA = 'EEC' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 2
         AND A.COD_PERSONA in (SELECT distinct (GBANC.cod_persona)
                                FROM GE_BANCOS GBANC, cc_cta_bancarias b
                               where gbanc.cod_banco = b.cod_banco
                                 and ((b.cod_modalidad = 43 and
                                     pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                     (b.cod_modalidad = 45 and
                                     pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                 and b.estado = 'N'
                                 and gbanc.estado = 'A');
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;
  
  IF P_CONSULTA = 'DIF' THEN
    BEGIN
       
          select 
          nvl(nvl(fug_obt_balini_efec(to_char(l.fecha,'YYYY'),to_char(l.fecha,'MM'),l.cod_moneda),0)  - 

          nvl(nvl(fug_obt_balini_efec(to_char(add_months(l.fecha,-1),'YYYY'),to_char(add_months(l.fecha,-1),'MM'),l.cod_moneda),0) +
          ( 
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'ECC'),0) + 
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'EPV'),0) +
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'EEO'),0) +
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'EEC'),0)  )                                        -
          (
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'SCC'),0) + 
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'SPV'),0) +
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'SEO'),0) +
          nvl(fug_obt_ent_efec(to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),l.cod_moneda,'SEC'),0)
          ),0),0) mto 

           INTO V_MONTO
          from lc_ope_efectivos l, ge_transacciones t
          where   TO_CHAR(l.FECHA, 'MM') = P_MES
          AND TO_CHAR(l.FECHA, 'YYYY') = P_ANO
          and TO_CHAR(l.FECHA, 'MM/YYYY') <> TO_CHAR(pag_cal.fu_obt_fec_actual(3), 'MM/YYYY')
          and l.cod_transaccion = t.cod_transaccion
          and l.cod_modulo = t.cod_modulo
          and l.cod_modalidad = t.cod_modalidad
          AND l.COD_MONEDA = P_MONEDA
          group by to_char(l.fecha,'MM'),to_char(l.fecha,'YYYY'),to_char(l.fecha,'MON-YY'),l.cod_moneda,to_char(l.fecha,'yyyy'),to_char(l.fecha,'mm'),to_char(add_months(l.fecha,-1),'YYYY'),to_char(add_months(l.fecha,-1),'MM');

         
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  -----------------------------
  ---------SALIDAS------------
  -----------------------------

  --SALIDAS EN CUENTA DEL CLIENTE
  IF P_CONSULTA = 'SCC' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 5;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  --SALIDAS POR VENTANILLA NO EN CUENTA DE CLIENTES
  IF P_CONSULTA = 'SPV' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 6
         and a.cod_persona is null
/*         AND A.COD_PERSONA not in (SELECT distinct (GBANC.cod_persona)
                                 FROM GE_BANCOS GBANC, cc_cta_bancarias b
                                where gbanc.cod_banco = b.cod_banco
                                  and ((b.cod_modalidad = 43 and
                                      pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                      (b.cod_modalidad = 45 and
                                      pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                  and b.estado = 'N'
                                  and gbanc.estado = 'A');*/;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  --SALIDAS EN EFECTIVO OTROS (MODULO DE CAMBIOS)
  IF P_CONSULTA = 'SEO' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 7;
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  --SALIDAS EN EFECTIVO CORRESPONSAL
  IF P_CONSULTA = 'SEC' THEN
    BEGIN
      SELECT NVL(SUM(A.MONTO), 0)
        INTO V_MONTO
        FROM LC_OPE_EFECTIVOS A
       WHERE TO_CHAR(A.FECHA, 'MM') = P_MES
         AND TO_CHAR(A.FECHA, 'YYYY') = P_ANO
         AND A.COD_MONEDA = P_MONEDA
         AND A.COD_TIP_OPE_EFE = 6
         AND A.COD_PERSONA in (SELECT distinct (GBANC.cod_persona)
                                FROM GE_BANCOS GBANC, cc_cta_bancarias b
                               where gbanc.cod_banco = b.cod_banco
                                 and ((b.cod_modalidad = 43 and
                                     pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                     (b.cod_modalidad = 45 and
                                     pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                 and b.estado = 'N'
                                 and gbanc.estado = 'A');
    EXCEPTION
      WHEN OTHERS THEN
        V_MONTO := 0;
    END;
  END IF;

  RETURN(V_MONTO);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000, 'ERROR AL OBTENER MONTO EFECTIVO');
  
END;
/

