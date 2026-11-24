CREATE OR REPLACE FORCE VIEW IT.GV_BCP_ES_RECCAP AS
Select DECODE(DE.DETALLADO,'S',tipo         ,NULL   ) TIPO         ,
       DECODE(DE.DETALLADO,'S',nro_operacion,NULL   ) NRO_OPERACION,
       DECODE(DE.DETALLADO,'S',nro_cheque   ,NULL   ) NRO_CHEQUE   ,
       DECODE(DE.DETALLADO,'N',PERIODO      ,FECHA  ) PERIODO      ,
       ENTRADA_SALIDA  ,
       CODIGO_ENTIDAD  ,
       CODIGO_MONEDA   ,
       ABREVIATURA                                    CODIGO_PAIS,
       SUM(MONTO) MONTO,
       COTIZACION,
       DECODE(DE.DETALLADO,'S',PAIS, NULL)PAIS                   ,
       DECODE(DE.DETALLADO,'S',OF_PRIPERSONA          ,NULL  ) OF_PRIPERSONA          ,
       DECODE(DE.DETALLADO,'S',OF_PRIEMPRESAS         ,NULL  ) OF_PRIEMPRESAS         ,
       DECODE(DE.DETALLADO,'S',OF_PUBLICO             ,NULL  ) OF_PUBLICO             ,
       DECODE(DE.DETALLADO,'S',OF_PROPIOSBCO          ,NULL  ) OF_PROPIOSBCO          ,
       DECODE(DE.DETALLADO,'S',MT_COM_EXT_BIENES_Y_SER,NULL  ) MT_COM_EXT_BIENES_Y_SER,
       DECODE(DE.DETALLADO,'S',MT_INVINSFINANCIEROS   ,NULL  ) MT_INVINSFINANCIEROS   ,
       DECODE(DE.DETALLADO,'S',MT_INVBIENESRAICES     ,NULL  ) MT_INVBIENESRAICES     ,
       --DECODE(DE.DETALLADO,'S',MT_REMESAS ,NULL  ) MT_REMESAS ,
       --DECODE(DE.DETALLADO,'S',PAGO_SALARIO ,NULL  ) PAGO_SALARIO ,
       DECODE(DE.DETALLADO,'S',MT_REMESAUTILIDADES    ,NULL  ) MT_REMESAUTILIDADES    ,
       DECODE(DE.DETALLADO,'S',MT_DONACION            ,NULL  ) MT_DONACION            ,
       DECODE(DE.DETALLADO,'S',MT_PAGO_DE_PRESTAMOS   ,NULL  ) MT_PAGO_DE_PRESTAMOS   ,
       DECODE(DE.DETALLADO,'S',MT_OTROS_              ,NULL  ) MT_OTROS_              ,
       DECODE(DE.DETALLADO,'S',FT_EFECTIVO            ,NULL  ) FT_EFECTIVO            ,
       DECODE(DE.DETALLADO,'S',FTDEP_CBCODECLARANTE   ,NULL  ) FTDEP_CBCODECLARANTE   ,
       DECODE(DE.DETALLADO,'S',FTCHE_CBCOPLAZA        ,NULL  ) FTCHE_CBCOPLAZA        ,
       DECODE(DE.DETALLADO,'S',FTCHE_PLAZAEXT         ,NULL  ) FTCHE_PLAZAEXT         ,
       DECODE(DE.DETALLADO,'S',FTOTRA                 ,NULL  ) FTOTRA                 ,
       FECHA                                                   FECHA                  ,
       DE.DETALLADO                                            DETALLADO
