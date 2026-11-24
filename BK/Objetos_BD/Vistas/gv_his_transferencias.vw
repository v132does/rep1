create or replace force view it.gv_his_transferencias as
select origen.COD_MONEDA transactionCurrency,
       origen.MONTO amount,
       origen.fec_insercion transactionDate,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') transactionhour,
       'T. enviada a ' || initcap(fue_obt_nom_persona(cli_des.cod_persona)) description,
       decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') statusDescription,
       'Transfer' transactionType,
       origen.NRO_DOCUMENTO transactionId,
       origen.fec_modificacion postedDate,
       fug_obt_nom_entidad fromBankName,
       fug_obt_nom_cuenta(origen.nro_cuenta) fromAccountName,
       origen.NRO_CUENTA fromAccountNumber,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) toAccountName,
       destino.NRO_CUENTA toAccountNumber,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad oriModalidad,
       destino.cod_modalidad desModalidad,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_origen,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_destino,
       origen.cod_tra_padre ori_tra_padre,
       ------------------------------------
       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario
------------------------------------
  from ah_movimientos_his origen,
       ah_movimientos_his destino,
       ge_cta_clientes    cli_ori,
       ge_cta_clientes    cli_des,
       ba_personas        per_ori,
       ba_personas        per_des
 where ((origen.cod_tra_padre in (309, 388) and
       origen.COD_TRANSACCION = 503) and
       (origen.cod_tra_padre in (309, 388,385,303)  and
       destino.COD_TRANSACCION = 602))
   and origen.FECHA = destino.FECHA
   and origen.HORA = destino.HORA
   and origen.COD_USUARIO = destino.COD_USUARIO
   and origen.nro_cuenta = cli_ori.nro_cuenta(+)
   and cli_ori.relacion(+) = 'P'
   and destino.nro_cuenta = cli_des.nro_cuenta(+)
   and cli_des.relacion(+) = 'P'
      ---------------
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
      ---------------
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
  AND trunc(origen.fec_insercion) between trunc(last_day(add_months(sysdate,-2))-1, 'mm') and trunc(sysdate)
union
/*Transferencias enviadas/recibidas  en la fecha*/
select origen.COD_MONEDA transactionCurrency,
       origen.MONTO amount,
       origen.fec_insercion transactionDate,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') transactionhour,
       'T. enviada a ' || initcap(fue_obt_nom_persona(cli_des.cod_persona)) description,
       decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') statusDescription,
       'Transfer' transactionType,
       origen.NRO_DOCUMENTO transactionId,
       origen.fec_modificacion postedDate,
       fug_obt_nom_entidad fromBankName,
       fug_obt_nom_cuenta(origen.nro_cuenta) fromAccountName,
       origen.NRO_CUENTA fromAccountNumber,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) toAccountName,
       destino.NRO_CUENTA toAccountNumber,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad oriModalidad,
       destino.cod_modalidad desModalidad,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_origen,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_destino,
       origen.cod_tra_padre ori_tra_padre,
       ------------------------------------
       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario
------------------------------------
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
      ---------------
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
      ---------------
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
      ----
   and pae_cnf.FU_OBT_EST_MODULO(3) <> 4
union
/*Tranferencias nocturnas durante el cierre*/
select origen.COD_MONEDA transactionCurrency,
       origen.MONTO amount,
       origen.fec_insercion transactionDate,
       origen.fec_insercion scheduledDate,
       to_char(origen.fec_insercion, 'hh24:mi:ss') transactionhour,
       'T. enviada a ' || initcap(fue_obt_nom_persona(cli_des.cod_persona)) description,
       decode(origen.ESTADO,
              'N',
              decode(origen.REVERSADO, 'N', 'Realizada', 'S', 'REJECTED'),
              'PENDING') statusDescription,
       'Transfer' transactionType,
       origen.NRO_DOCUMENTO transactionId,
       origen.fec_modificacion postedDate,
       fug_obt_nom_entidad fromBankName,
       fug_obt_nom_cuenta(origen.nro_cuenta) fromAccountName,
       origen.NRO_CUENTA fromAccountNumber,
       fug_obt_nom_cuenta(origen.nro_cuenta) debitAccountHolder,
       fug_obt_nom_entidad bankName,
       fug_obt_nom_cuenta(destino.nro_cuenta) toAccountName,
       destino.NRO_CUENTA toAccountNumber,
       fug_obt_nom_cuenta(destino.nro_cuenta) creditAccountHolder,
       'Transferencia' category,
       origen.cod_modalidad oriModalidad,
       destino.cod_modalidad desModalidad,
       origen.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(fue_obt_nom_persona(cli_ori.cod_persona)) nom_per_origen,
       initcap(fue_obt_nom_persona(cli_des.cod_persona)) nom_per_destino,
       origen.cod_tra_padre ori_tra_padre,
       ------------------------------------
       nvl(per_ori.cod_tip_documento, 7) tip_doc_sol,
       per_ori.nro_documento doc_solicitante,
       nvl(per_des.cod_tip_documento, 7) tip_doc_ben,
       per_des.nro_documento doc_beneficiario
