CREATE OR REPLACE PROCEDURE IT.PRG_INS_PRE_CAMPANA is
  v_nro_cta_tc  ge_cuentas.nro_cuenta%type;
  v_lin_cre_ini ta_cta_tarjetas.lin_credito%type;
  v_lin_cre_fin ta_cta_tarjetas.lin_credito%type;
  v_fec_cam_lin ge_sal_diarios.fecha%type;
  v_fec_actual  ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1) ;
  v_fec_ant_hab ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_ant_hab(v_fec_actual - 2,1);
  v_fec_sig_hab ge_calendarios.fec_actual%type;

/* ALV - 26/01/2016. Proceso para generación de datos de control de Prestamos 
   por lineas de credito de tarjetas */

  cursor c_cta_pre is
    select g.cod_persona, p.nro_cuenta, p.mto_capital, p.fec_inicio, p.cod_campana
      from pr_cta_prestamos p, ge_cta_clientes g
     where p.nro_cuenta = g.nro_cuenta
       and g.relacion = 'P'
       and p.fec_inicio < v_fec_ant_hab
       and exists (select 1 from ba_cod_referencias r
                    where r.dominio = 'CAM_TAR_PROMO'
                      and r.val_minimo = p.cod_campana)
       and not exists (select 1 from ge_tar_pre_campanas t
                        where t.nro_cta_prestamo = p.nro_cuenta);

  cursor c_cta_tar(p_cod_persona in ba_personas.cod_persona%type,
                   p_fec_inicio  in ge_sal_diarios.fecha%type) is
    select tc.nro_cuenta, tc.lin_credito, s.mto_linea, s.fecha
      from ge_cta_clientes a, ta_cta_tarjetas tc, ge_sal_diarios s
     where a.cod_persona = p_cod_persona
       and tc.nro_cuenta = a.nro_cuenta
       and a.cod_modulo = 5
       and a.relacion = 'P'
       and tc.estado <> 'C' -- No debe estar Cancelado
       and tc.nro_cuenta = s.nro_cuenta
       and s.fecha between p_fec_inicio and v_fec_sig_hab
       and s.mto_linea > tc.lin_credito ;

BEGIN
   for cab in c_cta_pre loop
      v_fec_sig_hab := pag_cal.fu_obt_fec_sig_hab(cab.fec_inicio, 1, 2);
      
      for det in c_cta_tar(cab.cod_persona, cab.fec_inicio) loop
         v_fec_cam_lin  := pag_cal.fu_obt_fec_sig_hab(det.fecha, 1) ;
         v_nro_cta_tc   := det.nro_cuenta  ;
         v_lin_cre_ini  := det.mto_linea   ;
         v_lin_cre_fin  := det.lin_credito ;
         
      end loop;
      
      insert into ge_tar_pre_campanas (COD_PER_PRINCIPAL, NRO_CTA_TARJETA, NRO_CTA_PRESTAMO,
                       MTO_PRESTAMO, COD_CAMPANA, FEC_INICIO, FEC_CAM_LINEA,
                       MTO_LIN_INICIAL, MTO_LIN_FINAL)
             values   (cab.cod_persona, v_nro_cta_tc, cab.nro_cuenta,
                       cab.mto_capital, cab.cod_campana, cab.fec_inicio, v_fec_cam_lin,
                       v_lin_cre_ini, v_lin_cre_fin);
       -- Si no encuentra la tarjeta debe limpiar los datos
       v_fec_cam_lin  := null ;
       v_nro_cta_tc   := null ;
       v_lin_cre_ini  := null ;
       v_lin_cre_fin  := null ;
   end loop;

EXCEPTION
     when others then
         raise_application_error(-20000,'Error en PRG_INS_PRE_CAMPANA'||' - '||sqlerrm);
end;
/

