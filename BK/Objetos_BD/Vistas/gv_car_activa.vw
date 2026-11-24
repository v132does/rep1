CREATE OR REPLACE VIEW IT.GV_CAR_ACTIVA AS
WITH
 MAX_DIRECCION_L AS (
    SELECT COD_PERSONA,
        MAX(COD_DIRECCION) AS COD_DIRECCION
    FROM BA_DIRECCIONES
    WHERE TIPO = 'L'
    GROUP BY COD_PERSONA
)
, MAX_DIRECCION_P AS (
    SELECT COD_PERSONA,
        MAX(COD_DIRECCION) AS COD_DIRECCION
    FROM BA_DIRECCIONES
    WHERE TIPO = 'P'
    GROUP BY COD_PERSONA
)
, ULT_OFERTA AS (
    SELECT
        COD_PERSONA,
        MAX(COD_REGISTRO) AS MAX_COD_REGISTRO
    FROM BA_PER_GEN_OFERTAS
    GROUP BY COD_PERSONA
)
, ULT_INGRESO AS (
    SELECT
        COD_PERSONA,
        MAX(COD_ING_CLIENTE) AS MAX_COD_ING_CLIENTE
    FROM GE_ING_CLIENTES
    GROUP BY COD_PERSONA
)
, ULT_PREVISON as (
  SELECT
    nro_cuenta, MAX(fecha) as MAX_FECHA
    FROM pr_previsiones
    group by NRO_CUENTA
)
, ULT_PREV_TAR as (
  SELECT
    nro_cuenta, MAX(fecha) as fecha
    FROM ta_previsiones
    group by NRO_CUENTA
)
, ULT_TASA as (
  SELECT
    NRO_CUENTA, MAX(FEC_INSERCION) as MAX_FEC_INSERCION
    FROM SB_TAS_APE_SEMANALES
    group by NRO_CUENTA
)
, ULT_SOL_GEST as (
  SELECT
    NRO_SOLICITUD, ESTADO, MAX(FECHA) as MAX_FECHA
    FROM PR_SOL_GESTIONES
    group by NRO_SOLICITUD, ESTADO
)
, MAX_NRO_GAR as (
  SELECT max(C.nro_garantia) nro_garantia, C.nro_cuenta
    FROM PR_CTA_GARANTIAS C
    group by nro_cuenta

)
, MAX_COD_GAR as (
  SELECT MAX(C.cod_garantia) cod_garantia, C.nro_garantia
    FROM PR_CTA_GARANTIAS C
    group by C.nro_garantia

)
/* MODFICACION A LA LOGICA CON UN SUM PORQUE PODIA FALLAR Y TRAER LAS CUOTAS */
, SUM_MTO_INT_DOCUMENTADO AS (
    SELECT NRO_CUENTA, SUM(MTO_INT_DOCUMENTADO) MTO_INT_DOCUMENTADO
    FROM pr_cuotas GROUP BY NRO_CUENTA
)
, max_ge as (
  SELECT nro_solicitud, estado, max(fecha) fecha
  FROM PR_SOL_GESTIONES
  where ESTADO = 'L'
  GROUP BY nro_solicitud, estado
)
, MAX_PREVISION_TAR AS (
  SELECT NVL(a.monto, 0) as MONTO, A.NRO_CUENTA
    FROM ta_previsiones a
    INNER JOIN ULT_PREV_TAR up ON up.fecha = a.fecha AND up.nro_cuenta = a.nro_cuenta
)
/* FUNCIONES */
, DES_EST_CTA as (
    SELECT *
    FROM ge_est_cuentas
)
, des_refcodes as (
  SELECT * FROM ba_cod_referencias   a 
)
, OBT_COTIZACION as (
  SELECT C.fecha, C.cod_moneda, C.val_conversion
  FROM (
      SELECT g.cod_moneda, MAX(g.fecha) AS max_fecha
      FROM ge_cotizaciones g
      GROUP BY g.cod_moneda
  ) B
  LEFT JOIN ge_cotizaciones C ON B.cod_moneda = C.cod_moneda AND B.max_fecha = C.fecha
)
/* CALCULOS ESPECIFICOS */

, TIENE_CAH AS (
    SELECT
         CT.COD_PERSONA,
         CASE
            WHEN (SELECT COUNT(*)
                FROM AH_CTA_VISTAS AHE, GE_CTA_CLIENTES GTE
                WHERE AHE.NRO_CUENTA = GTE.NRO_CUENTA AND GTE.COD_PERSONA = CT.COD_PERSONA AND GTE.RELACION = 'P'
            ) >= 1 THEN 'SI'
            ELSE 'NO'
        END AS CAJA_DE_AHORRO
    FROM BA_PERSONAS CT
)
, ES_GARANTE AS (
  SELECT
    CT.COD_PERSONA,
    CASE
        WHEN (SELECT COUNT(*)
            FROM GE_CTA_CLIENTES G
            WHERE G.RELACION IN ('C', 'G') AND G.COD_PERSONA = CT.COD_PERSONA
        ) >= 1 THEN 'SI'
        ELSE 'NO'
    END AS GARANTE
  FROM BA_PERSONAS CT
)
, CODEUDORIA AS (
  SELECT
    CTA.NRO_CUENTA,
        CTA.COD_PERSONA,
    CASE
        WHEN (SELECT COUNT(*)
            FROM GE_CTA_CLIENTES G
            WHERE G.RELACION = 'C' AND G.COD_PERSONA = CTA.COD_PERSONA and G.NRO_CUENTA=CTA.NRO_CUENTA ) >= 1 THEN 'SI'
        ELSE 'NO'
    END AS CODEUDORIA
  FROM ge_cta_clientes CTA
)
, NRO_CTA_RENOVADA AS (
  SELECT MAX(ic.nro_cuenta) MAX_NRO_CTA_RENOVADA, NRO_CTA_RENOVADA
  FROM PR_CTA_PRESTAMOS ic
  GROUP BY NRO_CTA_RENOVADA
)
, CAPITAL_PENDIENTE AS (
  SELECT SUM(NVL(PR.MTO_CAPITAL, 0)) MTO_CAPITAL_PEND, PR.NRO_CUENTA
  FROM PR_CUOTAS PR
  WHERE PR.ESTADO <> 'N'
  GROUP BY PR.NRO_CUENTA
)
, CAPITAL_PAGADO AS (
  SELECT SUM(NVL(PR.MTO_CAPITAL, 0)) MTO_CAPITAL_PAG, PR.NRO_CUENTA
  FROM PR_CUOTAS PR
  WHERE PR.ESTADO = 'N'
  GROUP BY PR.NRO_CUENTA
)
, ING_ANUAL AS (
  SELECT sum(PR.importe) INGRESO_ANUAL, PR.cod_persona
  FROM CR_PER_ING_EGRESOS PR
  WHERE PR.ING_EGRESO = 'I'
  AND PR.FRECUENCIA = 'A'
  AND PR.importe > 0
  GROUP BY PR.cod_persona
)
, GARANTIA AS (
  SELECT TG.COD_GARANTIA || '-' || TG.DESCRIPCION AS GARANTIA_DESC, g.NRO_CUENTA
  FROM PR_CTA_GARANTIAS G
  INNER JOIN PR_GAR_TIPOS TG ON TG.COD_GARANTIA = G.COD_GARANTIA
  inner join MAX_NRO_GAR
    on MAX_NRO_GAR.nro_garantia = G.nro_garantia and MAX_NRO_GAR.nro_cuenta = g.nro_cuenta
  inner join MAX_COD_GAR
    on MAX_COD_GAR.COD_GARANTIA = G.COD_GARANTIA AND MAX_COD_GAR.nro_garantia = G.nro_garantia
)
, CARGOS AS  (
  SELECT NVL(SUM(NVL(CAR.MONTO, 0)), 0) MONTO, COD_TRANSACCION, NRO_SOLICITUD
  FROM PR_SOL_CARGOS CAR
  WHERE COD_TRANSACCION IN ('736','1270','704')
  GROUP BY COD_TRANSACCION, NRO_SOLICITUD
)
, desc_plazo as
(
     SELECT case when a.descripcion = 'VISTA' then '0'
            when a.descripcion like '%ENTRE%' THEN TRIM(substr(descripcion, 7,3))
            when a.descripcion LIKE 'MENOR%' THEN '1'
            else '1081'
        end as mini,
        case when a.descripcion = 'VISTA' then '0'
            when a.descripcion like '%ENTRE%' THEN to_char(CAN_DIAS)
            when a.descripcion LIKE 'MENOR%' THEN to_char(CAN_DIAS)
            else '9999'
        end as maxi,
        a.*
        FROM ge_plz_contables a
)
, DEPARTAMENTO AS (
    SELECT DEP.DESCRIPCION, DIC.COD_PERSONA
    FROM BA_DIRECCIONES DIC
    INNER JOIN BA_CIUDADES CIU
      ON CIU.COD_PAIS = DIC.COD_PAIS AND CIU.COD_CIUDAD = DIC.COD_CIUDAD
    INNER JOIN BA_DEPARTAMENTOS DEP
      ON DEP.COD_DEPARTAMENTO = CIU.COD_DEPARTAMENTO
    WHERE DIC.PRINCIPAL = 'S'
    and dic.fec_insercion = (select max(fec_insercion) /*POR REGISTROS ELIMINADOS DE BA_DIRECCIONES*/
                                            from BA_DIRECCIONES d
                                            where d.cod_persona=dic.COD_PERSONA and d.principal='S')
)/* CONJUNTO DE TABLAS */
, datos_mod_modalidad as (
  select
    m.cod_modulo, g.cod_modalidad, m.descripcion as desc_modulo, g.descripcion as desc_modalidad, s.cod_sub_modalidad as cod_sub_modalidad, s.descripcion as desc_sub_modalidad
  from ba_modulos m
  left join ge_modalidades g on g.cod_modulo = m.cod_modulo
  left join ge_sub_modalidades s on s.cod_modulo = m.cod_modulo and s.cod_modalidad = g.cod_modalidad
)
, datos_cta_persona as ( --SE PUEDE USAR PARA TODOS LOS BLOQUES
  select
    CT.NRO_CUENTA
    ,P.COD_PERSONA
      ,P.nom_completo
      ,P.cod_actividad
      ,P.NRO_DOCUMENTO
      ,P.TIPO
      ,P.COD_USU_PROMOTOR
    ,P.TOT_INGRESOS
    ,P.DIR_CORREO
      ,PF.COD_SEXO
      ,PF.FEC_NACIMIENTO
      ,CL.cod_usu_oficial
    ,CL.cod_seg_cliente
    ,CL.cat_automatica
    ,CL.cat_riesgo
    ,CL.cat_sistema
    ,CL.cod_sec_contable
    ,CL.cod_tip_deudor
    ,CL.tipo as COD_TIP_CLIENTE
    ,CL.COD_GRU_ECONOMICO
    ,CL.CLI_CONFIDENCIAL
    ,CL.CLI_ESPECIAL
    ,GSC.descripcion as des_segmento
    ,SE.descripcion as SEC_CONTABLE
    ,DE.descripcion as TIP_DEUDOR
    ,ac.descripcion as desc_actividad
    ,bu.nombre as nombre_promotor
    ,ci_dp.descripcion as desc_ciu_particular
    ,ci_dl.descripcion as desc_ciu_laboral
    ,tc.SIGNIFICADO as TIP_CLIENTE
    ,DL.COD_CIUDAD as COD_CIUDAD_LAB
    ,DP.COD_CIUDAD as COD_CIUDAD_PAR
    ,cah.CAJA_DE_AHORRO
    ,ru.DESCRIPCION as DES_GRU_ECONOMICO
    ,btda.fec_insercion as FECHA_ONBOARDING
    ,dep.DESCRIPCION as DEPARTAMENTO
    ,IG.INGRESO_ANUAL
    ,EG.GARANTE
    ,G.GARANTIA_DESC
    ,CO.CODEUDORIA
    ,ct.relacion
    ,ct.cod_modulo
    ,ct.cod_modalidad
  FROM ge_cta_clientes CT
  INNER JOIN ge_clientes cl
      ON CL.cod_persona = CT.cod_persona
  INNER JOIN ba_personas P
      ON P.cod_persona = CT.cod_persona
  LEFT JOIN ba_per_Fisicas PF
      ON PF.cod_persona = P.cod_persona
  LEFT JOIN ge_sec_contables SE
      ON SE.cod_sec_contable = CL.cod_sec_contable
  LEFT JOIN ge_tip_deudores DE
      ON DE.cod_tip_deudor = CL.cod_tip_deudor
      AND SE.cod_sec_contable = DE.cod_sec_contable
  LEFT JOIN GE_SEG_CLIENTES GSC
      ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE
  LEFT JOIN MAX_DIRECCION_L MD ON MD.COD_PERSONA = P.COD_PERSONA
    LEFT JOIN BA_DIRECCIONES DL ON DL.COD_PERSONA = MD.COD_PERSONA AND MD.COD_DIRECCION = DL.COD_DIRECCION
  LEFT JOIN MAX_DIRECCION_P MP ON MP.COD_PERSONA = P.COD_PERSONA
    LEFT JOIN BA_DIRECCIONES DP ON DP.COD_PERSONA = MP.COD_PERSONA AND MP.COD_DIRECCION = DP.COD_DIRECCION
  left join ba_CIUDADES ci_dp on ci_dp.cod_pais = dp.cod_pais and ci_dp.cod_ciudad = dp.cod_ciudad
  left join ba_CIUDADES ci_dl on ci_dl.cod_pais = dl.cod_pais and ci_dl.cod_ciudad = dl.cod_ciudad
  left join ge_actividades AC on ac.cod_actividad = p.cod_actividad 
  left join des_refcodes tc on tc.dominio = 'TIP_CLIENTE' and tc.val_minimo = CL.TIPO  
  left join ba_usuarios bu on bu.cod_usuario = p.COD_USU_PROMOTOR 
  left join TIENE_CAH cah on cah.cod_persona = p.cod_persona
  left join GE_GRU_ECONOMICOS ru on ru.COD_GRU_ECONOMICO = CL.COD_GRU_ECONOMICO
  left join BA_TAB_DAT_ADICIONALES btda on btda.REFERENCIA = p.cod_persona AND btda.parametro LIKE 'CELULAR_ONBOARDING'
  left join DEPARTAMENTO dep on dep.cod_persona = p.cod_persona
  LEFT JOIN CODEUDORIA CO ON CO.NRO_CUENTA = CT.NRO_CUENTA AND CO.COD_PERSONA = P.COD_PERSONA
  LEFT JOIN ES_GARANTE EG ON EG.COD_PERSONA = P.COD_PERSONA
  LEFT JOIN ING_ANUAL IG ON IG.COD_PERSONA = P.COD_PERSONA
  LEFT JOIN GARANTIA G ON G.NRO_CUENTA = CT.NRO_CUENTA
  WHERE
    ct.relacion = 'P'
)
, RELACIONES as (
     SELECT
        PE.NRO_CUENTA,
        e.descripcion AS ESTADO,
        CUN.COD_MONEDA,
        NVL(SUM(CASE WHEN RELACION = 'Y' THEN 1 ELSE 0 END), 0) AS CONJUNTA,
        NVL(SUM(CASE WHEN RELACION = 'P' THEN 1 ELSE 0 END), 0) AS PRINCIPAL,
        NVL(SUM(CASE WHEN RELACION = 'O' THEN 1 ELSE 0 END), 0) AS INDISTINTA
    FROM (
        SELECT
            COUNT(*) AS CANTIDAD,
            gcc.RELACION,
            gcc.NRO_CUENTA,
            gcc.COD_MODULO,
            gcc.COD_MODALIDAD
        FROM GE_CTA_CLIENTES gcc
        WHERE gcc.RELACION IN ('Y', 'P', 'O') AND gcc.COD_MODULO = '3'
        GROUP BY gcc.NRO_CUENTA, gcc.COD_MODULO, gcc.COD_MODALIDAD, gcc.RELACION
    ) PE
    INNER JOIN AH_CTA_VISTAS CUN ON CUN.NRO_CUENTA = PE.NRO_CUENTA
    LEFT JOIN DES_EST_CTA e ON e.cod_modulo = PE.COD_MODULO AND e.cod_modalidad = PE.COD_MODALIDAD AND e.estado = CUN.ESTADO
    GROUP BY PE.NRO_CUENTA, e.descripcion, CUN.COD_MONEDA
)
, INGRESOS AS (
  SELECT
    gi.cod_persona as cod_persona,
    estado,
    gi.TIP_INGRESO cod_tip_ingreso,
    case
      when gi.TIP_INGRESO = null then 'Sin Ingreso'
      else d.abreviatura
      end AS tip_ingreso,
    NVL(gi.MON_INGRESO, 0) AS MON_INGRESO,
    NVL(fo.mto_ingreso, 0) AS MTO_ING_OFR
  FROM GE_ING_CLIENTES gi
  LEFT JOIN ULT_OFERTA UO ON UO.COD_PERSONA = gi.COD_PERSONA
  LEFT JOIN BA_PER_GEN_OFERTAS fo ON fo.COD_REGISTRO = UO.MAX_COD_REGISTRO AND fo.cod_persona = uo.cod_persona
  LEFT JOIN ULT_INGRESO UI ON UI.COD_PERSONA = GI.COD_PERSONA AND gi.cod_ing_cliente = UI.MAX_COD_ING_CLIENTE
  LEFT JOIN des_refcodes D ON D.dominio = 'TIP_INGRESO' AND d.val_minimo = gi.tip_ingreso
  WHERE  gi.ESTADO <> 'C'
  AND gi.cod_ing_cliente = UI.MAX_COD_ING_CLIENTE
)


