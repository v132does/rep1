create or replace force view it.gv_his_tra_cli as
select origen.COD_MONEDA moneda,
       origen.MONTO monto,
       origen.fec_modificacion fecha,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') hora,
             decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') estado,
       'Transfer' tipo,
       origen.NRO_DOCUMENTO transactionId,
       origen.fec_insercion postedDate,
       fug_obt_nom_entidad entidad,
       fug_obt_nom_cuenta(origen.nro_cuenta) cta_ori,
       origen.NRO_CUENTA nro_cta_ori,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) cta_des,
       destino.NRO_CUENTA nro_cta_des,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad cod_modalidad,
       destino.cod_modalidad desModalidad,
       origen.cod_modulo ,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_ori,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_des,
       origen.cod_tra_padre ori_tra_padre,
       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario
  from ah_movimientos_his origen,
       ah_movimientos_his destino,
       ge_cta_clientes    cli_ori,
       ge_cta_clientes    cli_des,
       ba_personas        per_ori,
       ba_personas        per_des
 where ((origen.cod_tra_padre in (309, 388) and
       origen.COD_TRANSACCION = 503) and
       (origen.cod_tra_padre in (309, 388,385) and
       destino.COD_TRANSACCION = 602))
   and origen.FECHA = destino.FECHA
   and origen.HORA = destino.HORA
   and origen.COD_USUARIO = destino.COD_USUARIO
   and origen.nro_cuenta = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and destino.nro_cuenta = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))
union

select origen.COD_MONEDA moneda,
       origen.MONTO monto,
       origen.fec_modificacion fecha,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') hora,
              decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') estado,
       'Transfer' tipo,
       origen.NRO_DOCUMENTO transactionId,
       origen.FEC_INSERCION postedDate,
       fug_obt_nom_entidad entidad,
       fug_obt_nom_cuenta(origen.nro_cuenta) cta_ori,
       origen.NRO_CUENTA nro_cta_ori,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) cta_des,
       destino.NRO_CUENTA nro_cta_des,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad cod_modalidad,
       destino.cod_modalidad desModalidad,
       origen.cod_modulo oriModulo,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_ori,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_des,
       origen.cod_tra_padre ori_tra_padre,
       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario

  from ge_movimientos  origen,
       ge_movimientos  destino,
       ge_cta_clientes cli_ori,
       ge_cta_clientes cli_des,
       ba_personas     per_ori,
       ba_personas     per_des
 where ((origen.cod_tra_padre in (309, 388) and
       origen.COD_TRANSACCION = 503) and
       (destino.COD_TRA_PADRE in (309, 388,385) and
       destino.COD_TRANSACCION = 602))
   and origen.FECHA = destino.FECHA
   and origen.HORA = destino.HORA
   and origen.COD_USUARIO = destino.COD_USUARIO
   and origen.nro_cuenta = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and destino.nro_cuenta = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))
union

select origen.COD_MONEDA moneda,
       origen.MONTO monto,
       origen.fec_modificacion fecha,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') hora,
       decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') estado,
       'Transfer' tipo,
       origen.NRO_DOCUMENTO transactionId,
       origen.FEC_INSERCION postedDate,
       fug_obt_nom_entidad entidad,
       fug_obt_nom_cuenta(origen.nro_cuenta) cta_ori,
       origen.NRO_CUENTA nro_cta_ori,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) cta_des,
       destino.NRO_CUENTA nro_cta_des,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad cod_modalidad,
       destino.cod_modalidad desModalidad,
       origen.cod_modulo oriModulo,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_ori,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_des,
       origen.cod_tra_padre ori_tra_padre,

       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario

  from ge_movimientos_noc origen,
       ge_movimientos_noc destino,
       ge_cta_clientes    cli_ori,
       ge_cta_clientes    cli_des,
       ba_personas        per_ori,
       ba_personas        per_des
 where ((origen.cod_tra_padre in (309, 388) and
       origen.COD_TRANSACCION = 503) and
       (destino.COD_TRA_PADRE in (309, 388,385) and
       destino.COD_TRANSACCION = 602))
   and origen.FECHA = destino.FECHA
   and origen.HORA = destino.HORA
   and origen.COD_USUARIO = destino.COD_USUARIO
   and origen.nro_cuenta = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and destino.nro_cuenta = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))

union all

select transf.cod_moneda moneda,
       transf.MONTO monto,
       transf.fec_modificacion fecha,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') hora,
       case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end estado,
       'Transfer' tipo,
       transf.nro_referencia transactionId,
       transf.FEC_INSERCION postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) entidad,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) cta_ori,
       transf.nro_cta_solicitante nro_cta_ori,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) cta_des,
       transf.nro_cta_beneficiario nro_cta_des,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end cod_modalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
          c.cod_modulo ,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_ori,
       initcap(transf.nom_beneficiario) nom_per_des,
       mov.cod_tra_padre,
       nvl(transf.cod_tip_doc_solicitante, 7) tip_doc_sol,
       transf.nro_doc_solicitante doc_solicitante,
       nvl(transf.cod_tip_doc_beneficiario, 7) tip_doc_ben,
       transf.nro_doc_beneficiario doc_beneficiario
  from ge_snp_transferencias transf,
       ah_movimientos_his    mov,
       ge_transacciones      tra,
       ge_cuentas            c,
       ge_cta_clientes       cli_ori,
       ge_cta_clientes       cli_des
 where (transf.nro_cta_solicitante = mov.nro_cuenta or
       transf.nro_cta_beneficiario = mov.nro_cuenta)
   and transf.hora = mov.hora
   and transf.fecha = mov.fecha
   and transf.cod_usuario = mov.cod_usuario
   and mov.cod_tra_padre = tra.cod_transaccion
   and mov.cod_mod_padre = tra.cod_modulo
   and mov.cod_mad_padre = tra.cod_modalidad
   and (c.nro_cuenta = transf.nro_cta_beneficiario or
       c.nro_cuenta = transf.nro_cta_solicitante)
   and transf.nro_cta_solicitante = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and transf.nro_cta_beneficiario = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))
