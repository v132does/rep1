create or replace force view it.gv_cie_previo as
select '*REVERSARA*:10-REV.AUT.OPE.PENDIENTES (PRG_REV_AUTOMATICA)' tipo,UPPER(a.estado||'-'||c.significado) estado,a.fecha,a.hora,
a.cod_usuario cod_usuario,
d.nombre usuario,
a.cod_ofi_origen||'-'||y.descripcion ofi_ori, a.nro_caja caja,
a.cod_mod_padre||'-'||a.cod_mad_padre||'-'||a.cod_tra_padre||'-'||x.descripcion tran, a.cod_oficina ofi,
'CTA/CONCEPTO: '||NVL(a.nro_cuenta,A.CONCEPTO) referencia,a.cod_moneda,a.monto,a.concepto, 'GE_MOVIMIENTOS' tabla, a.nro_documento
     from ge_movimientos a, ge_calendarios b, ba_cod_referencias c, ba_usuarios d, ge_transacciones x, ba_oficinas y
    where a.fecha = b.fec_actual
      and b.cod_modulo = 1
      and a.estado in ('J','P','X')
      and a.reversado ='N'
      and c.dominio = 'EST_MOVIMIENTO'
      and c.val_minimo = a.estado
      and d.cod_usuario = a.cod_usuario
      and x.cod_transaccion = a.cod_tra_padre
      and x.cod_modulo = a.cod_mod_padre
      and x.cod_modalidad = a.cod_mad_padre
      and y.cod_oficina = a.cod_ofi_origen
      and fub_con_mon_a_moneda(a.cod_moneda,'GS', nvl(a.monto,0)) = (select max(fub_con_mon_a_moneda(g.cod_moneda,'GS',nvl(g.monto,0)))
                       from ge_movimientos g
                       where g.fecha = a.fecha
                         and g.hora = a.hora
                         and g.cod_usuario = a.cod_usuario)
      and not exists (select 0 from ge_aut_pedidos b
                       where b.cod_usuario = a.cod_usuario
                         and b.fecha = a.fecha
                         and b.hora = a.hora
                         and b.respuesta = 'P'
                         and b.estado = 'S')
      and not exists (select 0 from ge_mov_autorizaciones m
                       where m.cod_usuario = a.cod_usuario
                         and m.fecha = a.fecha
                         and m.hora = a. hora
                         and m.estado = 'S' )-- solicitado
union
select '*REVERSARA*:25-AUT. PENDIENTES. (PRG_RCH_AUTORIZACIONES)' tipo, 'P'||'-'||'PENDIENTE DE RESPUESTA' estado,
a.fecha,a.hora,
a.cod_usuario usuario, d.nombre usuario,
null ofi_ori, null caja,
'SOLICITUD DE AUTORIZACION (Cotiz,Monto,Sobreg,otros)' tran, null ofi,
'AUTORIZADOR: '||A.COD_USU_AUTORIZADOR nro_cuenta, 'USD' cod_moneda, a.mto_mon_fuerte monto, a.mensaje concepto,
'GE_AUT_PEDIDOS' tabla, null nro_documento
from ge_aut_pedidos a, ba_usuarios d
where a.respuesta = 'P'
  and a.estado = 'S'
  and a.tip_autorizacion = 'T'
  and d.cod_usuario = a.cod_usuario
union
select distinct '*REVERSARA*:25-AUT. PENDIENTES. (PRG_RCH_AUTORIZACIONES)' tipo, 'P'||'-'||'PENDIENTE DE RESPUESTA' estado,
a.fecha,a.hora,
a.cod_usuario cod_usuario, d.nombre usuario,
null ofi_ori, null caja,
'SOLICITUD DE AUTORIZACION (Cotiz,Monto,Sobreg,otros)' tran, null ofi,
'AUTORIZADOR: '||A.COD_USU_AUTORIZADOR nro_cuenta, 'USD' cod_moneda, a.mto_mon_fuerte monto, a.mensaje concepto,
'GE_AUT_PEDIDOS' tabla, null nro_documento
from ge_aut_pedidos a, ba_usuarios d
where a.respuesta = 'P'
  and a.estado = 'S'
  and a.tip_autorizacion <> 'T'
  and d.cod_usuario = a.cod_usuario
union
select '*REVERSARA*:26-CAN.AUT.CIRCUITOS (PAW_CIR.PR_CAN_AUT_CIRCUITO)' tipo, 'P'||'-'||'PENDIENTE DE APROBACION' estado,
ci.fec_inicio fecha,to_char(ci.fec_insercion,'hh24:mi:ss') hora,
ci.usu_insercion cod_usuario, d.nombre usuario,
d.cod_oficina||'-'||y.descripcion ofi_ori, null caja,
t.cod_tip_circuito||'-'||c.descripcion||' (WORKFLOW)' tran, null ofi,
' CTA: '||K.NRO_CUENTA referencia, 'USD' cod_moneda, k.mto_mon_fuerte monto, ct.descripcion||'-'||ct.comentario||'-'||'CIRCUITO: '||CI.COD_CIRCUITO|| concepto,
'WF_CIRCUITOS' tabla, k.nro_documento
from wf_tip_cir_tareas t, wf_tip_circuitos c, wf_circuitos ci,
wf_cir_tareas ct, ba_usuarios d, ba_oficinas y, ge_mov_autorizaciones k
where ci.estado = 'E'--Estado en ejecucin
  and ci.cod_circuito = ct.cod_circuito
  and ci.cod_tar_actual = ct.cod_tarea
  and ci.cod_tip_circuito = ct.cod_tip_circuito
  and ct.cod_tip_circuito = t.cod_tip_circuito
  and ct.cod_tip_tarea = t.cod_tip_tarea
  and t.act_automatica = 'S'
  and t.cod_tip_circuito = c.cod_tip_circuito
  and d.cod_usuario = ci.usu_insercion
  and y.cod_oficina = d.cod_oficina
  and k.nro_pedido(+) = ci.referencia
;