,datos_cc as (
select 
to_char(pag_cal.fu_obt_fec_actual(6), 'yyyy-mm-dd') as FECHA_PROCESO
,cc.cod_modulo as modulo_cod
,mm.desc_modulo as modulo
,cc.cod_modalidad as modalidad_cod
,mm.desc_modalidad as modalidad
,cc.cod_sub_modalidad as sub_modalidad_cod
,mm.desc_sub_modalidad as sub_modalidad
,cta.cod_persona as cod_persona
,cta.nom_completo as nombre_cliente
,cta.cod_actividad as cod_actividad
,cta.desc_actividad as des_actividad
,cta.nro_documento as nrodoc
,cta.tipo as tipopersona
,cta.cod_sexo as sexo
,cta.fec_nacimiento as fec_nacimiento
,TRUNC(((pag_cal.fu_obt_fec_actual(6)) - CTA.FEC_NACIMIENTO) / 365.25) AS edad
,cc.nro_cuenta
,cc.dig_verificador as digito_verificador
,cc.cod_moneda
,co.val_conversion as cotizacion
,cc.cod_oficina as sucursal_cod
,ofi.descripcion as sucursal
,cc.estado as estado_cod
,est.descripcion as estado
,null as monto_desembolsado_or
,cc.sal_total * -1  as saldo_or
,cc.sal_total * -1  as cartera_total_or
,CASE
    WHEN nvl(cc.dia_atraso, 0) > 60 THEN cc.sal_total * -1
    ELSE 0
END AS cartera_vencida_or
,CASE
    WHEN nvl(cc.dia_atraso, 0) <= 60 THEN cc.sal_total * -1
    ELSE 0
END AS cartera_vigente_or

,null as monto_desembolsado_gs

,case when cc.cod_moneda = 'USD' then nvl(cc.sal_total * -1, 0) * co.val_conversion
      else nvl(cc.sal_total * -1, 0) end as saldo_gs
      
,case when cc.cod_moneda = 'USD' then nvl(cc.sal_total * -1, 0) * co.val_conversion 
      else nvl(cc.sal_total * -1, 0) end as cartera_total_gs
,case
	        when nvl(cc.dia_atraso, 0) > 60 then
	            case
	                when cc.cod_moneda = 'USD' then 
						cc.sal_total * co.val_conversion
	                else 
						cc.sal_total
	            end
    else 0 end as cartera_vencida_gs
,case when nvl(cc.dia_atraso, 0) <= 60 then  
    	case when cc.cod_moneda = 'USD' then nvl(cc.sal_total * -1, 0) * co.val_conversion else  nvl(cc.sal_total * -1, 0)  end 
    else 0 end as cartera_vigente_gs
    
,null as monto_desembolsado_dls
,case when cc.cod_moneda = 'GS' then  nvl(cc.sal_total * -1, 0) / co_usd.val_conversion 
      else nvl(cc.sal_total * -1, 0) end as saldo_dls

,case
    when cc.cod_moneda = 'GS' then nvl(cc.sal_total * -1, 0)  / co_usd.val_conversion
    else 
        nvl(cc.sal_total * -1, 0)
    end as cartera_total_dls
    
,case
	        when nvl(cc.dia_atraso, 0) > 60 then
	            case
	                when cc.cod_moneda = 'GS' then 
						 cc.sal_total / co_usd.val_conversion
	                else 
						cc.sal_total
	            end
    else 0 end as cartera_vencida_dls
,case
	        when nvl(cc.dia_atraso , 0) > 60 then
	            case
	                when cc.cod_moneda = 'GS' then 
						cc.sal_total / co_usd.val_conversion
	                else 
						cc.sal_total
	            end
    else 0 end as cartera_vigente_dls
    
,0 as sal_interes_or
,0 as a_devengar_or
,0 as dev_acumulado_or
,0 as dev_no_cobrado_or
,0 as dev_suspenso_or
,nvl(prev.monto,0) as prevision_or 
,0 as sal_interes_gs
,0 as a_devengar_gs
,0 as dev_acumulado_gs
,0 as dev_no_cobrado_gs
,0 as dev_suspenso_gs
,0 as prevision_gs
,0 as sal_interes_dls
,0 as a_devengar_dls
,0 as dev_acumulado_dls
,0 as dev_no_cobrado_dls
,0 as dev_suspenso_dls
,case
    when cc.cod_moneda = 'GS' then 
        nvl(prev.monto, 0)  / co_usd.val_conversion
    else 
        nvl(prev.monto, 0) 
    end as prevision_dls
,cc.cod_usu_promotor as asesor
,cc.fec_apertura as emision
,sob.fec_vencimiento as vencimiento 
,null as plazo
,null des_plazo--plazo.descripcion as des_plazo 
,cast('26.76' as decimal(18,2)) as tasa --63
,cc.dia_atraso as dias_atraso
,cc.max_atraso as max_atraso
,cc.pro_atraso as pro_atraso
,null as per_vto_capital
,cta.cod_seg_cliente cod_segmento
,cta.des_segmento segmento
,cc.en_juicio as judicializado --70
,null as can_cuotas
,null as can_cuotas_pag
,null as can_cuotas_pend
,cta.cat_automatica
,cta.cat_riesgo
,cta.cat_sistema
,null as tip_destino
,null as des_destino
,cc.cod_campana as cod_campana --79
,cam.descripcion as des_campana
,cc.cod_canal as cod_canal
,can.descripcion as des_canal
,null as amortizacion
,null as tip_amortizacion
,null as tip_interes
,cta.cod_sec_contable
,cta.sec_contable
,cta.cod_tip_deudor
,cta.tip_deudor --89
,cta.cod_tip_cliente
,cta.tip_cliente
,null as nro_terjeta
,null as cta_bancard
,null as afinidad
,null as des_afinidad
,null as mto_pag_minimo
,nvl(sob.monto_linea,0) as linea_credito 
,nvl(sob.sal_disponible * -1,0) as linea_disponible
,null as producto
,null as producto_comision
,null as cartera
,null as cod_cedente
,null as emp_cedente
,null as val_cedente
,null as asociacion
,cta.caja_de_ahorro
,cta.cod_usu_promotor as usu_promotor
,cta.garante
,cta.codeudoria
,null as ingr_mensual
,cta.cod_ciudad_par
,cta.desc_ciu_particular as ciudad_par
,cta.cod_ciudad_lab
,cta.desc_ciu_laboral ciudad_lab
,null as tel_principal
,nvl(cc.mto_mora,0) as monto_mora_or
,case
	    when cc.cod_moneda = 'USD' then
	      nvl(cc.mto_mora,0) * co.val_conversion
	    else
	      nvl(cc.mto_mora,0)
	  end as monto_mora_gs
,case
	    when cc.cod_moneda = 'GS' then
	      nvl(cc.mto_mora,0)  / co_usd.val_conversion
	    else
	      nvl(cc.mto_mora,0)
	  end as monto_mora_dls
,null as tipo_renovacion_r
,null as nro_cta_renovada
,cta.dir_correo as correo
,null as nro_solicitud
,null as previsiones_r1
,null as previsiones_cartera_r1
,null as previsiones_diferidas_r1
,null as previsiones_orden_r1
,null as capital_inicial_gs
,null as capital_pend_gs
,null as capital_pagado_gs
,null as cod_des_especifico
,null as tip_des_especifico
,cta.fecha_onboarding
,cta.ingreso_anual as ingresos_anuales
,cta.departamento
,cta.garantia_desc as garantia
,null as val_tas_nominal
,null as val_tas_efectiva
,null as mto_seg_vida
,null as mto_seg_incap
,null as mto_com_desem
,null as usu_aprobador
,cta.cli_confidencial
,cta.cli_especial
,null  as cob_automatico 
,null as nro_cta_debito
,null as est_cta_debito
,null as moneda_cta_debito
,null as rel_cta_debito
,ir.tip_ingreso
,nvl(ir.mon_ingreso, 0) as mto_ingreso_app
,nvl(ir.mto_ing_ofr, 0) as mto_ing_ofr
,null as cod_rub_economico
,null as des_rub_economico
,cad_2.val_parametro com_cta_original
,null as cod_gru_economico
,null as des_gru_economico
,'C_CORRIENTE' as marca_int

from cc_cta_corrientes cc
left join datos_cta_persona cta    
            on cc.nro_cuenta = cta.nro_cuenta 
            and cc.cod_modulo =cta.cod_modulo
            and cc.cod_modalidad =cta.cod_modalidad 
left join obt_cotizacion co 
	        on co.cod_moneda = cc.cod_moneda 
left join obt_cotizacion co_usd 
	        on co_usd.cod_moneda = 'USD'      
left join ingresos ir 
		    on ir.cod_persona=cta.cod_persona
left join ge_cta_dat_adicionales cad_2 on cad_2.nro_cuenta = cc.nro_cuenta and cad_2.parametro = 'CRM_NRO_OPERACION' 
left join datos_mod_modalidad mm 
		on mm.cod_modulo = cc.cod_modulo and mm.cod_modalidad = cc.cod_modalidad
		and mm.cod_sub_modalidad = cc.cod_sub_modalidad
left join ba_oficinas ofi on ofi.cod_oficina = cc.cod_oficina
left join des_est_cta est on est.cod_modulo = cc.cod_modulo and est.cod_modalidad = cc.cod_modalidad and est.estado = cc.estado and est.activo = 'S'    
left join cr_campanas cam on cam.cod_campana = cc.cod_campana and cam.cod_segmento = cta.cod_seg_cliente
left join ge_canales can on can.cod_canal = cc.cod_canal
left join cc_previsiones prev on prev.nro_cuenta = cta.nro_cuenta and (cta.nro_cuenta, prev.FEC_MODIFICACION) in (select nro_cuenta, max(FEC_MODIFICACION) FEC_MODIFICACION from cc_previsiones  group by nro_cuenta )
left join cc_sob_inventario sob on sob.nro_cuenta = cta.nro_cuenta and (cta.nro_cuenta, sob.FEC_INSERCION) in (select nro_cuenta, max(FEC_INSERCION)FEC_INSERCION from cc_sob_inventario  group by nro_cuenta)

	        
where cc.sal_total < 0 
)
, datos_cta_prestamo as (
  SELECT  --CTA.*
      --'2023-12-28' as partition_date
    CTA.cod_modulo
    ,mod.descripcion as desc_modulo
    ,NVL(g.cod_modalidad,cta.cod_modalidad) as COD_MODALIDAD
        ,g.descripcion AS desc_modalidad
        ,s.cod_sub_modalidad as cod_sub_modalidad
        ,s.descripcion AS desc_sub_modalidad
    ,CTA.nro_cuenta
      ,CTA.DIG_VERIFICADOR AS DIG_VERIFICADOR
      ,CTA.cod_moneda
      ,CTA.cod_oficina
      ,CTA.ESTADO
      ,NVL(CTA.sal_capital,0) sal_capital
      ,CTA.dia_atraso as dia_atraso
    ,CTA.FEc_INICIO as FEc_INICIO
    ,CTA.MONTO as  MONTO
    ,CTA.MTO_CAPITAL as MTO_CAPITAL
    ,CTA.SAL_INTERES as SAL_INTERES
    ,CTA.SAL_INT_ADELANTADO as SAL_INT_ADELANTADO
    ,CTA.val_int_devengar as val_int_devengar
    ,CTA.dev_acumulado as dev_acumulado
    ,CTA.dev_no_cobrado as dev_no_cobrado
    ,CTA.dev_suspenso as dev_suspenso
    ,CTA.fec_vencimiento as fec_vencimiento
    ,CTA.val_tasa as val_tasa
    ,CTA.MAX_ATRASO as MAX_ATRASO
    ,CTA.PRO_ATRASO as PRO_ATRASO
    ,CTA.PER_VTO_CAPITAL as PER_VTO_CAPITAL
    ,CTA.en_juicio
    ,CTA.can_cuotas as can_cuotas
    ,CTA.can_cuo_pagadas as can_cuo_pagadas
    ,CTA.tip_destino
    ,CTA.TIP_INTERES
    ,CTA.MTO_MORA as MTO_MORA
    ,CTA.TIP_RENOVACION
    ,CTA.NRO_SOLICITUD NRO_SOLICITUD
    ,CTA.COB_AUTOMATICO
    ,CTA.nro_cta_debito
    ,CTA.COD_RUB_ECONOMICO
    ,SOL.TIP_AMORTIZACION
    ,PREV.monto as prev_monto
    ,PREV.mto_pre_total as mto_pre_total
    ,TDE.TIP_DES_ESPECIFICO AS COD_TIP_DES_ESPECIFICO
    ,DES.SIGNIFICADO AS TIP_DES_ESPECIFICO
    ,SB.VAL_TAS_NOMINAL
    ,SB.VAL_TAS_EFECTIVA
    ,CO.VAL_CONVERSION as COTIZ
    ,CO_USD.VAL_CONVERSION as COTIZ_USD
    ,bo.descripcion as desc_oficina
    ,DE.descripcion as desc_est_cuenta
    ,sd.MTO_INT_DOCUMENTADO as MTO_INT_DOCUMENTADO
    ,CAD_2.val_parametro as COM_CTA_ORIGINAL
    ,CTA.cod_campana as cod_campana
    ,CC.descripcion as DES_CAMPANA
    ,CTA.cod_canal as cod_canal

    ,GC.descripcion as DES_CANAL
    ,GEN.DESCRIPCION as DESC_ENTES
    ,CAD.VAL_PARAMETRO
    ,REF.SIGNIFICADO AS DES_DESTINO
    ,cta.tipo
    ,gen.COD_ENTE
    ,(CTA.fec_vencimiento - CTA.fec_inicio) AS PLAZO
    ,SUBSTR(CTA.descripcion,LENGTH(SUBSTR(CTA.DESCRIPCION,1,(INSTR(CTA.DESCRIPCION,'CTA:'))+4))) NRO_CTA_GSOL
    ,ge.DESCRIPCION as DES_RUB_ECONOMICO
    ,REN.MAX_NRO_CTA_RENOVADA AS NRO_CTA_RENOVADA
    ,SMC.MTO_CAPITAL_PEND
    ,CP.MTO_CAPITAL_PAG
    ,C1.MONTO AS MTO_SEG_VIDA
    ,C2.MONTO AS MTO_SEG_INCAP
    ,C3.MONTO AS MTO_COM_DESEM
  FROM pr_cta_prestamos CTA
  LEFT JOIN pr_sec_creditos SCR
      ON CTA.cod_sec_credito = SCR.cod_sec_credito
  LEFT JOIN GE_CANALES GC
      ON GC.COD_CANAL = CTA.COD_CANAL
  left join datos_mod_modalidad mm
    on mm.cod_modulo = cta.cod_modulo
    and mm.cod_modalidad = cta.cod_modalidad
    and mm.cod_sub_modalidad = cta.cod_sub_modalidad
  left join ba_modulos mod on mod.cod_modulo = cta.cod_modulo
  left join ge_modalidades g on g.cod_modulo = cta.cod_modulo
        and ((g.cod_modalidad= cta.cod_modalidad)  --si es antes del 12-07 que haga el mappeo a los nuevos valores
            or (g.cod_modalidad= cta.cod_modalidad)) --a partir del 8 ya deberia venir mappeado
  left join ge_sub_modalidades s on s.cod_modulo = cta.cod_modulo
        and ((s.cod_modalidad = cta.cod_modalidad and s.cod_sub_modalidad = NVL(mm.cod_sub_modalidad,cta.cod_sub_modalidad))
            or ( s.cod_modalidad =  cta.cod_modalidad and s.cod_sub_modalidad = cta.cod_sub_modalidad))
  LEFT JOIN CR_CAMPANAS CC
      ON CC.COD_CAMPANA = CTA.cod_campana
  LEFT JOIN GE_CTA_DAT_ADICIONALES CAD
      ON CAD.NRO_CUENTA = CTA.NRO_CUENTA
      AND PARAMETRO = 'PRE_COD_ENT_COM_CARTERA'
  LEFT JOIN GE_ENTES GEN
      ON TO_CHAR(GEN.COD_ENTE) = TO_CHAR(CAD.VAL_PARAMETRO)
  LEFT JOIN PR_SOLICITUDES SOL
      ON SOL.NRO_SOLICITUD = CTA.NRO_SOLICITUD
  left join ULT_PREVISON up
    on up.nro_cuenta = CTA.nro_cuenta
  LEFT JOIN pr_previsiones PREV
      ON PREV.NRO_CUENTA = UP.NRO_CUENTA
      and PREV.fecha = up.MAX_FECHA
  LEFT JOIN PR_CTA_DESTINOS TDE
      ON TDE.NRO_CUENTA = CTA.NRO_CUENTA
  left join des_refcodes DES
      on DES.dominio = 'TIP_DES_ESPECIFICO'
      and DES.val_minimo = TDE.TIP_DES_ESPECIFICO
  left join ULT_TASA ut
    on ut.nro_cuenta = CTA.NRO_CUENTA
  LEFT JOIN SB_TAS_APE_SEMANALES SB
      ON SB.NRO_CUENTA =  ut.nro_cuenta
      and sb.FEC_INSERCION = ut.MAX_FEC_INSERCION
  left join OBT_COTIZACION co
      on co.cod_moneda = cta.cod_moneda
  left join OBT_COTIZACION co_usd
      on co_usd.cod_moneda = 'USD'
  left join ba_oficinas bo
      on bo.cod_oficina = cta.cod_oficina
  left join DES_EST_CTA DE
      on DE.cod_modulo = CTA.COD_MODULO and DE.cod_modalidad = CTA.COD_MODALIDAD and DE.estado = CTA.ESTADO
  left JOIN SUM_MTO_INT_DOCUMENTADO sd
      on sd.nro_cuenta = cta.nro_cuenta
  LEFT JOIN GE_CTA_DAT_ADICIONALES CAD_2
      ON CAD_2.NRO_CUENTA = CTA.NRO_CUENTA AND CAD_2.PARAMETRO = 'CRM_NRO_OPERACION'
    LEFT JOIN des_refcodes REF
        ON REF.dominio = 'TIP_DESTINO' and REF.val_minimo = CTA.TIP_DESTINO
    left join GE_RUB_ECONOMICOS ge
        on ge.COD_RUB_ECONOMICO = CTA.COD_RUB_ECONOMICO
  LEFT JOIN NRO_CTA_RENOVADA REN
    ON REN.NRO_CTA_RENOVADA = CTA.NRO_CUENTA
  LEFT JOIN CAPITAL_PENDIENTE SMC
    ON SMC.NRO_CUENTA = CTA.NRO_CUENTA
  LEFT JOIN CAPITAL_PAGADO CP
    ON CP.NRO_CUENTA = CTA.NRO_CUENTA
  LEFT JOIN CARGOS C1
    ON C1.NRO_SOLICITUD = CTA.NRO_SOLICITUD AND C1.COD_TRANSACCION = '736'
  LEFT JOIN CARGOS C2
    ON C2.NRO_SOLICITUD = CTA.NRO_SOLICITUD AND C2.COD_TRANSACCION = '1270'
  LEFT JOIN CARGOS C3
    ON C3.NRO_SOLICITUD = CTA.NRO_SOLICITUD AND C3.COD_TRANSACCION = '704'
    where cta.ESTADO NOT IN ('I','N')
)

