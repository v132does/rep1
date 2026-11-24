DECLARE
  v_sql LONG := q'[
	-- RESUMEN
SELECT
  m.tipo Tipo_Cartera,
  t.cod_moneda,
  p.nom_completo Entidad,
  t.fec_inicio Fecha_Desembolso,
  t.nro_cuenta,
  t.monto,
  t.mto_interes,
  t.fec_vencimiento Fecha_Vcto,
  t.cantidad cant_cuotas,
  t.val_tasa,
  (t.fec_vencimiento - t.fec_inicio) AS cant_dias,
  TO_CHAR(t.fec_vencimiento,'DD') dia,
  TO_CHAR(t.fec_vencimiento,'MM') mes,
  TO_CHAR(t.fec_vencimiento,'YYYY') año,
  CASE
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '01' THEN 'Enero'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '02' THEN 'Febrero'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '03' THEN 'Marzo'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '04' THEN 'Abril'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '05' THEN 'Mayo'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '06' THEN 'Junio'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '07' THEN 'Julio'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '08' THEN 'Agosto'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '09' THEN 'Setiembre'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '10' THEN 'Octubre'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '11' THEN 'Noviembre'
    WHEN TO_CHAR(t.fec_vencimiento,'MM') = '12' THEN 'Diciembre'
  END AS Descr_MES,
  NVL(t.sal_interes,0) Saldo_Interes,
  NVL(t.sal_capital,0) Saldo_capital,
  NVL(t.sal_capital,0) + NVL(t.sal_interes,0) Saldo_Documento,
  ((ROUND(SYSDATE - t.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
  CASE
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) > 0 THEN 'Vencido'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) = 0 THEN ' 0 Dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -30 AND -1 THEN 'AV. De 1 a 30 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -60 AND -31 THEN 'AV. De 31 a 60 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -90 AND -61 THEN 'AV. De 61 a 90 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -120 AND -91 THEN 'AV. De 91 a 120 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -150 AND -121 THEN 'AV. De 121 a 150 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -180 AND -151 THEN 'AV. De 151 a 180 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) BETWEEN -360 AND -181 THEN 'AV. De 181 a 360 dias'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) < -360 THEN 'AV. Mas de 360 dias'
  END AS Tramos,
  t.cod_modalidad,
  m.descripcion Desc_Modalidad,
  t.fec_ult_pago Fecha_Pago,
  t.fec_vencimiento - t.fec_inicio plazo,
  t.fec_vencimiento - TRUNC(SYSDATE) residual,
  CASE
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) <= 0 AND NVL(t.sal_capital,0) + NVL(t.sal_interes,0) > 0 THEN 'PENDIENTE'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) > 0 AND NVL(t.sal_capital,0) + NVL(t.sal_interes,0) > 0 THEN 'VENCIDO'
    WHEN ROUND(SYSDATE - t.fec_vencimiento, 0) > 0 AND NVL(t.sal_capital,0) + NVL(t.sal_interes,0) = 0 THEN 'PAGADO'
    ELSE NULL
  END est_pago,
  SUM(gg.mto_cuota) mto_garantia,
  gg.nro_cuenta nro_garantia,
  t.observacion obs_garantia,
  --
  ROUND(NVL(MAX(
    CASE 
      WHEN t.mer_secundario = 'S' THEN NVL(vp.md_sum,0)
      ELSE t.val_presente
    END
  ), 0), 2) AS val_presente,
  ROUND(NVL(md_devengado_agg.dev_diario, 0), 2) AS dev_diario,
  ROUND(NVL(md_devengado_agg.dev_acumulado, 0), 2) AS dev_acumulado_hoy,
  ROUND(NVL(t.val_int_devengar, 0), 2) AS a_devengar,
  ROUND(NVL(cap_diferido_diario_agg.cap_diferido_diario, 0), 2) AS cap_diferido_diario,
  ROUND(NVL(cap_diferido_acum_agg.cap_diferido_acum, 0), 2) AS cap_diferido_acum_hoy,
  ROUND(NVL(MAX(
       CASE 
          WHEN t.mer_secundario = 'S' THEN NVL(cap_a_diferir_agg.cap_a_diferir,0)
          ELSE 0            
       END
       ), 0), 2) AS cap_a_diferir
