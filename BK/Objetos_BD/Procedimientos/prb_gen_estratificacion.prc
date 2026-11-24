CREATE OR REPLACE PROCEDURE IT.PRB_GEN_ESTRATIFICACION is
---Genera informe de estratificaciones
--Simgia S.R.L. 2011
-- EP. 11/2014. SC 6310 - Modificado por Nicolas Andrusky a pedido de Jose Sala
V_FEC_ACTUAL DATE;
v_cod_mon_local  ba_monedas.cod_moneda%type;
v_rango1  NUMBER;
v_rango2  NUMBER;
v_rango3  NUMBER;
v_rango4  NUMBER;
v_rango5  NUMBER;
v_rango6  NUMBER;
v_sal_min_vigente NUMBER;

PROCEDURE LP_INS_SB_ESTRATIFICACI_DET
 (P_FEC_ACTUAL IN DATE
 );
PROCEDURE LP_INS_SB_ESTRATIFIC
 (RP_SDOFI IN SB_ESTRATIFICACIONES_DEP%ROWTYPE
 );

   r_sdofi          sb_estratificaciones_dep%rowtype;

CURSOR detalle IS
select
  b.cod_sec_contable,
  b.cod_moneda,
  b.descripcion,
  b.plz_hasta,
  CASE
  WHEN  abs(nvl(b.monto,0)) <= v_rango1 THEN v_rango1
  WHEN  abs(nvl(b.monto,0)) between (v_rango1+1) and v_rango2 THEN v_rango2
  WHEN  abs(nvl(b.monto,0)) between (v_rango2+1) and v_rango3 THEN v_rango3
  WHEN  abs(nvl(b.monto,0)) between (v_rango3+1) and v_rango4 THEN v_rango4
  WHEN  abs(nvl(b.monto,0)) between (v_rango4+1) and v_rango5 THEN v_rango5
  WHEN abs(nvl(b.monto,0)) > v_rango6 THEN v_rango6
  END  rango,
  sum(b.monto) monto,
  count(1) cantidad
  from(
  select e.cod_sec_contable cod_sec_contable,
    decode(e.cod_moneda,v_cod_mon_local,v_cod_mon_local,'X') cod_moneda,
    e.descripcion,e.monto,e.plz_hasta
    from sb_estratificaciones_dep_det e
    where e.cod_moneda=v_cod_mon_local
    and e.fecha = v_fec_actual

  UNION ALL
--* DOLARES
  select e.cod_sec_contable cod_sec_contable,
    decode(e.cod_moneda,v_cod_mon_local,v_cod_mon_local,'X') cod_moneda ,
    e.descripcion,(e.monto*pag_gen.fu_obt_cotizacion(e.cod_moneda,v_fec_actual))monto,e.plz_hasta
    from sb_estratificaciones_dep_det e
    where e.cod_moneda<>v_cod_mon_local
    and e.fecha = v_fec_actual
    )b
    group by  b.descripcion, b.cod_sec_contable, b.cod_moneda,  b.plz_hasta,
    CASE
    WHEN  abs(nvl(b.monto,0)) <= v_rango1 THEN v_rango1
    WHEN  abs(nvl(b.monto,0)) between (v_rango1+1) and v_rango2 THEN v_rango2
    WHEN  abs(nvl(b.monto,0)) between (v_rango2+1) and v_rango3 THEN v_rango3
    WHEN  abs(nvl(b.monto,0)) between (v_rango3+1) and v_rango4 THEN v_rango4
    WHEN  abs(nvl(b.monto,0)) between (v_rango4+1) and v_rango5 THEN v_rango5
    WHEN abs(nvl(b.monto,0)) > v_rango6 THEN v_rango6
    END
    ;

