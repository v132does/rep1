create or replace force view it.gv_qry_varios as
Select TO_CHAR(CTA.NRO_GARANTIA) nro_cuenta, CTA.COD_PERSONA, 'GARANTIA' DENOMINACION, CTA.COD_MONEDA, CTA.fec_inicio, CTA.fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, CTA.ESTADO, EST.SIGNIFICADO DESCRIPCION, DECODE(CTA.ESTADO,'N','N','S') ACTIVO,
        TIP.DESCRIPCION SC_NMMODAL, valor monto, 'G' tipo, null bajo_limite, cta.cod_garantia cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, PR_GAR_TIPOS TIP, PR_GARANTIAS CTA --garantías
 where EST.DOMINIO = 'EST_GARANTIA'
   AND EST.VAL_MINIMO = CTA.ESTADO
   and cta.COD_GARANTIA = TIP.COD_GARANTIA
UNION ALL
--límites
Select TO_CHAR(CTA.NRO_LINEA) nro_cuenta, CTA.COD_PERSONA, CTA.DESCRIPCION DENOMINACION, CTA.COD_MONEDA, CTA.fec_aprobacion, CTA.fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, CTA.ESTADO, EST.SIGNIFICADO DESCRIPCION, DECODE(CTA.ESTADO,'C','N','R','N','S') ACTIVO,
       'LIMITE DE CREDITO' SC_NMMODAL, cta.monto, 'L' tipo, null bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, PR_LINEAS CTA
 where EST.DOMINIO = 'EST_LIMITE'
   AND EST.VAL_MINIMO = CTA.ESTADO
UNION ALL
--sobregiros
Select TO_CHAR(det.nro_secuencia) nro_cuenta, DET.COD_PERSONA, 'LINEA DE SOBREGIRO' DESCRIPCION, DET.COD_MONEDA, det.fec_inicio, det.fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, DET.ESTADO, EST.SIGNIFICADO, DECODE(DET.ESTADO,'C','N','R','N','S') ACTIVO,
       'LINEA DE SOBREGIRO' SC_NMMODAL, det.monto, tipo /* T/P */, decode(nro_linea,'','N','S') bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, cc_lin_sobregiros det
 where EST.DOMINIO = 'EST_LIN_SOBREGIRO'
   AND EST.VAL_MINIMO = DET.ESTADO
   and det.nro_cuenta is null
   UNION ALL
--sobregiros cancelados, están en el histórico
Select TO_CHAR(det.nro_secuencia) nro_cuenta, DET.COD_PERSONA, 'LINEA DE SOBREGIRO' DESCRIPCION, DET.COD_MONEDA, det.fec_inicio, det.fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, DET.ESTADO, EST.SIGNIFICADO, DECODE(DET.ESTADO,'C','N','R','N','S') ACTIVO,
       'LINEA DE SOBREGIRO' SC_NMMODAL, det.monto, tipo /* T/P */, decode(nro_linea,'','N','S') bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, cc_lin_sobregiros_his det
 where EST.DOMINIO = 'EST_LIN_SOBREGIRO'
   AND EST.VAL_MINIMO = DET.ESTADO
   and det.estado = 'C'
   and det.nro_cuenta is null
UNION ALL
-- títutos representativos

Select TIT.NRO_TITULO nro_cuenta, TIT.COD_PERSONA, 'TITULOS REPRESENTATIVOS' DENOMINACION, TIT.COD_MONEDA, TIT.FEC_APERTURA fec_otorgamiento,
       TIT.fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, TIT.ESTADO, EST.SIGNIFICADO DESCRIPCION,
       --DECODE(TIT.ESTADO,'C','N','R','N','S') ACTIVO,
       'S' ACTIVO,
       'TITULOS REPRESENTATIVOS' SC_NMMODAL, TIT.CAPITAL monto, 'X' tipo, null bajo_limite, null cod_garantia,
       TIT.SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, AH_TITULOS TIT
 where EST.DOMINIO = 'EST_TITULOS'
   AND EST.VAL_MINIMO = TIT.ESTADO
