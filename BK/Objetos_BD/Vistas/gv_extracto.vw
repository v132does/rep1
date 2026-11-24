create or replace force view it.gv_extracto as
select cta.cod_persona,
       cta.fec_extracto,
       cta.nro_cuenta,
       cli.cod_oficina,
       cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(GVD.dir_envio,'.',''),',','') Direccion_retener,--Cuando es tip Envio Retener solo trae la sucursal a Retener
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       case
         when cta.cod_modalidad = 31 and cta.cod_moneda = 'GS' then
          '210500'
         when cta.cod_modalidad = 31 and cta.cod_moneda <> 'GS' then
          '215500'
         when cta.cod_modalidad = 41 and cta.cod_moneda = 'GS' then
          '210100'
         when cta.cod_modalidad = 41 and cta.cod_moneda <> 'GS' then
          '215000'
       end Tipo_Cuenta,
       cta.nro_cuenta Sub_Cuenta,
       cli.cod_extracto,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,

       replace(replace(GVD.dir_envio,'.',''),',','')direccion,
       gvd.piso piso,
       gvd.edificio edificio,
       gvd.departamento departamento,
       gvd.des_ciudad ciudad,

       null direccion_ente,
       null piso_ente,
       null edificio_ente,
       null departamento_ente,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)


  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         gv_dir_envios gvd





 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro != 'C'--INDIVIDUAL
   AND cli.cod_per_empresa IS NULL--se excluye NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'M'
   --Dirección Cliente gen Individual
   and gvd.cod_persona = cta.cod_persona
   and gvd.nro_cuenta = cta.nro_cuenta









union all
--CONSOLIDADO--
--CLIENTES GEN. CONSOLIDADOS (NO NOMINAS)
--PARA LOS EXTRACTOs CONSOLIDADOS----CROGENEXT-14 Sergio Servín 07/08/2014
select distinct
       cta.cod_persona,
       cta.fec_extracto,
       --cta.nro_cuenta,--CROGENEXT-14 Sergio Servín 07/08/2014
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N',cta.fec_extracto)nro_cuenta,
       cli.cod_oficina,
      -- cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto) CUENTA,--CROGENEXT-14 Sergio Servín 07/08/2014
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(GVD.dir_envio,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       'CONS.' Tipo_Cuenta,
       --cta.nro_cuenta Sub_Cuenta,--CROGENEXT-14 Sergio Servín 07/08/2014
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto) sub_cuenta,
       cli.cod_extracto,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       --cli.cod_per_empresa cliente,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,

       --para la impresión txt
       replace(replace(GVD.dir_envio,'.',''),',','')direccion,
       gvd.piso piso,
       gvd.edificio edificio,
       gvd.departamento departamento,
       gvd.des_ciudad ciudad,

       null direccion_ente,
       null piso_ente,
       null edificio_ente,
       null departamento_ente,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)

  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial,
               decode(cod_per_empresa,null,null,'CONS.')cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         gv_dir_envios gvd
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') = 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro = 'C'
   AND cli.cod_per_empresa IS NULL--se excluye NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'M'

    --Dirección Cliente gen CONSOLIDADO
   and gvd.cod_persona = cta.cod_persona
   and gvd.nro_cuenta IS NULL--(solo se toma el definido en dirección de envío)





UNION ALL


--PARA LAS CUENTAS NÓMINAS-- CONSOLIDADAS
select DISTINCT
       cta.cod_persona,
       cta.fec_extracto,
       --cta.nro_cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N',cta.fec_extracto)nro_cuenta,
       cli.cod_oficina,
       --cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto)CuentaS_CONSOLIDADA,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(gvd.direccion||' '||gvd.numero,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       'CONS.' Tipo_Cuenta,
       --cta.nro_cuenta Sub_Cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto),
       cli.cod_extracto,
       --null,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,

       --datos de la empresa
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       ci.descripcion ciudad,
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)



  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         ba_direcciones gvd,
         ba_ciudades ci
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') != 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro = 'C'
   AND cli.cod_per_empresa IS NOT NULL--SOLO NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'M'

    --Dirección Cliente gen CONSOLIDADO - NÓMINAS
   and gvd.cod_persona = cta.Cod_Per_Empresa
   and nvl(gvd.principal,'X') = 'S' --(dirección principal del ente )
   --Ciudad--
   and gvd.cod_ciudad = ci.cod_ciudad(+)
   and gvd.cod_pais = ci.cod_pais(+)




