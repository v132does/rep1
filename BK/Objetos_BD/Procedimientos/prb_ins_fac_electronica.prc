CREATE OR REPLACE PROCEDURE IT.PRB_INS_FAC_ELECTRONICA(p_fec_desde date DEFAULT NULL,
                                                      p_fec_hasta date DEFAULT NULL) IS

v_nro_id cb_doc_elec_cab.id_documento%TYPE;
v_nro_item cb_doc_elec_det.nro_item%TYPE;

V_cdc         varchar2(60);
v_timbrado    number(12);
v_nro_factura cb_lib_ventas.nro_factura%TYPE;
v_can_fac     number(15);
v_max_fac     number(15);
v_estado      cb_lib_ventas.estado%TYPE;
v_fac_ok      varchar2(1); 
v_itiope      varchar2(1) := fug_obt_pardinamico('FAC_TIP_OPERACION');
v_dModCont    varchar2(2) := fug_obt_pardinamico('FAC_COD_MAD_DNCP');
v_dEntCont    varchar2(5) := fug_obt_pardinamico('FAC_COD_ENT_DNCP');
v_dSecCont    varchar2(7) := fug_obt_pardinamico('FAC_COD_SEC_DNCP');
v_ddncpg      varchar2(8) := fug_obt_pardinamico('FAC_COD_GEN_DNCP');
v_ddncpe      varchar2(4) := fug_obt_pardinamico('FAC_COD_ESP_DNCP');
v_ruc_fusionado cb_doc_asociado.dRucFus%TYPE := substr(fug_obt_pardinamico('RUC_VISION'), 1, 8);