UNION

select transf.cod_moneda moneda,
       transf.MONTO monto,
       transf.fec_modificacion fecha,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') hora,
              case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end estado,
       'Transfer' tipo,
       transf.nro_referencia transactionId,
       transf.FEC_INSERCION postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) entidad,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) cta_ori,
       transf.nro_cta_solicitante nro_cta_ori,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) cta_des,
       transf.nro_cta_beneficiario nro_cta_des,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end cod_modalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       c.cod_modulo,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_ori,
       initcap(transf.nom_beneficiario) nom_per_des,
       mov.cod_tra_padre,
       nvl(transf.cod_tip_doc_solicitante, 7) tip_doc_sol,
       transf.nro_doc_solicitante doc_solicitante,
       nvl(transf.cod_tip_doc_beneficiario, 7) tip_doc_ben,
       transf.nro_doc_beneficiario doc_beneficiario
  from ge_snp_transferencias transf,
       ge_movimientos        mov,
       ge_transacciones      tra,
       ge_cuentas            c,
       ge_cta_clientes       cli_ori,
       ge_cta_clientes       cli_des
 where (transf.nro_cta_solicitante = mov.nro_cuenta or
       transf.nro_cta_beneficiario = mov.nro_cuenta)
   and transf.hora = mov.hora
   and transf.fecha = mov.fecha
   and transf.cod_usuario = mov.cod_usuario
   and mov.cod_tra_padre = tra.cod_transaccion
   and mov.cod_mod_padre = tra.cod_modulo
   and mov.cod_mad_padre = tra.cod_modalidad
   and (c.nro_cuenta = transf.nro_cta_beneficiario or
       c.nro_cuenta = transf.nro_cta_solicitante)
   and transf.nro_cta_solicitante = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and transf.nro_cta_beneficiario = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))
union
select transf.cod_moneda moneda,
       transf.MONTO monto,
       transf.fec_modificacion fecha,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') hora,
       case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end estado,
       'Transfer' tipo,
       transf.nro_referencia transactionId,
       transf.FEC_INSERCION postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) entidad,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) cta_ori,
       transf.nro_cta_solicitante nro_cta_ori,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) cta_des,
       transf.nro_cta_beneficiario nro_cta_des,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end cod_modalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       c.cod_modulo,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_ori,
       initcap(transf.nom_beneficiario) nom_per_des,
       mov.cod_tra_padre,
       nvl(transf.cod_tip_doc_solicitante, 7) tip_doc_sol,
       transf.nro_doc_solicitante doc_solicitante,
       nvl(transf.cod_tip_doc_beneficiario, 7) tip_doc_ben,
       transf.nro_doc_beneficiario doc_beneficiario
  from ge_snp_transferencias transf,
       ge_movimientos_noc    mov,
       ge_transacciones      tra,
       ge_cuentas            c,
       ge_cta_clientes       cli_ori,
       ge_cta_clientes       cli_des
 where (transf.nro_cta_solicitante = mov.nro_cuenta or
       transf.nro_cta_beneficiario = mov.nro_cuenta)
   and transf.hora = mov.hora
   and transf.fecha = mov.fecha
   and transf.cod_usuario = mov.cod_usuario
   and mov.cod_tra_padre = tra.cod_transaccion
   and mov.cod_mod_padre = tra.cod_modulo
   and mov.cod_mad_padre = tra.cod_modalidad
   and (c.nro_cuenta = transf.nro_cta_beneficiario or
       c.nro_cuenta = transf.nro_cta_solicitante)
   and transf.nro_cta_solicitante = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and transf.nro_cta_beneficiario = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta))
union
select transf.cod_moneda moneda,
       transf.MONTO monto,
       transf.fec_modificacion fecha,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') hora,
       case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end estado,
       'Transfer' tipo,
       transf.nro_referencia transactionId,
       transf.FEC_INSERCION postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) entidad,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) cta_ori,
       transf.nro_cta_solicitante nro_cta_ori,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) cta_des,
       transf.nro_cta_beneficiario nro_cta_des,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end cod_modalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       c.cod_modulo,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_ori,
       initcap(transf.nom_beneficiario) nom_per_des,
       pas_snp.fu_obt_cod_tra_padre,
       nvl(transf.cod_tip_doc_solicitante, 7) tip_doc_sol,
       transf.nro_doc_solicitante doc_solicitante,
       nvl(transf.cod_tip_doc_beneficiario, 7) tip_doc_ben,
       transf.nro_doc_beneficiario doc_beneficiario
  from ge_snp_transferencias transf,
       ge_cuentas            c,
       ge_cta_clientes       cli_ori,
       ge_cta_clientes       cli_des
 where transf.fecha is null
   and transf.hora is null
   and transf.cod_usuario is null
   and (c.nro_cuenta = transf.nro_cta_beneficiario or
       c.nro_cuenta = transf.nro_cta_solicitante)
   and transf.nro_cta_solicitante = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and transf.nro_cta_beneficiario = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_ori.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_ori.nro_cuenta))
   and (exists (select 1
                  from ah_cta_vistas a
                 where a.nro_cuenta = cli_des.nro_cuenta
                   and a.estado != 'C') or not exists
        (select 1
           from ah_cta_vistas a
          where a.nro_cuenta = cli_des.nro_cuenta));