UNION ALL
--tarjetas de débito (Ahorros Vista)
select det.nro_cuenta nro_cuenta, DET.COD_PERSONA, EMBOZADO DESCRIPCION, c.cod_moneda, det.fec_ingreso fec_inicio, det.fec_cancelacion fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, to_char(DET.cod_EST_solicitud) estado, EST.SIGNIFICADO, DECODE(TO_CHAR(DET.cod_est_solicitud),'16','N','1','N','S') ACTIVO,
       'TARJETA DE DEBITO' SC_NMMODAL, NULL monto, 'D' tipo, det.tar_activa bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, ah_cta_vistas c, ah_tar_debitos det
 where EST.DOMINIO = 'EST_TAR_DEBITO'
   AND EST.VAL_MINIMO = DET.cod_est_solicitud
   and c.nro_cuenta = det.nro_cuenta
UNION ALL
--tarjetas de débito (Cta.Ctes)
select det.nro_cuenta nro_cuenta, DET.COD_PERSONA, EMBOZADO DESCRIPCION, c.cod_moneda, det.fec_ingreso fec_inicio, det.fec_cancelacion fec_vencimiento,
       'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, to_char(DET.cod_EST_solicitud) estado, EST.SIGNIFICADO, DECODE(TO_CHAR(DET.cod_est_solicitud),'16','N','1','N','S') ACTIVO,
       'TARJETA DE DEBITO' SC_NMMODAL, NULL monto, 'D' tipo, det.tar_activa bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, cc_cta_corrientes c, ah_tar_debitos det
 where EST.DOMINIO = 'EST_TAR_DEBITO'
   AND EST.VAL_MINIMO = DET.cod_est_solicitud
   and c.nro_cuenta = det.nro_cuenta
union
--cajas de seguridad
select det.nro_contrato, per.COD_PERSONA,
      'Caja Nro: '||det.cod_caj_seguridad||' de '||fue_obt_titulo(fue_obt_des_oficina(det.cod_oficina)) DESCRIPCION,
       det.cod_moneda, det.fec_apertura fec_inicio, null fec_vencimiento,
       decode(per.tip_relacion,'T','P','A','Z') RELACION, NULL COD_MODULO, NULL COD_MODALIDAD,
       DET.estado, EST.SIGNIFICADO, DECODE(DET.ESTADO,'C','N','S') ACTIVO,
       'CAJAS DE SEGURIDAD' SC_NMMODAL, det.mto_adeudado monto, 'J' tipo, 'N' bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from BA_COD_REFERENCIAS EST, cs_con_personas per, cs_contratos det
 where EST.DOMINIO = 'EST_CONTRATO'
   AND EST.VAL_MINIMO = DET.estado
   and det.nro_contrato = per.nro_contrato
union all
-- Operaciones Futuras
select to_char(o.nro_operacion), o.cod_persona,
      'OPERACION FUTURA' DESCRIPCION,
       o.cod_moneda, o.fec_operacion fec_inicio, o.fec_vencimiento fec_vencimiento,
       'P' relacion, o.cod_modulo cod_modulo, o.cod_mad_transaccion cod_modalidad,
       o.estado, est.significado, decode(o.estado,'L','N','S') ACTIVO,
       m.descripcion sc_nmmodal, o.monto monto, 'O' tipo, 'N' bajo_limite, null cod_garantia,
        NULL SERIE, NULL REGISTRO
  from ba_cod_referencias est, lc_ope_futuras o, ge_modalidades m
 where o.cod_modulo = m.cod_modulo
   and o.cod_mad_transaccion = m.cod_modalidad
   and est.dominio = 'EST_OPE_FUTURA'
   and o.estado <> 'R'  --PN 26/03/2014 SPI 3177: Para que no se visualicen las Operaciones Futuras en estado Rechazado
   and est.val_minimo = o.estado
union all
-- Pólizas de Seguro
select nvl(to_char(a.codigo),a.nro_poliza), a.cod_persona,
       decode(a.codigo, null, 'PROPUESTA DE SEGURO NRO: '||a.nro_poliza,'POLIZA DE SEGURO NRO: '||a.codigo) descripcion,
       a.cod_moneda, a.fec_inicial fec_inicio, a.fec_final fec_vencimiento,
       'P' relacion, null cod_modulo, null cod_modalidad,
       a.estado, a.des_estado,
       decode(a.registro, 'ATM/WEB', decode(a.estado, 'V', 'S', 'N'),  decode(a.estado,'1','S','2','S','N')) activo, --Cuenta Activa = Poliza Emitida
       'CUENTAS DE SEGURO' sc_nmmodal, a.mto_prima monto, 'A' tipo, null bajo_liminte, null cod_garantia,
       null serie, registro REGISTRO
  from gv_pol_seguros a