cursor c_cabecera is
 select r.dinfoemi,
        r.dInfoFisc,
        r.itide,
        r.dDesTiDE,
        r.dNumTim,
        r.dEst,
        r.dPunExp,
        r.dNumDoc,
        r.nro_factura,
        r.tip_comprobante,
        r.dSerieNum,
        r.dFeIniT,
        r.dFeEmiDE,
        r.iTipTra,
        fug_obt_pardinamico(
                p_parametro =>'TIP_TRANSACCION_FAC_ELE',
                p_cod_sub_modalidad => r.iTipTra
        ) dDesTipTra, --Eze
        r.iTImp,
        r.dDesTImp,
        r.cMoneOpe,
        decode(r.cMoneOpe, 'PYG', 'Guarani', 'USD', 'US Dollar',
                           'RS', 'Brazilian Real','EUR','Euro',
                           'ARS', 'Argentine Peso') as dDesMoneOpe,
        decode(r.cMoneOpe, 'PYG', null, 1) as dCondTiCam,
        decode(r.cMoneOpe, 'PYG', null, round(r.cotizacion,2)) as dTiCam,
        r.iCondAnt,
        r.dDesCondAnt,
        r.cOblAfe, --GMPEREIRA TN-890
        r.dDesoblAfe, --GMPEREIRA TN-890									 					
        r.iNatRec,
        r.iTiOpe,
        r.cPaisRec,
        r.dDesPaisRe,
        r.iTiContRec,
        r.dRucRec,
        r.dDVRec,
        r.iTipIDRec,
        r.dDTipIDRec,
        r.dNumIDRec,
        r.dNomRec,
        r.dNomFanRec,
        r.dDirRec,
        r.dNumCasRec,
        r.cDepRec,
        r.dDesDepRec,
        r.cDisRec,
        r.dDesDisRec,
        r.cCiuRec,
        r.dDesCiuRec,
        r.dTelRec,
        r.dCelRec,
        r.dEmailRec,
        r.dCodCliente,
        r.iIndPres,
        r.dDesIndPres,
        r.dFecEmNR,
        r.dModCont,
        r.dEntCont,
        r.dAnoCont,
        r.dSecCont,
        r.dFeCodCont,
        r.iMotEmi,
        r.dDesMotEmi,
        r.dkmr,
        r.dfecem,
        r.iCondOpe,
        r.dDCondOpe,
        r.iCondCred,
        r.dDCondCred,
        r.dPlazoCre,
        r.dCuotas,
        r.dMonEnt,
        r.dCiclo,
        r.dFecIniC,
        r.dFecFinC,
        r.dVencPag,
        r.dContrato,
        r.dSalAnt,
        decode(r.cMoneOpe, 'PYG', r.exento_gs, r.exento_uss) as dSubExe,
        r.dSubExo,
        decode(r.cMoneOpe,
               'PYG',
               (r.imp_gs_5 + r.grav_gs_5),
               (r.imp_uss_5 + r.grav_uss_5)) as dSub5,
        decode(r.cMoneOpe,
               'PYG',
               (r.imp_gs_10 + r.grav_gs_10),
               (r.grav_uss_10 + r.imp_uss_10)) as dSub10,
        decode(r.cMoneOpe,
               'PYG',
               (r.exento_gs + r.imp_gs_5 + r.grav_gs_5 + r.imp_gs_10 +
               r.grav_gs_10),
               (r.exento_uss + r.imp_uss_5 + r.grav_uss_5 + r.grav_uss_10 +
               r.imp_uss_10)) as dTotOpe,
        r.dTotDesc,
        r.dtotdescglotem,
        r.dTotAntItem,
        r.dTotAnt,
        r.dPorcDescTotal,
        r.dDescTotal,
        r.dAnticipo,
        r.dRedon,
        r.dComi,
        decode(r.cMoneOpe,
               'PYG',
               (r.exento_gs + r.imp_gs_5 + r.grav_gs_5 + r.imp_gs_10 +
               r.grav_gs_10),
               (r.exento_uss + r.imp_uss_5 + r.grav_uss_5 + r.grav_uss_10 +
               r.imp_uss_10)) as dTotGralOpe,
        decode(r.cMoneOpe,
               'PYG',
               (r.imp_gs_5 ),
               (r.imp_uss_5 )) dIVA5,
        decode(r.cMoneOpe,
               'PYG',
               (r.imp_gs_10),
               (r.grav_uss_10 )) dIVA10,
        r.dLiqTotIVA5,
        r.dLiqTotIVA10,
        r.dIVAComi,
        decode(r.cMoneOpe,
               'PYG',
               (r.imp_gs_5 + r.imp_gs_10),
               (r.imp_uss_5 + r.imp_uss_10)) as dTotIVA,
        decode(r.cMoneOpe, 'PYG', (r.grav_gs_5), (r.grav_uss_5)) as dBaseGrav5,
        decode(r.cMoneOpe, 'PYG', (r.grav_gs_10), (r.grav_uss_10)) as dBaseGrav10,
        decode(r.cMoneOpe,
               'PYG',
               (r.grav_gs_5 + r.grav_gs_10),
               (r.grav_uss_5 + r.grav_uss_10)) as dTBasGraIVA,
        round(decode(r.cMoneOpe,
                     'PYG',
                     null,
                     (round(r.cotizacion,2) *
                     (r.exento_uss + r.imp_uss_5 + r.grav_uss_5 +
                     r.grav_uss_10 + r.imp_uss_10))),2) as dTotalGs,
        r.dCarQR,
        r.dInfAdic,
        r.sec_contable
 from
  (select
     '' as dinfoemi,
     '' as dInfoFisc,
     decode(v.tip_comprobante, 'F', '1', 'N','5') as itide,
     decode(v.tip_comprobante, 'F', 'Factura electrónica',
                               'N', 'Nota de crédito electrónica') as dDesTiDE,
     v.nro_timbrado  as dNumTim,
     substr(v.nro_factura,1,3) as dEst,
     substr(v.nro_factura,5,3) as dPunExp,
     substr(v.nro_factura,9) as dNumDoc,
     v.nro_factura as nro_factura,
     v.tip_comprobante as tip_comprobante,
     CASE 
          WHEN v.tip_comprobante = 'F' THEN v.serie
          WHEN v.tip_comprobante = 'N' THEN 
              CASE 
                  WHEN substr(v.nro_factura,5,3) = '001' THEN NULL 
                  ELSE v.serie 
              END
          ELSE v.serie
      END AS dSerieNum,
     (trunc(c.fec_ini_timbrado)) as dFeIniT, --comente xq la base de datos guada como dd/mm/yyyy--to_date(to_char(trunc(c.fec_insercion), 'YYYY-MM-DD'),'YYYY-MM-DD') as dFeIniT/*, --como Itgf no guarda fecha de inicio de vigencia del timbrado por sugerencia de Dick Ruiz uso la fecha de insercion.
     v.fecha as dFeEmiDE,
     fub_obt_tip_tra_factura(v.nro_factura, v.fecha, v.nro_timbrado, v.tip_comprobante) iTipTra,
     5 as iTImp, --por sugerencia de Dick Ruiz. Asi como entendimos poniendo la vista como emisor, las transcciones que emite ueno o similares.
     'IVA - Renta' as dDesTImp,
      IT.FUG_OBT_COD_ISO(nvl((select distinct(c.cod_moneda)
                                from cb_lib_ventas_det c
                               where c.nro_factura = v.nro_factura
                                 and c.nro_timbrado = v.nro_timbrado
                                 and c.tip_comprobante = v.tip_comprobante
                                 and c.fecha = v.fecha 
                                 and c.cod_mod_padre = 7),v.cod_moneda)) as cMoneOpe,
     nvl((select distinct(c.cotizacion)
            from cb_lib_ventas_det c
           where c.nro_factura = v.nro_factura
             and c.nro_timbrado = v.nro_timbrado
             and c.tip_comprobante = v.tip_comprobante
             and c.fecha = v.fecha 
             and c.cod_mod_padre = 7
             and rownum = 1),null) cotizacion,
     '' as iCondAnt,
     '' as dDesCondAnt,
     211 as cOblAfe, --GMPEREIRA TN-890
     'IMPUESTO AL VALOR AGREGADO - GRAVADAS Y EXONERADAS - EXPORTADORES' as dDesoblAfe,--GMPEREIRA TN-890									   
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'CO','1','2') as iNatRec,
     2 as iTiOpe,
     'PRY' as cPaisRec,
     'Paraguay' as dDesPaisRe,
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'CO',decode(p.tipo,'F',1,'J',2),'') as iTiContRec,
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'CO',v.nro_documento,'') as dRucRec,
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'CO', fub_val_dig_verificador(v.nro_documento, v.dig_verificador, v.cod_persona),'') as dDVRec,
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'NC',decode(p.cod_tip_documento,'1',1,'2',2,'8',3,'3',4,'7',5),'') as iTipIDRec, --30
     decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'NC',decode(p.cod_tip_documento,'1','Cédula paraguaya',
                                                                                            '2','Pasaporte',
                                                                                            '8','Cédula extranjera',
                                                                                            '3','Carnet de residencia',
                                                                                            '7','Innominado',
                                                                                            ''),'') as dDTipIDRec,
     case when decode(nvl(p.tip_iva,decode(p.tipo,'F','NC','J','CO')),'CO','1','2') = 2 --no contribuyente
               then v.nro_documento
                else '' --si es contribuyente no se completa.
     end as dNumIDRec,
     p.nom_completo as dNomRec,
     '' as dNomFanRec,
     replace(replace(replace(replace(replace(v.direccion,chr(10),' '),chr(12),' '),chr(13),' '),chr(9),' '),chr(160),' ')
        as dDirRec,
     nvl(IT.FUG_OBT_NRO_VIVIENDA((select nvl(numero,0)
                                    from ba_direcciones
                                   where cod_persona = p.cod_persona
                                     and principal = 'S')),0) as dNumCasRec,
     1 as cDepRec,
     'CAPITAL' as dDesDepRec,
     1 as cDisRec,
     'ASUNCION (DISTRITO)' as dDesDisRec, --40
     1 as cCiuRec,
     'ASUNCION (DISTRITO)' as dDesCiuRec,
     decode(t.tip_linea,'C','',decode(t.area,null,case when length(t.telefono) < 6 then
                                                             lpad(t.telefono,6,0)
                                                           else t.telefono end,
                                                   t.area||t.telefono)) as dTelRec,

    decode(t.tip_linea,'C',decode(t.area,null,case when length(t.telefono) < 10 then
                                                           lpad(t.telefono,10,0)
                                                         else t.telefono end,
                                              case when length(t.area) < 4 then
                                                lpad(t.area,4,0)||t.telefono
                                                else t.area||t.telefono end),'') as dCelRec,
     fub_val_mail(p.DIR_CORREO,
                    p.COD_PERSONA,
                    v.nro_factura) as dEmailRec,
     decode(length(p.COD_PERSONA), 1, rpad(p.COD_PERSONA,3,0),
                                   2, rpad(p.COD_PERSONA,3,0),
                                    p.COD_PERSONA) as dCodCliente,
     5  as iIndPres,
     'Operación bancaria' as dDesIndPres,
     '' as dFecEmNR,
     '' as dModCont, --50
     '' as dEntCont,
     '' as dAnoCont,
     '' as dSecCont,
     '' as dFeCodCont,
     decode(v.tip_comprobante,'N',1,'') as iMotEmi,
     decode(v.tip_comprobante,'N','Devolución y Ajuste de precios','') as dDesMotEmi,
     '' as dkmr,
     '' as dfecem,
     decode(v.tip_comprobante,'F',decode(v.tip_venta,'CO','1','CR','2'),'') as iCondOpe,
     decode(v.tip_comprobante,'F',decode(v.tip_venta,'CO','Contado','CR','Crédito'),'') as dDCondOpe, --60
     decode(v.tip_comprobante,'F',decode(v.tip_venta,'CR', 2),'') as iCondCred,
     decode(v.tip_comprobante,'F',decode(v.tip_venta,'CR', 'Cuota'),'') as dDCondCred,
     '' as dPlazoCre,
     decode(v.tip_comprobante,'F',decode(v.tip_venta,'CR', v.can_cuota),'') as dCuotas,
     '' as dMonEnt,
     '' as dCiclo,
     '' as dFecIniC,
     '' as dFecFinC,
     '' as dVencPag,
     '' as dContrato, --70
     '' as dSalAnt,
     nvl(v.mto_exento_gs,0)exento_gs,
      nvl(v.impuesto_5_gs,0)imp_gs_5,
     nvl(v.mto_gravado_5_gs,0)grav_gs_5,
     nvl(v.impuesto_10_gs,0)imp_gs_10,
     nvl(v.mto_gravado_10_gs,0)grav_gs_10,
     nvl(v.mto_exento,0)exento_uss,
     nvl(v.impuesto_5,0)imp_uss_5,
     nvl(v.mto_gravado_5,0)grav_uss_5,
     nvl(v.mto_gravado_10,0)grav_uss_10,
     nvl(v.impuesto_10,0)imp_uss_10,
     '' as dSubExo,
     0 as dTotDesc,
     0 as dtotdescglotem,
     0 as dTotAntItem,
     0 as dTotAnt, --80
     0 as dPorcDescTotal,
     0 as dDescTotal,
     0 as dAnticipo,
     0 as dRedon,
     0 as dComi,
     '' as dLiqTotIVA5,
     '' as dLiqTotIVA10,
     '' as dIVAComi,
     '' as dCarQR,
     'Si su documento electrónico presenta algún error puede solicitar la modificación dentro de las 72 horas siguientes de la emisión de este comprobante.' as dInfAdic,
     case when nvl(gc.cod_sec_contable, 'X') in ('P', 'I') then 'PUBLICO' else 'PRIVADO' end sec_contable
   from cb_lib_ventas v,
        cb_par_comprobantes c,
        ba_personas p,
        ba_telefonos t,
        ge_clientes gc
   where v.fecha >= p_fec_desde
     and v.fecha <= p_fec_hasta
     and c.nro_timbrado = v.nro_timbrado
     and c.cod_oficina = v.cod_oficina
     and c.tipo = v.tip_comprobante
     and v.cod_persona = p.cod_persona
     and nvl(v.nro_fac_referencia,-1) <> '0'
     and p.cod_persona = t.cod_persona(+)
     and p.cod_persona = gc.cod_persona(+)
     and t.principal(+) = 'S'
     and exists (select 1
                   from cb_lib_ventas_det a
                  where v.nro_factura = a.nro_factura
                    and v.fecha = a.fecha
                    and v.nro_timbrado = a.nro_timbrado
                    and v.tip_comprobante = a.tip_comprobante)
     and v.estado is null
     and v.serie is not null)r;


cursor c_detalle (p_nro_factura IN VARCHAR2,
                  p_fecha       IN DATE,
                  p_tip_comprobante IN VARCHAR2) is
  select a.cod_tra_padre as dcodint,         --Código interno
         a.descripcion as ddesproser,      --Descripción del producto y/o servicio
         77 as cunimed,         --Unidad de medida
         'UNI' as ddesunimed,      --Descripción de la unidad de medida
	         decode(a.cod_mod_padre,7,nvl(a.mto_exento,0) + nvl(a.mto_gravado_5,0) +
                                  nvl(a.mto_gravado_10,0)+nvl(a.impuesto_5,0)+
                                nvl(a.impuesto_10,0),
                                  1) as dcantproser,     --Cantidad del producto y/o servicio
         'PRY' as cpaisorig,    --Código del país de origen del producto
         'Paraguay' as ddespaisorig,       --Descripción del país de origen del producto
         '' as dinfitem,        --Información de interés del emisor con respecto al ítem
         '' as crelmerc,        --10 Código de datos de relevancia de las mercaderías
         '' as ddesrelmerc,     --Descripción del código de datos de relevancia de las mercaderías
         '' as dcanquimer,      --Cantidad de quiebra o merma
         '' as dporquimer,      --Porcentaje de quiebra o merma
         '' as dcdcanticipo,    --CDC del anticipo
         '' as dpararanc,       --Partida arancelaria
         '' as dncm,            --Nomenclatura común del Mercosur (NCM)
         '' as ddncpg,          --Código DNCP – Nivel General
         '' as ddncpe,          --Código DNCP – Nivel Especifico
         '' as dgtin,           --Código GTIN por producto
         '' as dgtinpq,         --20 Código GTIN por paquete
         decode(a.cod_mod_padre, 7 , 1,
                                    decode(v.cod_moneda, 'GS', nvl(a.mto_exento_gs,0) + nvl(a.mto_gra_5_gs,0) +
                                                               nvl(a.mto_gra_10_gs,0) + nvl(a.impuesto_5_gs,0) + nvl(a.impuesto_10_gs,0),
                                                               nvl(a.mto_exento,0) + nvl(a.mto_gravado_5,0) + nvl(a.mto_gravado_10,0) +
                                                               nvl(a.impuesto_5,0) + nvl(a.impuesto_10,0)))dpuniproser, --Precio unitario del producto y/o servicio (incluidos impuestos)
        /* decode(a.cod_moneda,'GS',null,a.cotizacion) as dticamit,*/        --Tipo de cambio por ítem
         '' as dticamit,
         (decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS', nvl(a.mto_exento_gs,0) + nvl(a.mto_gra_5_gs,0) +
                                                                            nvl(a.mto_gra_10_gs,0) + nvl(a.impuesto_5_gs,0) + nvl(a.impuesto_10_gs,0),
                                                                            nvl(a.mto_exento,0) + nvl(a.mto_gravado_5,0) + nvl(a.mto_gravado_10,0) +
                                                                            nvl(a.impuesto_5,0) + nvl(a.impuesto_10,0))* 1/* se multiplica por dcantproser que siempre es 1*/) as dtotbruopeitem,  --Total bruto de la operación por ítem
         0 as ddescitem,       --Descuento particular sobre el precio unitario por ítem (incluidos impuestos)
         0 as dporcdesit,      --Porcentaje de descuento particular por ítem
         0 as ddescgloitem,    --Descuento global sobre el precio unitario por ítem (incluidos impuestos)
         0 as dantpreuniit,    --Anticipo particular sobre el precio unitario por ítem (incluidos impuestos)
         0 as dantglopreuniit, --Anticipo global sobre el precio unitario por ítem (incluidos impuestos)
		     decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS', nvl(a.mto_exento_gs,0) + nvl(a.mto_gra_5_gs,0) +
                                                                               nvl(a.mto_gra_10_gs,0) + nvl(a.impuesto_5_gs,0) + nvl(a.impuesto_10_gs,0),
                                                                               nvl(a.mto_exento,0) + nvl(a.mto_gravado_5,0) + nvl(a.mto_gravado_10,0) +
                                                                               nvl(a.impuesto_5,0) + nvl(a.impuesto_10,0)) as dtotopeitem,     --Valor total de la operación por ítem
         '' as dtotopegs,       --30 Valor total de la operación por ítem en guaraníes
         CASE WHEN a.mto_exento > 0 THEN 3 else 1 END as iafeciva,        --Forma de afectación tributaria del IVA
         CASE WHEN a.mto_exento > 0 THEN 'Exento' else 'Gravado IVA' END as ddesafeciva,     --Descripción de la forma de afectación tributaria del IVA
         decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS',it.FUG_OBT_PROP_GRAV_IVA(a.mto_exento_gs, a.mto_gra_5_gs, a.mto_gra_10_gs),
         it.FUG_OBT_PROP_GRAV_IVA(a.mto_exento, a.mto_gravado_5, a.mto_gravado_10))as dpropiva, --Proporción gravada de IVA
         decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS', it.FUG_OBT_TASA_IVA(a.mto_exento_gs, a.mto_gra_5_gs, a.mto_gra_10_gs),
         it.FUG_OBT_TASA_IVA(a.mto_exento, a.mto_gravado_5, a.mto_gravado_10))as dtasaiva,  --Tasa del IVA
		 decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS', nvl(a.mto_gra_5_gs,0) + nvl(a.mto_gra_10_gs,0),
                                    nvl(a.mto_gravado_5,0) + nvl(a.mto_gravado_10,0)) as dbasgraviva,     --Base gravada del IVA por ítem
         decode(decode(a.cod_mod_padre,7,a.cod_moneda,v.cod_moneda), 'GS', nvl(a.impuesto_5_gs,0) + nvl(a.impuesto_10_gs,0),
                                    nvl(a.impuesto_5,0) + nvl(a.impuesto_10,0)) as dliqivaitem      --36 Liquidación del IVA por ítem
 from cb_lib_ventas v,
         cb_par_comprobantes c,
         ba_personas p,
         cb_lib_ventas_det a
    where c.nro_timbrado = v.nro_timbrado
       and c.cod_oficina = v.cod_oficina
       and c.tipo = v.tip_comprobante
       and (a.nro_factura = p_nro_factura or p_nro_factura IS NULL)
       and a.nro_factura = v.nro_factura
       and v.cod_persona = p.cod_persona
       and v.fecha = a.fecha
       and v.tip_comprobante = a.tip_comprobante
       and nvl(v.nro_fac_referencia,-1) <> '0'
       and v.nro_timbrado = a.nro_timbrado
       and v.fecha = p_fecha
       and v.tip_comprobante = p_tip_comprobante;

