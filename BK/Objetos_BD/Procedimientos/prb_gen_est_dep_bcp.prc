CREATE OR REPLACE PROCEDURE IT.PRB_GEN_EST_DEP_BCP is
    -- Genera informe de Depositos por Oficina
---Simgia S.R.L.2011
---EP 2015-01-12 - SC 11901 -  N.AN. modificaciones a la logica para coincidir con nueva logica del Informe Estratificaciones 

/* Insertar registro de depositos por oficina */
PROCEDURE LP_INS_SB_DEP_OFICINA_DET
 (RP_SDOFI_DET IN SB_DEP_OFICINAS_DET%ROWTYPE
 );
 
PROCEDURE LP_INS_SB_DEP_OFICIN
 (RP_SDOFI IN SB_DEP_OFICINAS%ROWTYPE
 );
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   v_cod_mon_fuerte ba_monedas.cod_moneda%type;

   v_tip_mon_ant    varchar2(02);
   r_sdofi          sb_dep_oficinas%rowtype;
   r_sdofi_det      sb_dep_oficinas_det%rowtype;
   v_cot_mon_fuerte sb_dep_oficinas_det.val_cotizacion%type;
   
   --- Cursor del detalle por oficina y moneda
   cursor c_dep_oficinas is    
     select decode(tip_moneda,'ME',v_cod_mon_fuerte,a.cod_moneda) cod_moneda,
         a.tip_moneda,
         a.cod_oficina oficina,
         decode(tip_moneda,'ME',v_cot_mon_fuerte,a.val_cotizacion) val_cotizacion,
         0 CAN_CTA_PER_SUP,
         0 CAN_CTA_PER_OTR, 
         count(1) CAN_CTA_CLIENTES,
         SUM(decode(a.cod_modalidad,41,a.saldo,0)) MTO_CTA_CORRIENTES,
         SUM(decode(a.cod_modalidad,31,a.saldo,0)) MTO_CTA_VISTAS,
         SUM(decode(a.cod_modalidad,32,a.saldo,0)) MTO_CTA_PLAZOS,
         SUM(decode(a.cod_modalidad,33,a.saldo,0)) MTO_CTA_CERTIFICADOS,
         SUM(decode(a.cod_modalidad,34,a.saldo,35,a.saldo,0)) MTO_CTA_TITULOS
  from (
        select s.cod_oficina, s.cod_moneda, s.cod_modalidad, decode(s.cod_moneda,v_cod_mon_local,'ML','ME') tip_moneda, 
               s.val_cotizacion val_cotizacion, 
                nvl(((s.saldo)*
                   decode(s.cod_moneda,v_cod_mon_local,1,pag_gen.fu_obt_cotizacion(s.cod_moneda,v_fec_actual))
                   ),0) saldo
         from sb_dep_oficinas_det s
         where s.fecha = v_fec_actual) a
         group by a.cod_oficina,  a.tip_moneda, decode(tip_moneda,'ME',v_cod_mon_fuerte,a.cod_moneda),
          decode(tip_moneda,'ME',v_cot_mon_fuerte,a.val_cotizacion)
         order by 1,2;
         
         -- v_control varchar2(1):= 'N';
         v_cotizacion sb_dep_oficinas.val_cotizacion%type;
         v_cant_sup  number(10);
         v_cant_otr  number(10);
         v_cant_cli  number(10);

/* Insertar registro de depositos por oficina */
PROCEDURE LP_INS_SB_DEP_OFICINA_DET
 (RP_SDOFI_DET IN SB_DEP_OFICINAS_DET%ROWTYPE
 )
 IS
