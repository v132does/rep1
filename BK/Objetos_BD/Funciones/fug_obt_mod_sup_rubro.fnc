CREATE OR REPLACE FUNCTION IT.FUG_OBT_MOD_SUP_RUBRO
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_RUBRO GE_TIP_ASIENTOS.COD_RUBRO%TYPE;
v_tipo pr_cta_prestamos.tipo%type;
v_cod_modalidad ge_modalidades.cod_modalidad%type;
v_plz_contable number(18,2);
v_tip_renovacion pr_cta_prestamos.tip_renovacion%type;
v_estado pr_cta_prestamos.estado%type;
v_tip_deudor varchar2(2) := null;
BEGIN
-- Certificados de Ahorros a Plazo Fijo

If p_cod_modulo = 3 then
   -- CDA
   select substr(replace(ta.cod_rubro,'TD',trim(to_char(cl.cod_tip_deudor, '09'))),
          6,3) || trim(to_char(pl.cod_plazo, '09')) ||
          substr(replace(ta.cod_rubro,'TD', trim(to_char(cl.cod_tip_deudor, '09'))),
          9,1) --mod_sup_rubro
     into V_RUBRO
     from ba_monedas          mo,
          ge_plz_contables    pl,
          ge_tip_asientos     ta,
          ge_transacciones    tr,
          ge_clientes         cl,
          ge_cta_clientes     cc,
          ah_cta_certificados ah
    where cc.nro_cuenta = p_nro_cuenta
      and mo.cod_moneda = ah.cod_moneda
      and ta.cod_tip_asiento = tr.cod_tip_asiento and tr.cod_transaccion = 604
      and tr.cod_modulo = cc.cod_modulo
      and tr.cod_modalidad = cc.cod_modalidad
      and ta.tip_movimiento = 'D'
      and ta.cod_moneda = ah.cod_moneda
      and cl.cod_persona = cc.cod_persona
      and nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable
      and decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente
      and pl.can_dias = (select min(can_dias) from ge_plz_contables
                          where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
      and cc.nro_cuenta = ah.nro_cuenta
      and
          --ah.est_batch not in ('A', 'C', 'T') and
          --ah.est_cer_batch not in ('V', 'P') and
          (cc.relacion = 'P' /*or(cc.relacion != 'P' and
           not exists (Select '1'
                     from ba_personas pe, ge_cta_clientes ccp
                    where ccp.nro_cuenta = ah.nro_cuenta and
                          ccp.relacion = 'P' and
                          pe.cod_persona = ccp.cod_persona and
                          pe.tipo = 'J'))*/)

     /*Union -- Vencidos
     Select substr(replace(ta.cod_rubro,'TD', trim(to_char(cl.cod_tip_deudor,'09'))),
                   6, 3) || trim(to_char(pl.cod_plazo, '09')) ||
            substr(replace(ta.cod_rubro,'TD', trim(to_char(cl.cod_tip_deudor,'09'))),
                   9,  1) --mod_sup_rubro
       Into v_rubro
      From ba_monedas          mo,
           ge_plz_contables    pl,
           ge_tip_asientos     ta,
           ge_transacciones    tr,
           ge_clientes         cl,
           ge_cta_clientes     cc,
           ah_cta_certificados ah
     Where cc.nro_cuenta = p_nro_cuenta and
           mo.cod_moneda = ah.cod_moneda and
           ta.cod_tip_asiento = tr.cod_tip_asiento and
           tr.cod_transaccion = 604 and
           tr.cod_modulo = cc.cod_modulo and
           tr.cod_modalidad = cc.cod_modalidad and
           ta.tip_movimiento = 'C' and  -- Credito a Rubro Vista
           ta.cod_moneda = ah.cod_moneda and
           cl.cod_persona = cc.cod_persona and
           nvl(ta.cod_sec_contable, cl.cod_sec_contable) =
           cl.cod_sec_contable and
           decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente and
           pl.can_dias = (select min(can_dias)
                          from ge_plz_contables
                          where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
                and cc.nro_cuenta = ah.nro_cuenta
           --   and ah.est_batch not in ('A', 'C', 'T')
                and (ah.est_cer_batch in ('V', 'P') or sal_tot_batch > capital); END IF; */

 -- Ahorros a la vista
 Union
   select substr(replace(ta.cod_rubro, 'TD', trim(to_char(cl.cod_tip_deudor, '09'))), 6, 3) || '01' || -- Plazo Vistas
          substr(replace(ta.cod_rubro, 'TD', trim(to_char(cl.cod_tip_deudor, '09'))), 9, 1) --mod_sup_rubro
     from ba_monedas       mo,
          ge_tip_asientos  ta,
          ge_transacciones tr,
          ge_clientes      cl,
          ge_cta_clientes  cc,
          ah_cta_vistas    ah
    where cc.nro_cuenta = p_nro_cuenta
      and mo.cod_moneda = ah.cod_moneda
      and ta.cod_tip_asiento = tr.cod_tip_asiento and tr.cod_transaccion = 690
      and tr.cod_modulo = cc.cod_modulo
      and tr.cod_modalidad = cc.cod_modalidad and ta.tip_movimiento = 'C'
      and ta.cod_moneda = ah.cod_moneda and cl.cod_persona = cc.cod_persona
      and nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable
      and decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente
      and ((ah.cod_sub_modalidad = 26 and ta.tip_cuenta = 'B') or (ah.cod_sub_modalidad <> 26 and nvl(ta.tip_cuenta, 'x') <> 'B'))
      and cc.nro_cuenta = ah.nro_cuenta
      and (cc.relacion = 'P' /*or
           (cc.relacion != 'P' and not exists
            (Select '1'
                from ba_personas pe, ge_cta_clientes ccp
               where ccp.nro_cuenta = ah.nro_cuenta and ccp.relacion = 'P' and
                     pe.cod_persona = ccp.cod_persona and pe.tipo = 'J'))*/)
 -- Plazo Fijo
 Union
   select substr(replace(ta.cod_rubro,'TD',trim(to_char(cl.cod_tip_deudor, '09'))),
          6,3) || trim(to_char(pl.cod_plazo, '09')) ||
          substr(replace(ta.cod_rubro,'TD', trim(to_char(cl.cod_tip_deudor, '09'))),
          9,1)
     from ba_monedas          mo,
          ge_plz_contables    pl,
          ge_tip_asientos     ta,
          ge_transacciones    tr,
          ge_clientes         cl,
          ge_cta_clientes     cc,
          ah_cta_plazos       ah
    where cc.nro_cuenta = p_nro_cuenta
      and mo.cod_moneda = ah.cod_moneda
      and ta.cod_tip_asiento = tr.cod_tip_asiento
      and tr.cod_transaccion = 602
      and tr.cod_modulo = cc.cod_modulo
      and tr.cod_modalidad = cc.cod_modalidad
      and ta.tip_movimiento = 'C'
      and ta.cod_moneda = ah.cod_moneda
      and cl.cod_persona = cc.cod_persona
      and nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable
      and decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente
      and pl.can_dias = (select min(can_dias) from ge_plz_contables
                          where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1))
      and cc.nro_cuenta = ah.nro_cuenta
      and cc.relacion = 'P';
