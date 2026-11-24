CREATE OR REPLACE FUNCTION IT.FUB_OBT_RUB_CONTABLE
 (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_TIP_MONTO  IN VARCHAR2 DEFAULT NULL
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
v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;

-- obtiene el codigo de rubro que corresponde a una cuenta
FUNCTION LF_OBT_COD_RUBRO
  (p_cod_modulo IN NUMBER,
   p_cod_modalidad IN NUMBER,
   p_cod_transaccion IN NUMBER,
   p_cod_moneda IN VARCHAR2,
   p_cod_sec_contable IN VARCHAR2,
   p_cod_tip_deudor IN NUMBER,
   p_residente IN VARCHAR2,
   p_cod_plazo IN VARCHAR2,
   p_tip_movimiento IN VARCHAR2,
   p_cod_sit_contable in number default null,
   p_est_cuenta in varchar2 default null,
   p_tip_renovacion in varchar2 default null,
   p_cat_automatica in number default null,
   p_tip_interes    in varchar2 default null,
   p_tip_cuenta     in varchar2 default null)
 RETURN varchar2   IS
v_cod_tip_asiento number(6);
v_cod_tip_asiento2 number(6);
v_ind_deudor varchar2(1);
v_ind_plazo varchar2(1);
v_ind_producto varchar2(1);
v_cod_pro_contable number(3);
p_cod_rubro  VARCHAR2(20);

BEGIN
   /* busco la transaccion que le corresponde */
   SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
     INTO v_cod_tip_asiento,  v_cod_tip_asiento2, v_cod_pro_contable
     FROM ge_modalidades mo, ge_transacciones tr
    WHERE tr.cod_modulo = p_cod_modulo
      AND tr.cod_modalidad = p_cod_modalidad
      AND tr.cod_transaccion = p_cod_transaccion
      and mo.cod_modulo = p_cod_modulo
      and mo.cod_modalidad = p_cod_modalidad;
   /* busco la cuenta contable que le corresponde */
   SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
     INTO v_ind_plazo,v_ind_deudor, p_cod_rubro, v_ind_producto
     FROM ge_tip_asientos
    WHERE cod_tip_asiento in (v_cod_tip_asiento, v_cod_tip_asiento2)
      AND cod_moneda = p_cod_moneda
      AND (cod_sec_contable is null or cod_sec_contable = p_cod_sec_contable)
      and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
      and (tip_interes is null or tip_interes = p_tip_interes)
      and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
      and (cat_automatica is null or cat_automatica = p_cat_automatica)
      and (est_cuenta is null or est_cuenta = p_est_cuenta)
      AND (ind_residente = 'X' OR ind_residente = p_residente)
      and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
      AND tip_movimiento = p_tip_movimiento
      AND nro_linea =  ( Select min(nro_linea)
                           FROM ge_tip_asientos
                          WHERE cod_tip_asiento = v_cod_tip_asiento
                            AND cod_moneda = p_cod_moneda
                            AND (cod_sec_contable is null or cod_sec_contable = p_cod_sec_contable)
                            and (tip_renovacion is null or tip_renovacion = NVL(p_tip_renovacion,'A'))
                            and (tip_interes is null or tip_interes = p_tip_interes)
                            and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)
                            and (cat_automatica is null or cat_automatica = p_cat_automatica)
                            and (est_cuenta is null or est_cuenta = p_est_cuenta)
                            AND (ind_residente = 'X' OR ind_residente = p_residente)
                            and (cod_sit_contable is null or cod_sit_contable = p_cod_sit_contable)
                            AND tip_movimiento = p_tip_movimiento)
      AND ROWNUM = 1;
   IF v_ind_plazo = 'S' then
      p_cod_rubro := substr(p_cod_rubro,1,2)||p_cod_plazo||
                    substr(p_cod_rubro,4,12);
   END IF;
   IF v_ind_deudor = 'S' OR substr(p_cod_rubro,9,2) = 'TD' then
      p_cod_rubro := substr(p_cod_rubro,1,8)||
                    (ltrim(to_char(p_cod_tip_deudor,'00')))||
                    substr(p_cod_rubro,11,5);
   END IF;
   ---Reemplaza el codigo del producto -----------------------
   IF v_IND_PRODUCTO = 'S' THEN
      p_cod_rubro := SUBSTR(p_cod_rubro,1,10)||
                     LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                     SUBSTR(p_cod_rubro,14,2);
   END IF;
   return p_cod_rubro;
