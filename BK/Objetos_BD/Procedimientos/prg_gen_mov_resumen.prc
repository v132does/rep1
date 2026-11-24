CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_RESUMEN
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('NRO_CTA_EXC_ACTUALIZACION'),'0');
v_horIni        varchar(10);
v_horFin        varchar(10);
v_nro_seq       number(12);
v_men_error     varchar2(400);
               

BEGIN
   ---1. Borro el resumen de movimientos
  v_nro_seq := nvl(v_nro_seq,0) + 1;
  v_horIni := to_char(sysdate,'hh24:mi:ss');
  --
  execute immediate 'truncate table GE_MOVIMIENTOS_RES';
  -- logueo
  v_horFin := to_char(sysdate,'hh24:mi:ss');
  PRG_ACT_LOG_PROCESOS('PRG_GEN_MOV_RESUMEN',v_nro_seq,trunc(sysdate),v_horIni, v_horFin,'1-Fin Truncate GE_MOVIMIENTOS_RES');

  ---2. Inserta registros en GE_MOVIMIENTOS_RES
  v_nro_seq := nvl(v_nro_seq,0) + 1;
  v_horIni := to_char(sysdate,'hh24:mi:ss');
  --
  INSERT INTO GE_MOVIMIENTOS_RES (
      fec_valor, monto, nro_cuenta, cod_moneda, cod_oficina, 
      est_cuenta, reversado, cod_transaccion, cod_modulo, 
      cod_modalidad, fec_max_insercion, procesado, rutina1, tipo, afecta
  )
  WITH ctas_excluidas AS (
      SELECT REGEXP_SUBSTR(v_val_parametro, '[^,]+', 1, LEVEL) AS cuenta_exc
      FROM DUAL
      CONNECT BY REGEXP_SUBSTR(v_val_parametro, '[^,]+', 1, LEVEL) IS NOT NULL
   )
  SELECT 
      A.FEC_VALOR, 
      SUM(NVL(A.MONTO, 0)) AS MONTO,             
      A.NRO_CUENTA, 
      A.COD_MONEDA, 
      
      -- Logica coalesce(COD_OFICINA, v_cod_oficina) -> PRIMER valor NO NULO
      MAX(A.COD_OFICINA) KEEP (
          DENSE_RANK FIRST ORDER BY 
          CASE WHEN A.COD_OFICINA IS NOT NULL THEN 0 ELSE 1 END, 
          A.FEC_INSERCION, A.FECHA, A.HORA, A.NRO_SECUENCIA
      ) AS COD_OFICINA,         
      
      -- Logica coalesce(v_est_cuenta, EST_CUENTA) -> ÚLTIMO valor NO NULO
      MAX(A.EST_CUENTA) KEEP (
          DENSE_RANK LAST ORDER BY 
          CASE WHEN A.EST_CUENTA IS NOT NULL THEN 1 ELSE 0 END, 
          A.FEC_INSERCION, A.FECHA, A.HORA, A.NRO_SECUENCIA
      ) AS EST_CUENTA,           
      
      A.REVERSADO,
      A.COD_TRANSACCION, 
      
      -- Logica coalesce(COD_MODULO, v_cod_modulo) -> PRIMER valor NO NULO
      MAX(A.COD_MODULO) KEEP (
          DENSE_RANK FIRST ORDER BY 
          CASE WHEN A.COD_MODULO IS NOT NULL THEN 0 ELSE 1 END, 
          A.FEC_INSERCION, A.FECHA, A.HORA, A.NRO_SECUENCIA
      ) AS COD_MODULO, 
      
      -- Logica coalesce(COD_MODALIDAD, v_cod_modalidad) -> PRIMER valor NO NULO
      MAX(A.COD_MODALIDAD) KEEP (
          DENSE_RANK FIRST ORDER BY 
          CASE WHEN A.COD_MODALIDAD IS NOT NULL THEN 0 ELSE 1 END, 
          A.FEC_INSERCION, A.FECHA, A.HORA, A.NRO_SECUENCIA
      ) AS COD_MODALIDAD, 
      
      MAX(A.FEC_INSERCION) AS FEC_MAX_INSERCION,
      'N' AS PROCESADO,                          
      UPPER(RTRIM(T.RUTINA1)) AS RUTINA1, 
      T.TIPO, 
      T.AFECTA
  FROM GE_MOVIMIENTOS A
  INNER JOIN GE_TRANSACCIONES T
      ON A.COD_TRANSACCION = T.COD_TRANSACCION
     AND A.COD_MODULO = T.COD_MODULO
     AND A.COD_MODALIDAD = T.COD_MODALIDAD
  WHERE A.COD_TRANSACCION > 0
    AND A.ESTADO = 'N'
    AND A.NRO_CUENTA IS NOT NULL
    AND T.RUTINA1 IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM ctas_excluidas exc 
        WHERE exc.cuenta_exc = A.NRO_CUENTA)
  GROUP BY 
      A.FEC_VALOR, 
      A.NRO_CUENTA, 
      A.REVERSADO, 
      A.COD_TRANSACCION, 
      A.COD_MONEDA, 
      UPPER(RTRIM(T.RUTINA1)), 
      T.TIPO, 
      T.AFECTA;
  COMMIT;
  -- logueo
  v_horFin := to_char(sysdate,'hh24:mi:ss');
  PRG_ACT_LOG_PROCESOS('PRG_GEN_MOV_RESUMEN',v_nro_seq,trunc(sysdate),v_horIni, v_horFin,'2-Fin Insert GE_MOVIMIENTOS_RES');
exception
   when others then
      v_men_error := substr(sqlerrm,1,399);
      v_nro_seq := nvl(v_nro_seq,0) + 1;
      v_horFin := to_char(sysdate,'hh24:mi:ss');
      PRG_ACT_LOG_PROCESOS('PRG_GEN_MOV_RESUMEN',v_nro_seq,trunc(sysdate),v_horIni, v_horFin, v_men_error);
      raise_application_error(-20000,'Error PRG_GEN_MOV_RESUMEN Error: '||v_men_error);
END;
/