, PRESTAMOS as (
  SELECT
  Distinct
  to_char(pag_cal.fu_obt_fec_actual(6), 'yyyy-mm-dd') as FECHA_PROCESO,
      CTA.cod_modulo AS MODULO_COD,
      CTA.desc_modulo AS MODULO,
      CTA.COD_MODALIDAD AS MODALIDAD_COD,
      CTA.desc_modalidad AS MODALIDAD,
    NVL(cta.cod_sub_modalidad,'') as sub_modalidad_cod, --nuevo
    NVL(cta.desc_sub_modalidad,'') as sub_modalidad, --nuevo
      CT.COD_PERSONA AS COD_PERSONA,
      CT.nom_completo AS NOMBRE_CLIENTE,
      CT.cod_actividad AS COD_ACTIVIDAD,
      CASE
         WHEN CT.desc_actividad IS NULL THEN 'Rubro / Actividad no registrados en el Sistema'
         ELSE CT.desc_actividad
      END AS DES_ACTIVIDAD,
      CT.NRO_DOCUMENTO AS NRODOC,
      CT.TIPO AS TIPOPERSONA,
      CT.COD_SEXO AS SEXO,
      CT.FEC_NACIMIENTO AS FEC_NACIMIENTO,
    TRUNC(((pag_cal.fu_obt_fec_actual(6)) - CT.FEC_NACIMIENTO) / 365.25)  as edad,
      CTA.nro_cuenta AS NRO_CUENTA,
      CTA.DIG_VERIFICADOR AS DIGITO_VERIFICADOR,
      CTA.cod_moneda AS COD_MONEDA,
      NVL(CTA.COTIZ, 1) AS cotizacion,
      CTA.cod_oficina AS SUCURSAL_COD,
      CTA.desc_oficina AS SUCURSAL,
      CTA.ESTADO AS ESTADO_COD,
      CTA.desc_est_cuenta AS ESTADO,
    CASE
      WHEN CTA.COD_MODALIDAD IN (608,62) AND CTA.COD_SUB_MODALIDAD IN ('1') THEN
      CASE
        WHEN CTA.FEc_INICIO > to_date('21/08/2021','dd/mm/yyyy') THEN CTA.MONTO
      ELSE
        Round((CTA.MTO_CAPITAL - ( (select p.MTO_INT_DOCUMENTADO from pr_cuotas p where P.nro_cuenta = CTA.nro_cuenta) * (0.1))))
      END
    ELSE CTA.monto
    END AS MONTO_DESEMBOLSADO_OR,

      CTA.sal_capital AS SALDO_OR,
      CTA.sal_capital AS CARTERA_TOTAL_OR,
      CASE
          WHEN NVL(CTA.dia_atraso, 0) > 60 THEN CTA.sal_capital
          ELSE 0
      END AS CARTERA_VENCIDA_OR,
      CASE
          WHEN NVL(CTA.dia_atraso, 0) <= 60 THEN CTA.sal_capital
          ELSE 0
      END AS CARTERA_VIGENTE_OR,
    CASE
      WHEN CTA.COD_MONEDA = 'USD' THEN
      CASE
        WHEN CTA.COD_MODALIDAD IN (608,62) AND CTA.COD_SUB_MODALIDAD IN ('1') THEN
          CASE
            WHEN CTA.FEc_INICIO > to_date('21/08/2021','dd/mm/yyyy') THEN
              CTA.monto*(fug_obt_cotizacion(CTA.cod_moneda,pag_cal.fu_obt_fec_actual(6)))
            ELSE ROUND((CTA.MTO_CAPITAL - (ROUND((select p.MTO_INT_DOCUMENTADO from pr_cuotas p where P.nro_cuenta = CTA.nro_cuenta) *0.1))*(fug_obt_cotizacion(CTA.cod_moneda,pag_cal.fu_obt_fec_actual(6)))))
            END
          ELSE ROUND(CTA.monto*(fug_obt_cotizacion(CTA.cod_moneda,pag_cal.fu_obt_fec_actual(6))))
          END
      ELSE CTA.MONTO
      END as MONTO_DESEMBOLSADO_GS,

    CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
        (CTA.sal_capital * NVL(CTA.COTIZ, 1))
          ELSE
        CTA.sal_capital
      END AS SALDO_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
        NVL(ROUND(CTA.sal_capital * NVL(CTA.COTIZ, 1)), 0)
          ELSE
        CTA.sal_capital
      END AS CARTERA_TOTAL_GS,
      CASE
          WHEN NVL(CTA.dia_atraso, 0) > 60 THEN
              CASE
                  WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(CTA.sal_capital * NVL(CTA.COTIZ, 1)), 0)
                  ELSE
            CTA.sal_capital
              END
          ELSE 0
      END AS CARTERA_VENCIDA_GS,

      CASE
          WHEN NVL(CTA.dia_atraso, 0) <= 60 THEN
              CASE
                  WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(CTA.sal_capital * NVL(CTA.COTIZ, 1)), 0)
                  ELSE CTA.sal_capital
              END
          ELSE 0
      END AS CARTERA_VIGENTE_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
              CASE
                  WHEN (CTA.COD_MODALIDAD IN (608, 62) AND CTA.COD_SUB_MODALIDAD IN ('1'))  THEN
                      CASE
                          WHEN CTA.FEc_INICIO > to_date('21/08/2021','dd/mm/yyyy')
                                THEN ROUND(CTA.monto / NVL(CTA.COTIZ_USD, 1))
                          ELSE
                                ROUND((CTA.MTO_CAPITAL - ROUND(MTO_INT_DOCUMENTADO) * 0.1) / NVL(CTA.COTIZ_USD, 1))
                      END
                  ELSE ROUND(CTA.monto / NVL(CTA.COTIZ_USD, 1))
              END
          ELSE CTA.MONTO
      END AS MONTO_DESEMBOLSADO_DLS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
        ROUND(CTA.sal_capital / NVL(CTA.COTIZ_USD, 1))
          ELSE
        CTA.sal_capital
      END AS SALDO_DLS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
        NVL(ROUND(CTA.sal_capital / NVL(CTA.COTIZ_USD, 1)), 0)
          ELSE
        CTA.sal_capital
      END AS CARTERA_TOTAL_DLS,
      CASE
          WHEN NVL(CTA.dia_atraso, 0) > 60 THEN
              CASE
                  WHEN CTA.COD_MONEDA = 'GS' THEN
            NVL(ROUND(CTA.sal_capital / NVL(CTA.COTIZ_USD, 1)), 0)
                  ELSE
            CTA.sal_capital
              END
          ELSE 0
      END AS CARTERA_VENCIDA_DLS,
      CASE
          WHEN NVL(CTA.dia_atraso, 0) <= 60 THEN
              CASE
                  WHEN CTA.COD_MONEDA = 'GS' THEN
            NVL(ROUND(CTA.sal_capital / NVL(CTA.COTIZ_USD, 1)), 0)
                  ELSE
            CTA.sal_capital
              END
          ELSE 0
      END AS CARTERA_VIGENTE_DLS,
      (NVL(CTA.SAL_INTERES, 0)) + (NVL(CTA.SAL_INT_ADELANTADO, 0)) AS SAL_INTERES_OR,
      (NVL(CTA.val_int_devengar, 0)) AS A_DEVENGAR_OR,
      (NVL(CTA.dev_acumulado, 0)) AS DEV_ACUMULADO_OR,
      (NVL(CTA.dev_no_cobrado, 0)) AS DEV_NO_COBRADO_OR,
      (NVL(CTA.dev_suspenso, 0)) AS DEV_SUSPENSO_OR,
      (NVL(CTA.prev_monto, 0) + NVL(CTA.MTO_PRE_TOTAL, 0)) AS PREVISION_OR,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND((NVL(CTA.SAL_INTERES, 0) + NVL(CTA.SAL_INT_ADELANTADO, 0)) * NVL(CTA.COTIZ, 1)), 0)
          ELSE
        NVL(CTA.SAL_INTERES, 0) + NVL(CTA.SAL_INT_ADELANTADO, 0)
      END AS SAL_INTERES_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND(NVL(CTA.val_int_devengar, 0) * NVL(CTA.COTIZ, 1)), 0)
          ELSE
        NVL(CTA.val_int_devengar, 0)
      END AS A_DEVENGAR_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND((NVL(CTA.dev_acumulado, 0) * NVL(CTA.COTIZ, 1)), 0), 0)

          ELSE
        NVL(CTA.dev_acumulado, 0)
      END AS DEV_ACUMULADO_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND(NVL(CTA.dev_no_cobrado, 0) * NVL(CTA.COTIZ, 1)), 0)
          ELSE
        NVL(CTA.dev_no_cobrado, 0)
      END AS DEV_NO_COBRADO_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND(NVL(CTA.dev_suspenso, 0) * NVL(CTA.COTIZ, 1)), 0)
          ELSE
        NVL(CTA.dev_suspenso, 0)
      END AS DEV_SUSPENSO_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
                NVL(ROUND((NVL(CTA.prev_monto, 0) + NVL(CTA.MTO_PRE_TOTAL, 0)) * NVL(CTA.COTIZ, 1)), 0)
          ELSE
            NVL( NVL(CTA.prev_monto, 0) + NVL(CTA.MTO_PRE_TOTAL, 0) , 0)
      END AS PREVISION_GS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND((NVL(CTA.SAL_INTERES, 0) + NVL(CTA.SAL_INT_ADELANTADO, 0)) / NVL(CTA.COTIZ_USD, 1)), 0)
          ELSE
        NVL(CTA.SAL_INTERES, 0) + NVL(CTA.SAL_INT_ADELANTADO, 0)
      END AS SAL_INTERES_DLS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND(NVL(CTA.val_int_devengar, 0) / NVL(CTA.COTIZ_USD, 1), 0), 0)
          ELSE
        NVL(CTA.val_int_devengar, 0)
      END AS A_DEVENGAR_DLS,
      CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND(NVL(CTA.dev_acumulado, 0) / NVL(CTA.COTIZ_USD, 1), 0), 0)
          ELSE
        NVL(CTA.dev_acumulado, 0)
      END AS DEV_ACUMULADO_DLS,

       CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND(NVL(CTA.dev_no_cobrado, 0) / NVL(CTA.COTIZ_USD, 1), 0), 0)
          ELSE
        NVL(CTA.dev_no_cobrado, 0)
      END AS DEV_NO_COBRADO_DLS,
          CASE
              WHEN CTA.COD_MONEDA = 'GS' THEN
                  NVL(ROUND(NVL(CTA.dev_suspenso, 0) / NVL(CTA.COTIZ_USD, 1), 0), 0)
              ELSE
          NVL(CTA.dev_suspenso, 0)
          END AS DEV_SUSPENSO_DLS,
      CASE WHEN CTA.COD_MONEDA = 'GS' THEN
              ROUND(NVL( NVL(ROUND(NVL(CTA.prev_monto, 0) + NVL(CTA.MTO_PRE_TOTAL, 0)), 0) / NVL(CTA.COTIZ_USD, 1) , 0))
      ELSE
            NVL( NVL(CTA.prev_monto, 0) + NVL(CTA.MTO_PRE_TOTAL, 0) , 0)
      END AS PREVISION_DLS,
      CT.cod_usu_oficial AS ASESOR,
    CTA.fec_inicio AS EMISION,
    CTA.fec_vencimiento AS VENCIMIENTO,
    (CTA.fec_vencimiento - CTA.fec_inicio) AS PLAZO,
    (SELECT pl.descripcion plazo
      FROM ge_plz_contables pl
      WHERE pl.can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables WHERE can_dias >= (CTA.fec_vencimiento - CTA.fec_inicio))) AS DES_PLAZO,
    CTA.val_tasa AS TASA,
    NVL(CTA.dia_atraso, 0) AS DIAS_ATRASO,
    NVL(CTA.MAX_ATRASO, 0) AS MAX_ATRASO,
    NVL(CTA.PRO_ATRASO, 0) AS PRO_ATRASO,
    NVL(CTA.PER_VTO_CAPITAL, 0) AS PER_VTO_CAPITAL,
    CT.cod_seg_cliente AS COD_SEGMENTO,
    CT.DES_SEGMENTO AS SEGMENTO,
    NVL(CTA.en_juicio, 'N') AS JUDICIALIZADO,
    CTA.can_cuotas AS CAN_CUOTAS,
    CTA.can_cuo_pagadas AS CAN_CUOTAS_PAG,
    CTA.can_cuotas - NVL(CTA.can_cuo_pagadas, 0) AS CAN_CUOTAS_PEND,
    CT.cat_automatica AS CAT_AUTOMATICA,
    CT.cat_riesgo AS CAT_RIESGO,
    CT.cat_sistema AS CAT_SISTEMA,
    CTA.tip_destino AS TIP_DESTINO,
        CASE WHEN CTA.DES_DESTINO IS NULL THEN ''
            ELSE CTA.DES_DESTINO
        END DES_DESTINO,
      CTA.cod_campana AS COD_CAMPANA,
      CTA.DES_CAMPANA AS DES_CAMPANA,
      CTA.cod_canal AS COD_CANAL,
      CTA.DES_CANAL as DES_CANAL,
      CTA.tipo AS AMORTIZACION,
    CASE
        WHEN CTA.TIP_AMORTIZACION = 'C' THEN 'CONSTANTE'
        WHEN CTA.TIP_AMORTIZACION = 'E' THEN 'ESPECIAL'
        WHEN CTA.TIP_AMORTIZACION = 'F' THEN 'FLEXIBLE'
        WHEN CTA.TIP_AMORTIZACION = 'P' THEN 'PRICE'
        WHEN CTA.TIP_AMORTIZACION = 'I' THEN 'PRICE CUOTAS IGUALES'
        ELSE ' '
    END AS TIP_AMORTIZACION,
    CASE
        WHEN CTA.TIP_INTERES = 'A' THEN 'ADELANTADO'
        WHEN CTA.TIP_INTERES = 'V' THEN 'VENCIDO'
        ELSE ' '
    END AS TIP_INTERES,
    CT.cod_sec_contable AS COD_SEC_CONTABLE,
    CT.SEC_CONTABLE AS SEC_CONTABLE,
    CT.cod_tip_deudor AS COD_TIP_DEUDOR,
    CT.TIP_DEUDOR AS TIP_DEUDOR,
    CT.COD_TIP_CLIENTE AS COD_TIP_CLIENTE,
    CASE
          WHEN CT.TIP_CLIENTE IS NULL THEN ' '
          ELSE CT.TIP_CLIENTE
      END AS TIP_CLIENTE,
    '' AS NRO_TERJETA,
    '' AS CTA_BANCARD,
    '' AS AFINIDAD,
    '-' as des_afinidad,
    0 as mto_pag_minimo,
    0 as linea_credito,
    0 as linea_disponible,

    CASE
      WHEN (NOT (CTA.COD_MODALIDAD IN (60,62,608,622,628,691,690,673) AND CTA.COD_SUB_MODALIDAD IN ('1') ) OR
      NOT (CTA.COD_MODALIDAD IN (628) AND CTA.COD_SUB_MODALIDAD IN ('2')) OR
      NOT (CTA.COD_MODALIDAD IN (691) AND CTA.COD_SUB_MODALIDAD IN ('4'))) and CT.cod_seg_cliente <> 1 THEN
      CASE
        WHEN CTA.COD_MODALIDAD = 61 AND CTA.COD_SUB_MODALIDAD IN ('1')  and CTA.COD_CAMPANA = 25 THEN 'AFD/VIVIENDA'
        WHEN CT.cod_seg_cliente IN (6,7,8,17) THEN 'PRESTAMO PERSONAL'
        WHEN CT.cod_seg_cliente IN (3,4,5) THEN 'PRESTAMO PYMES'
        WHEN CT.cod_seg_cliente IN (2,10) THEN 'PRESTAMO MICRO'
      ELSE cta.desc_modalidad
      END
      WHEN CTA.COD_MODALIDAD IN (608,62) AND CTA.COD_SUB_MODALIDAD IN ('1') and CT.cod_seg_cliente <> 1  THEN 'DESCUENTO DE DOCUMENTOS'
      WHEN CT.cod_seg_cliente = 1 THEN 'FUNCIONARIO'
      WHEN CTA.cod_modalidad in (60) AND CTA.COD_SUB_MODALIDAD IN ('1')  THEN 'FUNCIONARIO'
      WHEN (CTA.COD_MODALIDAD IN (628,691,690,673) AND CTA.COD_SUB_MODALIDAD IN ('1'))
            OR (CTA.COD_MODALIDAD IN (628)  AND CTA.COD_SUB_MODALIDAD IN ('2'))
      OR (CTA.COD_MODALIDAD IN (691) AND CTA.COD_SUB_MODALIDAD IN ('4')) THEN 'AFD/VIVIENDA'
      WHEN CTA.COD_CAMPANA = 25 THEN 'AFD/VIVIENDA'
    ELSE cta.desc_modalidad
    END AS PRODUCTO,
    CASE
      WHEN (CT.cod_seg_cliente = 1 or (CTA.cod_modalidad = 60 AND CTA.COD_SUB_MODALIDAD = '1')) THEN 'FUNCIONARIO'
      WHEN CTA.COD_CAMPANA = 25 THEN 'AFD/VIVIENDA'
      WHEN (CTA.cod_modalidad  = 622 AND CTA.COD_SUB_MODALIDAD = '1')  THEN 'COMPRA DE CARTERA'
      WHEN (CTA.COD_MODALIDAD IN (61,609,68,670,604,628,690,645,65) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente = 2)
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '2' and CT.cod_seg_cliente = 2)
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '3' and CT.cod_seg_cliente = 2)
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '4' and CT.cod_seg_cliente = 2)
      THEN 'PRESTAMO MICRO'
      WHEN (CTA.COD_MODALIDAD IN (61,609,68,670,604,628,690,645,65) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente IN (3,4,5))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '2' and CT.cod_seg_cliente IN (3,4,5))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '3' and CT.cod_seg_cliente IN (3,4,5))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '4' and CT.cod_seg_cliente IN (3,4,5))
      THEN 'PRESTAMO PYMES'
      WHEN (CTA.COD_MODALIDAD IN (61,609,68,670,604,628,690,645,65) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente IN (6,7,8))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '2' and CT.cod_seg_cliente IN (6,7,8))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '3' and CT.cod_seg_cliente IN (6,7,8))
        OR (CTA.COD_MODALIDAD IN (645) AND CTA.COD_SUB_MODALIDAD = '4' and CT.cod_seg_cliente IN (6,7,8))
      THEN 'CONSUMO'
      WHEN (CTA.COD_MODALIDAD IN (62,608,660) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente NOT IN (1)) THEN 'DESCUENTO DE DOCUMENTOS'
      WHEN (CTA.COD_MODALIDAD IN (673,691) AND CTA.COD_SUB_MODALIDAD = '1' )
        OR (CTA.COD_MODALIDAD IN (628) AND CTA.COD_SUB_MODALIDAD = '2')
        OR (CTA.COD_MODALIDAD IN (691) AND CTA.COD_SUB_MODALIDAD = '4')
      THEN 'AFD/VIVIENDA'
      WHEN (CTA.COD_MODALIDAD IN (617,618,619,961,635,968) AND CTA.COD_SUB_MODALIDAD = '1')
        OR (CTA.COD_MODALIDAD IN (961) AND CTA.COD_SUB_MODALIDAD = '2')
      THEN 'REF/REEST/MED.EXCEP'
      WHEN CTA.COD_MODALIDAD IN (610) AND CTA.COD_SUB_MODALIDAD = '1' THEN 'CAUCIÓN DE CHEQUES'
      WHEN (CTA.COD_MODALIDAD IN (602) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente <> 1 AND CTA.fec_inicio >= to_date('20220301', 'yyyymmdd')) THEN 'PREAPROBADO/ONB'
      WHEN (CTA.COD_MODALIDAD IN (602) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente <> 1 AND CTA.fec_inicio <  to_date('20220301', 'yyyymmdd') AND CT.cod_seg_cliente IN (6,7,8)) THEN 'CONSUMO'
      WHEN (CTA.COD_MODALIDAD IN (602) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente <> 1 AND CTA.fec_inicio <  to_date('20220301', 'yyyymmdd') AND CT.cod_seg_cliente IN (2)) THEN 'PRESTAMO MICRO'
      WHEN (CTA.COD_MODALIDAD IN (602) AND CTA.COD_SUB_MODALIDAD = '1' and CT.cod_seg_cliente <> 1 AND CTA.fec_inicio <  to_date('20220301', 'yyyymmdd') AND CT.cod_seg_cliente IN (3,4,5)) THEN 'PRESTAMO PYMES'
      WHEN CTA.TIP_RENOVACION IN ('R','E') THEN 'REF/REEST/MED.EXCEP'
      else cta.desc_modalidad
    END AS PRODUCTO_COMISION,
    CASE
      WHEN CTA.cod_canal = 25 THEN
        'CREDICENTRO'
      ELSE
        'FIELCO'
      END CARTERA,
    CTA.COD_ENTE AS COD_CEDENTE,
    CASE
      WHEN CTA.DESC_ENTES IS NULL THEN
        CTA.VAL_PARAMETRO
        ELSE CTA.DESC_ENTES
    END AS EMP_CEDENTE,
    CTA.VAL_PARAMETRO AS VAL_CEDENTE,
    '' AS ASOCIACION,
    CT.CAJA_DE_AHORRO,
    CASE
        WHEN CT.COD_USU_PROMOTOR IS NOT NULL THEN
            NVL(CT.COD_USU_PROMOTOR, ' ') || '-' || CT.nombre_promotor
        ELSE ' '
    END AS USU_PROMOTOR,
    CT.GARANTE,
    CT.CODEUDORIA,
    CT.TOT_INGRESOS AS INGR_MENSUAL,
    CT.COD_CIUDAD_PAR AS COD_CIUDAD_PAR,
    CT.desc_ciu_particular AS CIUDAD_PAR,
    CT.COD_CIUDAD_LAB AS COD_CIUDAD_LAB,
    CT.desc_ciu_laboral AS CIUDAD_LAB,
    ' ' AS TEL_PRINCIPAL,
    NVL(CTA.MTO_MORA, 0) AS MONTO_MORA_OR,
    CASE
        WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(NVL(CTA.MTO_MORA, 0) * CTA.COTIZ), 0)
        ELSE
        NVL(CTA.MTO_MORA, 0)
    END AS MONTO_MORA_GS,
    CASE
        WHEN CTA.COD_MONEDA = 'GS' THEN
            NVL(ROUND(NVL(CTA.MTO_MORA, 0) / CTA.COTIZ_USD), 0)
        ELSE
        NVL(CTA.MTO_MORA, 0)
    END AS MONTO_MORA_DLS,
    CASE
        WHEN CTA.TIP_RENOVACION = 'N' THEN 'RENOVADO'
        WHEN CTA.TIP_RENOVACION = 'R' THEN 'REFINANCIADO'
        WHEN CTA.TIP_RENOVACION = 'E' THEN 'REESTRUCTURADO'
        ELSE 'N/A'
    END AS TIPO_RENOVACION_R,
    CTA.NRO_CTA_RENOVADA,
    CT.DIR_CORREO AS CORREO,
    CTA.NRO_SOLICITUD AS NRO_SOLICITUD,
    NVL(CTA.prev_monto, 0) + NVL(CTA.mto_pre_total, 0) AS PREVISIONES_R1,
    NVL(CTA.prev_monto, 0) AS PREVISIONES_CARTERA_R1,
    NVL(CTA.mto_pre_total, 0) AS PREVISIONES_DIFERIDAS_R1,
    NVL(CTA.prev_monto, 0) + NVL(CTA.mto_pre_total, 0) AS PREVISIONES_ORDEN_R1,
    CASE
        WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(CTA.MTO_CAPITAL * CTA.COTIZ), 0)
        ELSE
        NVL(CTA.MTO_CAPITAL, 0)
    END AS CAPITAL_INICIAL_GS,
    CASE
        WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(CTA.MTO_CAPITAL_PEND * CTA.COTIZ), 0)
        ELSE
        NVL(CTA.MTO_CAPITAL_PEND, 0)
    END AS CAPITAL_PEND_GS,
    CASE
        WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(CTA.MTO_CAPITAL_PAG * CTA.COTIZ ), 0)
        ELSE
        NVL(MTO_CAPITAL_PAG, 0)
    END AS CAPITAL_PAGADO_GS,
    CTA.COD_TIP_DES_ESPECIFICO AS COD_DES_ESPECIFICO,
    CASE
       WHEN CTA.TIP_DES_ESPECIFICO is NULL THEN ' '
       ELSE CTA.TIP_DES_ESPECIFICO
    END AS TIP_DES_ESPECIFICO,
    CT.FECHA_ONBOARDING,
      CT.INGRESO_ANUAL AS INGRESOS_ANUALES,
    CT.DEPARTAMENTO,
    CT.GARANTIA_DESC AS GARANTIA,
    CTA.VAL_TAS_NOMINAL,
    CTA.VAL_TAS_EFECTIVA,
    CTA.MTO_SEG_VIDA AS MTO_SEG_VIDA,
    CTA.MTO_SEG_INCAP AS MTO_SEG_INCAP,
    CTA.MTO_COM_DESEM AS MTO_COM_DESEM,

    CASE
        WHEN (cta.COD_MODALIDAD <> 660 and cta.cod_sub_modalidad <> '1') THEN
            GE1.COD_USUARIO || '-' || NVL(BU_GES1.NOMBRE,' ')
        ELSE
            GE2.COD_USUARIO || '-' || NVL(BU_GES2.NOMBRE,' ')
        END AS USU_APROBADOR,
    CT.CLI_CONFIDENCIAL,
    CT.CLI_ESPECIAL,
    CTA.COB_AUTOMATICO AS COB_AUTOMATICO,
    CTA.nro_cta_debito AS nro_cta_debito,
    RLA.ESTADO AS EST_CTA_DEBITO,
    RLA.COD_MONEDA AS MONEDA_CTA_DEBITO,
    CASE
        WHEN RLA.CONJUNTA >= 1 THEN 'CONJUNTA'
        WHEN RLA.INDISTINTA >= 1 THEN 'INDISTINTA'
        WHEN (RLA.PRINCIPAL >= 1 AND RLA.CONJUNTA = 0 AND RLA.INDISTINTA = 0) THEN 'INDIVIDUAL'
    END AS REL_CTA_DEBITO,
    IR.TIP_INGRESO,
    IR.MON_INGRESO AS MTO_INGRESO_APP,
    IR.MTO_ING_OFR,
    CTA.COD_RUB_ECONOMICO,
    CTA.DES_RUB_ECONOMICO,
    cta.COM_CTA_ORIGINAL AS COM_CTA_ORIGINAL,
    CT.COD_GRU_ECONOMICO,
    CT.DES_GRU_ECONOMICO,
    'prestamo' AS MARCA_INT
    FROM datos_cta_prestamo CTA
    INNER JOIN datos_cta_persona CT
        ON CT.nro_cuenta = CTA.nro_cuenta
        and ct.cod_modulo=cta.cod_modulo 
        and ct.cod_modalidad=cta.cod_modalidad 
        and ct.relacion = 'P'
    LEFT JOIN RELACIONES RLA
        ON RLA.NRO_CUENTA = CTA.NRO_CTA_DEBITO
    LEFT JOIN INGRESOS IR
        ON IR.COD_PERSONA = ct.COD_PERSONA
    LEFT JOIN desc_plazo x
        on CTA.PLAZO between x.mini and x.maxi
    LEFT JOIN MAX_GE MG
      ON MG.NRO_SOLICITUD = CTA.NRO_SOLICITUD
      AND NOT ((CTA.COD_MODALIDAD IN (660,676) and cta.cod_sub_modalidad = '1'))
    LEFT JOIN PR_SOL_GESTIONES GE1
      ON REPLACE(GE1.NRO_SOLICITUD, '"', ' ')  = MG.NRO_SOLICITUD
      AND GE1.ESTADO = 'L'
      AND GE1.FECHA = MG.FECHA
    LEFT JOIN BA_USUARIOS BU_GES1
      ON BU_GES1.COD_USUARIO = GE1.COD_USUARIO
    LEFT JOIN MAX_GE MG2
      ON MG2.NRO_SOLICITUD = CTA.NRO_SOLICITUD
      AND (CTA.COD_MODALIDAD IN (660,676) and cta.cod_sub_modalidad = '1')
    LEFT JOIN PR_CTA_PRESTAMOS PR1
      ON PR1.NRO_CUENTA =  CTA.NRO_CTA_GSOL
    LEFT JOIN PR_SOL_GESTIONES GE2
      ON REPLACE(GE2.NRO_SOLICITUD, '"', ' ') = MG2.NRO_SOLICITUD
      AND GE2.ESTADO = 'L'
      AND GE2.FECHA  = MG2.FECHA
      AND REPLACE(GE2.NRO_SOLICITUD, '"', ' ') = PR1.NRO_SOLICITUD
    LEFT JOIN BA_USUARIOS BU_GES2
      ON BU_GES2.COD_USUARIO = GE2.COD_USUARIO
)
, datos_tarjetas as (
  SELECT
    Distinct
    CTA.cod_modulo cod_modulo
    ,mm.desc_modulo
    ,CTA.COD_MODALIDAD
    ,mm.desc_modalidad
    ,CTA.nro_cuenta
    ,CTA.cod_moneda
    ,CO.VAL_CONVERSION as COTIZ
    ,CTA.cod_oficina
    ,bo.descripcion as desc_oficina
    ,cta.ESTADO
    ,DE.descripcion as desc_est_cuenta
    ,CTA.sal_facturar
    ,CTA.sal_facturado
    ,CTA.sal_financiado
    ,CTA.sal_cuo_pendientes
    ,CTA.dia_mora
    ,CO_USD.VAL_CONVERSION as COTIZ_USD
    ,TAR.fec_emision
    ,TAR.fec_vencimiento
    ,CTA.MAX_ATRASO
    ,CTA.PRO_ATRASO
    ,CTA.en_juicio
    ,CTA.cod_campana
    ,CC.descripcion as DES_CAMPANA
    ,CTA.cod_canal
    ,GC.descripcion as DES_CANAL
    ,TAR.nro_tarjeta
    ,CTA.afinidad
    ,CTA.mto_pag_minimo
    ,CTA.lin_credito
    ,GEN.COD_ENTE
    ,GEN.DESCRIPCION AS EMP_CEDENTE
    ,CAD.VAL_PARAMETRO
    ,CTA.MTO_MORA
    ,CTA.DEB_AUTOMATICO
    ,CTA.NRO_CTA_DEBITO
    ,CTA.COD_RUB_ECONOMICO
    ,CAD_2.val_parametro as COM_CTA_ORIGINAL
    ,dr.significado as des_afinidad
    ,GES.COD_USUARIO as GES_COD_USU
    ,BU.NOMBRE as GES_NOM_USU
    ,GES.COD_USUARIO || '-' || NVL(BU.NOMBRE, 'Usuario no registrado en el Sistema') AS USU_APROBADOR
    ,TAR.cod_persona tar_cod_persona
    ,TAR.nro_cuenta tar_nro_cuenta
    ,ge.DESCRIPCION as DES_RUB_ECONOMICO
    ,PRE.MONTO AS MTO_PREVISION
    ,cta.tas_financiacion as val_tasa
  FROM ta_cta_tarjetas cta
  INNER JOIN ge_cta_clientes CT
    ON CT.nro_cuenta = CTA.nro_cuenta
    and ct.cod_modulo=cta.cod_modulo 
    and ct.cod_modalidad=cta.cod_modalidad 
    and ct.relacion = 'P'
  INNER JOIN ba_personas p
        ON P.cod_persona = CT.cod_persona
  LEFT JOIN (
    	select a.* 
    	from ta_tarjetas a 
    	inner join --para traer solo la ultima tarjeta activada
        	(select b.nro_cuenta, max(b.fec_activacion) fec_activacion
        	from ta_tarjetas b 
        	where b.cod_estado <> '10' and b.rel_tarjeta = '0' and b.vigente = 'S'
        	group by b.nro_cuenta) c 
        	on c.nro_cuenta = a.nro_cuenta and c.fec_activacion = a.fec_activacion
    	where a.cod_estado <> '10' and a.rel_tarjeta = '0' and a.vigente = 'S' 
	    ) TAR  
      ON TAR.NRO_CUENTA = CTA.NRO_CUENTA 
	        AND tar.cod_persona = P.cod_persona
        	AND tar.cod_estado <> '10' AND tar.rel_tarjeta = '0' AND tar.vigente = 'S'    
  LEFT JOIN GE_CANALES GC
    ON GC.COD_CANAL = CTA.COD_CANAL
  LEFT JOIN BA_MODULOS MC
    ON MC.COD_MODULO = CTA.COD_MODULO
  LEFT JOIN CR_CAMPANAS CC
    ON CC.COD_CAMPANA = CTA.cod_campana
  LEFT JOIN GE_CTA_DAT_ADICIONALES CAD
    ON CAD.NRO_CUENTA =  CTA.NRO_CUENTA
    AND PARAMETRO = 'PRE_COD_ENT_COM_CARTERA'
  LEFT JOIN GE_ENTES GEN
    ON TO_CHAR(GEN.COD_ENTE) = TO_CHAR(CAD.VAL_PARAMETRO)
    LEFT JOIN (
        SELECT MAX(tg.FECHA) MAX_FECHA, tg.NRO_SOLICITUD, tg.COD_ESTADO
        FROM TA_SOL_GESTIONES tg
        group by NRO_SOLICITUD, COD_ESTADO
    ) GE1
        ON GE1.NRO_SOLICITUD = CTA.NRO_SOLICITUD
        AND GE1.COD_ESTADO = 'APR'
    LEFT JOIN TA_SOL_GESTIONES GES
        ON GES.NRO_SOLICITUD = GE1.NRO_SOLICITUD
        AND GE1.COD_ESTADO = GES.COD_ESTADO
        AND GE1.MAX_FECHA = GES.FECHA
    LEFT JOIN BA_USUARIOS bu
      ON bu.cod_usuario = GES.COD_USUARIO
  LEFT JOIN GE_CTA_DAT_ADICIONALES CAD_2
      ON CAD_2.NRO_CUENTA = CTA.NRO_CUENTA AND CAD_2.PARAMETRO = 'CRM_NRO_OPERACION'
  LEFT JOIN des_refcodes DR
    ON DR.dominio = 'AFINIDAD' AND DR.val_minimo = CTA.afinidad
  LEFT JOIN OBT_COTIZACION co
      ON co.cod_moneda = cta.cod_moneda
  LEFT JOIN OBT_COTIZACION co_usd
      ON co_usd.cod_moneda = 'USD'
  left JOIN datos_mod_modalidad mm
    on mm.cod_modulo = cta.cod_modulo and mm.cod_modalidad = cta.cod_modalidad
  LEFT JOIN ba_oficinas bo
      ON bo.cod_oficina = cta.cod_oficina
  LEFT JOIN DES_EST_CTA DE
      ON DE.cod_modulo = CTA.COD_MODULO AND DE.cod_modalidad = CTA.COD_MODALIDAD AND DE.estado = CTA.ESTADO
  left join GE_RUB_ECONOMICOS ge
        on ge.COD_RUB_ECONOMICO = CTA.COD_RUB_ECONOMICO
  LEFT JOIN MAX_PREVISION_TAR PRE
        ON PRE.NRO_CUENTA = CTA.NRO_CUENTA

  WHERE CTA.ESTADO NOT IN ('C')
    AND (CTA.SAL_FACTURAR + CTA.SAL_FACTURADO + CTA.SAL_FINANCIADO + CTA.SAL_CUO_PENDIENTES) > 0
)
, TARJETAS AS (
    SELECT
  Distinct
  to_char(pag_cal.fu_obt_fec_actual(6), 'yyyy-mm-dd') as FECHA_PROCESO,
  CTA.cod_modulo AS MODULO_COD,
  CTA.desc_modulo AS MODULO,
  CTA.COD_MODALIDAD AS MODALIDAD_COD,
  CTA.desc_modalidad AS MODALIDAD,
  null as sub_modalidad_cod, --nuevo
  null as sub_modalidad, --nuevo
  CT.COD_PERSONA AS COD_PERSONA,
    CT.nom_completo AS NOMBRE_CLIENTE,
    CT.cod_actividad AS COD_ACTIVIDAD,
    CASE
       WHEN CT.desc_actividad IS NULL THEN 'Rubro / Actividad no registrados en el Sistema'
       ELSE CT.desc_actividad
    END AS DES_ACTIVIDAD,
  CT.NRO_DOCUMENTO AS NRODOC,
  CT.TIPO AS TIPOPERSONA,
  CT.COD_SEXO AS SEXO,
  CT.FEC_NACIMIENTO,
  TRUNC(((pag_cal.fu_obt_fec_actual(6)) - CT.FEC_NACIMIENTO) / 365.25) AS edad,
    CTA.nro_cuenta AS NRO_CUENTA,
    0 AS DIGITO_VERIFICADOR,
    CTA.cod_moneda AS COD_MONEDA,
    NVL(CTA.COTIZ, 1) AS cotizacion,
    CTA.cod_oficina AS SUCURSAL_COD,
  CTA.desc_oficina AS SUCURSAL,
  CTA.ESTADO AS ESTADO_COD,
  CTA.desc_est_cuenta AS ESTADO,
   0 AS MONTO_DESEMBOLSADO_OR,
   (CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes) AS SALDO_OR,
   NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) AS CARTERA_TOTAL_OR,

   CASE
       WHEN NVL(CTA.Dia_Mora, 0) > 60 THEN NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
       ELSE 0
   END AS CARTERA_VENCIDA_OR,
   CASE
       WHEN NVL(CTA.Dia_Mora, 0) <= 60 THEN NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
       ELSE 0
   END AS CARTERA_VIGENTE_OR,
   0 AS MONTO_DESEMBOLSADO_GS,
    CASE
        WHEN CTA.COD_MONEDA = 'USD' THEN
            ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) * NVL(CTA.COTIZ, 1))
        ELSE
            NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
  END AS SALDO_GS,
