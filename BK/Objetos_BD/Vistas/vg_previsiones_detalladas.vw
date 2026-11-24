create or replace force view it.vg_previsiones_detalladas as
select o.cod_persona riesgo, p.nom_completo nombre, d.abreviatura doc, p.nro_documento nro_doc,
       e.cat_riesgo, fup_obt_categoria(e.cat_automatica,e.cat_subjetiva) cat_crc, e.cod_oficina ofi, n.descripcion oficina, e.cod_usu_oficial,
       u.nombre nom_usu,g.descripcion banca,
       e.cat_subjetiva, e.cod_gru_economico gru_eco,
       e.cat_gru_economico, e.cat_sistema, e.tot_deu_sistema tot_deu_rsistema, e.tot_deu_con_sistema tot_con_rsistema,
       e.tipo, substr(r1.significado,1,40) tip_cliente, fub_obt_rub_contable(o.cod_modulo,o.nro_cuenta) rubro,
       o.cod_modulo,o.cod_modalidad, o.nro_cuenta, o.cod_moneda, o.cod_estado, t.descripcion estado, o.tot_deu_real,
       o.tot_deu_contingente, o.dev_no_cobrado,
       o.tot_gar_computables, o.tot_prevision, o.cat_automatica, o.cat_renovaciones, o.dia_atraso,
       nvl(o.tip_destino,4) tip_destino, substr(r2.significado,1,20) destino, o.cod_sec_credito,
       case when o.cod_sec_credito = 701 then --En el proceso: it.pap_cat.PR_PRO_DAT_PRESTAMO se le asigna el COD_BCO_CENTRAL en el cod_sec_credito
         'PRESTAMOS CONSUMO'
           when o.cod_sec_credito = 750 then
         'PRESTAMOS PARA LA VIVIENDA H20/H30'
           when o.cod_sec_credito = 111 then
           'CONSTRUCCION - OTROS'
           when o.cod_sec_credito = 135 then
           'COMERCIO MINORISTA'
           when o.cod_sec_credito = 172 then
            'ADELANTO DE IMP'
           when o.cod_sec_credito = 201 then
             'EXPLOTACION GANADERIA'
           when o.Cod_Sec_Credito = 203 then
             'OTRAS ACT.GANADERAS'
           when o.Cod_Sec_Credito = 330 then
            'OTRAS INDUSTRIAS'
           when o.cod_sec_credito = 400 then
            'EXPORTACION OTROS PRODUCTOS'
           when o.cod_sec_credito = 401 then
             'EXPORTACION PRODUCTOS AGRÍCOLAS'
           when o.cod_sec_credito = 408 then
             'IMPOR Y COMER. MAQ.Y  EQUIPOS'
           when o.cod_sec_credito = 409 then
           'OTROS COMERCIOS AL POR MAYOR'
           when o.cod_sec_credito not in (111,135,172,201,203,330,400,401,408,409,701,750) then
           (select se.descripcion from pr_sec_creditos se where se.cod_sec_credito = o.cod_sec_credito)
       end desc_sec_crd,
       decode(nvl(s.tip_renovacion,'A'),'A','Nuevo','D','Desembolso Etapas','V','Vista','E','Re-estructurado',
       'N','Renovado','R','Refinanciado','Otro') Tip_renovacion,
       case when o.cod_modulo = 6 and o.dia_atraso > 60 then
           o.tot_deu_real
       when o.cod_modulo = 5 and o.dia_atraso > 30 then
           o.tot_deu_real
       else
           0
       end mto_mora, s.cod_sec_credito sect_prestamo,
       (select se.descripcion from pr_sec_creditos se where se.cod_sec_credito = s.cod_sec_credito)desc_sect_prestamo,
       s.fec_inicio fec_desembolso
from ge_cla_operaciones o, ge_clientes e, ba_personas p,
     ba_tip_documentos d, ba_oficinas n, ba_cod_referencias r1, ge_est_cuentas t,
     ba_cod_referencias r2, ba_usuarios u,  ba_oficinas f, ba_gru_oficinas g, pr_cta_prestamos s
where o.cod_persona=e.cod_persona
and e.cod_persona=p.cod_persona
and p.cod_tip_documento=d.cod_tip_documento
and e.cod_oficina=n.cod_oficina
and r1.dominio='TIP_CLIENTE'
and r1.val_minimo=nvl(e.tipo,'T')
and r2.dominio='TIP_DESTINO'
and r2.val_minimo=nvl(o.tip_destino,4)
and e.cod_usu_oficial=u.cod_usuario
and u.cod_oficina=f.cod_oficina
and f.cod_gru_oficina=g.cod_gru_oficina(+)
and t.cod_modulo=o.cod_modulo
and t.cod_modalidad=o.cod_modalidad
and t.estado=o.cod_estado
and o.nro_cuenta = s.nro_cuenta(+)
order by o.cod_persona, o.cod_modulo, o.cod_modalidad, o.cod_moneda, o.nro_cuenta
;

