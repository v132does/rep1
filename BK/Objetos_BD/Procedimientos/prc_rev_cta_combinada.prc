CREATE OR REPLACE PROCEDURE IT.PRC_REV_CTA_COMBINADA
 IS
  v_fcdehoy date;
  v_nrsecue ge_movimientos.nro_secuencia%type;
  v_hora    ge_movimientos.hora%type;
  cursor ctacom is
  select av.nro_cuenta,gec.cod_sec_contable,gec.cod_tip_deudor,gec.residente,av.cod_moneda,av.cod_oficina,
       sum(nvl(av.sal_tot_batch,0)-nvl(av.sal_ret_batch,0)) v_salhoy
    from ge_clientes      gec,
         ge_cta_clientes  gcc,         
         ah_cta_vistas    av,
         ge_cuentas       ge
   where (av.cta_combinada = 'N' or -- BBVASOP-1277 - 23/08/2012 C.B.
         exists (select 1 from cc_cta_combinadas_his a  
                          where a.nro_cta_ahorro = av.nro_cuenta
                            and a.tip_movimiento = 'I'
                            and trunc(a.fec_insercion) = v_fcdehoy
                            and a.fec_apertura = v_fcdehoy 
                            and a.nro_ref_cta_combinada = 
                                (select nvl(max(aa.nro_ref_cta_combinada),0) from cc_cta_combinadas_his aa 
                                              where aa.nro_cta_ahorro = av.nro_cuenta and aa.tip_movimiento = 'I'
                                                and trunc(aa.fec_insercion) = v_fcdehoy)))
     and av.cod_modulo    = ge.cod_modulo
     and av.cod_modalidad = ge.cod_modalidad
     and av.cod_oficina   = ge.cod_oficina
     and av.nro_cuenta    = ge.nro_cuenta
     and av.nro_cuenta    = gcc.nro_cuenta
     and gcc.relacion     = 'P'
     and gcc.cod_persona  = gec.cod_persona
     and exists (select 1 from cc_cta_combinadas_his a 
                          where a.nro_cta_ahorro = av.nro_cuenta
                            and a.tip_movimiento = 'E'
                            and trunc(a.fec_insercion) = v_fcdehoy
                            and a.fec_apertura <> v_fcdehoy -- BBVASOP 1094
                            and a.nro_ref_cta_combinada = 
                                (select nvl(max(aa.nro_ref_cta_combinada),0) from cc_cta_combinadas_his aa 
                                              where aa.nro_cta_ahorro = av.nro_cuenta 
                                                and aa.tip_movimiento = 'E'
                                                and trunc(aa.fec_insercion) = v_fcdehoy))
 group by av.nro_cuenta,gec.cod_sec_contable,gec.cod_tip_deudor,gec.residente,av.cod_moneda,
          av.cod_oficina;

PROCEDURE LP_GEN_MOV_TRA
    (p_cdmodul in ge_movimientos.cod_modulo%type, 
     p_cdmodal in ge_movimientos.cod_modalidad%type, 
     p_cdtrans in ge_movimientos.cod_transaccion%type,
     p_cdofici in ge_movimientos.cod_oficina%type, 
     p_cdmoned in ge_movimientos.cod_moneda%type,
     p_cdsecto in ge_clientes.cod_sec_contable%type, 
     p_residen in ge_clientes.residente%type, 
     p_tpdeudo in number,
     p_cdplazo in number, 
     p_importe in number, 
     p_nro_cuenta in ge_movimientos.nro_cuenta%type) is
     
  v_contador  number := 0;  
  v_cod_rubro ge_tip_asientos.cod_rubro%type;
  v_tpasien   ge_tip_asientos.cod_tip_asiento%type;
  v_tpasien2  ge_tip_asientos.cod_tip_asiento%type;
  r_gmovi     GE_MOVIMIENTOS%ROWTYPE;
  cursor fgt is
    select ind_plazo, ind_deudor, tip_movimiento, cod_rubro
      from ge_tip_asientos
     where cod_tip_asiento  = v_tpasien
       and cod_moneda       = p_cdmoned
       and nvl(tip_cuenta, 'x') <> 'B'
       and (cod_sec_contable = p_cdsecto or cod_sec_contable is null)
       and (ind_residente   = p_residen or ind_residente = 'X')
    union all
    select ind_plazo, ind_deudor, tip_movimiento, cod_rubro
      from ge_tip_asientos
     where cod_tip_asiento  = v_tpasien2
       and cod_moneda       = p_cdmoned
       and nvl(tip_cuenta, 'x') <> 'B'
       and (cod_sec_contable = p_cdsecto or cod_sec_contable is null)
       and (ind_residente   = p_residen or ind_residente = 'X');