EXCEPTION
   WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,' '||SQLERRM);
        p_cod_rubro := NULL;
        return p_cod_rubro;
END;

BEGIN
-- Certificados de Ahorros a Plazo Fijo

If p_cod_modulo = 3 then
   Select replace(replace(ta.cod_rubro,'TD',trim(to_char(cl.cod_tip_deudor, '09'))),
          'P',trim(to_char(pl.cod_plazo, '9')))
   Into V_RUBRO
       --mo.cod_mon_bco_central
   From ba_monedas          mo,
        ge_plz_contables    pl,
        ge_tip_asientos     ta,
        ge_transacciones    tr,
        ge_clientes         cl,
        ge_cta_clientes     cc,
        ah_cta_certificados ah
  Where cc.nro_cuenta = p_nro_cuenta and
        mo.cod_moneda = ah.cod_moneda and
        ta.cod_tip_asiento = tr.cod_tip_asiento and tr.cod_transaccion = 604 and
        tr.cod_modulo = cc.cod_modulo and
        tr.cod_modalidad = cc.cod_modalidad and
        ta.tip_movimiento = 'D' and
        ta.cod_moneda = ah.cod_moneda and
       cl.cod_persona = cc.cod_persona and
       nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable and
       decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) = cl.residente and
       pl.can_dias = (select min(can_dias)
                        from ge_plz_contables
                       where can_dias >= (ah.fec_vencimiento - ah.fec_apertura + 1)) and
       cc.nro_cuenta = ah.nro_cuenta and
       --ah.est_batch not in ('A', 'C', 'T') and
       --ah.est_cer_batch not in ('V', 'P') and
       (cc.relacion = 'P' or(cc.relacion != 'P' and
       not exists (Select '1'
                     from ba_personas pe, ge_cta_clientes ccp
                    where ccp.nro_cuenta = ah.nro_cuenta and
                          ccp.relacion = 'P' and
                          pe.cod_persona = ccp.cod_persona and
                          pe.tipo = 'J')))

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

-- ahorros a la vista
    Union
    Select replace(replace(ta.cod_rubro,'TD',trim(to_char(cl.cod_tip_deudor, '09'))),
          'P','1')
      From ba_monedas       mo,
           ge_tip_asientos  ta,
           ge_transacciones tr,
           ge_clientes      cl,
           ge_cta_clientes  cc,
           ah_cta_vistas    ah
     Where cc.nro_cuenta = p_nro_cuenta and
           mo.cod_moneda = ah.cod_moneda and
           ta.cod_tip_asiento = tr.cod_tip_asiento and tr.cod_transaccion = 690 and
           tr.cod_modulo = cc.cod_modulo and
           tr.cod_modalidad = cc.cod_modalidad and ta.tip_movimiento = 'C' and
           ta.cod_moneda = ah.cod_moneda and cl.cod_persona = cc.cod_persona and
           nvl(ta.cod_sec_contable, cl.cod_sec_contable) = cl.cod_sec_contable and
           ((ah.cod_sub_modalidad = 26 and ta.tip_cuenta = 'B') or (ah.cod_sub_modalidad <> 26 and nvl(ta.tip_cuenta, 'x') <> 'B')) and -- Cuenta Basica
           decode(ta.ind_residente, 'X', cl.residente, ta.ind_residente) =
           cl.residente and cc.nro_cuenta = ah.nro_cuenta and
           (cc.relacion = 'P' or
           (cc.relacion != 'P' and not exists
            (Select '1'
                from ba_personas pe, ge_cta_clientes ccp
               where ccp.nro_cuenta = ah.nro_cuenta and ccp.relacion = 'P' and
                     pe.cod_persona = ccp.cod_persona and pe.tipo = 'J')));
