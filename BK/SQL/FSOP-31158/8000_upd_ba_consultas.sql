BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
UPDATE ba_Consultas
SET    det_sql =  'SELECT V.FECHA           FECHA,
       V.HORA            HORA,
       V.COD_OFI_CAMARA  COD_OFI_CAMARA,
       V.DESC_OFI_CAMARA DESC_OFI_CAMARA,
       V.COD_OFICINA     COD_OFICINA,
       V.DESC_OFICINA    DESC_OFICINA,
       V.NRO_CUENTA      NRO_CUENTA,
       V.MODULO          MODULO,
       V.TITULAR         TITULAR,
       V.MOTIVO          MOTIVO,
       V.BANCO           BANCO,
       V.NRO_CHEQUE      NRO_CHEQUE,
       V.COD_MONEDA      COD_MONEDA,
       V.IMPORTE         IMPORTE
  FROM (SELECT T.FECHA  FECHA,
          T.HORA,
          R.COD_OFICINA COD_OFI_CAMARA,
          FUE_OBT_DES_OFICINA(R.COD_OFICINA) DESC_OFI_CAMARA,
          T.COD_OFICINA COD_OFICINA,
          FUE_OBT_DES_OFICINA(substr(T.NRO_CUENTA, 1,2))  DESC_OFICINA,
          T.NRO_CUENTA NRO_CUENTA,
          B.DESCRIPCION MODULO,
          fug_obt_des_modalidad(t.COD_MODALIDAD) modalidad,
          FUE_OBT_NOM_PERSONA(A.COD_PERSONA) TITULAR,
          T.DES_CAUSA MOTIVO,
          FUG_OBT_DES_BANCO(T.COD_BANCO) BANCO,
          T.NRO_DOCUMENTO NRO_CHEQUE,
          T.COD_MONEDA,
          T.MONTO IMPORTE
           FROM GV_MOVIMIENTOS T,
                CC_CHE_REMITIDOS R,
                GE_CTA_CLIENTES A,
                BA_MODULOS B
          WHERE T.COD_TRA_PADRE = 321
           AND T.COD_TRANSACCION IN (522, 503)
           --AND T.COD_MODALIDAD IN (31, 41)
           AND T.REVERSADO = ''N''
           AND A.NRO_CUENTA = T.NRO_CUENTA
           AND A.COD_MODULO = B.COD_MODULO
       AND A.RELACION = ''P''
       AND T.NRO_DOCUMENTO = R.NRO_CHEQUE
       AND T.COD_BANCO = R.COD_BANCO
       AND R.FECHA = (SELECT MAX(V.FECHA)
                       FROM CC_CHE_REMITIDOS V
                      WHERE V.NRO_CHEQUE = R.NRO_CHEQUE
                        AND V.COD_BANCO = R.COD_BANCO
                        AND V.FECHA <= T.FECHA)
       UNION
       SELECT T.FECHA  FECHA,
          T.HORA,
          R.COD_OFICINA COD_OFI_CAMARA,
          FUE_OBT_DES_OFICINA(R.COD_OFICINA) DESC_OFI_CAMARA,
          T.COD_OFICINA COD_OFICINA,
          FUE_OBT_DES_OFICINA(substr(T.NRO_CUENTA, 1,2))  DESC_OFICINA,
          T.NRO_CUENTA NRO_CUENTA,
          B.DESCRIPCION MODULO,
          fug_obt_des_modalidad(t.COD_MODALIDAD) modalidad,
          FUE_OBT_NOM_PERSONA(A.COD_PERSONA) TITULAR,
          T.DES_CAUSA MOTIVO,
          FUG_OBT_DES_BANCO(T.COD_BANCO) BANCO,
          T.NRO_DOCUMENTO NRO_CHEQUE,
          T.COD_MONEDA,
          T.MONTO IMPORTE
           FROM GV_MOVIMIENTOS T,
                GE_CHE_CUSTODIAS R,
                GE_CTA_CLIENTES A,
                BA_MODULOS B
          WHERE T.COD_TRA_PADRE = 321
           AND T.COD_TRANSACCION IN (522, 503)
           AND T.REVERSADO = ''N''
           AND A.NRO_CUENTA = T.NRO_CUENTA
           AND A.COD_MODULO = B.COD_MODULO
       AND A.RELACION = ''P''
       AND T.NRO_DOCUMENTO = R.NRO_CHEQUE
       AND T.COD_BANCO = R.COD_BANCO) V
 WHERE (&'||'P_FILTROS)
 ORDER BY 1, 2, 6'
WHERE cod_consulta = 'CHE_DEVUEL';

COMMIT; 
