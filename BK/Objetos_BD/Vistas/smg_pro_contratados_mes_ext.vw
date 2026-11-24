CREATE OR REPLACE FORCE VIEW IT.SMG_PRO_CONTRATADOS_MES_EXT AS
select dat."NRO_CUENTA",dat."COD_PERSONA",dat."NOMBRE_PERSONA",dat."DESC_PRODUCTO",dat."COD_MONEDA",dat."FECHA_ALTA",dat."ESTADO_TARJETA",dat."NRO_GARANTIA",dat."COD_GARANTIA",dat."MTO_APL_COMPUTABLE",dat."MTO_RIESGO",dat."AFINIDAD",dat."LIN_CREDITO",dat."FEC_VENCIMIENTO",dat."NRO_TARJETA",dat."USU_PROMOTOR",dat."NOMBRE_OFICIAL",dat."USU_INSERCION",dat."NRO_SOLICITUD",dat."MTO_CAPITAL",dat."DIA_PLAZO",dat."VAL_TASA",dat."SALDO_DIARIO_DISPONIBLE",dat."ESTADO_CUENTA",dat."CAPITALIZACION",dat."FEC_APERTURA",dat."COD_OFICINA",dat."COD_MODULO",dat."COD_MODALIDAD",dat."ESTADO",dat."EST_DESC",dat."COD_USU_OFICIAL",dat."CANT",dat."GRUPO",ofi.descripcion ofi_descripcion,mo.descripcion as mod_descripcion
from (
      SELECT cc.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona) as nombre_persona,
      ttip.descripcion as desc_producto,c.cod_moneda,tt.fec_emision as fecha_alta,tte.descripcion as estado_tarjeta,
      tcg.nro_garantia,tcg.cod_garantia,tcg.mto_apl_computable,tcg.mto_riesgo,
      fug_obt_des_afinidad( tct.afinidad) as afinidad,tct.lin_credito,tt.fec_vencimiento,tt.nro_tarjeta,
      case when ts.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ts.cod_usu_promotor)  end as usu_promotor,
      fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
      fue_obt_nom_usuario(ts.usu_insercion) usu_insercion,
      ts.nro_solicitud as nro_solicitud, 0 as mto_capital,0 as dia_plazo,0 as val_tasa,
      0 as saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
      c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion est_desc, cli.cod_usu_oficial,
      count(1)cant, '01. Tarjetas de Crédito' grupo
    FROM ge_cuentas c,
         ge_est_cuentas est,
         ge_cta_clientes cc,
         ge_clientes cli,
         ta_tarjetas tt,
         ta_tipos ttip,
         ta_tar_estados tte ,
         ta_cta_garantias tcg,
         ta_cta_tarjetas tct,
         ta_solicitudes ts
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and c.cod_modulo = 5 -- tarjeta de credito
       and tt.nro_cuenta = cc.nro_cuenta and tt.cod_persona = cc.cod_persona
       and ttip.cod_modalidad = c.cod_modalidad
       and ttip.cod_modulo = c.cod_modulo
       and ttip.afinidad  = tct.afinidad
       and ttip.sub_afinidad = tct.sub_afinidad
       and tte.cod_estado = tt.cod_estado
       and tcg.nro_cuenta = cc.nro_cuenta
       and tct.nro_cuenta = c.nro_cuenta
       and tct.nro_solicitud = ts.nro_solicitud
     group by cc.nro_cuenta,tt.cod_persona,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),ttip.descripcion,
              c.cod_moneda,tt.fec_emision ,tte.descripcion,
              tcg.nro_garantia,tcg.cod_garantia,tcg.mto_apl_computable,tcg.mto_riesgo,
              tct.afinidad,tct.lin_credito,tt.fec_vencimiento,tt.nro_tarjeta,
              c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial),ts.cod_usu_promotor,
              fue_obt_nom_usuario(ts.usu_insercion),ts.nro_solicitud
    union all
    select
     c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
     c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,
     pcg.nro_garantia as nro_garantia,pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
     '' as afinidad,0 as lin_credito,PCP.FEC_VENCIMIENTO as fec_vencimiento,null as nro_tarjeta,
     case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
     fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
     fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
     pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
     0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
     c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion as est_desc, cli.cod_usu_oficial,
     count(1) cant, '02. Préstamos de Consumo' as grupo
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli,
          pr_cta_garantias pcg,
          pr_cta_prestamos pcp,
          pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (65, 68)) -- prestamos de consumo
       and pcg.nro_cuenta =  cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
     group by c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),
              c.cod_moneda,pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
              c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial),
              pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,ps.cod_usu_promotor,
              fue_obt_nom_usuario(ps.usu_insercion),pcp.fec_vencimiento
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,pcg.nro_garantia as nro_garantia,
            pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
            '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
            case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
            pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
            0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
            c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
           count(1), '03. H20/H30' as grupo
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli,
          pr_cta_garantias pcg,
          pr_cta_prestamos pcp,
          pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (612, 673)) -- H20/H30
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta    )
     group by
              c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
              ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
              ,c.cod_moneda,c.fec_apertura,
              pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
              pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa   ,ps.cod_usu_promotor,
              fue_obt_nom_usuario(ps.usu_insercion),pcp.fec_vencimiento
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,pcg.nro_garantia as nro_garantia,
            pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
            '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
            case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
            pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
            0 as  saldo_diario_disponible,'' as estado_cuenta,  '' as capitalizacion,
            c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            count(1), '04. Otros préstamos particulares' as grupo
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli
          ,pr_cta_garantias pcg
          ,pr_cta_prestamos pcp
          ,pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (676, 672, 610, 60)) -- otros préstamos particulares
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta  )
       group by
               c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
               cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
               ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
               ,c.cod_moneda,c.fec_apertura,
               pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
               pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,pcp.fec_vencimiento,PS.COD_USU_PROMOTOR,PS.COD_USU_PROMOTOR,PS.USU_INSERCION
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,pcg.nro_garantia as nro_garantia
            ,pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
            '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
            case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
            pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
            0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
            c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            count(1), '05. Operaciones de Comercio Exterior '
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli
          ,pr_cta_garantias pcg
          ,pr_cta_prestamos pcp
          ,pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (63, 64, 606, 602, 603, 627, 631)) -- operaciones de comercio exterior
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta   )
     group by
             c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
             cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
             ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
             ,c.cod_moneda,c.fec_apertura,
             pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
             pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa ,pcp.fec_vencimiento,PS.COD_USU_PROMOTOR,PS.COD_USU_PROMOTOR,PS.USU_INSERCION
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,pcg.nro_garantia as nro_garantia,
            pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
            '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
            case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
            pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
            0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
            c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
            count(1), '06. Préstamos Hipotecarios Empresas'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
          ,pr_cta_garantias pcg
          ,pr_cta_prestamos pcp
          ,pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (61, 67, 613, 622, 608)) -- prestamos hipotecarios empresas
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta  )
     group by
              c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
              ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
              ,c.cod_moneda,c.fec_apertura,
              pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
             pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,pcp.fec_vencimiento,PS.COD_USU_PROMOTOR,PS.COD_USU_PROMOTOR,PS.USU_INSERCION
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta, pcg.nro_garantia as nro_garantia,
            pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
            '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
             case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
            pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
            0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
            c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
           count(1), '07. Préstamos a la Vista'
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli
          ,pr_cta_garantias pcg
          ,pr_cta_prestamos pcp
          ,pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (677, 675)) -- prestamos a la vista
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta  )
     group by
              c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
              ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
              ,c.cod_moneda,c.fec_apertura,
              pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
             pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,pcp.fec_vencimiento,PS.COD_USU_PROMOTOR,PS.COD_USU_PROMOTOR,PS.USU_INSERCION
    union all
    select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
           c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,pcg.nro_garantia as nro_garantia,
           pcg.cod_garantia as cod_garantia,pcg.mto_apl_computable as mto_apl_computable,pcg.mto_riesgo as mto_riesgo,
           '' as afinidad,0 as lin_credito,pcp.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
           case when ps.cod_usu_promotor is null then '' else fue_obt_nom_usuario(ps.cod_usu_promotor)  end as usu_promotor,
           fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
           fue_obt_nom_usuario(ps.usu_insercion) usu_insercion,
           pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa,
           0 as  saldo_diario_disponible,'' as estado_cuenta,'' as capitalizacion,
           c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,
           count(1), '08. Otros préstamos de la empresa'
     from ge_cuentas c, ge_est_cuentas est, ge_cta_clientes cc, ge_clientes cli
          ,pr_cta_garantias pcg
          ,pr_cta_prestamos pcp
          ,pr_solicitudes ps
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 6 and c.cod_modalidad in (61, 67, 613, 622, 608, 613)) -- otros prestamos de la empresa
       and pcg.nro_cuenta = cc.nro_cuenta
       and pcp.nro_cuenta = cc.nro_cuenta
       and ps.nro_solicitud = pcp.nro_solicitud
       and pcg.mto_apl_computable >= any( select max(pcg2.mto_apl_computable) from pr_cta_garantias pcg2 where pcg2.nro_cuenta = cc.nro_cuenta   )
     group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
              ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
              ,c.cod_moneda,c.fec_apertura,
              pcg.nro_garantia,pcg.cod_garantia,pcg.mto_apl_computable,pcg.mto_riesgo,
              pcp.nro_solicitud,pcp.mto_capital,ps.dia_plazo,pcp.val_tasa      ,pcp.fec_vencimiento ,PS.COD_USU_PROMOTOR,PS.COD_USU_PROMOTOR,PS.USU_INSERCION
     union all
     select c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,
            0 as nro_garantia,0 as cod_garantia,0 as mto_apl_computable,0 as mto_riesgo,
            '' as afinidad,0 as lin_credito,null as fec_vencimiento,null as nro_tarjeta,
            '' as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            '' as usu_insercion,
            0 as nro_solicitud,0 as mto_capital,0 as dia_plazo,c.val_tasa as val_tasa,
            fug_obt_sal_diario(c.nro_cuenta, fug_obt_fec_anterior(1)) as saldo_diario_disponible,
            fug_obt_des_est_cta(c.cod_modulo,c.cod_modalidad,c.estado) as estado_cuenta,
            '' as capitalizacion,c.fec_apertura, c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion, cli.cod_usu_oficial,count(1), '09. Ahorro a la vista'
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 3 and c.cod_modalidad = 31) -- ahorro a la vista
      group by c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
              cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
              ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
              ,c.cod_moneda,c.fec_apertura,c.val_tasa
     union all
     select  c.nro_cuenta, cc.cod_persona,fue_obt_nom_persona(cc.cod_persona),'' as desc_producto,
            c.cod_moneda,c.fec_apertura as fecha_alta,'' as estado_tarjeta,0 as nro_garantia
            ,0 as cod_garantia,0 as mto_apl_computable,0 as mto_riesgo,
            '' as afinidad,0 as lin_credito,acc.fec_vencimiento as fec_vencimiento,null as nro_tarjeta,
             '' as usu_promotor,
            fue_obt_nom_usuario(cli.cod_usu_oficial) nombre_oficial,
            '' as usu_insercion,
            0 as nro_solicitud,0 as mto_capital,acc.fec_vencimiento - acc.fec_apertura as dia_plazo,gtf.val_tasa as val_tasa,
            fug_obt_sal_diario(c.nro_cuenta, fug_obt_fec_anterior(1)) as  saldo_diario_disponible,'' as estado_cuenta,
            bcr.significado as capitalizacion,c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado,
            est.descripcion, cli.cod_usu_oficial,count(1), '10. CDA'
     from ge_cuentas c,
          ge_est_cuentas est,
          ge_cta_clientes cc,
          ge_clientes cli,
          ah_cta_certificados acc,
          ba_cod_referencias bcr,
          ge_tas_fechas gtf
     where c.cod_modulo = est.cod_modulo
       and c.cod_modalidad = est.cod_modalidad
       and c.estado = est.estado
       and est.activo = 'S'
       and c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and cc.cod_persona = cli.cod_persona
       and (c.cod_modulo = 3 and c.cod_modalidad in (33, 36)) -- cda
       and acc.nro_cuenta = c.nro_cuenta
       and bcr.dominio = 'TIP_CAPITALIZACION'
       and bcr.val_minimo = acc.tip_capitalizacion
       and gtf.cod_tasa = acc.cod_tasa
       and ((acc.tas_personalizada = 'S' and gtf.nro_cuenta = c.nro_cuenta) or (acc.tas_personalizada = 'N' and gtf.nro_cuenta is null))
     group by  c.fec_apertura,c.cod_oficina, c.cod_modulo, c.cod_modalidad, c.estado, est.descripcion,
               cli.cod_usu_oficial, fue_obt_nom_usuario(cli.cod_usu_oficial)
               ,c.nro_cuenta,cc.cod_persona,fue_obt_nom_persona(cc.cod_persona)
               ,c.cod_moneda,c.fec_apertura,acc.fec_vencimiento - acc.fec_apertura,
               acc.fec_apertura,acc.fec_vencimiento,bcr.significado  ,acc.tas_personalizada,gtf.val_tasa
) dat, ba_oficinas ofi, ge_modalidades mo
where dat.cod_oficina = ofi.cod_oficina
  and dat.cod_modulo = mo.cod_modulo
  and dat.cod_modalidad = mo.cod_modalidad
order by 26,34,27,35,28,29,36,30,31,33
;

