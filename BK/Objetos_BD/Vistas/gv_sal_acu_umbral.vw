CREATE OR REPLACE VIEW IT.GV_SAL_ACU_UMBRAL AS
WITH params AS (
    SELECT
        pag_cal.fu_obt_fec_actual(3) as fec_base,
        fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_GS') as f_gs,
        fug_obt_pardinamico('COD_GRU_TRA_UMBRAL')    as f_ext,
        fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_GS_J') as j_gs,
        fug_obt_pardinamico('COD_GRU_TRA_UMBRAL_J')    as j_ext
    FROM dual
),
periodo AS (
    SELECT TRUNC(fec_base, 'MM') as fec_ini, LAST_DAY(fec_base) as fec_fin FROM params
),
movimientos AS (
    SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_transaccion, fecha, hora, cod_moneda, monto, estado, reversado FROM ge_movimientos
    UNION ALL
    SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_transaccion, fecha, hora, cod_moneda, monto, estado, reversado FROM ah_movimientos_his
    UNION ALL
    SELECT nro_cuenta, cod_modulo, cod_modalidad, cod_transaccion, fecha, hora, cod_moneda, monto, estado, reversado FROM cc_movimientos_his
)
SELECT p.cod_persona, p.nro_documento, p.nom_completo, x.nro_cuenta,a.fecha, a.hora, b.cod_transaccion, b.descripcion, a.cod_moneda,
    CASE fug_obt_tra_tipo(b.cod_transaccion, b.tipo, b.afecta)
        WHEN 'C' THEN NVL(a.monto, 0)
        ELSE 0
    END AS tot_credito
FROM movimientos a
JOIN ge_transacciones b ON a.cod_modulo = b.cod_modulo
                       AND a.cod_modalidad = b.cod_modalidad
                       AND a.cod_transaccion = b.cod_transaccion
JOIN ge_cuentas x      ON a.nro_cuenta = x.nro_cuenta
JOIN ge_cta_clientes c ON x.nro_cuenta = c.nro_cuenta
JOIN ba_personas p     ON c.cod_persona = p.cod_persona
JOIN ge_gru_transacciones_det d ON a.cod_modulo = d.cod_modulo
                               AND a.cod_modalidad = d.cod_modalidad
                               AND a.cod_transaccion = d.cod_transaccion
CROSS JOIN params k
CROSS JOIN periodo r
WHERE a.fecha BETWEEN r.fec_ini AND r.fec_fin
  AND a.estado IN ('N', 'P')
  AND a.reversado = 'N'
  AND b.ve_cliente = 'S'
  AND b.tipo IN ('C', 'D')
  AND NVL(b.afecta, 'XX') != 'B'
  AND c.relacion = 'P'
  AND p.tipo IN ('F', 'J')
  -- Lógica unificada de Umbral
  AND d.cod_gru_transaccion = CASE
        WHEN p.tipo = 'F' AND x.cod_moneda = 'GS' THEN k.f_gs
        WHEN p.tipo = 'F' AND x.cod_moneda <> 'GS' THEN k.f_ext
        WHEN p.tipo = 'J' AND x.cod_moneda = 'GS' THEN k.j_gs
        ELSE k.j_ext
      END
;
