CREATE OR REPLACE FORCE VIEW IT.BV_USD_BOVEDA AS
select  decode(a.cod_tip_ope_efe,1,'Entradas en cuenta de clientes', 3,'Entradas - Otros',5,'Salidas por cuenta de Clientes',6,'Salidas por ventanillas y no a través de cuenta de cliente',7, 'Otros_Salidas' ) as grupo,
             nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) nro_cliente,
             fue_obt_nom_persona(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta))) nom_cliente,
             fuw_obt_homebanking(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),null, 'P') as tipo_persona,
             fug_obt_datos_clientes(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),'S') sucursal_cliente,
             fue_obt_nom_usuario(fug_obt_cod_usu_oficial(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) )) gestor,
             fug_obt_des_transaccion(a.cod_modulo, a.cod_modalidad, a.cod_transaccion) transaccion,
             nvl(a.monto, 0) monto_trans,
             a.cod_tip_ope_efe as tipo_oper,
             a.cod_ofi_origen,
             to_char(a.fecha, 'dd') dia,
             to_char(a.fecha, 'mm') mes,
             to_char(a.fecha, 'yyyy') ano,
             a.cod_moneda
   from lc_ope_efectivos a
  where (a.cod_tip_ope_efe in (1, 3, 5, 7) or (a.cod_tip_ope_efe = 6  and a.cod_persona is null ))
    --and a.cod_moneda = 'USD'
 union all
 select   'Entradas por Ventanillas y no a través de cuenta de cliente' as grupo,
             nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) nro_cliente,
             fue_obt_nom_persona(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta))) nom_cliente,
             fuw_obt_homebanking(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),null, 'P') as tipo_persona,
             fug_obt_datos_clientes(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),'S') sucursal_cliente,
             fue_obt_nom_usuario(fug_obt_cod_usu_oficial(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) )) gestor,
             fug_obt_des_transaccion(a.cod_modulo, a.cod_modalidad, a.cod_transaccion) transaccion,
             nvl(a.monto, 0) monto_trans,
             a.cod_tip_ope_efe as tipo_oper,
             a.cod_ofi_origen,
             to_char(a.fecha, 'dd') dia,
             to_char(a.fecha, 'mm') mes,
             to_char(a.fecha, 'yyyy') ano,
             a.cod_moneda
  from lc_ope_efectivos a
  where a.cod_tip_ope_efe = 2
    --and a.cod_moneda = 'USD'
    and a.cod_persona is not null
    and a.cod_persona not in (SELECT distinct (gbanc.cod_persona)
                                 FROM ge_bancos gbanc, cc_cta_bancarias b
                                where gbanc.cod_banco = b.cod_banco
                                  and ((b.cod_modalidad = 43 and
                                      pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                      (b.cod_modalidad = 45 and
                                      pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                  and b.estado = 'N'
                                  and gbanc.estado = 'A')
union all
 select decode(a.cod_tip_ope_efe,2, 'Entradas de corresponsal ME', 'Salidas por Corresponsal ME') as grupo,
            nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) nro_cliente,
             fue_obt_nom_persona(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta))) nom_cliente,
             fuw_obt_homebanking(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),null, 'P') as tipo_persona,
             fug_obt_datos_clientes(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)),'S') sucursal_cliente,
             fue_obt_nom_usuario(fug_obt_cod_usu_oficial(nvl(a.cod_persona, fug_obt_cli_principal(a.nro_cuenta)) )) gestor,
             fug_obt_des_transaccion(a.cod_modulo, a.cod_modalidad, a.cod_transaccion) transaccion,
             nvl(a.monto, 0) monto_trans,
             decode(a.cod_tip_ope_efe,2,4,a.cod_tip_ope_efe) as tipo_oper,
             a.cod_ofi_origen,
             to_char(a.fecha, 'dd') dia,
             to_char(a.fecha, 'mm') mes,
             to_char(a.fecha, 'yyyy') ano,
             a.cod_moneda
   from lc_ope_efectivos a
  where a.cod_tip_ope_efe in (2, 6)
    --and a.cod_moneda = 'USD'
    and a.cod_persona in (select distinct (gbanc.cod_persona)
                                from ge_bancos gbanc, cc_cta_bancarias b
                               where gbanc.cod_banco = b.cod_banco
                                 and ((b.cod_modalidad = 43 and
                                     pag_gen.fu_obt_cod_entidad not between 1000 and 1999) or
                                     (b.cod_modalidad = 45 and
                                     pag_gen.fu_obt_cod_entidad between 1000 and 1999))
                                 and b.estado = 'N'
                                 and gbanc.estado = 'A')
;