--
  CASE
      WHEN CTA.COD_MONEDA = 'USD' THEN
          ROUND(NVL(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) * NVL(CTA.COTIZ, 1), 0))
      ELSE
          NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
  END AS CARTERA_TOTAL_GS,
  CASE
      WHEN NVL(CTA.Dia_Mora, 0) > 60 THEN
          CASE
              WHEN CTA.COD_MONEDA = 'USD' THEN
                  ROUND(NVL(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) * NVL(CTA.COTIZ, 1), 0))
              ELSE
                  NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
          END
      ELSE 0
  END AS CARTERA_VENCIDA_GS,
--
  CASE
      WHEN NVL(CTA.Dia_Mora, 0) <= 60 THEN
          CASE
              WHEN CTA.COD_MONEDA = 'USD' THEN
                  ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) * NVL(CTA.COTIZ, 1))
              ELSE
                  NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
          END
      ELSE 0
  END AS CARTERA_VIGENTE_GS,
  0 AS MONTO_DESEMBOLSADO_DLS,
  CASE
      WHEN CTA.COD_MONEDA = 'GS' THEN
          ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0) / NVL(CTA.COTIZ_USD, 1))
      ELSE
          NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
  END AS SALDO_DLS,
--
  CASE
      WHEN CTA.COD_MONEDA = 'GS' THEN
          NVL(ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado, 0) / NVL(CTA.COTIZ_USD, 0)), 0)
      ELSE
          NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
  END AS CARTERA_TOTAL_DLS,
