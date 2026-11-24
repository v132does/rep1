CREATE OR REPLACE PROCEDURE IT.PRP_VER_REC_APL_LIMITE IS

--Creado para Exclusion de Limites con Errores DYDMR-5047 / rpavon 23.09.2016--
--Variables--
v_val_parametro ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('NRO_LIN_EXC_REC_LIMIITE'), 0);
v_cod_gar_fogapy ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('COD_GAR_FOGAPY'), 0);
v_can_excluir   number;
v_lin_excluir   varchar2(8000);

--DYDMR-10965
v_es_abierta    varchar2(1);
v_sin_datos       exception;

--Cursor Principal--
Cursor c0 is
    SELECT Z.NRO_LINEA, Z.COD_PERSONA, T.NRO_CUENTA, T.COD_GARANTIA, T.NRO_GARANTIA, 'S' inserta,
           X.COD_MODULO
  FROM CX_CTA_GARANTIAS T, CX_CTA_IMPORTACIONES X, PR_LINEAS Z
 WHERE X.NRO_CUENTA = T.NRO_CUENTA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
 union
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, T.NRO_CUENTA, T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
        X.COD_MODULO
  FROM TA_CTA_GARANTIAS T, TA_CTA_TARJETAS X, PR_LINEAS Z
 WHERE X.NRO_CUENTA = T.NRO_CUENTA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
  UNION
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, T.NRO_CUENTA, T.COD_GARANTIA, T.NRO_GARANTIA, 'S' inserta,
        X.COD_MODULO
  FROM PR_CTA_GARANTIAS T, PR_CTA_PRESTAMOS X, PR_LINEAS Z
 WHERE X.NRO_CUENTA = T.NRO_CUENTA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND T.NRO_GARANTIA NOT IN (1,2,42)
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
 UNION
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, TO_CHAR(X.NRO_SECUENCIA), T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
        4 COD_MODULO
  FROM CC_LIN_SOB_GARANTIAS T, CC_LIN_SOBREGIROS X, PR_LINEAS Z
 WHERE X.NRO_SECUENCIA = T.NRO_SECUENCIA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = 4
                      AND K.VAL_PARAMETRO = 'S')
 UNION
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, T.NRO_CUENTA, T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
        X.COD_MODULO
  FROM MD_GARANTIAS T, MD_CTA_DOCUMENTOS X, PR_LINEAS Z
 WHERE X.NRO_CUENTA = T.NRO_CUENTA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   --and x.nro_cuenta='0110000773'
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
 UNION
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, TO_CHAR(T.NRO_SOLICITUD), T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
        X.COD_MODULO
  FROM PR_SOL_GARANTIAS T, PR_SOLICITUDES X, PR_LINEAS Z
 WHERE X.NRO_SOLICITUD = T.NRO_SOLICITUD
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   and INSTR(v_cod_gar_fogapy, T.COD_GARANTIA) = 0
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'SOL_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
 UNION
 SELECT Z.NRO_LINEA, Z.COD_PERSONA, TO_CHAR(T.NRO_SOLICITUD), T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
        X.COD_MODULO
  FROM TA_SOL_GARANTIAS T, TA_SOLICITUDES X, PR_LINEAS Z
 WHERE X.NRO_SOLICITUD = T.NRO_SOLICITUD
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'SOL_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S')
  UNION
  SELECT Z.NRO_LINEA, Z.COD_PERSONA, T.NRO_CUENTA, T.COD_GARANTIA, T.NRO_GARANTIA, 'N' inserta,
         X.COD_MODULO
  FROM PV_OPERACIONES_DET T, LC_CTA_CAMBIOS X, PR_LINEAS Z
 WHERE T.COD_GARANTIA <> 1
   AND X.NRO_CUENTA = T.NRO_CUENTA
   AND X.NRO_LINEA IS NOT NULL
   AND Z.NRO_LINEA = X.NRO_LINEA
   AND Z.ESTADO IN ('A','B')
   AND INSTR(V_VAL_PARAMETRO, Z.NRO_LINEA) = 0
   AND NOT EXISTS (SELECT 1 FROM PR_LIN_TIP_GARANTIAS Y  --DYDMR-10965 se agrega la condicion NOT
                    WHERE Y.NRO_LINEA = X.NRO_LINEA
                      AND Y.COD_GARANTIA = T.COD_GARANTIA)
   AND NOT EXISTS (SELECT 1
                     FROM GE_PAR_DINAMICOS K
                    WHERE K.PARAMETRO = 'MOD_EXC_CON_GAR'
                      AND K.COD_MODULO = X.COD_MODULO
                      AND K.VAL_PARAMETRO = 'S');
BEGIN
  --Inicializar--
  v_can_excluir := 0;
  v_lin_excluir := null;
  For r0 in c0 Loop
   /*-- se comenta para controlar primero si es una garantia abierta entonces insertamos automaticamente en el parámetro dinamico NRO_LIN_EXC_REC_LIMIITE
     v_can_excluir := nvl(v_can_excluir,0) + 1;
     v_lin_excluir := v_lin_excluir||'Limite:'||r0.nro_linea||'-Persona:'||r0.cod_persona||'-Modulo:'||r0.cod_modulo||'-Cuenta:'||r0.nro_cuenta||chr(13);
   */
     BEGIN
        select 'S'
          into v_es_abierta
          from pr_garantias a
          where a.nro_garantia = r0.nro_garantia
            and nvl(a.tipo,'C') = 'A' ;
     EXCEPTION
        when others then
           v_es_abierta := 'N';
     END;

     if v_es_abierta = 'S' then
         -- TENGO QUE AGREGAR AL PARAMETRO DINAMICO
       BEGIN
         UPDATE GE_PAR_DINAMICOS A
         SET A.VAL_PARAMETRO = A.VAL_PARAMETRO||','||r0.nro_linea
         WHERE A.PARAMETRO = 'NRO_LIN_EXC_REC_LIMIITE';

         IF SQL%ROWCOUNT = 0 THEN
             -- CONTROL MANUAL SI NO EXISTE AUN EL REGISTRO
             RAISE v_sin_datos;
         END IF;
       EXCEPTION
         WHEN v_sin_datos THEN
              INSERT INTO GE_PAR_DINAMICOS A (parametro, val_parametro)
              VALUES( 'NRO_LIN_EXC_REC_LIMIITE', r0.nro_linea);
       END;
     ELSE
         v_can_excluir := nvl(v_can_excluir,0) + 1;
         v_lin_excluir := v_lin_excluir||'Limite:'||r0.nro_linea||'-Persona:'||r0.cod_persona||'-Modulo:'||r0.cod_modulo||'-Cuenta:'||r0.nro_cuenta||chr(13);
         if r0.cod_modulo = 10 then
            v_can_excluir := 0;
         end if;
     END IF;

 END LOOP;
  --Validacion--
  if nvl(v_can_excluir,0) > 0 then
     Raise_application_error(-20000, 'Limite(s) c/ Tipos Garantias inconsistentes. '||chr(13)||
                             'Excluir cargando en Par.Din. NRO_LIN_EXC_REC_LIMIITE el Nro. Limite y repetir ejecucion.'||chr(13)||
                             v_lin_excluir);
  end if;
exception
  when others then
       Raise_application_error(-20000, 'Error en PRP_VER_REC_APL_LIMITE'||'-'||sqlerrm);
END;
/