FROM it.md_cta_documentos t
    JOIN it.ge_cta_clientes c ON t.nro_cuenta = c.nro_cuenta
    JOIN it.ba_personas p ON c.cod_persona = p.cod_persona
    JOIN it.ge_modalidades m ON t.cod_modulo = m.cod_modulo AND t.cod_modalidad = m.cod_modalidad
    LEFT JOIN md_cuo_instrumentos gg ON gg.nro_cta_repo = t.nro_cuenta
    LEFT JOIN (
      SELECT
        d.nro_cuenta,
        SUM(NVL(d.dev_acumulado, 0)) + SUM(NVL(d.val_cap_presente, 0)) AS md_sum
      FROM md_doc_detalles d
      GROUP BY d.nro_cuenta
    ) vp ON vp.nro_cuenta = t.nro_cuenta
    LEFT JOIN (
      SELECT
        dev.nro_cuenta,
        SUM(NVL(dev.mto_dev_acumulado,0)) AS dev_acumulado, 
        SUM(NVL(dev.mto_dev_acumulado / NULLIF(dev.can_dia_interes, 0), 0)) AS dev_diario
      FROM md_devengados dev
      WHERE dev.estado = 'C'
        AND dev.val_tasa != 0
        AND dev.can_dia_interes > 0
      GROUP BY dev.nro_cuenta
    ) md_devengado_agg ON md_devengado_agg.nro_cuenta = t.nro_cuenta
    LEFT JOIN (
      SELECT
        dev.nro_cuenta,
        SUM(NVL(dev.mto_dev_acumulado / NULLIF(dev.can_dia_interes, 0), 0)) AS cap_diferido_diario
      FROM md_devengados dev
      WHERE dev.estado = 'C'
        AND dev.val_tasa = 0
        AND dev.can_dia_interes > 0
      GROUP BY dev.nro_cuenta
    ) cap_diferido_diario_agg ON cap_diferido_diario_agg.nro_cuenta = t.nro_cuenta
    LEFT JOIN (
      SELECT
        dev.nro_cuenta,
        SUM(NVL(dev.mto_dev_acumulado, 0)) AS cap_diferido_acum
      FROM md_devengados dev
      WHERE dev.estado = 'C'
        AND dev.val_tasa = 0
      GROUP BY dev.nro_cuenta
    ) cap_diferido_acum_agg ON cap_diferido_acum_agg.nro_cuenta = t.nro_cuenta
    LEFT JOIN (
      SELECT
        md.nro_cuenta,
        SUM(NVL(md.mto_capital, 0)) - (SUM(NVL(md.dev_acumulado, 0)) + SUM(NVL(md.val_cap_presente, 0))) + 
        (SUM(NVL(md.mto_interes, 0)) - SUM(NVL(md.dev_acumulado, 0))) AS cap_a_diferir
      FROM md_doc_detalles md
      GROUP BY md.nro_cuenta
    ) cap_a_diferir_agg ON cap_a_diferir_agg.nro_cuenta = t.nro_cuenta
WHERE
  c.relacion = 'P'
  AND t.cod_modulo = 10
  AND t.cod_modalidad <> 119
  AND t.estado NOT IN ('S','N')
GROUP BY
  m.tipo,
  t.cod_moneda,
  p.nom_completo,
  t.fec_inicio,
  t.nro_cuenta,
  t.monto,
  t.mto_interes,
  t.fec_vencimiento,
  t.cantidad,
  t.val_tasa,
  t.sal_interes,
  t.sal_capital,
  t.cod_modalidad,
  m.descripcion,
  t.fec_ult_pago,
  gg.nro_cuenta,
  t.observacion,
  md_devengado_agg.dev_acumulado,
  t.val_int_devengar,
  md_devengado_agg.dev_diario,
  cap_diferido_diario_agg.cap_diferido_diario,
  cap_diferido_acum_agg.cap_diferido_acum,
  cap_a_diferir_agg.cap_a_diferir