--
  CASE
      WHEN NVL(CTA.Dia_Mora, 0) > 60 THEN
          CASE
              WHEN CTA.COD_MONEDA = 'GS' THEN
                  NVL(ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado, 0) / NVL(CTA.COTIZ_USD, 1)), 0)
              ELSE
                  NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
          END
      ELSE 0
  END AS CARTERA_VENCIDA_DLS,
--
      CASE
          WHEN NVL(CTA.Dia_Mora, 0) <= 60 THEN
              CASE
                  WHEN CTA.COD_MONEDA = 'GS' THEN
                      NVL(ROUND(NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado, 0) / NVL(CTA.COTIZ_USD, 1)), 0)
                  ELSE
                      NVL(CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes, 0)
              END
          ELSE 0
      END AS CARTERA_VIGENTE_DLS,
      0 AS SAL_INTERES_OR,
      0 AS A_DEVENGAR_OR,
      0 AS DEV_ACUMULADO_OR,
      0 AS DEV_NO_COBRADO_OR,
      0 AS DEV_SUSPENSO_OR,
      NVL(CTA.MTO_PREVISION, 0) AS PREVISION_OR,
      0 AS SAL_INTERES_GS,
      0 AS A_DEVENGAR_GS,
      0 AS DEV_ACUMULADO_GS,
      0 AS DEV_NO_COBRADO_GS,
      0 AS DEV_SUSPENSO_GS,
      CASE
      WHEN CTA.COD_MONEDA = 'USD' THEN
        NVL(ROUND(NVL(CTA.MTO_PREVISION, 0)* CTA.COTIZ), 0)
      ELSE
        NVL(CTA.MTO_PREVISION, 0)
    END AS PREVISION_GS,
--
    0 AS SAL_INTERES_DLS,
    0 AS A_DEVENGAR_DLS,
    0 AS DEV_ACUMULADO_DLS,
    0 AS DEV_NO_COBRADO_DLS,
    0 AS DEV_SUSPENSO_DLS,
    CASE
      WHEN CTA.COD_MONEDA = 'GS' THEN
      NVL(ROUND(NVL(CTA.MTO_PREVISION, 0)/ CTA.COTIZ_USD), 0)
      ELSE
        NVL(CTA.MTO_PREVISION, 0)
    END AS PREVISION_DLS,
    CT.cod_usu_oficial AS ASESOR,
    CTA.fec_emision AS EMISION,
    CTA.fec_vencimiento AS VENCIMIENTO,
    0 AS PLAZO,
    '' AS DES_PLAZO,
    val_tasa AS tasa,
    NVL(CTA.dia_mora, 0) AS DIAS_ATRASO,
    NVL(CTA.MAX_ATRASO, 0) AS MAX_ATRASO,
    NVL(CTA.PRO_ATRASO, 0) AS PRO_ATRASO,
    0 AS PER_VTO_CAPITAL,
    CT.cod_seg_cliente AS COD_SEGMENTO,
    CT.DES_SEGMENTO AS SEGMENTO,