union all
-- Renovación de Polizas de Seguro
select to_char(a.nro_renovacion), a.cod_persona,
       'RENOVACIÓN DE SEGURO - '|| upper(t.significado) descripcion,
       a.cod_moneda, a.fec_confirmacion fec_inicio, a.fec_hasta fec_vencimiento,
       'P' relacion, null cod_modulo, null cod_modalidad,
       a.estado,e.significado DES_ESTADO,-- a.des_estado,
       decode(a.estado, 'C', 'N', 'S' ) activo, --Cuenta Activa = Poliza Emitida
       'RENOVACIÓN DE SEGURO' sc_nmmodal, a.mto_capital monto, 'R' tipo, null bajo_liminte, null cod_garantia,
       null serie, to_char(nro_renovacion) REGISTRO
  from GE_REN_POL_SEGUROS a, ba_cod_referencias e, ba_cod_referencias t
 where e.dominio = 'EST_REN_SEGURO'
   and a.estado = e.val_minimo
   and a.cod_tip_seguro in ('V', 'P') --vida o accidentes personales
   and t.dominio = 'SEC_SEGURO'
   and t.val_minimo = a.cod_tip_seguro
union all
-- Custodia de Documentos: Empresa Emisora del Documento
Select to_char(a.cod_val_custodia), b.cod_persona, a.descripcion, a.cod_moneda, a.fec_ingreso, a.fec_vencimiento,
       'P' relacion, null cod_modulo, null cod_modalidad, a.estado, e.significado, decode(a.estado,'C', 'N', 'S') activo,
       'ACCIONES AL PORTADOR' sc_nmmodal, a.mto_total, 'U' tipo, null limite, null cod_garantia, null serie, NULL REGISTRO
From ge_val_custodias a, ge_entes b, ba_per_dat_adicionales d, ba_cod_referencias e
where a.cod_ente      = b.cod_ente
  and b.cod_persona   = d.cod_persona
  and d.parametro     = 'ACC_PORTADOR'
  and d.val_parametro = 'S'
  and a.estado        = e.val_minimo
  and e.dominio       = 'EST_VAL_CUSTODIA'
union all
-- Custodia de Documentos: Portadores de los Documentos.-
Select to_char(a.cod_val_custodia), c.cod_per_vinculo, a.descripcion, a.cod_moneda, a.fec_ingreso, a.fec_vencimiento,
       'P' relacion, null cod_modulo, null cod_modalidad, a.estado, e.significado, decode(a.estado,'C', 'N', 'S') activo,
       'ACCIONES AL PORTADOR' sc_nmmodal, a.mto_total, 'U' tipo, null limite, null cod_garantia, null serie, NULL REGISTRO
From ge_val_custodias a, ge_entes b, ba_vinculos c, ba_per_dat_adicionales d, ba_cod_referencias e
where a.cod_ente    = b.cod_ente
  and b.cod_persona = c.cod_persona
  and d.cod_persona = c.cod_per_vinculo
  and d.parametro     = 'ACC_PORTADOR'
  and d.val_parametro = 'S'
  and a.estado        = e.val_minimo
  and e.dominio       = 'EST_VAL_CUSTODIA'
group by to_char(a.cod_val_custodia), c.cod_per_vinculo, a.descripcion, a.cod_moneda, a.fec_ingreso, a.fec_vencimiento,
         a.estado, e.significado, decode(a.estado,'C', 'N', 'S'), a.mto_total
union all
-- Cheques en Custodia
select TO_CHAR(CU.COD_CHE_CUSTODIA) nro_cuenta, CU.COD_PERSONA, CU.DENOMINACION, CU.COD_MONEDA, CU.FEC_APERTURA, CU.FEC_VENCIMIENTO,
        'P' RELACION, NULL COD_MODULO, NULL COD_MODALIDAD, CU.ESTADO, DECODE(CU.ESTADO,'I','INGRESADO','N','NORMAL','C','CANCELADO','V','VENCIDO','X','PENDIENTE') DESCRIPCION, DECODE(CU.ESTADO,'C','N','S') ACTIVO,
        'CHEQUES EN CUSTODIA' SC_NMMODAL, CU.VAL_TOTAL, 'F' TIPO, NULL BAJO_LIMITE, NULL COD_GARANTIA, NULL SERIE, NULL REGISTRO
from CC_CHE_CUSTODIAS CU
;