UNION
Select  distinct m.tipo Tipo_Cartera, t.cod_moneda, p.nom_completo Entidad,  t.fec_apertura Fecha_Desembolso, t.nro_cuenta,
	t.sal_total, (select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta) to_interes,
	t.fec_vencimiento Fecha_Vcto,  0 cant_cuotas, fug_obt_val_tasa(t.cod_modulo, t.cod_modalidad, null, null, t.cod_moneda, null, null, t.cod_tasa, null, t.fec_vencimiento) val_tasa, (t.fec_vencimiento - t.fec_apertura) as cant_dias ,
	to_char(t.fec_vencimiento,'DD') dia,
	to_char(t.fec_vencimiento,'MM') mes,
	to_char(t.fec_vencimiento,'YYYY') año,
	case
	When to_char(t.fec_vencimiento,'MM') = '01' then 'Enero'
	When to_char(t.fec_vencimiento,'MM') = '02' then 'Febrero'
	When to_char(t.fec_vencimiento,'MM') = '03' then 'Marzo'
	When to_char(t.fec_vencimiento,'MM') = '04' then 'Abril'
	When to_char(t.fec_vencimiento,'MM') = '05' then 'Mayo'
	When to_char(t.fec_vencimiento,'MM') = '06' then 'Junio'
	When to_char(t.fec_vencimiento,'MM') = '07' then 'Julio'
	When to_char(t.fec_vencimiento,'MM') = '08' then 'Agosto'
	When to_char(t.fec_vencimiento,'MM') = '09' then 'Setiembre'
	When to_char(t.fec_vencimiento,'MM') = '10' then 'Octubre'
	When to_char(t.fec_vencimiento,'MM') = '11' then 'Noviembre'
	When to_char(t.fec_vencimiento,'MM') = '12' then 'Diciembre'
	end as Descr_MES,
	(select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta and cu.estado = 'E') Saldo_Interes,
	t.capital Saldo_capital,
	(select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta and cu.estado = 'E') + t.capital Saldo_Documento ,
	((round(sysdate - t.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
	case
	when round(sysdate - t.fec_vencimiento, 0) > 0 then                      'Vencido'
	when round(sysdate - t.fec_vencimiento, 0) = 0 then                      ' 0 Dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 30  and - 1   then  'AV. De 1 a 30 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 60  and - 31  then  'AV. De 31 a 60 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 90  and - 61  then  'AV. De 61 a 90 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 120 and - 91  then  'AV. De 91 a 120 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 150 and - 121 then  'AV. De 121 a 150 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 180 and - 151 then  'AV. De 151 a 180 dias'
	when round(sysdate - t.fec_vencimiento, 0) between - 360 and - 181 then  'AV. De 181 a 360 dias'
	when round(sysdate - t.fec_vencimiento, 0) < -360 then                   'AV. Mas de 360 dias'
	end as Tramos,
	t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_movimiento Fecha_Pago, t.fec_vencimiento - t.fec_apertura plazo,
	t.fec_vencimiento - trunc(sysdate) residual,
	case
	when round(sysdate - t.fec_vencimiento, 0) < 0 and nvl(t.sal_total,0)  > 0 then  'PENDIENTE'
	when round(sysdate - t.fec_vencimiento, 0) > 0 and nvl(t.sal_total,0)  > 0 then  'VENCIDO'
	when round(sysdate - t.fec_vencimiento, 0) > 0 and nvl(t.sal_total,0)  = 0 then  'PAGADO'
		else null end est_pago,
    null mto_garantia,
	null nro_garantia,
	null obs_garantia,
	--
	null val_presente,
	null dev_diario,
	null dev_acumulado_hoy,
	null a_devengar,
	null cap_diferido_diario,
	null cap_diferido_acum_hoy,
	null cap_a_diferir
	--
from it.ah_cta_certificados t, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
where t.nro_cuenta  = t.nro_cuenta
	and   t.nro_cuenta  = c.nro_cuenta
	and   c.relacion    = 'P'
	and   c.cod_persona = p.cod_persona
	and   t.cod_modulo    = 3
	and   t.cod_modulo    = m.cod_modulo
	and   t.cod_modalidad = m.cod_modalidad
	and   t.cod_modalidad = 36
	and   t.cod_tasa = t.cod_tasa
order by  1, 2, 4, 5]';

BEGIN

    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;

    UPDATE ba_consultas
    SET det_sql = v_sql
    WHERE cod_consulta = 'CD_PRE_BCO';

    DBMS_OUTPUT.PUT_LINE('Datos actualizados.');

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al intentar actualizar.');
END;
/