end if;


/*
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
           and (cc.relacion = 'P' or (cc.relacion != 'P'
           and not exists (Select '1'
                           from ba_personas pe, ge_cta_clientes ccp
                           where ccp.nro_cuenta = ct.nro_cuenta and
                           ccp.relacion = 'P' and
                           pe.cod_persona = ccp.cod_persona and
                           pe.tipo = 'J')));
end if;
*/
-- PRESTAMOS
if p_cod_modulo = 6 then
  BEGIN
   Select replace(replace(ta.cod_rubro,'TD',trim(to_char(cl.cod_tip_deudor, '09'))),
          'P',trim(to_char(pl.cod_plazo, '9')))
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
                                  where can_dias >= (pr.fec_vencimiento - (pr.fec_inicio + 1)));
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
if p_cod_modulo = 8 then
  declare
     cursor datos is select  a.cod_modulo,
                             a.cod_modalidad,
                             decode(p_tip_monto,'U',890,874) cod_transaccion,
                             a.cod_moneda,
                             c.cod_sec_contable,
                             c.cod_tip_deudor,
                             c.residente,
                             1 cod_plazo,
                             'D' tip_movimiento,
                             a.cod_sit_contable
                        from ge_clientes c,ge_cta_clientes b, ge_cuentas a
                       where a.nro_cuenta = p_nro_cuenta
                         and b.nro_cuenta = a.nro_cuenta
                         and b.relacion = 'P'
                         and c.cod_persona = b.cod_persona;
     reg datos%rowtype;
  begin
      open datos;
      fetch datos into reg;
      close datos;

      RETURN LF_OBT_COD_RUBRO(reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_moneda,
                       reg.cod_sec_contable, reg.cod_tip_deudor, reg.residente, reg.cod_plazo,
                       reg.tip_movimiento,reg.cod_sit_contable);
  end;

end if;
if p_cod_modulo = 10 then
   declare
     cursor datos is select  a.cod_modulo,
                             a.cod_modalidad,
                             t.cod_transaccion,
                             a.cod_moneda,
                             c.cod_sec_contable,
                             c.cod_tip_deudor,
                             c.residente,
                             FUG_OBT_PLZ_CONTABLE(nvl(a.fec_vencimiento - a.fec_apertura,0)) cod_plazo,
                             s.tip_movimiento,
                             a.cod_sit_contable
                        from ge_clientes c, ge_cta_clientes b, ge_cuentas a, ge_transacciones t, ge_tip_asientos s
                       where a.nro_cuenta = p_nro_cuenta
                         and b.nro_cuenta = a.nro_cuenta
                         and t.cod_tip_asiento = s.cod_tip_asiento
                         and t.cod_modulo = a.cod_modulo
                         and t.cod_modalidad = a.cod_modalidad
                         and s.cod_moneda = a.cod_moneda
                         /*filtrar transacciones de alta de capital por modalidad */
                         /*and a.cod_modalidad in(100, 101, 102, 109,110, 112, 113,114,115,116,117,118,119)*/
                                                -- 103,104,105,106,120,122,123,124
                         and b.relacion = 'P'
                         and c.cod_persona = b.cod_persona
                         and s.tip_movimiento = 'D'
                         and t.cod_transaccion = 711
                         and a.estado <> 'S';




      reg datos%rowtype;
   begin
      open datos;
      fetch datos into reg;
      close datos;

      RETURN LF_OBT_COD_RUBRO(reg.cod_modulo, reg.cod_modalidad, reg.cod_transaccion, reg.cod_moneda,
                       reg.cod_sec_contable, reg.cod_tip_deudor, reg.residente, reg.cod_plazo,
                       reg.tip_movimiento,reg.cod_sit_contable);

end;
end if;
return v_rubro;
EXCEPTION
   when no_data_found then
     return null;
   when others then
     return null;
END;
/