from ( select 'TRANSFERENCIAS'                                TIPO          ,
               TO_CHAR(a.nro_operacion)                        NRO_OPERACION ,
               null                                            NRO_CHEQUE    ,
               to_char(a.fec_operacion,'YYYYMM')               PERIODO       ,
               a.fec_operacion                                 FECHA         ,
               decode(A.cod_modalidad,75,'E',72,'S')           ENTRADA_SALIDA,
               pag_gen.FU_OBT_COD_ENTIDAD                      CODIGO_ENTIDAD,
               A.COD_MONEDA                                    CODIGO_MONEDA ,
               CP.ABREVIATURA                                  ABREVIATURA   ,
               TO_NUMBER(a.cod_pai_banco)                      CODIGO_PAIS   ,
               FUE_OBT_SIG_REFCODES('REL_PAIS_BBVA_BCP',a.cod_pai_banco) PAIS,
               A.MONTO                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(fug_obt_cotizacion(a.cod_moneda,decode(DE.DETALLADO,'S',a.fec_operacion,last_day(a.fec_operacion)))) COTIZACION,
                --  OF Origen de Fondos.
               decode(fue_obt_val_max_refcodes('TRA_TIP_FONDO',a.tip_fondo),'F','X',null) OF_PRIPERSONA ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FONDO',a.tip_fondo),'E','X',null) OF_PRIEMPRESAS,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FONDO',a.tip_fondo),'P','X',null) OF_PUBLICO ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FONDO',a.tip_fondo),'B','X',null) OF_PROPIOSBCO,
               -- MT Motivo de TransacciOn.
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'X','X',null) MT_COM_EXT_BIENES_Y_SER,
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'I','X',null) MT_INVINSFINANCIEROS   ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'R','X',null) MT_INVBIENESRAICES     ,


              --Pedido BSEVOCORE-541
              --decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'T','X',null) MT_REMESAS,
               /*decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'19','X',null) PAGO_SALARIO ,*/
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'U','X',null) MT_REMESAUTILIDADES    ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'D','X',null) MT_DONACION            ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'P','X',null) MT_PAGO_DE_PRESTAMOS   ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_MOTIVO',a.tip_motivo),'O','X',null) MT_OTROS_              ,
              -- FT Financiamiento de la TransacciOn.
               decode(fue_obt_val_max_refcodes('TRA_TIP_FINANCIACION',a.tip_financiacion),'E','X',null) FT_EFECTIVO           ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FINANCIACION',a.tip_financiacion),'D','X',null) FTDEP_CBCODECLARANTE  ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FINANCIACION',a.tip_financiacion),'C','X',null) FTCHE_CBCOPLAZA       ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FINANCIACION',a.tip_financiacion),'X','X',null) FTCHE_PLAZAEXT        ,
               decode(fue_obt_val_max_refcodes('TRA_TIP_FINANCIACION',a.tip_financiacion),'O','X',null) FTOTRA
         from lc_transferencias a , (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE,
              ba_cod_referencias cp
        where a.cod_pai_banco = cp.val_minimo
          and a.cod_modalidad in (75,72)
          and (cp.dominio = 'REL_PAIS_BBVA_BCP' OR cp.dominio IS NULL)
          and TO_CHAR(a.fec_operacion,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'CARTAS DE CREDITO'                             TIPO          ,
               A.NRO_CUENTA                                    NRO_OPERACION ,
               NULL                                            NRO_CHEQUE    ,
               to_char(a.fecha,'YYYYMM')                       PERIODO       ,
               a.fecha                                         FECHA         ,
               decode(a.cod_mad_padre,81,'S','E')              ENTRADA_SALIDA,
               pag_gen.FU_OBT_COD_ENTIDAD                      CODIGO_ENTIDAD,
               A.COD_MONEDA                                    CODIGO_MONEDA ,
               FUE_OBT_DES_REFCODES('REL_PAIS_BBVA_BCP',pai.cod_pais)ABREVIATURA   ,
               TO_NUMBER(pai.cod_pais)                         CODIGO_PAIS   ,
               FUE_OBT_SIG_REFCODES('REL_PAIS_BBVA_BCP',pai.cod_pais)PAIS    ,
               A.MONTO                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(decode(DE.DETALLADO,'S',A.COTIZACION,fug_obt_cotizacion(a.cod_moneda,last_day(a.fecha)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
              --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
        from cx_movimientos_his a, (select a.nro_cuenta, a.cod_pais from cx_cta_importaciones a union all
                                    select a.nro_cuenta, 258        from cx_cta_exportaciones a           ) pai,
                                   (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE

        where a.reversado     != 'S'
          and a.cod_mad_padre in (81,82)
          and a.cod_tra_padre in (368,384)
          and a.nro_cuenta    = pai.nro_cuenta
          and to_char(a.fecha,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'OPERACIONES DE COBRANZAS'                      TIPO          ,
               A.NRO_CUENTA                                    NRO_OPERACION ,
               NULL                                            NRO_CHEQUE    ,
               to_char(a.fecha,'YYYYMM')                       PERIODO       ,
               a.fecha                                         FECHA         ,
               decode(a.cod_mad_padre,83,'S','E')              ENTRADA_SALIDA,
               pag_gen.FU_OBT_COD_ENTIDAD                      CODIGO_ENTIDAD,
               A.COD_MONEDA                                    CODIGO_MONEDA ,
               FUE_OBT_DES_REFCODES('REL_PAIS_BBVA_BCP',pai.pais) ABREVIATURA,
               TO_NUMBER(nvl(pai.pais,999))                    CODIGO_PAIS   ,
               FUE_OBT_SIG_REFCODES('REL_PAIS_BBVA_BCP',pai.pais)PAIS        ,
               A.MONTO                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(decode(DE.DETALLADO,'S',A.COTIZACION,fug_obt_cotizacion(a.cod_moneda,last_day(a.fecha)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
        from cx_movimientos_his a, (select a.nro_cuenta, decode(a.cod_modalidad,83,a.cod_pai_beneficiario, a.cod_pai_pagador) pais from cx_cta_cobranzas a ) pai,
                                   (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
        where a.reversado     != 'S'
          and a.cod_mad_padre in (83,84)
          and a.cod_tra_padre in (368)
          and a.nro_cuenta    = pai.nro_cuenta
          and to_char(a.fecha,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'CHEQUES EMITIDOS'                              TIPO          ,
               a.nro_cuenta                                    NRO_OPERACION ,
               a.nro_cheque                                    NRO_CHEQUE    ,
               to_char(a.fecha,'YYYYMM')                       PERIODO       ,
               a.fecha                                         FECHA         ,
               'S'                                             ENTRADA_SALIDA,
               pag_gen.FU_OBT_COD_ENTIDAD                      CODIGO_ENTIDAD,
               fug_obt_mon_cta(A.NRO_CUENTA)                   CODIGO_MONEDA ,
               FUE_OBT_DES_REFCODES('REL_PAIS_BBVA_BCP',decode(a.nro_cuenta,3104000077,20,13))  ABREVIATURA   ,
               TO_NUMBER(decode(a.nro_cuenta,3104000077,20,13))CODIGO_PAIS   ,
               FUE_OBT_SIG_REFCODES('REL_PAIS_BBVA_BCP',decode(a.nro_cuenta,3104000077,20,13))PAIS        ,
               A.MONTO                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),decode(DE.DETALLADO,'S',a.fecha,last_day(a.fecha)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
        from cc_che_ger_emitidos a,
             (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
        where a.nro_cuenta in (3104000077, 3104000018,3104000085,3104000107)
          AND to_char(a.fecha,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'CHEQUES RECIBIDOS EN DEPOSITOS'                TIPO          ,
               a.nro_cuenta                                    NRO_OPERACION ,
               TO_NUMBER(a.nro_cheque)                         NRO_CHEQUE    ,
               to_char(a.fecha,'YYYYMM')                       PERIODO       ,
               a.fecha                                         FECHA         ,
               'E'                                             ENTRADA_SALIDA,
               pag_gen.fu_obt_cod_entidad                      CODIGO_ENTIDAD,
               a.cod_moneda                                    CODIGO_MONEDA ,
               'PY'                                            ABREVIATURA   ,
               1                                               CODIGO_PAIS   ,
               'PARAGUAY'                                      PAIS          ,
               a.monto                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(fug_obt_cotizacion(a.cod_moneda,decode(DE.DETALLADO,'S',a.fecha,last_day(a.fecha)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
              -- NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
          from ge_che_exterior a,
               ba_monedas      b,
               ge_cuentas      c,
               ge_bancos       d,
               ba_personas     e,
              (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
         where a.nro_cuenta = c.nro_cuenta(+)
         and b.cod_moneda   = a.cod_moneda
         and a.cod_moneda  != pag_gen.fu_obt_mon_local
         and a.cod_banco    = d.cod_banco
         and d.cod_persona  = e.cod_persona
         and a.cod_moneda  in ('USD','EUR')
         AND to_char(a.fecha,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'CLEARING DOLARES LOCAL - ENVIADOS'             TIPO          ,
               a.nro_cuenta                                    NRO_CUENTA    ,
               a.nro_cheque                                    NRO_CHEQUE    ,
               to_char(a.fecha,'YYYYMM')                       PERIODO       ,
               a.fecha                                         FECHA         ,
               'S'                                             ENTRADA_SALIDA,
               pag_gen.fu_obt_cod_entidad                      CODIGO_ENTIDAD,
               a.cod_moneda                                    CODIGO_MONEDA ,
               'US'                                            ABREVIATURA   ,
               13                                              CODIGO_PAIS   ,
               'ESTADOS UNIDOS'                                PAIS          ,
               a.monto                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(fug_obt_cotizacion(a.cod_moneda,decode(DE.DETALLADO,'S',a.fecha,last_day(a.fecha)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
          from cc_che_enviados a,
               ba_monedas      b,
               ge_bancos       c,
               ge_cuentas      d,
               (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
        where a.nro_cuenta = d.nro_cuenta(+)
          and b.cod_moneda = a.cod_moneda
          and c.cod_banco  = a.cod_banco
          and a.cod_moneda = 'USD'
          and a.com_directa= 'S'
          AND to_char(a.fecha,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        union ALL
        select 'CLEARING DOLARES LOCAL - RECIBIDOS'            TIPO          ,
               a.nro_cuenta                                    NRO_OPERACION ,
               a.nro_cheque                                    NRO_CHEQUE    ,
               to_char(a.fec_proceso,'YYYYMM')                 PERIODO       ,
               a.fec_proceso                                   FECHA         ,
               'E'                                             ENTRADA_SALIDA,
               pag_gen.fu_obt_cod_entidad                      CODIGO_ENTIDAD,
               fug_obt_mon_cta(a.nro_cuenta)                   CODIGO_MONEDA ,
               'PY'                                            ABREVIATURA   ,
               1                                               CODIGO_PAIS   ,
               'PARAGUAY'                                      PAIS          ,
               a.monto                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               round(fug_obt_cotizacion(fug_obt_mon_cta(a.nro_cuenta),decode(DE.DETALLADO,'S',a.fec_proceso,last_day(a.fec_proceso)))) COTIZACION,
               NULL                                            OF_PRIPERSONA ,
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               NULL                                            MT_OTROS_              ,
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               NULL                                            FTOTRA
          from cc_che_recibidos a,
               ba_monedas       b,
               ge_cuentas       d,
               (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
        where a.nro_cuenta   = d.nro_cuenta(+)
          and b.cod_moneda   = fug_obt_mon_cta(a.nro_cuenta)
          and fug_obt_mon_cta(a.nro_cuenta)   = 'USD'
          and a.com_directa  = 'S'
          and a.est_cheque   = 'P'
          and exists(Select 1
                     From cc_che_pagados xp
                     Where xp.nro_cuenta = a.nro_cuenta
                       and xp.nro_cheque = a.nro_cheque
                       and xp.monto      = a.monto)
          AND to_char(a.fec_proceso,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')
        UNION ALL
        select 'TRANSFERENCIAS BTS RECIBIDAS'                  TIPO          ,--LA 20-08-2015
               b.nro_cta_credito                               NRO_OPERACION ,
               b.nro_cheque                                    NRO_CHEQUE    ,
               to_char(b.fec_ingreso,'YYYYMM')                 PERIODO       ,
               b.fec_ingreso                                   FECHA         ,
               'E'                                             ENTRADA_SALIDA,
               pag_gen.fu_obt_cod_entidad                      CODIGO_ENTIDAD,
               b.cod_moneda                                    CODIGO_MONEDA ,
               'MX'                                            ABREVIATURA   ,
               12                                              CODIGO_PAIS   ,
               'MEXICO'                                        PAIS          ,
               b.monto                                         MONTO         ,
               DE.DETALLADO                                    DETALLADO     ,
               null                                            COTIZACION    ,
               'X'                                             OF_PRIPERSONA ,--Se agrega 'X'
               NULL                                            OF_PRIEMPRESAS,
               NULL                                            OF_PUBLICO    ,
               NULL                                            OF_PROPIOSBCO ,
               NULL                                            MT_COM_EXT_BIENES_Y_SER,
               NULL                                            MT_INVINSFINANCIEROS   ,
               NULL                                            MT_INVBIENESRAICES     ,
               --NULL                                            MT_REMESAS ,
               --NULL                                            PAGO_SALARIO,
               NULL                                            MT_REMESAUTILIDADES    ,
               NULL                                            MT_DONACION            ,
               NULL                                            MT_PAGO_DE_PRESTAMOS   ,
               'X'                                             MT_OTROS_              ,--Se agrega 'X'
               NULL                                            FT_EFECTIVO            ,
               NULL                                            FTDEP_CBCODECLARANTE   ,
               NULL                                            FTCHE_CBCOPLAZA        ,
               NULL                                            FTCHE_PLAZAEXT         ,
               'X'                                            FTOTRA--Se agrega 'X'
         from ge_pag_proveedores b,(SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE
        where b.tip_comprobante= 'N'
          and b.cod_ente = 1091
          and b.estado= 'N'
          AND to_char(b.fec_ingreso,'YYYY') = fug_obt_pardinamico('ANHO_GV_BCP_ES_RECCAP')) XR,
    (SELECT 'S' DETALLADO FROM DUAL UNION ALL SELECT 'N' FROM DUAL) DE

  WHERE XR.DETALLADO = DE.DETALLADO
  GROUP BY DECODE(DE.DETALLADO,'S',tipo         ,NULL   ),
           DECODE(DE.DETALLADO,'S',nro_operacion,NULL   ),
           DECODE(DE.DETALLADO,'S',nro_cheque   ,NULL   ),
           DECODE(DE.DETALLADO,'N',PERIODO      ,fecha  ),
           entrada_salida,
           codigo_entidad,
           codigo_moneda ,
           abreviatura   ,
           DECODE(DE.DETALLADO,'S',pais,NULL ),
           cotizacion,
           DECODE(DE.DETALLADO,'S',OF_PRIPERSONA          ,NULL  ),
           DECODE(DE.DETALLADO,'S',OF_PRIEMPRESAS         ,NULL  ),
           DECODE(DE.DETALLADO,'S',OF_PUBLICO             ,NULL  ),
           DECODE(DE.DETALLADO,'S',OF_PROPIOSBCO          ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_COM_EXT_BIENES_Y_SER,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_INVINSFINANCIEROS   ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_INVBIENESRAICES     ,NULL  ),
           --DECODE(DE.DETALLADO,'S',MT_REMESAS,NULL  ),
            --DECODE(DE.DETALLADO,'S', PAGO_SALARIO ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_REMESAUTILIDADES    ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_DONACION            ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_PAGO_DE_PRESTAMOS   ,NULL  ),
           DECODE(DE.DETALLADO,'S',MT_OTROS_              ,NULL  ),
           DECODE(DE.DETALLADO,'S',FT_EFECTIVO            ,NULL  ),
           DECODE(DE.DETALLADO,'S',FTDEP_CBCODECLARANTE   ,NULL  ),
           DECODE(DE.DETALLADO,'S',FTCHE_CBCOPLAZA        ,NULL  ),
           DECODE(DE.DETALLADO,'S',FTCHE_PLAZAEXT         ,NULL  ),
           DECODE(DE.DETALLADO,'S',FTOTRA                 ,NULL  ),
           FECHA                                                  ,
           DE.DETALLADO
;

