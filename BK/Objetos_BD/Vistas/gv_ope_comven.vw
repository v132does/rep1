CREATE OR REPLACE FORCE VIEW IT.GV_OPE_COMVEN AS
select xx.fecha,
       decode(xx.cla_operacion,1,'1-BANCO',2,'2-CASAS DE CAMBIO',3,'3-FINANCIERA',4,'4-SOC. AHORRO Y PTMOS. PARA LA VIVIENDA',5,'5-PARTICULARES',6,'6-SECTOR PUBLICO',7,'7-ARBITRAJES',8,'8-CONSOLIDADOS DE OPE. < 30.000',9,'9-OTRAS OPE') cla_operacion,
       xx.nombre,
       xx.cod_persona,
       xx.nro_doc,
       xx.tip_operacion,
       xx.cod_mad_padre,
       xx.cod_moneda,
       xx.cotizacion,
       nvl(xx.mto_compra,0) mto_compra,
       nvl(xx.mto_venta,0) mto_venta,
       nvl(xx.tot_cot_compra,0) tot_cot_compra,
       nvl(xx.tot_cot_venta,0) tot_cot_venta
from (
SELECT GV.FECHA,FUL_CLI_OPE_CAMBIOS(CLIENTE.COD_PERSONA,GV.MONTO,GV.COD_MONEDA, GV.FECHA,'N',GV.COD_MAD_PADRE) CLA_OPERACION,
NVL(cliente.nombre,'-') NOMBRE,cliente.cod_persona,cliente.nro_doc,LC_TIP_OPERACIONES.DESCRIPCION TIP_OPERACION,GV.COD_MAD_PADRE,
GV.COD_MONEDA,DECODE(GV.COD_MONEDA, 'USD',GV.COTIZACION,fug_obt_cotizacion('USD')) COTIZACION,
(DECODE(GV.COD_MAD_PADRE, 71,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION), 0)) +
(DECODE(GV.COD_MAD_PADRE, 73,DECODE( GV.NRO_SECUENCIA,1,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION),0),74,DECODE(GV.NRO_SECUENCIA,1,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION),0),0)) MTO_COMPRA,
(DECODE(GV.COD_MAD_PADRE, 72,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION), 0)) +
(DECODE(GV.COD_MAD_PADRE, 73,DECODE( GV.NRO_SECUENCIA,2,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION),0),74,DECODE(GV.NRO_SECUENCIA,2,pal_cam.fu_con_mon_a_moneda(GV.COD_MONEDA,PAG_GEN.FU_OBT_MON_FUERTE,nvl(GV.MONTO,0),GV.COTIZACION),0),0)) MTO_VENTA,
(DECODE( GV.COD_MAD_PADRE,71,DECODE(GV.COD_MONEDA, 'USD', GV.COTIZACION,fug_obt_cotizacion('USD')), 73,DECODE( GV.NRO_SECUENCIA, 1 ,DECODE(GV.COD_MONEDA, 'USD',GV.COTIZACION,pag_gen.fu_obt_cotizacion('USD')),0), 74,DECODE( GV.NRO_SECUENCIA, 1 ,DECODE(GV.COD_MONEDA, 'USD',GV.COTIZACION,pag_gen.fu_obt_cotizacion('USD')),0), 0)) TOT_COT_COMPRA,
(DECODE(GV.COD_MAD_PADRE,71 ,1,73,DECODE(GV.NRO_SECUENCIA,1,1,0),74,DECODE(GV.NRO_SECUENCIA,1,1,0), 0)) IND_COT_COMPRA,
(DECODE(GV.COD_MAD_PADRE,72,DECODE(GV.COD_MONEDA, 'USD', GV.COTIZACION,pag_gen.fu_obt_cotizacion('USD')), 73,DECODE( GV.NRO_SECUENCIA, 2,DECODE(GV.COD_MONEDA, 'USD',GV.COTIZACION,fug_obt_cotizacion('USD')),0), 74,DECODE( GV.NRO_SECUENCIA, 2,DECODE(GV.COD_MONEDA, 'USD',GV.COTIZACION,fug_obt_cotizacion('USD')),0),0)) TOT_COT_VENTA,
(DECODE(GV.COD_MAD_PADRE,72 ,1,73,DECODE(GV.NRO_SECUENCIA,2,1,0),74,DECODE(GV.NRO_SECUENCIA,2,1,0), 0)) IND_COT_VENTA
  FROM BA_MONEDAS,gv_mov_cambios_his GV,LC_TIP_OPERACIONES,
        (select GV.nro_documento,GV.nro_documento2 nro_doc,GV.fecha,GV.hora,GV.cod_usuario,ba_personas.cod_persona,nvl(ba_personas.nom_completo,gv.concepto) nombre
           from ba_personas,lc_movimientos_his GV
          where to_char(GV.nro_documento2) = ba_personas.cod_persona(+)
            and GV.cod_transaccion = 760
            and GV.COD_MOD_PADRE = 7
            and GV.reversado = 'N') cliente
 WHERE BA_MONEDAS.COD_MONEDA = GV.COD_MONEDA
   AND ((GV.COD_MAD_PADRE IN (71,72) AND GV.NRO_SECUENCIA = 1) OR (GV.COD_MAD_PADRE IN (73) AND GV.NRO_SECUENCIA IN (1,2)))
   AND GV.MONTO IS NOT NULL
   AND GV.COTIZACION IS NOT NULL
   AND GV.MTO_EQU_LOCAL IS NOT NULL
   and cliente.fecha(+) = GV.fecha
   and cliente.cod_usuario(+) = GV.cod_usuario
   and cliente.hora(+) = GV.hora
   AND GV.REVERSADO = 'N'
   AND GV.COD_TIP_OPE_CAMBIO = LC_TIP_OPERACIONES.COD_TIP_OPERACION
   AND AFE_POSICION IN ('E','O')
   AND COD_MAD_PADRE <> 74
ORDER BY CLA_OPERACION ,NOMBRE) xx;

