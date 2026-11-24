create or replace procedure it.prq_rev_est_caja is

CURSOR C_CONTRATOS IS
SELECT *
  FROM CS_AUDITORIAS A
 WHERE A.TABLA= 'CS_CONTRATOS'
   AND ORIGEN ='GPPROFIN'
   AND FEC_CALENDARIO >= '14/09/2009'
   AND A.CLAVE IN (SELECT NRO_CONTRATO
                     FROM CS_CONTRATOS C
                    WHERE C.COD_CAJ_SEGURIDAD IN ('1012'  ,'1020'  ,'1037'  ,'1050'  ,'1058'  ,'1079'  ,'1113'  ,'1140'  ,'1141'  ,'1148'  ,
                                                  '2003'  ,'2004'  ,'2006'  ,'2008'  ,'2012'  ,'2015'  ,'2017'  ,'2018'  ,'2021'  ,'2024'  ,
                                                  '2045'  ,'2046'  ,'2048'  ,'2054'  ,'2056'  ,'2090'  ,'2111'  ,'2120'  ,'2123'  ,'2156'  ,
                                                  '2252'  ,'2285'  ,'2286'  ,'2311'  ,'2321'  ,'2326'  ,'2328'  ,'2332'  ,'2338'  ,'2341'  ,
                                                  '2388'  ,'2410'  ,'2411'  ,'2415'  ,'2416'  ,'3052'  ,'3108'  ,'3158'  ,'3170'  ,'3179'  ,
                                                  '3180'  ,'3181'  ,'3187'  ,'3189'  ,'3199'  ,'3306'  ,'3311'  ,'3350'  ,'3353'  ,'3355'  ,
                                                  '3358'  ,'3359'  ,'3360'  ,'3362'  ,'3367'  ,'3371'  ,'3373'  ,'3375'  ,'3383'  ,'3384'  ,
                                                  '3386'  ,'3393'  ,'3395'  ,'3396'  ,'3398'  ,'3400'  ,'3700'  ,'3701'  ,'3708'  ,'3712'  ,
                                                  '3713'  ,'3714'  ,'3719'  ,'3733'  ,'3737'  ,'3738'  ,'3739'  ,'3742'  ,'3749'  ,'2197'  ,
                                                  '2413'  ,'3703'  ,'2101'  ,'2296'  ,'2295'  ,'2422'  ,'2424'  ,'2009'  ,'3444'  ,'1131'  ,
                                                  '2149'  ,'2160'  ,'2406'  ,'2292'  ))
AND DETALLE LIKE '~ESTADO:<i:A:f><i:C:f>~FEC_CANCELACION:<i::f><i:%'
ORDER BY A.FEC_CALENDARIO;

CURSOR C_CAJAS IS
SELECT *
  FROM CS_AUDITORIAS B
 WHERE B.TABLA = 'CS_CAJ_SEGURIDAD'
   and b.fec_calendario >= '14/09/2009'
   AND CLAVE IN(SELECT COD_CAJ_SEGURIDAD||'#'||COD_OFICINA
                  FROM CS_CAJ_SEGURIDAD C
                 WHERE C.COD_CAJ_SEGURIDAD  IN   ('1012'  ,'1020'  ,'1037'  ,'1050'  ,'1058'  ,'1079'  ,'1113'  ,'1140'  ,'1141'  ,'1148'  ,
                                                  '2003'  ,'2004'  ,'2006'  ,'2008'  ,'2012'  ,'2015'  ,'2017'  ,'2018'  ,'2021'  ,'2024'  ,
                                                  '2045'  ,'2046'  ,'2048'  ,'2054'  ,'2056'  ,'2090'  ,'2111'  ,'2120'  ,'2123'  ,'2156'  ,
                                                  '2252'  ,'2285'  ,'2286'  ,'2311'  ,'2321'  ,'2326'  ,'2328'  ,'2332'  ,'2338'  ,'2341'  ,
                                                  '2388'  ,'2410'  ,'2411'  ,'2415'  ,'2416'  ,'3052'  ,'3108'  ,'3158'  ,'3170'  ,'3179'  ,
                                                  '3180'  ,'3181'  ,'3187'  ,'3189'  ,'3199'  ,'3306'  ,'3311'  ,'3350'  ,'3353'  ,'3355'  ,
                                                  '3358'  ,'3359'  ,'3360'  ,'3362'  ,'3367'  ,'3371'  ,'3373'  ,'3375'  ,'3383'  ,'3384'  ,
                                                  '3386'  ,'3393'  ,'3395'  ,'3396'  ,'3398'  ,'3400'  ,'3700'  ,'3701'  ,'3708'  ,'3712'  ,
                                                  '3713'  ,'3714'  ,'3719'  ,'3733'  ,'3737'  ,'3738'  ,'3739'  ,'3742'  ,'3749'  ,'2197'  ,
                                                  '2413'  ,'3703'  ,'2101'  ,'2296'  ,'2295'  ,'2422'  ,'2424'  ,'2009'  ,'3444'  ,'1131'  ,
                                                  '2149'  ,'2160'  ,'2406'  ,'2292'  ));

BEGIN
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
 FOR REG IN C_CONTRATOS LOOP
     prg_rev_auditoria('CS_CONTRATOS',REG.FEC_SISTEMA,REG.USUARIO,REG.CLAVE);
 END LOOP;
  FOR REG IN C_CAJAS LOOP
     prg_rev_auditoria('CS_CAJ_SEGURIDAD',REG.FEC_SISTEMA,REG.USUARIO,REG.CLAVE);
 END LOOP;

exception
  when others then
    raise_application_error(-20000,'Al reversar estados de Caj.Seg'||' - '||sqlerrm);
end;
/

