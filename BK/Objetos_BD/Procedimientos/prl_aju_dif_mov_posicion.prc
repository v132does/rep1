create or replace procedure it.prl_aju_dif_mov_posicion is
v_est_mod_cambios number(2);
cursor c_datos is
select t.*, nvl(mto_pos,0) - nvl(mto_mov,0) dif_monto
from
(
select a.cod_moneda,
       o.cod_ofi_cambio ofi_cambios,
       c.descripcion des_ofi_cambios,
       b.afe_posicion afe_pos, decode(b.afe_posicion,'E','Efectivo','O','Otros','N','No Afecta') des_afe_pos,
       a.cod_bco_central cod_bcp,
       a.cod_mad_padre, d.descripcion des_modal,
       b.cod_mad_hijo cod_mad_hijo,
       decode(a.cod_mad_padre,71,decode(b.afe_posicion,'E',xx_mto_com_efe_act,'O',xx_mto_com_nef_act,0),
                              72,decode(b.afe_posicion,'E',xx_mto_vta_efe_act,'O',xx_mto_vta_nef_act,0),
                              73,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_arb_com_efe_act,'O',xx_mto_arb_com_nef_act,0),
                                                       72,decode(b.afe_posicion,'E',xx_mto_arb_vta_efe_act,'O',xx_mto_arb_vta_nef_act,0),0),
                              74,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_cje_com_efe_act,'O',xx_mto_cje_com_nef_act,0),
                                                       72,decode(b.afe_posicion,'E',xx_mto_cje_vta_efe_act,'O',xx_mto_cje_vta_nef_act,0),0),0) mto_pos,


       sum(nvl(a.monto,0)) mto_mov
from ba_oficinas o, lc_tip_operaciones b, ge_movimientos a, ba_oficinas c,
     ge_modalidades d,
(
SELECT
cod_moneda xx_cod_moneda,
cod_tip_ope_bcp xx_cod_tip_ope_bcp,
cod_ofi_cambio xx_cod_ofi_cambio,

mto_com_efe_act xx_mto_com_efe_act,
mto_com_nef_act xx_mto_com_nef_act,
mto_vta_efe_act xx_mto_vta_efe_act,
mto_vta_nef_act xx_mto_vta_nef_act,

mto_arb_com_efe_act xx_mto_arb_com_efe_act,
mto_arb_com_nef_act xx_mto_arb_com_nef_act,
mto_arb_vta_efe_act xx_mto_arb_vta_efe_act,
mto_arb_vta_nef_act xx_mto_arb_vta_nef_act,

mto_cje_com_efe_act xx_mto_cje_com_efe_act,
mto_cje_com_nef_act xx_mto_cje_com_nef_act,
mto_cje_vta_efe_act xx_mto_cje_vta_efe_act,
mto_cje_vta_nef_act xx_mto_cje_vta_nef_act,

mto_com_efe_loc xx_mto_com_efe_loc,
mto_com_nef_loc xx_mto_com_nef_loc,
mto_vta_efe_loc xx_mto_vta_efe_loc,
mto_vta_nef_loc xx_mto_vta_nef_loc
from lc_posiciones
)
where a.cod_tip_ope_cambio = b.cod_tip_operacion
and b.afe_posicion in ('E','O')
and a.cod_ofi_origen = o.cod_oficina
and a.estado = 'N'
and a.reversado = 'N'
and c.cod_oficina = o.cod_ofi_cambio
and d.cod_modulo = 7
and d.cod_modalidad = a.cod_mad_padre
and xx_cod_moneda = a.cod_moneda
and xx_cod_tip_ope_bcp = a.cod_bco_central
and xx_cod_ofi_cambio = o.cod_ofi_cambio
group by a.cod_moneda,
         o.cod_ofi_cambio, c.descripcion,
         b.afe_posicion, a.cod_bco_central,
         a.cod_mad_padre, d.descripcion,
         b.cod_mad_hijo,
         decode(a.cod_mad_padre,71,decode(b.afe_posicion,'E',xx_mto_com_efe_act,'O',xx_mto_com_nef_act,0),
                                72,decode(b.afe_posicion,'E',xx_mto_vta_efe_act,'O',xx_mto_vta_nef_act,0),
                                73,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_arb_com_efe_act,'O',xx_mto_arb_com_nef_act,0),
                                                       72,decode(b.afe_posicion,'E',xx_mto_arb_vta_efe_act,'O',xx_mto_arb_vta_nef_act,0),0),
                                74,decode(b.cod_mad_hijo,71,decode(b.afe_posicion,'E',xx_mto_cje_com_efe_act,'O',xx_mto_cje_com_nef_act,0),
                                                       72,decode(b.afe_posicion,'E',xx_mto_cje_vta_efe_act,'O',xx_mto_cje_vta_nef_act,0),0),0)
) t
where nvl(mto_pos,0) <> nvl(mto_mov,0);