end if;

-- cuenta corrientes
if p_cod_modulo = 4 then

    Select substr(replace(ta.cod_rubro,
                          'TD',
                          trim(to_char(cl.cod_tip_deudor, '09'))),
                  6,
                  3) || '01' || -- Plazo Vistas
           substr(replace(ta.cod_rubro,
                          'TD',
                          trim(to_char(cl.cod_tip_deudor, '09'))),
                  9,
                  1) --mod_sup_rubro
      Into v_rubro
      From ba_monedas        mo,
           ge_tip_asientos   ta,
           ge_transacciones  tr,
           ge_clientes       cl,
           ge_cta_clientes   cc,
           cc_cta_corrientes ct
     Where cc.nro_cuenta = p_nro_cuenta and
           mo.cod_moneda = ct.cod_moneda and
           ta.cod_tip_asiento = tr.cod_tip_asiento and tr.cod_transaccion = 690 and
           tr.cod_modulo = cc.cod_modulo and
           tr.cod_modalidad = cc.cod_modalidad and ta.tip_movimiento = 'C' and
           ta.cod_moneda = ct.cod_moneda and cl.cod_persona = cc.cod_persona and
           nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable and
           decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) =
           cl.residente and cc.nro_cuenta = ct.nro_cuenta
          --                     and ct.est_batch not in ('A', 'C', 'T')
           and (cc.relacion = 'P' /*or (cc.relacion != 'P'
           and not exists (Select '1'
                           from ba_personas pe, ge_cta_clientes ccp
                           where ccp.nro_cuenta = ct.nro_cuenta and
                           ccp.relacion = 'P' and
                           pe.cod_persona = ccp.cod_persona and
                           pe.tipo = 'J'))*/);
