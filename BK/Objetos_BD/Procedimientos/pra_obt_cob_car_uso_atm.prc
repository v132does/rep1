CREATE OR REPLACE PROCEDURE IT.PRA_OBT_COB_CAR_USO_ATM ( p_nro_cuenta       in varchar2,
                                                     p_gru_transaccion  in number,
                                                     p_val_cargo        in out ge_movimientos.val_tasa%type,
                                                     p_val_impuesto     in out ge_movimientos.val_tasa%type 
                                                     ) is
  -- MDPMATNT-1 -- Mensajería en ATM sobre comisiones por transacciones -- CN: 02/2016
  V_COD_TAS_CARGO        GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_CARGO        GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_CARGO            GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_COD_TRA_IMPUESTO     GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
  V_COD_TAS_IMPUESTO     GE_MOVIMIENTOS.COD_TASA%TYPE;
  V_VAL_TAS_IMPUESTO     GE_MOVIMIENTOS.VAL_TASA%TYPE;
  V_VAL_IMPUESTO         GE_MOVIMIENTOS.VAL_TASA%TYPE;
  v_cod_gru_transaccion  GE_GRU_TRANSACCIONES.COD_GRU_TRANSACCION%type;
  v_cod_mod_cargo     GE_MOVIMIENTOS.COD_MODULO%TYPE;
  v_cod_mad_cargo     GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;

cursor cargos is
  select a.cod_gru_transaccion, 
         a.tipo, 
         a.cod_tra_cargo, 
         a.par_dinamico, 
         a.ind_atm_propio ntr_atm ,
         a.cod_tra_bancard
    from gv_gru_tra_cob_car_atm a,
         ( select val_minimo cod_tra_bancard, 
                  nvl(val_maximo,'N') activado
             from ba_cod_referencias 
            where dominio = 'COD_TRA_BANCARD' ) b
   where cod_gru_transaccion = p_gru_transaccion
     and a.cod_tra_bancard = b.cod_tra_bancard
     and b.activado = 'S';
     
cursor ctas is
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, a.cod_ente
    from ah_cta_vistas a
   where nro_cuenta = p_nro_cuenta
     and estado not in ('T','C','A','X')
     and not exists (select 1
                       from ge_par_entes p
                      where p.parametro = 'NRO_CUENTA'
                        and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
     and ( exists( select 1
                   from ge_movimientos           m,
                        ge_gru_transacciones_det g
                  where m.nro_cuenta = a.nro_cuenta
                    and m.estado = 'N'
                    and m.reversado = 'N'
                    and cod_mod_padre = g.cod_modulo
                    and cod_mad_padre = g.cod_modalidad
                    and cod_tra_padre = g.cod_transaccion
                    and g.cod_gru_transaccion = v_cod_gru_transaccion ) 
          or exists( select 1
                       from ge_movimientos_noc       m,
                            ge_gru_transacciones_det g
                      where m.nro_cuenta = a.nro_cuenta
                        and m.estado = 'N'
                        and m.reversado = 'N'
                        and cod_mod_padre = g.cod_modulo
                        and cod_mad_padre = g.cod_modalidad
                        and cod_tra_padre = g.cod_transaccion
                        and g.cod_gru_transaccion = v_cod_gru_transaccion ))
  union all
  select nro_cuenta, cod_moneda, cod_oficina, cod_modulo, cod_modalidad, a.cod_ente
    from cc_cta_corrientes a
   where nro_cuenta = p_nro_cuenta
     and estado not in ('T','C','A','X')
     and not exists (select 1
                       from ge_par_entes p
                      where p.parametro = 'NRO_CUENTA'
                        and p.val_parametro = a.nro_cuenta) -- cuenta sponsor
     and ( exists( select 1
                     from ge_movimientos           m,
                          ge_gru_transacciones_det g
                    where m.nro_cuenta = a.nro_cuenta
                      and m.estado = 'N'
                      and m.reversado = 'N'
                      and cod_mod_padre = g.cod_modulo
                      and cod_mad_padre = g.cod_modalidad
                      and cod_tra_padre = g.cod_transaccion
                      and g.cod_gru_transaccion = v_cod_gru_transaccion ) 
         or exists( select 1
                      from ge_movimientos_noc       m,
                           ge_gru_transacciones_det g
                    where m.nro_cuenta = a.nro_cuenta
                      and m.estado = 'N'
                      and m.reversado = 'N'
                      and cod_mod_padre = g.cod_modulo
                      and cod_mad_padre = g.cod_modalidad
                      and cod_tra_padre = g.cod_transaccion
                      and g.cod_gru_transaccion = v_cod_gru_transaccion ));  -- DYDMR-5533
begin
  p_val_cargo    := 0;
  p_val_impuesto := 0;
  for cg in cargos loop
    v_cod_gru_transaccion := cg.cod_gru_transaccion;
    for reg in ctas loop
      v_cod_mod_cargo := reg.cod_modulo;
      v_cod_mad_cargo := reg.cod_modalidad;

      --Se cobra cargos por la operacion si corresponde
      if cg.ntr_atm = 'S' then
        prg_obt_car_uso_pro_atm (reg.nro_cuenta,
                                 cg.cod_gru_transaccion,
                                 cg.cod_tra_cargo,
                                 cg.par_dinamico,
                                 V_COD_TAS_CARGO,
                                 V_VAL_TAS_CARGO,
                                 v_val_cargo,
                                 V_COD_TRA_IMPUESTO,
                                 V_COD_TAS_IMPUESTO,
                                 V_VAL_TAS_IMPUESTO,
                                 v_val_impuesto,
                                 'S');
      else
        prg_obt_car_uso_otr_atm (reg.nro_cuenta,
                                 cg.cod_gru_transaccion,
                                 cg.cod_tra_cargo,
                                 cg.par_dinamico,
                                 V_COD_TAS_CARGO,
                                 V_VAL_TAS_CARGO,
                                 v_val_cargo,
                                 V_COD_TRA_IMPUESTO,
                                 V_COD_TAS_IMPUESTO,
                                 V_VAL_TAS_IMPUESTO,
                                 v_val_impuesto,
                                 'S');
      end if;
      
      p_val_cargo    := nvl(p_val_cargo,0) + nvl(v_val_cargo,0);
      p_val_impuesto := nvl(p_val_impuesto,0) + nvl(v_val_impuesto,0);
  
    end loop;
  end loop;
  
  p_val_cargo    := nvl(p_val_cargo,0);
  p_val_impuesto := nvl(p_val_impuesto,0);
      
end pra_obt_cob_car_uso_atm;
/