PROCEDURE LP_INS_SB_ESTRATIFICACI_DET
 (P_FEC_ACTUAL IN DATE
 )
 IS
 Cursor sb_estratificaci is
     select  b.cod_rubro, tip_saldo, cod_modalidad,b.cod_plazo, b.cod_moneda,cod_sec_contable,b.nro_cuenta,b.monto,b.plazo,b.descripcion   from (
    --AHORRO A LA VISTA
     select distinct   c.cod_rubro,
                      c.cod_moneda,
                      c.cod_sec_contable,
                      c.cod_oficina,
                      substr(c.cod_rubro,6,3) cuentas,
                      substr(c.cod_rubro,9,2) sub_cuenta,
                      to_char(p.can_dias) plazo,
                      nvl(d.sal_actual,0) monto,
                      d.nro_cuenta nro_cuenta,
                      c.tip_saldo,
                      --nvl(max(g.cod_departamento),1) cod_departamento,
                      c.cod_modalidad,
                      'AHORRO A LA VISTA' descripcion,
                      c.cod_plazo
             from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                  ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
              where c.fecha            = P_FEC_ACTUAL
                and d.nro_referencia   = c.nro_referencia
                and d.fecha            = c.fecha
                and c.cod_moneda       = m.cod_moneda
                and ge.nro_cuenta      = d.nro_cuenta
                and g.cod_persona      = ge.cod_persona
                and nvl(c.sal_total,0) != 0
                and c.cod_rubro is not null
                and p.cod_plazo=c.cod_plazo
                and substr(c.cod_rubro,1,1) = '2'
                and x.dominio = 'EST_VISTA'
                and x.val_minimo = substr(c.cod_rubro,6,3)
                --and substr(c.cod_rubro,6,3) IN ('102','138','196','236','238','292')
 UNION
 --CERTIFICADOS DE DEPOSITO
 select distinct   c.cod_rubro,
                      c.cod_moneda,
                      c.cod_sec_contable,
                      c.cod_oficina,
                      substr(c.cod_rubro,6,3) cuentas,
                      substr(c.cod_rubro,9,2) sub_cuenta,
                      to_char(p.can_dias) plazo,
                      nvl(d.sal_actual,0) monto,
                      d.nro_cuenta nro_cuenta,
                      c.tip_saldo,
                      --nvl(max(g.cod_departamento),1) cod_departamento,
                      c.cod_modalidad,
                      'CERTIFICADOS DE DEPOSITO' descripcion,
                      c.cod_plazo
             from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                  ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
              where c.fecha            = P_FEC_ACTUAL
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
 select distinct   c.cod_rubro,
                      c.cod_moneda,
                      --decode(substr(c.cod_rubro,6,3),'140','N','142','N',c.cod_sec_contable) cod_sec_contable,
                      decode(x.val_maximo,null,c.cod_sec_contable,x.val_maximo) cod_sec_contable,
                      c.cod_oficina,
                      substr(c.cod_rubro,6,3) cuentas,
                      substr(c.cod_rubro,9,2) sub_cuenta,
                      to_char(p.can_dias) plazo,
                      nvl(d.sal_actual,0) monto,
                      d.nro_cuenta nro_cuenta,
                      c.tip_saldo,
                      --nvl(max(g.cod_departamento),1) cod_departamento,
                      c.cod_modalidad,
                      'CUENTAS CORRIENTES' descripcion,
                      c.cod_plazo
             from cb_sal_inventarios_det_his d, cb_sal_inventarios_his c,  ba_monedas m,
                  ge_clientes g, ge_cta_clientes ge, ge_plz_contables p, ba_cod_referencias x
              where c.fecha            = P_FEC_ACTUAL
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
                )b
         where b.monto<>0
       order by 3;

BEGIN
   For reg in sb_estratificaci loop -- Inserta el detalle
     insert into sb_estratificaciones_dep_det
       (fecha, cod_moneda, cod_sec_contable,nro_cuenta, monto,plz_hasta,
        descripcion)
     values
       (v_fec_actual, reg.cod_moneda, reg.cod_sec_contable,reg.nro_cuenta, NVL(reg.monto,0),
        reg.plazo, reg.descripcion);
   End loop;
   commit;