begin
--Verificacion para controlar que se efectue antes del cierre--
v_est_mod_cambios := PAE_CNF.FU_OBT_EST_MODULO(7); --Estado Modulo de Cambios--
if v_est_mod_cambios <> 2 then --Control del modulo debe estar en 2=Abierto--
   RAISE_APPLICATION_ERROR(-20000,'Error. Modulo de Cambios no está Abierto, No se puede ajustar la posicion.');
end if;

--Ciclo Principal--
for dat in c_datos loop
    if ((nvl(dat.dif_monto,0) <> 0)) then
       if dat.cod_mad_padre in (71,72) then
        -- compra o venta
        update lc_posiciones a
           set mto_com_efe_act = decode(dat.cod_mad_padre,71,decode(dat.afe_pos,'E',a.mto_com_efe_act-dat.dif_monto,a.mto_com_efe_act),a.mto_com_efe_act),
               mto_com_nef_act = decode(dat.cod_mad_padre,71,decode(dat.afe_pos,'O',a.mto_com_nef_act-dat.dif_monto,a.mto_com_nef_act),a.mto_com_nef_act),
               mto_vta_efe_act = decode(dat.cod_mad_padre,72,decode(dat.afe_pos,'E',a.mto_vta_efe_act-dat.dif_monto,a.mto_vta_efe_act),a.mto_vta_efe_act),
               mto_vta_nef_act = decode(dat.cod_mad_padre,72,decode(dat.afe_pos,'O',a.mto_vta_nef_act-dat.dif_monto,a.mto_vta_nef_act),a.mto_vta_nef_act)
         where a.COD_OFI_CAMBIO = dat.ofi_cambios
           and a.COD_MONEDA = dat.cod_moneda
           and a.COD_TIP_OPE_BCP = dat.cod_bcp;
       elsif dat.cod_mad_padre in (73) then
        -- arbitraje
        update lc_posiciones a
           set mto_arb_com_efe_act = decode(dat.cod_mad_hijo,71,decode(dat.afe_pos,'E',a.mto_arb_com_efe_act-dat.dif_monto,a.mto_arb_com_efe_act),a.mto_arb_com_efe_act),
               mto_arb_com_nef_act = decode(dat.cod_mad_hijo,71,decode(dat.afe_pos,'O',a.mto_arb_com_nef_act-dat.dif_monto,a.mto_arb_com_nef_act),a.mto_arb_com_nef_act),
               mto_arb_vta_efe_act = decode(dat.cod_mad_hijo,72,decode(dat.afe_pos,'E',a.mto_arb_vta_efe_act-dat.dif_monto,a.mto_arb_vta_efe_act),a.mto_arb_vta_efe_act),
               mto_arb_vta_nef_act = decode(dat.cod_mad_hijo,72,decode(dat.afe_pos,'O',a.mto_arb_vta_nef_act-dat.dif_monto,a.mto_arb_vta_nef_act),a.mto_arb_vta_nef_act)
         where a.COD_OFI_CAMBIO = dat.ofi_cambios
           and a.COD_MONEDA = dat.cod_moneda
           and a.COD_TIP_OPE_BCP = dat.cod_bcp;
       elsif dat.cod_mad_padre in (74) then
        -- canje
        update lc_posiciones a
           set mto_cje_com_efe_act = decode(dat.cod_mad_hijo,71,decode(dat.afe_pos,'E',a.mto_cje_com_efe_act-dat.dif_monto,a.mto_cje_com_efe_act),a.mto_cje_com_efe_act),
               mto_cje_com_nef_act = decode(dat.cod_mad_hijo,71,decode(dat.afe_pos,'O',a.mto_cje_com_nef_act-dat.dif_monto,a.mto_cje_com_nef_act),a.mto_cje_com_nef_act),
               mto_cje_vta_efe_act = decode(dat.cod_mad_hijo,72,decode(dat.afe_pos,'E',a.mto_cje_vta_efe_act-dat.dif_monto,a.mto_cje_vta_efe_act),a.mto_cje_vta_efe_act),
               mto_cje_vta_nef_act = decode(dat.cod_mad_hijo,72,decode(dat.afe_pos,'O',a.mto_cje_vta_nef_act-dat.dif_monto,a.mto_cje_vta_nef_act),a.mto_cje_vta_nef_act)
         where a.COD_OFI_CAMBIO = dat.ofi_cambios
           and a.COD_MONEDA = dat.cod_moneda
           and a.COD_TIP_OPE_BCP = dat.cod_bcp;
       end if;
    end if;
end loop;

exception
  when others then
       RAISE_APPLICATION_ERROR(-20001,'ERROR en prl_aju_dif_mov_posicion. '||sqlerrm);
end;
/