--
    NVL(CTA.en_juicio, 'N') AS JUDICIALIZADO,
    0 AS CAN_CUOTAS,
    0 AS CAN_CUOTAS_PAG,
    0 AS CAN_CUOTAS_PEND,
    CT.cat_automatica AS CAT_AUTOMATICA,
    CT.cat_riesgo AS CAT_RIESGO,
    CT.cat_sistema AS CAT_SISTEMA,
    0 AS TIP_DESTINO,
    'N/A' AS DES_DESTINO,
    CTA.cod_campana AS COD_CAMPANA,
    cta.DES_CAMPANA AS DES_CAMPANA,
    CTA.cod_canal AS COD_CANAL,
    cta.DES_CANAL AS DES_CANAL,
    '' AS AMORTIZACION,
    '' AS TIP_AMORTIZACION,
    '' AS TIP_INTERES,
    CT.cod_sec_contable AS COD_SEC_CONTABLE,
    CT.SEC_CONTABLE AS SEC_CONTABLE,
    CT.cod_tip_deudor AS COD_TIP_DEUDOR,
    CT.TIP_DEUDOR AS TIP_DEUDOR,
    CT.COD_TIP_CLIENTE AS COD_TIP_CLIENTE,
    CASE
        WHEN CT.TIP_CLIENTE IS NULL THEN ''
        ELSE CT.TIP_CLIENTE
    END AS TIP_CLIENTE,
    CTA.nro_tarjeta AS NRO_TERJETA,
    CTA.nro_cuenta AS CTA_BANCARD,
    CTA.afinidad AS AFINIDAD,
    case
      when CTA.des_afinidad is null then ''
      else CTA.des_afinidad
    end
    AS DES_AFINIDAD,
    CTA.mto_pag_minimo AS mto_pag_minimo,
    CTA.lin_credito AS linea_credito,
    CTA.lin_credito - (CTA.sal_facturar + CTA.sal_facturado + CTA.sal_financiado + CTA.sal_cuo_pendientes) AS linea_disponible,
    'TARJETA' AS PRODUCTO,
    'TARJETA' AS PRODUCTO_COMISION,
    CASE
      WHEN CTA.cod_canal = 25 THEN 'CREDICENTRO'
      ELSE 'FIELCO'
    END AS CARTERA,
    CTA.COD_ENTE AS COD_CEDENTE,
    CTA.EMP_CEDENTE AS EMP_CEDENTE,
    CTA.VAL_PARAMETRO AS VAL_CEDENTE,
    ' ' AS ASOCIACION,
    CT.CAJA_DE_AHORRO,
    CASE
      WHEN CT.COD_USU_PROMOTOR IS NOT NULL THEN
          NVL(CT.COD_USU_PROMOTOR, ' ') || '-' || CT.nombre_promotor
      ELSE ' '
   END AS USU_PROMOTOR,
--
   CT.GARANTE AS GARANTE,
   CT.CODEUDORIA AS CODEUDORIA,
    CT.TOT_INGRESOS AS INGR_MENSUAL,
    CT.COD_CIUDAD_PAR AS COD_CIUDAD_PAR,
    CT.desc_ciu_particular AS CIUDAD_PAR,
    CT.COD_CIUDAD_LAB AS COD_CIUDAD_LAB,
    CT.desc_ciu_laboral AS CIUDAD_LAB,
    '' AS TEL_PRINCIPAL,
    NVL(CTA.MTO_MORA, 0) AS MONTO_MORA_OR,
    CASE
      WHEN CTA.COD_MONEDA = 'USD' THEN
        NVL(ROUND(NVL(CTA.MTO_MORA, 0) * CTA.COTIZ), 0)
      ELSE
        NVL(CTA.MTO_MORA, 0)
    END AS MONTO_MORA_GS,