begin
   select a.cod_tip_asiento, a.cod_tip_asiento2
     into v_tpasien, v_tpasien2
     from ge_transacciones a
    where cod_modulo      = p_cdmodul
      and cod_modalidad   = p_cdmodal
      and cod_transaccion = p_cdtrans;
   for i in fgt loop
      v_nrsecue :=  v_nrsecue + 1;
      if v_nrsecue > 900 then
         v_nrsecue := 1;         
         --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
      end if;
      v_contador := nvl(v_contador,0) + 1;
      v_cod_rubro := i.cod_rubro;
      if i.ind_deudor = 'S' then
         v_cod_rubro := substr(v_cod_rubro,1,8)||
                       ltrim(to_char(p_tpdeudo,'00'))||
                       substr(v_cod_rubro,11,5);
      end if;
      if i.ind_plazo = 'S' then
         v_cod_rubro := substr(v_cod_rubro,1,2)||
                      ltrim(to_char(p_cdplazo))||
                      substr(v_cod_rubro,4,12);
      end if;
      r_gmovi.cod_modulo      := p_cdmodul;
      r_gmovi.cod_modalidad   := p_cdmodal;
      r_gmovi.cod_oficina     := p_cdofici;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.cod_rubro       := v_cod_rubro;
      r_gmovi.tip_mov_rubro   := (case when i.tip_movimiento = 'D' then 'C' else 'D' end);
      r_gmovi.cod_moneda      := p_cdmoned;
      r_gmovi.cod_usuario     := upper(user);
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fcdehoy;
      r_gmovi.nro_secuencia   := v_nrsecue;
      --
      r_gmovi.fec_valor       := v_fcdehoy;
      r_gmovi.cod_tra_padre   := 682;
      r_gmovi.cod_mod_padre   := 3;
      r_gmovi.cod_mad_padre   := 31;
      r_gmovi.monto           := p_importe;
      r_gmovi.nro_documento   := null;
      r_gmovi.nro_documento2  := null;
      r_gmovi.nro_documento3  := null;
      r_gmovi.cod_tasa        := null;
      r_gmovi.val_tasa        := null;
      r_gmovi.cotizacion      := null;
      r_gmovi.cod_ofi_origen  := p_cdofici;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Revers.de Ctas.Combinadas';
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
    end loop;
    if v_contador = 0 then
      raise_application_error(-20000,'Error. no existe asiento.:'||to_char(v_tpasien)||
      ' res.:'||p_residen||' sec.'||p_cdsecto);
    end if;
exception
  when others then
    raise_application_error(-20000,sqlerrm);
end;
begin
    v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
    v_nrsecue := 0;
    --v_hora    := fug_ini_hora(v_fcdehoy,'HH24:MI:SS');
    v_hora := to_char(sysdate,'HH24:MI:SS');
    v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    for cc in ctacom loop
       IF nvl(cc.v_salhoy,0) > 0 then
          LP_GEN_MOV_TRA(3, 31, 682, cc.cod_oficina, cc.cod_moneda,
                         cc.cod_sec_contable,cc.residente, cc.cod_tip_deudor,
                         1, nvl(cc.v_salhoy,0),cc.nro_cuenta);
       END IF;
    end loop;
exception
  when others then
    raise_application_error(-20000,'Error. en transferencia_contable '||sqlerrm);
end;
/

