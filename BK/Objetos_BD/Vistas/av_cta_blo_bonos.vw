CREATE OR REPLACE FORCE VIEW IT.AV_CTA_BLO_BONOS AS
SELECT fue_obt_titulo(fue_obt_nom_persona(b.cod_persona)) nom_completo,
       case
          when instr(fue_obt_titulo(fue_obt_nro_doc_persona(fug_obt_cli_principal(a.nro_cuenta))),'-') > 1 then null
          else fue_obt_titulo(fue_obt_nro_doc_persona(fug_obt_cli_principal(a.nro_cuenta)))
       end nro_documento,
       case
          when instr(fue_obt_titulo(fue_obt_nro_doc_persona(fug_obt_cli_principal(a.nro_cuenta))),'-') > 1 then
               fue_obt_titulo(fue_obt_nro_doc_persona(fug_obt_cli_principal(a.nro_cuenta)))
          else null
       end ruc,
       (select max(nro_titulo) from ah_titulos a where  a.serie = t.serie) + rownum nro_operacion,
       fue_obt_titulo(fue_obt_nom_persona(b.cod_persona)) comitente,
       null cod_bolsa,
       b.cod_persona,
       FUG_OBT_NOM_ENTIDAD emisor,
       t.serie serie,
       t.fec_apertura fec_ini_serie,
       t.fec_vencimiento fec_vto_serie,
       fug_obt_val_tasa(3,
                        36,
                        null,
                        null,
                        a.cod_moneda,
                        null,
                        null,
                        fug_obt_parentes(e.cod_ente,'COD_TAS_BONOS'),
                        null,
                        null) val_tasa,
       c.fec_inicio fec_venta,
       null can_bonos,
       null mto_corte,
       c.monto mto_total,
       0 dia_transcurridos,
       0 int_acumulado,
       c.monto mto_desembolsar,
       'PRIMARIO' mercado,
       fue_obt_des_moneda(a.cod_moneda) moneda,
       0 mto_interes,
       'NUEVO' estado,
       c.nro_cuenta nro_cta_credito,
       'B' tip_colocacion,
       0 mto_plu_precio,
       0 mto_min_precio
  FROM ge_bloqueos c, ge_cuentas a, ge_cta_clientes b,
       ( SELECT cod_ente FROM ge_entes WHERE tipo = 'BO') e,
       ( select ah.serie, ah.nro_titulo, ah.fec_apertura, ah.fec_vencimiento
         from   ah_titulos ah
         where  ah.serie = (select max(ti.serie)
                            from   ah_titulos ti)
         and    ah.nro_titulo = (select max(tu.nro_titulo)
                                 from   ah_titulos tu
                                 where  tu.serie = (select max(tu.serie)
                                                    from   ah_titulos tu
                                                    where  tu.serie = (select max(ti.serie)
                                                    from   ah_titulos ti)))) t
 WHERE c.nro_cuenta = a.nro_cuenta
   AND c.nro_cuenta = b.nro_cuenta
   AND b.cod_persona = fug_obt_cli_principal(a.nro_cuenta)
   AND c.cod_causa = fug_obt_parentes(e.cod_ente,'COD_CAU_BLO_CUENTA');

