create or replace view it.gv_mov_tra_cambios as
select gv_movimientos.cod_ofi_origen,
       ba_oficinas.descripcion oficina,
       gv_movimientos.cod_moneda,
       ba_monedas.descripcion moneda,
       gv_movimientos.cod_mod_padre,
       gv_movimientos.cod_mad_padre,
       initcap(ge_modalidades.descripcion) || ' de Divisas' modalidad,
       gv_movimientos.nro_documento,
       initcap(lc_tip_operaciones.descripcion) tip_operacion,
       case
         when gv_movimientos.cod_usuario like 'CEXCHANGE%' or
              gv_movimientos.cod_usuario like 'MVM_%' then
          to_char(gv_movimientos.fec_insercion, 'HH24:MI:SS')
         else
          gv_movimientos.hora
       end as hora,
       case
         when gv_movimientos.cod_usuario like 'CEXCHANGE%' or
              gv_movimientos.cod_usuario like 'MVM_%' then
          trunc(gv_movimientos.fec_insercion)
         else
          gv_movimientos.fecha
       end as fecha,
       gv_movimientos.cod_usuario,
       'nombre' nombre,
       gv_movimientos.monto cantidad,
       gv_movimientos.cotizacion,
       gv_movimientos.mto_equ_local monto,
       gv_movimientos.cod_oficina,
       gv_movimientos.nro_caja,
       gv_movimientos.nro_secuencia,
       gv_movimientos.cod_banco,
       decode(gv_movimientos.nro_secuencia,
              1,
              gv_movimientos.nro_documento3,
              0) nro_cheque,
       ge_bancos.descripcion banco,
       decode(cliente.cod_persona,
              null,
              fue_obt_tip_doc_abreviatura(cod_tip_documento),
              fue_obt_tip_doc_abreviatura(fue_obt_doc_principal(cliente.cod_persona))) tip_documento,
       decode(cliente.cod_persona,
              null,
              cliente.referencia,
              fue_obt_nro_doc_persona(cliente.cod_persona)) nro_doc_cliente,
       nvl(cliente.cod_persona,
           (fue_obt_cod_persona_doc(cliente.cod_tip_documento,
                                    cliente.referencia))) cod_persona,
       decode(cliente.cod_persona,
              null,
              cliente.concepto,
              fue_obt_nom_persona(cliente.cod_persona)) nom_cliente,
       cliente.concepto,
       pag_gen.fu_obt_cotizacion('USD', gv_movimientos.fecha) val_conversion
  from ba_monedas,
       ba_oficinas,
       ge_modalidades,
       lc_tip_operaciones,
      (select m.fecha,
       m.hora,
       m.cod_usuario,
       m.nro_documento,
       nvl(to_number(m.nro_documento2), m.cod_persona) as cod_persona,
       m.concepto,
       m.referencia,
       o.cod_tip_documento
       from gv_movimientos m
         outer apply (
            select * from ba_cli_ocasionales o 
             where o.nro_documento = m.referencia
             fetch first 1 row only -- Aquí controlas que solo traiga uno
         ) o
       where m.cod_transaccion = 760 and m.cod_mod_padre = 7
        union
        select m.fecha,
               m.hora,
               m.cod_usuario,
               m.nro_documento,
               nvl(to_number(m.cod_persona), to_number(c.cod_persona)),
               m.concepto,
               m.referencia,
               null
          from gv_movimientos m
          left join ge_cta_clientes c
            on m.nro_cuenta = c.nro_cuenta
           and c.relacion = 'P'
         where m.cod_transaccion in (503, 602)
           and m.cod_moneda <> 'GS'
           and ((m.cod_usuario between 'CEXCHANGE' and 'CEXCHANGEZZ') or
               (m.cod_usuario between 'MVM_' and 'MVM_ZZ'))) cliente,
       gv_movimientos,
       ge_bancos
 where ba_oficinas.cod_oficina = gv_movimientos.cod_ofi_origen
   and ba_monedas.cod_moneda = gv_movimientos.cod_moneda
   and ge_modalidades.cod_modulo = gv_movimientos.cod_mod_padre
   and ge_modalidades.cod_modalidad = gv_movimientos.cod_mad_padre
   and cliente.fecha(+) = gv_movimientos.fecha
   and cliente.hora(+) = gv_movimientos.hora
   and cliente.cod_usuario(+) = gv_movimientos.cod_usuario
   and cliente.nro_documento(+) = gv_movimientos.nro_documento
   and gv_movimientos.cod_tip_ope_cambio =
       lc_tip_operaciones.cod_tip_operacion
   and gv_movimientos.reversado = 'N'
   and gv_movimientos.estado = 'N'
   and gv_movimientos.cod_mod_padre = 7
   and gv_movimientos.cod_moneda <> 'GS'
   and gv_movimientos.cod_mad_padre in (71, 72, 73, 74)
   and gv_movimientos.cod_banco = ge_bancos.cod_banco(+)
 order by gv_movimientos.fecha,
          gv_movimientos.nro_documento,
          gv_movimientos.hora