END;

PROCEDURE LP_INS_SB_ESTRATIFIC
 (RP_SDOFI IN SB_ESTRATIFICACIONES_DEP%ROWTYPE
 )
 IS
BEGIN

  insert into sb_estratificaciones_dep--Inserta la cabecera
  (FECHA,COD_MONEDA,COD_SEC_CONTABLE,MTO_HASTA,SECUENCIA,CANTIDAD,CONCEPTO,MONTO,PLZ_HASTA)
  values
  (v_fec_actual,rp_sdofi.cod_moneda,rp_sdofi.cod_sec_contable,rp_sdofi.mto_hasta,1,rp_sdofi.cantidad,rp_sdofi.concepto,NVL(rp_sdofi.monto,0),rp_sdofi.plz_hasta);

END;

BEGIN

/*     select pag_cal.FU_OBT_FEC_ANT_HAB (x.pri_dia_mes,31,1)
     into v_fec_actual
     from
       (select f.pri_dia_mes
         from ge_calendarios f
         where f.cod_modulo=1)x;

   v_fec_actual := to_date(v_fec_actual,'dd/mm/yyyy');*/
   
    -- PN DYDMR-1667: ITGF - Informes Estratificación de Depósitos y Depósitos Por Oficina Febrero/2015 SC 13865
    select pag_cal.FU_OBT_FEC_ANT_HAB(f.pri_dia_mes,31,1) 
      into v_fec_actual
      from ge_calendarios f 
     where f.cod_modulo = 1;
         
   --v_fec_actual := to_date(v_fec_actual,'dd/mm/yyyy');

   v_cod_mon_local  := pag_gen.fu_obt_mon_local;

  begin
    select sal_min_vigente
    into v_sal_min_vigente
    from pr_parametros;
  exception
     when others then
       raise_application_error(-20000, 'Error al recuperar pr_parametros.sal_min_vigente '||sqlerrm);
  end;

  --Hasta 10 salarios minimos
  v_rango1 := v_sal_min_vigente * 10;
  --Mayor a 10 salarios minimos  hasta 75 salarios minimos
  v_rango2 :=  v_sal_min_vigente * 75;
  --Mayor a 75 salarios minimos  hasta 150 salarios minimos
  v_rango3 := v_sal_min_vigente * 150;
  --Mayor a 150 salarios minimos  hasta 250 salarios minimos
  v_rango4 := v_sal_min_vigente * 250;
  --Mayor a 250 salarios minimos  hasta 350 salarios minimos
  v_rango5 := v_sal_min_vigente * 350;
  --Mayor 350 salarios minimos
  v_rango6 := (v_sal_min_vigente * 350)+1;

   DELETE FROM SB_ESTRATIFICACIONES_DEP
   WHERE FECHA = v_fec_actual;
   DELETE FROM SB_ESTRATIFICACIONES_DEP_DET
   WHERE FECHA = v_fec_actual;

   commit;

   LP_INS_SB_ESTRATIFICACI_DET(v_fec_actual);--llama al procedimiento para realizar la insercion de los detalles


   for ofi in detalle loop---recorre el cursor del detalle

      r_sdofi.cod_moneda := ofi.cod_moneda;
      r_sdofi.cod_sec_contable:= ofi.cod_sec_contable;
      r_sdofi.mto_hasta := ofi.rango;
      r_sdofi.cantidad := ofi.cantidad;
      r_sdofi.concepto := ofi.descripcion;
      r_sdofi.MONTO   := ofi.monto; --(ofi.MONTO/1000000); LV OCT/2015 DE-1497 Ajuste para no redondear los montos en el Informe de estratificacion
      r_sdofi.plz_hasta := ofi.plz_hasta;
      --- Insertar registro en tabla de informe
      LP_INS_SB_ESTRATIFIC(r_sdofi);
  end loop;

END;
------- FIN PROCEDIMIENTO PARA LISTADO DE ESTRATIFICACION -------;
/