cursor c_doc_asociado (p_nro_factura IN VARCHAR2,
                       p_fecha       IN DATE) is
select d.nro_factura,
       d.nro_fac_referencia,
       d.impreso,
       decode(b.serie, null, 2, 1) as iTipDocAso,--Tipo de documento asociado
       decode(b.serie, null,'Impreso', 'Electrónico') as dDesTipDocAso,--Descripción del tipo de documento asociado
       decode(b.serie, null, '', b.cod_control) as dCdCDERef, --CDC del DTE referenciado
       decode(b.serie, null, b.nro_timbrado, '') as dNTimDI, --Nro. timbrado documento impreso de referencia
       decode(b.serie, null, substr(d.nro_fac_referencia,1,3),'') as dEstDocAso,  --Establecimiento
       decode(b.serie, null, substr(d.nro_fac_referencia,5,3),'') as dPExpDocAso, --Punto de expedición
       decode(b.serie, null, substr(d.nro_fac_referencia,9),'') as dNumDocAso,  --Número del documento
       decode(b.serie, null, 1,'') as iTipoDocAso, --Tipo de documento impreso
       decode(b.serie, null, 'Factura','') as dDTipoDocAso,  --Descripción del tipo de documento impreso
       decode(b.serie, null, b.fecha,  '') as dFecEmiDI, --Fecha de emisión del documento impreso de referencia
       '' as dNumComRet,  --Número de comprobante de retención
       '' as dNumResCF, --Número de resolución de crédito fiscal
       '' as iTipCons,  --Tipo de constancia
       '' as dDesTipCons, --Descripción del tipo de constancia
       '' as dNumCons,  --Número de constancia
       '' as dNumControl, --Número de control de la constancia
       decode(b.usu_insercion, 'MIGRAV', v_ruc_fusionado, null) dRucFus --Ruc del Emisor (Vision)
  from cb_lib_ventas d, cb_par_comprobantes a, cb_lib_ventas b
 where d.tip_comprobante = 'N'
   and d.nro_timbrado = a.nro_timbrado
   and d.cod_oficina = a.cod_oficina
   and d.tip_comprobante = a.tipo
   and d.nro_fac_referencia <> '0'
   and d.nro_fac_referencia = b.nro_factura
   and d.nro_tim_referencia = b.nro_timbrado
   and d.fec_fac_referencia = b.fecha
   and b.tip_comprobante = 'F'
   and (d.nro_factura = p_nro_factura or p_nro_factura IS NULL)
   and d.fecha = p_fecha;