UNION ALL
--PARA LAS CUENTAS NÓMINAS-- INDIVIDUAL
select cta.cod_persona,
       cta.fec_extracto,
       cta.nro_cuenta,
       --FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N')nro_cuenta
       cli.cod_oficina,
       cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(gvd.direccion||' '||gvd.numero,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       case
         when cta.cod_modalidad = 31 and cta.cod_moneda = 'GS' then
          '210500'
         when cta.cod_modalidad = 31 and cta.cod_moneda <> 'GS' then
          '215500'
         when cta.cod_modalidad = 41 and cta.cod_moneda = 'GS' then
          '210100'
         when cta.cod_modalidad = 41 and cta.cod_moneda <> 'GS' then
          '215000'
       end Tipo_Cuenta,
       cta.nro_cuenta Sub_Cuenta,
       --FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S')
       cli.cod_extracto,
       --null,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,


       --datos de la empresa
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       ci.descripcion ciudad,
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)



  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         ba_direcciones gvd,
         ba_ciudades ci
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') != 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro != 'C'
   AND cli.cod_per_empresa IS NOT NULL--SOLO NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'M'

     --Dirección Cliente gen CONSOLIDADO - NÓMINAS
   and gvd.cod_persona = cta.Cod_Per_Empresa
   and nvl(gvd.principal,'X') = 'S' --(dirección principal del ente )

   --Ciudad--
   and gvd.cod_ciudad = ci.cod_ciudad(+)
   and gvd.cod_pais = ci.cod_pais(+)




   union all
-----------------------------------
---     EXTRACTO TRIMESTRAL     ---
-----------------------------------
--INDIVIDUAL--
select cta.cod_persona,
       cta.fec_extracto,
       cta.nro_cuenta,
       cli.cod_oficina,
       cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(GVD.dir_envio,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       case
         when cta.cod_modalidad = 31 and cta.cod_moneda = 'GS' then
          '210500'
         when cta.cod_modalidad = 31 and cta.cod_moneda <> 'GS' then
          '215500'
         when cta.cod_modalidad = 41 and cta.cod_moneda = 'GS' then
          '210100'
         when cta.cod_modalidad = 41 and cta.cod_moneda <> 'GS' then
          '215000'
       end Tipo_Cuenta,
       cta.nro_cuenta Sub_Cuenta,
       cli.cod_extracto,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,

       replace(replace(GVD.dir_envio,'.',''),',','')direccion,
       gvd.piso piso,
       gvd.edificio edificio,
       gvd.departamento departamento,
       gvd.des_ciudad ciudad,

       null direccion_ente,
       null piso_ente,
       null edificio_ente,
       null departamento_ente,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)

  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         gv_dir_envios gvd
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') != 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro != 'C'
   AND cli.cod_per_empresa IS NULL--se excluye ctas NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'T'

--Dirección Cliente gen Individual
   and gvd.cod_persona = cta.cod_persona
   and gvd.nro_cuenta = cta.nro_cuenta




   and cta.fec_extracto IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2))
union all
--CONSOLIDADO--
--PARA LOS EXTRACTOS CONSOLIDADOS----CROGENEXT-14 Sergio Servín 07/08/2014
select distinct
       cta.cod_persona,
       cta.fec_extracto,
       --cta.nro_cuenta,--CROGENEXT-14 Sergio Servín 07/08/2014
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N',cta.fec_extracto)nro_cuenta,
       cli.cod_oficina,
      -- cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto) CUENTA,--CROGENEXT-14 Sergio Servín 07/08/2014
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(GVD.dir_envio,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       'CONS.' Tipo_Cuenta,
       --cta.nro_cuenta Sub_Cuenta,--CROGENEXT-14 Sergio Servín 07/08/2014
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N',cta.fec_extracto) sub_cuenta,
       cli.cod_extracto,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,

       --para la impresión txt
       replace(replace(GVD.dir_envio,'.',''),',','')direccion,
       gvd.piso piso,
       gvd.edificio edificio,
       gvd.departamento departamento,
       gvd.des_ciudad ciudad,

       null direccion_ente,
       null piso_ente,
       null edificio_ente,
       null departamento_ente,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)
  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial,
               decode(cod_per_empresa,null,null,'CONS.')cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
                  gv_dir_envios gvd
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') = 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro = 'C'
   AND cli.cod_per_empresa IS NULL--se excluye ctas NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'T'

    --Dirección Cliente gen CONSOLIDADO
   and gvd.cod_persona = cta.cod_persona
   and gvd.nro_cuenta IS NULL--(solo se toma el definido en dirección de envío)




  and cta.fec_extracto IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2))

union all