--
    CASE
      WHEN CTA.COD_MONEDA = 'GS' THEN
        NVL(ROUND(NVL(CTA.MTO_MORA, 0) / CTA.COTIZ_USD), 0)
      ELSE
        NVL(CTA.MTO_MORA, 0)
    END AS MONTO_MORA_DLS,
    'N/A' AS TIPO_RENOVACION_R,
    '' AS NRO_CTA_RENOVADA,
    NVL(CT.DIR_CORREO, ' ') AS CORREO,
    -1 AS NRO_SOLICITUD,
    0 AS previsiones_r1,
    0 AS previsiones_cartera_r1,
    0 AS previsiones_diferidas_r1,
    0 AS previsiones_orden_r1,
    0 AS CAPITAL_PEND_GS,
    0 AS CAPITAL_INICIAL_GS,
    0 AS COD_DES_ESPECIFICO,
    0 as CAPITAL_PAGADO_GS,
    '' AS TIP_DES_ESPECIFICO,
    CT.FECHA_ONBOARDING,
    CT.INGRESO_ANUAL AS INGRESOS_ANUALES,
    CT.DEPARTAMENTO,
    CT.GARANTIA_DESC AS GARANTIA,
    0 AS VAL_TAS_NOMINAL,
    0 AS VAL_TAS_EFECTIVA,
    0 AS MTO_SEG_VIDA,
    0 AS MTO_SEG_INCAP,
    0 AS MTO_COM_DESEM,
    CTA.USU_APROBADOR,
    CT.CLI_CONFIDENCIAL AS CLI_CONFIDENCIAL,
    CT.CLI_ESPECIAL AS CLI_ESPECIAL,
    CTA.DEB_AUTOMATICO AS COB_AUTOMATICO,
    CTA.NRO_CTA_DEBITO AS NRO_CTA_DEBITO,
    RLA.ESTADO AS EST_CTA_DEBITO,
    RLA.COD_MONEDA AS MONEDA_CTA_DEBITO,

    CASE
      WHEN RLA.CONJUNTA > 1 THEN 'CONJUNTA'
      WHEN RLA.INDISTINTA > 1 THEN 'INDISTINTA'
      WHEN (RLA.PRINCIPAL >= 1 AND RLA.CONJUNTA = 0 AND RLA.INDISTINTA = 0) THEN 'INDIVIDUAL'
      else ''
    END REL_CTA_DEBITO,
    IR.TIP_INGRESO AS TIP_INGRESO,
    NVL(IR.MON_INGRESO, 0) AS MTO_INGRESO_APP,
    NVL(IR.MTO_ING_OFR, 0) AS MTO_ING_OFR,
    CTA.COD_RUB_ECONOMICO AS COD_RUB_ECONOMICO,
    NVL(CTA.DES_RUB_ECONOMICO, ' ') AS DES_RUB_ECONOMICO,
    CTA.COM_CTA_ORIGINAL AS COM_CTA_ORIGINAL,
    CT.COD_GRU_ECONOMICO AS COD_GRU_ECONOMICO,
    CT.DES_GRU_ECONOMICO,

    'TARJETA' AS MARCA_INT
  FROM datos_tarjetas cta
  INNER JOIN datos_cta_persona CT ON CT.nro_cuenta = CTA.nro_cuenta
  and ct.cod_modulo=cta.cod_modulo 
  and ct.cod_modalidad=cta.cod_modalidad
  LEFT JOIN RELACIONES RLA ON RLA.NRO_CUENTA = CTA.NRO_CTA_DEBITO
  LEFT JOIN INGRESOS IR ON IR.COD_PERSONA = ct.COD_PERSONA
)
, datos_op AS (
    SELECT
    Distinct
        CTA.cod_modulo
        ,MC.DESCRIPCION as desc_modulo
        ,CTA.COD_MODALIDAD
    ,mm.desc_modalidad
        ,CTA.cod_moneda
        ,CO.VAL_CONVERSION as COTIZ
        ,CO_USD.VAL_CONVERSION as COTIZ_USD
        ,CTA.cod_oficina
        ,bo.descripcion as desc_oficina
        ,CTA.ESTADO
        ,DE.descripcion as desc_est_cuenta
        ,CTA.SAL_TOTAL
        ,CTA.DIA_ATRASO
        ,cta.FEC_APERTURA
        ,TAR.fec_vencimiento
        ,CTA.en_juicio
        ,TAR.nro_tarjeta
        ,GEN.COD_ENTE
        ,GEN.DESCRIPCION AS EMP_CEDENTE
        ,CAD.VAL_PARAMETRO
    ,SB.VAL_TAS_NOMINAL as VAL_TAS_NOMINAL
        ,SB.VAL_TAS_EFECTIVA as VAL_TAS_EFECTIVA
        ,CTA.COD_RUB_ECONOMICO
        ,CAD_2.val_parametro as COM_CTA_ORIGINAL
        ,CTA.NRO_CUENTA
        ,ge.DESCRIPCION as DES_RUB_ECONOMICO
        ,PRE.MONTO AS MTO_PREVISION
	,cta.val_tasa
    FROM OV_CTA_VENCIDAS cta
    LEFT JOIN ta_tarjetas TAR
            ON TAR.NRO_CUENTA = CTA.nro_cuenta
            AND TAR.rel_tarjeta = '0'
            AND TAR.cod_estado <> '10'
    LEFT JOIN BA_MODULOS MC
            ON MC.COD_MODULO = CTA.COD_MODULO
    LEFT JOIN GE_CTA_DAT_ADICIONALES CAD
            ON CAD.NRO_CUENTA = CTA.NRO_CUENTA
            AND PARAMETRO = 'PRE_COD_ENT_COM_CARTERA'
    LEFT JOIN GE_ENTES GEN
            ON to_char(GEN.COD_ENTE) = to_char(CAD.VAL_PARAMETRO)
    LEFT JOIN  SB_TAS_APE_SEMANALES SB
            ON SB.NRO_CUENTA = CTA.NRO_CUENTA
    left JOIN datos_mod_modalidad mm on mm.cod_modulo = cta.cod_modulo and mm.cod_modalidad = cta.cod_modalidad
    left join OBT_COTIZACION co on co.cod_moneda = cta.cod_moneda
  left join OBT_COTIZACION co_usd on co_usd.cod_moneda = 'USD'
    left join ba_oficinas bo on bo.cod_oficina = cta.cod_oficina
  left join DES_EST_CTA DE on DE.cod_modulo = CTA.COD_MODULO and DE.cod_modalidad = CTA.COD_MODALIDAD and DE.estado = CTA.ESTADO
  LEFT JOIN GE_CTA_DAT_ADICIONALES CAD_2 ON CAD_2.NRO_CUENTA = CTA.NRO_CUENTA AND CAD_2.PARAMETRO = 'CRM_NRO_OPERACION'
    left join GE_RUB_ECONOMICOS ge
        on ge.COD_RUB_ECONOMICO = CTA.COD_RUB_ECONOMICO
    LEFT JOIN MAX_PREVISION_TAR PRE
        ON PRE.NRO_CUENTA = CTA.NRO_CUENTA

  WHERE CTA.ESTADO <> 'C'
)
-- PARTE OP
, OP AS (
    SELECT
      Distinct
      to_char(pag_cal.fu_obt_fec_actual(6), 'yyyy-mm-dd') as FECHA_PROCESO,
      CTA.cod_modulo AS MODULO_COD,
            CTA.desc_modulo AS MODULO,
            CTA.COD_MODALIDAD AS MODALIDAD_COD,
            CTA.desc_modalidad AS MODALIDAD,
      null as sub_modalidad_cod, --nuevo
      null as sub_modalidad, --nuevo
            CT.COD_PERSONA AS COD_PERSONA,
            CT.nom_completo AS NOMBRE_CLIENTE,
            CT.cod_actividad AS COD_ACTIVIDAD,
            CASE
                WHEN CT.desc_actividad IS NULL THEN 'Rubro / Actividad no registrados en el Sistema'
                ELSE CT.desc_actividad
            END AS DES_ACTIVIDAD,
            CT.NRO_DOCUMENTO AS NRODOC,
            CT.TIPO AS TIPOPERSONA,
            CT.COD_SEXO AS SEXO,
            CT.FEC_NACIMIENTO AS FEC_NACIMIENTO,
      TRUNC(((pag_cal.fu_obt_fec_actual(6)) - CT.FEC_NACIMIENTO) / 365.25)  as edad,
          CTA.nro_cuenta AS NRO_CUENTA,
            0 AS DIGITO_VERIFICADOR,
            CTA.cod_moneda AS COD_MONEDA,
            NVL(CTA.COTIZ, 1) AS cotizacion,
            CTA.cod_oficina AS SUCURSAL_COD,
            CTA.desc_oficina AS SUCURSAL,
            CTA.ESTADO AS ESTADO_COD,
            CTA.desc_est_cuenta AS ESTADO,
            0 AS MONTO_DESEMBOLSADO_OR,
            CTA.SAL_TOTAL AS SALDO_OR,
            NVL(CTA.SAL_TOTAL,0) AS CARTERA_TOTAL_OR,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) > 60 THEN
            NVL(CTA.SAL_TOTAL, 0)
        ELSE 0
        END AS CARTERA_VENCIDA_OR,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) <= 60 THEN
            NVL(CTA.SAL_TOTAL, 0)
        ELSE 0
        END AS CARTERA_VIGENTE_OR,
        0 as MONTO_DESEMBOLSADO_GS,
        CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
          (NVL(CTA.SAL_TOTAL, 0))*(CTA.COTIZ)
        ELSE
          NVL(CTA.SAL_TOTAL,0)
        END as SALDO_GS,
        CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND((NVL((CTA.SAL_TOTAL),0)*(CTA.COTIZ))),0)
        ELSE NVL((CTA.SAL_TOTAL), 0)
        END AS CARTERA_TOTAL_GS,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) > 60 THEN
          CASE
            WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND((NVL((CTA.SAL_TOTAL),0)*(CTA.COTIZ))),0)
          ELSE NVL((CTA.SAL_TOTAL), 0)
          END
        ELSE 0
        END AS CARTERA_VENCIDA_GS,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) <= 60 THEN
          CASE
            WHEN CTA.COD_MONEDA = 'USD' THEN
              NVL(ROUND((NVL((CTA.SAL_TOTAL),0)*(CTA.COTIZ))),0)
          ELSE NVL((CTA.SAL_TOTAL),0)
          END
        ELSE 0
        END AS CARTERA_VIGENTE_GS,
        0 as MONTO_DESEMBOLSADO_DLS,
        CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
            ROUND((NVL((CTA.SAL_TOTAL), 0))/(CTA.COTIZ_USD))
        ELSE NVL((CTA.SAL_TOTAL),0)
        END as SALDO_DLS,
        CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
            NVL(ROUND(NVL((CTA.SAL_TOTAL), 0)/(CTA.COTIZ_USD)),0)
        ELSE
              NVL(CTA.SAL_TOTAL, 0)
        END AS CARTERA_TOTAL_DLS,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) > 60 THEN
          CASE
            WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND((NVL((CTA.SAL_TOTAL),0)/(CTA.COTIZ_USD))),0)
          ELSE NVL((CTA.SAL_TOTAL), 0)
          END
        ELSE 0
        END AS CARTERA_VENCIDA_DLS,
        CASE
          WHEN NVL(CTA.DIA_ATRASO,0) <= 60 THEN
          CASE
            WHEN CTA.COD_MONEDA = 'GS' THEN
              NVL(ROUND(NVL(CTA.SAL_TOTAL, 0)/(CTA.COTIZ_USD)),0)
          ELSE NVL((CTA.SAL_TOTAL), 0)
          END
        ELSE 0 END AS CARTERA_VIGENTE_DLS,
        0 AS SAL_INTERES_OR,
        0 AS A_DEVENGAR_OR,
        0 AS DEV_ACUMULADO_OR,
        0 AS DEV_NO_COBRADO_OR,
        0 AS DEV_SUSPENSO_OR,
            NVL(CTA.MTO_PREVISION,0) AS PREVISION_OR,
        0 AS SAL_INTERES_GS,
        0 AS A_DEVENGAR_GS,
        0 AS DEV_ACUMULADO_GS,
        0 AS DEV_NO_COBRADO_GS,
        0 AS DEV_SUSPENSO_GS,
        CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND(NVL(CTA.MTO_PREVISION, 0)* CTA.COTIZ), 0)
          ELSE
            NVL(CTA.MTO_PREVISION, 0)
        END AS PREVISION_GS,
        0 AS SAL_INTERES_DLS,
        0 AS A_DEVENGAR_DLS,
        0 AS DEV_ACUMULADO_DLS,
        0 AS DEV_NO_COBRADO_DLS,
        0 AS DEV_SUSPENSO_DLS,
        CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
             NVL(ROUND(NVL(CTA.MTO_PREVISION, 0)/ CTA.COTIZ_USD), 0)
          ELSE
             NVL(CTA.MTO_PREVISION, 0)
        END AS PREVISION_DLS,
        CT.cod_usu_oficial AS ASESOR,
        cta.FEC_APERTURA AS EMISION,
        cta.fec_vencimiento AS VENCIMIENTO,
        0 AS PLAZO,
        '' AS DES_PLAZO,
        val_tasa as tasa,
        NVL(CTA.DIA_ATRASO,0)  AS DIAS_ATRASO,
        NVL(CTA.DIA_ATRASO,0) AS MAX_ATRASO,
        NVL(CTA.DIA_ATRASO,0) AS PRO_ATRASO,
        0 AS PER_VTO_CAPITAL,
        CT.cod_seg_cliente AS COD_SEGMENTO,
        CT.des_segmento AS SEGMENTO,
        NVL(CTA.en_juicio,'N') as JUDICIALIZADO,
        0 as CAN_CUOTAS,
        0 as CAN_CUOTAS_PAG,
        0 as CAN_CUOTAS_PEND,
        CT.cat_automatica AS CAT_AUTOMATICA,
        CT.cat_riesgo AS CAT_RIESGO,
        CT.cat_sistema AS CAT_SISTEMA,
        0 as TIP_DESTINO,
        'N/A' AS DES_DESTINO,
        -1 as COD_CAMPANA,
        ' ' AS DES_CAMPANA,
        -1 AS COD_CANAL,
        '' AS DES_CANAL,
        '' AS AMORTIZACION,
        '' AS TIP_AMORTIZACION,
        '' AS TIP_INTERES,
        CT.cod_sec_contable AS COD_SEC_CONTABLE,
        CT.SEC_CONTABLE  AS SEC_CONTABLE,
        CT.cod_tip_deudor AS COD_TIP_DEUDOR,
        CT.TIP_DEUDOR  AS TIP_DEUDOR,
        CT.COD_TIP_CLIENTE AS COD_TIP_CLIENTE,
        CASE
                WHEN CT.TIP_CLIENTE IS NULL THEN ''
                ELSE CT.TIP_CLIENTE
          END AS TIP_CLIENTE,
        CTA.nro_tarjeta AS NRO_TERJETA,
        CTA.nro_cuenta AS CTA_BANCARD,
        '' AS AFINIDAD,
        '' AS DES_AFINIDAD,
        0 as mto_pag_minimo,
        0 as linea_credito,
        0 as linea_disponible,
        CASE
          WHEN (CTA.COD_MODALIDAD = '151') THEN 'TARJETA'
          ELSE 'FIDEICOMISO -OV'
          END AS PRODUCTO,
        CASE
          WHEN (CTA.COD_MODALIDAD = '151')  THEN 'TARJETA'
          ELSE 'FIDEICOMISO -OV'
          END AS PRODUCTO_COMISION,
        null AS CARTERA,
        CTA.COD_ENTE AS COD_CEDENTE,
        CTA.EMP_CEDENTE AS EMP_CEDENTE,
        CTA.VAL_PARAMETRO AS VAL_CEDENTE,
        ' ' AS ASOCIACION,
        CT.CAJA_DE_AHORRO,
        CASE
                WHEN CT.COD_USU_PROMOTOR IS NOT NULL THEN
              NVL(CT.COD_USU_PROMOTOR, ' ') || '-' || CT.nombre_promotor
              ELSE ' '
            END AS USU_PROMOTOR,
            CT.GARANTE AS GARANTE,
        CT.CODEUDORIA AS CODEUDORIA,
        CT.TOT_INGRESOS AS INGR_MENSUAL,
        CT.COD_CIUDAD_PAR AS COD_CIUDAD_PAR,
        CT.desc_ciu_particular AS CIUDAD_PAR,
        CT.COD_CIUDAD_LAB AS COD_CIUDAD_LAB,
        CT.desc_ciu_laboral AS CIUDAD_LAB,
         ' ' AS TEL_PRINCIPAL,
            NVL(CTA.SAL_TOTAL,0) AS MONTO_MORA_OR,
        CASE
          WHEN CTA.COD_MONEDA = 'USD' THEN
            NVL(ROUND((NVL(CTA.SAL_TOTAL,0)*(CTA.COTIZ))),0)
        ELSE NVL(CTA.SAL_TOTAL, 0)
        END AS MONTO_MORA_GS,
        CASE
          WHEN CTA.COD_MONEDA = 'GS' THEN
            NVL(ROUND((NVL(CTA.SAL_TOTAL,0)/(CTA.COTIZ_USD))),0)
        ELSE NVL(CTA.SAL_TOTAL, 0)
        END AS MONTO_MORA_DLS,
        'N/A' AS TIPO_RENOVACION_R,
        ' ' AS NRO_CTA_RENOVADA,
        NVL(CT.DIR_CORREO, ' ') AS CORREO,
        -1 AS NRO_SOLICITUD,
        0 as previsiones_r1,
        0 AS previsiones_cartera_r1,
        0 AS previsiones_diferidas_r1,
        0 AS previsiones_orden_r1,
        --0 AS CAPITAL_INICIAL_GS,
        0 AS CAPITAL_PEND_GS,
        0 AS CAPITAL_INICIAL_GS,
        0 as CAPITAL_PAGADO_GS,
        0 AS COD_DES_ESPECIFICO,
        ' ' AS TIP_DES_ESPECIFICO,
        CT.FECHA_ONBOARDING,
        CT.INGRESO_ANUAL AS INGRESOS_ANUALES,
          CT.DEPARTAMENTO,
            CT.GARANTIA_DESC AS GARANTIA,
        CTA.VAL_TAS_NOMINAL,
        CTA.VAL_TAS_EFECTIVA,
        0 AS  MTO_SEG_VIDA,
        0 AS  MTO_SEG_INCAP,
        0 AS  MTO_COM_DESEM,
        '-' AS USU_APROBADOR,
        CT.CLI_CONFIDENCIAL,
        CT.CLI_ESPECIAL,
        ' ' COB_AUTOMATICO,
        ' ' AS NRO_CTA_DEBITO,
        ' ' AS EST_CTA_DEBITO,
        ' ' AS MONEDA_CTA_DEBITO,
        ' ' AS REL_CTA_DEBITO,
        IR.TIP_INGRESO,
        IR.MON_INGRESO MTO_INGRESO_APP,
        IR.MTO_ING_OFR,
        CTA.COD_RUB_ECONOMICO,
        NVL(CTA.DES_RUB_ECONOMICO, ' ') AS DES_RUB_ECONOMICO,
            CTA.COM_CTA_ORIGINAL AS COM_CTA_ORIGINAL,
        CT.COD_GRU_ECONOMICO,
        CT.DES_GRU_ECONOMICO,
        'CTA_VENCIDAS' AS MARCA_INT
        FROM datos_op cta
        INNER JOIN datos_cta_persona CT ON CT.NRO_CUENTA = CTA.NRO_CUENTA
        and ct.cod_modulo=cta.cod_modulo 
        and ct.cod_modalidad=cta.cod_modalidad 
        and ct.relacion = 'P'
        LEFT JOIN INGRESOS IR ON IR.COD_PERSONA = CT.COD_PERSONA
)
select  FECHA_PROCESO,
        MODULO_COD,
        MODULO,
        MODALIDAD_COD,
        MODALIDAD,
        SUB_MODALIDAD_COD,
        SUB_MODALIDAD,
        COD_PERSONA,
        NOMBRE_CLIENTE,
        COD_ACTIVIDAD,
        DES_ACTIVIDAD,
        NRODOC,
        TIPOPERSONA,
        SEXO,
        FEC_NACIMIENTO,
        EDAD,
        NRO_CUENTA,
        DIGITO_VERIFICADOR,
        COD_MONEDA,
        COTIZACION,
        SUCURSAL_COD,
        SUCURSAL,
        ESTADO_COD,
        ESTADO,
        MONTO_DESEMBOLSADO_OR,
        SALDO_OR,
        CARTERA_TOTAL_OR,
        CARTERA_VENCIDA_OR,
        CARTERA_VIGENTE_OR,
        MONTO_DESEMBOLSADO_GS,
        SALDO_GS,
        CARTERA_TOTAL_GS,
        CARTERA_VENCIDA_GS,
        CARTERA_VIGENTE_GS,
        MONTO_DESEMBOLSADO_DLS,
        SALDO_DLS,
        CARTERA_TOTAL_DLS,
        CARTERA_VENCIDA_DLS,
        CARTERA_VIGENTE_DLS,
        SAL_INTERES_OR,
        A_DEVENGAR_OR,
        DEV_ACUMULADO_OR,
        DEV_NO_COBRADO_OR,
        DEV_SUSPENSO_OR,
        PREVISION_OR,
        SAL_INTERES_GS,
        A_DEVENGAR_GS,
        DEV_ACUMULADO_GS,
        DEV_NO_COBRADO_GS,
        DEV_SUSPENSO_GS,
        PREVISION_GS,
        SAL_INTERES_DLS,
        A_DEVENGAR_DLS,
        DEV_ACUMULADO_DLS,
        DEV_NO_COBRADO_DLS,
        DEV_SUSPENSO_DLS,
        PREVISION_DLS,
        ASESOR,
        EMISION,
        VENCIMIENTO,
        PLAZO,
        DES_PLAZO,
        TASA,
        DIAS_ATRASO,
        MAX_ATRASO,
        PRO_ATRASO,
        PER_VTO_CAPITAL,
        COD_SEGMENTO,
        SEGMENTO,
        JUDICIALIZADO,
        CAN_CUOTAS,
        CAN_CUOTAS_PAG,
        CAN_CUOTAS_PEND,
        CAT_AUTOMATICA,
        CAT_RIESGO,
        CAT_SISTEMA,
        TIP_DESTINO,
        DES_DESTINO,
        COD_CAMPANA,
        DES_CAMPANA,
        COD_CANAL,
        DES_CANAL,
        AMORTIZACION,
        TIP_AMORTIZACION,
        TIP_INTERES,
        COD_SEC_CONTABLE,
        SEC_CONTABLE,
        COD_TIP_DEUDOR,
        TIP_DEUDOR,
        COD_TIP_CLIENTE,
        TIP_CLIENTE,
        NRO_TERJETA,
        CTA_BANCARD,
        AFINIDAD,
        DES_AFINIDAD,
        MTO_PAG_MINIMO,
        LINEA_CREDITO,
        LINEA_DISPONIBLE,
        PRODUCTO,
        PRODUCTO_COMISION,
        CARTERA,
        COD_CEDENTE,
        EMP_CEDENTE,
        VAL_CEDENTE,
        ASOCIACION,
        CAJA_DE_AHORRO,
        USU_PROMOTOR,
        GARANTE,
        CODEUDORIA,
        INGR_MENSUAL,
        COD_CIUDAD_PAR,
        CIUDAD_PAR,
        COD_CIUDAD_LAB,
        CIUDAD_LAB,
        TEL_PRINCIPAL,
        MONTO_MORA_OR,
        MONTO_MORA_GS,
        MONTO_MORA_DLS,
        TIPO_RENOVACION_R,
        NRO_CTA_RENOVADA,
        CORREO,
        NRO_SOLICITUD,
        PREVISIONES_R1,
        PREVISIONES_CARTERA_R1,
        PREVISIONES_DIFERIDAS_R1,
        PREVISIONES_ORDEN_R1,
        CAPITAL_INICIAL_GS,
        CAPITAL_PEND_GS,
        CAPITAL_PAGADO_GS,
        COD_DES_ESPECIFICO,
        TIP_DES_ESPECIFICO,
        FECHA_ONBOARDING,
        INGRESOS_ANUALES,
        DEPARTAMENTO,
        GARANTIA,
        VAL_TAS_NOMINAL,
        VAL_TAS_EFECTIVA,
        MTO_SEG_VIDA,
        MTO_SEG_INCAP,
        MTO_COM_DESEM,
        USU_APROBADOR,
        CLI_CONFIDENCIAL,
        CLI_ESPECIAL,
        COB_AUTOMATICO,
        NRO_CTA_DEBITO,
        EST_CTA_DEBITO,
        MONEDA_CTA_DEBITO,
        REL_CTA_DEBITO,
        TIP_INGRESO,
        MTO_INGRESO_APP,
        MTO_ING_OFR,
        COD_RUB_ECONOMICO,
        DES_RUB_ECONOMICO,
        COM_CTA_ORIGINAL,
        COD_GRU_ECONOMICO,
        DES_GRU_ECONOMICO,
        MARCA_INT
from prestamos
union all
select FECHA_PROCESO,
        MODULO_COD,
        MODULO,
        MODALIDAD_COD,
        MODALIDAD,
        SUB_MODALIDAD_COD,
        SUB_MODALIDAD,
        COD_PERSONA,
        NOMBRE_CLIENTE,
        COD_ACTIVIDAD,
        DES_ACTIVIDAD,
        NRODOC,
        TIPOPERSONA,
        SEXO,
        FEC_NACIMIENTO,
        EDAD,
        NRO_CUENTA,
        DIGITO_VERIFICADOR,
        COD_MONEDA,
        COTIZACION,
        SUCURSAL_COD,
        SUCURSAL,
        ESTADO_COD,
        ESTADO,
        MONTO_DESEMBOLSADO_OR,
        SALDO_OR,
        CARTERA_TOTAL_OR,
        CARTERA_VENCIDA_OR,
        CARTERA_VIGENTE_OR,
        MONTO_DESEMBOLSADO_GS,
        SALDO_GS,
        CARTERA_TOTAL_GS,
        CARTERA_VENCIDA_GS,
        CARTERA_VIGENTE_GS,
        MONTO_DESEMBOLSADO_DLS,
        SALDO_DLS,
        CARTERA_TOTAL_DLS,
        CARTERA_VENCIDA_DLS,
        CARTERA_VIGENTE_DLS,
        SAL_INTERES_OR,
        A_DEVENGAR_OR,
        DEV_ACUMULADO_OR,
        DEV_NO_COBRADO_OR,
        DEV_SUSPENSO_OR,
        PREVISION_OR,
        SAL_INTERES_GS,
        A_DEVENGAR_GS,
        DEV_ACUMULADO_GS,
        DEV_NO_COBRADO_GS,
        DEV_SUSPENSO_GS,
        PREVISION_GS,
        SAL_INTERES_DLS,
        A_DEVENGAR_DLS,
        DEV_ACUMULADO_DLS,
        DEV_NO_COBRADO_DLS,
        DEV_SUSPENSO_DLS,
        PREVISION_DLS,
        ASESOR,
        EMISION,
        VENCIMIENTO,
        PLAZO,
        DES_PLAZO,
        TASA,
        DIAS_ATRASO,
        MAX_ATRASO,
        PRO_ATRASO,
        PER_VTO_CAPITAL,
        COD_SEGMENTO,
        SEGMENTO,
        JUDICIALIZADO,
        CAN_CUOTAS,
        CAN_CUOTAS_PAG,
        CAN_CUOTAS_PEND,
        CAT_AUTOMATICA,
        CAT_RIESGO,
        CAT_SISTEMA,
        TIP_DESTINO,
        DES_DESTINO,
        COD_CAMPANA,
        DES_CAMPANA,
        COD_CANAL,
        DES_CANAL,
        AMORTIZACION,
        TIP_AMORTIZACION,
        TIP_INTERES,
        COD_SEC_CONTABLE,
        SEC_CONTABLE,
        COD_TIP_DEUDOR,
        TIP_DEUDOR,
        COD_TIP_CLIENTE,
        TIP_CLIENTE,
        NRO_TERJETA,
        CTA_BANCARD,
        AFINIDAD,
        DES_AFINIDAD,
        MTO_PAG_MINIMO,
        LINEA_CREDITO,
        LINEA_DISPONIBLE,
        PRODUCTO,
        PRODUCTO_COMISION,
        CARTERA,
        COD_CEDENTE,
        EMP_CEDENTE,
        VAL_CEDENTE,
        ASOCIACION,
        CAJA_DE_AHORRO,
        USU_PROMOTOR,
        GARANTE,
        CODEUDORIA,
        INGR_MENSUAL,
        COD_CIUDAD_PAR,
        CIUDAD_PAR,
        COD_CIUDAD_LAB,
        CIUDAD_LAB,
        TEL_PRINCIPAL,
        MONTO_MORA_OR,
        MONTO_MORA_GS,
        MONTO_MORA_DLS,
        TIPO_RENOVACION_R,
        NRO_CTA_RENOVADA,
        CORREO,
        NRO_SOLICITUD,
        PREVISIONES_R1,
        PREVISIONES_CARTERA_R1,
        PREVISIONES_DIFERIDAS_R1,
        PREVISIONES_ORDEN_R1,
        CAPITAL_INICIAL_GS,
        CAPITAL_PEND_GS,
        CAPITAL_PAGADO_GS,
        COD_DES_ESPECIFICO,
        TIP_DES_ESPECIFICO,
        FECHA_ONBOARDING,
        INGRESOS_ANUALES,
        DEPARTAMENTO,
        GARANTIA,
        VAL_TAS_NOMINAL,
        VAL_TAS_EFECTIVA,
        MTO_SEG_VIDA,
        MTO_SEG_INCAP,
        MTO_COM_DESEM,
        USU_APROBADOR,
        CLI_CONFIDENCIAL,
        CLI_ESPECIAL,
        COB_AUTOMATICO,
        NRO_CTA_DEBITO,
        EST_CTA_DEBITO,
        MONEDA_CTA_DEBITO,
        REL_CTA_DEBITO,
        TIP_INGRESO,
        MTO_INGRESO_APP,
        MTO_ING_OFR,
        COD_RUB_ECONOMICO,
        DES_RUB_ECONOMICO,
        COM_CTA_ORIGINAL,
        COD_GRU_ECONOMICO,
        DES_GRU_ECONOMICO,
        MARCA_INT
