create or replace force view it.pv_cta_prestamos as
select  pp.nro_cuenta, pg.cod_persona,  fue_obt_nom_persona(pg.cod_persona) denominacion_cliente
       ,pp.cod_modalidad as modalidad,fug_obt_des_modal(pp.cod_modulo,pp.cod_modalidad) tipo_denominacion
       ,pp.cod_moneda moneda,pp.mto_capital monto,pp.sal_capital saldo_capital,pp.sal_interes saldo_interes
       ,  case when pp.estado = 'C' then 'Vigente'
               when pp.estado = 'V' then 'Vencido'
               when pp.estado = 'G' then 'En Gestion'
               when pp.estado = 'M' then 'Moroso'
               when pp.estado = 'I' then 'Irrecuperable'
               when pp.estado = 'N' then 'Cancelado'
          end estado

       ,pp.cod_oficina oficina, bof.descripcion denominacion_oficina, pp.val_tasa tasa
       , (select bu.nombre
 from ba_usuarios bu
where bu.cod_usuario = (select ba.cod_usu_promotor
                         from ba_personas  ba
                        where ba.cod_persona = pg.cod_persona)) Usuario
                        ,pp.nro_solicitud Nro_Propuesta
       ,case when pp.nro_sol_renovada is null then 'N' when pp.nro_sol_renovada is not null then 'S' end Renovado
       ,pp.nro_sol_renovada Nro_Renovado
       ,(select b.significado
           from ba_cod_referencias b
          where b.dominio='TIP_RENOVACION'
            and b.val_minimo= pp.tip_renovacion)For_Renov
       ,pg.cod_garantia as tipo_gar,pt.descripcion, pg.mto_aplicado Monto_Aplicado,pg.nro_garantia Garantia
        , fue_obt_nom_persona(pg.nro_garantia) nombre_del_garante
       ,(select pr.cod_moneda
          from pr_garantias pr
         where pr.cod_garantia = pg.cod_garantia
           and pr.nro_garantia = pg.nro_garantia) moneda_gar
       ,(select  pr.valor
           from pr_garantias pr
         where pr.cod_garantia = pg.cod_garantia
           and pr.nro_garantia = pg.nro_garantia) Valor_de_la_Garantia

       , pp.fec_inicio fecha_desembolso

       ,(select bf.descripcion
          from ba_oficinas bf
         where bf.cod_oficina = (select ge.cod_oficina
                from ge_clientes ge
                     where ge.cod_persona = pg.cod_persona)) cli_oficina

       , pp.fec_vencimiento
       , pp.monto monto_desembolsado
       ,pp.mto_capital
       ,(select sum(pc.mto_interes) from pr_cuotas pc where pc.nro_cuenta = pp.nro_cuenta) mto_interes
       ,pp.sal_capital
       ,pp.sal_interes
       ,  pp.mto_capital + (select sum(pc.mto_interes) from pr_cuotas pc where pc.nro_cuenta = pp.nro_cuenta) mto_total
       , pp.sal_capital + pp.sal_interes saldo_total
from    pr_cta_prestamos pp
      , pr_cta_garantias pg
      , ba_oficinas bof
      , ba_usuarios u
      , pr_gar_tipos pt

where pg.nro_cuenta = pp.nro_cuenta
  and bof.cod_oficina = pp.cod_oficina
  and u.cod_usuario = pp.usu_insercion
  and pt.cod_garantia = pg.cod_garantia

order by pp.nro_cuenta;

