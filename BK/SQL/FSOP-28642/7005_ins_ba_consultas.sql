BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_DCH_MOV', 'Deposito de Cheques en ATM', NULL, 'G', NULL, 'En este reporte se puede obtener todas las transacciones de Deposito de cheques en TED', 'SELECT to_char(a.fecha, ''dd/MM/YYYY'') AS fecha,
       a.nombre_completo  AS nombre_depositante,
       a.atm_id           AS atm_id,
       a.lote             AS lote,
       a.transaccion      AS nro_transaccion,
       a.numero_cheque    AS numero_cheque,
       a.cod_banco        AS cod_banco,
       a.banco            AS banco,
       a.monto            AS monto,
       a.moneda           AS moneda,
       a.tipo_transaccion AS tipo_transaccion,
       a.nro_boleta       AS nro_boleta,
       a.numero_cuenta    AS numero_de_cuenta,
       a.cod_persona      AS cod_persona,
       a.can_cheque       AS cantidad_cheque
  FROM (SELECT TRUNC(cd.fecha) AS fecha,
               cd.nom_completo AS nombre_completo,
               cd.nro_documento AS nro_doc_depositante,
               cd.atm_id AS atm_id,
               cd.cod_lote AS lote,
               cd.nro_transaccion AS transaccion,
               g.nro_documento AS nro_boleta,
               cd.cod_cheque AS numero_cheque,
               gb.cod_banco AS cod_banco,
               gb.descripcion AS banco,
               g.cod_moneda AS moneda,
               cd.tip_transaccion AS tipo_transaccion,
               cd.nro_cuenta AS numero_cuenta,
               cd.cod_persona AS cod_persona,
               cd.monto_cheque AS monto,
               (SELECT COUNT(*)
                  FROM cj_dep_chq_atm_reg cc
                 WHERE cc.cod_lote = cd.cod_lote) can_cheque,
               g.nro_documento
          FROM cj_dep_chq_atm_reg cd
          JOIN ge_bancos gb
            ON to_number(cd.cod_banco) = gb.cod_banco
          JOIN gv_movimientos g
            ON g.cod_tra_padre = 395
           AND g.estado        = ''N''
           AND g.reversado     = ''N''
           AND g.concepto = cd.tip_documento || cd.nro_documento
           AND g.nro_cuenta = cd.nro_cuenta
           AND g.fec_valor = trunc(cd.fecha)
         WHERE cd.tip_transaccion IN
               (''deposito_che_clie'', ''deposito_che_no_clie'')
         ORDER BY cd.fecha DESC) a
 WHERE &'||'P_FILTROS', 'ROWNUM IS NOT NULL', null, NULL);

COMMIT;