end if;

if p_cod_modulo = 5 then --- TARJETAS
/*   Select substr(replace(ta.cod_rubro,
                      'TD',
                      trim(to_char(cl.cod_tip_deudor, '09'))),
              6,
              3) --mod_sup_rubro
   into v_rubro
   From ge_plz_contables    pl,
        ge_tip_asientos     ta,
        ge_transacciones    tr,
        ge_clientes         cl,
        ge_cta_clientes     cc,
        ta_cta_tarjetas pr
  Where cc.nro_cuenta = '503490000051' and
        ta.cod_tip_asiento = tr.cod_tip_asiento and
        tr.cod_modulo = pr.cod_modulo and
        tr.cod_modalidad = pr.cod_modalidad and
        ta.tip_movimiento = 'C' and
        ta.cod_moneda = pr.cod_moneda and
        cc.nro_cuenta = pr.nro_cuenta and
        cl.cod_persona = cc.cod_persona and
        cc.relacion = 'P' and
        nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable and
        decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente and
        pl.can_dias = 0;*/
   --- Por el momento fijo hasta implementar tarjetas
     /* 265 vencido
        269 gestion
        275 moroso*/
   select decode(t.cat_automatica,1,205,2,265,3,269,275)
   into v_rubro
   from ta_cta_tarjetas t
   where t.nro_cuenta = p_nro_cuenta;
