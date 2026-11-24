CREATE OR REPLACE VIEW IT.GV_SAL_ACTIVO AS
WITH CAT_PREVISION as (
  SELECT fecha,cod_persona,max(cat_automatica) cat_automatica FROM ge_cla_operaciones_his
  group by fecha,cod_persona
)

SELECT  distinct
        trunc(c.fecha) AS fecha_proceso,
        d.nro_cuenta AS nro_cuenta,
        s.cod_persona AS cod_persona,
        bf.tipo,
        bf.cod_tip_documento,
        bf.nro_documento,
        pers.nom_completo AS nombre,
        c.cod_modulo AS cod_modulo,
        MC.DESCRIPCION AS des_modulo,
        c.cod_modalidad AS cod_modalidad,
        modal.descripcion AS desmodalidad,
        PR.cod_sub_modalidad AS cod_sub_modalidad,--nuevo
        sm.descripcion as des_sub_modalidad,--nuevo
        c.cod_oficina cod_oficina,
        ofi.descripcion as ba_oficinas,
        c.cod_moneda cod_moneda,
        NVL((SELECT COT.VAL_CONVERSION FROM GE_COTIZACIONES COT WHERE COT.COD_MONEDA =  c.cod_moneda AND COT.FECHA = c.fecha),1) as cotizacion,
        tip_saldo,
        CASE
        WHEN tip_saldo = 'A' THEN 'A DEVENGAR'
        WHEN tip_saldo = 'C' THEN 'CAPITAL'
        WHEN tip_saldo = 'D' THEN 'DEVENGADO'
        WHEN tip_saldo = 'F' THEN 'PREVISIONES ESPECIALES'
        WHEN tip_saldo = 'I' THEN 'INTERES'
        WHEN tip_saldo = 'S' THEN 'INTERES EN SUSPENSO'
        WHEN tip_saldo = 'V' THEN 'PREVISIONES'
        END AS TIPOSALDO,
        c.situacion,
        estcta.descripcion as estado,
        trunc(p.fec_apertura) AS FEC_APERTURA,
        trunc(p.fec_vencimiento)  AS FEC_VENCIMIENTO,
        p.cod_tasa,
        p.val_tasa val_tasa,
        tas.descripciON AS des_tasa,
        c.cod_rubro cod_rubro,
        rub.descripcion as des_rubro,
        sal_actual as sal_actual,
        round(sal_actual*(NVL((SELECT COT.VAL_CONVERSION FROM GE_COTIZACIONES COT WHERE COT.COD_MONEDA =  c.cod_moneda AND COT.FECHA = c.fecha),1))) AS saldo_gs,
        CL.CAT_RIESGO,
        CL.CAT_SUBJETIVA,
        CL.CAT_AUTOMATICA,
        CL.CAT_RENOVACIONES,
        CL.COD_SEG_CLIENTE,
        gsc.DESCRIPCION AS DES_SEG_CLIENTE,
        CL.COD_SEC_CONTABLE,
        SE.DESCRIPCION AS DES_SEC_CONTABLE,
        CL.COD_TIP_DEUDOR,
        DE.DESCRIPCION AS DES_TIP_DEUDOR,
        BF.cod_actividad AS COD_ACTIVIDAD,
        ga.DESCRIPCION AS DES_ACTIVIDAD,
        PR.COD_RUB_ECONOMICO AS COD_RUB_ECONOMICO,
        GU.descripciON AS DES_RUB_ECONOMICO,
        case when PR.COD_RUB_ECONOMICO in ('13000','14000','14001','14002','14003','14004','14005','14008','14009') then 'Agribusiness'
    when PR.COD_RUB_ECONOMICO in ('511000','511001','511002','511003','511004','511005','512100','512101','512102','512103','512104','512105','512106','512200','512201',
    '512202','512203','512204','512205','512206','512207','512208','512209','512210','512211','512212','513100','513101','513102','513103','513104','513105','513900','513901','513902','513903','513904','513905','513906','513907','514100','514200','514201','514300','514301','514302','514303','514304','514305','514306','514307','514308','514900','514901','514902','514903','514904','514905','515000','515001','515002','515003','515004','519000','519001','519002','519003','519004','519005','519006','519007','519008') then 'COMERCIO AL POR MAYOR'
    when PR.COD_RUB_ECONOMICO in ('521100','521101','521102','521103','521900','521901','521902','521903','521904','521905','521906','521907','521908','521909','522000',' 522001','522002','522003','522004','522005','522006','522007','522008','522009','522010','522011','522012','522013','522014','522015','522016','522017','522018','522019','522020','522021','522022','522023','522024','522025','522026','522027','523100','523101','523102','523103','523200','523201','523202','523203','523204','523205','523206','523207','523208','523209','523210','523300','523301','523302','523303','523304','523305','523306','523307','523308','523309','523310','523400','523401','523402','523403','523404','523405','523406','523407','523408','523409','523900','523901','523902','523903','523904','523905','523906','523907','523908','523909','523910','523911','523912','523913','523914','523915','523916','523917','523918','523919','523920','523921','523922','523923','523924','523925','523926','523927','523928','523929','523930','523931','524000','524001','524002','524003','524004','525100','525101','525102','525200','525201','525202','525203','525204','525205','525206','525900','525901','525902','525903','526000','526001','526002','526003','526004','526005',' 526006','526007') then 'COMERCIO AL POR MENOR'
    when PR.COD_RUB_ECONOMICO in ('453000','454001','452004','455001','455000','451005','452000','452005','452008','452002','452001','452006','452009','451001','452007','451002','452003','451000','452010','451004','454000','451003') then 'CONSTRUCCIÓN'
    when PR.COD_RUB_ECONOMICO in ('970100','970101','970102','970103','970104','970105','970106','970107','970108') then 'CONSUMO'
    when PR.COD_RUB_ECONOMICO in ('12100','12101','12102','12103','12104','12105','12200','12201','12202','12203','12204','12205','12206','12207','12299','14006','14007') then 'CRIA DE ANIMALES'
    when PR.COD_RUB_ECONOMICO in ('11100','11101','11102','11103','11104','11105','11106','11107','11108','11109','11110','11111','11200','11201','11202','11203','11204','11300','11301','11302','11303','11304','11305','11399') then 'CULTIVOS AGRÍCOLAS EN GRAL.'
    when PR.COD_RUB_ECONOMICO in ('171200','171201','222100','222200','182002','182000','252007','269202','201002','201000','281301','182004','182005','293001','351101','322001','312001','314002','351100','269600','191100','153102','155101','155100','221902','221901','221903','221102','221302','221101','221100','221202','221200','221201','221204','221203','221300','221301','151400','153300','153104','153200','154200','155103','155300','155402','155400','154102','154300','154301','233000','151303','154903','154902','151302','154400','155203','154900','154101','154401','153100','154100','160000','155201','155202','155200','153103','151300','151200','272002','222201','151304','151301','151102','331101','352000','361001','173002','172101','210902','241200','312000','293000','292700','289902','252004','252005','172100','269101','202901','202900','269501','269500','202903','202902','191202','369300','252002','341001','269104','269105','314001','359200','369905','232005','210202','192000','182006','192001','251102','342000','202203','269401','269504','269400','269302','269103','172103','291300','361002','172300','291200','322000','242303','210200','210201','252003','331300','291500','331100','369904','281102','243001','243000','281103','281300','172301','293002','152004','289300','292500','292400','152005','172201','172202','313000','291400','332000','242400','369100','369400','269201','315000','152003','191200','152006','292600','292100','300000','311000','291101','292200','292300','291100','172901',' 269301','252008','252006','241302','369402','202904','269505','359100','359102','291102','361000','210900','359900','319000','251900','251901','251902','289900','269900','242900','172900','292900','291900','202301','210901','369903','201001','359101','359201','202200','343000','210102','210101','210100','182001','314000','242200','242201','242100','241300','181001','182003','181000','271002','242302','269102','269300','269100','269200','191201','231000','202905','202100','202101','252000','232000','242300','281100','252001','271000','271003','272000','272003','323000','281201','202300','333000','241301','359202','172302','181002','173001','241100','281200','172200','172102','173000','369906','369200','210103','289901','369105','321000','172902','341000','369901','369902','261001','261000','269402','331200','232003','191203','369401','269503','242301','251100','272001','351201','351200','300001','292102','292501','292301','369907','353000','261003','289100','231001','273100','273200','281101','269901','281104','222103','221103','222101','222102','271001','151107','151106','232004','269203','153101','269999','269601','369900','269502','221399','222204','221900','261002','171100','242304','151103','242402','242401','371001','369103','154201','222202','151101','232002','202202','191102','151104','191101','151105','369102','152002','223005','369104','222203','369101','261005','152001','152000','155401','151100','202201','261004','251101','371000','372000','155102','232001','223003','223002','223001','223004','221104','221904','154901','292101','289200') then 'INDUSTRIAS MANUFACTURERAS '
    when PR.COD_RUB_ECONOMICO in ('651100','651900','651901','651902','651903','659100','659101','659200','659201','659202','659203','659900','659901','659902','659903','659904','660100','660101','660200','660201','660202','660203','660300','660301','660302','660303','660304','660305','660306','660399','671100','671101','671102','671103','671200','671201','671202','671900','671901','671902','671903','671904','671905','671906','672000','672001','672002','672003') then 'INTERMEDIACIÓN FINANCIERA'
    when PR.COD_RUB_ECONOMICO in ('809002','701002','922000','853101','911201','852002','900005','923100','853202','911102','853204','924103','924104','752200','921101','803005','851901','900002','911101','20004','924105','911103','851100','923300','751100','851903','852001','752300','851201','851200','919101','923200','851202','990001','911202','911100','919200','911200','919100','911104','924101','919900','924904','921303','851902','753000','921301','921300','900001','20005','900003','924903','900006','751400','751401','112000','912000','921302','930102','900004','924100','702000','701000','930901','853203','924102','930902','924905','853201','921401','921400','852000','851904','970302','751106','751104','751202','751201','751103','751107','751102','702002','713003','713005','711103','711102','713000','713004','712902','712302','711200','711300','711100','711101','701006','712201','712100','712200','712300','713006','713002','712900','713001','712301','712901','701008','751105','701007','851103','410000','15000','15001','851109','851104','851204','851107','851203','970206','701001','702001','970205','970203','970200','970204','970202','970201','970404','970207','970208','410001','402001','921102','809001','900000','701005','970301','809000','801001','809005','801000','801003','801002','802100','802101','802201','802200','803000','803002','803001','809003','970306','970305','809008','809009','809007','809006','921201','921200','701004','20000','101001','142900','20001','131000','132000','142100','120000','111000','141000','141001','142200','101000','102000','103000','402000','930301','924902','970401','970403','970402','751101','401000','50001','950000','851101','803004','803003','924901','851110','851106','851108','930101','930100','970300','990000','921900','924900','930900','851900','809099','851105','970406','970307','930200','50002','50000','930300','970405','803006','20002','15003','921304','921402','921100','402002','403001','809004','751200','751300','752100','15002','50003','851102','970303','970304','851905','950002','950001','20006','930302','751108','853100','853200','752301','403000','970400','701003','20003') then 'OTROS SECTORES ECONOMICOS'
    when PR.COD_RUB_ECONOMICO in ('551000','551001','551002','551003','551004','552000','552001','552002','552003','552004','552005','552006','552007','552008','552009','552010','552011','601000','602100','602101','602102','602103','602104','602105','602106','602107','602108','602200','602201','602202','602203','602204','602300','602301','602302','602303','603000','603001','611000','611001','611002','611003','612000','612001','612002','612003','621000','621001','621002','621003','621004','622000','622001','630100','630101','630102','630200','630201','630300','630301','630302','630303','630400','630401','630402','630403','630900','630901','630902','630903','630904','630905','630906','641100','641101','641102','641200','642000','642001','642002','642003','642004','642005','642006','642007') then 'SERVICIOS'
    when PR.COD_RUB_ECONOMICO in ('723004','749907','724002','742100','741400','742102','749906','749913','749914','749909','749302','749500','749908','741102','749400','749202','749201','749200','749300','749301','749915','724001','723002','723001','749910','749901','749902','749912','723003','741100','731004','731005','731003','731001','731002','724000','722001','749204','741405','741403','741402','741404','749101','721000','722000','743003','743004','732002','741301','742203','742201','742202','742200','732001','724003','749203','742103','741300','732000','732003','731000','725000','725001','749100','729000','749900','749911','749905','741401','723000','743000','741201','749904','721002','721001','741202','741200','743001','743002','749102','749903','741101','742105','742101','742104') then 'Servicios Personales'
    when PR.COD_RUB_ECONOMICO in ('501000','501001','501002','501003','501004','501005','501006','502000','502001','502002','502003','502004','502005','502006','503000','503001','504000','504001','504002','505000','505001','505002') then 'VENTA, MANTENIMIENTO Y REPARACIÓN DE VEHÍCULOS'
    when PR.COD_RUB_ECONOMICO in ('970000','970001','970002','970003') then 'VIVIENDA'
    else 'NO DEFINIDO' end as Actividad_Superior,
        PR.CAN_CUOTAS AS CAN_CUOTAS,
        PR.CAN_CUO_PAGADAS AS CAN_CUO_PAGADAS,
        NVL(PR.DIA_ATRASO,0) AS DIAS_ATRASO,
        TART.afinidad AS AFINIDAD,
        RF.SIGNIFICADO AS DES_AFINIDAD,
        nvl(GEN.DESCRIPCION,(SELECT VAL_PARAMETRO FROM GE_CTA_DAT_ADICIONALES WHERE NRO_CUENTA = d.nro_cuenta AND PARAMETRO = 'PRE_COD_ENT_COM_CARTERA')) AS EMP_CEDENTE,
        CASE
        WHEN PR.TIP_RENOVACION = 'N' THEN
        'RENOVADO'
        WHEN PR.TIP_RENOVACION = 'R' THEN
        'REFINANCIADO'
        WHEN PR.TIP_RENOVACION = 'E' THEN
        'REESTRUCTURADO'
        ELSE 'N/A'
        END AS TIPO_RENOVACION_R
        , TRF.SIGNIFICADO AS TIP_DES_ESPECIFICO,
        cli.tip_cliente_r1,
        cli.TIP_CLIENTE_SISTEMA,
        cli.CAT_SISTEMA,
        cli.cat_automatica AS cat_automatica_R1,
        cli.gru_economico,
        cli.cod_gru_economico
        , bcp.CLA_SISTEMA,
        bcp.TOT_DEU_SISTEMA,
        bcp.TOT_CON_ENTIDAD,
        bcp.TOT_CON_SISTEMA,
        bcp.TOT_COU_ENTIDAD,
        bcp.TOT_COU_SISTEMA,
        bcp.TOT_RIESGO,
        bcp.PERIODO,
        current_timestamp ingested_timestamp--,
        --trunc(pag_cal.fu_obt_fec_actual(6)) AS partition_date*/
      FROM cb_sal_inventarios_his c
      INNER JOIN cb_sal_inventarios_det_his d
          ON d.nro_referencia = c.nro_referencia AND d.fecha = c.fecha
      INNER JOIN ge_cta_clientes s
          ON s.nro_cuenta = d.nro_cuenta AND s.relaciON = 'P'
      INNER JOIN ge_cuentAS p
            ON p.nro_cuenta = s.nro_cuenta
      INNER JOIN ge_clientes cl
          ON s.cod_persona = cl.cod_persona
      LEFT JOIN ba_personas pers
        ON pers.cod_persona=s.cod_persona
      LEFT JOIN ge_modalidades modal
        ON modal.cod_modulo=c.cod_modulo
        and modal.cod_modalidad=c.cod_modalidad
      LEFT JOIN ba_oficinas ofi
        ON ofi.cod_oficina=c.cod_oficina
      LEFT JOIN ge_est_cuentas estcta
       ON estcta.cod_modulo=p.cod_modulo
       and estcta.cod_modalidad=p.cod_modalidad
       and estcta.estado=C.SITUACION
      LEFT JOIN cb_rubros rub
          on rub.cod_rubro=c.cod_rubro
      LEFT JOIN (SELECT sb_cla_operaciones.nro_cuenta,
               NVL(refe.significado, 'Referencia  no registrada en el Sistema') AS CAT_SISTEMA,
               gu2.COD_GRU_ECONOMICO,
               NVL(refe2.significado, 'Referencia  no registrada en el Sistema') AS tip_cliente_r1,
               NVL(refe3.significado, 'Referencia  no registrada en el Sistema') AS TIP_CLIENTE_SISTEMA,
                sb_cla_operaciones.cat_automatica,
                gu2.descripciON gru_economico,
                count(sb_clientes.cod_persona),
                sb_cla_operaciones.fecha
          FROM GE_CLIENTES_HIS sb_clientes
          JOIN ge_cla_operaciones_his sb_cla_operaciones
               ON sb_clientes.cod_persona = sb_cla_operaciones.cod_persona AND sb_clientes.fecha = sb_cla_operaciones.fecha
          LEFT JOIN ge_gru_economicos gu2
               ON sb_clientes.cod_gru_economico = gu2.cod_gru_economico
          LEFT JOIN CAT_PREVISION cat
          on sb_clientes.cod_persona=cat.cod_persona
          and  sb_cla_operaciones.fecha = cat.fecha
          LEFT JOIN ba_cod_referencias REFE
          on refe.val_minimo=replace(CASE WHEN NVL(sb_clientes.cod_gru_economico,-1)=1 THEN
                                            NVL(sb_clientes.cat_gru_economico,to_number(sb_clientes.cat_riesgo))
                                           WHEN NVL(sb_clientes.cod_gru_economico,-1)= -1 THEN
                                              CASE WHEN NVL(sb_clientes.cat_riesgo,to_char(sb_clientes.cat_automatica))= 1 THEN
                                                CASE WHEN cat.cat_automatica > 1.1 THEN 1.2
                                                  ELSE cat.cat_automatica END
                                               ELSE TO_NUMBER(( NVL(sb_clientes.cat_riesgo, to_char(sb_clientes.cat_automatica)))) END
                                            ELSE
                                              COALESCE(sb_clientes.cat_gru_economico, to_number(sb_clientes.cat_riesgo)) END,',', '.')
          and dominio='CAT_RIE_BCP'
          LEFT JOIN ba_cod_referencias REFE2
          on refe2.val_minimo=CASE
                                WHEN sb_cla_operaciones.cod_sec_credito IN ('702', '703') THEN 'V'
                                ELSE
                                  CASE WHEN sb_clientes.tipo = 'T' AND sb_cla_operaciones.tip_destino ='4' THEN 'P'
                                    ELSE sb_clientes.tipo
                                  END
                              END
          AND refe2.dominio='TIP_CLIENTE'
           LEFT JOIN ba_cod_referencias REFE3
          on refe3.val_minimo=sb_clientes.tipo
          AND refe3.dominio='TIP_CLIENTE'
          GROUP BY  sb_cla_operaciones.fecha,sb_cla_operaciones.nro_cuenta,refe2.significado,
       refe3.significado, sb_cla_operaciones.cat_automatica, gu2.descripcion,
       refe.significado,gu2.COD_GRU_ECONOMICO
           ) cli
       ON s.nro_cuenta = cli.nro_cuenta
       and cli.fecha=c.fecha

      LEFT JOIN GE_TASAS TAS
          ON TAS.COD_TASA = P.COD_TASA

      LEFT JOIN ge_sec_contables se
          ON se.cod_sec_contable = cl.cod_sec_contable

      LEFT JOIN ge_tip_deudores de
          ON de.cod_tip_deudOR = cl.cod_tip_deudor
              AND se.cod_sec_contable = de.cod_sec_contable

      LEFT JOIN GE_SEG_CLIENTES gsc
          ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE

      LEFT JOIN PR_CTA_PRESTAMOS PR --PR_CTA_PRESTAMOS_HIS
          ON PR.NRO_CUENTA = s.nro_cuenta
              --AND PR.FECHA = C.FECHA

      LEFT JOIN ge_sub_modalidades sm
        ON sm.cod_modulo=PR.cod_modulo
        and sm.cod_modalidad=PR.cod_modalidad
        and sm.cod_sub_modalidad=PR.cod_sub_modalidad

      LEFT JOIN GE_CTA_DAT_ADICIONALES CAD
          ON CAD.NRO_CUENTA = s.NRO_CUENTA
              AND PARAMETRO = 'PRE_COD_ENT_COM_CARTERA'

      LEFT JOIN GE_ENTES GEN
          ON TO_NCHAR(GEN.COD_ENTE) = CAD.VAL_PARAMETRO


      LEFT JOIN PR_CTA_DESTINOS TDE
          ON TDE.NRO_CUENTA = S.NRO_CUENTA

      LEFT JOIN BA_COD_REFERENCIAS TRF
          ON TRF.VAL_MINIMO = TDE.TIP_DES_ESPECIFICO
              AND TRF.DOMINIO = 'TIP_DES_ESPECIFICO'


      LEFT JOIN GE_RUB_ECONOMICOS GU
          ON GU.COD_RUB_ECONOMICO = PR.COD_RUB_ECONOMICO

      LEFT JOIN BA_PERSONAS BF
          ON BF.COD_PERSONA = S.COD_PERSONA


      LEFT JOIN (SELECT gbch.CLA_SISTEMA,
              gbch.TOT_DEU_SISTEMA,
              gbch.TOT_CON_ENTIDAD,
              gbch.TOT_CON_SISTEMA,
              gbch.TOT_COU_ENTIDAD,
              gbch.TOT_COU_SISTEMA,

       gbch.TOT_RIESGO,
              gbch.PERIODO,
              gbch.NRO_DOCUMENTO

          FROM ge_bcp_clasificacion_his gbch

          WHERE gbch.fec_proceso = (SELECT max(fec_proceso)
          FROM ge_bcp_clasificacion_his)) bcp
          ON bcp.NRO_DOCUMENTO = BF.nro_documento


      LEFT JOIN GE_ACTIVIDADES ga
          ON ga.COD_ACTIVIDAD = BF.cod_actividad

      LEFT JOIN BA_MODULOS MC
          ON MC.COD_MODULO = c.COD_MODULO

      LEFT JOIN TA_CTA_TARJETAS TART
          ON TART.NRO_CUENTA = S.NRO_CUENTA

      LEFT JOIN BA_COD_REFERENCIAS RF
          ON RF.VAL_MINIMO = tart.afinidad
              AND RF.DOMINIO = 'AFINIDAD'
      WHERE  (c.cod_modulo IN ('5','6','15') or (c.cod_modulo IN ('4') and sal_actual < 0))
      
      AND c.fecha = (pag_cal.fu_obt_fec_actual(6))
;