BEGIN
  --proposito: insertar registros a la tabla que alimenta a la vista que usara la ws de IDL. son los DE (Documentos Electronicos).
  --Autor: mmelgarejo.
  --Fecha: 15/07/2022
  --obs: las columnas se toman de la especificacion tecnica de la Sifen vesion_01.
  BEGIN
    pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
  EXCEPTION
    WHEN OTHERS THEN
      --Logueo el error y paso el rise al proceso principal.
      PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                             p_det_error    => 'Error en validación del módulo '||pae_cnf.g_cod_modulo||'. '||sqlerrm,
                             p_cod_persona  => null,
                             p_nro_cuenta   => null);
  raise;
  END;

  v_max_fac := fug_obt_pardinamico('CAN_MAX_DOC_FACTURY');  
  
  begin
    select count(*) 
           into v_can_fac
    from cb_doc_elec_cab
    where nvl(est_fac,'PROCESANDO') = 'PROCESANDO';
  exception
    when others then
         v_can_fac := 0;
  end;
  
  if nvl(v_can_fac,0) < nvl(v_max_fac,0) then 
    FOR REG IN c_cabecera LOOP
      v_nro_item := 0;
      v_nro_factura := reg.nro_factura;
      v_fac_ok  := 'Y';

      BEGIN
        -- obtenemos el id para el documento electronico
        SELECT S_ID_DE_CAB.NEXTVAL
          INTO v_nro_id
          FROM DUAL;
      EXCEPTION
        WHEN OTHERS THEN
          --Logueo el error y corto el proceso ya que no se podrán cargar documentos sin este id.
          PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                 p_det_error    => 'Error al consumir la secuencia S_ID_DE_CAB:'||sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
          EXIT;
      END;
      
      BEGIN
        
        insert into cb_doc_elec_cab a(
          a.id_documento,    --1 ID
          a.dinfoemi,        --Información de interés del emisor respecto al DE
          a.dinfofisc,       --Información de interés del Fisco respecto al DE. ej nota de remision.
          a.itide,           --Tipo de Documento Electrónico. 1= Factura Electronica segun M.T.
          a.ddestide,        --Descripción del tipo de documento electrónico
          a.dnumtim,         --Número del timbrado
          a.dest,            --Establecimiento
          a.dpunexp,         --Punto de expedición
          a.dnumdoc,         --Número del documento
          a.dserienum,       --10 Serie del número de timbrado
          a.dfeinit,         --Fecha inicio de vigencia del timbrado
          a.dfeemide,        --Fecha y hora de emisión del DE
          a.itiptra,         --Tipo de transacción
          a.ddestiptra,      --Descripción del tipo de transacción
          a.itimp,           --Tipo de impuesto afectado
          a.ddestimp,        --Descripción del tipo de impuesto afectado
          a.cmoneope,        --Moneda de la operación
          a.ddesmoneope,     --Descripción de la moneda de la operación
          a.dcondticam,       --Condición del tipo de cambio
          a.dticam,          --20 Tipo de cambio de la operación
          a.icondant,        --Condición del Anticipo
          a.ddescondant,     --Descripción de la condición del Anticipo
          a.cOblAfe,         --Tipo de obligaciones GMPEREIRA TN-890 - Facturación Electrónica, vigencia de la Nota Técnica 18
          a.dDesoblAfe,      --Descripción de la obligación afectada GMPEREIRA TN-890 - Facturación Electrónica, vigencia de la Nota Técnica 18																																 						
          a.inatrec,         --Naturaleza del receptor
          a.itiope,          --Tipo de operación
          a.cpaisrec,        --Código de país del receptor
          a.ddespaisre,      --Descripción del país receptor
          a.iticontrec,      --Tipo de contribuyente receptor
          a.drucrec,         --RUC del receptor
          a.ddvrec,          --Dígito verificador del RUC del receptor
          a.itipidrec,       --30 Tipo de documento de identidad del receptor
          a.ddtipidrec,      --Descripción del tipo de documento de identidad
          a.dnumidrec,       --Número de documento de identidad
          a.dnomrec,         --Nombre o razón social del receptor del DE
          a.dnomfanrec,      --Nombre de fantasía
          a.ddirrec,         --Dirección del receptor
          a.dnumcasrec,      --Número de casa del receptor
          a.cdeprec,         --Código del departamento del receptor
          a.ddesdeprec,      --Descripción del departamento del receptor
          a.cdisrec,         --Código del distrito del receptor
          a.ddesdisrec,      --40 Descripción del distrito del receptor
          a.cciurec,         --Código de la ciudad del receptor
          a.ddesciurec,      --Descripción de la ciudad del receptor
          a.dtelrec,         --Número de teléfono del receptor
          a.dcelrec,         --Número de celular del receptor
          a.demailrec,       --Correo electrónico del receptor
          a.dcodcliente,     --Código del cliente
          a.iindpres,        --Indicador de presencia
          a.ddesindpres,     --Descripción del indicador de presencia
          a.dfecemnr,        --Fecha futura del traslado de mercadería
          a.dmodcont,        --50 Modalidad - Código emitido por la DNCP
          a.dentcont,        --Entidad - Código emitido por la DNCP
          a.danocont,        --Año - Código emitido por la DNCP
          a.dseccont,        --Secuencia - emitido por la DNCP
          a.dfecodcont,      --Fecha de emisión del código de contratación por la DNCP
          a.imotemi,         --Motivo de emisión
          a.ddesmotemi,      --Descripción del motivo de emisión
          a.dkmr,            --Kilómetros estimados de recorrido
          a.dfecem,          --Fecha futura de emisión de la factura
          a.icondope,        --Condición de la operación                             1= Contado 2= Crédito
          a.ddcondope,       --60 Descripción de la condición de operación
          a.icondcred,       --Condición de la operación a crédito
          a.ddcondcred,      --Descripción de la condición de la operación a crédito
          a.dplazocre,       --Plazo del crédito
          a.dcuotas,         --Cantidad de cuotas
          a.dmonent,         --Monto de la entrega inicial
          a.dciclo,          --Ciclo
          a.dfecinic,        --Fecha de inicio de ciclo
          a.dfecfinc,        --Fecha de fin de ciclo
          a.dvencpag,        --Fecha de vencimiento para el pago
          a.dcontrato,       --70 Número de contrato
          a.dsalant,         --Saldo anterior
          a.dsubexe,         --Subtotal de la operación exenta
          a.dsubexo,         --Subtotal de la operación exonerada
          a.dsub5,           --Subtotal de la operación con IVA incluido a la tasa 5%(es total del iva 5)
          a.dsub10,          --Subtotal de la operación con IVA incluido a la tasa 10% (es total del iva 10)
          a.dtotope,         --Total Bruto de la operación
          a.dtotdesc,        --Total descuento particular por ítem
          a.dtotdescglotem,  --Total descuento global por ítem
          a.dtotantitem,     --Total Anticipo por ítem
          a.dtotant,         --80 Total Anticipo global por ítem
          a.dporcdesctotal,  --Porcentaje de descuento global sobre total de la operación
          a.ddesctotal,      --Total Descuentos de la operación
          a.danticipo,       --Total Anticipos de la operación
          a.dredon,          --Redondeo de la operación
          a.dcomi,           --Comisión de la operación
          a.dtotgralope,     --Total Neto de la operación
          a.diva5,           --Liquidación del IVA a la tasa del 5%
          a.diva10,          --Liquidación del IVA a la tasa del 10%
          a.dliqtotiva5,     --Liquidación total del IVA por redondeo a la tasa del 5%
          a.dliqtotiva10,    --90 Liquidación total del IVA por redondeo a la tasa del 10%
          a.divacomi,        --Liquidación total del IVA de la comisión
          a.dtotiva,         --Liquidación total del IVA
          a.dbasegrav5,      --Total base gravada al 5%
          a.dbasegrav10,     --Total base gravada al 10%
          a.dtbasgraiva,     --Total de la base gravada de IVA
          a.dtotalgs,        --Total general de la operación en Guaraníes
          a.dcarqr,          --Caracteres correspondientes al código QR
          a.dinfadic         --Información adicional de interés para el emisor
          )
        values
          (v_nro_id,   --1 sec. para usar como pk. y con este actualizar cuando venga de la set el registro.
          reg.dinfoemi,
          reg.dInfoFisc,
          reg.itide,
          reg.dDesTiDE,
          reg.dNumTim,
          reg.dEst,
          reg.dPunExp,
          reg.dNumDoc,
          reg.dSerieNum, --10
          reg.dFeIniT, --comente xq la base de datos guada como dd/mm/yyyy--to_date(to_char(trunc(c.fec_insercion), 'YYYY-MM-DD'),'YYYY-MM-DD') as dFeIniT/*, --como Itgf no guarda fecha de inicio de vigencia del timbrado por sugerencia de Dick Ruiz uso la fecha de insercion.
          reg.dFeEmiDE,
          reg.iTipTra, --para mas adelante se podria parametrizar dependiendo que se factura ya que en itfg entra varios puntos. Segun lo conversado con Dick Ruiz.
          reg.dDesTipTra,
          reg.iTImp, --por sugerencia de Dick Ruiz. Asi como entendimos poniendo la vista como emisor, las transcciones que emite ueno o similares.
          reg.dDesTImp,
          reg.cMoneOpe,
          reg.dDesMoneOpe,-- se comenta xq tiene que decir Guarani y este trae guaranies,(select descripcion from ba_monedas where cod_moneda = v.cod_moneda) as dDesMoneOpe
          reg.dCondTiCam,
          round(reg.dTiCam), --20
          reg.iCondAnt,
          reg.dDesCondAnt,
          reg.cOblAfe, -- GMPEREIRA TN-890 - Facturación Electrónica, vigencia de la Nota Técnica 18
          reg.dDesoblAfe, -- GMPEREIRA TN-890 - Facturación Electrónica, vigencia de la Nota Técnica 18																									   
          reg.iNatRec,
          decode(reg.sec_contable, 'PUBLICO', v_itiope, reg.iTiOpe),
          reg.cPaisRec,
          reg.dDesPaisRe,
          reg.iTiContRec,
          reg.dRucRec,
          reg.dDVRec,
          reg.iTipIDRec, --30
          reg.dDTipIDRec,
          reg.dNumIDRec,
          reg.dNomRec,
          reg.dNomFanRec,
          reg.dDirRec,
          reg.dNumCasRec,
          reg.cDepRec,
          reg.dDesDepRec,
          reg.cDisRec,
          reg.dDesDisRec, --40
          reg.cCiuRec,
          reg.dDesCiuRec,
          reg.dTelRec,
          reg.dCelRec,
          reg.dEmailRec,
          reg.dCodCliente,
          reg.iIndPres,
          reg.dDesIndPres,
          reg.dFecEmNR,
          decode(reg.sec_contable, 'PUBLICO', v_dModCont, reg.dModCont), --50
          decode(reg.sec_contable, 'PUBLICO', v_dEntCont, reg.dEntCont),
          decode(reg.sec_contable, 'PUBLICO', to_char(reg.dFeEmiDE, 'YY'), reg.dAnoCont),
          decode(reg.sec_contable, 'PUBLICO', v_dSecCont, reg.dSecCont),
          decode(reg.sec_contable, 'PUBLICO', reg.dFeEmiDE, reg.dFeCodCont),
          reg.iMotEmi,
          reg.dDesMotEmi,
          reg.dkmr,
          reg.dfecem,
          reg.iCondOpe,
          reg.dDCondOpe, --60
          reg.iCondCred,
          reg.dDCondCred,
          reg.dPlazoCre,
          reg.dCuotas,
          reg.dMonEnt,
          reg.dCiclo,
          reg.dFecIniC,
          reg.dFecFinC,
          reg.dVencPag,
          reg.dContrato, --70
          reg.dSalAnt,
          reg.dSubExe,
          reg.dSubExo,
          reg.dSub5,
          reg.dSub10,
          reg.dTotOpe,
          reg.dTotDesc,
          reg.dtotdescglotem,
          reg.dTotAntItem,
          reg.dTotAnt, --80
          reg.dPorcDescTotal,
          reg.dDescTotal,
          reg.dAnticipo,
          reg.dRedon,
          reg.dComi,
          reg.dTotGralOpe,
          reg.dIVA5,
          reg.dIVA10,
          reg.dLiqTotIVA5,
          reg.dLiqTotIVA10,
          reg.dIVAComi,
          reg.dTotIVA,
          reg.dBaseGrav5,
          reg.dBaseGrav10,
          reg.dTBasGraIVA,
          decode(reg.cMoneOpe,'PYG','',(reg.dTotGralOpe * round(reg.dTiCam))),
          reg.dCarQR,
          reg.dInfAdic);

      EXCEPTION
        WHEN OTHERS THEN
          --Logueo el error y marco el registro como no procesado.
          v_fac_ok  := 'N';
          PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                 p_det_error    => 'Error al insertar en CB_DOC_ELEC_CAB. Documento: '||v_nro_factura||'. '||sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
      END;

      if v_fac_ok     = 'Y' and
         reg.iCondOpe in (1) and
         reg.itide in (1) then
        BEGIN
          insert into cb_medio_pago(
            de_id,
            iTiPago, --Tipo de pago
            dDesTiPag, --Descripción del tipo de pago
            dMonTiPag, --Monto por tipo de pago
            cMoneTiPag, --Moneda por tipo de pago
            dDMoneTiPag, --Descripción de la moneda por tipo de pago
            dTiCamTiPag, --Tipo de cambio por tipo de pago
            iDenTarj,--Denominación de la tarjeta
            dDesDenTarj,--Descripción de denominación de la tarjeta
            dRSProTar, --Razón social de la procesadora de tarjeta
            dRUCProTar, --RUC de la procesadora de tarjeta
            dDVProTar, --Dígito verificador del RUC de la procesadora de tarjeta
            iForProPa,--Forma de procesamiento de pago
            dCodAuOpe,--Código de autorización de la operación
            dNomTit ,--Nombre del titular de la tarjeta
            dNumTarj,--Número de la tarjeta
            dNumCheq,--Número de cheque
            dBcoEmi) --Banco emisor
          values(
            v_nro_id,
            '16', --Tipo de pago
            'Pago bancario', --Descripción del tipo de pago
            reg.dTotOpe, --Monto por tipo de pago
            reg.cMoneOpe,
            reg.dDesMoneOpe, --Descripción de la moneda por tipo de pago
            decode(reg.cMoneOpe, 'PYG', '', REG.dticam), --Tipo de cambio por tipo de pago
            '',--Denominación de la tarjeta
            '',--Descripción de denominación de la tarjeta
            '', --Razón social de la procesadora de tarjeta
            '', --RUC de la procesadora de tarjeta
            '', --Dígito verificador del RUC de la procesadora de tarjeta
            '',--Forma de procesamiento de pago
            '',--Código de autorización de la operación
            '' ,--Nombre del titular de la tarjeta
            '',--Número de la tarjeta
            '',--Número de cheque
            ''); --Banco emisor
        EXCEPTION
          WHEN OTHERS THEN
          --Logueo el error y marco el registro como no procesado.
            v_fac_ok  := 'N';
            PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                   p_det_error    => 'Error al insertar en CB_MEDIO_PAGO. Documento: '||v_nro_factura||'. '||sqlerrm,
                                   p_cod_persona  => null,
                                   p_nro_cuenta   => null );
        END;
      end if;

      if v_fac_ok = 'Y' then

        BEGIN

          for det in c_detalle(reg.nro_factura, reg.dFeEmiDE, reg.tip_comprobante) loop
            v_nro_item := v_nro_item + 1;

            insert into cb_doc_elec_det(
              de_id,           --id
              dcodint,         --Código interno
              ddesproser,      --Descripción del producto y/o servicio
              cunimed,         --Unidad de medida
              ddesunimed,      --Descripción de la unidad de medida
              dcantproser,     --Cantidad del producto y/o servicio
              cpaisorig,    --Código del país de origen del producto
              ddespaisorig,       --Descripción del país de origen del producto
              dinfitem,        --Información de interés del emisor con respecto al ítem
              crelmerc,        --10 Código de datos de relevancia de las mercaderías
              ddesrelmerc,     --Descripción del código de datos de relevancia de las mercaderías
              dcanquimer,      --Cantidad de quiebra o merma
              dporquimer,      --Porcentaje de quiebra o merma
              dcdcanticipo,    --CDC del anticipo
              dpararanc,       --Partida arancelaria
              dncm,            --Nomenclatura común del Mercosur (NCM)
              ddncpg,          --Código DNCP – Nivel General
              ddncpe,          --Código DNCP – Nivel Especifico
              dgtin,           --Código GTIN por producto
              dgtinpq,         --20 Código GTIN por paquete
              dpuniproser,     --Precio unitario del producto y/o servicio (incluidos impuestos)
              dticamit,        --Tipo de cambio por ítem
              dtotbruopeitem,  --Total bruto de la operación por ítem
              ddescitem,       --Descuento particular sobre el precio unitario por ítem (incluidos impuestos)
              dporcdesit,      --Porcentaje de descuento particular por ítem
              ddescgloitem,    --Descuento global sobre el precio unitario por ítem (incluidos impuestos)
              dantpreuniit,    --Anticipo particular sobre el precio unitario por ítem (incluidos impuestos)
              dantglopreuniit, --Anticipo global sobre el precio unitario por ítem (incluidos impuestos)
              dtotopeitem,     --Valor total de la operación por ítem
              dtotopegs,       --30 Valor total de la operación por ítem en guaraníes
              iafeciva,        --Forma de afectación tributaria del IVA
              ddesafeciva,     --Descripción de la forma de afectación tributaria del IVA
              dpropiva,        --Proporción gravada de IVA
              dtasaiva,      --Tasa del IVA
              dbasgraviva,     --Base gravada del IVA por ítem
              dliqivaitem,     --36 Liquidación del IVA por ítem
              nro_item)
            values(
              v_nro_id,
              det.dcodint,         --Código interno
              det.ddesproser,      --Descripción del producto y/o servicio
              det.cunimed,         --Unidad de medida
              det.ddesunimed,      --Descripción de la unidad de medida
              det.dcantproser,     --Cantidad del producto y/o servicio
              det.cpaisorig,    --Código del país de origen del producto
              det.ddespaisorig,       --Descripción del país de origen del producto
              det.dinfitem,        --Información de interés del emisor con respecto al ítem
              det.crelmerc,        --10 Código de datos de relevancia de las mercaderías
              det.ddesrelmerc,     --Descripción del código de datos de relevancia de las mercaderías
              det.dcanquimer,      --Cantidad de quiebra o merma
              det.dporquimer,      --Porcentaje de quiebra o merma
              det.dcdcanticipo,    --CDC del anticipo
              det.dpararanc,       --Partida arancelaria
              det.dncm,            --Nomenclatura común del Mercosur (NCM)
              decode(reg.sec_contable, 'PUBLICO', v_ddncpg, det.ddncpg),          --Código DNCP – Nivel General
              decode(reg.sec_contable, 'PUBLICO', v_ddncpe, det.ddncpe),          --Código DNCP – Nivel Especifico
              det.dgtin,           --Código GTIN por producto
              det.dgtinpq,         --20 Código GTIN por paquete
              det.dpuniproser,     --Precio unitario del producto y/o servicio (incluidos impuestos)
              det.dticamit,        --Tipo de cambio por ítem
              det.dtotbruopeitem,  --Total bruto de la operación por ítem
              det.ddescitem,       --Descuento particular sobre el precio unitario por ítem (incluidos impuestos)
              det.dporcdesit,      --Porcentaje de descuento particular por ítem
              det.ddescgloitem,    --Descuento global sobre el precio unitario por ítem (incluidos impuestos)
              det.dantpreuniit,    --Anticipo particular sobre el precio unitario por ítem (incluidos impuestos)
              det.dantglopreuniit, --Anticipo global sobre el precio unitario por ítem (incluidos impuestos)
              det.dtotopeitem,     --Valor total de la operación por ítem
              det.dtotopegs,       --30 Valor total de la operación por ítem en guaraníes
              det.iafeciva,        --Forma de afectación tributaria del IVA
              det.ddesafeciva,     --Descripción de la forma de afectación tributaria del IVA
              det.dpropiva,        --Proporción gravada de IVA
              det.dtasaiva,      --Tasa del IVA
              det.dbasgraviva,     --Base gravada del IVA por ítem
              det.dliqivaitem,      --36 Liquidación del IVA por ítem
              v_nro_item);

          end loop;

        EXCEPTION
          WHEN OTHERS THEN
            --Logueo el error y marco el registro como no procesado.
            v_fac_ok := 'N';         
            PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                    p_det_error    => 'Error al insertar en CB_DOC_ELEC_DET. Documento: '||v_nro_factura||'. '||sqlerrm,
                                    p_cod_persona  => null,
                                    p_nro_cuenta   => null);
        END;
      end if;
      
      if v_fac_ok  = 'Y' and
         reg.itide in (5) then

        BEGIN
          for dasoc in c_doc_asociado(reg.nro_factura, reg.dFeEmiDE) loop

            if dasoc.itipdocaso= 1 then
              V_cdc:=dasoc.dCdCDERef;
              v_timbrado:=null;
            else
              V_cdc:=null;
              v_timbrado:=dasoc.dNTimDI;
            end if ;

              insert into cb_doc_asociado(
                de_id,
                itipdocaso,
                ddestipdocaso,
                dcdcderef,
                dntimdi,
                destdocaso,
                dpexpdocaso,
                dnumdocaso,
                itipodocaso,
                ddtipodocaso,
                dfecemidi,
                dnumcomret,
                dnumrescf,
                itipcons,
                ddestipcons,
                dnumcons,
                dnumcontrol,
                drucfus)
              values(
                v_nro_id,
                dasoc.itipdocaso,
                dasoc.ddestipdocaso,
                V_cdc,
                v_timbrado,
                dasoc.destdocaso,
                dasoc.dpexpdocaso,
                dasoc.dnumdocaso,
                dasoc.itipodocaso,
                dasoc.ddtipodocaso,
                dasoc.dfecemidi,
                dasoc.dnumcomret,
                dasoc.dnumrescf,
                dasoc.itipcons,
                dasoc.ddestipcons,
                dasoc.dnumcons,
                dasoc.dnumcontrol,
                dasoc.drucfus);

          end loop;
        EXCEPTION
          WHEN OTHERS THEN
            --Logueo el error, revierto los insert y continúo
            v_fac_ok := 'N';
            PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                  p_det_error    => 'Error al insertar en CB_DOC_ASOCIADO. Documento: '||v_nro_factura||'. '||sqlerrm,
                                  p_cod_persona  => null,
                                  p_nro_cuenta   => null);
        END;        
      end if;
    
      IF reg.sec_contable = 'PUBLICO' THEN
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                              p_det_error    => 'El cliente ' || reg.dCodCliente || ' pertenece al sector Público. Se modifica el tipo de operación a B2G en su comprobante: ' || reg.dest || '-' || reg.dpunexp || '-' || reg.dnumdoc,
                              p_cod_persona  => null,
                              p_nro_cuenta   => null);
      END IF;
        
      IF v_fac_ok = 'Y' THEN
        v_can_fac := nvl(v_can_fac,0) + 1;
        v_estado := 'G'; --Generado
      ELSE
        -- Si hubo un error en la inserción, se marca el estado como error y ejecuto un rollback por cualquier información que se haya insertado.
        v_estado := 'X'; --Error
        ROLLBACK;
      END IF;

      BEGIN
        --Se actualiza CB_LIB_VENTAS con el estado correspondiente
        update cb_lib_ventas a
          set a.estado = v_estado
        where a.nro_factura = reg.nro_factura
          and a.fecha = reg.dFeEmiDE;
      EXCEPTION
        WHEN OTHERS THEN
          PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_INS_FAC_ELECTRONICA',
                                 p_det_error    => 'Error al actualizar cb_lib_ventas. Documento: '||v_nro_factura||'. '||sqlerrm,
                                 p_cod_persona  => null,
                                 p_nro_cuenta   => null);
          ROLLBACK;
          CONTINUE;
      END;

      --Confirmamos los cambios comprobante por comprobante
      COMMIT;

      if v_can_fac >= v_max_fac then
        exit;
      end if;

    end loop;
  end if;
Exception
  When no_data_found then
    raise_application_error(-20000,'No se encontro para insertar el Documento Electrónico. '||sqlerrm);
  when others then
    raise_application_error(-20000,'Error de procesamiento: '||sqlerrm);
END PRB_INS_FAC_ELECTRONICA;
/