end if;
-- PRESTAMOS
if p_cod_modulo = 6 then
  BEGIN
   Select substr(replace(ta.cod_rubro,
                      'TD',
                      trim(to_char(cl.cod_tip_deudor, '09'))),
              6,
              3) ||
              case
              when pr.cod_modalidad in (670,671) then
                 '0'||substr(ta.cod_rubro,9,2)
              when nvl(pr.tip_renovacion,'A') in ('N','R','E') then
                 trim(to_char(pl.cod_plazo, '9'))||substr(ta.cod_rubro,9,2)
              else null
              end --mod_sup_rubro
    into v_rubro
    From ge_plz_contables    pl,
         ge_tip_asientos     ta,
         ge_transacciones    tr,
         ge_clientes         cl,
         ge_cta_clientes     cc,
         pr_cta_prestamos pr
    Where cc.nro_cuenta = p_nro_cuenta and
          ta.cod_tip_asiento = tr.cod_tip_asiento
          ----------
          and (
              (pr.estado in ('A','C') and pr.tipo in ('A','D') and tr.cod_transaccion = 801)
           or (pr.estado in ('A','C') and pr.tipo = 'P' and tr.cod_transaccion = 805)
           or (pr.estado = 'V' and pr.tipo in ('A','D') and tr.cod_transaccion = 820)
           or (pr.estado = 'V' and pr.tipo = 'P' and tr.cod_transaccion = 821)
           or (pr.estado = 'G' and tr.cod_transaccion = 822)
           or (pr.estado in ('I','M') and tr.cod_transaccion = 823)
              )
          and nvl(pr.tip_renovacion,'A') = nvl(ta.tip_renovacion,nvl(pr.tip_renovacion,'A'))
          ----------
          and     tr.cod_modulo = pr.cod_modulo and
                  tr.cod_modalidad = pr.cod_modalidad and
                  ta.tip_movimiento = 'C' and
                  ta.cod_moneda = pr.cod_moneda and
                  nvl(ta.est_cuenta,pr.estado) = pr.estado and
                  nvl(ta.tip_cuenta,pr.tipo) = pr.tipo and
                  cc.nro_cuenta = pr.nro_cuenta and
                  cl.cod_persona = cc.cod_persona and
                  cc.relacion = 'P' and
                  nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable and
                  decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente and
                  pl.can_dias = (select min(can_dias)
                                   from ge_plz_contables
                                  where can_dias >= (pr.fec_vencimiento - pr.fec_inicio + 1));
   EXCEPTION
      WHEN OTHERS THEN
         --- Fijo como estaba antes, sobre todo para Canceladas
         select cod_modalidad, tipo, fug_obt_plz_contable(nvl(fec_vencimiento,fec_inicio)-fec_inicio),
                tip_renovacion, estado
         into v_cod_modalidad, v_tipo, v_plz_contable, v_tip_renovacion, v_estado
         from pr_cta_prestamos
         where nro_cuenta = p_nro_cuenta;
        If v_tip_renovacion in ('N', 'R', 'E') Then
           -- Todos los renovados, refinanciados y reestructurados
           if v_tip_renovacion = 'N' then
              if v_tipo = 'A' then
                 v_tip_deudor := '06';
              else
                 v_tip_deudor := '04';
              end if;
           elsif v_tip_renovacion = 'R' then
              if v_tipo = 'A' then
                 v_tip_deudor := '08';
              else
                 v_tip_deudor := '06';
              end if;
           elsif v_tip_renovacion = 'E' then
              if v_tipo = 'A' then
                 v_tip_deudor := '10';
              else
                 v_tip_deudor := '08';
              end if;
           end if;

           if v_tipo = 'A' then     --   Prestamos amortizables
              v_rubro := '173';
           elsif v_tipo = 'P' then  -- Prestamos no amortizables
              v_rubro := '169';
           elsif v_tipo = 'D' then  -- Descuento de documentos
              v_rubro := '351';
           end if;
        Else
           if v_cod_modalidad not in (660,670,671) then
              if v_tipo = 'A' then     --   Prestamos amortizables
                 v_rubro := '173';
              elsif v_tipo = 'P' then  -- Prestamos no amortizables
                 v_rubro := '169';
              elsif v_tipo = 'D' then  -- Descuento de documentos
                 v_rubro := '351';
              end if;
           elsif v_cod_modalidad = 660 then
              if v_estado in ('C','A','V') then
                 v_rubro := '265';
              elsif v_estado = 'G' then
                 v_rubro := '269';
              elsif v_estado = 'M' then
                 v_rubro := '275';
              end if;
           elsif v_cod_modalidad = 670 then
              v_rubro := '251004';
           elsif v_cod_modalidad = 671 then
              v_rubro := '251002';
           end if;
        End if;

        if v_tip_renovacion = 'N' then     -- prestamos renovados 617
            v_rubro := v_rubro || v_plz_contable ||nvl(v_tip_deudor,'04');
        elsif v_tip_renovacion = 'R' then  -- prestamos refinanciados 618
            v_rubro := v_rubro || v_plz_contable ||nvl(v_tip_deudor,'06');
        elsif v_tip_renovacion = 'E' then  -- prestamos reestructurados 619
            v_rubro := v_rubro || v_plz_contable ||nvl(v_tip_deudor,'08');
        end if;
   END;
end if;

return v_rubro;
EXCEPTION
   when no_data_found then
   return null;
END;
/