------------------------------------
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
      ---------------
   and cli_ori.cod_persona = per_ori.cod_persona
   and cli_des.cod_persona = per_des.cod_persona
      ---------------
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
/*SIPAP*/
/*Enviados-historicos*/
select transf.cod_moneda transactionCurrency,
       transf.MONTO amount,
       transf.fec_insercion transactionDate,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') transactionhour,
       case
         when transf.fec_recepcion is not null then
          'T. recibida de ' || initcap(transf.nom_solicitante)
         else
          'T. enviada a ' || initcap(transf.nom_beneficiario)
       end description, --fug_obt_des_transaccion(4, 455, mov.cod_tra_padre),
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
       end statusDescription,
       'Transfer' transactionType,
       transf.nro_referencia transactionId,
       transf.fec_modificacion postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) fromBankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) fromAccountName,
       transf.nro_cta_solicitante fromAccountNumber,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) toAccountName,
       transf.nro_cta_beneficiario toAccountNumber,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end oriModalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_origen,
       initcap(transf.nom_beneficiario) nom_per_destino,
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
    AND trunc(mov.fec_insercion) between trunc(last_day(add_months(sysdate,-2))-1, 'mm') and trunc(sysdate)
UNION
/*Enviados-en la fecha*/
select transf.cod_moneda transactionCurrency,
       transf.MONTO amount,
       transf.fec_insercion transactionDate,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') transactionhour,
       case
         when transf.fec_recepcion is not null then
          'T. recibida de ' || initcap(transf.nom_solicitante)
         else
          'T. enviada a ' || initcap(transf.nom_beneficiario)
       end description,
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
       end statusDescription,
       'Transfer' transactionType,
       transf.nro_referencia transactionId,
       transf.fec_modificacion postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) fromBankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) fromAccountName,
       transf.nro_cta_solicitante fromAccountNumber,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) toAccountName,
       transf.nro_cta_beneficiario toAccountNumber,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end oriModalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_origen,
       initcap(transf.nom_beneficiario) nom_per_destino,
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
   and pae_cnf.FU_OBT_EST_MODULO(3) <> 4
union
select transf.cod_moneda transactionCurrency,
       transf.MONTO amount,
       transf.fec_insercion transactionDate,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') transactionhour,
       case
         when transf.fec_recepcion is not null then
          'T. recibida de ' || initcap(transf.nom_solicitante)
         else
          'T. enviada a ' || initcap(transf.nom_beneficiario)
       end description,
       case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion in ('L','R') and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end statusDescription,
       'Transfer' transactionType,
       transf.nro_referencia transactionId,
       transf.fec_modificacion postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) fromBankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) fromAccountName,
       transf.nro_cta_solicitante fromAccountNumber,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) toAccountName,
       transf.nro_cta_beneficiario toAccountNumber,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end oriModalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_origen,
       initcap(transf.nom_beneficiario) nom_per_destino,
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
select transf.cod_moneda transactionCurrency,
       transf.MONTO amount,
       transf.fec_insercion transactionDate,
       transf.fec_insercion scheduledDate,
       to_char(transf.fec_insercion, 'hh24:mi:ss') transactionhour,
       case
         when transf.fec_recepcion is not null then
          'T. recibida de ' || initcap(transf.nom_solicitante)
         else
          'T. enviada a ' || initcap(transf.nom_beneficiario)
       end description,
       case
         when transf.situacion = 'L' and transf.estado = 'A' and
              transf.fec_recepcion is null then
          'SENT'
         when transf.situacion in ('L','R') and transf.estado = 'A' and
              transf.fec_recepcion is not null then
          'RECEIVED'
         when transf.situacion in ('P', 'V') and transf.estado in ('A', 'S') then
          'PENDING'
         when transf.estado = 'S' then
          'PENDING'
         when transf.estado = 'C' or transf.situacion = 'C' or
              (transf.situacion in ('L','I') and transf.estado = 'R') then
          'REJECTED'
       end statusDescription,
       'Transfer' transactionType,
       transf.nro_referencia transactionId,
       transf.fec_modificacion postedDate,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_solicitante) fromBankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_solicitante),
           transf.nom_solicitante) fromAccountName,
       transf.nro_cta_solicitante fromAccountNumber,
       transf.nom_solicitante debitAccountHolder,
       it.fug_obt_nom_snp_participante(transf.cod_swi_pte_beneficiario) bankName,
       nvl(fug_obt_nom_cuenta(transf.nro_cta_beneficiario),
           transf.nom_beneficiario) toAccountName,
       transf.nro_cta_beneficiario toAccountNumber,
       transf.nom_beneficiario creditAccountHolder,
       'Transferencia' category,
       case
         when transf.fec_recepcion is null then
          c.cod_modalidad
       end oriModalidad,
       case
         when transf.fec_recepcion is not null then
          c.cod_modalidad
       end desModalidad,
       transf.concepto concepto,
       nvl(cli_ori.cod_persona, 0) idPerOrigen,
       nvl(cli_des.cod_persona, 0) idPerDestino,
       initcap(transf.nom_solicitante) nom_per_origen,
       initcap(transf.nom_beneficiario) nom_per_destino,
       pas_snp.fu_obt_cod_tra_padre,
       nvl(transf.cod_tip_doc_solicitante, 7) tip_doc_sol,
       transf.nro_doc_solicitante doc_solicitante,
       nvl(transf.cod_tip_doc_beneficiario, 7) tip_doc_ben,
       transf.nro_doc_beneficiario doc_beneficiario
  from ge_snp_transferencias transf,
       ge_cuentas            c,
       ge_cta_clientes       cli_ori,
       ge_cta_clientes       cli_des
 where /*transf.fecha is null
   and transf.hora is null
   and transf.cod_usuario is null
   and */(c.nro_cuenta = transf.nro_cta_beneficiario or
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
;