Cursor Oficinas is
   select  b.moneda, b.oficina, b.cod_modalidad, b.nro_cuenta, saldo, b.tip_moneda, b.cod_moneda from (
     --AHORRO A LA VISTA
     select distinct  m.cod_mon_bco_central moneda,
                      c.cod_rubro,
                      c.cod_moneda,
                      decode(c.cod_moneda,v_cod_mon_local,'ML','ME') tip_moneda,
                      c.cod_sec_contable,
                      c.cod_oficina oficina,
                      substr(c.cod_rubro,6,3) cuentas,
                      substr(c.cod_rubro,9,2) sub_cuenta,
                      to_char(p.can_dias) plazo,
                      nvl(d.sal_actual,0) saldo,
                      d.nro_cuenta nro_cuenta,
                      c.tip_saldo,                      
                      31 cod_modalidad
                   
             from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                  ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
              where c.fecha            = v_fec_actual
                and d.nro_referencia   = c.nro_referencia
                and d.fecha            = c.fecha
                and c.cod_moneda       = m.cod_moneda
                and ge.nro_cuenta      = d.nro_cuenta
                and g.cod_persona      = ge.cod_persona
                and nvl(c.sal_total,0) != 0
                and c.cod_rubro is not null
                and p.cod_plazo=c.cod_plazo
                and substr(c.cod_rubro,1,1) = '2'
                --and substr(c.cod_rubro,6,3) IN ('102','138','196','236','238','292')
                and x.dominio = 'EST_VISTA'
                and x.val_minimo = substr(c.cod_rubro,6,3)
     UNION
     --CERTIFICADOS DE DEPOSITO
     select distinct m.cod_mon_bco_central moneda,
                          c.cod_rubro,
                          c.cod_moneda,
                          decode(c.cod_moneda,v_cod_mon_local,'ML','ME') tip_moneda,
                          c.cod_sec_contable,
                          c.cod_oficina,
                          substr(c.cod_rubro,6,3) cuentas,
                          substr(c.cod_rubro,9,2) sub_cuenta,
                          to_char(p.can_dias) plazo,
                          nvl(d.sal_actual,0) saldo,
                          d.nro_cuenta nro_cuenta,
                          c.tip_saldo,
                          33 cod_modalidad

                 from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                      ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
                  where c.fecha            = v_fec_actual
                    and d.nro_referencia   = c.nro_referencia
                    and d.fecha            = c.fecha
                    and c.cod_moneda       = m.cod_moneda
                    and ge.nro_cuenta      = d.nro_cuenta
                    and g.cod_persona      = ge.cod_persona
                    and nvl(c.sal_total,0) != 0
                    and c.cod_rubro is not null
                    and p.cod_plazo=c.cod_plazo
                    and substr(c.cod_rubro,1,1) = '2'
                    --and substr(c.cod_rubro,6,3) IN ('104','152','156','166','294','298','306')
                    and x.dominio = 'EST_CDA'
                    and x.val_minimo = substr(c.cod_rubro,6,3)
     UNION
     --CUENTAS CORRIENTES
     select distinct m.cod_mon_bco_central moneda,
                     c.cod_rubro,
                          c.cod_moneda,
                          decode(c.cod_moneda,v_cod_mon_local,'ML','ME') tip_moneda,
                          --decode(substr(c.cod_rubro,6,3),'140','N','142','N',c.cod_sec_contable) cod_sec_contable,
                          decode(x.val_maximo,null,c.cod_sec_contable,x.val_maximo) cod_sec_contable,
                          c.cod_oficina,
                          substr(c.cod_rubro,6,3) cuentas,
                          substr(c.cod_rubro,9,2) sub_cuenta,
                          to_char(p.can_dias) plazo,
                          nvl(d.sal_actual,0) saldo,
                          d.nro_cuenta nro_cuenta,
                          c.tip_saldo,
                          41 cod_modalidad
                          
                 from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                      ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
                  where c.fecha            = v_fec_actual
                    and d.nro_referencia   = c.nro_referencia
                    and d.fecha            = c.fecha
                    and c.cod_moneda       = m.cod_moneda
                    and ge.nro_cuenta      = d.nro_cuenta
                    and g.cod_persona      = ge.cod_persona
                    and nvl(c.sal_total,0) != 0
                    and c.cod_rubro is not null
                    and p.cod_plazo=c.cod_plazo
                    and substr(c.cod_rubro,1,1) = '2'
                    --and substr(c.cod_rubro,6,3) IN ('136','140','142','144','148','284','290')                                         
                    and x.dominio = 'EST_CTACTE'
                    and x.val_minimo = substr(c.cod_rubro,6,3)
     --BSEVOCORE-309-- Reclasificacion de los rubros 152 y 166
     UNION
     --CTA PLAZOS
     select distinct m.cod_mon_bco_central moneda,
                 c.cod_rubro,
                      c.cod_moneda,
                      decode(c.cod_moneda,v_cod_mon_local,'ML','ME') tip_moneda,
                      decode(x.val_maximo,null,c.cod_sec_contable,x.val_maximo) cod_sec_contable,
                      c.cod_oficina,
                      substr(c.cod_rubro,6,3) cuentas,
                      substr(c.cod_rubro,9,2) sub_cuenta,
                      to_char(p.can_dias) plazo,
                      nvl(d.sal_actual,0) saldo,
                      d.nro_cuenta nro_cuenta,
                      c.tip_saldo,
                      32 cod_modalidad
                          
             from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                  ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
              where c.fecha            = v_fec_actual
                and d.nro_referencia   = c.nro_referencia
                and d.fecha            = c.fecha
                and c.cod_moneda       = m.cod_moneda
                and ge.nro_cuenta      = d.nro_cuenta
                and g.cod_persona      = ge.cod_persona
                and nvl(c.sal_total,0) != 0
                and c.cod_rubro is not null
                and p.cod_plazo=c.cod_plazo
                and substr(c.cod_rubro,1,1) = '2'                                      
                and x.dominio = 'EST_CTAPLAZOS'
                and x.val_minimo = substr(c.cod_rubro,6,3) 
     )b
     
       where b.saldo<>0
       order by b.moneda;
       
   v_cotizacion sb_dep_oficinas.val_cotizacion%type;
   v_cod_mon_mem sb_dep_oficinas.cod_moneda%type := null;
