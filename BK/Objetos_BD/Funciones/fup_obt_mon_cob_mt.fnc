create or replace function it.fup_obt_mon_cob_mt(p_nro_cuenta ge_cuentas.nro_cuenta%type,
                                              p_tip_monto  varchar2,
                                              p_fec_ult_categorizacion date,
                                              p_nro_cta_madre ge_cuentas.nro_cuenta%type)
  return number as
  -- Created on 21/12/2021 by OFIGUEREDO
  -- Local variables here
  v_max_fec_mt     date;
  v_tot_riesgo     number;
  --v_fec_ult_cat    date;
  v_fec_ini_cobros date;
  v_tot_cobrado    number;
  v_nro_cta_madre_mt  pr_cta_prestamos.nro_cuenta%type;
begin
  -- Test statements here

  --obtiene cuenta madre de la cuenta MT evaluada (si es la madre retornara mismo valor que parametro)
  /*select distinct(mm.nro_cuenta)
    into v_nro_cta_madre
    from ge_cta_dat_adicionales mm
   where mm.parametro in
         ('PRE_RRR_CTA_MBT', 'PRE_RRR_CTA_MBT1', 'PRE_RRR_CTA_MBT2')
     and (mm.nro_cuenta = p_nro_cuenta or mm.val_parametro = p_nro_cuenta);*/
   v_nro_cta_madre_mt := p_nro_cta_madre;
  --obtencion de riesgo total de las operaciones MT 
  --fecha inicio de saldo para cuenta madre
  select max(fec_inicio)
    into v_max_fec_mt
    from pr_Cta_prestamos p
   where p.nro_cuenta in
         (SELECT ss.val_parametro
            FROM pr_cta_prestamos       bb,
                 ge_cta_dat_adicionales ss
           WHERE ss.nro_cuenta = bb.nro_cuenta
             AND SS.NRO_CUENTA = v_nro_cta_madre_mt --'2222877' --CUENTA MADRE
             AND ss.parametro in
                 ('PRE_RRR_CTA_MBT', 'PRE_RRR_CTA_MBT1', 'PRE_RRR_CTA_MBT2')
             AND ((bb.estado NOT IN ('N', 'I') AND
                 nvl(bb.sal_capital, 0) + nvl(bb.sal_int_adelantado, 0) +
                 nvl(bb.sal_interes, 0) > 0)));

  if p_tip_monto = 'R' then
  
    --saldo total de las operaciones
    select sum(cuo.saldo)
      into v_tot_riesgo
      from (select (sum(mto_capital) + sum(cu.mto_interes)) saldo --saldo cuenta madre
              from pr_Cuotas cu
             where (nro_cuenta = nvl(v_nro_cta_madre_mt,p_nro_cuenta)) --'2222877'
               and (nro_cuota >=
                   (select min(nro_cuota)
                      from pr_cobros c
                     where (c.fecha > v_max_fec_mt OR v_max_fec_mt is null) -- '30/11/2020'
                       and nro_cuenta = cu.nro_cuenta
                     or cu.nro_cuenta not in (select distinct nro_cuenta from pr_cobros cc where cc.fecha > v_max_fec_mt)))                      
            union all
            select (sum(mto_capital) + sum(cu.mto_interes)) saldo --saldo cuentas MT relacionadas
              from pr_Cuotas cu
             where nro_cuenta in
                   (select mm.val_parametro
                      from ge_cta_dat_adicionales mm
                     where mm.parametro in
                           ('PRE_RRR_CTA_MBT',
                            'PRE_RRR_CTA_MBT1',
                            'PRE_RRR_CTA_MBT2')
                       and mm.nro_cuenta = v_nro_cta_madre_mt
                       and mm.val_parametro <> mm.nro_cuenta)) cuo;
  
    return NVL(v_tot_riesgo,0);
    
   -----------------//------------//-----------------
  else--'C' para retornar lo cobrado
  
    --Obtenci?n de total de cobros de las operaciones
    v_fec_ini_cobros := v_max_fec_mt;
    
/*    if v_max_fec_mt is not null then
      --si la ultima categorizacion supera la fecha de inicio de la ultima MT se tiene en cuenta desde ahi
      if p_fec_ult_categorizacion > v_max_fec_mt then 
      
        v_fec_ini_cobros := p_fec_ult_categorizacion;
      else --sino usar la ultima fecha de inicio de MT
        v_fec_ini_cobros := v_max_fec_mt;
      end if;
    end if;*/
  
    select (sum(nvl(mto_capital, 0)) + sum(nvl(c.mto_interes, 0)))
      into v_tot_cobrado
      from pr_cobros c
     where c.fecha > v_fec_ini_cobros -- '30/11/2020'
       and (nro_cuenta = v_nro_cta_madre_mt or nro_cuenta = p_nro_cuenta or
            nro_cuenta in
            (select mm.val_parametro
               from ge_cta_dat_adicionales mm
              where mm.parametro in ('PRE_RRR_CTA_MBT',
                                     'PRE_RRR_CTA_MBT1',
                                     'PRE_RRR_CTA_MBT2')
                and mm.nro_cuenta = v_nro_cta_madre_mt));
  
    return NVL(v_tot_cobrado,0);
  
  end if;

end;
/