-- solo cuentas nóminas-- CONSOLIDADO
select DISTINCT
       cta.cod_persona,
       cta.fec_extracto,
       --cta.nro_cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N',cta.fec_extracto),
       cli.cod_oficina,
      -- cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S',cta.fec_extracto)CuentaS_CONSOLIDADA,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(gvd.direccion||' '||gvd.numero,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       'CONS.' Tipo_Cuenta,
       cta.nro_cuenta Sub_Cuenta,
       cli.cod_extracto,
       --null,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,
       --datos de la empresa
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       ci.descripcion ciudad,
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)

  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         ba_direcciones gvd,
         ba_ciudades ci
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') != 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro = 'C'
   AND cli.cod_per_empresa IS NOT NULL--SOLO NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'T'

    --Dirección Cliente gen CONSOLIDADO - NÓMINAS
   and gvd.cod_persona = cta.Cod_Per_Empresa
   and nvl(gvd.principal,'X') = 'S' --(dirección principal del ente )

   --Ciudad--
   and gvd.cod_ciudad = ci.cod_ciudad(+)
   and gvd.cod_pais = ci.cod_pais(+)



   and cta.fec_extracto IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2))

UNION ALL

--NOMINA TRIMESTRAL - INDIVIDUAL
select
       cta.cod_persona,
       cta.fec_extracto,
       cta.nro_cuenta,
       --FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'N')
       cli.cod_oficina,
       cta.cod_oficina || substr((1000000 + cta.nro_cuenta), 2, 7) Cuenta,
       --FUG_OBT_CTA_EXT_CONSOLIDADO(CTA.COD_PERSONA,'S')CuentaS_CONSOLIDADA,
       replace(replace(cli.nom_cliente,'.',''),',','') Nombre,
       replace(replace(gvd.direccion||' '||gvd.numero,'.',''),',','') Direccion,
       substr(cli.telefono,1,instr(cli.telefono,' ')) Prefijo,
       cli.telefono Telefono,
       cli.cod_oficina Sucursal,
       case
         when cta.cod_modalidad = 31 and cta.cod_moneda = 'GS' then
          '210500'
         when cta.cod_modalidad = 31 and cta.cod_moneda <> 'GS' then
          '215500'
         when cta.cod_modalidad = 41 and cta.cod_moneda = 'GS' then
          '210100'
         when cta.cod_modalidad = 41 and cta.cod_moneda <> 'GS' then
          '215000'
       end Tipo_Cuenta,
       cta.nro_cuenta Sub_Cuenta,
       cli.cod_extracto,
       --null,
       decode(cli.tip_direccion, 'R', 'Retener') Retener,
       funcionario,
       cli.cli_confidencial,
       cli.cod_per_empresa cliente,
       cli.fre_extracto,
       cli.tip_impresion,
       --datos de la empresa
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       ci.descripcion ciudad,
       gvd.direccion||' '||gvd.numero,
       gvd.piso,
       gvd.edificio,
       gvd.departamento,
       bdp.val_parametro tip_gen_extracto --(C = consolidado / I = individual)

  from ge_ext_cli_cuentas cta, ba_per_dat_adicionales bdp, ba_per_dat_adicionales fre, ge_modalidades m,
       (select funcionario, cod_extracto,cod_persona, fec_extracto,nom_cliente,
               direccion, substr(telefono,1,instr(telefono,' ')),telefono, tip_direccion, cli_confidencial, cod_per_empresa,
               fre_extracto, tip_impresion, cod_oficina
         from ge_ext_clientes) cli,
         ba_direcciones gvd,
         ba_ciudades ci
 where cta.cod_persona = cli.cod_persona
   and cta.fre_extracto = cli.fre_extracto
   and cta.fec_extracto = cli.fec_extracto
   and cta.cod_extracto = cli.cod_extracto
   and cta.cod_modalidad = m.cod_modalidad
   and m.cod_modulo not in (6,5) --CROGENEXT-14 Sergio Servín 07/08/2014
   --and fue_per_dat_adicional(cta.COD_PERSONA,'TIP_GEN_EXTRACTOS') != 'C'----CROGENEXT-14 Sergio Servín 07/08/2014
   and bdp.parametro = 'TIP_GEN_EXTRACTOS'
   and bdp.cod_persona = cta.cod_persona
   and bdp.val_parametro != 'C'
   AND cli.cod_per_empresa IS NOT NULL--SOLO NÓMINAS
   and fre.parametro = 'FRE_EXTRACTOS'
   and fre.cod_persona = cta.cod_persona
   and fre.val_parametro = 'T'

    --Dirección Cliente gen CONSOLIDADO - NÓMINAS
   and gvd.cod_persona = cta.Cod_Per_Empresa
   and nvl(gvd.principal,'X') = 'S' --(dirección principal del ente )

   --Ciudad--
   and gvd.cod_ciudad = ci.cod_ciudad(+)
   and gvd.cod_pais = ci.cod_pais(+)



   and cta.fec_extracto IN (pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/03/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/06/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/09/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2),
                            pag_cal.fu_obt_fec_habil(LAST_DAY(TO_DATE('05/12/'||to_char(cta.fec_extracto,'YYYY'),'DD/MM/YYYY')),-1,2))


 order by 1,5
;