BEGIN 

   For reg in oficinas loop -- Inserta el detalle
     if reg.tip_moneda = 'ME' and v_cod_mon_mem <> reg.cod_moneda then
        v_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda,v_fec_actual);
        v_cod_mon_mem := reg.cod_moneda;
     end if;
     
     insert into sb_dep_oficinas_det
       (fecha, cod_moneda, cod_oficina,cod_modalidad, nro_cuenta,
        val_cotizacion,saldo)
     values
       (v_fec_actual, reg.cod_moneda, reg.oficina,reg.cod_modalidad, reg.nro_cuenta,
        decode(reg.tip_moneda,'ME',v_cotizacion,0), reg.saldo);
   End loop;
   commit;
END;
PROCEDURE LP_INS_SB_DEP_OFICIN
 (RP_SDOFI IN SB_DEP_OFICINAS%ROWTYPE
 )
 IS
 BEGIN
  
    v_cant_cli := nvl(rp_sdofi.CAN_CTA_CLIENTES,0);
    v_cant_otr := nvl(rp_sdofi.CAN_CTA_PER_OTR,0);
    v_cant_sup := nvl(rp_sdofi.CAN_CTA_PER_SUP,0);   
   
   insert into sb_dep_oficinas -- Inserta el resumen
     (FECHA, COD_MONEDA, COD_OFICINA, VAL_COTIZACION,
      CAN_CTA_PER_SUP, CAN_CTA_PER_OTR, CAN_CTA_CLIENTES,
      MTO_CTA_CORRIENTES, MTO_CTA_VISTAS, MTO_CTA_PLAZOS,
      MTO_CTA_CERTIFICADOS, MTO_CTA_TITULOS)
   values
     (rp_sdofi.FECHA, rp_sdofi.COD_MONEDA, rp_sdofi.COD_OFICINA, rp_sdofi.VAL_COTIZACION,
      nvl(v_Cant_sup,0), nvl(v_cant_otr,0), nvl(v_cant_cli,0),
      nvl(rp_sdofi.MTO_CTA_CORRIENTES,0), nvl(rp_sdofi.MTO_CTA_VISTAS,0), nvl(rp_sdofi.MTO_CTA_PLAZOS,0),
      nvl(rp_sdofi.MTO_CTA_CERTIFICADOS,0), nvl(rp_sdofi.MTO_CTA_TITULOS,0));
END;
BEGIN

   select pag_cal.FU_OBT_FEC_ANT_HAB (f.pri_dia_mes,31,1) 
     into v_fec_actual
     from ge_calendarios f 
    where f.cod_modulo=1;
   --v_fec_actual     := /*pag_cal.fu_obt_fec_actual(3)*/;
   
   DELETE FROM SB_DEP_OFICINAS
   WHERE FECHA = V_FEC_ACTUAL;
   DELETE FROM SB_DEP_OFICINAS_DET
   WHERE FECHA = V_FEC_ACTUAL;
   
   -- commit; --solo para pruebas
   
   v_cod_mon_local  := pag_gen.fu_obt_mon_local;
   v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
   r_sdofi_det.fecha          := v_fec_actual;
   v_cot_mon_fuerte := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte,v_fec_actual);
   --Para insertar el detalle
    lp_ins_sb_dep_oficina_det(r_sdofi_det);
   ---Para la cabecera 
   r_sdofi.fecha          := v_fec_actual;

   for ofi in c_dep_oficinas loop---recorre el cursor del detalle
     
      if ofi.tip_moneda = 'ME' then
          r_sdofi.cod_moneda := v_cod_mon_fuerte;
          r_sdofi.val_cotizacion := v_cot_mon_fuerte;
      else
          r_sdofi.cod_moneda     := v_cod_mon_local;
          r_sdofi.val_cotizacion := null;
      end if;
      
      r_sdofi.cod_oficina   := ofi.oficina;
      
     --- Insertar registro en tabla de informe
     r_sdofi.can_cta_clientes     := ofi.can_cta_clientes;
     r_sdofi.MTO_CTA_CORRIENTES   := ofi.MTO_CTA_CORRIENTES;
     r_sdofi.MTO_CTA_VISTAS       := ofi.MTO_CTA_VISTAS;
     r_sdofi.MTO_CTA_PLAZOS       := ofi.MTO_CTA_PLAZOS;
     r_sdofi.MTO_CTA_CERTIFICADOS := ofi.MTO_CTA_CERTIFICADOS;
     r_sdofi.MTO_CTA_TITULOS      := ofi.MTO_CTA_TITULOS;
     lp_ins_sb_dep_oficin(r_sdofi);
      
  end loop;
  
end PRB_GEN_EST_DEP_BCP;
/

