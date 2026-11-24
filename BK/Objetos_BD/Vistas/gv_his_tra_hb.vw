create or replace force view it.gv_his_tra_hb as
select case
          when co.cod_persona = cd.cod_persona then
            'Transferencia entre Cuentas'
          when co.cod_persona != cd.cod_persona then
             'Transferencia entre Cuentas de Terceros'
       end descripcion_tipo,
       '-'                nro_referencia,
       mo.nro_cuenta      nro_cta_solicitante,
       po.nro_documento   nro_doc_solicitante,
       po.nom_completo    nom_solicitante,
       pd.nro_documento   nro_doc_beneficiario,
       pd.nom_completo    nom_beneficiario,
       md.nro_cuenta      nro_cta_beneficiario,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) cod_swi_pte_beneficiario,
       mo.cod_moneda      cod_moneda,
       mo.monto           monto,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) cod_swi_pte_solicitante,
       to_char(mo.fec_valor,'DD/MM/YYYY')  fec_valor,
       mo.hora            hora,
       null               nro_ref_externa,
       mo.concepto        concepto,
       null               observacion,
       co.cod_persona     cod_per_solicitante,
       cd.cod_persona     cod_per_beneficiario
  from ah_movimientos_his mo,
       ah_movimientos_his md,
       ge_cta_clientes co,
       ge_cta_clientes cd,
       ba_personas po,
       ba_personas pd
 where ((mo.cod_tra_padre in (309, 388)  and
       mo.COD_TRANSACCION = 503) and
       (md.cod_tra_padre in  (309, 388,385)  and
       md.COD_TRANSACCION = 602)
       )
   and mo.FECHA        = md.FECHA
   and mo.HORA         = md.HORA
   and mo.COD_USUARIO  = md.COD_USUARIO
   and co.nro_cuenta   = mo.nro_cuenta(+)
   and co.relacion(+)  = 'P'
   and cd.nro_cuenta   = md.nro_cuenta(+)
   and cd.relacion(+)  = 'P'
      ---------------
   and co.cod_persona  = po.cod_persona
   and cd.cod_persona  = pd.cod_persona
      ---------------
union all
-- movimientos del dia
select case
          when co.cod_persona = cd.cod_persona then
            'Transferencia entre Cuentas'
          when co.cod_persona != cd.cod_persona then
             'Transferencia entre Cuentas de Terceros'
       end descripcion_tipo,
       '-'                nro_referencia,
       mo.nro_cuenta      nro_cta_solicitante,
       po.nro_documento   nro_doc_solicitante,
       po.nom_completo    nom_solicitante,
       pd.nro_documento   nro_doc_beneficiario,
       pd.nom_completo    nom_beneficiario,
       md.nro_cuenta      nro_cta_beneficiario,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) cod_swi_pte_beneficiario,
       mo.cod_moneda      cod_moneda,
       mo.monto           monto,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) cod_swi_pte_solicitante,
       to_char(mo.fec_valor,'DD/MM/YYYY')  fec_valor,
       mo.hora            hora,
       null               nro_ref_externa,
       mo.concepto        concepto,
       null               observacion,
       co.cod_persona     cod_per_solicitante,
       cd.cod_persona     cod_per_beneficiario
  from ge_movimientos mo,
       ge_movimientos md,
       ge_cta_clientes co,
       ge_cta_clientes cd,
       ba_personas po,
       ba_personas pd
 where ((mo.cod_tra_padre in (309, 388) and
       mo.COD_TRANSACCION = 503) and
       (md.cod_tra_padre in  (309, 388,385) and
       md.COD_TRANSACCION = 602))
   and mo.FECHA        = md.FECHA
   and mo.HORA         = md.HORA
   and mo.COD_USUARIO  = md.COD_USUARIO
   and co.nro_cuenta   = mo.nro_cuenta(+)
   and co.relacion(+)  = 'P'
   and cd.nro_cuenta   = md.nro_cuenta(+)
   and cd.relacion(+)  = 'P'
      ---------------
   and co.cod_persona  = po.cod_persona
   and cd.cod_persona  = pd.cod_persona
      ---------------
   and pae_cnf.FU_OBT_EST_MODULO(3) <> 4
union all
-- movimientos nocturnos
select case
          when co.cod_persona = cd.cod_persona then
            'Transferencia entre Cuentas'
          when co.cod_persona != cd.cod_persona then
             'Transferencia entre Cuentas de Terceros'
       end descripcion_tipo,
       '-'                nro_referencia,
       mo.nro_cuenta      nro_cta_solicitante,
       po.nro_documento   nro_doc_solicitante,
       po.nom_completo    nom_solicitante,
       pd.nro_documento   nro_doc_beneficiario,
       pd.nom_completo    nom_beneficiario,
       md.nro_cuenta      nro_cta_beneficiario,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad)  cod_swi_pte_beneficiario,
       mo.cod_moneda      cod_moneda,
       mo.monto           monto,
       pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) cod_swi_pte_solicitante,
       to_char(mo.fec_valor,'DD/MM/YYYY')  fec_valor,
       mo.hora            hora,
       null               nro_ref_externa,
       mo.concepto        concepto,
       null               observacion,
       co.cod_persona     cod_per_solicitante,
       cd.cod_persona     cod_per_beneficiario
  from ge_movimientos_noc mo,
       ge_movimientos_noc md,
       ge_cta_clientes co,
       ge_cta_clientes cd,
       ba_personas po,
       ba_personas pd
 where ((mo.cod_tra_padre in (309, 388) and
       mo.COD_TRANSACCION = 503) and
       (md.cod_tra_padre in (309, 388,385) and
       md.COD_TRANSACCION = 602))
   and mo.FECHA        = md.FECHA
   and mo.HORA         = md.HORA
   and mo.COD_USUARIO  = md.COD_USUARIO
   and co.nro_cuenta   = mo.nro_cuenta(+)
   and co.relacion(+)  = 'P'
   and cd.nro_cuenta   = md.nro_cuenta(+)
   and cd.relacion(+)  = 'P'
      ---------------
   and co.cod_persona  = po.cod_persona
   and cd.cod_persona  = pd.cod_persona
      ---------------
union all
     select 'Transferencia Interbancaria',
            to_char(s.nro_referencia) as nro_referencia,
            s.nro_cta_solicitante,
            s.nro_doc_solicitante,
            s.nom_solicitante,
            s.nro_doc_beneficiario,
            s.nom_beneficiario,
            s.nro_cta_beneficiario,
            s.cod_swi_pte_beneficiario,
            s.cod_moneda,
            s.monto,
            s.cod_swi_pte_solicitante,
            to_char(s.fec_valor, 'DD/MM/YYYY') as fec_valor,
            s.hora,
            s.nro_ref_externa,
            s.concepto,
            s.observacion,
            s.cod_per_solicitante,
            s.cod_per_beneficiario
       from ge_snp_transferencias s
      where s.estado    = 'A' --- autorizado
        and s.situacion = 'L' --Liquidado */
        and s.cod_msj_swift=fug_obt_pardinamico( 'COD_SPI_PCD' )
;