from tarjetas
union all
select FECHA_PROCESO,
        MODULO_COD,
        MODULO,
        MODALIDAD_COD,
        MODALIDAD,
        SUB_MODALIDAD_COD,
        SUB_MODALIDAD,
        COD_PERSONA,
        NOMBRE_CLIENTE,
        COD_ACTIVIDAD,
        DES_ACTIVIDAD,
        NRODOC,
        TIPOPERSONA,
        SEXO,
        FEC_NACIMIENTO,
        EDAD,
        NRO_CUENTA,
        DIGITO_VERIFICADOR,
        COD_MONEDA,
        COTIZACION,
        SUCURSAL_COD,
        SUCURSAL,
        ESTADO_COD,
        ESTADO,
         case when modulo_cod= 15 and modalidad_cod = '153' and monto_desembolsado_or < 0 then monto_desembolsado_or * -1 else monto_desembolsado_or end as monto_desembolsado_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and saldo_or < 0 then saldo_or * -1 else saldo_or end as saldo_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_total_or < 0 then cartera_total_or * -1 else cartera_total_or end as cartera_total_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vencida_or < 0 then cartera_vencida_or * -1 else cartera_vencida_or end as cartera_vencida_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vigente_or < 0 then cartera_vigente_or * -1 else cartera_vigente_or end as cartera_vigente_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and monto_desembolsado_gs < 0 then monto_desembolsado_gs * -1 else monto_desembolsado_gs end as monto_desembolsado_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and saldo_gs < 0 then saldo_gs * -1 else saldo_gs end as saldo_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_total_gs < 0 then cartera_total_gs * -1 else cartera_total_gs end as cartera_total_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vencida_gs < 0 then cartera_vencida_gs * -1 else cartera_vencida_gs end as cartera_vencida_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vigente_gs < 0 then cartera_vigente_gs * -1 else cartera_vigente_gs end as cartera_vigente_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and monto_desembolsado_dls < 0 then monto_desembolsado_dls * -1 else monto_desembolsado_dls end as monto_desembolsado_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and saldo_dls < 0 then saldo_dls * -1 else saldo_dls end as saldo_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_total_dls < 0 then cartera_total_dls * -1 else cartera_total_dls end as cartera_total_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vencida_dls < 0 then cartera_vencida_dls * -1 else cartera_vencida_dls end as cartera_vencida_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and cartera_vigente_dls < 0 then cartera_vigente_dls * -1 else cartera_vigente_dls end as cartera_vigente_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and sal_interes_or < 0 then sal_interes_or * -1 else sal_interes_or end as sal_interes_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and a_devengar_or < 0 then a_devengar_or * -1 else a_devengar_or end as a_devengar_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_acumulado_or < 0 then dev_acumulado_or * -1 else dev_acumulado_or end as dev_acumulado_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_no_cobrado_or < 0 then dev_no_cobrado_or * -1 else dev_no_cobrado_or end as dev_no_cobrado_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_suspenso_or < 0 then dev_suspenso_or * -1 else dev_suspenso_or end as dev_suspenso_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and prevision_or < 0 then prevision_or * -1 else prevision_or end as prevision_or
        , case when modulo_cod= 15 and modalidad_cod = '153' and sal_interes_gs < 0 then sal_interes_gs * -1 else sal_interes_gs end as sal_interes_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and a_devengar_gs < 0 then a_devengar_gs * -1 else a_devengar_gs end as a_devengar_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_acumulado_gs < 0 then dev_acumulado_gs * -1 else dev_acumulado_gs end as dev_acumulado_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_no_cobrado_gs < 0 then dev_no_cobrado_gs * -1 else dev_no_cobrado_gs end as dev_no_cobrado_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_suspenso_gs < 0 then dev_suspenso_gs * -1 else dev_suspenso_gs end as dev_suspenso_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and prevision_gs < 0 then prevision_gs * -1 else prevision_gs end as prevision_gs
        , case when modulo_cod= 15 and modalidad_cod = '153' and sal_interes_dls < 0 then sal_interes_dls * -1 else sal_interes_dls end as sal_interes_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and a_devengar_dls < 0 then a_devengar_dls * -1 else a_devengar_dls end as a_devengar_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_acumulado_dls < 0 then dev_acumulado_dls * -1 else dev_acumulado_dls end as dev_acumulado_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_no_cobrado_dls < 0 then dev_no_cobrado_dls * -1 else dev_no_cobrado_dls end as dev_no_cobrado_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and dev_suspenso_dls < 0 then dev_suspenso_dls * -1 else dev_suspenso_dls end as dev_suspenso_dls
        , case when modulo_cod= 15 and modalidad_cod = '153' and prevision_dls < 0 then prevision_dls * -1 else prevision_dls end as prevision_dls
        ,ASESOR,
        EMISION,
        VENCIMIENTO,
        PLAZO,
        DES_PLAZO,
        TASA,
        DIAS_ATRASO,
        MAX_ATRASO,
        PRO_ATRASO,
        PER_VTO_CAPITAL,
        COD_SEGMENTO,
        SEGMENTO,
        JUDICIALIZADO,
        CAN_CUOTAS,
        CAN_CUOTAS_PAG,
        CAN_CUOTAS_PEND,
        CAT_AUTOMATICA,
        CAT_RIESGO,
        CAT_SISTEMA,
        TIP_DESTINO,
        DES_DESTINO,
        COD_CAMPANA,
        DES_CAMPANA,
        COD_CANAL,
        DES_CANAL,
        AMORTIZACION,
        TIP_AMORTIZACION,
        TIP_INTERES,
        COD_SEC_CONTABLE,
        SEC_CONTABLE,
        COD_TIP_DEUDOR,
        TIP_DEUDOR,
        COD_TIP_CLIENTE,
        TIP_CLIENTE,
        NRO_TERJETA,
        CTA_BANCARD,
        AFINIDAD,
        DES_AFINIDAD,
        MTO_PAG_MINIMO,
        LINEA_CREDITO,
        LINEA_DISPONIBLE,
        PRODUCTO,
        PRODUCTO_COMISION,
        CARTERA,
        COD_CEDENTE,
        EMP_CEDENTE,
        VAL_CEDENTE,
        ASOCIACION,
        CAJA_DE_AHORRO,
        USU_PROMOTOR,
        GARANTE,
        CODEUDORIA,
        INGR_MENSUAL,
        COD_CIUDAD_PAR,
        CIUDAD_PAR,
        COD_CIUDAD_LAB,
        CIUDAD_LAB,
        TEL_PRINCIPAL,
        MONTO_MORA_OR,
        MONTO_MORA_GS,
        MONTO_MORA_DLS,
        TIPO_RENOVACION_R,
        NRO_CTA_RENOVADA,
        CORREO,
        NRO_SOLICITUD,
        PREVISIONES_R1,
        PREVISIONES_CARTERA_R1,
        PREVISIONES_DIFERIDAS_R1,
        PREVISIONES_ORDEN_R1,
        CAPITAL_INICIAL_GS,
        CAPITAL_PEND_GS,
        CAPITAL_PAGADO_GS,
        COD_DES_ESPECIFICO,
        TIP_DES_ESPECIFICO,
        FECHA_ONBOARDING,
        INGRESOS_ANUALES,
        DEPARTAMENTO,
        GARANTIA,
        VAL_TAS_NOMINAL,
        VAL_TAS_EFECTIVA,
        MTO_SEG_VIDA,
        MTO_SEG_INCAP,
        MTO_COM_DESEM,
        USU_APROBADOR,
        CLI_CONFIDENCIAL,
        CLI_ESPECIAL,
        COB_AUTOMATICO,
        NRO_CTA_DEBITO,
        EST_CTA_DEBITO,
        MONEDA_CTA_DEBITO,
        REL_CTA_DEBITO,
        TIP_INGRESO,
        MTO_INGRESO_APP,
        MTO_ING_OFR,
        COD_RUB_ECONOMICO,
        DES_RUB_ECONOMICO,
        COM_CTA_ORIGINAL,
        COD_GRU_ECONOMICO,
        DES_GRU_ECONOMICO,
        MARCA_INT
from op
union all
select FECHA_PROCESO,
        MODULO_COD,
        MODULO,
        MODALIDAD_COD,
        MODALIDAD,
        SUB_MODALIDAD_COD,
        SUB_MODALIDAD,
        COD_PERSONA,
        NOMBRE_CLIENTE,
        COD_ACTIVIDAD,
        DES_ACTIVIDAD,
        NRODOC,
        TIPOPERSONA,
        SEXO,
        FEC_NACIMIENTO,
        EDAD,
        NRO_CUENTA,
        DIGITO_VERIFICADOR,
        COD_MONEDA,
        COTIZACION,
        SUCURSAL_COD,
        SUCURSAL,
        ESTADO_COD,
        ESTADO,
        MONTO_DESEMBOLSADO_OR,
        SALDO_OR,
        CARTERA_TOTAL_OR,
        CARTERA_VENCIDA_OR,
        CARTERA_VIGENTE_OR,
        MONTO_DESEMBOLSADO_GS,
        SALDO_GS,
        CARTERA_TOTAL_GS,
        CARTERA_VENCIDA_GS,
        CARTERA_VIGENTE_GS,
        MONTO_DESEMBOLSADO_DLS,
        SALDO_DLS,
        CARTERA_TOTAL_DLS,
        CARTERA_VENCIDA_DLS,
        CARTERA_VIGENTE_DLS,
        SAL_INTERES_OR,
        A_DEVENGAR_OR,
        DEV_ACUMULADO_OR,
        DEV_NO_COBRADO_OR,
        DEV_SUSPENSO_OR,
        PREVISION_OR,
        SAL_INTERES_GS,
        A_DEVENGAR_GS,
        DEV_ACUMULADO_GS,
        DEV_NO_COBRADO_GS,
        DEV_SUSPENSO_GS,
        PREVISION_GS,
        SAL_INTERES_DLS,
        A_DEVENGAR_DLS,
        DEV_ACUMULADO_DLS,
        DEV_NO_COBRADO_DLS,
        DEV_SUSPENSO_DLS,
        PREVISION_DLS,
        ASESOR,
        EMISION,
        VENCIMIENTO,
        PLAZO,
        DES_PLAZO,
        TASA,
        DIAS_ATRASO,
        MAX_ATRASO,
        PRO_ATRASO,
        PER_VTO_CAPITAL,
        COD_SEGMENTO,
        SEGMENTO,
        JUDICIALIZADO,
        CAN_CUOTAS,
        CAN_CUOTAS_PAG,
        CAN_CUOTAS_PEND,
        CAT_AUTOMATICA,
        CAT_RIESGO,
        CAT_SISTEMA,
        TIP_DESTINO,
        DES_DESTINO,
        COD_CAMPANA,
        DES_CAMPANA,
        COD_CANAL,
        DES_CANAL,
        AMORTIZACION,
        TIP_AMORTIZACION,
        TIP_INTERES,
        COD_SEC_CONTABLE,
        SEC_CONTABLE,
        COD_TIP_DEUDOR,
        TIP_DEUDOR,
        COD_TIP_CLIENTE,
        TIP_CLIENTE,
        NRO_TERJETA,
        CTA_BANCARD,
        AFINIDAD,
        DES_AFINIDAD,
        MTO_PAG_MINIMO,
        LINEA_CREDITO,
        LINEA_DISPONIBLE,
        PRODUCTO,
        PRODUCTO_COMISION,
        CARTERA,
        COD_CEDENTE,
        EMP_CEDENTE,
        VAL_CEDENTE,
        ASOCIACION,
        CAJA_DE_AHORRO,
        USU_PROMOTOR,
        GARANTE,
        CODEUDORIA,
        INGR_MENSUAL,
        COD_CIUDAD_PAR,
        CIUDAD_PAR,
        COD_CIUDAD_LAB,
        CIUDAD_LAB,
        TEL_PRINCIPAL,
        MONTO_MORA_OR,
        MONTO_MORA_GS,
        MONTO_MORA_DLS,
        TIPO_RENOVACION_R,
        NRO_CTA_RENOVADA,
        CORREO,
        NRO_SOLICITUD,
        PREVISIONES_R1,
        PREVISIONES_CARTERA_R1,
        PREVISIONES_DIFERIDAS_R1,
        PREVISIONES_ORDEN_R1,
        CAPITAL_INICIAL_GS,
        CAPITAL_PEND_GS,
        CAPITAL_PAGADO_GS,
        COD_DES_ESPECIFICO,
        TIP_DES_ESPECIFICO,
        FECHA_ONBOARDING,
        INGRESOS_ANUALES,
        DEPARTAMENTO,
        GARANTIA,
        VAL_TAS_NOMINAL,
        VAL_TAS_EFECTIVA,
        MTO_SEG_VIDA,
        MTO_SEG_INCAP,
        MTO_COM_DESEM,
        USU_APROBADOR,
        CLI_CONFIDENCIAL,
        CLI_ESPECIAL,
        COB_AUTOMATICO,
        NRO_CTA_DEBITO,
        EST_CTA_DEBITO,
        MONEDA_CTA_DEBITO,
        REL_CTA_DEBITO,
        TIP_INGRESO,
        MTO_INGRESO_APP,
        MTO_ING_OFR,
        COD_RUB_ECONOMICO,
        DES_RUB_ECONOMICO,
        COM_CTA_ORIGINAL,
        COD_GRU_ECONOMICO,
        DES_GRU_ECONOMICO,
        MARCA_INT
from datos_cc;