create or replace force view it.gv_tas_per_variables as
select c.cod_oficina,
       cl.cod_persona,
       tf.nro_cuenta,
       c.denominacion denominacion_o_cliente,
       c.cod_moneda,
       FUY_OBT_NOM_USUARIO(cli.cod_usu_oficial) gestor,
       tf.cod_tasa,
       tas.descripcion,
       tf.val_tasa imp_tasa_personaliza,
       tf.val_extension porc_exoneracion,
       tf.fec_vigencia,
       tf.fec_vencimiento
  from it.ge_tas_rangos   tf,
       it.ge_cuentas      c,
       it.ge_cta_clientes cl,
       it.ge_clientes     cli,
       it.ge_tasas        tas
 where tf.nro_cuenta is not null
   and (tf.fec_vencimiento is null or tf.fec_vencimiento >= trunc(sysdate))
   and tf.nro_cuenta = c.nro_cuenta
   and tf.nro_cuenta = cl.nro_cuenta
   and cl.relacion = 'P'
   and cl.cod_persona = cli.cod_persona
   and tf.cod_tasa = tas.cod_tasa

union

select cli.cod_oficina,
       tf.cod_persona,
       null nro_cuenta,
       p.nom_completo denominacion_o_cliente,
       null cod_moneda,
       FUY_OBT_NOM_USUARIO(cli.cod_usu_oficial) gestor,
       tf.cod_tasa,
       tas.descripcion,
       tf.val_tasa imp_tasa_personaliza,
       tf.val_extension porc_exoneracion,
       tf.fec_vigencia,
       tf.fec_vencimiento
  from it.ge_tas_rangos tf,
       it.ba_personas   p,
       it.ge_clientes   cli,
       it.ge_tasas      tas
 where tf.cod_persona is not null
   and (tf.fec_vencimiento is null or tf.fec_vencimiento >= trunc(sysdate))
   and tf.cod_persona = p.cod_persona
   and tf.cod_persona = cli.cod_persona
   and tf.cod_tasa = tas.cod_tasa;

