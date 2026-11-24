create or replace procedure it.pr_operaciones_efectivo(p_moneda in varchar2,
                                                    p_desde  in date,
                                                    p_hasta  in date) is

  v_efec_entradas    float := 0;
  v_efec_entradas_c  float := 0;
  v_efec_salidas     float := 0;
  v_efec_salidas_c   float := 0;
  v_trans_entradas   float := 0;
  v_trans_entradas_c float := 0;
  v_trans_salidas    float := 0;
  v_trans_salidas_c  float := 0;

  v_cantidad_f float := 0;
  v_cantidad_j float := 0;

  r_infope it.ge_operaciones_informe%rowtype;

begin
  begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1;   end;
  delete ge_operaciones_informe;
  commit;

  --RANGO DE MONTOS
  for aa in (select ee.cod_rango,
                    ee.rango_min,
                    ee.rango_max,
                    ge.descripcion,
                    ge.residente,
                    ge.tipo_per
               from ge_rango_informe ee, ge_tip_seg_clientes ge
              where ee.cod_moneda = p_moneda
                and ge.residente is not null
              order by ee.cod_rango, tipo_per, residente) loop
    -----------------------------
    ---------ENTRADAS------------
    -----------------------------
    --Entradas en Cuenta del Cliente

    select nvl(sum(a.monto), 0), count(1)
      into v_efec_entradas, v_efec_entradas_c
      from lc_ope_efectivos a, ge_clientes ge, ba_personas ba
     where (a.fecha >= p_desde and a.fecha <= p_hasta)
       and (a.monto >= aa.rango_min and a.monto <= aa.rango_max)
       and a.cod_moneda = p_moneda
       and a.cod_tip_ope_efe in ('1','2','3','4')
       and a.cod_persona = ge.cod_persona
       and ge.cod_persona = ba.cod_persona
       and ge.residente = aa.residente
       and ba.tipo = aa.tipo_per;

    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    --TRANSFERENCIAS RECIBIDAS
    select nvl(sum(a.monto), 0), count(1)
      into v_trans_entradas, v_trans_entradas_c
      from lc_transferencias a, ge_clientes ge, ba_personas ba
     where a.cod_tip_referencia = 00
       and (a.fec_operacion >= p_desde and a.fec_operacion <= p_hasta)
       and a.cod_moneda = p_moneda
       and (a.monto >= aa.rango_min and a.monto <= aa.rango_max)
       and a.cod_per_beneficiario = ge.cod_persona
       and ge.cod_persona = ba.cod_persona
       and ge.residente = aa.residente
       and ba.tipo = aa.tipo_per;
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -----------------------------
    ---------SALIDAS-------------
    -----------------------------
    --Salidas en Cuenta del Cliente

    select nvl(sum(a.monto), 0), count(1)
      into v_efec_salidas, v_efec_salidas_c
      from lc_ope_efectivos a, ge_clientes ge, ba_personas ba
     where (a.fecha >= p_desde and a.fecha <= p_hasta)
       and a.cod_moneda = p_moneda
       and a.cod_tip_ope_efe in ('5','6','7','8')
       and (a.monto >= aa.rango_min and a.monto < aa.rango_max)
       and a.cod_persona = ge.cod_persona
       and ge.cod_persona = ba.cod_persona
       and ge.residente = aa.residente
       and ba.tipo = aa.tipo_per;



    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    --TRANSFERENCIAS EMITIDAS
    select nvl(sum(a.monto), 0), count(1)
      into v_trans_salidas, v_trans_salidas_c
      from lc_transferencias a, ge_clientes ge, ba_personas ba
     where a.cod_per_solicitante is not null
       and a.cod_modulo = 7
       and (a.fec_operacion >= p_desde and a.fec_operacion <= p_hasta)
       and a.cod_moneda = p_moneda
       and (a.monto >= aa.rango_min and a.monto <= aa.rango_max)
       and a.cod_per_solicitante = ge.cod_persona
       and ge.cod_persona = ba.cod_persona
       and ge.residente = aa.residente
       and ba.tipo = aa.tipo_per;

    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------

    r_infope.efectivo_e  := v_efec_entradas;
    r_infope.transf_e    := v_trans_entradas;
    r_infope.cod_rango   := aa.cod_rango;
    r_infope.cod_moneda  := p_moneda;
    r_infope.mes         := to_char(p_desde, 'MM');
    r_infope.anho        := to_char(p_desde, 'YYYY');
    r_infope.efectivo_s  := v_efec_salidas;
    r_infope.transf_s    := v_trans_salidas;
    r_infope.cantidad    := v_efec_entradas_c + v_efec_salidas_c +
                            v_trans_entradas_c + v_trans_salidas_c;
    r_infope.tip_persona := aa.tipo_per;
    r_infope.residente   := aa.residente;

    insert into ge_operaciones_informe values r_infope;

    v_efec_entradas    := 0;
    v_efec_entradas_c  := 0;
    v_efec_salidas     := 0;
    v_efec_salidas_c   := 0;
    v_trans_entradas   := 0;
    v_trans_entradas_c := 0;
    v_trans_salidas    := 0;
    v_trans_salidas_c  := 0;

  end loop;

  --HALLAR LOS PORCENTAJES QUE CORRESPONDE A CADA RANGO Y TIPO DE PERSONA
  select nvl(sum(cantidad), 0)
    into v_cantidad_f
    from ge_operaciones_informe ii
   where ii.tip_persona = 'F';

  select nvl(sum(cantidad), 0)
    into v_cantidad_j
    from ge_operaciones_informe ii
   where ii.tip_persona = 'J';

  for bb in (select ee.*
               from ge_operaciones_informe ee
              where ee.tip_persona = 'F') loop

    update ge_operaciones_informe ii
       set ii.porcentaje = round((ii.cantidad * 100) / v_cantidad_f, 2)
     where ii.tip_persona = bb.tip_persona
       and ii.residente = bb.residente
       and ii.cantidad = bb.cantidad;

  end loop;

  for cc in (select ee.*
               from ge_operaciones_informe ee
              where ee.tip_persona = 'J') loop

    update ge_operaciones_informe ii
       set ii.porcentaje = round((ii.cantidad * 100) / v_cantidad_j, 2)
     where ii.tip_persona = cc.tip_persona
       and ii.residente = cc.residente
       and ii.cantidad = cc.cantidad;

  end loop;

end;
/

