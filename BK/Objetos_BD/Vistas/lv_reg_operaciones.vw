create or replace force view it.lv_reg_operaciones as
select DECODE(COD_MAD_PADRE,71,1,72,2) cod_mad_padre,
       to_char(G.fecha,'dd/mm/yyyy') fecha,
       GE.COD_ENTIDAD,
       decode(O.COD_OFICINA,4,1,6,2,7,2,8,2,9,2,15,1,16,1,17,6,3) cod_oficina,
       SUBSTR(FUL_OBT_COD_CLI_ENTIDAD(G.COD_MAD_PADRE,G.COD_TIP_OPE_CAMBIO,CLI.COD_PERSONA),1, (INSTR(FUL_OBT_COD_CLI_ENTIDAD(G.COD_MAD_PADRE,G.COD_TIP_OPE_CAMBIO,CLI.COD_PERSONA),'~')-1) ) cod_cli,
       SUBSTR(FUL_OBT_COD_CLI_ENTIDAD(G.COD_MAD_PADRE,G.COD_TIP_OPE_CAMBIO,CLI.COD_PERSONA),(INSTR(FUL_OBT_COD_CLI_ENTIDAD(G.COD_MAD_PADRE,G.COD_TIP_OPE_CAMBIO,CLI.COD_PERSONA),'~')+1) ) cod_ent,
       M.COD_NUMERICO,
       SUM(G.MONTO) ME,
			 SUM(NVL(G.MTO_EQU_LOCAL, 0))/SUM(G.MONTO) PRO_COT_ME,
			 decode(g.cod_moneda,pag_gen.fu_obt_mon_fuerte,(SUM(NVL(G.MTO_EQU_LOCAL, 0))/SUM(G.MONTO)),PAG_GEN.FU_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte, G.FECHA)) COT_USD,
       SUM(NVL(G.MTO_EQU_LOCAL, 0)) MTO_GS,
			 decode(g.cod_moneda,pag_gen.fu_obt_mon_fuerte,SUM(G.MONTO) ,(SUM(NVL(G.MTO_EQU_LOCAL, 0))/decode(g.cod_moneda,pag_gen.fu_obt_mon_fuerte,AVG(G.COTIZACION),PAG_GEN.FU_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte, G.FECHA)))) mto_usd
  FROM GE_MOVIMIENTOS G,
       LC_TIP_OPERACIONES L,
       BA_MONEDAS M,
       GE_PAR_GENERALES GE,
       BA_OFICINAS O,
       (select fecha, hora, cod_usuario,nro_documento, nro_documento2 cod_persona, concepto
          from GE_MOVIMIENTOS G
          where cod_transaccion = 760 ) CLI
 WHERE COD_MOD_PADRE = 7
   AND COD_MAD_PADRE IN (71, 72)
   AND REVERSADO = 'N'
   AND NRO_SECUENCIA = 1
   AND L.AFE_POSICION IN ('E', 'O') -- afecta efectivo u otross
   AND G.ESTADO IN ('N')
   AND COD_TIP_OPE_CAMBIO = COD_TIP_OPERACION
   AND M.COD_MONEDA = G.COD_MONEDA
   AND G.COD_OFI_ORIGEN = O.COD_OFICINA
   and CLI.fecha(+) = G.fecha
   and CLI.hora(+)  = G.hora
   and CLI.cod_usuario(+)   = G.cod_usuario
   and CLI.nro_documento(+) = G.nro_documento
 GROUP BY DECODE(COD_MAD_PADRE,71,1,72,2),
       G.fecha,
       GE.COD_ENTIDAD,
       FUL_OBT_COD_CLI_ENTIDAD(G.COD_MAD_PADRE,
                               G.COD_TIP_OPE_CAMBIO,
                               CLI.COD_PERSONA),
			 decode(O.COD_OFICINA,4,1,6,2,7,2,8,2,9,2,15,1,16,1,17,6,3),
       M.COD_NUMERICO,
       G.COD_MONEDA
ORDER BY decode(O.COD_OFICINA,4,1,6,2,7,2,8,2,9,2,15,1,16,1,17,6,3),G.COD_MONEDA
;

